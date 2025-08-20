// lib/services/firebase_sync_service.dart - Fixed with proper error handling
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_helper.dart';
import '../controllers/auth_controller.dart';
import 'dart:async';

class FirebaseSyncService extends GetxController {
  static FirebaseSyncService get instance => Get.find<FirebaseSyncService>();

  FirebaseFirestore? _firestore;

  // Observable properties
  final RxBool isOnline = false.obs;
  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Initializing...'.obs;
  final Rx<DateTime> lastSyncTime = DateTime.now().obs;
  final RxBool firebaseAvailable = false.obs;
  final RxString firebaseError = ''.obs;

  // Sync configuration
  final List<String> _syncTables = [
    'users',
    'courses',
    'fleet',
    'schedules',
    'invoices',
    'payments',
    'currencies',
    'settings',
    'attachments',
    'notes',
    'notifications',
    'billing_records',
  ];

  // Tracking
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;

  // Get AuthController
  AuthController get _authController => Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    _initializeSync();
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.onClose();
  }

  /// Initialize sync service with robust error handling
  Future<void> _initializeSync() async {
    try {
      // Test Firebase availability
      print('1. Testing Firebase availability...');
      await _testFirebaseAvailability();

      // Load last sync time
      print('2. Loading last sync time...');
      await _loadLastSyncTime();

      // Monitor connectivity
      print('3. Setting up connectivity monitoring...');
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

      // Check initial connectivity
      print('4. Checking initial connectivity...');
      final connectivityResult = await Connectivity().checkConnectivity();
      _onConnectivityChanged(connectivityResult);

      // Create missing collections if Firebase is available
      if (firebaseAvailable.value) {
        print('5. Creating missing collections...');
        await _createMissingCollections();
      }

      // Set up periodic sync (only if Firebase is available)
      if (firebaseAvailable.value) {
        print('6. Setting up periodic sync...');
        _setupPeriodicSync();
        syncStatus.value = 'Ready';

        // Auto-trigger sync if user is already authenticated
        if (_authController.isFirebaseAuthenticated) {
          print('7. User authenticated, scheduling initial sync...');
          Future.delayed(const Duration(seconds: 2), () {
            triggerManualSync();
          });
        }
      } else {
        syncStatus.value = 'Firebase Unavailable - Offline Mode';
      }

      print(
          '✅ Firebase Sync Service initialized (Firebase Available: ${firebaseAvailable.value})');
    } catch (e, stackTrace) {
      print('❌ Error initializing Firebase Sync Service: $e');
      print('📋 Stack trace: $stackTrace');
      _handleFirebaseError(e);
    }
  }

  /// Test Firebase availability
  Future<void> _testFirebaseAvailability() async {
    try {
      _firestore = FirebaseFirestore.instance;

      // Test basic Firestore operation
      await _firestore!.settings.persistenceEnabled;

      firebaseAvailable.value = true;
      firebaseError.value = '';
      print('✅ Firebase Firestore is available');
    } catch (e) {
      print('❌ Firebase availability test failed: $e');
      _handleFirebaseError(e);
    }
  }

  /// Handle Firebase errors gracefully
  void _handleFirebaseError(dynamic error) {
    firebaseAvailable.value = false;

    String errorMessage = 'Firebase unavailable';

    if (error is PlatformException) {
      if (error.code == 'channel-error') {
        errorMessage = 'Firebase platform connection failed';
      } else if (error.code == 'permission-denied') {
        errorMessage = 'Firebase permission denied - check security rules';
      } else {
        errorMessage = 'Firebase platform error: ${error.message}';
      }
    } else if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        errorMessage = 'Firebase permission denied - check security rules';
      } else {
        errorMessage = 'Firebase error: ${error.message}';
      }
    } else {
      errorMessage = 'Firebase error: ${error.toString()}';
    }

    firebaseError.value = errorMessage;
    syncStatus.value = 'Offline Mode - $errorMessage';
    print('🔥 Firebase Sync Error: $errorMessage');
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasOnline = isOnline.value;
    isOnline.value = result != ConnectivityResult.none;

    print('🌐 Connectivity changed: $result (Online: ${isOnline.value})');

    if (isOnline.value && !wasOnline && firebaseAvailable.value) {
      print('🌐 Connection restored - testing Firebase and triggering sync');
      syncStatus.value = 'Connection restored';
      _testFirebaseAndSync();
    } else if (!isOnline.value && wasOnline) {
      print('📴 Connection lost');
      syncStatus.value = 'Offline';
    } else if (isOnline.value && !firebaseAvailable.value) {
      print('🌐 Connection available but Firebase unavailable');
      syncStatus.value = 'Online - Firebase Unavailable';
    }
  }

  /// Test Firebase and trigger sync if available
  Future<void> _testFirebaseAndSync() async {
    try {
      await _testFirebaseAvailability();
      if (firebaseAvailable.value && _shouldSync()) {
        _triggerSync();
      }
    } catch (e) {
      print('❌ Error testing Firebase after connection restore: $e');
    }
  }

  /// Setup periodic background sync
  void _setupPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (isOnline.value &&
          !isSyncing.value &&
          firebaseAvailable.value &&
          _shouldSync()) {
        print('⏰ Periodic sync triggered');
        _triggerSync();
      }
    });
  }

  /// Check if sync should run
  bool _shouldSync() {
    // Only sync if Firebase is available and user is authenticated
    if (!firebaseAvailable.value || !_authController.isFirebaseAuthenticated) {
      print(
          '⚠️ Sync skipped - Firebase: ${firebaseAvailable.value}, Auth: ${_authController.isFirebaseAuthenticated}');
      return false;
    }

    // Sync every 5 minutes minimum
    final timeSinceLastSync = DateTime.now().difference(lastSyncTime.value);
    final shouldSync = timeSinceLastSync.inMinutes >= 5;

    print(
        '⏰ Sync check - Last sync: ${timeSinceLastSync.inMinutes}m ago, Should sync: $shouldSync');
    return shouldSync;
  }

  /// Get the correct collection path based on table type
  String _getCorrectCollectionPath(String table) {
    // Shared collections (available to all users)
    final sharedCollections = [
      'courses',
      'fleet',
      'currencies',
      'settings',
      'reminders'
    ];

    // User-specific collections (private to each user)
    final userCollections = [
      'users',
      'schedules',
      'invoices',
      'payments',
      'attachments',
      'notes',
      'notifications',
      'billing_records',
      'timeline',
      'usermessages'
    ];

    if (sharedCollections.contains(table)) {
      // Use flat structure at root level (matches your Firestore)
      return table;
    } else if (userCollections.contains(table)) {
      final firebaseUserId = _authController.currentFirebaseUserId;
      if (firebaseUserId == null) {
        throw Exception('User not authenticated with Firebase');
      }
      // Use flat structure: collection name directly (matches your Firestore)
      return table;
    } else {
      // Default to user-specific for unknown tables
      final firebaseUserId = _authController.currentFirebaseUserId;
      if (firebaseUserId == null) {
        throw Exception('User not authenticated with Firebase');
      }
      return table;
    }
  }

  /// Trigger manual sync
  Future<void> triggerManualSync() async {
    print('\n🔄 === MANUAL SYNC TRIGGERED ===');

    if (!isOnline.value) {
      print('❌ No internet connection');
      Get.snackbar(
        'Sync Error',
        'No internet connection available',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    if (!firebaseAvailable.value) {
      print('❌ Firebase not available');
      Get.snackbar(
        'Sync Error',
        'Firebase services are currently unavailable',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    if (!_authController.isFirebaseAuthenticated) {
      print('❌ User not authenticated with Firebase');
      Get.snackbar(
        'Sync Error',
        'Please enable cloud sync in settings',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        onTap: (_) => _authController.forceFirebaseAuthentication(),
      );
      return;
    }

    print('✅ Pre-sync checks passed');
    await _triggerSync();
  }

  /// Ensure sync tracking columns exist
  Future<void> _ensureSyncTracking() async {
    print('🔧 Ensuring sync tracking columns exist...');

    final db = await DatabaseHelper.instance.database;

    for (String table in _syncTables) {
      try {
        // Check if sync columns exist
        final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
        final columnNames =
            tableInfo.map((row) => row['name'] as String).toSet();

        bool hasLastModified = columnNames.contains('last_modified');
        bool hasFirebaseSynced = columnNames.contains('firebase_synced');

        if (!hasLastModified) {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN last_modified INTEGER DEFAULT 0');
          print('✅ Added last_modified to $table');
        }

        if (!hasFirebaseSynced) {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN firebase_synced INTEGER DEFAULT 0');
          print('✅ Added firebase_synced to $table');
        }

        // Mark existing records as needing sync if this is first time
        if (!hasLastModified || !hasFirebaseSynced) {
          await db.execute('''
            UPDATE $table 
            SET last_modified = ${DateTime.now().toUtc().millisecondsSinceEpoch}, 
                firebase_synced = 0 
            WHERE last_modified IS NULL OR last_modified = 0
          ''');
          print('✅ Marked existing $table records for sync');
        }
      } catch (e) {
        print('⚠️ Error setting up sync tracking for $table: $e');
      }
    }
  }

  /// Create initial shared data in Firebase
  Future<void> _createInitialSharedData() async {
    if (_firestore == null) return;

    try {
      print('📦 Creating initial shared data in Firebase...');

      // Create default courses (using root-level collections)
      final coursesRef = _firestore!.collection('courses');
      final coursesSnapshot = await coursesRef.limit(1).get();

      if (coursesSnapshot.docs.isEmpty) {
        final defaultCourses = [
          {
            'name': 'Beginner Driving Course',
            'price': 300,
            'status': 'Active',
            'created_at': FieldValue.serverTimestamp(),
            'description': 'Basic driving skills and road safety',
            'duration': '2 months',
            'lessons_included': 10
          },
          // ... rest of your default courses
        ];

        for (var course in defaultCourses) {
          await coursesRef.add(course);
        }
        print('✅ Created default courses');
      }

      // Create default fleet vehicles (using root-level collections)
      final fleetRef = _firestore!.collection('fleet');
      final fleetSnapshot = await fleetRef.limit(1).get();

      if (fleetSnapshot.docs.isEmpty) {
        final defaultFleet = [
          {
            'carplate': 'ABC123',
            'make': 'Toyota',
            'model': 'Corolla',
            'modelyear': '2023',
            'status': 'Available',
            'created_at': FieldValue.serverTimestamp(),
            'color': 'White',
            'transmission': 'Automatic'
          },
          // ... rest of your default fleet
        ];

        for (var vehicle in defaultFleet) {
          await fleetRef.add(vehicle);
        }
        print('✅ Created default fleet vehicles');
      }

      // Create default currencies (using root-level collections)
      final currenciesRef = _firestore!.collection('currencies');
      final currenciesSnapshot = await currenciesRef.limit(1).get();

      if (currenciesSnapshot.docs.isEmpty) {
        final defaultCurrencies = [
          {
            'name': 'US Dollar',
            'code': 'USD',
            'symbol': '\$',
            'created_at': FieldValue.serverTimestamp(),
            'is_default': true
          },
          // ... rest of your default currencies
        ];

        for (var currency in defaultCurrencies) {
          await currenciesRef.add(currency);
        }
        print('✅ Created default currencies');
      }

      print('✅ Initial shared data creation completed');
    } catch (e) {
      print('❌ Error creating initial shared data: $e');
    }
  }

  /// Sync shared data across all users
  Future<void> _syncSharedData() async {
    if (_firestore == null) return;

    try {
      print('🔄 Syncing shared data across all users...');

      // Sync shared tables that should be available to all users
      final sharedTables = ['courses', 'fleet', 'currencies', 'settings'];

      for (String table in sharedTables) {
        try {
          // Download shared data from root-level collection (matches your Firestore)
          final sharedCollection = _firestore!.collection(table);
          final snapshot = await sharedCollection.get();

          if (snapshot.docs.isNotEmpty) {
            print(
                '📥 Downloading shared $table data: ${snapshot.docs.length} records');
            await _mergeDownloadedRecords(table, snapshot.docs);
          } else {
            print('📭 No shared $table data found in Firebase');
          }
        } catch (e) {
          print('❌ Error syncing shared $table: $e');
        }
      }
    } catch (e) {
      print('❌ Error in shared data sync: $e');
    }
  }

  /// Upload local changes to Firebase with comprehensive logging
  Future<void> _uploadLocalChanges() async {
    if (_firestore == null) {
      throw Exception('Firestore not available');
    }

    final db = await DatabaseHelper.instance.database;
    int totalUploaded = 0;

    for (String table in _syncTables) {
      try {
        print('📤 Processing table: $table');

        // Get unsynced records
        final unsyncedRecords = await db.query(
          table,
          where: 'firebase_synced = ? OR firebase_synced IS NULL',
          whereArgs: [0],
        );

        print('📊 Found ${unsyncedRecords.length} unsynced records in $table');

        if (unsyncedRecords.isNotEmpty) {
          await _uploadTableRecords(table, unsyncedRecords);
          totalUploaded += unsyncedRecords.length;
        }
      } catch (e) {
        print('❌ Error uploading $table: $e');
        // Continue with other tables
      }
    }

    print('📤 Upload phase complete. Total uploaded: $totalUploaded records');
  }

  /// Alternative: Use separate queries to avoid composite index
  Future<int> _downloadTableChangesSeparateQueries(String table) async {
    if (_firestore == null) {
      throw Exception('Firestore not available');
    }

    try {
      final collectionPath = _getCorrectCollectionPath(table);
      final collection = _firestore!.collection(collectionPath);

      final userSpecificTables = [
        'users',
        'schedules',
        'invoices',
        'payments',
        'attachments',
        'notes',
        'notifications',
        'billing_records'
      ];

      List<QueryDocumentSnapshot> allDocs = [];

      if (userSpecificTables.contains(table)) {
        final userId = _authController.currentFirebaseUserId;
        if (userId != null) {
          // Query 1: Get user records modified since last sync
          if (lastSyncTime.value.millisecondsSinceEpoch > 0) {
            final recentQuery = collection
                .where('user_id', isEqualTo: userId)
                .orderBy('last_modified')
                .startAfter([Timestamp.fromDate(lastSyncTime.value)]);

            final recentSnapshot = await recentQuery.get();
            allDocs.addAll(recentSnapshot.docs);

            print(
                '📥 Found ${recentSnapshot.docs.length} recent $table records for user');
          } else {
            // First sync: get all user records
            final allUserQuery = collection.where('user_id', isEqualTo: userId);
            final allUserSnapshot = await allUserQuery.get();
            allDocs.addAll(allUserSnapshot.docs);

            print(
                '📥 First sync: found ${allUserSnapshot.docs.length} total $table records for user');
          }
        }
      } else {
        // Shared data - get all records modified since last sync
        Query query = collection;

        if (lastSyncTime.value.millisecondsSinceEpoch > 0) {
          query = query.where('last_modified',
              isGreaterThan: Timestamp.fromDate(lastSyncTime.value));
        }

        final snapshot = await query.get();
        allDocs.addAll(snapshot.docs);

        print(
            '📥 Found ${snapshot.docs.length} modified shared $table records');
      }

      if (allDocs.isNotEmpty) {
        await _mergeDownloadedRecords(table, allDocs);
      }

      return allDocs.length;
    } catch (e) {
      print('❌ Error downloading $table changes: $e');
      return 0;
    }
  }

  /// Handle record deletions from other devices
  Future<void> _handleRecordDeletion(String table, String docId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localId = int.tryParse(docId);

      if (localId != null) {
        await db.delete(
          table,
          where: 'id = ?',
          whereArgs: [localId],
        );
        print('🗑️ Deleted record $localId from $table (remote deletion)');
      }
    } catch (e) {
      print('❌ Error handling deletion for $table record $docId: $e');
    }
  }

  /// Mark records as synced in local database
  Future<void> _markRecordsAsSynced(
      String table, List<Map<String, dynamic>> records) async {
    final db = await DatabaseHelper.instance.database;

    for (final record in records) {
      try {
        await db.update(
          table,
          {'firebase_synced': 1},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
      } catch (e) {
        print('Could not mark $table record as synced: $e');
      }
    }
  }

  /// Initialize sync for a new user (called after Firebase authentication)
  Future<void> initializeUserSync() async {
    print('🎯 Initializing user sync...');

    if (!firebaseAvailable.value) {
      print('⚠️ Cannot initialize sync - Firebase not available');
      return;
    }

    if (!_authController.isFirebaseAuthenticated) {
      print('⚠️ Cannot initialize sync - user not authenticated with Firebase');
      return;
    }

    try {
      print(
          '🔄 Initializing sync for user: ${_authController.currentFirebaseUserId}');

      // Ensure sync tracking is set up
      await _ensureSyncTracking();

      // Create initial shared data if it doesn't exist
      await _createInitialSharedData();

      // Start real-time listeners
      listenToRealtimeChanges();

      // Trigger initial sync
      Future.delayed(const Duration(seconds: 1), () {
        triggerManualSync();
      });

      print('✅ User sync initialized successfully');
    } catch (e) {
      print('❌ Error initializing user sync: $e');
    }
  }

  /// Force full sync for initial setup or data recovery
  Future<void> forceFullSync() async {
    print('🔄 Force full sync requested');

    if (!isOnline.value) {
      Get.snackbar(
        'Sync Error',
        'No internet connection available',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    if (!firebaseAvailable.value) {
      // Try to re-test Firebase availability
      await _testFirebaseAvailability();
      if (!firebaseAvailable.value) {
        Get.snackbar(
          'Sync Error',
          'Firebase services are unavailable: ${firebaseError.value}',
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
        return;
      }
    }

    if (!_authController.isFirebaseAuthenticated) {
      await _authController.forceFirebaseAuthentication();
      if (!_authController.isFirebaseAuthenticated) {
        return;
      }
    }

    try {
      isSyncing.value = true;
      syncStatus.value = 'Full Sync in Progress...';

      // Reset last sync time to force full sync
      lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(0);

      await _triggerSync();

      Get.snackbar(
        'Full Sync Complete',
        'All data has been synchronized',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
      );
    } catch (e) {
      print('Full sync error: $e');
      Get.snackbar(
        'Full Sync Error',
        'Failed to perform full sync: ${e.toString()}',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// Reset and resync all data
  Future<void> resetAndResync() async {
    print('🔄 Reset and resync requested');

    if (!firebaseAvailable.value) {
      await _testFirebaseAvailability();
      if (!firebaseAvailable.value) {
        Get.snackbar(
          'Sync Error',
          'Firebase services are unavailable',
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
        return;
      }
    }

    if (!_authController.isFirebaseAuthenticated) {
      await _authController.forceFirebaseAuthentication();
      if (!_authController.isFirebaseAuthenticated) {
        return;
      }
    }

    try {
      isSyncing.value = true;
      syncStatus.value = 'Resetting sync...';

      // Mark all local records as unsynced
      final db = await DatabaseHelper.instance.database;
      for (String table in _syncTables) {
        await db.execute(
            'UPDATE $table SET firebase_synced = 0 WHERE firebase_synced = 1');
        print('🔄 Marked all $table records as unsynced');
      }

      // Reset sync time
      lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(0);

      // Trigger full sync
      await _triggerSync();

      Get.snackbar(
        'Reset Complete',
        'Data sync has been reset and re-synchronized',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
      );
    } catch (e) {
      print('Reset and resync error: $e');
      Get.snackbar(
        'Reset Error',
        'Failed to reset sync: ${e.toString()}',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'isOnline': isOnline.value,
      'isSyncing': isSyncing.value,
      'syncStatus': syncStatus.value,
      'lastSyncTime': lastSyncTime.value,
      'firebaseAvailable': firebaseAvailable.value,
      'firebaseError': firebaseError.value,
      'isFirebaseAuthenticated': _authController.isFirebaseAuthenticated,
      'currentUser': _authController.currentUser.value?.email,
      'firebaseUserId': _authController.currentFirebaseUserId,
      'syncTables': _syncTables,
    };
  }

  /// Save last sync time to SharedPreferences
  Future<void> _saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_sync_time', lastSyncTime.value.millisecondsSinceEpoch);
  }

  /// Load last sync time from SharedPreferences
  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getInt('last_sync_time') ?? 0;
    if (savedTime > 0) {
      lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(savedTime);
    }
  }

  /// Format sync time for display
  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Test Firebase connection and show result
  Future<void> testFirebaseConnection() async {
    try {
      await _testFirebaseAvailability();

      if (firebaseAvailable.value) {
        Get.snackbar(
          'Firebase Available',
          'Firebase connection is working properly',
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
      } else {
        Get.snackbar(
          'Firebase Unavailable',
          firebaseError.value.isNotEmpty
              ? firebaseError.value
              : 'Firebase connection failed',
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Firebase Test Failed',
        'Error testing Firebase: ${e.toString()}',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }

  /// Auto-create missing Firestore collections with initial data
  Future<void> _createMissingCollections() async {
    if (_firestore == null) return;

    final collectionsToCheck = [
      'courses',
      'fleet',
      'invoices',
      'payments',
      'currencies',
      'settings',
      'attachments',
      'notes',
      'notifications',
      'billing_records',
    ];

    print('🔄 Checking Firestore collections...');

    for (final collectionName in collectionsToCheck) {
      try {
        // Check if collection exists by trying to read one document
        final snapshot =
            await _firestore!.collection(collectionName).limit(1).get();

        if (snapshot.docs.isEmpty) {
          // Collection exists but is empty - add initial document
          await _firestore!.collection(collectionName).doc('init').set({
            'created_at': FieldValue.serverTimestamp(),
            'type': 'initialization_record',
            'message': 'Auto-created during sync initialization'
          });
          print('✅ Added initial document to: $collectionName');
        } else {
          print('✅ Collection already has data: $collectionName');
        }
      } catch (e) {
        // If we get a "not found" or permission error, try to create
        if (e.toString().contains('permission-denied') ||
            e.toString().contains('Invalid argument')) {
          try {
            // Create collection by adding a document
            await _firestore!.collection(collectionName).doc('init').set({
              'created_at': FieldValue.serverTimestamp(),
              'type': 'initialization_record',
              'message': 'Auto-created during sync initialization'
            });
            print('✅ Created collection: $collectionName');
          } catch (createError) {
            print('❌ Failed to create $collectionName: $createError');
          }
        } else {
          print('⚠️ Error checking $collectionName: $e');
        }
      }
    }
  }

  /// Get device identifier with better tracking
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    String? deviceName = prefs.getString('device_name');

    if (deviceId == null) {
      deviceId = 'device_${DateTime.now().toUtc().millisecondsSinceEpoch}';
      await prefs.setString('device_id', deviceId);

      // Get device name
      deviceName = await _getDeviceName();
      await prefs.setString('device_name', deviceName);
    }

    return deviceId;
  }

  /// Get device name for better tracking
  Future<String> _getDeviceName() async {
    try {
      // Use a simpler approach without external packages
      final prefs = await SharedPreferences.getInstance();
      String? deviceName = prefs.getString('device_name');

      if (deviceName == null) {
        // Create a simple device identifier
        deviceName =
            'Device-${DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000}';
        await prefs.setString('device_name', deviceName);
      }

      return deviceName;
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Enhanced device tracking for multi-device sync
  Future<void> _updateDeviceTracking() async {
    try {
      if (!_authController.isFirebaseAuthenticated || _firestore == null) {
        print(
            '⚠️ Cannot update device tracking - not authenticated or Firestore unavailable');
        return;
      }

      final deviceId = await _getDeviceId();
      final deviceName = await _getDeviceName();
      final userId = _authController.currentFirebaseUserId;

      if (userId != null) {
        await _firestore!.collection('user_devices').doc(userId).set({
          'devices': FieldValue.arrayUnion([
            {
              'device_id': deviceId,
              'device_name': deviceName,
              'last_seen': FieldValue.serverTimestamp(),
              'last_sync': FieldValue.serverTimestamp(),
            }
          ])
        }, SetOptions(merge: true));

        print('📱 Device tracking updated: $deviceName ($deviceId)');
      }
    } catch (e) {
      print('⚠️ Could not update device tracking: $e');
      // Don't rethrow - this is non-critical functionality
    }
  }

  /// Listen to real-time changes for instant multi-device sync
  /// Listen to real-time changes with proper error handling
  void listenToRealtimeChanges() {
    if (_firestore == null) {
      print('⚠️ Firestore not available for real-time listeners');
      return;
    }

    print('👂 Setting up real-time listeners for multi-device sync...');

    // Listen to user-specific collections
    final userSpecificTables = [
      'schedules',
      'invoices',
      'payments',
      'attachments',
      'notes',
      'notifications',
      'billing_records'
    ];

    for (final table in userSpecificTables) {
      try {
        final userId = _authController.currentFirebaseUserId;
        if (userId == null) {
          print(
              '⚠️ User not authenticated, skipping real-time listener for $table');
          continue;
        }

        final collection = _firestore!.collection(table);

        print('🔧 Setting up listener for $table...');

        collection.where('user_id', isEqualTo: userId).snapshots().listen(
            (snapshot) {
          if (!isSyncing.value) {
            print(
                '🔔 Real-time change detected in $table: ${snapshot.docChanges.length} changes');
            _handleRealtimeChanges(table, snapshot);
          }
        }, onError: (error) {
          print('❌ Real-time listener error for $table: $error');
          // Don't throw, just log the error
        }, cancelOnError: false // Prevent listener from stopping on error
            );

        print('✅ Real-time listener active for $table');
      } catch (e) {
        print('❌ Error setting up real-time listener for $table: $e');
        // Continue with other tables instead of crashing
      }
    }
  }

  /// Debug what data exists locally and in Firebase
  Future<void> debugDataFlow() async {
    print('\n🔍 === COMPREHENSIVE DATA DEBUG ===');

    await debugLocalData();
    await debugFirebaseData();
    await debugSyncStatus();

    print('🔍 === END COMPREHENSIVE DEBUG ===\n');
  }

  /// Debug local data in SQLite
  Future<void> debugLocalData() async {
    print('\n📱 LOCAL DATABASE DEBUG:');

    final db = await DatabaseHelper.instance.database;
    final userSpecificTables = [
      'users',
      'schedules',
      'invoices',
      'payments',
      'attachments',
      'notes',
      'notifications',
      'billing_records'
    ];

    for (String table in userSpecificTables) {
      try {
        // Check total records
        final totalResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $table 
        WHERE deleted IS NULL OR deleted = 0
      ''');
        final total = totalResult.first['count'] as int;

        // Check unsynced records
        final unsyncedResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $table 
        WHERE (deleted IS NULL OR deleted = 0) 
        AND (firebase_synced IS NULL OR firebase_synced = 0)
      ''');
        final unsynced = unsyncedResult.first['count'] as int;

        print('  📊 $table: $total total, $unsynced unsynced');

        // Check if user_id column exists and sample data
        if (total > 0) {
          try {
            final sampleResult = await db.rawQuery('''
            SELECT id, firebase_user_id, firebase_synced, created_at 
            FROM $table 
            WHERE deleted IS NULL OR deleted = 0 
            LIMIT 3
          ''');

            print('    Sample records:');
            for (var record in sampleResult) {
              print(
                  '      ID: ${record['id']}, firebase_user_id: ${record['firebase_user_id'] ?? 'NULL'}, synced: ${record['firebase_synced']}');
            }
          } catch (e) {
            print('    ❌ Error getting sample data: $e');
          }
        } else {
          print('    📭 No records found');
        }
      } catch (e) {
        print('  ❌ $table: Error - $e');
      }
    }
  }

  /// Debug Firebase data
  Future<void> debugFirebaseData() async {
    if (_firestore == null) {
      print('\n❌ FIREBASE DEBUG: Firestore not available');
      return;
    }

    print('\n☁️ FIREBASE DATABASE DEBUG:');

    final userId = _authController.currentFirebaseUserId;
    print('🔑 Searching for firebase_user_id: $userId');

    final userSpecificTables = [
      'users',
      'schedules',
      'invoices',
      'payments',
      'attachments',
      'notes',
      'notifications',
      'billing_records'
    ];

    for (String table in userSpecificTables) {
      try {
        // Check total documents in collection
        final totalSnapshot =
            await _firestore!.collection(table).limit(10).get();
        print('  📊 $table: ${totalSnapshot.docs.length} total documents');

        if (totalSnapshot.docs.isNotEmpty) {
          print('    Sample document user_ids:');
          for (var doc in totalSnapshot.docs.take(3)) {
            final data = doc.data();
            print(
                '      Doc ${doc.id}: firebase_user_id = ${data['firebase_user_id'] ?? 'NOT SET'}');
          }
        }

        // Check documents for your specific user
        if (userId != null) {
          final userSnapshot = await _firestore!
              .collection(table)
              .where('firebase_user_id', isEqualTo: userId)
              .limit(10)
              .get();

          print(
              '    🎯 Documents for your user ($userId): ${userSnapshot.docs.length}');

          if (userSnapshot.docs.isNotEmpty) {
            for (var doc in userSnapshot.docs.take(3)) {
              final data = doc.data();
              print(
                  '      Your doc ${doc.id}: created_at = ${data['created_at']}, last_modified = ${data['last_modified']}');
            }
          }
        }
      } catch (e) {
        print('  ❌ $table: Error - $e');
      }
    }
  }

  /// Debug sync status for each table
  Future<void> debugSyncStatus() async {
    print('\n🔄 SYNC STATUS DEBUG:');

    final db = await DatabaseHelper.instance.database;
    final userSpecificTables = [
      'users',
      'schedules',
      'invoices',
      'payments',
      'attachments',
      'notes',
      'notifications',
      'billing_records'
    ];

    print('Last Sync Time: ${lastSyncTime.value}');
    print('Is Syncing: ${isSyncing.value}');
    print('Is Online: ${isOnline.value}');
    print('Firebase Available: ${firebaseAvailable.value}');

    for (String table in userSpecificTables) {
      try {
        // Check records that should be uploaded
        final toUploadResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $table 
        WHERE (deleted IS NULL OR deleted = 0) 
        AND (firebase_synced IS NULL OR firebase_synced = 0)
      ''');
        final toUpload = toUploadResult.first['count'] as int;

        // Check records that are synced
        final syncedResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $table 
        WHERE (deleted IS NULL OR deleted = 0) 
        AND firebase_synced = 1
      ''');
        final synced = syncedResult.first['count'] as int;

        print('  📤 $table: $toUpload to upload, $synced synced');
      } catch (e) {
        print('  ❌ $table: Error - $e');
      }
    }
  }

  /// Force upload all local data (for testing)
  Future<void> forceUploadAllLocalData() async {
    print('\n🚀 FORCE UPLOADING ALL LOCAL DATA...');

    // Mark all records as unsynced
    await markAllRecordsAsUnsynced();

    // Trigger sync
    await triggerManualSync();

    print('🚀 Force upload complete');
  }

  /// Mark all records as unsynced (helper method)
  Future<void> markAllRecordsAsUnsynced() async {
    print('🔧 Marking all records as unsynced...');

    final db = await DatabaseHelper.instance.database;

    for (String table in _syncTables) {
      try {
        await db.execute('''
        UPDATE $table 
        SET firebase_synced = 0, 
            last_modified = ${DateTime.now().toUtc().millisecondsSinceEpoch}
      ''');
        print('✅ Marked all $table records as unsynced');
      } catch (e) {
        print('❌ Error marking $table: $e');
      }
    }

    // Reset sync time to force full sync
    lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(0);
    await _saveLastSyncTime();
  }

  /// Updated download method to filter by firebase_user_id (Firebase) and map to firebase_user_id (local)
  Future<int> _downloadTableChanges(String table) async {
    if (_firestore == null) {
      throw Exception('Firestore not available');
    }

    try {
      final collectionPath = _getCorrectCollectionPath(table);
      final collection = _firestore!.collection(collectionPath);

      Query query = collection;

      // For user-specific data, only download records belonging to current user
      final userSpecificTables = [
        'users',
        'schedules',
        'invoices',
        'payments',
        'attachments',
        'notes',
        'notifications',
        'billing_records'
      ];

      if (userSpecificTables.contains(table)) {
        final userId = _authController.currentFirebaseUserId;
        if (userId != null) {
          // Filter by firebase_user_id in Firebase (which stores the Firebase UID)
          query = query.where('firebase_user_id', isEqualTo: userId);
          print('📥 Filtering $table for user: $userId');
        }
      }

      print('📥 Downloading all $table records and filtering locally');

      final snapshot = await query.get();
      print('📥 Downloaded ${snapshot.docs.length} total records from $table');

      // Filter by last_modified locally to avoid needing composite index
      final filteredDocs = <QueryDocumentSnapshot>[];

      if (lastSyncTime.value.millisecondsSinceEpoch > 0) {
        final lastSyncTimestamp = Timestamp.fromDate(lastSyncTime.value);

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final docLastModified = data['last_modified'];

          if (docLastModified is Timestamp) {
            if (docLastModified.compareTo(lastSyncTimestamp) > 0) {
              filteredDocs.add(doc);
            }
          } else {
            // If no last_modified or invalid format, include it
            filteredDocs.add(doc);
          }
        }

        print(
            '📥 Found ${filteredDocs.length} records modified since ${lastSyncTime.value}');
      } else {
        // First sync - take all records
        filteredDocs.addAll(snapshot.docs);
        print('📥 First sync - taking all ${filteredDocs.length} records');
      }

      if (filteredDocs.isNotEmpty) {
        await _mergeDownloadedRecords(table, filteredDocs);
      }

      return filteredDocs.length;
    } catch (e) {
      print('❌ Error downloading $table changes: $e');
      return 0;
    }
  }

  /// Force complete bidirectional sync
  Future<void> forceCompleteSync() async {
    print('\n🚀 === FORCING COMPLETE SYNC ===');

    try {
      final syncService = Get.find<FirebaseSyncService>();
      final authController = Get.find<AuthController>();

      // Check prerequisites
      if (!authController.isLoggedIn.value) {
        print('❌ Not logged in locally');
        return;
      }

      if (!authController.isFirebaseAuthenticated) {
        print('❌ Not authenticated with Firebase');
        return;
      }

      if (!syncService.isOnline.value) {
        print('❌ Not online');
        return;
      }

      print('✅ Prerequisites met - starting sync');
      print('🔑 Firebase User ID: ${authController.currentFirebaseUserId}');

      // Step 1: Reset sync time to force full sync
      print('🔄 Step 1: Resetting sync time for full sync');
      syncService.lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(0);

      // Step 2: Mark all local records as unsynced to force upload
      print('🔄 Step 2: Marking all records for upload');
      await markAllLocalRecordsForSync();

      // Step 3: Trigger manual sync
      print('🔄 Step 3: Triggering manual sync');
      await syncService.triggerManualSync();

      // Step 4: Verify results
      print('🔄 Step 4: Verifying sync results');
      await Future.delayed(Duration(seconds: 5)); // Wait for sync to complete
      await verifySyncResults();

      print('🚀 === COMPLETE SYNC FINISHED ===');
    } catch (e) {
      print('❌ Error during complete sync: $e');
    }
  }

  /// Mark all local records as needing sync
  Future<void> markAllLocalRecordsForSync() async {
    final db = await DatabaseHelper.instance.database;

    final tables = [
      'users',
      'schedules',
      'invoices',
      'payments',
      'attachments',
      'notes',
      'notifications',
      'billing_records'
    ];

    for (String table in tables) {
      try {
        await db.execute('''
        UPDATE $table 
        SET firebase_synced = 0, 
            last_modified = ?
        WHERE firebase_user_id IS NOT NULL
      ''', [DateTime.now().toUtc().millisecondsSinceEpoch]);

        print('  ✅ Marked $table records for sync');
      } catch (e) {
        print('  ❌ Error marking $table: $e');
      }
    }
  }

  /// Verify sync results
  Future<void> verifySyncResults() async {
    final db = await DatabaseHelper.instance.database;

    print('\n📊 === SYNC VERIFICATION ===');

    final tables = ['users', 'schedules', 'invoices', 'payments'];

    for (String table in tables) {
      try {
        // Check local synced records
        final syncedResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $table 
        WHERE firebase_synced = 1 AND firebase_user_id IS NOT NULL
      ''');
        final synced = syncedResult.first['count'] as int;

        // Check local unsynced records
        final unsyncedResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $table 
        WHERE firebase_synced = 0 AND firebase_user_id IS NOT NULL
      ''');
        final unsynced = unsyncedResult.first['count'] as int;

        // Check total local records
        final totalResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $table 
        WHERE firebase_user_id IS NOT NULL
      ''');
        final total = totalResult.first['count'] as int;

        print('  📊 $table: $total total, $synced synced, $unsynced unsynced');

        if (unsynced > 0) {
          print(
              '    ⚠️ Still has unsynced records - sync may not have completed');
        } else if (synced > 0) {
          print('    ✅ All records synced successfully');
        }
      } catch (e) {
        print('  ❌ Error checking $table: $e');
      }
    }

    print('📊 === END VERIFICATION ===\n');
  }

  /// Debug what's happening during sync
  Future<void> debugSyncProcess() async {
    print('\n🔍 === DEBUGGING SYNC PROCESS ===');

    final syncService = Get.find<FirebaseSyncService>();

    print('📊 Sync Service Status:');
    print('  Is Syncing: ${syncService.isSyncing.value}');
    print('  Is Online: ${syncService.isOnline.value}');
    print('  Firebase Available: ${syncService.firebaseAvailable.value}');
    print('  Sync Status: ${syncService.syncStatus.value}');
    print('  Last Sync: ${syncService.lastSyncTime.value}');

    // Check if sync is actually running
    if (syncService.isSyncing.value) {
      print('🔄 Sync is currently running...');
    } else {
      print('⏸️ Sync is not running');
    }

    // Try to trigger sync and watch for errors
    try {
      print('🧪 Testing sync trigger...');
      await syncService.triggerManualSync();
      print('✅ Sync trigger completed');
    } catch (e) {
      print('❌ Sync trigger failed: $e');
    }

    print('🔍 === END SYNC DEBUG ===\n');
  }

  /// Updated convert method to properly map Firebase user_id to local firebase_user_id
  Map<String, dynamic> _convertFirestoreToSqlite(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Convert timestamps
    if (result['created_at'] is Timestamp) {
      result['created_at'] =
          (result['created_at'] as Timestamp).toDate().toIso8601String();
    }

    if (result['last_modified'] is Timestamp) {
      result['last_modified'] =
          (result['last_modified'] as Timestamp).millisecondsSinceEpoch;
    }

    // CRITICAL FIX: Map Firebase user_id to local firebase_user_id column
    if (result['user_id'] != null) {
      result['firebase_user_id'] = result['user_id'];
      print(
          '🔄 Mapping Firebase user_id (${result['user_id']}) to local firebase_user_id');
    }

    // Remove Firebase-specific fields that don't exist in local schema
    result.remove('user_id'); // Remove this - it conflicts with local schema
    result.remove('sync_device_id');

    // Ensure firebase_synced is set for downloaded records
    result['firebase_synced'] = 1;

    return result;
  }

  /// Also update the upload conversion method
  Map<String, dynamic> _convertSqliteToFirestore(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Remove SQLite-specific fields
    result.remove('firebase_synced');
    result.remove('firebase_uid');

    // CRITICAL FIX: Map local firebase_user_id to Firebase user_id
    if (result['firebase_user_id'] != null) {
      result['user_id'] = result['firebase_user_id'];
      print(
          '🔄 Mapping local firebase_user_id (${result['firebase_user_id']}) to Firebase user_id');
    }

    // Remove the local column name from Firebase data
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

    // Remove null values
    result.removeWhere((key, value) => value == null);

    return result;
  }

  // Add these methods to your FirebaseSyncService class to enhance automatic sync

  /// Enhanced setup for automatic sync with multiple triggers
  Future<void> setupAutomaticSync() async {
    print('🔄 === SETTING UP AUTOMATIC SYNC ===');

    try {
      // 1. Set up periodic sync (already exists, but let's enhance it)
      _setupEnhancedPeriodicSync();

      // 2. Set up auth state sync triggers
      _setupAuthSyncTriggers();

      // 3. Set up data change sync triggers
      _setupDataChangeSyncTriggers();

      // 4. Set up app lifecycle sync triggers
      _setupAppLifecycleSyncTriggers();

      print('✅ Automatic sync setup complete');
    } catch (e) {
      print('❌ Error setting up automatic sync: $e');
    }
  }

  /// Enhanced periodic sync with more frequent checks
  void _setupEnhancedPeriodicSync() {
    // Cancel existing timer
    _syncTimer?.cancel();

    // Set up new timer with shorter interval for more responsive sync
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_shouldAutoSync()) {
        print('⏰ Automatic periodic sync triggered');
        _triggerSync();
      }
    });

    print('✅ Enhanced periodic sync set up (every 2 minutes)');
  }

  /// Enhanced sync condition checking
  bool _shouldAutoSync() {
    // Basic conditions
    if (!isOnline.value ||
        isSyncing.value ||
        !firebaseAvailable.value ||
        !_authController.isFirebaseAuthenticated) {
      return false;
    }

    // Check if there's local data to upload
    final hasUnsyncedData = _hasUnsyncedLocalData();

    // Check time since last sync
    final timeSinceLastSync = DateTime.now().difference(lastSyncTime.value);
    final timeCondition = timeSinceLastSync.inMinutes >= 2;

    // Sync if there's unsynced data OR it's been more than 2 minutes
    final shouldSync = hasUnsyncedData || timeCondition;

    if (shouldSync) {
      print(
          '⏰ Auto-sync conditions met - Unsynced data: $hasUnsyncedData, Time: ${timeSinceLastSync.inMinutes}m');
    }

    return shouldSync;
  }

  /// Check if there's unsynced local data
  bool _hasUnsyncedLocalData() {
    // This is a quick check - you could make it more sophisticated
    // For now, we'll assume there might be unsynced data if last sync was recent
    final timeSinceLastSync = DateTime.now().difference(lastSyncTime.value);
    return timeSinceLastSync.inSeconds <
        10; // Recent activity suggests unsynced data
  }

  /// Set up authentication state sync triggers
  void _setupAuthSyncTriggers() {
    // Listen for authentication state changes
    ever(_authController.isLoggedIn, (bool isLoggedIn) {
      if (isLoggedIn && _authController.isFirebaseAuthenticated) {
        print('🔐 User logged in - triggering sync');
        Future.delayed(const Duration(seconds: 3), () {
          if (_shouldAutoSync()) {
            _triggerSync();
          }
        });
      }
    });

    ever(_authController.firebaseUser, (firebaseUser) {
      if (firebaseUser != null && _authController.isLoggedIn.value) {
        print('🔥 Firebase user authenticated - triggering sync');
        Future.delayed(const Duration(seconds: 3), () {
          if (_shouldAutoSync()) {
            _triggerSync();
          }
        });
      }
    });

    print('✅ Auth sync triggers set up');
  }

  /// Set up data change sync triggers (enhance existing database helpers)
  void _setupDataChangeSyncTriggers() {
    // The DatabaseHelperSyncExtension already has some of this
    // We'll enhance it with better timing
    print(
        '✅ Data change sync triggers already configured in DatabaseHelperSyncExtension');
  }

  /// Set up app lifecycle sync triggers
  void _setupAppLifecycleSyncTriggers() {
    // Listen for connectivity changes (this already exists, but let's enhance it)
    ever(isOnline, (bool online) {
      if (online &&
          firebaseAvailable.value &&
          _authController.isFirebaseAuthenticated) {
        print('🌐 Connection restored - scheduling sync');
        Future.delayed(const Duration(seconds: 5), () {
          if (_shouldAutoSync()) {
            _triggerSync();
          }
        });
      }
    });

    print('✅ App lifecycle sync triggers set up');
  }

  /// Trigger sync with debouncing to prevent too frequent syncs
  Timer? _syncDebounceTimer;
  void triggerDebouncedSync({Duration delay = const Duration(seconds: 5)}) {
    // Cancel existing timer
    _syncDebounceTimer?.cancel();

    // Set new timer
    _syncDebounceTimer = Timer(delay, () {
      if (_shouldAutoSync()) {
        print('🔄 Debounced sync triggered');
        _triggerSync();
      }
    });
  }

  /// Enhanced database helper methods that trigger debounced sync
  /// Update your DatabaseHelperSyncExtension to use this:

  /// Enhanced insert method with smarter sync triggering
  static Future<int> insertWithSmartSync(
      Database db, String table, Map<String, dynamic> values) async {
    // Add sync tracking data
    values['last_modified'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    values['firebase_synced'] = 0;

    final result = await db.insert(table, values);

    // Trigger debounced sync instead of immediate sync
    if (FirebaseSyncService.instance.isOnline.value &&
        !FirebaseSyncService.instance.isSyncing.value) {
      FirebaseSyncService.instance.triggerDebouncedSync();
    }

    return result;
  }

  /// Show sync status to users
  void showSyncStatus() {
    final stats = getSyncStats();

    String message;
    Color backgroundColor;

    if (stats['isSyncing']) {
      message = 'Syncing data...';
      backgroundColor = Colors.blue;
    } else if (!stats['isOnline']) {
      message = 'Offline - will sync when connected';
      backgroundColor = Colors.orange;
    } else if (!stats['isFirebaseAuthenticated']) {
      message = 'Sign in required for sync';
      backgroundColor = Colors.red;
    } else {
      final lastSync = stats['lastSyncTime'] as DateTime;
      final minutesAgo = DateTime.now().difference(lastSync).inMinutes;
      message = 'Last synced $minutesAgo minutes ago';
      backgroundColor = Colors.green;
    }

    Get.snackbar(
      'Sync Status',
      message,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _triggerSync() async {
    if (isSyncing.value) {
      print('⚠️ Sync already in progress, skipping');
      return;
    }
    try {
      isSyncing.value = true;
      syncStatus.value = 'Syncing...';

      // Phase 1: Add sync tracking to tables if needed
      await _ensureSyncTracking();

      // Phase 2: Sync shared data
      await _syncSharedData();

      // CRITICAL CHANGE: Download FIRST, then upload
      // Phase 3: Download remote changes BEFORE uploading local changes
      print('📥 Phase 3: Downloading remote changes FIRST...');
      await _downloadRemoteChanges();

      // Phase 4: Upload local changes AFTER downloading
      print('📤 Phase 4: Uploading local changes...');
      await _uploadLocalChanges();

      // Phase 5: Update sync time
      lastSyncTime.value = DateTime.now();
      await _saveLastSyncTime();

      syncStatus.value = 'Last sync: ${_formatSyncTime(lastSyncTime.value)}';
      print('✅ Sync completed successfully at ${DateTime.now()}');
    } catch (e, stackTrace) {
      // ... existing error handling ...
    } finally {
      isSyncing.value = false;
    }
  }

// 3. Add a method to check for unsynced local changes before downloading
  Future<bool> _hasUnsyncedLocalChanges(String table) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      table,
      where: 'firebase_synced = ?',
      whereArgs: [0],
      limit: 1,
    );

    return result.isNotEmpty;
  }

// 4. Enhanced conflict detection
  Future<void> _downloadRemoteChanges() async {
    print('📥 Starting download of remote changes...');

    int totalDownloaded = 0;

    for (final table in _syncTables) {
      try {
        // Check if we have local unsynced changes first
        final hasLocalChanges = await _hasUnsyncedLocalChanges(table);
        if (hasLocalChanges) {
          print(
              '⚠️ Table $table has unsynced local changes - will merge carefully');
        }

        final downloadCount = await _downloadTableChanges(table);
        totalDownloaded += downloadCount;

        if (downloadCount > 0) {
          print('📥 Downloaded $downloadCount changes for $table');
        }
      } catch (e) {
        print('❌ Error downloading $table: $e');
      }
    }

    print('📥 Total downloaded: $totalDownloaded changes');
  }

// Enhanced method to ensure proper timestamp handling in database operations
  Future<void> _ensureTimestampConsistency() async {
    final db = await DatabaseHelper.instance.database;

    for (final table in _syncTables) {
      try {
        // Find records with invalid or missing timestamps
        final invalidRecords = await db.query(
          table,
          where: 'last_modified IS NULL OR last_modified <= 0',
        );

        if (invalidRecords.isNotEmpty) {
          print(
              '🔧 Fixing ${invalidRecords.length} records with invalid timestamps in $table');

          for (final record in invalidRecords) {
            final id = record['id'];
            final now = DateTime.now().toUtc().millisecondsSinceEpoch;

            await db.update(
              table,
              {
                'last_modified': now,
                'firebase_synced': 0, // Mark as needing sync
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      } catch (e) {
        print('⚠️ Could not fix timestamps for $table: $e');
      }
    }
  }

  Future<void> _uploadTableRecords(
      String table, List<Map<String, dynamic>> records) async {
    if (_firestore == null) {
      throw Exception('Firestore not available');
    }

    try {
      print('📤 Uploading ${records.length} records to $table...');

      // Get the correct collection path
      final collectionPath = _getCorrectCollectionPath(table);
      final collection = _firestore!.collection(collectionPath);

      int successCount = 0;
      int errorCount = 0;
      int skippedCount = 0;

      // Upload records with timestamp checking
      for (final record in records) {
        try {
          final docId = record['id'].toString();
          final localLastModified = record['last_modified'] as int? ?? 0;

          // CRITICAL FIX: Check if remote data is newer before uploading
          final existingDoc = await collection.doc(docId).get();

          if (existingDoc.exists) {
            final existingData = existingDoc.data() as Map<String, dynamic>?;
            if (existingData != null) {
              // Convert remote timestamp to int for comparison
              final remoteLastModified =
                  _getTimestampAsInt(existingData['last_modified']);

              if (remoteLastModified != null &&
                  remoteLastModified > localLastModified) {
                // Remote is newer - DON'T upload, UPDATE LOCAL with remote data
                final db = await DatabaseHelper.instance.database;

                // Convert remote data to local format
                final localData = _convertFirestoreToSqlite(existingData);
                localData['firebase_synced'] = 1; // Mark as synced
                localData.remove('id'); // Don't overwrite the ID

                // UPDATE LOCAL DATABASE with newer remote data
                await db.update(
                  table,
                  localData,
                  where: 'id = ?',
                  whereArgs: [record['id']],
                );

                skippedCount++;
                print(
                    '⚠️ UPLOAD SKIPPED & LOCAL UPDATED: Remote newer for ID $docId');
                print(
                    '   Local timestamp:  ${DateTime.fromMillisecondsSinceEpoch(localLastModified)}');
                print(
                    '   Remote timestamp: ${DateTime.fromMillisecondsSinceEpoch(remoteLastModified)}');
                print('   → Local database updated with newer remote data');
                continue; // Skip this upload
              }
            }
          }

          // Proceed with upload if local is newer or equal
          final firestoreData = _convertSqliteToFirestore(record);

          // For user-specific data, ensure user_id is set
          if ([
            'users',
            'schedules',
            'invoices',
            'payments',
            'attachments',
            'notes',
            'notifications',
            'billing_records'
          ].contains(table)) {
            // Use firebase_user_id from record, or current user as fallback
            final recordFirebaseUserId = record['firebase_user_id'] ??
                _authController.currentFirebaseUserId;

            if (recordFirebaseUserId != null) {
              firestoreData['user_id'] = recordFirebaseUserId;
            } else {
              print('⚠️ No firebase_user_id for $table record ${record['id']}');
              errorCount++;
              continue;
            }
          }

          // Upload to Firebase
          await collection.doc(docId).set(firestoreData);

          // Mark as synced locally
          final db = await DatabaseHelper.instance.database;
          await db.update(
            table,
            {'firebase_synced': 1},
            where: 'id = ?',
            whereArgs: [record['id']],
          );

          successCount++;
          print('📤 Uploaded ID: $docId to $table');
        } catch (e) {
          errorCount++;
          print('❌ Failed to upload ${record['id']} to $table: $e');
        }
      }

      print('📤 Upload complete for $table:');
      print('   ✅ Successful uploads: $successCount');
      print('   🔄 Skipped & local updated: $skippedCount');
      print('   ❌ Errors: $errorCount');
    } catch (e) {
      print('❌ Error uploading $table: $e');
      throw e;
    }
  }

// Add this helper method if you don't have it already
  int? _getTimestampAsInt(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is int) {
      return timestamp;
    } else if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    } else if (timestamp is DateTime) {
      return timestamp.millisecondsSinceEpoch;
    } else if (timestamp is String) {
      try {
        final dateTime = DateTime.parse(timestamp);
        return dateTime.millisecondsSinceEpoch;
      } catch (e) {
        print('⚠️ Could not parse timestamp string: $timestamp');
        return null;
      }
    }

    print('⚠️ Unknown timestamp format: ${timestamp.runtimeType}');
    return null;
  }

  /// FIXED: Real-time record merge with proper constraint handling
  Future<void> _mergeDownloadedRecord(
      String table, String docId, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final sqliteData = _convertFirestoreToSqlite(data);

      // Use the document ID as the local ID
      final localId = int.tryParse(docId);
      if (localId == null) {
        print('⚠️ Skipping record with invalid ID: $docId');
        return;
      }

      // CRITICAL FIX: Use INSERT OR REPLACE to handle constraint violations
      // This ensures we don't get primary key constraint errors

      // Check if record exists locally (for logging/conflict detection)
      final existing = await db.query(
        table,
        where: 'id = ?',
        whereArgs: [localId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Record exists - check for conflicts
        final localLastModified = existing.first['last_modified'] as int? ?? 0;
        final remoteLastModified = sqliteData['last_modified'] as int? ?? 0;
        final localSynced = existing.first['firebase_synced'] as int? ?? 1;

        // Apply Last-Modified-Wins for real-time updates
        if (localSynced == 0 && localLastModified > remoteLastModified) {
          // Local has unsynced changes that are newer - keep local
          print(
              '⚡ Real-time conflict: Local wins for ID $localId (newer unsynced changes)');
          print(
              '   Local timestamp:  ${DateTime.fromMillisecondsSinceEpoch(localLastModified)}');
          print(
              '   Remote timestamp: ${DateTime.fromMillisecondsSinceEpoch(remoteLastModified)}');
          return; // Don't update, keep local changes
        }

        // Remote wins or local is synced - safe to update
        sqliteData['firebase_synced'] = 1;
        sqliteData.remove('id'); // Don't overwrite ID

        await db.update(
          table,
          sqliteData,
          where: 'id = ?',
          whereArgs: [localId],
        );
        print('📝 Real-time update: ID $localId in $table');

        if (localSynced == 0) {
          print('   ⚡ Real-time conflict: Remote wins (newer timestamp)');
        }
      } else {
        // Record doesn't exist locally - insert it
        // FIX: Use INSERT OR REPLACE to handle any constraint issues
        sqliteData['id'] = localId;
        sqliteData['firebase_synced'] = 1;

        try {
          await db.insert(table, sqliteData);
          print('➕ Real-time insert: ID $localId in $table');
        } catch (e) {
          if (e.toString().contains('UNIQUE constraint failed') ||
              e.toString().contains('PRIMARY KEY constraint')) {
            print(
                '⚠️ Primary key constraint on insert, using INSERT OR REPLACE for ID $localId');

            // FIX: Use raw SQL with INSERT OR REPLACE
            final columns = sqliteData.keys.join(', ');
            final placeholders = List.filled(sqliteData.length, '?').join(', ');

            await db.rawInsert(
              'INSERT OR REPLACE INTO $table ($columns) VALUES ($placeholders)',
              sqliteData.values.toList(),
            );
            print('✅ Real-time insert/replace: ID $localId in $table');
          } else {
            rethrow; // Re-throw if it's a different error
          }
        }
      }
    } catch (e) {
      print('❌ Error merging real-time record for $table: $e');

      // ADDITIONAL FIX: If all else fails, try a force update
      if (e.toString().contains('UNIQUE constraint failed') ||
          e.toString().contains('PRIMARY KEY constraint')) {
        try {
          final localId = int.tryParse(docId);
          if (localId != null) {
            final sqliteData = _convertFirestoreToSqlite(data);
            sqliteData['firebase_synced'] = 1;
            sqliteData.remove('id');

            // Force update existing record
            final updateResult = await db.update(
              table,
              sqliteData,
              where: 'id = ?',
              whereArgs: [localId],
            );

            if (updateResult > 0) {
              print('🔧 Force updated existing record ID $localId in $table');
            } else {
              print('⚠️ No record found to update for ID $localId in $table');
            }
          }
        } catch (forceError) {
          print('❌ Force update also failed: $forceError');
        }
      }
    }
  }

// ADDITIONAL FIX: Enhanced real-time change handler with better error handling
  Future<void> _handleRealtimeChanges(
      String table, QuerySnapshot snapshot) async {
    try {
      print(
          '⚡ Processing real-time changes for $table: ${snapshot.docChanges.length} changes');

      for (final change in snapshot.docChanges) {
        try {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            final docSnapshot = change.doc;

            // Check if document exists and has data
            if (docSnapshot.exists) {
              final data = docSnapshot.data() as Map<String, dynamic>?;

              if (data != null) {
                // Process this specific change with better error handling
                await _mergeDownloadedRecord(table, docSnapshot.id, data);
              } else {
                print('⚠️ Document ${docSnapshot.id} has no data');
              }
            } else {
              print('⚠️ Document ${docSnapshot.id} does not exist');
            }
          } else if (change.type == DocumentChangeType.removed) {
            // Handle deletions
            await _handleRecordDeletion(table, change.doc.id);
          }
        } catch (changeError) {
          // Don't let one failed change break the entire batch
          print('❌ Error processing individual change in $table: $changeError');
          print('   Document ID: ${change.doc.id}');
          print('   Change type: ${change.type}');
          // Continue processing other changes
        }
      }
    } catch (e) {
      print('❌ Error handling real-time changes batch for $table: $e');
    }
  }

// ENHANCED: Batch merge method with better constraint handling
  Future<void> _mergeDownloadedRecords(
      String table, List<QueryDocumentSnapshot> docs) async {
    final db = await DatabaseHelper.instance.database;
    int insertCount = 0;
    int updateCount = 0;
    int conflictCount = 0;
    int skipCount = 0;
    int constraintErrorCount = 0;

    print('🔄 Merging ${docs.length} downloaded $table records...');

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final firebaseId = doc.id;
        if (!doc.exists || data == null) continue;

        final sqliteData = _convertFirestoreToSqlite(data);
        final localId = int.tryParse(firebaseId);
        if (localId == null) {
          print('⚠️ Skipping record with invalid ID: $firebaseId');
          skipCount++;
          continue;
        }

        // Check if record exists locally
        final existing = await db.query(
          table,
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final localLastModified =
              existing.first['last_modified'] as int? ?? 0;
          final remoteLastModified = sqliteData['last_modified'] as int? ?? 0;
          final localSynced = existing.first['firebase_synced'] as int? ?? 1;

          if (localSynced == 1) {
            // Local data is already synced, safe to accept remote changes
            sqliteData['firebase_synced'] = 1;
            sqliteData.remove('id');

            await db.update(
              table,
              sqliteData,
              where: 'id = ?',
              whereArgs: [localId],
            );
            updateCount++;
            print('📝 Updated local record ID: $localId (local was synced)');
          } else {
            // Local has unsynced changes - use Last-Modified-Wins strategy
            if (remoteLastModified > localLastModified) {
              // Remote is newer - accept remote changes
              sqliteData['firebase_synced'] = 1;
              sqliteData.remove('id');

              await db.update(
                table,
                sqliteData,
                where: 'id = ?',
                whereArgs: [localId],
              );
              conflictCount++;
              print(
                  '⚡ CONFLICT: Remote wins for ID $localId (newer timestamp)');
            } else {
              // Local is newer or equal - keep local changes
              skipCount++;
              print(
                  '⚡ CONFLICT: Local wins for ID $localId (newer local changes)');
              continue; // Skip this remote update
            }
          }
        } else {
          // New record - insert it with constraint handling
          sqliteData['id'] = localId;
          sqliteData['firebase_synced'] = 1;

          try {
            await db.insert(table, sqliteData);
            insertCount++;
            print('➕ Inserted new record ID: $localId');
          } catch (insertError) {
            if (insertError.toString().contains('UNIQUE constraint failed') ||
                insertError.toString().contains('PRIMARY KEY constraint')) {
              constraintErrorCount++;
              print(
                  '⚠️ Constraint error on insert, attempting INSERT OR REPLACE for ID $localId');

              try {
                // Use INSERT OR REPLACE as fallback
                final columns = sqliteData.keys.join(', ');
                final placeholders =
                    List.filled(sqliteData.length, '?').join(', ');

                await db.rawInsert(
                  'INSERT OR REPLACE INTO $table ($columns) VALUES ($placeholders)',
                  sqliteData.values.toList(),
                );
                insertCount++;
                print('✅ Insert/replace successful for ID $localId');
              } catch (replaceError) {
                print(
                    '❌ Insert/replace also failed for ID $localId: $replaceError');
                skipCount++;
              }
            } else {
              print(
                  '❌ Non-constraint error inserting ID $localId: $insertError');
              skipCount++;
            }
          }
        }
      } catch (e) {
        print('❌ Error merging record: $e');
        skipCount++;
      }
    }

    print('✅ Merge complete for $table:');
    print('   📥 Inserted: $insertCount');
    print('   📝 Updated: $updateCount');
    print('   ⚡ Conflicts: $conflictCount');
    print('   ⚠️ Constraint errors handled: $constraintErrorCount');
    print('   ⏭️ Skipped: $skipCount');
  }
}
