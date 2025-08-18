// lib/services/firebase_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class FirebaseSyncService extends GetxController {
  static FirebaseSyncService get instance => Get.find<FirebaseSyncService>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  final RxBool isOnline = false.obs;
  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Offline'.obs;
  final Rx<DateTime> lastSyncTime = DateTime.now().obs;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;

  // Tables to sync - add/remove based on your needs
  final List<String> _syncTables = [
    'users',
    'courses',
    'schedules',
    'invoices',
    'payments',
    'billings',
    'attachments',
    'notes',
    'fleet',
    'notifications'
  ];

  @override
  Future<void> onInit() async {
    try {
      super.onInit();

      // Check if required dependencies are available
      if (!Get.isRegistered<DatabaseHelper>()) {
        throw Exception(
            'DatabaseHelper not found. Initialize DatabaseHelper first.');
      }

      // Settings controller is optional - sync can work without it
      if (!Get.isRegistered<SettingsController>()) {
        print('⚠️ SettingsController not found. Using default sync settings.');
      }

      await _initializeFirestore();
      await _setupConnectivityListener();
      await _loadLastSyncTime();
      _startPeriodicSync();
      print('✅ Firebase Sync Service initialized successfully');
    } catch (e) {
      print('❌ Firebase Sync Service initialization failed: $e');
      syncStatus.value = 'Initialization Failed';
      // Don't rethrow - let the app continue
    }
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.onClose();
  }

  /// Initialize Firestore settings for offline persistence
  Future<void> _initializeFirestore() async {
    try {
      // Enable offline persistence
      await _firestore.enablePersistence();

      // Configure Firestore settings
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      print('Firestore initialized with offline persistence');
    } catch (e) {
      print('Error initializing Firestore: $e');
    }
  }

  /// Setup connectivity listener to detect online/offline status
  Future<void> _setupConnectivityListener() async {
    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _updateOnlineStatus(connectivityResult);

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateOnlineStatus,
      onError: (error) {
        print('Connectivity error: $error');
      },
    );
  }

  /// Update online status and trigger sync if connected
  void _updateOnlineStatus(ConnectivityResult result) {
    final wasOnline = isOnline.value;
    isOnline.value = result != ConnectivityResult.none;

    if (!wasOnline && isOnline.value) {
      syncStatus.value = 'Connected - Syncing...';
      _triggerSync();
    } else if (!isOnline.value) {
      syncStatus.value = 'Offline';
    }
  }

  /// Start periodic sync when online
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (isOnline.value && !isSyncing.value) {
        _triggerSync();
      }
    });
  }

  /// Trigger manual sync
  Future<void> triggerManualSync() async {
    if (!isOnline.value) {
      Get.snackbar(
        'Sync Error',
        'No internet connection available',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    await _triggerSync();
  }

  /// Main sync method - handles both upload and download
  Future<void> _triggerSync() async {
    if (isSyncing.value) return;

    try {
      isSyncing.value = true;
      syncStatus.value = 'Syncing...';

      // Step 1: Upload pending changes to Firestore
      await _uploadPendingChanges();

      // Step 2: Download changes from Firestore
      await _downloadChanges();

      // Step 3: Update last sync time
      lastSyncTime.value = DateTime.now();
      await _saveLastSyncTime();

      syncStatus.value = 'Synced';

      Get.snackbar(
        'Sync Complete',
        'Data synchronized successfully',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('Sync error: $e');
      syncStatus.value = 'Sync Failed';

      Get.snackbar(
        'Sync Error',
        'Failed to sync data: ${e.toString()}',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// Upload pending changes to Firestore
  Future<void> _uploadPendingChanges() async {
    final db = await DatabaseHelper.instance.database;

    for (String table in _syncTables) {
      try {
        // Get all records that need syncing (modified since last sync)
        final records = await _getPendingRecords(table);

        if (records.isNotEmpty) {
          print('Uploading ${records.length} records from $table');

          // Upload in batches
          await _uploadRecordsInBatches(table, records);
        }
      } catch (e) {
        print('Error uploading $table: $e');
      }
    }
  }

  /// Get records that need to be synced to Firebase
  Future<List<Map<String, dynamic>>> _getPendingRecords(String table) async {
    final db = await DatabaseHelper.instance.database;

    // Check if table has sync tracking columns
    final hasTrackingColumns = await _hasTrackingColumns(table);

    if (hasTrackingColumns) {
      // Get records modified since last sync or never synced
      return await db.query(
        table,
        where: 'last_modified > ? OR firebase_synced = 0',
        whereArgs: [lastSyncTime.value.millisecondsSinceEpoch],
      );
    } else {
      // If no tracking columns, get all records (first-time sync)
      return await db.query(table);
    }
  }

  /// Check if table has sync tracking columns
  Future<bool> _hasTrackingColumns(String table) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final result = await db.rawQuery("PRAGMA table_info($table)");
      final columnNames = result.map((row) => row['name'] as String).toList();

      return columnNames.contains('last_modified') &&
          columnNames.contains('firebase_synced');
    } catch (e) {
      return false;
    }
  }

  /// Upload records to Firestore in batches
  Future<void> _uploadRecordsInBatches(
      String table, List<Map<String, dynamic>> records) async {
    const batchSize = 500; // Firestore batch limit

    for (int i = 0; i < records.length; i += batchSize) {
      final batch = _firestore.batch();
      final endIndex =
          (i + batchSize < records.length) ? i + batchSize : records.length;
      final batchRecords = records.sublist(i, endIndex);

      for (final record in batchRecords) {
        final docRef =
            _firestore.collection(table).doc(record['id'].toString());

        // Clean the record for Firebase (remove SQLite-specific fields)
        final cleanRecord = Map<String, dynamic>.from(record);
        cleanRecord.remove('firebase_synced');
        cleanRecord['last_modified'] = FieldValue.serverTimestamp();

        batch.set(docRef, cleanRecord, SetOptions(merge: true));
      }

      await batch.commit();

      // Mark records as synced in local database
      await _markRecordsAsSynced(table, batchRecords);
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
        // Table might not have tracking columns - this is OK
        print('Could not mark $table record as synced: $e');
      }
    }
  }

  /// Download changes from Firestore
  Future<void> _downloadChanges() async {
    for (String table in _syncTables) {
      try {
        await _downloadTableChanges(table);
      } catch (e) {
        print('Error downloading $table: $e');
      }
    }
  }

  /// Download changes for a specific table
  Future<void> _downloadTableChanges(String table) async {
    try {
      // Get documents modified since last sync
      Query query = _firestore.collection(table);

      if (lastSyncTime.value.millisecondsSinceEpoch > 0) {
        query = query.where(
          'last_modified',
          isGreaterThan: Timestamp.fromDate(lastSyncTime.value),
        );
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        print('Downloading ${snapshot.docs.length} records for $table');
        await _mergeDownloadedRecords(table, snapshot.docs);
      }
    } catch (e) {
      print('Error downloading $table changes: $e');
    }
  }

  /// Merge downloaded records with local database
  Future<void> _mergeDownloadedRecords(
      String table, List<QueryDocumentSnapshot> docs) async {
    final db = await DatabaseHelper.instance.database;

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final recordId = doc.id;

        // Convert Firestore data to SQLite format
        final sqliteData = _convertFirestoreToSqlite(data);
        sqliteData['id'] = int.tryParse(recordId) ?? recordId;

        // Check if record exists locally
        final existing = await db.query(
          table,
          where: 'id = ?',
          whereArgs: [recordId],
        );

        if (existing.isNotEmpty) {
          // Update existing record
          await db.update(
            table,
            sqliteData,
            where: 'id = ?',
            whereArgs: [recordId],
          );
        } else {
          // Insert new record
          await db.insert(table, sqliteData);
        }
      } catch (e) {
        print('Error merging record from $table: $e');
      }
    }
  }

  /// Convert Firestore data types to SQLite compatible types
  Map<String, dynamic> _convertFirestoreToSqlite(
      Map<String, dynamic> firestoreData) {
    final sqliteData = <String, dynamic>{};

    for (final entry in firestoreData.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Timestamp) {
        sqliteData[key] = value.millisecondsSinceEpoch;
      } else if (value is FieldValue) {
        // Skip FieldValue entries
        continue;
      } else {
        sqliteData[key] = value;
      }
    }

    return sqliteData;
  }

  /// Add sync tracking columns to tables
  Future<void> addSyncTrackingToTables() async {
    final db = await DatabaseHelper.instance.database;

    for (String table in _syncTables) {
      try {
        // Add last_modified column
        await db.execute(
            'ALTER TABLE $table ADD COLUMN last_modified INTEGER DEFAULT 0');

        // Add firebase_synced column
        await db.execute(
            'ALTER TABLE $table ADD COLUMN firebase_synced INTEGER DEFAULT 0');

        print('Added sync tracking to $table');
      } catch (e) {
        // Columns might already exist
        print('Sync tracking columns may already exist in $table: $e');
      }
    }
  }

  /// Force full sync (useful for initial setup or data recovery)
  Future<void> forceFullSync() async {
    if (!isOnline.value) {
      Get.snackbar(
        'Sync Error',
        'No internet connection available',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
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
    lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(savedTime);
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'isOnline': isOnline.value,
      'isSyncing': isSyncing.value,
      'syncStatus': syncStatus.value,
      'lastSyncTime': lastSyncTime.value,
      'syncTables': _syncTables,
    };
  }

  /// Clear all local data and re-download from Firebase
  Future<void> resetAndResync() async {
    if (!isOnline.value) {
      Get.snackbar(
        'Reset Error',
        'No internet connection available',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    try {
      isSyncing.value = true;
      syncStatus.value = 'Resetting Data...';

      final db = await DatabaseHelper.instance.database;

      // Clear all synced tables
      for (String table in _syncTables) {
        try {
          await db.delete(table);
          print('Cleared table: $table');
        } catch (e) {
          print('Error clearing $table: $e');
        }
      }

      // Reset sync time and force full download
      lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(0);
      await _downloadChanges();

      lastSyncTime.value = DateTime.now();
      await _saveLastSyncTime();

      syncStatus.value = 'Reset Complete';

      Get.snackbar(
        'Reset Complete',
        'Data has been reset and re-synchronized',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
      );
    } catch (e) {
      print('Reset error: $e');
      syncStatus.value = 'Reset Failed';

      Get.snackbar(
        'Reset Error',
        'Failed to reset data: ${e.toString()}',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isSyncing.value = false;
    }
  }
}
