// lib/services/multi_tenant_firebase_sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

/// Complete Multi-Tenant Firebase Sync Service
class MultiTenantFirebaseSyncService extends GetxService {
  // Singleton instance
  static MultiTenantFirebaseSyncService get instance =>
      Get.find<MultiTenantFirebaseSyncService>();

  // Firebase instances
  FirebaseFirestore? _firestore;
  firebase_auth.FirebaseAuth? _firebaseAuth;

  // Controllers
  AuthController get _authController => Get.find<AuthController>();

  // Sync state
  final RxBool isSyncing = false.obs;
  final RxBool isOnline = true.obs;
  final RxBool firebaseAvailable = false.obs;
  final Rx<DateTime> lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0).obs;

  // Timers
  Timer? _periodicSyncTimer;
  Timer? _debouncedSyncTimer;

  // Sync tables
  final List<String> _syncTables = [
    'users',
    'courses',
    'fleet',
    'schedules',
    'invoices',
    'payments',
    'billing_records',
    'notes',
    'notifications',
    'attachments',
    'currencies',
    'settings'
  ];

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeFirebase();
    _setupConnectivityListener();
  }

  /// Initialize Firebase services
  Future<void> _initializeFirebase() async {
    try {
      _firestore = FirebaseFirestore.instance;
      _firebaseAuth = firebase_auth.FirebaseAuth.instance;
      firebaseAvailable.value = true;
      print('✅ Multi-tenant Firebase services initialized');
    } catch (e) {
      print('❌ Firebase initialization failed: $e');
      firebaseAvailable.value = false;
    }
  }

  /// Set up connectivity listener
  void _setupConnectivityListener() {
    // Simple connectivity check - you can enhance this
    Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkConnectivity();
    });
  }

  /// Check internet connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      isOnline.value = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      isOnline.value = false;
    }
  }

  // Get school configuration service
  SchoolConfigService get _schoolConfig => SchoolConfigService.instance;

  /// Setup automatic sync with multi-tenant support
  Future<void> setupAutomaticSync() async {
    if (!firebaseAvailable.value) {
      print('⚠️ Firebase not available, skipping automatic sync setup');
      return;
    }

    try {
      // Wait for school configuration to be initialized
      await _ensureSchoolConfigInitialized();

      print(
          '🏫 Setting up multi-tenant Firebase sync for school: ${_schoolConfig.schoolName.value}');
      print('   School ID: ${_schoolConfig.schoolId.value}');

      // Start periodic sync
      _startPeriodicSync();

      // Set up auth state listeners
      _setupAuthStateListeners();

      print('✅ Automatic sync setup completed');
    } catch (e) {
      print('❌ Failed to setup automatic sync: $e');
    }
  }

  /// Ensure school configuration is initialized before syncing
  Future<void> _ensureSchoolConfigInitialized() async {
    if (!_schoolConfig.isInitialized.value) {
      print('⏳ Waiting for school configuration to initialize...');
      await _schoolConfig.initializeSchoolConfig();
    }

    if (!_schoolConfig.isValidConfiguration()) {
      throw Exception(
          'Invalid school configuration. Cannot proceed with sync.');
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (isOnline.value && !isSyncing.value && firebaseAvailable.value) {
        triggerManualSync();
      }
    });
    print('⏰ Periodic sync started (every 5 minutes)');
  }

  /// Set up auth state listeners
  void _setupAuthStateListeners() {
    _firebaseAuth?.authStateChanges().listen((user) {
      if (user != null) {
        print('🔐 Firebase user signed in, triggering sync...');
        Future.delayed(const Duration(seconds: 2), () {
          triggerManualSync();
        });
      }
    });
  }

  /// Trigger debounced sync (delays sync to avoid rapid successive calls)
  void triggerDebouncedSync({required Duration delay}) {
    _debouncedSyncTimer?.cancel();
    _debouncedSyncTimer = Timer(const Duration(seconds: 3), () {
      if (firebaseAvailable.value && !isSyncing.value && isOnline.value) {
        triggerManualSync();
      }
    });
    print('⏰ Debounced sync scheduled in 3 seconds');
  }

  /// Initialize user-specific sync after authentication
  Future<void> initializeUserSync() async {
    if (!firebaseAvailable.value) {
      print('⚠️ Firebase not available, skipping user sync initialization');
      return;
    }

    try {
      await _ensureSchoolConfigInitialized();
      print(
          '🔐 Initializing user sync for school: ${_schoolConfig.schoolName.value}');

      // Trigger initial sync
      await triggerManualSync();

      print('✅ User sync initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize user sync: $e');
    }
  }

  /// Trigger manual sync
  Future<void> triggerManualSync() async {
    if (isSyncing.value) {
      print('⏳ Sync already in progress, skipping...');
      return;
    }

    if (!firebaseAvailable.value || _firestore == null) {
      print('⚠️ Firestore not available, skipping sync');
      return;
    }

    if (!isOnline.value) {
      print('⚠️ No internet connection, skipping sync');
      return;
    }

    isSyncing.value = true;

    try {
      print('🔄 === STARTING MULTI-TENANT SYNC ===');

      await _ensureSchoolConfigInitialized();

      // Upload local changes
      await _uploadAllTables();

      // Download remote changes
      await _downloadAllTables();

      // Update last sync time
      lastSyncTime.value = DateTime.now();

      print('✅ === MULTI-TENANT SYNC COMPLETED ===');
    } catch (e) {
      print('❌ Sync failed: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  /// Upload all local changes to Firebase
  Future<void> _uploadAllTables() async {
    print('📤 Uploading local changes...');

    for (final table in _syncTables) {
      try {
        await _uploadTableChanges(table);
      } catch (e) {
        print('❌ Error uploading $table: $e');
        // Continue with other tables
      }
    }
  }

  /// Download all remote changes from Firebase
  Future<void> _downloadAllTables() async {
    print('📥 Downloading remote changes...');

    for (final table in _syncTables) {
      try {
        await _downloadTableChanges(table);
      } catch (e) {
        print('❌ Error downloading $table: $e');
        // Continue with other tables
      }
    }
  }

  /// Upload changes for a specific table
  Future<void> _uploadTableChanges(String table) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Get unsynced records
      final unsyncedRecords = await db.query(
        table,
        where: 'firebase_synced IS NULL OR firebase_synced = 0',
      );

      if (unsyncedRecords.isEmpty) {
        print('📊 No unsynced records in $table');
        return;
      }

      print('📤 Uploading ${unsyncedRecords.length} records from $table');

      final schoolPath = _schoolConfig.getCollectionPath(table);
      final collection = _firestore!.collection(schoolPath);

      for (final record in unsyncedRecords) {
        try {
          final data = _convertSqliteToFirestore(record);

          // Add school metadata
          data['school_id'] = _schoolConfig.schoolId.value;
          data['school_name'] = _schoolConfig.schoolName.value;
          data['sync_timestamp'] = FieldValue.serverTimestamp();

          final docRef = collection.doc(record['id'].toString());
          await docRef.set(data, SetOptions(merge: true));

          // Mark as synced
          await db.update(
            table,
            {'firebase_synced': 1},
            where: 'id = ?',
            whereArgs: [record['id']],
          );
        } catch (e) {
          print('❌ Error uploading record ${record['id']}: $e');
        }
      }

      print('✅ Successfully uploaded $table');
    } catch (e) {
      print('❌ Error in _uploadTableChanges for $table: $e');
    }
  }

  /// Download changes for a specific table
  Future<void> _downloadTableChanges(String table) async {
    try {
      final schoolPath = _schoolConfig.getCollectionPath(table);
      final collection = _firestore!.collection(schoolPath);

      // Query only documents for this school
      final query = collection.where('school_id',
          isEqualTo: _schoolConfig.schoolId.value);
      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        print('📊 No documents found in $schoolPath');
        return;
      }

      print(
          '📥 Downloading ${snapshot.docs.length} documents from $schoolPath');

      final db = await DatabaseHelper.instance.database;

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Verify this document belongs to current school
          if (data['school_id'] != _schoolConfig.schoolId.value) {
            print(
                '⚠️ Skipping document ${doc.id} - belongs to different school');
            continue;
          }

          final localData = _convertFirestoreToSqlite(data);

          // Try to update existing record first
          final existingRecords = await db.query(
            table,
            where: 'id = ?',
            whereArgs: [doc.id],
          );

          if (existingRecords.isNotEmpty) {
            await db.update(
              table,
              localData,
              where: 'id = ?',
              whereArgs: [doc.id],
            );
          } else {
            // Insert as new record
            localData['id'] = doc.id;
            await db.insert(table, localData);
          }
        } catch (e) {
          print('❌ Error processing document ${doc.id}: $e');
        }
      }

      print('✅ Successfully downloaded $table');
    } catch (e) {
      print('❌ Error in _downloadTableChanges for $table: $e');
    }
  }

  /// Convert SQLite data to Firestore format
  Map<String, dynamic> _convertSqliteToFirestore(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Remove SQLite-specific fields
    result.remove('firebase_synced');
    result.remove('firebase_uid');

    // Convert timestamps
    if (result['created_at'] is String) {
      try {
        result['created_at'] = DateTime.parse(result['created_at']);
      } catch (e) {
        result['created_at'] = DateTime.now();
      }
    }

    if (result['last_modified'] is int) {
      result['last_modified'] =
          DateTime.fromMillisecondsSinceEpoch(result['last_modified']);
    }

    // Convert specific integer fields back to booleans for Firestore
    final booleanFields = [
      'is_default',
      'status',
      'active',
      'enabled',
      'visible',
      'required',
      'completed',
      'paid',
      'confirmed'
    ];

    for (final field in booleanFields) {
      if (result[field] is int) {
        result[field] = result[field] == 1;
      }
    }

    // Remove null values
    result.removeWhere((key, value) => value == null);

    return result;
  }

  /// Convert Firestore data to SQLite format
  Map<String, dynamic> _convertFirestoreToSqlite(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Remove Firebase-specific fields
    result.remove('school_id');
    result.remove('school_name');
    result.remove('sync_timestamp');

    // Convert timestamps
    if (result['created_at'] is Timestamp) {
      result['created_at'] =
          (result['created_at'] as Timestamp).toDate().toIso8601String();
    }

    if (result['last_modified'] is Timestamp) {
      result['last_modified'] = (result['last_modified'] as Timestamp)
          .toDate()
          .millisecondsSinceEpoch;
    }

    // Convert boolean values to integers for SQLite
    result.forEach((key, value) {
      if (value is bool) {
        result[key] = value ? 1 : 0;
      }
    });

    // Handle nested maps or lists that might contain booleans
    result.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = _convertNestedBooleans(value);
      } else if (value is List) {
        result[key] = _convertListBooleans(value);
      }
    });

    // Mark as synced
    result['firebase_synced'] = 1;

    return result;
  }

  /// Convert booleans in nested maps
  Map<String, dynamic> _convertNestedBooleans(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.forEach((key, value) {
      if (value is bool) {
        result[key] = value ? 1 : 0;
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertNestedBooleans(value);
      } else if (value is List) {
        result[key] = _convertListBooleans(value);
      }
    });
    return result;
  }

  /// Convert booleans in lists
  List<dynamic> _convertListBooleans(List<dynamic> list) {
    return list.map((item) {
      if (item is bool) {
        return item ? 1 : 0;
      } else if (item is Map<String, dynamic>) {
        return _convertNestedBooleans(item);
      } else if (item is List) {
        return _convertListBooleans(item);
      }
      return item;
    }).toList();
  }

  /// Sync a specific collection manually
  Future<void> syncCollection(String localTable,
      {String? firestoreCollection}) async {
    if (!firebaseAvailable.value) {
      print('⚠️ Firebase not available for syncing $localTable');
      return;
    }

    await _ensureSchoolConfigInitialized();

    print('🔄 Syncing collection: $localTable');

    try {
      await _uploadTableChanges(localTable);
      await _downloadTableChanges(localTable);
      print('✅ Successfully synced $localTable');
    } catch (e) {
      print('❌ Error syncing $localTable: $e');
      rethrow;
    }
  }

  /// Create initial shared data for this school
  Future<void> createInitialSharedData() async {
    if (!firebaseAvailable.value) {
      print('⚠️ Firebase not available, skipping initial data creation');
      return;
    }

    await _ensureSchoolConfigInitialized();

    if (_firestore == null) {
      print('⚠️ Firestore not available, skipping initial data creation');
      return;
    }

    try {
      print(
          '📦 Creating initial shared data for school: ${_schoolConfig.schoolName.value}');

      // Create school metadata document
      await _createSchoolMetadata();

      // Create default courses for this school
      await _createDefaultCourses();

      // Create default fleet for this school
      await _createDefaultFleet();

      // Create default currencies for this school
      await _createDefaultCurrencies();

      print(
          '✅ Initial shared data created for school ${_schoolConfig.schoolId.value}');
    } catch (e) {
      print('❌ Error creating initial shared data: $e');
    }
  }

  /// Create school metadata document
  Future<void> _createSchoolMetadata() async {
    try {
      final schoolMetaRef =
          _firestore!.collection('schools').doc(_schoolConfig.schoolId.value);

      final schoolMetadata = {
        'school_id': _schoolConfig.schoolId.value,
        'school_name': _schoolConfig.schoolName.value,
        'business_address':
            Get.find<SettingsController>().businessAddress.value,
        'business_city': Get.find<SettingsController>().businessCity.value,
        'business_country':
            Get.find<SettingsController>().businessCountry.value,
        'business_phone': Get.find<SettingsController>().businessPhone.value,
        'business_email': Get.find<SettingsController>().businessEmail.value,
        'created_at': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      await schoolMetaRef.set(schoolMetadata, SetOptions(merge: true));
      print('✅ School metadata created/updated');
    } catch (e) {
      print('❌ Error creating school metadata: $e');
    }
  }

  /// Create default courses for this school
  Future<void> _createDefaultCourses() async {
    try {
      final coursesPath = _schoolConfig.getCollectionPath('courses');
      final coursesRef = _firestore!.collection(coursesPath);

      // Check if courses already exist for this school
      final existingCourses = await coursesRef.limit(1).get();
      if (existingCourses.docs.isNotEmpty) {
        print(
            '📚 Courses already exist for school ${_schoolConfig.schoolId.value}');
        return;
      }

      final defaultCourses = [
        {
          'name': 'Class 1',
          'price': 15,
          'status': 'Active',
          'created_at': FieldValue.serverTimestamp(),
          'school_id': _schoolConfig.schoolId.value,
          'school_name': _schoolConfig.schoolName.value,
        },
        {
          'name': 'Class 2',
          'price': 9,
          'status': 'Active',
          'created_at': FieldValue.serverTimestamp(),
          'school_id': _schoolConfig.schoolId.value,
          'school_name': _schoolConfig.schoolName.value,
        },
      ];

      for (var course in defaultCourses) {
        await coursesRef.add(course);
      }

      print('✅ Created ${defaultCourses.length} default courses');
    } catch (e) {
      print('❌ Error creating default courses: $e');
    }
  }

  /// Create default fleet for this school
  Future<void> _createDefaultFleet() async {
    try {
      final fleetPath = _schoolConfig.getCollectionPath('fleet');
      final fleetRef = _firestore!.collection(fleetPath);

      // Check if fleet already exists for this school
      final existingFleet = await fleetRef.limit(1).get();
      if (existingFleet.docs.isNotEmpty) {
        print(
            '🚗 Fleet already exists for school ${_schoolConfig.schoolId.value}');
        return;
      }

      final defaultFleet = [
        {
          'carplate': 'SCHOOL-001',
          'make': 'Toyota',
          'model': 'Corolla',
          'modelyear': '2023',
          'status': 'Available',
          'created_at': FieldValue.serverTimestamp(),
          'school_id': _schoolConfig.schoolId.value,
          'school_name': _schoolConfig.schoolName.value,
        },
      ];

      for (var vehicle in defaultFleet) {
        await fleetRef.add(vehicle);
      }

      print('✅ Created ${defaultFleet.length} default fleet vehicles');
    } catch (e) {
      print('❌ Error creating default fleet: $e');
    }
  }

  /// Create default currencies for this school
  Future<void> _createDefaultCurrencies() async {
    try {
      final currenciesPath = _schoolConfig.getCollectionPath('currencies');
      final currenciesRef = _firestore!.collection(currenciesPath);

      // Check if currencies already exist for this school
      final existingCurrencies = await currenciesRef.limit(1).get();
      if (existingCurrencies.docs.isNotEmpty) {
        print(
            '💰 Currencies already exist for school ${_schoolConfig.schoolId.value}');
        return;
      }

      final defaultCurrencies = [
        {
          'name': 'US Dollar',
          'code': 'USD',
          'symbol': '\$',
          'school_id': _schoolConfig.schoolId.value,
          'school_name': _schoolConfig.schoolName.value,
        },
      ];

      for (var currency in defaultCurrencies) {
        await currenciesRef.add(currency);
      }

      print('✅ Created ${defaultCurrencies.length} default currencies');
    } catch (e) {
      print('❌ Error creating default currencies: $e');
    }
  }

  /// Check if sync is needed
  bool get needsSync {
    // Check if enough time has passed since last sync
    final timeSinceLastSync = DateTime.now().difference(lastSyncTime.value);
    return timeSinceLastSync.inMinutes > 5;
  }

  /// Get current sync status as string
  String get syncStatusText {
    if (!firebaseAvailable.value) return 'Firebase unavailable';
    if (!isOnline.value) return 'Offline';
    if (isSyncing.value) return 'Syncing...';
    return 'Ready';
  }

  /// Force a complete re-sync (mark all as unsynced and sync)
  Future<void> forceCompleteSync() async {
    if (!firebaseAvailable.value) {
      print('⚠️ Firebase not available for force sync');
      return;
    }

    print('🔄 Starting forced complete sync...');

    try {
      final db = await DatabaseHelper.instance.database;

      // Mark all records as unsynced
      for (final table in _syncTables) {
        try {
          await db.execute(
              'UPDATE $table SET firebase_synced = 0 WHERE firebase_synced = 1');
          print('📝 Marked $table records as unsynced');
        } catch (e) {
          print('⚠️ Could not mark $table as unsynced: $e');
        }
      }

      // Reset last sync time
      lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(0);

      // Trigger sync
      await triggerManualSync();

      print('✅ Forced complete sync finished');
    } catch (e) {
      print('❌ Error during forced complete sync: $e');
    }
  }

  @override
  void onClose() {
    _periodicSyncTimer?.cancel();
    _debouncedSyncTimer?.cancel();
    super.onClose();
  }
}
