// lib/services/production_sync_engine.dart
// FIXED VERSION - Ensures sync button downloads data correctly

import 'dart:convert';
import 'dart:io';
import 'package:driving/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:crypto/crypto.dart';
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
  // MAIN SYNC METHOD - FIXED VERSION
  // ===================================================================

  static Future<SyncResult> performProductionSync({
    required String schoolId,
    bool forceFullSync = false,
  }) async {
    try {
      print('🚀 Starting production sync for school: $schoolId');

      final currentState = await _loadSyncState(schoolId);
      print('📱 Device: ${currentState.deviceId}');

      try {
        print('📝 Registering device with server...');
        await ApiService.registerDevice(
          schoolId: schoolId,
          deviceId: currentState.deviceId,
        );
        print('✅ Device registration successful');
      } catch (e) {
        print('⚠️ Device registration failed: $e');
      }

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
          // 🔧 FIX: Use the production download endpoint for incremental sync
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

  // ===================================================================
  // FIXED: Full Sync using production endpoint
  // ===================================================================

  static Future<SyncResult> _executeFullSync(DeviceSyncState state) async {
    try {
      print('⬇️ Executing full sync...');

      try {
        await ApiService.registerDevice(
          schoolId: state.schoolId,
          deviceId: state.deviceId,
        );
      } catch (e) {
        print('⚠️ Device re-registration failed during full sync: $e');
      }

      // 🔧 FIX: Use downloadAllSchoolData instead of legacy syncDownload
      print('📥 Downloading all school data from production endpoint...');
      final serverData = await ApiService.downloadAllSchoolData(
        schoolId: state.schoolId,
      );

      print('💾 Updating local database...');
      await _updateLocalDatabase(serverData);

      print('📤 Uploading pending changes...');
      final uploadResult = await _uploadPendingChanges();
      final downloadedCount = _countRecords(serverData);

      print('✅ Full sync completed:');
      print('   Downloaded: $downloadedCount records');
      print('   Uploaded: ${uploadResult['uploaded']} changes');

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
  // FIXED: Incremental Sync with Smart Full Sync Detection
  // ===================================================================

  static Future<SyncResult> _executeIncrementalSyncFixed(
      DeviceSyncState currentState) async {
    print('⚡ Executing incremental sync (FIXED)...');

    try {
      // 🔧 FIX: Use the production endpoint for incremental sync
      final lastSyncTime = currentState.lastIncrementalSync;

      print('📥 Downloading incremental changes from production endpoint...');
      final serverData = await ApiService.downloadIncrementalChanges(
        schoolId: currentState.schoolId,
        since: lastSyncTime,
      );

      // Check if we received data
      final downloadedCount = _countRecords(serverData);
      print('📊 Received $downloadedCount records from server');

      // 🔧 CRITICAL FIX: Smart detection of when full sync is needed
      if (downloadedCount == 0) {
        // Check multiple conditions that indicate we should do a full sync
        bool shouldDoFullSync = false;
        String reason = '';

        if (lastSyncTime != null) {
          // Check if it's been more than 1 hour since last sync
          final hoursSinceLastSync =
              DateTime.now().difference(lastSyncTime).inHours;

          if (hoursSinceLastSync > 1) {
            shouldDoFullSync = true;
            reason =
                'Last sync was $hoursSinceLastSync hours ago, doing full sync to ensure data consistency';
          }
        }

        // Check if we have very little local data (suggests incomplete sync)
        final localDataCheck = await _checkLocalDataCompleteness();
        if (!localDataCheck['has_sufficient_data']) {
          shouldDoFullSync = true;
          reason =
              'Local database appears incomplete: ${localDataCheck['reason']}';
        }

        if (shouldDoFullSync) {
          print('⚠️ $reason');
          print(
              '🔄 Switching to full sync to ensure all data is downloaded...');
          return await _executeFullSync(currentState);
        } else {
          print(
              '✅ No new changes from server (this is normal if no data was modified)');
        }
      }

      print('💾 Updating local database...');
      await _updateLocalDatabase(serverData);

      print('📤 Uploading pending changes...');
      final uploadResult = await _uploadPendingChanges();

      print('✅ Incremental sync completed:');
      print('   Downloaded: $downloadedCount records');
      print('   Uploaded: ${uploadResult['uploaded']} changes');

      return SyncResult(true, 'Incremental sync completed successfully',
          details: {
            'strategy': 'incrementalSync',
            'downloaded_records': downloadedCount,
            'uploaded_changes': uploadResult['uploaded'] ?? 0,
            'sync_time': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('❌ Incremental sync failed: $e');
      print('🔄 Falling back to full sync...');

      // Fallback to full sync if incremental fails
      return await _executeFullSync(currentState);
    }
  }

  // ===================================================================
  // Helper: Check if local database has sufficient data
  // ===================================================================

  static Future<Map<String, dynamic>> _checkLocalDataCompleteness() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Check key tables for data
      final userCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM users')) ??
          0;

      final courseCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM courses')) ??
          0;

      // If we have no users or courses, database is likely incomplete
      if (userCount == 0 || courseCount == 0) {
        return {
          'has_sufficient_data': false,
          'reason':
              'Missing core data (users: $userCount, courses: $courseCount)',
        };
      }

      return {
        'has_sufficient_data': true,
        'user_count': userCount,
        'course_count': courseCount,
      };
    } catch (e) {
      print('⚠️ Error checking local data: $e');
      // If we can't check, assume we need full sync to be safe
      return {
        'has_sufficient_data': false,
        'reason': 'Unable to verify local data: $e',
      };
    }
  }

  // ===================================================================
  // STRATEGY DETERMINATION
  // ===================================================================

  static Future<SyncStrategy> _determineSyncStrategy(
      DeviceSyncState currentState, bool forceFullSync) async {
    if (forceFullSync) {
      print('🎯 Strategy: fullReset (forced)');
      return SyncStrategy.fullReset;
    }

    if (currentState.lastFullSync == null) {
      print('🎯 Strategy: firstTimeSetup (no previous sync)');
      return SyncStrategy.firstTimeSetup;
    }

    if (currentState.requiresFullSync) {
      print('🎯 Strategy: fullReset (required)');
      return SyncStrategy.fullReset;
    }

    // 🔧 CRITICAL FIX: Check for invalid/future timestamps
    if (currentState.lastIncrementalSync != null) {
      final now = DateTime.now();

      // If last sync is in the future, reset to full sync
      if (currentState.lastIncrementalSync!.isAfter(now)) {
        print('🎯 Strategy: fullReset (invalid future timestamp detected)');
        print('   Last sync: ${currentState.lastIncrementalSync}');
        print('   Current time: $now');
        return SyncStrategy.fullReset;
      }

      // Check if it's been too long since last sync
      final daysSinceLastSync =
          now.difference(currentState.lastIncrementalSync!).inDays;
      if (daysSinceLastSync > 7) {
        print('🎯 Strategy: fullReset (stale data - $daysSinceLastSync days)');
        return SyncStrategy.fullReset;
      }
    }

    // 🔧 FIX: If lastIncrementalSync is null but lastFullSync exists,
    // do a full sync to ensure we have all data
    if (currentState.lastIncrementalSync == null &&
        currentState.lastFullSync != null) {
      final daysSinceFullSync =
          DateTime.now().difference(currentState.lastFullSync!).inDays;
      if (daysSinceFullSync > 1) {
        print('🎯 Strategy: fullReset (no incremental sync history)');
        return SyncStrategy.fullReset;
      }
    }

    print('🎯 Strategy: incrementalSync (normal operation)');
    return SyncStrategy.incrementalSync;
  }

  // ===================================================================
  // DATABASE UPDATE
  // ===================================================================

  static Future<void> _updateLocalDatabase(
      Map<String, dynamic> serverData) async {
    try {
      final db = await DatabaseHelper.instance.database;

      print('🔄 Updating local database...');

      // Update users
      if (serverData['users'] != null) {
        for (var userData in serverData['users']) {
          await SyncService.upsertUser(userData);
        }
        print('✅ Users updated: ${(serverData['users'] as List).length}');
      }

      // Update courses
      if (serverData['courses'] != null) {
        for (var courseData in serverData['courses']) {
          await SyncService.upsertCourse(courseData);
        }
        print('✅ Courses updated: ${(serverData['courses'] as List).length}');
      }

      // Update fleet
      if (serverData['fleet'] != null) {
        for (var fleetData in serverData['fleet']) {
          await SyncService.upsertFleet(fleetData);
        }
        print('✅ Fleet updated: ${(serverData['fleet'] as List).length}');
      }

      // Update schedules
      if (serverData['schedules'] != null) {
        for (var scheduleData in serverData['schedules']) {
          await SyncService.upsertSchedule(scheduleData);
        }
        print(
            '✅ Schedules updated: ${(serverData['schedules'] as List).length}');
      }

      // Update invoices
      if (serverData['invoices'] != null) {
        for (var invoiceData in serverData['invoices']) {
          await SyncService.upsertInvoice(invoiceData);
        }
        print('✅ Invoices updated: ${(serverData['invoices'] as List).length}');
      }

      // Update payments
      if (serverData['payments'] != null) {
        for (var paymentData in serverData['payments']) {
          await SyncService.upsertPayment(paymentData);
        }
        print('✅ Payments updated: ${(serverData['payments'] as List).length}');
      }

      print('✅ Local database update completed');
    } catch (e) {
      print('❌ Error updating local database: $e');
      throw e;
    }
  }

  // ===================================================================
  // UPLOAD PENDING CHANGES
  // ===================================================================

  static Future<Map<String, dynamic>> _uploadPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final changesJson = prefs.getString('sync_pending_changes');

      if (changesJson == null || changesJson.isEmpty) {
        print('ℹ️ No pending changes to upload');
        return {'uploaded': 0, 'message': 'No pending changes'};
      }

      final changes = json.decode(changesJson);
      if (changes is! Map || changes.isEmpty) {
        print('ℹ️ No pending changes to upload');
        return {'uploaded': 0, 'message': 'No pending changes'};
      }

      // Convert to list format for API
      List<Map<String, dynamic>> changesList = [];
      for (var entry in changes.entries) {
        if (entry.value is Map) {
          final item = entry.value as Map<String, dynamic>;
          changesList.add({
            'table': item['table'],
            'action': item['action'] ?? 'create',
            'data': item['data'],
            'id': item['data']['id'],
          });
        }
      }

      final result = await ApiService.syncUpload(changesList);

      if (result['success'] == true) {
        await prefs.remove('sync_pending_changes');
        print('✅ Uploaded ${changesList.length} changes');
        return {
          'uploaded': result['uploaded'] ?? changesList.length,
          'message': 'Upload successful'
        };
      } else {
        print('⚠️ Upload had issues: ${result['message']}');
        return {
          'uploaded': 0,
          'message': 'Upload failed: ${result['message']}'
        };
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return {'uploaded': 0, 'message': 'Upload error: ${e.toString()}'};
    }
  }

  static Future<void> _clearPendingChanges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sync_pending_changes');
  }

  static int _countRecords(Map<String, dynamic> data) {
    int count = 0;
    for (final table in [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet'
    ]) {
      if (data[table] != null && data[table] is List) {
        count += (data[table] as List).length;
      }
    }
    return count;
  }

  static DeviceSyncState _updateSyncState(
    DeviceSyncState currentState,
    SyncResult result,
    SyncStrategy strategy,
  ) {
    final now = DateTime.now();

    return currentState.copyWith(
      lastIncrementalSync: strategy == SyncStrategy.incrementalSync
          ? now
          : currentState.lastIncrementalSync,
      lastFullSync: [SyncStrategy.firstTimeSetup, SyncStrategy.fullReset]
              .contains(strategy)
          ? now
          : currentState.lastFullSync,
      requiresFullSync: false,
    );
  }

  // ===================================================================
  // UTILITY METHODS
  // ===================================================================

  static Future<bool> isProductionSyncAvailable() async {
    try {
      return await ApiService.testServerConnection();
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getDeviceSyncInfo() async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString(_syncStateKey);

      return {
        'device_id': deviceId,
        'has_sync_state': stateJson != null,
        'sync_state': stateJson != null ? json.decode(stateJson) : null,
      };
    } catch (e) {
      return {
        'device_id': 'error',
        'has_sync_state': false,
        'error': e.toString(),
      };
    }
  }

  static Future<void> resetSyncState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncStateKey);
    print('🔄 Sync state reset');
  }
}
