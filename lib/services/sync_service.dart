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

  // Full sync - download all data from server
  static Future<SyncResult> fullSync() async {
    try {
      print('🔄 Starting full sync...');

      // Check authentication first
      final authController = Get.find<AuthController>();
      if (!authController.isLoggedIn.value) {
        print('❌ User not authenticated');
        return SyncResult(false, 'User not authenticated');
      }

      // Check connectivity
      if (!await isOnline()) {
        print('❌ No internet connection');
        return SyncResult(false, 'No internet connection');
      }

      print('✅ Prerequisites met, proceeding with sync...');

      // Get last sync timestamp
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_lastSyncKey);
      print('📅 Last sync: ${lastSync ?? 'Never'}');

      try {
        // Download data from server
        print('⬇️ Downloading data from server...');
        final serverData = await ApiService.syncDownload(lastSync: lastSync);
        print('✅ Server data downloaded successfully');

        // Update local database
        print('💾 Updating local database...');
        await _updateLocalDatabase(serverData);
        print('✅ Local database updated');

        // Upload pending changes
        print('⬆️ Uploading pending changes...');
        final uploadResult = await _uploadPendingChanges();
        print('✅ Pending changes uploaded');

        // Update last sync timestamp
        final syncTimestamp =
            serverData['sync_timestamp'] ?? DateTime.now().toIso8601String();
        await prefs.setString(_lastSyncKey, syncTimestamp);
        print('✅ Sync timestamp updated');

        final downloadedCount = _countSyncedRecords(serverData);
        final uploadedCount = uploadResult.uploadedCount;

        print('🎉 Full sync completed successfully');
        print('📊 Downloaded: $downloadedCount records');
        print('📊 Uploaded: $uploadedCount records');

        return SyncResult(true, 'Sync completed successfully', details: {
          'downloaded': downloadedCount,
          'uploaded': uploadedCount,
          'sync_timestamp': syncTimestamp,
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

  // Get/Save sync settings
  static Future<Map<String, dynamic>> getSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'autoSync': prefs.getBool('auto_sync') ?? true,
        'interval': prefs.getInt('sync_interval') ?? 30,
        'lastSync': prefs.getString(_lastSyncKey) ?? 'Never',
      };
    } catch (e) {
      return {
        'autoSync': true,
        'interval': 30,
        'lastSync': 'Never',
      };
    }
  }

  static Future<void> saveSyncSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_sync', settings['autoSync'] ?? true);
      await prefs.setInt('sync_interval', settings['interval'] ?? 30);
      if (settings['lastSync'] != null) {
        await prefs.setString(_lastSyncKey, settings['lastSync']);
      }
    } catch (e) {
      print('❌ Failed to save sync settings: $e');
    }
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

  // Data conversion methods
  static Map<String, dynamic> _convertUserApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'fname': apiData['fname'],
      'lname': apiData['lname'],
      'email': apiData['email'],
      'date_of_birth': apiData['date_of_birth'],
      'password': '', // Don't store password locally
      'role': apiData['role'],
      'status': apiData['status'],
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
      'gender': apiData['gender'],
      'phone': apiData['phone'],
      'address': apiData['address'],
      'idnumber': apiData['idnumber'],
      'email_verified_at': apiData['email_verified_at'],
      'profile_picture': apiData['profile_picture'],
      'emergency_contact': apiData['emergency_contact'],
      'remember_token': apiData['remember_token'],
    };
  }

  static Map<String, dynamic> _convertCourseApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'name': apiData['name'],
      'price': apiData['price'],
      'status': apiData['status'],
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
    };
  }

  static Map<String, dynamic> _convertScheduleApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'student_id': apiData['student_id'],
      'instructor_id': apiData['instructor_id'],
      'course_id': apiData['course_id'],
      'vehicle_id': apiData['vehicle_id'],
      'lesson_date': apiData['lesson_date'],
      'lesson_time': apiData['lesson_time'],
      'duration': apiData['duration'],
      'status': apiData['status'],
      'lesson_type': apiData['lesson_type'],
      'notes': apiData['notes'],
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
    };
  }

  static Map<String, dynamic> _convertInvoiceApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'student': apiData['student_id'],
      'course': apiData['course_id'],
      'amount': apiData['amount'],
      'status': apiData['status'],
      'due_date': apiData['due_date'],
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
    };
  }

  static Map<String, dynamic> _convertPaymentApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'invoice_id': apiData['invoice_id'],
      'student_id': apiData['student_id'],
      'amount': apiData['amount'],
      'payment_method': apiData['payment_method'],
      'payment_date': apiData['payment_date'],
      'status': apiData['status'],
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
    };
  }

  static Map<String, dynamic> _convertFleetApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'make': apiData['make'],
      'model': apiData['model'],
      'year': apiData['year'],
      'license_plate': apiData['license_plate'],
      'status': apiData['status'],
      'created_at': apiData['created_at'],
      'updated_at': apiData['updated_at'],
    };
  }
}
