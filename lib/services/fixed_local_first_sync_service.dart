// lib/services/fixed_local_first_sync_service.dart
// CREATE THIS NEW FILE

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FixedLocalFirstSyncService extends GetxService {
  static FixedLocalFirstSyncService get instance =>
      Get.find<FixedLocalFirstSyncService>();

  FirebaseFirestore? _firestore;
  String? _currentDeviceId;

  // Sync state
  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Idle'.obs;
  final Rx<DateTime> lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0).obs;
  final RxBool isOnline = true.obs;
  final RxBool firebaseAvailable = false.obs;

  // Timers
  Timer? _periodicSyncTimer;
  Timer? _connectivityTimer;
  firebase_auth.FirebaseAuth? _firebaseAuth;
  // Sync tables in priority order
  final List<String> _syncTables = [
    'users', // Highest priority - needed for relationships
    'courses', // Second priority - needed for schedules/invoices
    'fleet', // Needed for schedules
    'schedules', // Depends on users, courses, fleet
    'invoices', // Depends on users, courses
    'payments', // Depends on invoices
    'billing_records', // Depends on schedules, invoices
    'notes', // Lower priority
    'notifications',
    'attachments',
    'timeline',
    'usermessages',
  ];

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initialize();
    _setupConnectivityMonitoring();
    _setupPeriodicSync();
  }

  Future<void> _initialize() async {
    try {
      _firestore = FirebaseFirestore.instance;
      _currentDeviceId = await _getOrCreateDeviceId();
      firebaseAvailable.value = true;
      print(
          '✅ Fixed sync service initialized with device ID: $_currentDeviceId');
    } catch (e) {
      print('❌ Failed to initialize fixed sync service: $e');
      firebaseAvailable.value = false;
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = await _generateDeviceId();
      await prefs.setString('device_id', deviceId);
      print('🆔 Generated new device ID: $deviceId');
    }

    return deviceId;
  }

  Future<String> _generateDeviceId() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Simple device ID for mobile
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final random = (timestamp % 10000).toString();
        return '${Platform.isAndroid ? 'android' : 'ios'}_$random';
      } else {
        // Fallback for other platforms
        return 'device_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  void _setupConnectivityMonitoring() {
    _connectivityTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      isOnline.value = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      isOnline.value = false;
    }
  }

  void _setupPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (isOnline.value && !isSyncing.value && firebaseAvailable.value) {
        syncWithFirebase().catchError((e) {
          print('⚠️ Periodic sync failed: $e');
        });
      }
    });
    print('⏰ Periodic sync configured (every 5 minutes)');
  }

  Future<void> triggerManualSync() async {
    return await syncWithFirebase();
  }

  /// MAIN SYNC METHOD - Fixed local-first approach
  Future<void> syncWithFirebase() async {
    if (isSyncing.value || _firestore == null || _currentDeviceId == null) {
      print('⚠️ Sync already in progress or service not initialized');
      return;
    }

    isSyncing.value = true;
    syncStatus.value = 'Starting sync...';

    try {
      print('🔄 === FIXED LOCAL FIRST SYNC STARTED ===');
      print('📱 Device ID: $_currentDeviceId');

      final schoolId = await _getSchoolId();
      if (schoolId.isEmpty) {
        throw Exception('School ID not configured');
      }

      // CRITICAL FIX: Pull and merge FIRST, then push
      await _pullAndMergeRemoteChanges(schoolId);
      await _pushLocalChangesToFirebase(schoolId);

      lastSyncTime.value = DateTime.now();
      syncStatus.value = 'Sync completed successfully';

      // Update sync metadata
      await _updateSyncMetadata();

      print('✅ === FIXED LOCAL FIRST SYNC COMPLETED ===');
    } catch (e) {
      print('❌ Sync failed: $e');
      syncStatus.value = 'Sync failed: ${e.toString()}';
      rethrow;
    } finally {
      isSyncing.value = false;
    }
  }

  /// STEP 1: Pull and intelligently merge remote changes
  Future<void> _pullAndMergeRemoteChanges(String schoolId) async {
    print('📥 === PULLING AND MERGING REMOTE CHANGES ===');
    syncStatus.value = 'Pulling remote changes...';

    int totalProcessed = 0;
    int totalInserted = 0;
    int totalUpdated = 0;
    int totalConflicts = 0;
    int totalSkipped = 0;

    for (final table in _syncTables) {
      try {
        print('📥 Processing $table...');

        final results = await _pullAndMergeTable(schoolId, table);

        totalProcessed += results['processed'] ?? 0;
        totalInserted += results['inserted'] ?? 0;
        totalUpdated += results['updated'] ?? 0;
        totalConflicts += results['conflicts'] ?? 0;
        totalSkipped += results['skipped'] ?? 0;
      } catch (e) {
        print('❌ Error processing $table: $e');
      }
    }

    print(
        '📊 PULL SUMMARY: $totalProcessed processed, $totalInserted inserted, $totalUpdated updated, $totalConflicts conflicts, $totalSkipped skipped');
  }

  /// Pull and merge a specific table
  Future<Map<String, int>> _pullAndMergeTable(
      String schoolId, String table) async {
    int processed = 0, inserted = 0, updated = 0, conflicts = 0, skipped = 0;

    try {
      final snapshot = await _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection(table)
          .get();

      print('📥 Found ${snapshot.docs.length} $table records in Firebase');

      for (final doc in snapshot.docs) {
        final result =
            await _mergeRecordWithConflictResolution(table, doc.id, doc.data());

        processed++;
        switch (result) {
          case MergeResult.inserted:
            inserted++;
            break;
          case MergeResult.updated:
            updated++;
            break;
          case MergeResult.conflict:
            conflicts++;
            break;
          case MergeResult.skipped:
            skipped++;
            break;
        }
      }

      print(
          '✅ $table: $processed processed, $inserted inserted, $updated updated, $conflicts conflicts, $skipped skipped');
    } catch (e) {
      print('❌ Error pulling $table: $e');
    }

    return {
      'processed': processed,
      'inserted': inserted,
      'updated': updated,
      'conflicts': conflicts,
      'skipped': skipped,
    };
  }
// Fixed _convertFirestoreToSqlite method for FixedLocalFirstSyncService
// Replace your existing _convertFirestoreToSqlite method with this comprehensive version

  /// COMPREHENSIVE: Convert Firestore data to SQLite format with complete timestamp handling
  Map<String, dynamic> _convertFirestoreToSqlite(Map<String, dynamic> data) {
    try {
      final result = Map<String, dynamic>.from(data);

      // Remove Firebase-specific fields that don't exist in local schema
      result.remove('school_id');
      result.remove('school_name');
      result.remove('sync_timestamp');
      result.remove('updatedAt');
      result.remove('firebase_user_id'); // Remove if it exists

      print('🔄 Converting Firestore data to SQLite format...');
      print('📥 Original data keys: ${data.keys.toList()}');

      // CRITICAL: Convert ALL timestamp fields comprehensively
      _convertTimestampField(result, 'created_at', isDateString: true);
      _convertTimestampField(result, 'last_modified', isDateString: false);
      _convertTimestampField(result, 'date_of_birth', isDateString: true);
      _convertTimestampField(result, 'due_date', isDateString: true);
      _convertTimestampField(result, 'payment_date', isDateString: true);
      _convertTimestampField(result, 'start', isDateString: true);
      _convertTimestampField(result, 'end', isDateString: true);
      _convertTimestampField(result, 'updated_at', isDateString: false);
      _convertTimestampField(result, 'last_login', isDateString: false);

      // Convert boolean values to integers for SQLite
      result.forEach((key, value) {
        if (value is bool) {
          result[key] = value ? 1 : 0;
          print('📄 Converted boolean $key: $value -> ${result[key]}');
        }
      });

      // Handle any remaining Timestamp objects that might have been missed
      result.forEach((key, value) {
        if (value is Timestamp) {
          print('⚠️ Found unexpected Timestamp in field $key, converting...');
          result[key] = value.toDate().toIso8601String();
        } else if (value is Map<String, dynamic>) {
          // Handle nested objects that might contain Timestamps
          result[key] = _convertNestedTimestamps(value);
        } else if (value is List) {
          // Handle lists that might contain Timestamps
          result[key] = _convertListTimestamps(value);
        }
      });

      // Mark as synced from Firebase
      result['firebase_synced'] = 1;

      print('✅ Converted data keys: ${result.keys.toList()}');
      return result;
    } catch (e) {
      print('❌ Error in _convertFirestoreToSqlite: $e');
      print('🔍 Problematic data: $data');
      rethrow;
    }
  }

  /// Convert a specific timestamp field with proper error handling
  void _convertTimestampField(Map<String, dynamic> data, String fieldName,
      {bool isDateString = true}) {
    if (!data.containsKey(fieldName)) return;

    final value = data[fieldName];
    if (value == null) {
      data.remove(fieldName);
      return;
    }

    try {
      if (value is Timestamp) {
        final dateTime = value.toDate();
        data[fieldName] = isDateString
            ? dateTime.toIso8601String()
            : dateTime.millisecondsSinceEpoch;
        print('📅 Converted $fieldName: Timestamp -> ${data[fieldName]}');
      } else if (value is Map<String, dynamic>) {
        // Handle Firestore Timestamp format: {seconds: x, nanoseconds: y}
        if (value.containsKey('seconds') && value.containsKey('nanoseconds')) {
          final seconds = value['seconds'] as int;
          final nanoseconds = value['nanoseconds'] as int;
          final dateTime = DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + (nanoseconds / 1000000).round());
          data[fieldName] = isDateString
              ? dateTime.toIso8601String()
              : dateTime.millisecondsSinceEpoch;
          print('📅 Converted $fieldName: Map -> ${data[fieldName]}');
        }
      } else if (value is String) {
        // Validate and potentially convert string dates
        try {
          final dateTime = DateTime.parse(value);
          data[fieldName] = isDateString
              ? dateTime.toIso8601String()
              : dateTime.millisecondsSinceEpoch;
        } catch (e) {
          print('⚠️ Invalid date string in $fieldName: $value');
          // Keep original string value
        }
      } else if (value is int && !isDateString) {
        // Already in correct format for milliseconds
        data[fieldName] = value;
      } else if (value is int && isDateString) {
        // Convert milliseconds to ISO string
        data[fieldName] =
            DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
      }
    } catch (e) {
      print('❌ Error converting $fieldName: $e');
      print('🔍 Value: $value (${value.runtimeType})');
      // Remove problematic field rather than crash
      data.remove(fieldName);
    }
  }

  /// Convert nested objects that might contain Timestamps
  Map<String, dynamic> _convertNestedTimestamps(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);

    result.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is bool) {
        result[key] = value ? 1 : 0;
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertNestedTimestamps(value);
      } else if (value is List) {
        result[key] = _convertListTimestamps(value);
      }
    });

    return result;
  }

  /// Convert lists that might contain Timestamps
  List<dynamic> _convertListTimestamps(List<dynamic> list) {
    return list.map((item) {
      if (item is Timestamp) {
        return item.toDate().toIso8601String();
      } else if (item is bool) {
        return item ? 1 : 0;
      } else if (item is Map<String, dynamic>) {
        return _convertNestedTimestamps(item);
      } else if (item is List) {
        return _convertListTimestamps(item);
      }
      return item;
    }).toList();
  }

  /// Enhanced merge method with better error handling
  Future<MergeResult> _mergeRecordWithConflictResolution(
    String table,
    String docId,
    Map<String, dynamic> remoteData,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localId = int.tryParse(docId);

      if (localId == null) {
        print('⚠️ Invalid record ID for $table: $docId');
        return MergeResult.skipped;
      }

      // Convert remote data to local format with comprehensive timestamp handling
      Map<String, dynamic> localData;
      try {
        localData = _convertFirestoreToSqlite(remoteData);
      } catch (e) {
        print('❌ Failed to convert $table record $docId: $e');
        return MergeResult.skipped;
      }

      // Ensure the record has a valid ID
      localData['id'] = localId;

      // Check if record exists locally
      final existing = await db.query(
        table,
        where: 'id = ?',
        whereArgs: [localId],
        limit: 1,
      );

      if (existing.isEmpty) {
        // Insert new record
        try {
          await db.insert(table, localData,
              conflictAlgorithm: ConflictAlgorithm.replace);
          print('✅ Inserted new $table record: $localId');
          return MergeResult.inserted;
        } catch (e) {
          print('❌ Failed to insert $table record $localId: $e');
          print('🔍 Data that failed: $localData');
          return MergeResult.skipped;
        }
      } else {
        // Update existing record with conflict resolution
        final localRecord = existing.first;
        final shouldUpdate =
            _shouldUpdateRecord(localRecord, remoteData, table, localId);

        if (shouldUpdate) {
          try {
            await db.update(
              table,
              localData,
              where: 'id = ?',
              whereArgs: [localId],
            );
            print('✅ Updated $table record: $localId');
            return MergeResult.updated;
          } catch (e) {
            print('❌ Failed to update $table record $localId: $e');
            print('🔍 Data that failed: $localData');
            return MergeResult.skipped;
          }
        } else {
          print('⏭️ Skipped $table record $localId (no update needed)');
          return MergeResult.skipped;
        }
      }
    } catch (e) {
      print(
          '❌ Error in _mergeRecordWithConflictResolution for $table $docId: $e');
      return MergeResult.skipped;
    }
  }

  /// Determine if a record should be updated based on timestamps
  bool _shouldUpdateRecord(
    Map<String, dynamic> localRecord,
    Map<String, dynamic> remoteData,
    String table,
    int recordId,
  ) {
    try {
      // Get timestamps for comparison
      final localTimestamp =
          _getTimestampAsInt(localRecord['last_modified']) ?? 0;
      final remoteTimestamp =
          _getTimestampAsInt(remoteData['last_modified']) ?? 0;

      print('🔍 CONFLICT ANALYSIS for $table record $recordId:');
      print(
          'Local: modified=${DateTime.fromMillisecondsSinceEpoch(localTimestamp)}, synced=${localRecord['firebase_synced']}, device=${localRecord['last_modified_device']}');
      print(
          'Remote: modified=${DateTime.fromMillisecondsSinceEpoch(remoteTimestamp)}, device=${remoteData['last_modified_device']}');

      // If remote is newer, update
      if (remoteTimestamp > localTimestamp) {
        print('✅ Remote is newer, will update');
        return true;
      }

      // If local is newer and already synced, skip
      if (localTimestamp > remoteTimestamp &&
          localRecord['firebase_synced'] == 1) {
        print('⏭️ Local is newer and synced, skipping');
        return false;
      }

      // If timestamps are equal but local isn't synced, update to mark as synced
      if (localTimestamp == remoteTimestamp &&
          localRecord['firebase_synced'] != 1) {
        print('🔄 Same timestamp but not synced, will update');
        return true;
      }

      print('⏭️ No update needed');
      return false;
    } catch (e) {
      print('❌ Error comparing timestamps: $e');
      return true; // When in doubt, update
    }
  }

  /// Insert new record from remote
  Future<MergeResult> _insertNewRecord(Database db, String table, int localId,
      Map<String, dynamic> localData) async {
    try {
      localData['id'] = localId;
      localData['firebase_synced'] = 1;

      await db.insert(table, localData);
      print('➕ Inserted new $table record: $localId');
      return MergeResult.inserted;
    } catch (e) {
      print('❌ Failed to insert $table record $localId: $e');
      return MergeResult.skipped;
    }
  }

  /// ADVANCED: Resolve conflicts between local and remote data
  Future<MergeResult> _resolveConflict(
    Database db,
    String table,
    int localId,
    Map<String, dynamic> localRecord,
    Map<String, dynamic> remoteData,
  ) async {
    // Extract conflict resolution data
    final localLastModified = localRecord['last_modified'] as int? ?? 0;
    final remoteLastModified =
        _getTimestampAsInt(remoteData['last_modified']) ?? 0;
    final localSynced = localRecord['firebase_synced'] as int? ?? 1;
    final localDevice = localRecord['last_modified_device'] as String?;
    final remoteDevice = remoteData['last_modified_device'] as String?;

    print('🔍 CONFLICT ANALYSIS for $table record $localId:');
    print(
        '   Local: modified=${DateTime.fromMillisecondsSinceEpoch(localLastModified)}, synced=$localSynced, device=$localDevice');
    print(
        '   Remote: modified=${DateTime.fromMillisecondsSinceEpoch(remoteLastModified)}, device=$remoteDevice');

    // RULE 1: Local has unsynced changes - check timestamps
    if (localSynced == 0) {
      if (localLastModified > remoteLastModified) {
        await _logConflict(table, localId, 'LOCAL_WINS_NEWER_UNSYNCED',
            localLastModified, remoteLastModified);
        print('   ✅ LOCAL WINS: Newer unsynced changes');
        return MergeResult.skipped;
      } else if (localLastModified == remoteLastModified &&
          localDevice == _currentDeviceId) {
        await _logConflict(
            table,
            localId,
            'LOCAL_WINS_SAME_TIMESTAMP_LOCAL_DEVICE',
            localLastModified,
            remoteLastModified);
        print('   ✅ LOCAL WINS: Same timestamp, local device');
        return MergeResult.skipped;
      }
    }

    // RULE 2: Remote wins in most other cases
    if (remoteLastModified >= localLastModified || localSynced == 1) {
      remoteData['firebase_synced'] = 1;
      remoteData.remove('id');

      await db.update(
        table,
        remoteData,
        where: 'id = ?',
        whereArgs: [localId],
      );

      final reason = remoteLastModified > localLastModified
          ? 'REMOTE_NEWER'
          : 'LOCAL_ALREADY_SYNCED';
      await _logConflict(
          table, localId, reason, localLastModified, remoteLastModified);
      print('   ✅ REMOTE WINS: $reason');
      return localSynced == 0 ? MergeResult.conflict : MergeResult.updated;
    }

    return MergeResult.skipped;
  }

  /// STEP 2: Push only unsynced local changes
  Future<void> _pushLocalChangesToFirebase(String schoolId) async {
    print('📤 === PUSHING LOCAL CHANGES ===');
    syncStatus.value = 'Pushing local changes...';

    int totalPushed = 0;

    for (final table in _syncTables) {
      final pushed = await _pushTableToFirebase(schoolId, table);
      totalPushed += pushed;
    }

    print('📊 PUSH SUMMARY: $totalPushed records pushed to Firebase');
  }

  /// Push unsynced records from a table
  Future<int> _pushTableToFirebase(String schoolId, String table) async {
    final db = await DatabaseHelper.instance.database;

    // Get ONLY unsynced records
    final unsyncedRecords = await db.query(
      table,
      where:
          '(firebase_synced = ? OR firebase_synced IS NULL) AND (deleted IS NULL OR deleted = 0)',
      whereArgs: [0],
    );

    if (unsyncedRecords.isEmpty) {
      return 0;
    }

    print('📤 Pushing ${unsyncedRecords.length} unsynced $table records');

    int successCount = 0;
    for (final record in unsyncedRecords) {
      try {
        await _pushSingleRecordToFirebase(schoolId, table, record);
        successCount++;
      } catch (e) {
        print('❌ Failed to push $table record ${record['id']}: $e');
      }
    }

    print('✅ Pushed $successCount/${unsyncedRecords.length} $table records');
    return successCount;
  }

  /// Push single record to Firebase
  Future<void> _pushSingleRecordToFirebase(
    String schoolId,
    String table,
    Map<String, dynamic> record,
  ) async {
    final recordId = record['id'].toString();

    // Convert to Firebase format
    final firebaseData = _convertSqliteToFirestore(record);

    // Add/update device tracking
    firebaseData['last_modified_device'] = _currentDeviceId;
    firebaseData['last_modified'] = FieldValue.serverTimestamp();

    // Push to Firebase
    await _firestore!
        .collection('schools')
        .doc(schoolId)
        .collection(table)
        .doc(recordId)
        .set(firebaseData, SetOptions(merge: true));

    // Mark as synced locally
    final db = await DatabaseHelper.instance.database;
    await db.update(
      table,
      {'firebase_synced': 1},
      where: 'id = ?',
      whereArgs: [int.parse(recordId)],
    );
  }

  /// Log conflicts for debugging and analysis
  Future<void> _logConflict(String table, int recordId, String resolution,
      int localTimestamp, int remoteTimestamp) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('sync_conflicts', {
        'table_name': table,
        'record_id': recordId,
        'conflict_type': resolution,
        'local_timestamp': localTimestamp,
        'remote_timestamp': remoteTimestamp,
        'local_device': _currentDeviceId,
        'remote_device': 'unknown',
        'resolution': resolution,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ Could not log conflict: $e');
    }
  }

  /// Update sync metadata
  Future<void> _updateSyncMetadata() async {
    try {
      final db = await DatabaseHelper.instance.database;

      for (final table in _syncTables) {
        final total = await db.rawQuery(
            'SELECT COUNT(*) as count FROM $table WHERE deleted IS NULL OR deleted = 0');
        final synced = await db.rawQuery(
            'SELECT COUNT(*) as count FROM $table WHERE firebase_synced = 1 AND (deleted IS NULL OR deleted = 0)');

        await db.execute('''
          UPDATE sync_metadata 
          SET last_sync_timestamp = ?, 
              last_sync_device = ?,
              total_records = ?,
              synced_records = ?,
              updated_at = CURRENT_TIMESTAMP
          WHERE table_name = ?
        ''', [
          DateTime.now().millisecondsSinceEpoch,
          _currentDeviceId,
          total.first['count'],
          synced.first['count'],
          table
        ]);
      }
    } catch (e) {
      print('⚠️ Could not update sync metadata: $e');
    }
  }

  Map<String, dynamic> _convertSqliteToFirestore(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Remove SQLite-specific fields
    result.remove('firebase_synced');
    result.remove('id');

    // Convert timestamps
    if (result['created_at'] is String) {
      try {
        result['created_at'] = DateTime.parse(result['created_at']);
      } catch (e) {
        result['created_at'] = DateTime.now();
      }
    }

    // Ensure last_modified is set
    result['last_modified'] = FieldValue.serverTimestamp();
    result['last_modified_device'] = _currentDeviceId;

    // Remove null values
    result.removeWhere((key, value) => value == null);
    return result;
  }

// FIXED: Replace your _syncSingleUserToFirebase method with this
  Future<void> _syncSingleUserToFirebase(Map<String, dynamic> localUser) async {
    if (_firestore == null || _firebaseAuth == null) return;

    try {
      final email = localUser['email']?.toString().toLowerCase();
      final localId = localUser['id'];
      final existingFirebaseUid = localUser['firebase_uid'];

      if (email == null || email.isEmpty) {
        print('❌ Cannot sync user: no email found');
        return;
      }

      // Skip if already marked as synced AND has Firebase UID
      final alreadySynced = localUser['firebase_synced'] == 1;
      if (alreadySynced &&
          existingFirebaseUid != null &&
          existingFirebaseUid.isNotEmpty) {
        print(
            '✅ User already synced, skipping: $email (Firebase UID: $existingFirebaseUid)');
        return;
      }

      print('🔄 Syncing user to Firebase: $email (Local ID: $localId)');

      final schoolConfig = Get.find<SchoolConfigService>();
      final schoolId = schoolConfig.schoolId.value;

      if (schoolId.isEmpty) {
        print('❌ No school ID available for sync');
        return;
      }

      // Check if user already exists in Firestore by email first
      final existingByEmailQuery = await _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingByEmailQuery.docs.isNotEmpty) {
        print('📋 User already exists in Firestore: $email');

        // Update local record with Firebase info and mark as synced
        final existingDoc = existingByEmailQuery.docs.first;
        final firestoreData = existingDoc.data();
        final firebaseUid = firestoreData['firebase_uid'];

        if (firebaseUid != null) {
          final db = await DatabaseHelper.instance.database;
          await db.update(
            'users',
            {
              'firebase_synced': 1,
              'firebase_uid': firebaseUid,
            },
            where: 'id = ?',
            whereArgs: [localId],
          );
          print('✅ Local user updated with existing Firebase info');
        }
        return;
      }

      // If we have existing Firebase UID, use it for the document
      String? firebaseUid = existingFirebaseUid;

      // If no Firebase UID, we need to create/find Firebase Auth user
      if (firebaseUid == null || firebaseUid.isEmpty) {
        // This would require additional logic to handle Firebase Auth creation
        // For now, let's skip users without Firebase UID during sync
        print('⚠️ Skipping sync for user without Firebase UID: $email');
        return;
      }

      // Prepare Firestore data
      final firestoreData = _convertSqliteToFirestore(localUser);
      firestoreData['firebase_uid'] = firebaseUid;
      firestoreData['local_id'] = localId;
      firestoreData['last_modified'] = DateTime.now().toIso8601String();
      firestoreData['firebase_synced'] = 1;
      firestoreData['school_id'] = schoolId;

      // Use Firebase UID as document ID for consistency
      final userDocRef = _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(firebaseUid);

      await userDocRef.set(firestoreData, SetOptions(merge: true));
      print('✅ User synced to Firestore: $email (Doc ID: $firebaseUid)');

      // Mark as synced in local database
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'users',
        {'firebase_synced': 1},
        where: 'id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      print('❌ Error syncing user to Firebase: $e');
    }
  }

  int? _getTimestampAsInt(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is int) return timestamp;
    if (timestamp is Timestamp) return timestamp.millisecondsSinceEpoch;
    if (timestamp is DateTime) return timestamp.millisecondsSinceEpoch;
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp).millisecondsSinceEpoch;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<String> _getSchoolId() async {
    try {
      final schoolConfig = SchoolConfigService.instance;
      if (!schoolConfig.isInitialized.value) {
        await schoolConfig.initializeSchoolConfig();
      }
      return schoolConfig.schoolId.value;
    } catch (e) {
      print('❌ Could not get school ID: $e');
      return '';
    }
  }

  static Timer? _syncTimer;

  static void _triggerSmartSync() {
    // Cancel previous timer to debounce rapid changes
    _syncTimer?.cancel();

    // Wait 3 seconds after last change before syncing
    _syncTimer = Timer(const Duration(seconds: 3), () {
      try {
        // Use only the new fixed sync service
        if (Get.isRegistered<FixedLocalFirstSyncService>()) {
          final syncService = Get.find<FixedLocalFirstSyncService>();
          if (!syncService.isSyncing.value &&
              syncService.isOnline.value &&
              syncService.firebaseAvailable.value) {
            syncService.syncWithFirebase().catchError((e) {
              print('⚠️ Smart sync failed: $e');
            });
          }
        } else {
          print('⚠️ Fixed sync service not available');
        }
      } catch (e) {
        print('⚠️ Could not trigger smart sync: $e');
      }
    });
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

  SchoolConfigService get _schoolConfig => SchoolConfigService.instance;

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
        // Additional business fields (optional but good to have)
        'business_website': '',
        'subscription_status': 'active',
      };

      await schoolMetaRef.set(schoolMetadata, SetOptions(merge: true));
      print('✅ School metadata created/updated');
    } catch (e) {
      print('❌ Error creating school metadata: $e');
    }
  }

  @override
  void onClose() {
    _periodicSyncTimer?.cancel();
    _connectivityTimer?.cancel();
    super.onClose();
  }
}

enum MergeResult { inserted, updated, conflict, skipped }
