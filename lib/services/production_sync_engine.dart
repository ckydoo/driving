// lib/services/production_sync_engine.dart
// Create this as a new file in your Flutter project

import 'dart:convert';
import 'dart:io';
import 'package:driving/services/sync_service.dart';
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

      // Step 2: CRITICAL FIX - Register device with server first
      try {
        print('📝 Registering device with server...');
        await ApiService.registerDevice(
          schoolId: schoolId,
          deviceId: currentState.deviceId,
        );
        print('✅ Device registration successful');
      } catch (e) {
        print('⚠️ Device registration failed: $e');
        // Continue anyway - device might already be registered
        // or this might be a network issue
      }

      // Step 3: Determine strategy
      final strategy =
          await _determineSyncStrategy(currentState, forceFullSync);
      print('🎯 Sync Strategy: ${strategy.name}');

      // Step 4: Execute sync based on strategy
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

      // Step 5: Update sync state on success
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
  // FULL SYNC EXECUTION - ALSO FIXED TO ENSURE DEVICE REGISTRATION
  // ===================================================================

  static Future<SyncResult> _executeFullSync(DeviceSyncState state) async {
    try {
      print('⬇️ Executing full sync...');

      // Ensure device is registered before downloading
      try {
        await ApiService.registerDevice(
          schoolId: state.schoolId,
          deviceId: state.deviceId,
        );
      } catch (e) {
        print('⚠️ Device re-registration failed during full sync: $e');
        // Continue anyway
      }

      // Download all school data
      final serverData = await ApiService.downloadAllSchoolData(
        schoolId: state.schoolId,
      );

      // Update local database
      await _updateLocalDatabase(serverData);

      // Upload any pending changes
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
    print('💾 Updating local database with relationship handling...');

    final db = await DatabaseHelper.instance.database;
    int totalInserted = 0;
    int totalFailed = 0;

    await db.transaction((txn) async {
      // Process each table type
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
            try {
              // Convert Laravel data to SQLite format
              final convertedRecord = _convertRecord(record, tableType);

              await txn.insert(
                tableType,
                convertedRecord,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              totalInserted++;
              print('✅ Synced $tableType: ${convertedRecord['id']}');
            } catch (e) {
              totalFailed++;
              print('❌ Failed to sync $tableType record: $e');
            }
          }
        }
      }
    });

    print(
        '✅ Database sync completed: $totalInserted inserted, $totalFailed failed');
  }

// ADD this new method to handle the conversions:
  static Map<String, dynamic> _convertRecord(
      Map<String, dynamic> data, String tableType) {
    switch (tableType) {
      case 'users':
        return _convertUserRecord(data);
      case 'courses':
        return _convertCourseRecord(data);
      case 'fleet':
        return _convertFleetRecord(data);
      case 'schedules':
        return _convertScheduleRecord(data);
      case 'invoices':
        return _convertInvoiceRecord(data);
      case 'payments':
        return _convertPaymentRecord(data);
      default:
        return _cleanRecord(data);
    }
  }

// ADD these conversion methods:

  static Map<String, dynamic> _convertUserRecord(Map<String, dynamic> data) {
    // Only include fields your users table has
    return {
      'id': data['id']?.toString(),
      'fname': data['fname']?.toString() ?? '',
      'lname': data['lname']?.toString() ?? '',
      'email': data['email']?.toString() ?? '',
      'password': '', // Don't sync passwords
      'role': data['role']?.toString() ?? 'student',
      'status': data['status']?.toString() ?? 'Active',
      'date_of_birth': data['date_of_birth']?.toString() ?? '2000-01-01',
      'gender': data['gender']?.toString() ?? 'other',
      'phone': data['phone']?.toString() ?? '',
      'address': data['address']?.toString() ?? '',
      'idnumber': data['idnumber']?.toString() ?? '',
      'created_at':
          data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'updated_at':
          data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      'school_id': data['school_id']?.toString(),
    };
  }

  static Map<String, dynamic> _convertScheduleRecord(
      Map<String, dynamic> data) {
    // Extract IDs from nested objects
    String? student;
    String? instructor;
    String? course;
    String? car;

    // Handle nested student: {student: {id: 2}} → student: "2"
    if (data['student'] is Map) {
      student = (data['student'] as Map)['id']?.toString();
    } else {
      student = data['student']?.toString() ?? data['student']?.toString();
    }

    // Handle nested instructor
    if (data['instructor'] is Map) {
      instructor = (data['instructor'] as Map)['id']?.toString();
    } else {
      instructor =
          data['instructor']?.toString() ?? data['instructor_id']?.toString();
    }

    // Handle nested course
    if (data['course'] is Map) {
      course = (data['course'] as Map)['id']?.toString();
    } else {
      course = data['course']?.toString() ?? data['course_id']?.toString();
    }

    // Handle nested car
    if (data['car'] is Map) {
      car = (data['car'] as Map)['id']?.toString();
    } else {
      car = data['car']?.toString() ?? data['vehicle_id']?.toString();
    }

    return {
      'id': data['id']?.toString(),
      'student': student,
      'instructor': instructor,
      'course': course,
      'car': car,
      'start': data['start']?.toString() ?? '',
      'end': data['end']?.toString() ?? '',
      'status': data['status']?.toString() ?? 'scheduled',
      'class_type': data['class_type']?.toString() ?? 'practical',
      'attended': _convertBoolean(data['attended']),
      'is_recurring': _convertBoolean(data['is_recurring']),
      'recurrence_pattern': data['recurrence_pattern']?.toString(),
      'recurrence_end_date': data['recurrence_end_date']?.toString(),
      'created_at':
          data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'updated_at':
          data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      'school_id': data['school_id']?.toString(),
    };
  }

  static Map<String, dynamic> _convertInvoiceRecord(Map<String, dynamic> data) {
    // Extract student ID from nested object
    String? student;
    if (data['student'] is Map) {
      student = (data['student'] as Map)['id']?.toString();
    } else {
      student = data['student']?.toString() ?? data['student']?.toString();
    }

    // Extract course ID from nested object
    String? course;
    if (data['course'] is Map) {
      course = (data['course'] as Map)['id']?.toString();
    } else {
      course = data['course']?.toString() ?? data['course_id']?.toString();
    }

    return {
      'id': data['id']?.toString(),
      'student': student,
      'course': course,
      'invoice_number': data['invoice_number']?.toString() ??
          'INV-${DateTime.now().millisecondsSinceEpoch}',
      'total_amount': _parseDouble(data['total_amount']) ?? 0.0,
      'amountpaid':
          _parseDouble(data['amountpaid'] ?? data['amountpaid']) ?? 0.0,
      'status': data['status']?.toString() ?? 'pending',
      'lessons': data['lessons']?.toString() ?? '',
      'price_per_lesson': _parseDouble(data['price_per_lesson']) ?? 0.0,
      'due_date': data['due_date']?.toString() ??
          DateTime.now()
              .add(Duration(days: 30))
              .toIso8601String()
              .split('T')[0],
      'created_at':
          data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'updated_at':
          data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      'school_id': data['school_id']?.toString(),
    };
  }

  static Map<String, dynamic> _convertPaymentRecord(Map<String, dynamic> data) {
    // Extract invoice ID from nested object
    String? invoiceId;
    if (data['invoice'] is Map) {
      invoiceId = (data['invoice'] as Map)['id']?.toString();
    } else {
      invoiceId =
          data['invoiceId']?.toString() ?? data['invoiceId']?.toString();
    }

    // Extract user ID from nested object
    String? userId;
    if (data['user'] is Map) {
      userId = (data['user'] as Map)['id']?.toString();
    } else {
      userId = data['userId']?.toString() ?? data['user_id']?.toString();
    }

    return {
      'id': data['id']?.toString(),
      'invoiceId': invoiceId,
      'amount': _parseDouble(data['amount']) ?? 0.0,
      'method': data['method']?.toString() ?? 'cash',
      'paymentDate': data['paymentDate']?.toString() ??
          data['payment_date']?.toString() ??
          DateTime.now().toIso8601String().split('T')[0],
      'status': data['status']?.toString() ?? 'completed',
      'notes': data['notes']?.toString() ?? '',
      'reference': data['reference']?.toString() ?? '',
      'receipt_path': data['receipt_path']?.toString() ?? '',
      'receipt_generated': _convertBoolean(data['receipt_generated']),
      'userId': userId,
      'created_at':
          data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'updated_at':
          data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _convertCourseRecord(Map<String, dynamic> data) {
    return {
      'id': data['id']?.toString(),
      'name': data['name']?.toString() ?? '',
      'price': _parseDouble(data['price']) ?? 0.0,
      'status': data['status']?.toString() ?? 'active',
      'created_at':
          data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'updated_at':
          data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      'school_id': data['school_id']?.toString(),
    };
  }

  static Map<String, dynamic> _convertFleetRecord(Map<String, dynamic> data) {
    return {
      'id': data['id']?.toString(),
      'carplate': data['carplate']?.toString() ?? '',
      'make': data['make']?.toString() ?? '',
      'model': data['model']?.toString() ?? '',
      'modelyear':
          data['modelyear']?.toString() ?? DateTime.now().year.toString(),
      'status': data['status']?.toString() ?? 'available',
      'instructor': data['instructor']?.toString(),
      'created_at':
          data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'updated_at':
          data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      'school_id': data['school_id']?.toString(),
    };
  }

// Helper method for unknown tables
  static Map<String, dynamic> _cleanRecord(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Remove nested objects and convert booleans
    for (final key in result.keys.toList()) {
      final value = result[key];

      if (value is bool) {
        result[key] = value ? 1 : 0;
      } else if (value is Map || value is List) {
        result.remove(key); // Remove nested objects
      }
    }

    return result;
  }

// Helper conversion methods (ADD these if you don't have them):

  static int _convertBoolean(dynamic value) {
    if (value == null) return 0;
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value != 0 ? 1 : 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return (lower == 'true' || lower == '1' || lower == 'yes') ? 1 : 0;
    }
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

// ✅ NEW: Add this helper method to fix SQLite type issues
  static Map<String, dynamic> _fixSQLiteTypes(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Convert all boolean values to integers (SQLite doesn't support boolean)
    for (final key in result.keys.toList()) {
      final value = result[key];

      if (value is bool) {
        result[key] = value ? 1 : 0;
        print('🔄 Converted boolean $key: $value -> ${result[key]}');
      }
    }

    return result;
  }

  static Future<Map<String, dynamic>> _uploadPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString('sync_pending_changes');

      if (pendingJson == null || pendingJson.isEmpty || pendingJson == '{}') {
        return {'uploaded': 0, 'message': 'No pending changes'};
      }

      final pendingChanges = json.decode(pendingJson) as Map<String, dynamic>;

      // ✅ FIX: Convert Map structure to List format expected by API
      final changesList = <Map<String, dynamic>>[];

      for (final entry in pendingChanges.entries) {
        final dataType = entry.key;
        final items = entry.value as List<dynamic>;

        for (final item in items) {
          changesList.add({
            'table': dataType,
            'operation': item['operation'] ?? 'create',
            'data': item['data'],
            'id': item['data']['id'],
          });
        }
      }

      // Now pass the List instead of Map to syncUpload
      final result = await ApiService.syncUpload(changesList);

      if (result['success'] == true) {
        await prefs.remove('sync_pending_changes');
        return {
          'uploaded': result['uploaded'] ?? changesList.length,
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
