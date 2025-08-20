// lib/services/firebase_sync_service.dart - Fixed with proper error handling
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      print('🔄 Initializing Firebase Sync Service...');

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

  /// Main sync operation with comprehensive error handling and logging
  Future<void> _triggerSync() async {
    if (isSyncing.value) {
      print('⚠️ Sync already in progress, skipping');
      return;
    }

    if (!isOnline.value ||
        !firebaseAvailable.value ||
        !_authController.isFirebaseAuthenticated) {
      print(
          '⚠️ Sync preconditions not met - Online: ${isOnline.value}, Firebase: ${firebaseAvailable.value}, Auth: ${_authController.isFirebaseAuthenticated}');
      return;
    }

    try {
      isSyncing.value = true;
      syncStatus.value = 'Syncing...';

      print(
          '🔄 Starting sync for user: ${_authController.currentFirebaseUserId}');
      print('📊 Sync tables: ${_syncTables.join(', ')}');

      // Test Firebase connection before proceeding
      await _testFirebaseAvailability();
      if (!firebaseAvailable.value) {
        throw Exception('Firebase connection lost during sync');
      }

      // Phase 1: Add sync tracking to tables if needed
      await _ensureSyncTracking();

      // Phase 2: Sync shared data (available to all users)
      await _syncSharedData();

      // Phase 3: Upload local changes
      print('📤 Phase 3: Uploading local changes...');
      await _uploadLocalChanges();

      // Phase 4: Download user-specific changes
      print('📥 Phase 4: Downloading user-specific changes...');
      await _downloadRemoteChanges();

      // Phase 5: Update sync time
      lastSyncTime.value = DateTime.now();
      await _saveLastSyncTime();

      syncStatus.value = 'Last sync: ${_formatSyncTime(lastSyncTime.value)}';
      print('✅ Sync completed successfully at ${DateTime.now()}');

      Get.snackbar(
        'Sync Complete',
        'Data synchronized successfully',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 2),
      );
    } catch (e, stackTrace) {
      print('❌ Sync error: $e');
      print('📋 Stack trace: $stackTrace');
      syncStatus.value = 'Sync failed - ${e.toString()}';

      // Handle specific error types
      if (e is PlatformException && e.code == 'channel-error') {
        _handleFirebaseError(e);
        Get.snackbar(
          'Sync Error',
          'Firebase connection lost. Running in offline mode.',
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
      } else {
        Get.snackbar(
          'Sync Error',
          'Failed to sync: ${e.toString()}',
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
      }
    } finally {
      isSyncing.value = false;
      print('🏁 Sync operation completed\n');
    }
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
            SET last_modified = ${DateTime.now().millisecondsSinceEpoch}, 
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

  /// Upload table records with proper collection structure
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

      // Upload records
      for (final record in records) {
        try {
          final firestoreData = _convertSqliteToFirestore(record);

          // Use record ID as document ID for consistency
          final docId = record['id'].toString();

          // For shared data, don't include user-specific fields
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
            firestoreData['user_id'] = _authController.currentFirebaseUserId;
            firestoreData['sync_device_id'] = await _getDeviceId();
            print('👤 Uploading user-specific data to: $collectionPath');
          } else {
            print('🌍 Uploading shared data to: $collectionPath');
          }

          await collection
              .doc(docId)
              .set(firestoreData, SetOptions(merge: true));
          successCount++;

          print('✅ Uploaded $table record $docId to $collectionPath');
        } catch (e) {
          print('❌ Error uploading record ${record['id']}: $e');
          errorCount++;
        }
      }

      print(
          '📤 Upload complete for $table - Success: $successCount, Errors: $errorCount');

      // Mark successfully uploaded records as synced
      if (successCount > 0) {
        await _markRecordsAsSynced(table, records);
      }
    } catch (e) {
      print('❌ Error uploading $table records: $e');
      // Don't throw - continue with other tables
    }
  }

  /// Download remote changes from Firebase with comprehensive logging
  Future<void> _downloadRemoteChanges() async {
    int totalDownloaded = 0;

    for (String table in _syncTables) {
      try {
        print('📥 Processing downloads for table: $table');
        final count = await _downloadTableChanges(table);
        totalDownloaded += count;
      } catch (e) {
        print('❌ Error downloading $table: $e');
        // Continue with other tables
      }
    }

    print(
        '📥 Download phase complete. Total downloaded: $totalDownloaded records');
  }

  // Updated _downloadTableChanges method to avoid composite index requirement

  /// Download changes for a specific table with user filtering (NO INDEX REQUIRED)
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
          query = query.where('user_id', isEqualTo: userId);
          print('📥 Filtering $table for user: $userId');
        }
      }

      // MODIFIED: Don't use compound query to avoid index requirement
      // Instead of filtering by last_modified in Firestore, we'll filter in memory

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

// Alternative approach: Separate queries to avoid compound index
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

  /// Enhanced merge with conflict resolution
  Future<void> _mergeDownloadedRecords(
      String table, List<QueryDocumentSnapshot> docs) async {
    final db = await DatabaseHelper.instance.database;
    int insertCount = 0;
    int updateCount = 0;
    int conflictCount = 0;
    int skipCount = 0;

    print('🔄 Merging ${docs.length} downloaded $table records...');

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final firebaseId = doc.id;
        final sqliteData = _convertFirestoreToSqlite(data);

        // Use the document ID as the local ID
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
          // Conflict resolution - use latest modification
          final localLastModified =
              existing.first['last_modified'] as int? ?? 0;
          final remoteLastModified = sqliteData['last_modified'] as int? ?? 0;

          if (remoteLastModified > localLastModified) {
            // Remote is newer - update local
            sqliteData['firebase_synced'] = 1;
            sqliteData.remove('id'); // Don't overwrite ID

            await db.update(
              table,
              sqliteData,
              where: 'id = ?',
              whereArgs: [localId],
            );
            updateCount++;
            print(
                '📝 Updated local record ID: $localId in $table (remote newer)');
          } else if (remoteLastModified < localLastModified) {
            // Local is newer - keep local, but mark as sync needed
            await db.update(
              table,
              {'firebase_synced': 0},
              where: 'id = ?',
              whereArgs: [localId],
            );
            conflictCount++;
            print('⚡ Conflict detected for ID: $localId (local newer)');
          } else {
            // Same timestamp - update anyway
            sqliteData['firebase_synced'] = 1;
            sqliteData.remove('id');

            await db.update(
              table,
              sqliteData,
              where: 'id = ?',
              whereArgs: [localId],
            );
            updateCount++;
            print(
                '📝 Updated local record ID: $localId in $table (same timestamp)');
          }
        } else {
          // Insert new record
          sqliteData['id'] = localId;
          sqliteData['firebase_synced'] = 1;
          sqliteData['last_modified'] = DateTime.now().millisecondsSinceEpoch;

          await db.insert(table, sqliteData);
          insertCount++;
          print('➕ Inserted new record ID: $localId in $table');
        }
      } catch (e) {
        print('❌ Error merging ${doc.id}: $e');
        skipCount++;
      }
    }

    print(
        '🔄 $table merge complete - Inserted: $insertCount, Updated: $updateCount, Conflicts: $conflictCount, Skipped: $skipCount');
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

    // Remove null values
    result.removeWhere((key, value) => value == null);

    return result;
  }

  /// Convert Firestore data to SQLite format
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

    // Remove Firestore-specific fields
    result.remove('user_id');
    result.remove('sync_device_id');

    return result;
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

  /// Debug method to check sync status and data
  Future<void> debugSyncStatus() async {
    print('\n🔍 === SYNC DEBUG INFO ===');
    print('📊 Firebase Available: ${firebaseAvailable.value}');
    print('🌐 Online: ${isOnline.value}');
    print(
        '🔐 Firebase Authenticated: ${_authController.isFirebaseAuthenticated}');
    print('👤 Firebase User ID: ${_authController.currentFirebaseUserId}');
    print('⏰ Last Sync: ${lastSyncTime.value}');
    print('📋 Sync Tables: ${_syncTables.join(', ')}');

    if (_authController.isFirebaseAuthenticated) {
      // Check each table for unsynced records
      final db = await DatabaseHelper.instance.database;

      for (String table in _syncTables) {
        try {
          final totalRecords = await db.query(table);
          final unsyncedRecords = await db.query(
            table,
            where: 'firebase_synced = ? OR firebase_synced IS NULL',
            whereArgs: [0],
          );

          print(
              '📋 $table: ${totalRecords.length} total, ${unsyncedRecords.length} unsynced');

          // Show sample unsynced record
          if (unsyncedRecords.isNotEmpty) {
            final sample = unsyncedRecords.first;
            print(
                '   Sample unsynced: ID=${sample['id']}, firebase_synced=${sample['firebase_synced']}');
          }
        } catch (e) {
          print('❌ Error checking $table: $e');
        }
      }
    }

    print('=========================\n');
  }

  /// Force mark all records as unsynced (for debugging)
  Future<void> markAllRecordsAsUnsynced() async {
    print('🔧 Marking all records as unsynced...');

    final db = await DatabaseHelper.instance.database;

    for (String table in _syncTables) {
      try {
        await db.execute('''
          UPDATE $table 
          SET firebase_synced = 0, 
              last_modified = ${DateTime.now().millisecondsSinceEpoch}
        ''');
        print('✅ Marked all $table records as unsynced');
      } catch (e) {
        print('❌ Error marking $table: $e');
      }
    }

    // Reset sync time
    lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(0);
    await _saveLastSyncTime();

    print('🔧 All records marked as unsynced. Ready for sync.');
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
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
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
        deviceName = 'Device-${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
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

  /// Handle real-time changes
  Future<void> _handleRealtimeChanges(
      String table, QuerySnapshot snapshot) async {
    try {
      print(
          '⚡ Processing real-time changes for $table: ${snapshot.docChanges.length} changes');

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          // Convert DocumentSnapshot to QueryDocumentSnapshot
          final queryDocSnapshot =
              change.doc as QueryDocumentSnapshot<Map<String, dynamic>>;
          await _mergeDownloadedRecords(table, [queryDocSnapshot]);
        } else if (change.type == DocumentChangeType.removed) {
          // Handle deletions
          await _handleRecordDeletion(table, change.doc.id);
        }
      }
    } catch (e) {
      print('❌ Error handling real-time changes: $e');
    }
  }
}
