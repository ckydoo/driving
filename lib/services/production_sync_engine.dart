// lib/services/production_sync_engine.dart
// FIXED VERSION - Matches ProductionSyncController.php requirements

import 'dart:convert';
import 'dart:io';
import 'package:driving/services/sync_service.dart'; // Needed for ID mapping helper
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../models/sync_result.dart';

class DeviceSyncState {
  final String deviceId;
  final String schoolId;
  final DateTime? lastFullSync;
  final DateTime? lastIncrementalSync;
  final int syncVersion;
  final bool requiresFullSync;
  final Map<String, String> tableVersions;

  DeviceSyncState({
    required this.deviceId,
    required this.schoolId,
    this.lastFullSync,
    this.lastIncrementalSync,
    required this.syncVersion,
    this.requiresFullSync = false,
    required this.tableVersions,
  });

  factory DeviceSyncState.fromJson(Map<String, dynamic> json) {
    return DeviceSyncState(
      deviceId: json['deviceId'],
      schoolId: json['schoolId'],
      lastFullSync: json['lastFullSync'] != null
          ? DateTime.parse(json['lastFullSync'])
          : null,
      lastIncrementalSync: json['lastIncrementalSync'] != null
          ? DateTime.parse(json['lastIncrementalSync'])
          : null,
      syncVersion: json['syncVersion'] ?? 1,
      requiresFullSync: json['requiresFullSync'] ?? false,
      tableVersions: Map<String, String>.from(json['tableVersions'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'schoolId': schoolId,
      'lastFullSync': lastFullSync?.toIso8601String(),
      'lastIncrementalSync': lastIncrementalSync?.toIso8601String(),
      'syncVersion': syncVersion,
      'requiresFullSync': requiresFullSync,
      'tableVersions': tableVersions,
    };
  }

  DeviceSyncState copyWith({
    DateTime? lastFullSync,
    DateTime? lastIncrementalSync,
    int? syncVersion,
    bool? requiresFullSync,
    Map<String, String>? tableVersions,
  }) {
    return DeviceSyncState(
      deviceId: deviceId,
      schoolId: schoolId,
      lastFullSync: lastFullSync ?? this.lastFullSync,
      lastIncrementalSync: lastIncrementalSync ?? this.lastIncrementalSync,
      syncVersion: syncVersion ?? this.syncVersion,
      requiresFullSync: requiresFullSync ?? this.requiresFullSync,
      tableVersions: tableVersions ?? this.tableVersions,
    );
  }
}

enum SyncStrategy {
  firstTimeSetup,
  incrementalSync,
  fullReset,
  conflictResolution
}

class ProductionSyncEngine {
  static const String _syncStateKey = 'production_sync_state';
  static const String _deviceIdKey = 'device_unique_id';

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecondsSinceEpoch;
      deviceId = 'device_${timestamp}_$random';
      await prefs.setString(_deviceIdKey, deviceId);
      print('📱 Generated new device ID: $deviceId');
    }

    return deviceId;
  }

  static Future<DeviceSyncState> _loadSyncState(String schoolId) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId();
    final stateJson = prefs.getString(_syncStateKey);

    if (stateJson != null) {
      try {
        final state = DeviceSyncState.fromJson(json.decode(stateJson));
        if (state.schoolId == schoolId) {
          return state;
        }
      } catch (e) {
        print('⚠️ Error loading sync state: $e');
      }
    }

    return DeviceSyncState(
      deviceId: deviceId,
      schoolId: schoolId,
      syncVersion: 1,
      tableVersions: {},
    );
  }

  static Future<void> _saveSyncState(DeviceSyncState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncStateKey, json.encode(state.toJson()));
  }

  // ===================================================================
  // MAIN SYNC METHOD
  // ===================================================================

  static Future<SyncResult> performProductionSync({
    required String schoolId,
    bool forceFullSync = false,
  }) async {
    try {
      print('🚀 Starting production sync for school: $schoolId');

      final currentState = await _loadSyncState(schoolId);
      print('📱 Device: ${currentState.deviceId}');

      // Attempt registration (non-blocking)
      _registerDeviceInBackground(schoolId, currentState.deviceId);

      final strategy =
          await _determineSyncStrategy(currentState, forceFullSync);
      print('🎯 Sync Strategy: ${strategy.name}');

      late SyncResult result;

      switch (strategy) {
        case SyncStrategy.firstTimeSetup:
        case SyncStrategy.fullReset:
          result = await _executeFullSync(currentState);
          break;
        case SyncStrategy.incrementalSync:
        case SyncStrategy.conflictResolution:
          result = await _executeIncrementalSyncFixed(currentState);
          break;
      }

      if (result.success) {
        final updatedState = _updateSyncState(currentState, result, strategy);
        await _saveSyncState(updatedState);
      }

      return result;
    } catch (e, stackTrace) {
      print('💥 Production sync failed: $e');
      print('📚 Stack trace: $stackTrace');
      return SyncResult(false, 'Production sync failed: ${e.toString()}');
    }
  }

  static Future<void> _registerDeviceInBackground(
      String schoolId, String deviceId) async {
    try {
      await ApiService.registerDevice(schoolId: schoolId, deviceId: deviceId);
    } catch (e) {
      print('⚠️ Background device registration failed (non-critical): $e');
    }
  }

  // ===================================================================
  // FULL SYNC
  // ===================================================================

  static Future<SyncResult> _executeFullSync(DeviceSyncState state) async {
    try {
      print('⬇️ Executing full sync...');

      print('📥 Downloading all school data...');
      // Ensure ApiService handles the response wrapping
      final response =
          await ApiService.downloadAllSchoolData(schoolId: state.schoolId);

      // Handle response wrapping (Laravel usually wraps in 'data' key)
      final serverData = response.containsKey('data') && response['data'] is Map
          ? response['data']
          : response;

      print('💾 Updating local database...');
      await _updateLocalDatabase(serverData);

      print('📤 Uploading pending changes...');
      final uploadResult = await _uploadPendingChanges(state.schoolId);

      final downloadedCount = _countRecords(serverData);

      return SyncResult(
        true,
        'Full sync completed successfully',
        details: {
          'strategy': 'full_sync',
          'downloaded_records': downloadedCount,
          'uploaded_changes': uploadResult['uploaded'],
          'sync_time': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Full sync failed: $e');
      return SyncResult(false, 'Full sync failed: ${e.toString()}');
    }
  }

  // ===================================================================
  // INCREMENTAL SYNC
  // ===================================================================

  static Future<SyncResult> _executeIncrementalSyncFixed(
      DeviceSyncState currentState) async {
    print('⚡ Executing incremental sync...');

    try {
      final lastSyncTime = currentState.lastIncrementalSync;

      print('📥 Downloading changes since $lastSyncTime...');
      final response = await ApiService.downloadIncrementalChanges(
        schoolId: currentState.schoolId,
        since: lastSyncTime,
      );

      // Handle response wrapping
      final serverData = response.containsKey('data') && response['data'] is Map
          ? response['data']
          : response;

      final downloadedCount = _countRecords(serverData);
      print('📊 Received $downloadedCount records');

      // Smart Fallback Logic
      if (downloadedCount == 0) {
        if (await _shouldForceFullSync(lastSyncTime)) {
          print('🔄 Smart Fallback: Switching to full sync...');
          return await _executeFullSync(currentState);
        }
      }

      print('💾 Updating local database...');
      await _updateLocalDatabase(serverData);

      print('📤 Uploading pending changes...');
      final uploadResult = await _uploadPendingChanges(currentState.schoolId);

      return SyncResult(true, 'Incremental sync completed', details: {
        'strategy': 'incrementalSync',
        'downloaded_records': downloadedCount,
        'uploaded_changes': uploadResult['uploaded'] ?? 0,
        'sync_time': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Incremental sync failed: $e');
      print('🔄 Falling back to full sync...');
      return await _executeFullSync(currentState);
    }
  }

  static Future<bool> _shouldForceFullSync(DateTime? lastSyncTime) async {
    if (lastSyncTime == null) return true;

    // 1. Check time elapsed (> 24 hours usually warrants a check, simplified here)
    if (DateTime.now().difference(lastSyncTime).inHours > 24) return true;

    // 2. Check local data health
    final completeness = await _checkLocalDataCompleteness();
    if (!completeness['has_sufficient_data']) return true;

    return false;
  }

  // ===================================================================
  // UPLOAD PENDING CHANGES - COMPLETELY REWRITTEN
  // ===================================================================

  static Future<Map<String, dynamic>> _uploadPendingChanges(
      String schoolId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final changesJson = prefs.getString('sync_pending_changes');

      if (changesJson == null || changesJson.isEmpty) {
        return {'uploaded': 0, 'message': 'No changes'};
      }

      final changes = json.decode(changesJson);
      if (changes is! Map || changes.isEmpty) {
        return {'uploaded': 0, 'message': 'No changes'};
      }

      // 1. Group changes by 'type' (table) as expected by ProductionSyncController
      List<Map<String, dynamic>> groupedChanges = [];
      int totalItems = 0;

      // Ensure we process dependencies in order: users -> courses -> fleet -> invoices -> payments -> schedules
      final orderedTables = [
        'users',
        'courses',
        'fleet',
        'invoices',
        'payments',
        'schedules'
      ];

      for (var tableName in orderedTables) {
        if (changes.containsKey(tableName)) {
          final rawList = changes[tableName] as List;
          if (rawList.isEmpty) continue;

          List<Map<String, dynamic>> processedItems = [];

          for (var item in rawList) {
            if (item is Map) {
              // 2. Map fields for strict PHP validation
              var data = Map<String, dynamic>.from(item['data']);

              // Inject School ID if missing
              data['school_id'] = schoolId;

              // Fix Field Names for Production Controller
              if (tableName == 'invoices') {
                if (data.containsKey('student'))
                  data['student_id'] = data['student'];
                if (data.containsKey('course'))
                  data['course_id'] = data['course'];
              }
              if (tableName == 'schedules') {
                if (data.containsKey('student'))
                  data['student_id'] = data['student'];
                if (data.containsKey('instructor'))
                  data['instructor_id'] = data['instructor'];
                if (data.containsKey('course'))
                  data['course_id'] = data['course'];
                if (data.containsKey('car')) data['vehicle_id'] = data['car'];
              }
              if (tableName == 'payments') {
                // Ensure userId is present (some local DBs use user_id or userId)
                if (!data.containsKey('userId') &&
                    data.containsKey('user_id')) {
                  data['userId'] = data['user_id'];
                }
              }

              processedItems.add({
                'operation': item['operation'] ??
                    item['action'] ??
                    'upsert', // Normalized
                'id': data['id'],
                'data': data,
              });
            }
          }

          if (processedItems.isNotEmpty) {
            groupedChanges.add({
              'type': tableName,
              'items': processedItems,
            });
            totalItems += processedItems.length;
          }
        }
      }

      if (groupedChanges.isEmpty) {
        return {'uploaded': 0, 'message': 'No valid changes to upload'};
      }

      print(
          '📤 Sending $totalItems changes in ${groupedChanges.length} groups to production...');

      // 3. Send to NEW endpoint
      // Note: We use a specific method name to indicate this is the grouped upload
      final response = await ApiService.uploadChanges(groupedChanges);

      // 4. Handle Response & ID Mappings
      bool success = response['success'] == true;

      if (success) {
        final responseData = response['data'] ?? {};

        // Critical: Update Local IDs with Server IDs
        if (responseData['id_mappings'] != null) {
          await _updateLocalIds(responseData['id_mappings']);
        }

        // Clear pending changes on success
        await prefs.remove('sync_pending_changes');
        return {
          'uploaded': responseData['uploaded'] ?? totalItems,
          'message': 'Upload successful'
        };
      } else {
        return {
          'uploaded': 0,
          'message': 'Upload failed: ${response['message']}'
        };
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return {'uploaded': 0, 'message': 'Upload error: ${e.toString()}'};
    }
  }

  // Reuse logic from SyncService but specifically for this engine
  static Future<void> _updateLocalIds(Map<String, dynamic> idMappings) async {
    print('🔄 Processing Server ID mappings...');
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      for (final tableEntry in idMappings.entries) {
        final table = tableEntry.key;
        final mappings = tableEntry.value;
        if (mappings is! Map) continue;

        for (final entry in mappings.entries) {
          final localId = entry.key;
          final serverId = entry.value;

          if (localId.toString() == serverId.toString()) continue;

          try {
            // 1. Disable Foreign Keys (Safety)
            await txn.execute('PRAGMA foreign_keys = OFF');

            // 2. Update the Primary ID
            await txn.rawUpdate(
                'UPDATE $table SET id = ? WHERE id = ?', [serverId, localId]);

            // 3. Update References (Simplified for brevity, ensure these match your schema)
            if (table == 'users') {
              await txn.rawUpdate(
                  'UPDATE invoices SET student = ? WHERE student = ?',
                  [serverId, localId]);
              await txn.rawUpdate(
                  'UPDATE schedules SET student = ? WHERE student = ?',
                  [serverId, localId]);
              await txn.rawUpdate(
                  'UPDATE schedules SET instructor = ? WHERE instructor = ?',
                  [serverId, localId]);
            }
            if (table == 'courses') {
              await txn.rawUpdate(
                  'UPDATE invoices SET course = ? WHERE course = ?',
                  [serverId, localId]);
            }

            // 4. Re-enable Foreign Keys
            await txn.execute('PRAGMA foreign_keys = ON');
          } catch (e) {
            print(
                '⚠️ ID Mapping failed for $table ($localId -> $serverId): $e');
          }
        }
      }
    });
  }

  // ===================================================================
  // UTILS
  // ===================================================================

  static int _countRecords(Map<String, dynamic> data) {
    int count = 0;
    // Iterate known keys
    for (var key in data.keys) {
      if (data[key] is List) {
        count += (data[key] as List).length;
      }
    }
    return count;
  }

  static Future<Map<String, dynamic>> _checkLocalDataCompleteness() async {
    // ... existing logic ...
    final db = await DatabaseHelper.instance.database;
    final userCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM users')) ??
        0;
    return {'has_sufficient_data': userCount > 0};
  }

  static Future<SyncStrategy> _determineSyncStrategy(
      DeviceSyncState state, bool force) async {
    if (force || state.lastFullSync == null) return SyncStrategy.firstTimeSetup;
    return SyncStrategy.incrementalSync;
  }

  static DeviceSyncState _updateSyncState(
      DeviceSyncState current, SyncResult result, SyncStrategy strategy) {
    final now = DateTime.now();
    return current.copyWith(
        lastFullSync: strategy == SyncStrategy.firstTimeSetup ||
                strategy == SyncStrategy.fullReset
            ? now
            : current.lastFullSync,
        lastIncrementalSync: now,
        requiresFullSync: false);
  }

  // Database Update helper
  static Future<void> _updateLocalDatabase(
      Map<String, dynamic> serverData) async {
    // Use existing SyncService helpers to keep code DRY, but ensure they are imported
    if (serverData['users'] != null) {
      for (var u in serverData['users']) await SyncService.upsertUser(u);
    }
    if (serverData['courses'] != null) {
      for (var c in serverData['courses']) await SyncService.upsertCourse(c);
    }
    if (serverData['fleet'] != null) {
      for (var f in serverData['fleet']) await SyncService.upsertFleet(f);
    }
    if (serverData['schedules'] != null) {
      for (var s in serverData['schedules'])
        await SyncService.upsertSchedule(s);
    }
    if (serverData['invoices'] != null) {
      for (var i in serverData['invoices']) await SyncService.upsertInvoice(i);
    }
    if (serverData['payments'] != null) {
      for (var p in serverData['payments']) await SyncService.upsertPayment(p);
    }
  }
}
