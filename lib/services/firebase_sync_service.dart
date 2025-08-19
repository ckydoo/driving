// lib/services/firebase_sync_service.dart - Fixed version with comprehensive logging
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
  ];

  // Tracking
  final Set<String> _processingUsers = <String>{};
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
      await _testFirebaseAvailability();

      // Load last sync time
      await _loadLastSyncTime();

      // Monitor connectivity
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

      // Check initial connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      _onConnectivityChanged(connectivityResult);

      // Set up periodic sync (only if Firebase is available)
      if (firebaseAvailable.value) {
        _setupPeriodicSync();
        syncStatus.value = 'Ready';

        // Auto-trigger sync if user is already authenticated
        if (_authController.isFirebaseAuthenticated) {
          print('🔄 User already authenticated, triggering initial sync...');
          Future.delayed(const Duration(seconds: 2), () {
            triggerManualSync();
          });
        }
      } else {
        syncStatus.value = 'Firebase Unavailable - Offline Mode';
      }

      print(
          '✅ Firebase Sync Service initialized (Firebase Available: ${firebaseAvailable.value})');
    } catch (e) {
      print('❌ Error initializing Firebase Sync Service: $e');
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
      } else {
        errorMessage = 'Firebase platform error: ${error.message}';
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

  String _getCollectionPath(String table) {
    // Define which tables should be shared across all devices
    final sharedTables = [
      'courses',
      'fleet',
      'schedules',
      'invoices',
      'payments',
      'users' // If you want user accounts to be shared
    ];

    if (sharedTables.contains(table)) {
      // Use global collection for shared data
      return 'global_data/$table';
    } else {
      // Use user-specific collection for personal data
      final firebaseUserId = _authController.currentFirebaseUserId;
      if (firebaseUserId == null) {
        throw Exception('User not authenticated with Firebase');
      }
      return 'user_data/$firebaseUserId/$table';
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

      // Phase 2: Upload local changes
      print('📤 Phase 2: Uploading local changes...');
      await _uploadLocalChanges();

      // Phase 3: Download remote changes
      print('📥 Phase 3: Downloading remote changes...');
      await _downloadRemoteChanges();

      // Phase 4: Update sync time
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
    } catch (e) {
      print('❌ Sync error: $e');
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

  /// Merge downloaded records with local database
  Future<void> _mergeDownloadedRecords(
      String table, List<QueryDocumentSnapshot> docs) async {
    final db = await DatabaseHelper.instance.database;
    int insertCount = 0;
    int updateCount = 0;
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
          // Update existing record
          sqliteData['firebase_synced'] = 1;
          sqliteData['last_modified'] = DateTime.now().millisecondsSinceEpoch;
          sqliteData.remove('id'); // Don't overwrite ID

          await db.update(
            table,
            sqliteData,
            where: 'id = ?',
            whereArgs: [localId],
          );
          updateCount++;
          print('📝 Updated local record ID: $localId in $table');
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
        '🔄 $table merge complete - Inserted: $insertCount, Updated: $updateCount, Skipped: $skipCount');
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

  /// Listen to real-time changes for specific collections (placeholder)
  void listenToRealtimeChanges() {
    print('👂 Real-time listeners would be set up here');
    // Implementation for real-time sync can be added later
  }

  /// Get device identifier
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
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

  // Fixed Firebase Sync Service - Collection Path Issue

  /// Get current user's Firebase collection path
  String _getUserCollectionPath(String table) {
    final firebaseUserId = _authController.currentFirebaseUserId;
    if (firebaseUserId == null || firebaseUserId.isEmpty) {
      throw Exception('User not authenticated with Firebase');
    }

    // Debug: Print what we're getting
    print('🔄 Getting collection path for table: $table');
    print('🔑 Firebase User ID: $firebaseUserId');

    // Fix: Ensure the path structure is correct
    // Firestore collection paths must have odd number of segments
    // Format: collection/document/collection
    final path = 'user_data/$firebaseUserId/$table';

    print('📁 Generated collection path: $path');

    // Validate the path structure
    final segments = path.split('/');
    if (segments.length % 2 == 0) {
      throw Exception(
          'Invalid collection path: $path (even number of segments)');
    }

    return path;
  }

  /// Alternative: Simplified collection structure
  String _getUserCollectionPathSimplified(String table) {
    final firebaseUserId = _authController.currentFirebaseUserId;
    if (firebaseUserId == null || firebaseUserId.isEmpty) {
      throw Exception('User not authenticated with Firebase');
    }

    // Simplified approach: Direct table collections with user filtering
    print('🔄 Getting collection path for table: $table');
    print('🔑 Firebase User ID: $firebaseUserId');

    // Just use the table name directly and filter by user_id
    final path = table;

    print('📁 Simplified collection path: $path');
    return path;
  }

  /// Upload table records with proper error handling
  Future<void> _uploadTableRecords(
      String table, List<Map<String, dynamic>> records) async {
    if (_firestore == null) {
      throw Exception('Firestore not available');
    }

    try {
      print('📤 Uploading ${records.length} records to $table...');

      // Get collection path
      final collectionPath = _getUserCollectionPath(table);
      final collection = _firestore!.collection(collectionPath);

      // Ensure collection exists by creating it if needed
      await _ensureCollectionExists(collectionPath);
      final firebaseUserId = _authController.currentFirebaseUserId;

      int successCount = 0;
      int errorCount = 0;

      // Upload records in batches
      const batchSize = 10;
      for (int i = 0; i < records.length; i += batchSize) {
        final batch = _firestore!.batch();
        final endIndex =
            (i + batchSize < records.length) ? i + batchSize : records.length;

        for (int j = i; j < endIndex; j++) {
          try {
            final record = records[j];
            final firestoreData = _convertSqliteToFirestore(record);

            // Add user identification
            firestoreData['user_id'] = firebaseUserId;
            firestoreData['sync_device_id'] = await _getDeviceId();

            // Use record ID as document ID
            final docId = record['id'].toString();
            final docRef = collection.doc(docId);

            batch.set(docRef, firestoreData, SetOptions(merge: true));
          } catch (e) {
            print('❌ Error preparing record ${records[j]['id']}: $e');
            errorCount++;
          }
        }

        try {
          await batch.commit();
          successCount += (endIndex - i - errorCount);
          print('✅ Batch uploaded: ${endIndex - i} records');
        } catch (e) {
          print('❌ Batch upload failed: $e');
          errorCount += (endIndex - i);
        }
      }

      print(
          '📤 Upload complete for $table - Success: $successCount, Errors: $errorCount');

      // Mark successfully uploaded records as synced
      if (successCount > 0) {
        await _markRecordsAsSynced(table, records.take(successCount).toList());
      }
    } catch (e) {
      print('❌ Error uploading $table records: $e');
      throw e;
    }
  }

  /// Ensure collection exists in Firestore
  Future<void> _ensureCollectionExists(String collectionPath) async {
    if (_firestore == null) return;

    try {
      print('🔧 Ensuring collection exists: $collectionPath');

      // Check if collection exists by trying to get any document
      final testQuery =
          await _firestore!.collection(collectionPath).limit(1).get();

      if (testQuery.docs.isEmpty) {
        print('📁 Collection does not exist, creating it...');

        // Create collection by adding a temporary document
        final tempDoc =
            _firestore!.collection(collectionPath).doc('_temp_init');
        await tempDoc.set({
          'temp': true,
          'created_at': FieldValue.serverTimestamp(),
          'message': 'Collection initialization document'
        });

        print('✅ Collection created with temporary document');

        // Optionally delete the temp document immediately
        // await tempDoc.delete();
        // print('🗑️ Temporary document removed');
      } else {
        print('✅ Collection already exists');
      }
    } catch (e) {
      print('⚠️ Error ensuring collection exists: $e');
      // Continue anyway - the first document will create the collection
    }
  }

  /// Download changes for a specific table
  Future<int> _downloadTableChanges(String table) async {
    if (_firestore == null) {
      throw Exception('Firestore not available');
    }

    try {
      // Get collection path
      final collectionPath = _getUserCollectionPath(table);

      // Ensure collection exists before querying
      await _ensureCollectionExists(collectionPath);

      Query query = _firestore!.collection(collectionPath);
      // Only get changes since last sync
      if (lastSyncTime.value.millisecondsSinceEpoch > 0) {
        query = query.where(
          'last_modified',
          isGreaterThan: Timestamp.fromDate(lastSyncTime.value),
        );
        print('📥 Downloading $table changes since ${lastSyncTime.value}');
      } else {
        print('📥 Downloading all $table records (first sync)');
      }

      final snapshot = await query.get();
      print('📥 Found ${snapshot.docs.length} remote changes in $table');

      if (snapshot.docs.isNotEmpty) {
        await _mergeDownloadedRecords(table, snapshot.docs);
      }

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error downloading $table changes: $e');
      throw e;
    }
  }

  /// Debug: Test collection path generation
  Future<void> debugCollectionPaths() async {
    final tables = [
      'users',
      'courses',
      'fleet',
      'schedules',
      'invoices',
      'payments'
    ];

    print('\n🔧 === DEBUGGING COLLECTION PATHS ===');
    print('Firebase User ID: ${_authController.currentFirebaseUserId}');

    for (String table in tables) {
      try {
        final path = _getUserCollectionPath(table);
        final segments = path.split('/');
        print('✅ $table: $path (${segments.length} segments)');

        // Test if we can create a reference
        final ref = _firestore!.collection(path);
        print('   📁 Collection reference created successfully');
      } catch (e) {
        print('❌ $table: ERROR - $e');
      }
    }
    print('🔧 === END DEBUG ===\n');
  }
}
