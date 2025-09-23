// lib/services/production_sync_engine.dart
// Create this as a new file in your Flutter project

import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Import your existing services
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../models/sync_result.dart';

// ===================================================================
// 1. DEVICE SYNC STATE MANAGEMENT
// ===================================================================

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

// ===================================================================
// 2. SYNC STRATEGY ENUM
// ===================================================================

enum SyncStrategy {
  firstTimeSetup, // New device joining school
  incrementalSync, // Normal operation
  fullReset, // Data corruption recovery
  conflictResolution // Server-client mismatch
}

// ===================================================================
// 3. PRODUCTION SYNC ENGINE
// ===================================================================

class ProductionSyncEngine {
  static const String _syncStateKey = 'production_sync_state';
  static const String _deviceIdKey = 'device_unique_id';

  // Generate or get device ID
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

  // Load sync state
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

    // Create new sync state
    return DeviceSyncState(
      deviceId: deviceId,
      schoolId: schoolId,
      syncVersion: 1,
      tableVersions: {},
    );
  }

  // Save sync state
  static Future<void> _saveSyncState(DeviceSyncState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncStateKey, json.encode(state.toJson()));
  }

  // ===================================================================
  // MAIN SYNC METHOD - SIMPLIFIED FOR YOUR EXISTING SETUP
  // ===================================================================

  static Future<SyncResult> performProductionSync({
    required String schoolId,
    bool forceFullSync = false,
  }) async {
    try {
      print('🚀 Starting production sync for school: $schoolId');

      // Step 1: Load current device sync state
      final currentState = await _loadSyncState(schoolId);
      print('📱 Device: ${currentState.deviceId}');

      // Step 2: Determine strategy
      final strategy =
          await _determineSyncStrategy(currentState, forceFullSync);
      print('🎯 Sync Strategy: ${strategy.name}');

      // Step 3: Execute sync based on strategy
      late SyncResult result;

      switch (strategy) {
        case SyncStrategy.firstTimeSetup:
        case SyncStrategy.fullReset:
          result = await _executeFullSync(currentState);
          break;
        case SyncStrategy.incrementalSync:
        case SyncStrategy.conflictResolution:
          result = await _executeIncrementalSync(currentState);
          break;
      }

      // Step 4: Update sync state on success
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
  // STRATEGY DETERMINATION
  // ===================================================================

  static Future<SyncStrategy> _determineSyncStrategy(
      DeviceSyncState currentState, bool forceFullSync) async {
    if (forceFullSync) {
      return SyncStrategy.fullReset;
    }

    if (currentState.lastFullSync == null) {
      return SyncStrategy.firstTimeSetup;
    }

    if (currentState.requiresFullSync) {
      return SyncStrategy.fullReset;
    }

    // Check if it's been too long since last sync
    if (currentState.lastIncrementalSync != null) {
      final daysSinceLastSync =
          DateTime.now().difference(currentState.lastIncrementalSync!).inDays;
      if (daysSinceLastSync > 7) {
        return SyncStrategy.fullReset;
      }
    }

    return SyncStrategy.incrementalSync;
  }

  // ===================================================================
  // SYNC IMPLEMENTATIONS
  // ===================================================================

  static Future<SyncResult> _executeFullSync(
      DeviceSyncState currentState) async {
    print('🔄 Executing full sync...');

    try {
      // Use your existing API service - no Last-Sync header for full sync
      final serverData = await ApiService.syncDownload(lastSync: null);

      // Update local database using existing method
      await _updateLocalDatabase(serverData);

      // Clear any pending changes since we're doing full sync
      await _clearPendingChanges();

      final downloadedCount = _countRecords(serverData);

      return SyncResult(true, 'Full sync completed successfully', details: {
        'strategy': 'fullSync',
        'downloaded_records': downloadedCount,
        'sync_timestamp':
            serverData['sync_timestamp'] ?? DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return SyncResult(false, 'Full sync failed: ${e.toString()}');
    }
  }

  static Future<SyncResult> _executeIncrementalSync(
      DeviceSyncState currentState) async {
    print('⚡ Executing incremental sync...');

    try {
      // Use existing API with last sync timestamp
      final lastSyncTime = currentState.lastIncrementalSync?.toIso8601String();
      final serverData = await ApiService.syncDownload(lastSync: lastSyncTime);

      // Update local database
      await _updateLocalDatabase(serverData);

      // Upload any pending changes using existing method
      final uploadResult = await _uploadPendingChanges();

      final downloadedCount = _countRecords(serverData);

      return SyncResult(true, 'Incremental sync completed successfully',
          details: {
            'strategy': 'incrementalSync',
            'downloaded_records': downloadedCount,
            'uploaded_changes': uploadResult['uploaded'] ?? 0,
            'sync_timestamp': serverData['sync_timestamp'] ??
                DateTime.now().toIso8601String(),
          });
    } catch (e) {
      return SyncResult(false, 'Incremental sync failed: ${e.toString()}');
    }
  }

  // ===================================================================
  // HELPER METHODS - Using your existing services
  // ===================================================================

  static Future<void> _updateLocalDatabase(
      Map<String, dynamic> serverData) async {
    // Use your existing SyncService method
    // You'll need to make this method accessible or copy its logic
    print('💾 Updating local database...');

    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      // Update each table type
      for (final tableType in [
        'users',
        'courses',
        'fleet',
        'schedules',
        'invoices',
        'payments'
      ]) {
        if (serverData[tableType] != null) {
          final records = serverData[tableType] as List;
          print('💾 Processing ${records.length} $tableType records...');

          for (final record in records) {
            await txn.insert(
              tableType,
              record,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    });

    print('✅ Local database updated');
  }

  static Future<Map<String, dynamic>> _uploadPendingChanges() async {
    try {
      // Use your existing upload logic
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString('sync_pending_changes');

      if (pendingJson == null || pendingJson.isEmpty || pendingJson == '{}') {
        return {'uploaded': 0, 'message': 'No pending changes'};
      }

      final pendingChanges = json.decode(pendingJson);
      final result = await ApiService.syncUpload(pendingChanges);

      if (result['success'] == true) {
        await prefs.remove('sync_pending_changes');
        return {
          'uploaded': result['uploaded'] ?? 0,
          'message': 'Upload successful'
        };
      } else {
        return {
          'uploaded': 0,
          'message': 'Upload failed: ${result['message']}'
        };
      }
    } catch (e) {
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

  /// Check if production sync is available
  static Future<bool> isProductionSyncAvailable() async {
    try {
      return await ApiService.testServerConnection();
    } catch (e) {
      return false;
    }
  }

  /// Get device sync info for debugging
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
        'device_id': 'unknown',
        'has_sync_state': false,
        'error': e.toString(),
      };
    }
  }

  /// Clear all sync state (for testing/debugging)
  static Future<void> clearSyncState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncStateKey);
    await prefs.remove('sync_pending_changes');
    await prefs.remove('last_sync_timestamp');
    print('🧹 Sync state cleared');
  }
}
