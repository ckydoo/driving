// lib/services/sync_service.dart - FIXED VERSION

import 'dart:convert';
import 'dart:io';
import 'package:driving/services/api_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/sync_result.dart'; // Import shared SyncResult
import 'package:driving/models/user.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/models/fleet.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class SyncService {
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _pendingChangesKey = 'pending_changes';

  // Improved connectivity check
  static Future<bool> isOnline() async {
    try {
      print('🔍 Checking internet connectivity...');

      // Method 1: Try to reach Google's DNS (simple and fast)
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(Duration(seconds: 5));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          print('✅ Internet connection confirmed');
          return true;
        }
      } catch (e) {
        print('⚠️ DNS lookup failed, trying alternative method...');
      }

      // Method 2: Try your API health endpoint if DNS fails
      try {
        final response = await ApiService.checkConnectivity();
        if (response) {
          print('✅ API connectivity confirmed');
          return true;
        }
      } catch (e) {
        print('⚠️ API connectivity check failed: $e');
      }

      print('❌ No internet connection detected');
      return false;
    } catch (e) {
      print('❌ Connectivity check error: $e');
      return false;
    }
  }

  // Also update your SyncService.fullSync method:

  static Future<SyncResult> fullSync({bool forceFullDownload = false}) async {
    try {
      print('🔄 Starting full sync...');

      if (!await isOnline()) {
        return SyncResult(false, 'No internet connection');
      }

      final authController = Get.find<AuthController>();
      if (!authController.isLoggedIn.value) {
        return SyncResult(false, 'User not authenticated');
      }

      final prefs = await SharedPreferences.getInstance();

      // Get last sync timestamp
      String? lastSync;
      if (!forceFullDownload) {
        final lastSyncStored = prefs.getString(_lastSyncKey);
        if (lastSyncStored != null &&
            lastSyncStored != 'Never' &&
            lastSyncStored.isNotEmpty &&
            lastSyncStored.contains('T')) {
          lastSync = lastSyncStored;
          print('📅 Last sync: $lastSync');
        } else {
          lastSync = null;
          print('📅 Last sync: Never (first sync or invalid format)');
        }
      } else {
        // Force full download by not sending Last-Sync header
        lastSync = null;
        print('📅 Forcing full download - ignoring last sync');
      }

      try {
        // Download data from server
        print('⬇️ Downloading data from server...');
        final serverData = await ApiService.syncDownload(lastSync: lastSync);
        print('✅ Server data downloaded successfully');

        // Update local database
        print('💾 Updating local database...');
        await _updateLocalDatabase(serverData);
        print('✅ Local database updated');

        // Upload pending changes ONLY if not forcing full download
        if (!forceFullDownload) {
          print('⬆️ Uploading pending changes...');
          final uploadResult = await _uploadPendingChanges();
          print('✅ Pending changes uploaded');
        } else {
          print('ℹ️ Skipping upload during forced full download');
        }

        // Update last sync timestamp
        final syncTimestamp =
            serverData['sync_timestamp'] ?? DateTime.now().toIso8601String();

        String finalTimestamp;
        if (syncTimestamp is String && syncTimestamp.contains('T')) {
          finalTimestamp = syncTimestamp;
        } else {
          finalTimestamp = DateTime.now().toIso8601String();
        }

        await prefs.setString(_lastSyncKey, finalTimestamp);
        print('✅ Sync timestamp updated: $finalTimestamp');

        final downloadedCount = _countSyncedRecords(serverData);

        print('🎉 Full sync completed successfully');
        print('📊 Downloaded: $downloadedCount records');

        return SyncResult(true, 'Sync completed successfully', details: {
          'downloaded': downloadedCount,
          'uploaded': 0,
          'sync_timestamp': finalTimestamp,
        });
      } catch (e) {
        print('❌ Sync operation failed: $e');
        return SyncResult(false, 'Sync failed: ${e.toString()}');
      }
    } catch (e) {
      print('❌ Full sync error: $e');
      return SyncResult(false, 'Sync error: ${e.toString()}');
    }
  }

  // Upload pending changes to server
  static Future<SyncResult> uploadPendingChanges() async {
    try {
      print('⬆️ Starting upload of pending changes...');

      if (!await isOnline()) {
        return SyncResult(false, 'No internet connection');
      }

      final authController = Get.find<AuthController>();
      if (!authController.isLoggedIn.value) {
        return SyncResult(false, 'User not authenticated');
      }

      final prefs = await SharedPreferences.getInstance();
      final pendingChangesJson = prefs.getString(_pendingChangesKey);

      if (pendingChangesJson == null || pendingChangesJson.isEmpty) {
        print('ℹ️ No pending changes to upload');
        return SyncResult(true, 'No pending changes to upload');
      }

      final pendingChanges = json.decode(pendingChangesJson);

      if (pendingChanges.isEmpty) {
        print('ℹ️ Pending changes empty');
        return SyncResult(true, 'No pending changes to upload');
      }

      print('📤 Uploading ${pendingChanges.length} change groups...');

      // Upload to server
      final result = await ApiService.syncUpload(pendingChanges);

      // Clear pending changes on successful upload
      await prefs.remove(_pendingChangesKey);

      print('✅ Upload completed successfully');

      return SyncResult(true, 'Upload completed', details: {
        'uploaded': result['uploaded'] ?? 0,
      });
    } catch (e) {
      print('❌ Upload failed: $e');
      return SyncResult(false, 'Upload failed: ${e.toString()}');
    }
  }

  // Internal method for uploading pending changes (used by fullSync)
  static Future<SyncResult> _uploadPendingChanges() async {
    return await uploadPendingChanges();
  }

  // Update local database with server data
  static Future<void> _updateLocalDatabase(
      Map<String, dynamic> serverData) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      // Update users
      if (serverData['users'] != null) {
        for (var userData in serverData['users']) {
          final localUserData = _convertUserApiToLocal(userData);
          await txn.insert(
            'users',
            User.fromJson(localUserData).toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Update courses
      if (serverData['courses'] != null) {
        for (var courseData in serverData['courses']) {
          final localCourseData = _convertCourseApiToLocal(courseData);
          await txn.insert(
            'courses',
            Course.fromJson(localCourseData).toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Update schedules
      if (serverData['schedules'] != null) {
        for (var scheduleData in serverData['schedules']) {
          final localScheduleData = _convertScheduleApiToLocal(scheduleData);
          await txn.insert(
            'schedules',
            Schedule.fromJson(localScheduleData).toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Update invoices
      if (serverData['invoices'] != null) {
        for (var invoiceData in serverData['invoices']) {
          final localInvoiceData = _convertInvoiceApiToLocal(invoiceData);
          await txn.insert(
            'invoices',
            Invoice.fromMap(localInvoiceData).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Update payments
      if (serverData['payments'] != null) {
        for (var paymentData in serverData['payments']) {
          final localPaymentData = _convertPaymentApiToLocal(paymentData);
          await txn.insert(
            'payments',
            Payment.fromJson(localPaymentData).toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Update fleet
      if (serverData['fleet'] != null) {
        for (var fleetData in serverData['fleet']) {
          final localFleetData = _convertFleetApiToLocal(fleetData);
          await txn.insert(
            'fleet',
            Fleet.fromJson(localFleetData).toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  // Track changes for later sync
  static Future<void> trackChange(
      String table, Map<String, dynamic> data, String operation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingChangesJson = prefs.getString(_pendingChangesKey) ?? '{}';
      final existingChanges = json.decode(existingChangesJson);

      if (existingChanges[table] == null) {
        existingChanges[table] = [];
      }

      existingChanges[table].add({
        'data': data,
        'operation': operation, // 'create', 'update', 'delete'
        'timestamp': DateTime.now().toIso8601String(),
      });

      await prefs.setString(_pendingChangesKey, json.encode(existingChanges));
      print('📝 Tracked $operation change for $table');
    } catch (e) {
      print('❌ Failed to track change: $e');
    }
  }

  // Get sync status
  static Future<Map<String, dynamic>> getSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_lastSyncKey);
    final pendingChanges = prefs.getString(_pendingChangesKey);

    final isConnected = await isOnline();
    Map<String, dynamic>? serverStatus;

    if (isConnected) {
      try {
        serverStatus = await ApiService.getSyncStatus();
      } catch (e) {
        print('❌ Failed to get server status: $e');
      }
    }

    return {
      'last_sync': lastSync,
      'has_pending_changes': pendingChanges != null && pendingChanges != '{}',
      'is_online': isConnected,
      'server_status': serverStatus,
    };
  }

// Load sync settings - return ISO timestamps, not display format
  static Future<Map<String, dynamic>> loadSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'autoSync': prefs.getBool('auto_sync') ?? true,
        'interval': prefs.getInt('sync_interval') ?? 30,
        'lastSync':
            prefs.getString(_lastSyncKey) ?? 'Never', // Return ISO timestamp
      };
    } catch (e) {
      return {
        'autoSync': true,
        'interval': 30,
        'lastSync': 'Never',
      };
    }
  }

// Save sync settings - only save non-timestamp settings here
  static Future<void> saveSyncSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (settings.containsKey('autoSync')) {
        await prefs.setBool('auto_sync', settings['autoSync'] ?? true);
      }

      if (settings.containsKey('interval')) {
        await prefs.setInt('sync_interval', settings['interval'] ?? 30);
      }

      // DON'T save lastSync here - it's handled separately by fullSync()
      // The timestamp should only be saved in ISO format by the sync process
    } catch (e) {
      print('❌ Failed to save sync settings: $e');
    }
  }

// Alternative method for getting settings for display
  static Future<Map<String, dynamic>> getSyncSettings() async {
    return await loadSyncSettings();
  }

  // Count synced records helper
  static int _countSyncedRecords(Map<String, dynamic> serverData) {
    int count = 0;

    final dataTypes = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet'
    ];
    for (String type in dataTypes) {
      if (serverData[type] != null && serverData[type] is List) {
        count += (serverData[type] as List).length;
      }
    }

    return count;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        // Try parsing as double first, then convert to int
        try {
          return double.parse(value).toInt();
        } catch (e2) {
          print('⚠️ Could not parse int from string: $value');
          return null;
        }
      }
    }
    print('⚠️ Could not parse int from: $value (${value.runtimeType})');
    return null;
  }

  // Update your schedule conversion functions in lib/services/sync_service.dart or api_service.dart

  static Map<String, dynamic> _convertScheduleApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'start': apiData['start'],
      'end': apiData['end'],
      'course': apiData['course'] ?? apiData['course_id'],
      'student': apiData['student'] ?? apiData['student_id'],
      'instructor': apiData['instructor'] ?? apiData['instructor_id'],
      'car': apiData['vehicle'] ?? apiData['vehicle_id'] ?? apiData['car'] ?? 0,
      'class_type': apiData['class_type'] ?? 'Practical',
      'status': apiData['status'] ?? 'Scheduled',
      'attended': apiData['attended'] == 1 || apiData['attended'] == true,
      'lessonsCompleted': apiData['lessons_completed'] ?? 0,
      'lessonsDeducted': _parseInteger(apiData['lessons_deducted']) ?? 1,
      'is_recurring':
          apiData['is_recurring'] == 1 || apiData['is_recurring'] == true,
      'recurrence_pattern':
          apiData['recurring_pattern'] ?? apiData['recurrence_pattern'],
      'recurrence_end_date':
          apiData['recurring_end_date'] ?? apiData['recurrence_end_date'],
      'notes': apiData['notes'],
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
    };
  }

  static Map<String, dynamic> _convertScheduleLocalToApi(
      Map<String, dynamic> localData) {
    return {
      'student': localData['student'], // Keep Flutter field names
      'instructor': localData['instructor'], // Laravel will map these
      'course': localData['course'], // in the upsertSchedule method
      'car': localData['car'] ?? 0,
      'start': localData['start'],
      'end': localData['end'],
      'class_type': localData['class_type'] ?? 'Practical',
      'status': localData['status'] ?? 'Scheduled',
      'attended': localData['attended'] == true ? 1 : 0,
      'lessonsCompleted': localData['lessonsCompleted'] ?? 0,
      'lessonsDeducted': localData['lessonsDeducted'] ?? 1,
      'is_recurring': localData['is_recurring'] == true ? 1 : 0,
      'recurrence_pattern': localData['recurrence_pattern'],
      'recurrence_end_date': localData['recurrence_end_date'],
      'notes': localData['notes'],
    };
  }

// Safe integer parsing helper
  static int _parseInteger(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final doubleValue = double.tryParse(value);
      return doubleValue?.toInt() ?? 0;
    }
    return 0;
  }

  // ✅ FIXED: Fleet conversion method with null safety
  static Map<String, dynamic> _convertFleetApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'carplate': apiData['carplate'] ?? '',
      'make': apiData['make'] ?? '',
      'model': apiData['model'] ?? '',
      'modelyear': apiData['modelyear'] ?? DateTime.now().year,
      'instructor': apiData['instructor'] ?? 0,
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
    };
  }

// Updated conversion functions in lib/services/sync_service.dart

  static Map<String, dynamic> _convertInvoiceApiToLocal(
      Map<String, dynamic> apiData) {
    // Extract student ID from nested student object or direct field
    int studentId;
    if (apiData['student'] is Map<String, dynamic>) {
      studentId = apiData['student']['id'];
    } else if (apiData['student'] is int) {
      studentId = apiData['student'];
    } else if (apiData['student_id'] != null) {
      studentId = apiData['student_id'];
    } else {
      throw Exception('Cannot extract student ID from invoice data');
    }

    // Extract course ID from nested course object or direct field
    int courseId;
    if (apiData['course'] is Map<String, dynamic>) {
      courseId = apiData['course']['id'];
    } else if (apiData['course'] is int) {
      courseId = apiData['course'];
    } else if (apiData['course_id'] != null) {
      courseId = apiData['course_id'];
    } else {
      throw Exception('Cannot extract course ID from invoice data');
    }

    return {
      'id': apiData['id'],
      'invoice_number': apiData['invoice_number'] ?? '',
      'student': studentId,
      'course': courseId,
      'lessons': _parseInteger(apiData['lessons']),
      'price_per_lesson': _parseDouble(apiData['price_per_lesson']),
      'amountpaid': _parseDouble(apiData['amountpaid']),
      'created_at': apiData['created_at'],
      'due_date': apiData['due_date'],
      'status': apiData['status'] ?? 'unpaid',
      'total_amount': _parseDouble(apiData['total_amount']),
      'used_lessons': _parseInteger(apiData['used_lessons'] ?? 0),
      'updated_at': apiData['updated_at'],
    };
  }

  static Map<String, dynamic> _convertPaymentApiToLocal(
      Map<String, dynamic> apiData) {
    // Extract invoice ID from nested invoice object or direct field
    int invoiceId;
    if (apiData['invoice'] is Map<String, dynamic>) {
      invoiceId = apiData['invoice']['id'];
    } else if (apiData['invoice_id'] != null) {
      invoiceId = apiData['invoice_id'];
    } else if (apiData['invoiceId'] != null) {
      invoiceId = apiData['invoiceId'];
    } else {
      throw Exception('Cannot extract invoice ID from payment data');
    }

    // Extract user ID from nested user object or direct field (optional)
    int? userId;
    if (apiData['user'] is Map<String, dynamic>) {
      userId = apiData['user']['id'];
    } else if (apiData['user_id'] != null) {
      userId = apiData['user_id'];
    } else if (apiData['userId'] != null) {
      userId = apiData['userId'];
    }

    return {
      'id': apiData['id'],
      'invoiceId': invoiceId,
      'amount': _parseDouble(apiData['amount']), // Safe conversion
      'method': apiData['method'] ?? apiData['payment_method'] ?? 'Cash',
      'paymentDate': apiData['paymentDate'] ?? apiData['payment_date'],
      'status': apiData['status'] ?? 'Paid',
      'notes': apiData['notes'],
      'reference': apiData['reference'],
      'receipt_path': apiData['receipt_path'],
      'receipt_generated_at': apiData['receipt_generated_at'],
      'cloud_storage_path': apiData['cloud_storage_path'],
      'receipt_file_size': apiData['receipt_file_size'],
      'receipt_type': apiData['receipt_type'],
      'receipt_generated': apiData['receipt_generated'] == true ||
          apiData['receipt_generated'] == 1,
      'userId': userId,
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

// Also add safe conversions for other data types
  static Map<String, dynamic> _convertCourseApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'name': apiData['name'] ?? '',
      'price': _parseDouble(apiData['price']), // Safe conversion
      'status': apiData['status'] ?? 'active',
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
    };
  }

  static Map<String, dynamic> _convertUserApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'fname': apiData['fname'] ?? '',
      'lname': apiData['lname'] ?? '',
      'email': apiData['email'] ?? '',
      'date_of_birth': apiData['date_of_birth'],
      'role': apiData['role'] ?? 'student',
      'status': apiData['status'] ?? 'active',
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
      'gender': apiData['gender'] ?? '',
      'phone': apiData['phone'] ?? '',
      'address': apiData['address'] ?? '',
      'idnumber': apiData['idnumber'] ?? '',
      'email_verified_at': apiData['email_verified_at'],
      'profile_picture': apiData['profile_picture'],
      'emergency_contact': apiData['emergency_contact'],
      'remember_token': apiData['remember_token'],
    };
  }
}
