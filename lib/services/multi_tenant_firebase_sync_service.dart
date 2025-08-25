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
  final RxString syncStatus = 'Idle'.obs;
  final RxBool isOnline = false.obs;
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

  Future<void> triggerManualSync() async {
    if (isSyncing.value || !firebaseAvailable.value) {
      print('⚠️ Sync conditions not met - skipping');
      return;
    }

    isSyncing.value = true;
    syncStatus.value = 'Starting sync...';

    try {
      print('🔄 === LOCAL FIRST SYNC STARTED ===');

      // Step 1: Check connectivity
      if (!isOnline.value) {
        throw Exception('No internet connection');
      }

      // Step 2: Push local changes to Firebase FIRST (LOCAL FIRST approach)
      syncStatus.value = 'Uploading local changes...';
      await _pushLocalChangesToFirebase();

      // Step 3: Pull any updates from Firebase
      syncStatus.value = 'Downloading remote changes...';
      await _pullFirebaseChanges();

      lastSyncTime.value = DateTime.now();
      syncStatus.value = 'Sync completed successfully';

      print('✅ === LOCAL FIRST SYNC COMPLETED ===');
    } catch (e) {
      print('❌ Sync failed: $e');
      syncStatus.value = 'Sync failed: ${e.toString()}';
    } finally {
      isSyncing.value = false;
    }
  }

  /// Push local changes to Firebase (LOCAL FIRST priority)
  Future<void> _pushLocalChangesToFirebase() async {
    try {
      print('📤 Pushing local changes to Firebase...');

      final schoolId = _schoolConfig.schoolId.value;
      if (schoolId.isEmpty) {
        throw Exception('No school ID configured');
      }

      // Push users first (highest priority for local-first)
      await _pushUsersToFirebase(schoolId);

      // Push other data
      await _pushLocalChangesToFirebase();

      print('✅ Local changes pushed to Firebase');
    } catch (e) {
      print('❌ Error pushing local changes: $e');
      throw e;
    }
  }

  /// Push users to Firebase with special handling for auth creation
  Future<void> _pushUsersToFirebase(String schoolId) async {
    try {
      print('👥 Pushing local users to Firebase...');

      final db = await DatabaseHelper.instance.database;

      // Get all local users that need syncing
      final localUsers = await db.query(
        'users',
        where: 'firebase_synced = ? OR firebase_synced IS NULL',
        whereArgs: [0],
      );

      print('📤 Found ${localUsers.length} users to sync to Firebase');

      for (final userMap in localUsers) {
        try {
          await _syncSingleUserToFirebase(userMap, schoolId);
        } catch (e) {
          print('❌ Failed to sync user ${userMap['email']}: $e');
          // Continue with other users
        }
      }

      print('✅ Users sync to Firebase completed');
    } catch (e) {
      print('❌ Error pushing users to Firebase: $e');
      throw e;
    }
  }

  /// Sync a single user to Firebase (handles auth + Firestore)
  Future<void> _syncSingleUserToFirebase(
      Map<String, dynamic> userMap, String schoolId) async {
    try {
      final email = userMap['email'] as String;
      final password =
          userMap['password'] as String? ?? 'temppass123'; // Fallback password

      print('🔄 Syncing user to Firebase: $email');

      // Step 1: Ensure user exists in Firebase Auth
      await _ensureFirebaseAuthUser(email, password);

      // Step 2: Save/update user data in Firestore
      final firestoreData = Map<String, dynamic>.from(userMap);
      firestoreData.addAll({
        'last_modified': DateTime.now().toIso8601String(),
        'firebase_synced': 1,
        'school_id': schoolId,
        'local_id': userMap['id'], // Keep reference to local ID
      });
      firestoreData.remove('id'); // Remove for Firestore

      // Check if user already exists in Firestore
      final existingQuery = await _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Update existing
        await existingQuery.docs.first.reference.update(firestoreData);
        print('✅ Updated existing user in Firestore: $email');
      } else {
        // Create new
        await _firestore!
            .collection('schools')
            .doc(schoolId)
            .collection('users')
            .add(firestoreData);
        print('✅ Created new user in Firestore: $email');
      }

      // Step 3: Mark as synced in local database
      await _markLocalRecordAsSynced('users', userMap['id']);
    } catch (e) {
      print('❌ Error syncing single user: $e');
      // Don't throw - we want to continue with other users
    }
  }

  /// Ensure user exists in Firebase Auth (create if needed)
  Future<void> _ensureFirebaseAuthUser(String email, String password) async {
    try {
      // Try to get existing user
      final methods = await _firebaseAuth!.fetchSignInMethodsForEmail(email);

      if (methods.isEmpty) {
        // User doesn't exist, create them
        print('🔥 Creating new Firebase Auth user: $email');
        await _firebaseAuth!.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Firebase Auth user created');
      } else {
        print('ℹ️ Firebase Auth user already exists: $email');
      }
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        print('ℹ️ Firebase Auth user already exists: $email');
      } else {
        print('⚠️ Could not ensure Firebase Auth user: $e');
        // Don't throw - continue with Firestore sync even if auth fails
      }
    }
  }

  /// Pull changes from Firebase to local database
  Future<void> _pullFirebaseChanges() async {
    try {
      print('📥 Pulling changes from Firebase...');

      final schoolId = _schoolConfig.schoolId.value;
      if (schoolId.isEmpty) return;

      // Pull updates for each table
      await _pullTableFromFirebase('users', schoolId);
      await _pullTableFromFirebase('courses', schoolId);
      await _pullTableFromFirebase('schedules', schoolId);
      await _pullTableFromFirebase('invoices', schoolId);
      await _pullTableFromFirebase('payments', schoolId);

      print('✅ Firebase changes pulled successfully');
    } catch (e) {
      print('❌ Error pulling Firebase changes: $e');
      throw e;
    }
  }

  /// Pull specific table from Firebase
  Future<void> _pullTableFromFirebase(String tableName, String schoolId) async {
    try {
      print('📥 Pulling $tableName from Firebase...');

      final firebaseRecords = await _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection(tableName)
          .get();

      final db = await DatabaseHelper.instance.database;
      int updatedCount = 0;

      for (final doc in firebaseRecords.docs) {
        try {
          final firebaseData = doc.data();
          final localId = firebaseData['local_id'];

          if (localId != null) {
            // Check if local record exists and needs updating
            final existingRecord = await db.query(
              tableName,
              where: 'id = ?',
              whereArgs: [localId],
              limit: 1,
            );

            if (existingRecord.isNotEmpty) {
              final localRecord = existingRecord.first;
              final localModified = localRecord['last_modified'] as int? ?? 0;
              final firebaseModified = DateTime.parse(
                      firebaseData['last_modified'] ??
                          DateTime.now().toIso8601String())
                  .millisecondsSinceEpoch;

              if (firebaseModified > localModified) {
                // Firebase data is newer, update local
                final updateData = Map<String, dynamic>.from(firebaseData);
                updateData['id'] = localId;
                updateData['firebase_synced'] = 1;
                updateData.remove('local_id');

                await db.update(
                  tableName,
                  updateData,
                  where: 'id = ?',
                  whereArgs: [localId],
                );
                updatedCount++;
              }
            }
          }
        } catch (e) {
          print('⚠️ Error processing $tableName record: $e');
        }
      }

      print('✅ Updated $updatedCount $tableName records from Firebase');
    } catch (e) {
      print('❌ Error pulling $tableName from Firebase: $e');
    }
  }

  /// Mark local record as synced
  Future<void> _markLocalRecordAsSynced(
      String tableName, dynamic recordId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        tableName,
        {
          'firebase_synced': 1,
          'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [recordId],
      );
    } catch (e) {
      print('⚠️ Could not mark $tableName record $recordId as synced: $e');
    }
  }

  /// Check sync status for users
  Future<Map<String, dynamic>> getSyncStatusSummary() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final totalUsers =
          await db.rawQuery('SELECT COUNT(*) as count FROM users');
      final syncedUsers = await db.rawQuery(
          'SELECT COUNT(*) as count FROM users WHERE firebase_synced = 1');
      final unsyncedUsers = await db.rawQuery(
          'SELECT COUNT(*) as count FROM users WHERE firebase_synced = 0 OR firebase_synced IS NULL');

      return {
        'total_users': totalUsers.first['count'] as int,
        'synced_users': syncedUsers.first['count'] as int,
        'unsynced_users': unsyncedUsers.first['count'] as int,
        'firebase_available': firebaseAvailable.value,
        'last_sync': lastSyncTime.value.toIso8601String(),
        'sync_status': syncStatus.value,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
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

// Replace your _downloadTableChanges method in MultiTenantFirebaseSyncService with this fixed version:

  /// Download changes for a specific table - FIXED to prevent constraint violations
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

          // ✅ FIX: Try to update existing record first, then insert if not exists
          final existingRecords = await db.query(
            table,
            where: 'id = ?',
            whereArgs: [doc.id],
          );

          if (existingRecords.isNotEmpty) {
            // Record exists - update it
            await db.update(
              table,
              localData,
              where: 'id = ?',
              whereArgs: [doc.id],
            );
            print('📝 Updated existing record ${doc.id} in $table');
          } else {
            // Record doesn't exist - insert it
            try {
              localData['id'] = doc.id;
              await db.insert(table, localData);
              print('➕ Inserted new record ${doc.id} in $table');
            } catch (insertError) {
              if (insertError.toString().contains('UNIQUE constraint failed')) {
                // ✅ CONSTRAINT FIX: Use INSERT OR REPLACE as fallback
                print(
                    '⚠️ Constraint violation detected for ${doc.id}, using INSERT OR REPLACE');

                final columns = localData.keys.join(', ');
                final placeholders =
                    List.filled(localData.length, '?').join(', ');

                await db.rawInsert(
                  'INSERT OR REPLACE INTO $table ($columns) VALUES ($placeholders)',
                  localData.values.toList(),
                );
                print(
                    '✅ Successfully used INSERT OR REPLACE for ${doc.id} in $table');
              } else {
                // Re-throw other errors
                rethrow;
              }
            }
          }
        } catch (e) {
          print('❌ Error processing document ${doc.id}: $e');
          // Continue with other documents instead of failing the entire sync
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
    result.remove('firebase_user_id');

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
