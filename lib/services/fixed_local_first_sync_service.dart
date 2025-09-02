// lib/services/fixed_local_first_sync_service.dart
// CREATE THIS NEW FILE

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/utils/timestamp_converter.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/deduplication_sync_service.dart';
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

// Call this in your initialization
  Future<void> _initialize() async {
    try {
      _firestore = FirebaseFirestore.instance;
      _currentDeviceId = await _getOrCreateDeviceId();
      firebaseAvailable.value = true;

      final schoolId = await _getSchoolId();
      if (schoolId.isNotEmpty) {
        _setupRealTimeListeners(schoolId); // ← ADD THIS
      }

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

  Future<void> syncWithFirebase() async {
    if (isSyncing.value || _firestore == null || _currentDeviceId == null) {
      print('⚠️ Sync already in progress or service not initialized');
      return;
    }

    isSyncing.value = true;
    syncStatus.value = 'Starting sync...';

    try {
      print('🔄 === FIXED LOCAL FIRST SYNC STARTED ===');

      final schoolId = await _getSchoolId();
      if (schoolId.isEmpty) {
        throw Exception('School ID not configured');
      }

      // CRITICAL: Sync deleted records first
      await _syncDeletedRecords(schoolId);

      // Then pull and merge remote changes
      await _pullAndMergeRemoteChanges(schoolId);

      // Finally push local changes
      await _pushLocalChangesToFirebase(schoolId);

      lastSyncTime.value = DateTime.now();
      syncStatus.value = 'Sync completed successfully';

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

  // Add this to your FixedLocalFirstSyncService class
// Replace your existing _pullAndMergeRemoteChanges method with this fixed version:

  Future<void> _pullAndMergeRemoteChanges(String schoolId) async {
    print('📥 === PULLING AND MERGING REMOTE CHANGES ===');
    syncStatus.value = 'Pulling remote changes...';

    int totalProcessed = 0;
    int totalInserted = 0;
    int totalUpdated = 0;

    for (final table in _syncTables) {
      try {
        print('📥 Processing $table...');

        // GET RECORDS WITH SERVER TIMESTAMP CHECK
        final lastPullTime = await _getLastPullTimestamp(table);
        print(
            '🕐 Last pull time for $table: ${DateTime.fromMillisecondsSinceEpoch(lastPullTime)}');

        // Convert to Firestore timestamp for query
        final lastPullTimestamp =
            Timestamp.fromMillisecondsSinceEpoch(lastPullTime);

        // Use proper timestamp comparison with Firestore Timestamp
        final querySnapshot = await _firestore!
            .collection('schools')
            .doc(schoolId)
            .collection(table)
            .where('last_modified', isGreaterThan: lastPullTimestamp)
            .get();

        print(
            '📥 Found ${querySnapshot.docs.length} updated $table records in Firebase since last pull');

        for (final doc in querySnapshot.docs) {
          final remoteData = doc.data();

          // ✅ FIXED: Use improved timestamp conversion
          final remoteTimestamp =
              _getTimestampAsInt(remoteData['last_modified']);

          if (remoteTimestamp == null) {
            print('⚠️ Skipping ${table} record ${doc.id}: invalid timestamp');
            continue;
          }

          // DEBUG: Check if this record should be processed
          if (remoteTimestamp <= lastPullTime) {
            print(
                '⏭️ Skipping ${table} record ${doc.id}: timestamp $remoteTimestamp <= last pull $lastPullTime');
            continue;
          }

          print('📄 Processing ${table} record ${doc.id}');
          print(
              '   Remote timestamp: $remoteTimestamp (${DateTime.fromMillisecondsSinceEpoch(remoteTimestamp)})');
          print(
              '   Last pull time: $lastPullTime (${DateTime.fromMillisecondsSinceEpoch(lastPullTime)})');

          // ✅ FIXED: Use safe merge with proper error handling
          final result = await _safelyMergeRecord(table, doc.id, remoteData);

          if (result == MergeResult.inserted) totalInserted++;
          if (result == MergeResult.updated) totalUpdated++;
          totalProcessed++;
        }

        // Update last pull timestamp for this table
        await _updateLastPullTimestamp(table);
      } catch (e) {
        print('❌ Error processing $table: $e');
        // Continue with other tables instead of failing completely
      }
    }

    print(
        '📊 PULL SUMMARY: $totalProcessed processed, $totalInserted inserted, $totalUpdated updated');
  }

// ✅ ENHANCED: Improved timestamp conversion with better error handling
  int? _getTimestampAsInt(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      // Handle integer timestamps (already in milliseconds)
      if (timestamp is int) return timestamp;

      // Handle Firestore Timestamp objects
      if (timestamp is Timestamp) return timestamp.millisecondsSinceEpoch;

      // Handle DateTime objects
      if (timestamp is DateTime) return timestamp.millisecondsSinceEpoch;

      // Handle string timestamps
      if (timestamp is String) {
        // Handle ISO string format
        if (timestamp.contains('T') || timestamp.contains('-')) {
          return DateTime.parse(timestamp).millisecondsSinceEpoch;
        }
        // Handle numeric string
        final parsed = int.tryParse(timestamp);
        if (parsed != null) return parsed;
      }

      // Handle Map format (Firestore Timestamp serialized)
      if (timestamp is Map<String, dynamic>) {
        if (timestamp.containsKey('seconds') &&
            timestamp.containsKey('nanoseconds')) {
          final seconds = timestamp['seconds'] as int;
          final nanoseconds = timestamp['nanoseconds'] as int;
          return seconds * 1000 + (nanoseconds ~/ 1000000);
        }
      }

      // ✅ NEW: Handle the specific error format from your logs
      if (timestamp.toString().contains('Timestamp(seconds=')) {
        final match = RegExp(r'seconds=(\d+)').firstMatch(timestamp.toString());
        if (match != null) {
          final seconds = int.parse(match.group(1)!);
          return seconds * 1000; // Convert to milliseconds
        }
      }
    } catch (e) {
      print(
          '❌ Error converting timestamp: $timestamp (${timestamp.runtimeType}) - $e');
    }

    return null;
  }

// ✅ NEW: Safe record merging to prevent crashes
  Future<MergeResult> _safelyMergeRecord(
    String table,
    String docId,
    Map<String, dynamic> remoteData,
  ) async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Convert Firebase data to SQLite format
      final localData = _convertFirestoreToSqlite(remoteData);
      final localId = int.tryParse(docId);

      if (localId == null) {
        print('❌ Invalid document ID for $table: $docId');
        return MergeResult.skipped;
      }

      localData['id'] = localId;

      // ✅ ENHANCED: Fleet-specific deduplication by carplate
      if (table == 'fleet') {
        return await _mergeFleetRecordWithPlateDeduplication(db, localData);
      }

      // ✅ ENHANCED: User-specific deduplication by email/idnumber
      if (table == 'users') {
        return await _mergeUserRecordWithEmailDeduplication(db, localData);
      }

      // ✅ ENHANCED: General deduplication for other tables
      return await _mergeRecordWithTimestampComparison(db, table, localData);
    } catch (e) {
      print('❌ Error in _safelyMergeRecord for $table $docId: $e');
      print('🔍 Remote data: $remoteData');
      return MergeResult.skipped;
    }
  }

  Future<MergeResult> _mergeFleetRecordWithPlateDeduplication(
    Database db,
    Map<String, dynamic> fleetData,
  ) async {
    final carplate = fleetData['carplate'];
    final fleetId = fleetData['id'];

    if (carplate == null || carplate == '') {
      print('⚠️ Fleet record missing carplate, using ID-based merge');
      return await _mergeRecordWithTimestampComparison(db, 'fleet', fleetData);
    }

    try {
      // Check for existing fleet by carplate (more reliable than ID)
      final existingByCarplate = await db.query(
        'fleet',
        where: 'carplate = ?',
        whereArgs: [carplate],
        limit: 1,
      );

      if (existingByCarplate.isEmpty) {
        // No existing fleet with this carplate - safe to insert
        await db.insert('fleet', fleetData,
            conflictAlgorithm: ConflictAlgorithm.replace);
        print('🚗 INSERTED new fleet: $carplate (ID: $fleetId)');
        return MergeResult.inserted;
      }

      final existingFleet = existingByCarplate.first;
      final existingId = existingFleet['id'];

      // Compare timestamps to decide whether to update
      final remoteTimestamp =
          _getTimestampAsInt(fleetData['last_modified']) ?? 0;
      final localTimestamp =
          _getTimestampAsInt(existingFleet['last_modified']) ?? 0;

      print(
          '🚗 Fleet carplate "$carplate": Remote ID $fleetId vs Local ID $existingId');
      print('   Remote timestamp: $remoteTimestamp');
      print('   Local timestamp: $localTimestamp');

      if (remoteTimestamp > localTimestamp) {
        // Remote is newer - update the existing record
        await db.update(
          'fleet',
          fleetData,
          where: 'carplate = ?',
          whereArgs: [carplate],
        );
        print('🔄 UPDATED fleet: $carplate with newer remote data');
        return MergeResult.updated;
      } else if (remoteTimestamp < localTimestamp) {
        // Local is newer - keep local version
        print('⏭️ SKIPPED fleet: $carplate (local is newer)');
        return MergeResult.skipped;
      } else {
        // Same timestamp - mark as synced if needed
        final localSynced = (existingFleet['firebase_synced'] as int?) ?? 1;
        if (localSynced == 0) {
          await db.update(
            'fleet',
            {'firebase_synced': 1},
            where: 'carplate = ?',
            whereArgs: [carplate],
          );
          print('✅ MARKED fleet as synced: $carplate');
          return MergeResult.updated;
        }
        print('⏭️ SKIPPED fleet: $carplate (already synced)');
        return MergeResult.skipped;
      }
    } catch (e) {
      print('❌ Error merging fleet record: $e');
      return MergeResult.skipped;
    }
  }

  /// ✅ NEW: User-specific merge with email deduplication
  Future<MergeResult> _mergeUserRecordWithEmailDeduplication(
    Database db,
    Map<String, dynamic> userData,
  ) async {
    final email = userData['email'];
    final idnumber = userData['idnumber'];
    final userId = userData['id'];

    if ((email == null || email == '') &&
        (idnumber == null || idnumber == '')) {
      print('⚠️ User record missing email and ID number, using ID-based merge');
      return await _mergeRecordWithTimestampComparison(db, 'users', userData);
    }

    try {
      // Check for existing user by email or idnumber
      List<Map<String, dynamic>> existingUsers = [];

      if (email != null && email != '') {
        final emailMatches = await db.query(
          'users',
          where: 'email = ?',
          whereArgs: [email],
        );
        existingUsers.addAll(emailMatches);
      }

      if (idnumber != null && idnumber != '') {
        final idMatches = await db.query(
          'users',
          where: 'idnumber = ? AND email != ?',
          whereArgs: [idnumber, email ?? ''],
        );
        existingUsers.addAll(idMatches);
      }

      if (existingUsers.isEmpty) {
        // No existing user - safe to insert
        await db.insert('users', userData,
            conflictAlgorithm: ConflictAlgorithm.replace);
        print('👤 INSERTED new user: $email (ID: $userId)');
        return MergeResult.inserted;
      }

      // Use the first matching user for comparison
      final existingUser = existingUsers.first;
      final existingId = existingUser['id'];

      // Compare timestamps
      final remoteTimestamp =
          _getTimestampAsInt(userData['last_modified']) ?? 0;
      final localTimestamp =
          _getTimestampAsInt(existingUser['last_modified']) ?? 0;

      print('👤 User "$email": Remote ID $userId vs Local ID $existingId');

      if (remoteTimestamp > localTimestamp) {
        // Update existing user
        await db.update(
          'users',
          userData,
          where: 'id = ?',
          whereArgs: [existingId],
        );
        print('🔄 UPDATED user: $email with newer remote data');
        return MergeResult.updated;
      } else {
        print('⏭️ SKIPPED user: $email (local is newer or same)');
        return MergeResult.skipped;
      }
    } catch (e) {
      print('❌ Error merging user record: $e');
      return MergeResult.skipped;
    }
  }

  /// ✅ ENHANCED: General record merge with timestamp comparison
  Future<MergeResult> _mergeRecordWithTimestampComparison(
    Database db,
    String table,
    Map<String, dynamic> recordData,
  ) async {
    final recordId = recordData['id'];

    if (recordId == null) {
      print('❌ Record missing ID for $table');
      return MergeResult.skipped;
    }

    try {
      // Check if record exists by ID
      final existing = await db.query(
        table,
        where: 'id = ?',
        whereArgs: [recordId],
        limit: 1,
      );

      if (existing.isEmpty) {
        // Insert new record
        await db.insert(table, recordData,
            conflictAlgorithm: ConflictAlgorithm.replace);
        print('📥 INSERTED new $table record: $recordId');
        return MergeResult.inserted;
      }

      final existingRecord = existing.first;

      // Compare timestamps
      final remoteTimestamp =
          _getTimestampAsInt(recordData['last_modified']) ?? 0;
      final localTimestamp =
          _getTimestampAsInt(existingRecord['last_modified']) ?? 0;
      final localSynced = (existingRecord['firebase_synced'] as int?) ?? 1;

      print('🔍 $table record $recordId:');
      print('   Remote timestamp: $remoteTimestamp');
      print('   Local timestamp: $localTimestamp');
      print('   Local synced: $localSynced');

      if (remoteTimestamp > localTimestamp) {
        // Remote is newer - update local
        await db.update(
          table,
          recordData,
          where: 'id = ?',
          whereArgs: [recordId],
        );
        print('🔄 UPDATED $table record: $recordId (remote newer)');
        return MergeResult.updated;
      } else if (remoteTimestamp == localTimestamp && localSynced == 0) {
        // Same timestamp but local not synced - mark as synced
        await db.update(
          table,
          {'firebase_synced': 1},
          where: 'id = ?',
          whereArgs: [recordId],
        );
        print('✅ MARKED $table record as synced: $recordId');
        return MergeResult.updated;
      } else {
        // Local is newer or already synced
        print('⏭️ SKIPPED $table record: $recordId (local is newer/synced)');
        return MergeResult.skipped;
      }
    } catch (e) {
      print('❌ Error merging $table record: $e');
      return MergeResult.skipped;
    }
  }

// Helper methods (if you don't already have them):
  Future<int> _getLastPullTimestamp(String table) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_pull_$table') ?? 0;
    return timestamp;
  }

  Future<void> _updateLastPullTimestamp(String table) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_pull_$table', DateTime.now().millisecondsSinceEpoch);
  }

// ✅ ENHANCED: Better _convertFirestoreToSqlite method
  Map<String, dynamic> _convertFirestoreToSqlite(Map<String, dynamic> data) {
    try {
      var result = Map<String, dynamic>.from(data);

      // Remove Firebase-specific fields
      result.remove('school_id');
      result.remove('school_name');
      result.remove('sync_timestamp');
      result.remove('updatedAt');
      result.remove('firebase_user_id');
      result.remove('local_id');

      print('🔄 Converting Firestore data to SQLite format...');

      // Convert ALL timestamp fields comprehensively
      final timestampFields = [
        'created_at',
        'last_modified',
        'updated_at',
        'payment_date',
        'due_date',
        'start',
        'end',
        'date_of_birth',
        'last_login'
      ];

      for (String field in timestampFields) {
        if (result.containsKey(field)) {
          final convertedValue = _getTimestampAsInt(result[field]);
          if (convertedValue != null) {
            // For date fields, store as ISO string; for timestamps, store as int
            if (['created_at', 'date_of_birth'].contains(field)) {
              result[field] =
                  DateTime.fromMillisecondsSinceEpoch(convertedValue)
                      .toIso8601String();
            } else {
              result[field] = convertedValue;
            }
          } else {
            result.remove(field); // Remove if can't convert
          }
        }
      }

      // Convert boolean values to integers for SQLite
      result.forEach((key, value) {
        if (value is bool) {
          result[key] = value ? 1 : 0;
        }
      });

      // Mark as synced from Firebase
      result['firebase_synced'] = 1;
      result['last_modified_device'] = _currentDeviceId;

      // Remove null values
      result.removeWhere((key, value) => value == null);

      return result;
    } catch (e) {
      print('❌ Error in _convertFirestoreToSqlite: $e');
      print('🔍 Problematic data: $data');
      rethrow;
    }
  }

// Add this to your FixedLocalFirstSyncService
  final Map<String, StreamSubscription> _firestoreListeners = {};

  void _setupRealTimeListeners(String schoolId) {
    for (final table in _syncTables) {
      _firestoreListeners[table] = _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection(table)
          .snapshots()
          .listen((snapshot) {
        print('🎯 REAL-TIME UPDATE detected for $table');
        _processRealTimeChanges(table, snapshot);
      });
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

  Future<MergeResult> _mergeRecordWithConflictResolution(
    String table,
    String docId,
    Map<String, dynamic> remoteData,
  ) async {
    try {
      print('🔄 Attempting to merge $table $docId');

      final db = await DatabaseHelper.instance.database;
      final localId = int.tryParse(docId);

      if (localId == null) {
        print('⚠️ Invalid record ID for $table: $docId');
        return MergeResult.skipped;
      }

      // Convert remote data
      final localData = _convertFirestoreToSqlite(remoteData);
      localData['id'] = localId;

      // Check if record exists locally
      final existing = await db.query(
        table,
        where: 'id = ?',
        whereArgs: [localId],
        limit: 1,
      );

      if (existing.isEmpty) {
        // INSERT NEW RECORD
        try {
          await db.insert(table, localData,
              conflictAlgorithm: ConflictAlgorithm.replace);
          print('✅ INSERTED new $table record: $localId');
          return MergeResult.inserted;
        } catch (e) {
          print('❌ Failed to insert $table record $localId: $e');
          return MergeResult.skipped;
        }
      } else {
        // UPDATE EXISTING RECORD - FIXED CONFLICT RESOLUTION
        final localRecord = existing.first;

        // Get timestamps properly
        final remoteTimestamp =
            _getTimestampAsInt(remoteData['last_modified']) ?? 0;
        final localTimestamp =
            _getTimestampAsInt(localRecord['last_modified']) ?? 0;

        final localSynced = (localRecord['firebase_synced'] as int?) ?? 1;
        final localDevice = localRecord['last_modified_device']?.toString();
        final remoteDevice = remoteData['last_modified_device']?.toString();

        print('🔍 Timestamp Comparison:');
        print(
            '   Remote: $remoteTimestamp (${DateTime.fromMillisecondsSinceEpoch(remoteTimestamp)})');
        print(
            '   Local:  $localTimestamp (${DateTime.fromMillisecondsSinceEpoch(localTimestamp)})');
        print('   Local Synced: $localSynced');
        print(
            '   Devices: Local=$localDevice, Remote=$remoteDevice, Current=$_currentDeviceId');

        // CRITICAL FIX: Proper conflict resolution
        if (remoteTimestamp > localTimestamp) {
          // REMOTE IS NEWER - Update local with remote data
          try {
            await db.update(
              table,
              localData,
              where: 'id = ?',
              whereArgs: [localId],
            );
            print('✅ UPDATED $table record: $localId (remote is newer)');
            return MergeResult.updated;
          } catch (e) {
            print('❌ Failed to update $table record $localId: $e');
            return MergeResult.skipped;
          }
        } else if (remoteTimestamp < localTimestamp) {
          // LOCAL IS NEWER - Keep local data, but don't overwrite remote yet
          print('⏭️ SKIPPED $table record $localId (local is newer)');
          return MergeResult.skipped;
        } else {
          // SAME TIMESTAMP - Check sync status
          if (localSynced == 0 && localDevice == _currentDeviceId) {
            // This device made the change but hasn't synced yet
            print(
                '⏭️ SKIPPED $table record $localId (same timestamp, local unsynced change)');
            return MergeResult.skipped;
          } else {
            // Mark as synced if needed
            if (localSynced == 0) {
              await db.update(
                table,
                {'firebase_synced': 1},
                where: 'id = ?',
                whereArgs: [localId],
              );
              print('✅ MARKED SYNCED $table record: $localId (same timestamp)');
              return MergeResult.updated;
            }
            print(
                '⏭️ SKIPPED $table record $localId (same timestamp, already synced)');
          }
        }

        return MergeResult.skipped;
      }
    } catch (e) {
      print(
          '❌ Error in _mergeRecordWithConflictResolution for $table $docId: $e');
      return MergeResult.skipped;
    }
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

  /// Improved push process with better error handling and verification
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
      print('✅ $table: No unsynced records found');
      return 0;
    }

    print('📤 Pushing ${unsyncedRecords.length} unsynced $table records');

    int successCount = 0;
    int failureCount = 0;

    for (final record in unsyncedRecords) {
      // ✅ FIXED: Properly cast the record ID to int
      final recordIdRaw = record['id'];
      final int recordId;

      // Handle different possible types for ID
      if (recordIdRaw is int) {
        recordId = recordIdRaw;
      } else if (recordIdRaw is String) {
        recordId = int.parse(recordIdRaw);
      } else {
        print(
            '❌ Invalid record ID type for $table: ${recordIdRaw.runtimeType}');
        failureCount++;
        continue;
      }

      try {
        // Push to Firebase
        await _pushSingleRecordToFirebase(schoolId, table, record);

        // ✅ VERIFICATION: Double-check that record was marked as synced
        final verificationRecord = await checkRecordSyncStatus(table, recordId);
        if (verificationRecord?['firebase_synced'] == 1) {
          successCount++;
          print('✅ $table record $recordId: Push confirmed successful');
        } else {
          print(
              '⚠️ $table record $recordId: Push succeeded but sync status not updated');
          // Try to fix it
          await db.update(
            table,
            {'firebase_synced': 1},
            where: 'id = ?',
            whereArgs: [recordId],
          );
        }
      } catch (e) {
        failureCount++;
        print('❌ Failed to push $table record $recordId: $e');

        // Optional: Mark as failed for later retry
        await db.update(
          table,
          {
            'sync_error': e.toString(),
            'sync_error_count': (record['sync_error_count'] as int? ?? 0) + 1,
          },
          where: 'id = ?',
          whereArgs: [recordId],
        );
      }
    }

    print(
        '📊 $table PUSH SUMMARY: $successCount success, $failureCount failed');
    return successCount;
  }

  /// Enhanced method to batch update sync status (more efficient)
  Future<void> batchMarkAsSynced(String table, List<dynamic> recordIds) async {
    if (recordIds.isEmpty) return;

    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();

    for (final idRaw in recordIds) {
      // ✅ FIXED: Handle different ID types
      final int id;
      if (idRaw is int) {
        id = idRaw;
      } else if (idRaw is String) {
        id = int.parse(idRaw);
      } else {
        print('⚠️ Skipping invalid ID type: ${idRaw.runtimeType}');
        continue;
      }

      batch.update(
        table,
        {'firebase_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    try {
      await batch.commit(noResult: true);
      print('✅ Batch marked ${recordIds.length} $table records as synced');
    } catch (e) {
      print('❌ Batch sync status update failed: $e');
      // Fallback to individual updates
      for (final idRaw in recordIds) {
        try {
          final int id;
          if (idRaw is int) {
            id = idRaw;
          } else if (idRaw is String) {
            id = int.parse(idRaw);
          } else {
            continue;
          }

          await db.update(
            table,
            {'firebase_synced': 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        } catch (individualError) {
          print(
              '❌ Individual sync update failed for $table $idRaw: $individualError');
        }
      }
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
    result.remove('firebase_doc_id');

    // Convert timestamps to Firestore Timestamp objects
    if (result['created_at'] is String) {
      try {
        result['created_at'] =
            Timestamp.fromDate(DateTime.parse(result['created_at']));
      } catch (e) {
        result['created_at'] = Timestamp.now();
      }
    }

    if (result['last_modified'] is int) {
      result['last_modified'] =
          Timestamp.fromMillisecondsSinceEpoch(result['last_modified']);
    } else {
      result['last_modified'] = FieldValue.serverTimestamp();
    }

    // Convert other timestamp fields
    final timestampFields = [
      'due_date',
      'payment_date',
      'start',
      'end',
      'date_of_birth'
    ];
    for (String field in timestampFields) {
      if (result[field] is String) {
        try {
          result[field] = Timestamp.fromDate(DateTime.parse(result[field]));
        } catch (e) {
          result.remove(field); // Remove if can't convert
        }
      }
    }

    // Ensure last_modified is set
    result['last_modified'] = FieldValue.serverTimestamp();
    result['last_modified_device'] = _currentDeviceId;

    // Remove null values
    result.removeWhere((key, value) => value == null);
    return result;
  }

  Future<void> updateDatabaseSchemaForFirebaseUserId() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Check if firebase_user_id column exists, if not add it
      final tableInfo = await db.rawQuery("PRAGMA table_info(users)");
      final hasFirebaseUserId =
          tableInfo.any((column) => column['name'] == 'firebase_user_id');

      if (!hasFirebaseUserId) {
        await db.execute('ALTER TABLE users ADD COLUMN firebase_user_id TEXT');
        print('✅ Added firebase_user_id column to users table');

        // Migrate existing firebase_uid values to firebase_user_id
        await db.execute('''
        UPDATE users 
        SET firebase_user_id = firebase_uid 
        WHERE firebase_uid IS NOT NULL AND firebase_user_id IS NULL
      ''');
        print('✅ Migrated existing firebase_uid values to firebase_user_id');
      }
    } catch (e) {
      print('❌ Error updating database schema: $e');
    }
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

  Future<void> _pushDeletedRecordsToFirebase(
      String schoolId, String table) async {
    final db = await DatabaseHelper.instance.database;

    // Get locally deleted but not synced records
    final deletedRecords = await db.query(
      table,
      where: 'deleted = ? AND firebase_synced = ?',
      whereArgs: [1, 0],
    );

    for (final record in deletedRecords) {
      try {
        final recordId = record['id'].toString();

        // Mark as deleted in Firebase
        await _firestore!
            .collection('schools')
            .doc(schoolId)
            .collection(table)
            .doc(recordId)
            .update({
          'deleted': true,
          'last_modified': FieldValue.serverTimestamp(),
          'last_modified_device': _currentDeviceId,
        });

        // Mark as synced locally
        await db.update(
          table,
          {'firebase_synced': 1},
          where: 'id = ?',
          whereArgs: [record['id']],
        );

        print('✅ Deleted $table record $recordId pushed to Firebase');
      } catch (e) {
        print('❌ Failed to push deleted $table record ${record['id']}: $e');
      }
    }
  }

  /// This method IS used by _syncDeletedRecords()
  Future<void> _pullDeletedRecordsFromFirebase(
      String schoolId, String table) async {
    try {
      // Get records marked as deleted in Firebase
      final deletedSnapshot = await _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection(table)
          .where('deleted', isEqualTo: true)
          .get();

      for (final doc in deletedSnapshot.docs) {
        final localId = int.tryParse(doc.id);
        if (localId != null) {
          // Soft delete locally
          final db = await DatabaseHelper.instance.database;
          await db.update(
            table,
            {
              'deleted': 1,
              'firebase_synced': 1,
            },
            where: 'id = ?',
            whereArgs: [localId],
          );
          print('✅ Applied remote deletion for $table record $localId');
        }
      }
    } catch (e) {
      print('❌ Error pulling deleted records from $table: $e');
    }
  }

  /// This method IS used by syncWithFirebase()
  Future<void> _syncDeletedRecords(String schoolId) async {
    print('🗑️ === SYNCING DELETED RECORDS ===');

    for (final table in _syncTables) {
      try {
        // Push locally deleted records to Firebase
        await _pushDeletedRecordsToFirebase(schoolId, table);

        // Pull deleted records from Firebase
        await _pullDeletedRecordsFromFirebase(schoolId, table);
      } catch (e) {
        print('❌ Error syncing deleted records for $table: $e');
      }
    }
  }

  Future<void> _processRealTimeChanges(
      String table, QuerySnapshot snapshot) async {
    // Add small delay to let local updates complete
    await Future.delayed(Duration(milliseconds: 100));

    for (final doc in snapshot.docChanges) {
      if (doc.type == DocumentChangeType.modified ||
          doc.type == DocumentChangeType.added) {
        final remoteData = doc.doc.data() as Map<String, dynamic>;
        final remoteDevice = remoteData['last_modified_device'] as String?;

        // Skip processing our own changes
        if (remoteDevice == _currentDeviceId) {
          print('🛑 Skipping own change for $table:${doc.doc.id}');
          continue;
        } else if (doc.type == DocumentChangeType.removed) {
          // Handle deleted records in real-time
          print('🗑️ Real-time delete detected in $table: ${doc.doc.id}');
          final localId = int.tryParse(doc.doc.id);
          if (localId != null) {
            final db = await DatabaseHelper.instance.database;
            await db.update(
              table,
              {
                'deleted': 1,
                'firebase_synced': 1,
              },
              where: 'id = ?',
              whereArgs: [localId],
            );
            print('✅ Real-time delete applied for $table record $localId');
          }
        }
      }
    }
  }

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

  /// Add this method to your FixedLocalFirstSyncService class
  /// Verify and fix sync status for debugging
  Future<Map<String, dynamic>> verifySyncStatus({String? specificTable}) async {
    final db = await DatabaseHelper.instance.database;
    final tables = specificTable != null ? [specificTable] : _syncTables;
    final results = <String, dynamic>{};

    for (final table in tables) {
      try {
        // Get all records with their sync status
        final allRecords = await db.query(table,
            columns: ['id', 'firebase_synced', 'last_modified'],
            where: 'deleted IS NULL OR deleted = 0');

        // Get unsynced count
        final unsyncedCount = await db.query(
          table,
          where:
              '(firebase_synced = ? OR firebase_synced IS NULL) AND (deleted IS NULL OR deleted = 0)',
          whereArgs: [0],
        );

        // Get synced count
        final syncedCount = await db.query(
          table,
          where: 'firebase_synced = 1 AND (deleted IS NULL OR deleted = 0)',
        );

        results[table] = {
          'total': allRecords.length,
          'synced': syncedCount.length,
          'unsynced': unsyncedCount.length,
          'unsynced_records': unsyncedCount
              .map((r) => {
                    'id': r['id'],
                    'firebase_synced': r['firebase_synced'],
                    'last_modified': r['last_modified'],
                  })
              .toList(),
        };

        print('📊 $table: ${syncedCount.length}/${allRecords.length} synced');
      } catch (e) {
        results[table] = {'error': e.toString()};
        print('❌ Error checking $table: $e');
      }
    }

    return results;
  }

  /// Force mark specific records as synced (for debugging)
  Future<void> debugMarkAsSynced(String table, List<int> recordIds) async {
    final db = await DatabaseHelper.instance.database;

    for (final id in recordIds) {
      try {
        final result = await db.update(
          table,
          {'firebase_synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );

        if (result > 0) {
          print('✅ DEBUG: Marked $table record $id as synced');
        } else {
          print('⚠️ DEBUG: No record found for $table ID $id');
        }
      } catch (e) {
        print('❌ DEBUG: Error marking $table record $id: $e');
      }
    }
  }

  /// SIMPLE FIX: Disable triggers during sync operations
  /// Add these methods to your FixedLocalFirstSyncService class

// Add this flag to your FixedLocalFirstSyncService class
  bool _syncOperationInProgress = false;

  /// Disable all triggers temporarily during sync
  Future<void> _disableTriggers(Database db, List<String> tables) async {
    for (String table in tables) {
      await db.execute('DROP TRIGGER IF EXISTS update_${table}_timestamp');
      await db.execute('DROP TRIGGER IF EXISTS insert_${table}_timestamp');
    }
    print('🔇 Temporarily disabled triggers during sync');
  }

  /// Re-enable triggers after sync
  Future<void> _enableTriggers(Database db, List<String> tables) async {
    for (String table in tables) {
      // Create simpler triggers that only reset firebase_synced for actual data changes
      await db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_${table}_timestamp
      AFTER UPDATE ON $table
      WHEN (
        -- Only reset if firebase_synced was already 1 (meaning this is a real data change)
        OLD.firebase_synced = 1
      )
      BEGIN
        UPDATE $table SET 
          last_modified = (strftime('%s', 'now') * 1000),
          firebase_synced = 0
        WHERE id = NEW.id;
      END;
    ''');

      await db.execute('''
      CREATE TRIGGER IF NOT EXISTS insert_${table}_timestamp
      AFTER INSERT ON $table
      BEGIN
        UPDATE $table SET 
          last_modified = (strftime('%s', 'now') * 1000),
          firebase_synced = 0
        WHERE id = NEW.id;
      END;
    ''');
    }
    print('🔊 Re-enabled smart triggers after sync');
  }

// ✅ FIXED: Push single record with consistent document ID strategy
  Future<void> _pushSingleRecordToFirebase(
    String schoolId,
    String table,
    Map<String, dynamic> record,
  ) async {
    final recordIdRaw = record['id'];
    final int recordId;

    // Handle different possible types for ID
    if (recordIdRaw is int) {
      recordId = recordIdRaw;
    } else if (recordIdRaw is String) {
      recordId = int.parse(recordIdRaw);
    } else {
      throw Exception('Invalid record ID type: ${recordIdRaw.runtimeType}');
    }

    print('🔄 Pushing $table record ID: $recordId to Firebase');

    try {
      // Convert to Firebase format
      final firebaseData = _convertSqliteToFirestore(record);

      // **CRITICAL**: Always include local_id for identification
      firebaseData['local_id'] = recordId;
      firebaseData['last_modified_device'] = _currentDeviceId;
      firebaseData['last_modified'] = FieldValue.serverTimestamp();

      // Remove internal database fields that shouldn't go to Firebase
      firebaseData.remove('firebase_synced');
      firebaseData
          .remove('id'); // Remove the 'id' field since we use it as document ID

      // **CRITICAL FIX**: Always use local database ID as Firebase document ID
      final documentId = recordId.toString();

      await _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection(table)
          .doc(documentId) // Use local ID as document ID consistently
          .set(firebaseData, SetOptions(merge: true));

      print('✅ Successfully pushed $table record $recordId to Firebase');
      print('   Firebase Document ID: $documentId (local ID)');
      print('   Local Database ID: $recordId');

      // Mark as synced in local database
      await _markRecordAsSynced(table, recordId);
    } catch (e) {
      print('❌ Failed to push $table record $recordId: $e');

      // Log detailed error information
      if (e.toString().contains('permission')) {
        print('💡 Check Firebase security rules for $table collection');
      }

      rethrow;
    }
  }

  /// ✅ Helper method to mark record as synced
  Future<void> _markRecordAsSynced(String table, int recordId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final updateResult = await db.update(
        table,
        {
          'firebase_synced': 1,
          'last_modified': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [recordId],
      );

      if (updateResult > 0) {
        print('✅ Marked $table record $recordId as synced locally');
      } else {
        print(
            '⚠️ Failed to mark $table record $recordId as synced - record not found');
      }
    } catch (e) {
      print('❌ Error marking $table record $recordId as synced: $e');
    }
  }

  /// ✅ CLEANUP: Fix mismatched document IDs
  Future<void> fixMismatchedUserDocuments() async {
    print('🔧 === FIXING MISMATCHED USER DOCUMENTS ===');

    final schoolId = await _getSchoolId();
    if (schoolId.isEmpty) {
      print('❌ No school ID available');
      return;
    }

    try {
      // Get all user documents from Firebase
      final snapshot = await _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .get();

      print('📋 Found ${snapshot.docs.length} user documents in Firebase');

      final batch = _firestore!.batch();
      int fixedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final currentDocId = doc.id;
        final localId = data['local_id'];

        // Skip system documents
        if (currentDocId.startsWith('_')) continue;

        if (localId != null) {
          final correctDocId = localId.toString();

          // Check if document ID needs fixing
          if (currentDocId != correctDocId) {
            print('🔄 Fixing user: $currentDocId → $correctDocId');
            print('   Name: ${data['fname']} ${data['lname']}');
            print('   Email: ${data['email']}');

            // Create new document with correct ID
            final newDocRef = _firestore!
                .collection('schools')
                .doc(schoolId)
                .collection('users')
                .doc(correctDocId);

            // Ensure data has the correct local_id
            final correctedData = Map<String, dynamic>.from(data);
            correctedData['local_id'] = int.tryParse(correctDocId) ?? localId;
            correctedData['id'] = int.tryParse(correctDocId) ?? localId;
            correctedData['fixed_at'] = FieldValue.serverTimestamp();

            batch.set(newDocRef, correctedData);

            // Delete old document with wrong ID
            batch.delete(doc.reference);

            fixedCount++;
          }
        } else {
          print('⚠️ User document $currentDocId is missing local_id field');
          // Try to infer from numeric document ID
          final parsedId = int.tryParse(currentDocId);
          if (parsedId != null) {
            final updatedData = Map<String, dynamic>.from(data);
            updatedData['local_id'] = parsedId;
            updatedData['id'] = parsedId;
            batch.update(doc.reference, {'local_id': parsedId, 'id': parsedId});
            print('✅ Added missing local_id to user document $currentDocId');
          }
        }
      }

      if (fixedCount > 0) {
        await batch.commit();
        print('✅ Fixed $fixedCount user documents');

        // Trigger a sync to ensure all devices get the updates
        await syncWithFirebase();
      } else {
        print('✅ All user documents already have correct IDs');
      }
    } catch (e) {
      print('❌ Error fixing user documents: $e');
    }
  }

  /// ✅ ENHANCED: Ensure all local records have proper local_id in Firebase
  Future<void> ensureLocalIdInFirebase() async {
    print('🔧 === ENSURING LOCAL_ID IN FIREBASE DOCUMENTS ===');

    final schoolId = await _getSchoolId();
    if (schoolId.isEmpty) return;

    final db = await DatabaseHelper.instance.database;

    for (String table in _syncTables) {
      try {
        // Get all local records
        final localRecords = await db.query(
          table,
          where: 'firebase_synced = 1 AND (deleted IS NULL OR deleted = 0)',
        );

        if (localRecords.isEmpty) continue;

        print('🔍 Checking $table: ${localRecords.length} synced records');

        for (final record in localRecords) {
          final localId = record['id'];
          if (localId == null) continue;

          try {
            // Check Firebase document
            final firebaseDoc = await _firestore!
                .collection('schools')
                .doc(schoolId)
                .collection(table)
                .doc(localId.toString())
                .get();

            if (firebaseDoc.exists) {
              final firebaseData = firebaseDoc.data()!;

              // Ensure local_id field exists
              if (!firebaseData.containsKey('local_id') ||
                  firebaseData['local_id'] != localId) {
                await firebaseDoc.reference.update({
                  'local_id': localId,
                  'id': localId,
                });
                print('✅ Updated $table document $localId with local_id');
              }
            }
          } catch (e) {
            print('⚠️ Error checking $table record $localId: $e');
          }
        }
      } catch (e) {
        print('❌ Error processing $table: $e');
      }
    }
  }

  /// Quick fix method to apply immediately
  Future<void> quickFixTriggers() async {
    final db = await DatabaseHelper.instance.database;
    final tables = [
      'fleet',
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'attachments',
      'notes'
    ];

    print('⚡ APPLYING QUICK TRIGGER FIX...');

    for (String table in tables) {
      // Drop old problematic trigger
      await db.execute('DROP TRIGGER IF EXISTS update_${table}_timestamp');

      // Create new smart trigger
      await db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_${table}_timestamp
      AFTER UPDATE ON $table
      WHEN (OLD.firebase_synced = 1)
      BEGIN
        UPDATE $table SET 
          last_modified = (strftime('%s', 'now') * 1000),
          firebase_synced = 0
        WHERE id = NEW.id;
      END;
    ''');

      print('⚡ Fixed trigger for $table');
    }

    print('🎉 Quick trigger fix complete!');
  }

  /// Check if a specific record exists and its sync status
  Future<Map<String, dynamic>?> checkRecordSyncStatus(
      String table, int recordId) async {
    final db = await DatabaseHelper.instance.database;

    final records = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [recordId],
      limit: 1,
    );

    if (records.isEmpty) {
      print('❌ Record $recordId not found in $table');
      return null;
    }

    final record = records.first;
    print('🔍 Record $recordId in $table:');
    print('   firebase_synced: ${record['firebase_synced']}');
    print('   last_modified: ${record['last_modified']}');
    print('   deleted: ${record['deleted']}');

    return record;
  }

  /// ✅ FIX 8: Update your sync initialization to clean existing duplicates
  Future<void> initializeSync() async {
    print('🔄 Initializing sync service...');

    try {
      // Clean existing duplicates first
      await DeduplicationSyncService.cleanExistingDuplicates();

      // ... rest of your existing initialization code ...

      print('✅ Sync service initialized successfully');
    } catch (e) {
      print('❌ Error initializing sync service: $e');
      rethrow;
    }
  }

// Replace your existing insertWithSync method with this:
  static Future<int> insertWithSync(
    Database db,
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      // ✅ CONVERT TIMESTAMPS BEFORE INSERTING
      final convertedData = TimestampConverter.prepareForSQLite(data);

      // Set sync tracking fields
      convertedData['firebase_synced'] = 0;
      convertedData['last_modified'] = DateTime.now().millisecondsSinceEpoch;
      convertedData['last_modified_device'] = await _getCurrentDeviceId();

      final result = await db.insert(table, convertedData);

      // Mark for Firebase sync
      _markForFirebaseSync(table, result);

      return result;
    } catch (e) {
      print('❌ Error in insertWithSync for $table: $e');
      print('🔍 Data: $data');
      rethrow;
    }
  }

// Replace your existing updateWithSync method with this:
  static Future<int> updateWithSync(
    Database db,
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    try {
      // ✅ CONVERT TIMESTAMPS BEFORE UPDATING
      final convertedData = TimestampConverter.prepareForSQLite(data);

      // Set sync tracking fields
      convertedData['firebase_synced'] = 0;
      convertedData['last_modified'] = DateTime.now().millisecondsSinceEpoch;
      convertedData['last_modified_device'] = await _getCurrentDeviceId();

      final result = await db.update(table, convertedData,
          where: where, whereArgs: whereArgs);

      // Mark for Firebase sync if update was successful
      if (result > 0 && whereArgs.isNotEmpty) {
        _markForFirebaseSync(table, whereArgs.first);
      }

      return result;
    } catch (e) {
      print('❌ Error in updateWithSync for $table: $e');
      print('🔍 Data: $data');
      rethrow;
    }
  }

// Helper method to get device ID
  static Future<String> _getCurrentDeviceId() async {
    // You can implement this based on your device ID logic
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

// Helper method to mark records for sync
  static void _markForFirebaseSync(String table, dynamic recordId) {
    // Add record to sync queue or trigger immediate sync
    print('📤 Marked $table record $recordId for Firebase sync');
  }
}

enum MergeResult { inserted, updated, conflict, skipped }
