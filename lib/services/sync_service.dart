// lib/services/sync_service.dart - COMPLETE VERSION WITH ALL CONSTANTS

import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:get/get.dart';

// Import your existing files (adjust paths as needed)
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../controllers/auth_controller.dart';
import '../models/sync_result.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../models/fleet.dart';

class SyncService {
  // ✅ ALL REQUIRED CONSTANTS DEFINED HERE - MADE PUBLIC SO OTHER CLASSES CAN ACCESS
  static const String lastSyncKey = 'last_sync_timestamp';
  static const String pendingChangesKey = 'sync_pending_changes';
  static const String syncSettingsKey = 'sync_settings';

  // Private aliases for backward compatibility within this class
  static const String _lastSyncKey = lastSyncKey;
  static const String _pendingChangesKey = pendingChangesKey;
  static const String _syncSettingsKey = syncSettingsKey;

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

      // Method 2: Try a simple HTTP request
      try {
        final response = await HttpClient()
            .getUrl(Uri.parse('https://www.google.com'))
            .timeout(Duration(seconds: 5));
        await response.close();
        print('✅ HTTP connectivity confirmed');
        return true;
      } catch (e) {
        print('⚠️ HTTP connectivity check failed: $e');
      }

      print('❌ No internet connection detected');
      return false;
    } catch (e) {
      print('❌ Connectivity check error: $e');
      return false;
    }
  }

  // Full sync with server
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
          final downloadedCount = _countSyncedRecords(serverData);
          // Update last sync timestamp
          final syncTimestamp =
              serverData['sync_timestamp'] ?? DateTime.now().toIso8601String();

          String finalTimestamp;
          if (syncTimestamp is String && syncTimestamp.contains('T')) {
            finalTimestamp = syncTimestamp;
          } else {
            finalTimestamp = DateTime.now().toIso8601String();
          }
          // ✅ FIXED: Check upload result and fail sync if upload fails
          if (!uploadResult.success) {
            print('❌ Upload failed during full sync');
            return SyncResult(false, 'Sync failed: ${uploadResult.message}',
                details: {
                  'downloaded': downloadedCount,
                  'uploaded': 0,
                  'upload_error': uploadResult.message,
                  'sync_timestamp': finalTimestamp,
                });
          }

          print('✅ Pending changes uploaded successfully');
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

  // Upload pending changes to server - FIXED VERSION
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

      // ✅ ONLY CLEAR PENDING CHANGES ON COMPLETE SUCCESS
      if (result['success'] == true && (result['errors'] as List).isEmpty) {
        // Complete success - clear all pending changes
        await prefs.remove(_pendingChangesKey);
        print('✅ Upload completed successfully - cleared all pending changes');

        return SyncResult(true, 'Upload completed', details: {
          'uploaded': result['uploaded'] ?? 0,
          'errors': [],
          'partial': false,
        });
      } else if (result['success'] == true &&
          (result['errors'] as List).isNotEmpty) {
        // Partial success - remove only successful items from pending changes
        final errors = result['errors'] as List;
        final successfulItems =
            await _removeSuccessfulItemsFromPending(pendingChanges, errors);

        print(
            '⚠️ Upload partially successful - ${successfulItems} items processed, ${errors.length} failed');

        return SyncResult(true, 'Upload partially completed', details: {
          'uploaded': result['uploaded'] ?? 0,
          'errors': errors,
          'partial': true,
        });
      } else {
        // Complete failure - keep all pending changes
        print('❌ Upload failed completely - keeping pending changes');

        return SyncResult(
            false, 'Upload failed: ${result['message'] ?? 'Unknown error'}',
            details: {
              'uploaded': 0,
              'errors': result['errors'] ?? [],
              'partial': false,
            });
      }
    } catch (e) {
      print('❌ Upload failed: $e');
      return SyncResult(false, 'Upload failed: ${e.toString()}');
    }
  }

  // Internal method for uploading pending changes (used by fullSync)
  static Future<SyncResult> _uploadPendingChanges() async {
    return await uploadPendingChanges();
  }

  // Helper method to remove only successful items from pending changes
  static Future<int> _removeSuccessfulItemsFromPending(
      Map<String, dynamic> pendingChanges, List<dynamic> errors) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int successfulItems = 0;

      // Create a map of failed items by type and ID for quick lookup
      final failedItems = <String, Set<String>>{};
      for (final error in errors) {
        if (error is Map<String, dynamic> &&
            error.containsKey('item') &&
            error['item'].containsKey('data')) {
          final itemData = error['item']['data'] as Map<String, dynamic>;
          final itemType = _getItemType(
              error); // Implement this based on your error structure
          final itemId = itemData['id']?.toString();

          if (itemType != null && itemId != null) {
            failedItems.putIfAbsent(itemType, () => <String>{}).add(itemId);
          }
        }
      }

      // Remove successful items from each data type
      final updatedChanges = <String, dynamic>{};

      for (final entry in pendingChanges.entries) {
        final dataType = entry.key;
        final items = entry.value as List<dynamic>;
        final failedItemsForType = failedItems[dataType] ?? <String>{};

        final remainingItems = <dynamic>[];

        for (final item in items) {
          final itemData = item['data'] as Map<String, dynamic>;
          final itemId = itemData['id']?.toString();

          if (itemId != null && failedItemsForType.contains(itemId)) {
            // This item failed - keep it in pending changes
            remainingItems.add(item);
          } else {
            // This item succeeded - remove it from pending changes
            successfulItems++;
          }
        }

        if (remainingItems.isNotEmpty) {
          updatedChanges[dataType] = remainingItems;
        }
      }

      // Save updated pending changes
      if (updatedChanges.isNotEmpty) {
        await prefs.setString(_pendingChangesKey, json.encode(updatedChanges));
        print(
            '📝 Updated pending changes: removed $successfulItems successful items');
      } else {
        await prefs.remove(_pendingChangesKey);
        print(
            '🧹 Cleared all pending changes - all items processed successfully');
      }

      return successfulItems;
    } catch (e) {
      print('❌ Error updating pending changes: $e');
      return 0;
    }
  }

  static String? _getItemType(Map<String, dynamic> error) {
    // This method should extract the item type from the error structure
    // You'll need to implement this based on how your server structures error responses

    // Method 1: Check if errors include the table name directly
    if (error.containsKey('table')) {
      return error['table'];
    }

    // Method 2: Infer from the item data structure
    final item = error['item'];
    if (item != null && item['data'] != null) {
      final data = item['data'] as Map<String, dynamic>;

      // Infer type from data structure
      if (data.containsKey('fname') || data.containsKey('lname'))
        return 'users';
      if (data.containsKey('course_name') || data.containsKey('duration_hours'))
        return 'courses';
      if (data.containsKey('make') || data.containsKey('carplate'))
        return 'fleet';
      if (data.containsKey('start') || data.containsKey('end'))
        return 'schedules';
      if (data.containsKey('total_amount') || data.containsKey('due_date'))
        return 'invoices';
      if (data.containsKey('payment_method') ||
          data.containsKey('payment_date')) return 'payments';
    }

    return null;
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

  // Update local database with server data
  static Future<void> _updateLocalDatabase(
      Map<String, dynamic> serverData) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      // Update users with school_id support
      if (serverData['users'] != null) {
        print('💾 Processing ${(serverData['users'] as List).length} users...');
        for (var userData in serverData['users']) {
          try {
            // Convert API format to local format with school_id
            final localUserData = _convertUserApiToLocalFixed(userData);
            print(
                '📝 Converting user: ${userData['email']} (school_id: ${userData['school_id']})');

            await txn.insert(
              'users',
              localUserData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            print('✅ Synced user: ${userData['email']}');
          } catch (e) {
            print('❌ Failed to sync user ${userData['email']}: $e');
          }
        }
      }

      // Update courses
      if (serverData['courses'] != null) {
        print(
            '💾 Processing ${(serverData['courses'] as List).length} courses...');
        for (var courseData in serverData['courses']) {
          try {
            final localCourseData = _convertCourseApiToLocal(courseData);
            await txn.insert(
              'courses',
              localCourseData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            print('❌ Failed to sync course: $e');
          }
        }
      }

      // Update schedules
      if (serverData['schedules'] != null) {
        print(
            '💾 Processing ${(serverData['schedules'] as List).length} schedules...');
        for (var scheduleData in serverData['schedules']) {
          try {
            final localScheduleData = _convertScheduleApiToLocal(scheduleData);
            await txn.insert(
              'schedules',
              localScheduleData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            print('❌ Failed to sync schedule: $e');
          }
        }
      }

      // Update invoices
      if (serverData['invoices'] != null) {
        print(
            '💾 Processing ${(serverData['invoices'] as List).length} invoices...');
        for (var invoiceData in serverData['invoices']) {
          try {
            final localInvoiceData = _convertInvoiceApiToLocal(invoiceData);
            await txn.insert(
              'invoices',
              localInvoiceData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            print('❌ Failed to sync invoice: $e');
          }
        }
      }

      // Update payments
      if (serverData['payments'] != null) {
        print(
            '💾 Processing ${(serverData['payments'] as List).length} payments...');
        for (var paymentData in serverData['payments']) {
          try {
            final localPaymentData = _convertPaymentApiToLocal(paymentData);
            await txn.insert(
              'payments',
              localPaymentData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            print('❌ Failed to sync payment: $e');
          }
        }
      }

      // Update fleet
      if (serverData['fleet'] != null) {
        print(
            '💾 Processing ${(serverData['fleet'] as List).length} fleet items...');
        for (var fleetData in serverData['fleet']) {
          try {
            final localFleetData = _convertFleetApiToLocal(fleetData);
            await txn.insert(
              'fleet',
              localFleetData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            print('❌ Failed to sync fleet item: $e');
          }
        }
      }
    });
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

  // Load sync settings
  static Future<Map<String, dynamic>> loadSyncSettings() async {
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

  // Save sync settings
  static Future<void> saveSyncSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (settings.containsKey('autoSync')) {
        await prefs.setBool('auto_sync', settings['autoSync'] ?? true);
      }

      if (settings.containsKey('interval')) {
        await prefs.setInt('sync_interval', settings['interval'] ?? 30);
      }
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

  // Conversion methods (implement these based on your data structure)
  static Map<String, dynamic> _convertUserApiToLocalFixed(
      Map<String, dynamic> userData) {
    return {
      'id': userData['id'],
      'fname': userData['fname'] ?? '',
      'lname': userData['lname'] ?? '',
      'email': userData['email'],
      'role': userData['role'],
      'phone': userData['phone'] ?? '',
      'password': userData['password'] ?? '',
      'status': userData['status'] ?? 'active',
      'date_of_birth': userData['date_of_birth'] ?? '2000-01-01',
      'gender': userData['gender'] ?? 'other',
      'address': userData['address'] ?? '',
      'last_login': userData['last_login'] ?? '',
      'idnumber': userData['idnumber'],
      'school_id': userData['school_id'],
    };
  }

  static Map<String, dynamic> _convertCourseApiToLocal(
      Map<String, dynamic> courseData) {
    return {
      'id': courseData['id'],
      'name': courseData['name'],
      'price': courseData['price'] ?? 0.0,
      'status': courseData['status'] ?? 'active',
      'school_id': courseData['school_id'],
    };
  }

  static Map<String, dynamic> _convertScheduleApiToLocal(
      Map<String, dynamic> scheduleData) {
    return {
      'id': scheduleData['id'],
      'student_id': scheduleData['student'],
      'instructor_id': scheduleData['instructor'],
      'course_id': scheduleData['course'],
      'vehicle_id': scheduleData['vehicle'],
      'start': scheduleData['start'],
      'end': scheduleData['end'],
      'is_recurring': scheduleData['is_recurring'] ?? 0,
      'recurrence_pattern': scheduleData['recurrence_pattern'] ?? '',
      'recurrence_end_date': scheduleData['recurrence_end_date'] ?? '',
      'attended': scheduleData['attended'] ?? 0,
      'lessons_completed': scheduleData['lessons_completed'] ?? 0,
      'lessons_deducted': scheduleData['lessons_deducted'] ?? 0,
      'status': scheduleData['status'] ?? 'scheduled',
      'class_type': scheduleData['class_type'] ?? 'Practical',
      'notes': scheduleData['notes'] ?? '',
      'school_id': scheduleData['school_id'],
    };
  }

  static Map<String, dynamic> _convertInvoiceApiToLocal(
      Map<String, dynamic> invoiceData) {
    return {
      'id': invoiceData['id'],
      'student': invoiceData['student'],
      'lessons': invoiceData['lessons'] ?? 0,
      'invoice_number': invoiceData['invoice_number'],
      'course': invoiceData['course'],
      'amountpaid': invoiceData['amountpaid'] ?? 0.0,
      'price_per_lesson': invoiceData['price_per_lesson'] ?? 0.0,
      'used_lessons': invoiceData['used_lessons'] ?? 0,
      'total_amount': invoiceData['total_amount'],
      'status': invoiceData['status'] ?? 'pending',
      'due_date': invoiceData['due_date'],
      'school_id': invoiceData['school_id'],
    };
  }

  static Map<String, dynamic> _convertPaymentApiToLocal(
      Map<String, dynamic> paymentData) {
    return {
      'id': paymentData['id'],
      'invoiceId': paymentData['invoiceId'],
      'amount': paymentData['amount'],
      'method': paymentData['method'] ?? 'cash',
      'reference': paymentData['reference'] ?? '',
      'receipt_path': paymentData['receipt_path'] ?? '',
      'receipt_generated': paymentData['receipt_generated'] ?? 0,
      'userId': paymentData['userId'] ?? 0,
      'paymentDate': paymentData['paymentDate'],
      'status': paymentData['status'] ?? 'completed',
    };
  }

  static Map<String, dynamic> _convertFleetApiToLocal(
      Map<String, dynamic> fleetData) {
    return {
      'id': fleetData['id'],
      'make': fleetData['make'],
      'model': fleetData['model'],
      'modelyear': fleetData['modelyear'] ?? fleetData['modelyear'],
      'carPlate': fleetData['carplate'] ?? fleetData['carPlate'],
      'status': fleetData['status'] ?? 'available',
      'instructor': fleetData['instructor'],
      'school_id': fleetData['school_id'],
    };
  }

  // Add this method to your SyncService class

  static Future<void> clearAllSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear all sync-related data
      await prefs.remove('sync_pending_changes');
      await prefs.remove('last_sync_timestamp');
      await prefs.remove('sync_debug_logs');
      await prefs.remove('sync_last_error');

      print('🧹 All sync data cleared successfully');
      print('✅ Pending changes cleared');
      print('✅ Sync timestamps cleared');
      print('✅ Debug logs cleared');
    } catch (e) {
      print('❌ Failed to clear sync data: $e');
    }
  }
}
