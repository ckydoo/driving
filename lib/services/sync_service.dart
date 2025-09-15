// lib/services/sync_service.dart - CORRECTED VERSION

import 'dart:convert';
import 'package:driving/services/api_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/auth_controller.dart';
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

  // Check if device is online and can reach the API
  static Future<bool> isOnline() async {
    return await ApiService.checkConnectivity();
  }

  // Full sync - download all data from server
  static Future<SyncResult> fullSync() async {
    try {
      if (!await isOnline()) {
        return SyncResult(false, 'No internet connection');
      }

      final authController = Get.find<AuthController>();
      if (!authController.isLoggedIn.value) {
        return SyncResult(false, 'User not authenticated');
      }

      // Get last sync timestamp
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_lastSyncKey);

      // Download data from server
      final serverData = await ApiService.syncDownload(lastSync: lastSync);

      // Update local database
      await _updateLocalDatabase(serverData);

      // Upload pending changes
      final uploadResult = await _uploadPendingChanges();

      // Update last sync timestamp
      await prefs.setString(_lastSyncKey, serverData['sync_timestamp']);

      return SyncResult(true, 'Sync completed successfully', details: {
        'downloaded': _countSyncedRecords(serverData),
        'uploaded': uploadResult.details?['uploaded'] ?? 0,
      });
    } catch (e) {
      return SyncResult(false, 'Sync failed: ${e.toString()}');
    }
  }

  // Upload local changes to server
  static Future<SyncResult> _uploadPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingChangesJson = prefs.getString(_pendingChangesKey);

      if (pendingChangesJson == null) {
        return SyncResult(true, 'No pending changes');
      }

      final pendingChanges = json.decode(pendingChangesJson);

      if (pendingChanges.isEmpty) {
        return SyncResult(true, 'No pending changes');
      }

      // Upload to server
      final result = await ApiService.syncUpload(pendingChanges);

      // Clear pending changes on successful upload
      await prefs.remove(_pendingChangesKey);

      return SyncResult(true, 'Upload completed', details: result);
    } catch (e) {
      return SyncResult(false, 'Upload failed: ${e.toString()}');
    }
  }

  // Update local database with server data
  static Future<void> _updateLocalDatabase(
      Map<String, dynamic> serverData) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      // Update users
      if (serverData['users'] != null) {
        for (var userData in serverData['users']) {
          // Convert API format to local format before storing
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
  }

  // Get sync status
  static Future<Map<String, dynamic>> getSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_lastSyncKey);
    final pendingChanges = prefs.getString(_pendingChangesKey);

    final isConnected = await isOnline();
    final serverStatus = isConnected ? await ApiService.getSyncStatus() : null;

    return {
      'last_sync': lastSync,
      'has_pending_changes': pendingChanges != null && pendingChanges != '{}',
      'is_online': isConnected,
      'server_status': serverStatus,
    };
  }

  // Count synced records
  static int _countSyncedRecords(Map<String, dynamic> data) {
    int count = 0;
    for (String key in [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet'
    ]) {
      if (data[key] != null) {
        count += (data[key] as List).length;
      }
    }
    return count;
  }

  // Auto sync when coming online
  static Future<void> autoSync() async {
    if (await isOnline()) {
      final status = await getSyncStatus();

      // Sync if we have pending changes or haven't synced in 24 hours
      final shouldSync = status['has_pending_changes'] == true ||
          status['last_sync'] == null ||
          DateTime.now()
                  .difference(DateTime.parse(status['last_sync']))
                  .inHours >
              24;

      if (shouldSync) {
        await fullSync();
      }
    }
  }

  // ========================================
  // DATA CONVERSION METHODS (Same as ApiService)
  // ========================================

  // User conversions
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
      'gender': apiData['gender'],
      'phone': apiData['phone'],
      'address': apiData['address'],
      'idnumber': apiData['idnumber'],
    };
  }

  // Schedule conversions
  static Map<String, dynamic> _convertScheduleApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'start': apiData['start'],
      'end': apiData['end'],
      'course': apiData['course_id'],
      'student': apiData['student_id'],
      'instructor': apiData['instructor_id'],
      'car': apiData['car_id'],
      'class_type': apiData['class_type'],
      'status': apiData['status'],
      'attended': apiData['attended'],
      'lessonsDeducted': apiData['lessons_deducted'],
      'is_recurring': apiData['is_recurring'],
      'recurrence_pattern': apiData['recurring_pattern'],
      'recurrence_end_date': apiData['recurring_end_date'],
    };
  }

  // Course conversions
  static Map<String, dynamic> _convertCourseApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'name': apiData['name'],
      'description': apiData['description'],
      'price': apiData['price'],
      'lessons': apiData['lessons'],
      'type': apiData['type'],
      'status': apiData['status'],
      'duration_minutes': apiData['duration_minutes'],
    };
  }

  // Fleet conversions
  static Map<String, dynamic> _convertFleetApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'carplate': apiData['registration'],
      'make': apiData['make'],
      'model': apiData['model'],
      'modelyear': apiData['year'].toString(),
      'instructor': apiData['assigned_instructor_id'] ?? 0,
    };
  }

  // Invoice conversions
  static Map<String, dynamic> _convertInvoiceApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'invoice_number': apiData['invoice_number'],
      'student': apiData['student_id'],
      'course': apiData['course_id'],
      'lessons': apiData['lessons'],
      'price_per_lesson': apiData['price_per_lesson'],
      'amountpaid': apiData['amount_paid'],
      'created_at': apiData['created_at'],
      'due_date': apiData['due_date'],
      'status': apiData['status'],
      'total_amount': apiData['total_amount'],
    };
  }

  // Payment conversions
  static Map<String, dynamic> _convertPaymentApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'invoiceId': apiData['invoice_id'],
      'amount': apiData['amount'],
      'method': apiData['payment_method'],
      'paymentDate': apiData['payment_date'],
      'notes': apiData['notes'],
      'reference': apiData['reference_number'],
      'receipt_path': apiData['receipt_path'],
    };
  }
}

class SyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? details;

  SyncResult(this.success, this.message, {this.details});
}
