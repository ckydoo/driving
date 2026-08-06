import 'package:flutter/foundation.dart';
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

class SyncService {
  // ✅ ALL REQUIRED CONSTANTS DEFINED HERE - MADE PUBLIC SO OTHER CLASSES CAN ACCESS
  static const String lastSyncKey = 'last_sync_timestamp';
  static const String pendingChangesKey = 'sync_pending_changes';
  static const String syncSettingsKey = 'sync_settings';

  // Private aliases for backward compatibility within this class
  static const String _lastSyncKey = lastSyncKey;
  static const String _pendingChangesKey = pendingChangesKey;

  // Improved connectivity check
  static Future<bool> isOnline() async {
    try {
      debugPrint('🔍 Checking internet connectivity...');

      // Method 1: Try to reach Google's DNS (simple and fast)
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(Duration(seconds: 5));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          debugPrint('✅ Internet connection confirmed');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ DNS lookup failed, trying alternative method...');
      }

      // Method 2: Try a simple HTTP request
      try {
        final response = await HttpClient()
            .getUrl(Uri.parse('https://www.google.com'))
            .timeout(Duration(seconds: 5));
        await response.close();
        debugPrint('✅ HTTP connectivity confirmed');
        return true;
      } catch (e) {
        debugPrint('⚠️ HTTP connectivity check failed: $e');
      }

      debugPrint('❌ No internet connection detected');
      return false;
    } catch (e) {
      debugPrint('❌ Connectivity check error: $e');
      return false;
    }
  }

  // Full sync with server
  static Future<SyncResult> fullSync({bool forceFullDownload = false}) async {
    try {
      debugPrint('🔄 Starting full sync...');

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
          debugPrint('📅 Last sync: $lastSync');
        } else {
          lastSync = null;
          debugPrint('📅 Last sync: Never (first sync or invalid format)');
        }
      } else {
        // Force full download by not sending Last-Sync header
        lastSync = null;
        debugPrint('📅 Forcing full download - ignoring last sync');
      }

      try {
        // Download data from server
        debugPrint('⬇️ Downloading data from server...');
        final serverData = await ApiService.syncDownload(lastSync: lastSync);
        debugPrint('✅ Server data downloaded successfully');

        // Update local database
        debugPrint('💾 Updating local database...');
        await _updateLocalDatabase(serverData);
        debugPrint('✅ Local database updated');

        int uploadedCount = 0;

        // Upload pending changes ONLY if not forcing full download
        if (!forceFullDownload) {
          debugPrint('⬆️ Uploading pending changes...');
          final uploadResult = await _uploadPendingChanges();
          uploadedCount = uploadResult.details?['uploaded'] as int? ?? 0;
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
            debugPrint('❌ Upload failed during full sync');
            return SyncResult(false, 'Sync failed: ${uploadResult.message}',
                details: {
                  'downloaded': downloadedCount,
                  'uploaded': 0,
                  'upload_error': uploadResult.message,
                  'sync_timestamp': finalTimestamp,
                });
          }

          debugPrint('✅ Pending changes uploaded successfully');
        } else {
          debugPrint('ℹ️ Skipping upload during forced full download');
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
        debugPrint('✅ Sync timestamp updated: $finalTimestamp');

        final downloadedCount = _countSyncedRecords(serverData);

        debugPrint('🎉 Full sync completed successfully');
        debugPrint('📊 Downloaded: $downloadedCount records');

        return SyncResult(true, 'Sync completed successfully', details: {
          'downloaded': downloadedCount,
          'uploaded': uploadedCount,
          'sync_timestamp': finalTimestamp,
        });
      } catch (e) {
        debugPrint('❌ Sync operation failed: $e');
        return SyncResult(false, 'Sync failed: ${e.toString()}');
      }
    } catch (e) {
      debugPrint('❌ Full sync error: $e');
      return SyncResult(false, 'Sync error: ${e.toString()}');
    }
  }

  // Upload pending changes to server - FIXED VERSION

  static Future<SyncResult> uploadPendingChanges() async {
    try {
      debugPrint('⬆️ Starting upload of pending changes...');

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
        debugPrint('ℹ️ No pending changes to upload');
        return SyncResult(true, 'No pending changes to upload');
      }

      final pendingChanges = json.decode(pendingChangesJson);

      if (pendingChanges.isEmpty) {
        debugPrint('ℹ️ Pending changes empty');
        return SyncResult(true, 'No pending changes to upload');
      }

      // Count total items for logging
      int totalItems = 0;
      if (pendingChanges is Map) {
        for (final items in pendingChanges.values) {
          if (items is List) totalItems += items.length;
        }
      }

      debugPrint('📤 Uploading $totalItems items...');

      // Prefer production grouped endpoint for consistent behavior with
      // multi-device sync, then fall back to legacy if unavailable.
      Map<String, dynamic> result;
      try {
        result = await _uploadUsingProductionEndpoint(pendingChanges);
      } catch (e) {
        debugPrint(
            '⚠️ Production upload path failed, falling back to legacy: $e');
        result = await ApiService.syncUpload(pendingChanges);
      }

      debugPrint('🔍 Upload result: $result');

      final success = result['success'] == true;
      final uploaded = (result['uploaded'] as num?)?.toInt() ?? 0;
      final errors = result['errors'] ?? [];
      final isPartial = result['partial'] == true;
      final idMappings = result['id_mappings'] ?? {}; // ✅ GET ID MAPPINGS

      // Only clear the queue on strong complete success.
      final completeSuccess = success &&
          errors.isEmpty &&
          (totalItems == 0 || uploaded >= totalItems || uploaded > 0);

      if (completeSuccess) {
        // ✅ UPDATE LOCAL DATABASE WITH SERVER IDs
        if (idMappings.isNotEmpty) {
          await _updateLocalIdsWithServerIds(idMappings);
        }

        // Complete success - clear all pending changes
        await prefs.remove(_pendingChangesKey);
        debugPrint(
            '✅ Upload completed successfully - cleared all pending changes');

        return SyncResult(true, 'Upload completed', details: {
          'uploaded': uploaded,
          'expected': totalItems,
          'errors': [],
          'partial': false,
          'id_mappings': idMappings,
        });
      } else if (success && errors.isNotEmpty) {
        // ✅ UPDATE LOCAL DATABASE WITH SERVER IDs for successful items
        if (idMappings.isNotEmpty) {
          await _updateLocalIdsWithServerIds(idMappings);
        }

        // Partial success - remove only successful items
        final successfulItems =
            await _removeSuccessfulItemsFromPending(pendingChanges, errors);

        debugPrint(
            '⚠️ Upload partially successful - $successfulItems items processed, ${errors.length} failed');

        return SyncResult(true, 'Upload partially completed', details: {
          'uploaded': uploaded,
          'expected': totalItems,
          'errors': errors,
          'partial': true,
          'id_mappings': idMappings,
        });
      } else {
        // Complete failure - keep all pending changes
        debugPrint('❌ Upload failed completely - keeping pending changes');

        return SyncResult(
            false, 'Upload failed: ${result['message'] ?? 'Unknown error'}',
            details: {
              'uploaded': uploaded,
              'expected': totalItems,
              'errors': errors,
              'partial': isPartial,
            });
      }
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      return SyncResult(false, 'Upload failed: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> _uploadUsingProductionEndpoint(
      dynamic pendingChanges) async {
    if (pendingChanges is! Map) {
      throw Exception('Invalid pending changes format for production upload');
    }

    final groupedChanges = _buildGroupedChangesForProduction(
        Map<String, dynamic>.from(pendingChanges));

    if (groupedChanges.isEmpty) {
      return {
        'success': true,
        'uploaded': 0,
        'errors': <dynamic>[],
        'partial': false,
        'message': 'No valid changes to upload',
        'id_mappings': <String, dynamic>{},
      };
    }

    final response = await ApiService.uploadChanges(groupedChanges);
    final responseData = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return {
      'success': response['success'] == true,
      'uploaded': (responseData['uploaded'] as num?)?.toInt() ?? 0,
      'errors': responseData['errors'] ?? <dynamic>[],
      'partial': responseData['partial'] ?? false,
      'message': response['message'] ?? 'Upload completed',
      'id_mappings': responseData['id_mappings'] ?? <String, dynamic>{},
      'processed_items': responseData['processed_items'],
    };
  }

  static List<Map<String, dynamic>> _buildGroupedChangesForProduction(
      Map<String, dynamic> pendingChanges) {
    final groupedChanges = <Map<String, dynamic>>[];

    final orderedTables = [
      'users',
      'courses',
      'fleet',
      'invoices',
      'payments',
      'schedules'
    ];

    final currentSchoolId =
        Get.find<AuthController>().currentUser.value?.schoolId;

    for (final tableName in orderedTables) {
      final raw = pendingChanges[tableName];
      if (raw is! List || raw.isEmpty) {
        continue;
      }

      final items = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is! Map) continue;

        final operation =
            (item['operation'] ?? item['action'] ?? 'upsert').toString();
        final rawData = item['data'] is Map
            ? Map<String, dynamic>.from(item['data'] as Map)
            : Map<String, dynamic>.from(item);

        final normalizedData =
            _normalizeDataForProduction(tableName, rawData, currentSchoolId);

        items.add({
          'operation': operation,
          'id': normalizedData['id'],
          'data': normalizedData,
        });
      }

      if (items.isNotEmpty) {
        groupedChanges.add({
          'type': tableName,
          'items': items,
        });
      }
    }

    return groupedChanges;
  }

  static Map<String, dynamic> _normalizeDataForProduction(
    String table,
    Map<String, dynamic> data,
    String? schoolId,
  ) {
    final normalized = Map<String, dynamic>.from(data);

    if ((normalized['school_id'] == null ||
            normalized['school_id'].toString().isEmpty) &&
        schoolId != null &&
        schoolId.isNotEmpty) {
      normalized['school_id'] = schoolId;
    }

    if (table == 'users') {
      final role = (normalized['role'] ?? '').toString().toLowerCase().trim();
      final email = (normalized['email'] ?? '').toString().trim();

      // Server requires email on sync payloads. Keep local optional behavior,
      // but provide a stable placeholder for instructors when email is missing.
      if (role == 'instructor' && email.isEmpty) {
        normalized['email'] = _buildInstructorPlaceholderEmail(
          normalized: normalized,
          schoolId: schoolId,
        );
      }
    }

    if (table == 'payments') {
      if (!normalized.containsKey('invoiceId') &&
          normalized.containsKey('invoice_id')) {
        normalized['invoiceId'] = normalized['invoice_id'];
      }
      if (!normalized.containsKey('userId') &&
          normalized.containsKey('user_id')) {
        normalized['userId'] = normalized['user_id'];
      }
      if (!normalized.containsKey('method') &&
          normalized.containsKey('payment_method')) {
        normalized['method'] = normalized['payment_method'];
      }
      if (!normalized.containsKey('paymentDate') &&
          normalized.containsKey('payment_date')) {
        normalized['paymentDate'] = normalized['payment_date'];
      }
      if (!normalized.containsKey('paymentDate') &&
          normalized.containsKey('created_at')) {
        normalized['paymentDate'] = normalized['created_at'];
      }

      normalized.remove('invoice_id');
      normalized.remove('user_id');
      normalized.remove('payment_method');
      normalized.remove('payment_date');
    }

    return normalized;
  }

  static String _buildInstructorPlaceholderEmail({
    required Map<String, dynamic> normalized,
    String? schoolId,
  }) {
    final idPart = (normalized['id'] ?? '').toString().trim();
    final phoneRaw = (normalized['phone'] ?? '').toString();
    final phoneDigits = phoneRaw.replaceAll(RegExp(r'[^0-9]'), '');
    final schoolPart = (normalized['school_id'] ?? schoolId ?? '0')
        .toString()
        .trim()
        .replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');

    final stablePart = idPart.isNotEmpty
        ? 'u$idPart'
        : (phoneDigits.isNotEmpty
            ? 'p$phoneDigits'
            : 't${DateTime.now().millisecondsSinceEpoch}');

    return 'instructor.$schoolPart.$stablePart@local.invalid';
  }

// ✅ NEW METHOD: Update local database IDs with server IDs
  static Future<void> _updateLocalIdsWithServerIds(
      Map<String, dynamic> idMappings) async {
    try {
      debugPrint('🔄 Updating local IDs with server IDs...');

      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        for (final tableEntry in idMappings.entries) {
          final table = tableEntry.key;
          final mappings = tableEntry.value;

          if (mappings is! Map) {
            continue;
          }

          for (final mapping in mappings.entries) {
            final localId = int.tryParse(mapping.key.toString());
            final serverId = int.tryParse(mapping.value.toString());

            if (localId != null && serverId != null && localId != serverId) {
              debugPrint('🔄 Updating $table: $localId -> $serverId');

              // Update the record's ID
              await txn.rawUpdate(
                  'UPDATE $table SET id = ? WHERE id = ?', [serverId, localId]);

              // ✅ CRITICAL: Update foreign key references in other tables
              if (table == 'users') {
                // Update student references
                await txn.rawUpdate(
                    'UPDATE invoices SET student = ? WHERE student = ?',
                    [serverId, localId]);
                await txn.rawUpdate(
                    'UPDATE schedules SET student = ? WHERE student = ?',
                    [serverId, localId]);
                // Update instructor references
                await txn.rawUpdate(
                    'UPDATE schedules SET instructor = ? WHERE instructor = ?',
                    [serverId, localId]);
                await txn.rawUpdate(
                    'UPDATE fleet SET instructor = ? WHERE instructor = ?',
                    [serverId, localId]);
              }

              if (table == 'courses') {
                // Update course references
                await txn.rawUpdate(
                    'UPDATE invoices SET course = ? WHERE course = ?',
                    [serverId, localId]);
                await txn.rawUpdate(
                    'UPDATE schedules SET course = ? WHERE course = ?',
                    [serverId, localId]);
              }

              if (table == 'fleet') {
                // Update vehicle references
                await txn.rawUpdate(
                    'UPDATE schedules SET car = ? WHERE car = ?',
                    [serverId, localId]);
              }

              debugPrint(
                  '✅ Updated $table and all references: $localId -> $serverId');
            }
          }
        }
      });

      debugPrint('✅ Local ID updates completed');
    } catch (e) {
      debugPrint('❌ Failed to update local IDs: $e');
      // Don't throw - this is not critical for sync success
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
      final keepAllForType = <String>{};
      for (final error in errors) {
        if (error is! Map<String, dynamic>) continue;

        final itemType = _getItemType(error);
        if (itemType == null) continue;

        String? itemId;

        if (error.containsKey('item_id') && error['item_id'] != null) {
          itemId = error['item_id'].toString();
        } else if (error.containsKey('item') && error['item'] is Map) {
          final item = error['item'] as Map;
          if (item['id'] != null) {
            itemId = item['id'].toString();
          } else if (item['data'] is Map &&
              (item['data'] as Map)['id'] != null) {
            itemId = (item['data'] as Map)['id'].toString();
          }
        } else if (error.containsKey('data') && error['data'] is Map) {
          final data = error['data'] as Map;
          if (data['id'] != null) {
            itemId = data['id'].toString();
          }
        }

        if (itemId != null && itemId.isNotEmpty && itemId != 'unknown') {
          failedItems.putIfAbsent(itemType, () => <String>{}).add(itemId);
        } else {
          // Conservative path: if we can't map failing IDs, keep this table pending.
          keepAllForType.add(itemType);
        }
      }

      // Remove successful items from each data type
      final updatedChanges = <String, dynamic>{};

      for (final entry in pendingChanges.entries) {
        final dataType = entry.key;
        final items = entry.value as List<dynamic>;
        final failedItemsForType = failedItems[dataType] ?? <String>{};

        if (keepAllForType.contains(dataType)) {
          updatedChanges[dataType] = List<dynamic>.from(items);
          continue;
        }

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
        debugPrint(
            '📝 Updated pending changes: removed $successfulItems successful items');
      } else {
        await prefs.remove(_pendingChangesKey);
        debugPrint(
            '🧹 Cleared all pending changes - all items processed successfully');
      }

      return successfulItems;
    } catch (e) {
      debugPrint('❌ Error updating pending changes: $e');
      return 0;
    }
  }

  static String? _getItemType(Map<String, dynamic> error) {
    // This method should extract the item type from the error structure
    // You'll need to implement this based on how your server structures error responses

    // Method 1: Check if errors include the table name directly
    if (error.containsKey('table')) {
      return error['table']?.toString();
    }
    if (error.containsKey('type')) {
      return error['type']?.toString();
    }

    // Method 2: Infer from the item data structure
    final item = error['item'];
    if (item != null && item['data'] != null) {
      final data = item['data'] as Map<String, dynamic>;

      // Infer type from data structure
      if (data.containsKey('fname') || data.containsKey('lname')) {
        return 'users';
      }
      if (data.containsKey('course_name') ||
          data.containsKey('duration_hours')) {
        return 'courses';
      }
      if (data.containsKey('make') || data.containsKey('carplate')) {
        return 'fleet';
      }
      if (data.containsKey('start') || data.containsKey('end')) {
        return 'schedules';
      }
      if (data.containsKey('total_amount') || data.containsKey('due_date')) {
        return 'invoices';
      }
      if (data.containsKey('payment_method') ||
          data.containsKey('payment_date') ||
          data.containsKey('method') ||
          data.containsKey('paymentDate') ||
          data.containsKey('invoiceId')) {
        return 'payments';
      }
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
      debugPrint('📝 Tracked $operation change for $table');
    } catch (e) {
      debugPrint('❌ Failed to track change: $e');
    }
  }

  // Clear all pending changes (useful for debugging or after successful sync)
  static Future<void> clearPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingChangesKey);
      debugPrint('🧹 Cleared all pending changes');
    } catch (e) {
      debugPrint('❌ Failed to clear pending changes: $e');
    }
  }

  // Update local database with server data
  static Future<void> _updateLocalDatabase(
      Map<String, dynamic> serverData) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      // Update users with school_id support
      if (serverData['users'] != null) {
        debugPrint(
            '💾 Processing ${(serverData['users'] as List).length} users...');
        for (var userData in serverData['users']) {
          try {
            // Convert API format to local format with school_id
            final localUserData = _convertUserApiToLocalFixed(userData);
            debugPrint(
                '📝 Converting user: ${userData['email']} (school_id: ${userData['school_id']})');

            await _upsertUserByIdentity(txn, localUserData);
            debugPrint('✅ Synced user: ${userData['email']}');
          } catch (e) {
            debugPrint('❌ Failed to sync user ${userData['email']}: $e');
          }
        }
      }

      // Update courses
      if (serverData['courses'] != null) {
        debugPrint(
            '💾 Processing ${(serverData['courses'] as List).length} courses...');
        for (var courseData in serverData['courses']) {
          try {
            final localCourseData = _convertCourseApiToLocal(courseData);
            await _upsertCourseByIdentity(txn, localCourseData);
          } catch (e) {
            debugPrint('❌ Failed to sync course: $e');
          }
        }
      }

      // Update schedules
      if (serverData['schedules'] != null) {
        debugPrint(
            '💾 Processing ${(serverData['schedules'] as List).length} schedules...');
        for (var scheduleData in serverData['schedules']) {
          try {
            final localScheduleData = _convertScheduleApiToLocal(scheduleData);
            await _upsertScheduleByIdentity(txn, localScheduleData);
          } catch (e) {
            debugPrint('❌ Failed to sync schedule: $e');
          }
        }
      }

      // Update invoices
      if (serverData['invoices'] != null) {
        debugPrint(
            '💾 Processing ${(serverData['invoices'] as List).length} invoices...');
        for (var invoiceData in serverData['invoices']) {
          try {
            final localInvoiceData = _convertInvoiceApiToLocal(invoiceData);
            await _upsertInvoiceByIdentity(txn, localInvoiceData);
          } catch (e) {
            debugPrint('❌ Failed to sync invoice: $e');
          }
        }
      }

      // Update payments
      if (serverData['payments'] != null) {
        debugPrint(
            '💾 Processing ${(serverData['payments'] as List).length} payments...');
        for (var paymentData in serverData['payments']) {
          try {
            final localPaymentData = _convertPaymentApiToLocal(paymentData);
            await _upsertPaymentByIdentity(txn, localPaymentData);
          } catch (e) {
            debugPrint('❌ Failed to sync payment: $e');
          }
        }
      }

      // Update fleet
      if (serverData['fleet'] != null) {
        debugPrint(
            '💾 Processing ${(serverData['fleet'] as List).length} fleet items...');
        for (var fleetData in serverData['fleet']) {
          try {
            final localFleetData = _convertFleetApiToLocal(fleetData);
            await _upsertFleetByIdentity(txn, localFleetData);
          } catch (e) {
            debugPrint('❌ Failed to sync fleet item: $e');
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
        // Get the current school ID from AuthController
        final authController = Get.find<AuthController>();
        final currentUser = authController.currentUser.value;

        if (currentUser != null && currentUser.schoolId != null) {
          serverStatus = await ApiService.getSyncStatus(
            schoolId: currentUser.schoolId!,
          );
        } else {
          debugPrint('⚠️ Cannot get server status: No school ID available');
        }
      } catch (e) {
        debugPrint('❌ Failed to get server status: $e');
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
        'interval': prefs.getInt('sync_interval') ?? 5,
        'lastSync': prefs.getString(_lastSyncKey) ?? 'Never',
      };
    } catch (e) {
      return {
        'autoSync': true,
        'interval': 5,
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
      debugPrint('❌ Failed to save sync settings: $e');
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
      'id': _toIntOrNull(courseData['id'] ?? courseData['course_id']),
      'name': courseData['name'],
      'price': courseData['price'] ?? 0.0,
      'status': courseData['status'] ?? 'active',
      'school_id': courseData['school_id'] ?? courseData['schoolId'],
    };
  }

  static Future<void> _upsertCourseByIdentity(
      DatabaseExecutor db, Map<String, dynamic> localCourseData) async {
    final hasSchoolId = await _tableHasColumn(db, 'courses', 'school_id');
    final writeData = Map<String, dynamic>.from(localCourseData);
    if (!hasSchoolId) {
      writeData.remove('school_id');
    }

    final courseName = (localCourseData['name'] ?? '').toString().trim();
    if (courseName.isEmpty) {
      await db.insert(
        'courses',
        writeData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final incomingSchoolId = localCourseData['school_id']?.toString();

    String where = 'LOWER(TRIM(name)) = LOWER(TRIM(?))';
    final whereArgs = <Object?>[courseName];

    if (hasSchoolId) {
      where +=
          " AND COALESCE(CAST(school_id AS TEXT), '') = COALESCE(CAST(? AS TEXT), '')";
      whereArgs.add(incomingSchoolId);
    }

    final existing = await db.query(
      'courses',
      columns: ['id'],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingId = _toIntOrNull(existing.first['id']);
      if (existingId != null) {
        final updateData = Map<String, dynamic>.from(writeData)
          ..['id'] = existingId;
        await db.update(
          'courses',
          updateData,
          where: 'id = ?',
          whereArgs: [existingId],
        );
        return;
      }
    }

    await db.insert(
      'courses',
      writeData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _upsertUserByIdentity(
      DatabaseExecutor db, Map<String, dynamic> localUserData) async {
    final hasSchoolId = await _tableHasColumn(db, 'users', 'school_id');
    final writeData = Map<String, dynamic>.from(localUserData);
    if (!hasSchoolId) {
      writeData.remove('school_id');
    }

    final email =
        (localUserData['email'] ?? '').toString().trim().toLowerCase();
    if (email.isEmpty) {
      await db.insert('users', writeData,
          conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }

    final incomingSchoolId = localUserData['school_id']?.toString();
    String where = 'LOWER(TRIM(email)) = LOWER(TRIM(?))';
    final whereArgs = <Object?>[email];

    if (hasSchoolId) {
      where +=
          " AND COALESCE(CAST(school_id AS TEXT), '') = COALESCE(CAST(? AS TEXT), '')";
      whereArgs.add(incomingSchoolId);
    }

    final existing = await db.query('users',
        columns: ['id'], where: where, whereArgs: whereArgs, limit: 1);

    if (existing.isNotEmpty) {
      final existingId = _toIntOrNull(existing.first['id']);
      if (existingId != null) {
        final updateData = Map<String, dynamic>.from(writeData)
          ..['id'] = existingId;
        await db.update('users', updateData,
            where: 'id = ?', whereArgs: [existingId]);
        return;
      }
    }

    await db.insert('users', writeData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _upsertFleetByIdentity(
      DatabaseExecutor db, Map<String, dynamic> localFleetData) async {
    final hasSchoolId = await _tableHasColumn(db, 'fleet', 'school_id');
    final writeData = Map<String, dynamic>.from(localFleetData);
    if (!hasSchoolId) {
      writeData.remove('school_id');
    }

    final carplate =
        (localFleetData['carplate'] ?? '').toString().trim().toUpperCase();
    if (carplate.isEmpty) {
      await db.insert('fleet', writeData,
          conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }

    final incomingSchoolId = localFleetData['school_id']?.toString();
    String where = 'UPPER(TRIM(carplate)) = UPPER(TRIM(?))';
    final whereArgs = <Object?>[carplate];

    if (hasSchoolId) {
      where +=
          " AND COALESCE(CAST(school_id AS TEXT), '') = COALESCE(CAST(? AS TEXT), '')";
      whereArgs.add(incomingSchoolId);
    }

    final existing = await db.query('fleet',
        columns: ['id'], where: where, whereArgs: whereArgs, limit: 1);

    if (existing.isNotEmpty) {
      final existingId = _toIntOrNull(existing.first['id']);
      if (existingId != null) {
        final updateData = Map<String, dynamic>.from(writeData)
          ..['id'] = existingId;
        await db.update('fleet', updateData,
            where: 'id = ?', whereArgs: [existingId]);
        return;
      }
    }

    await db.insert('fleet', writeData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _upsertInvoiceByIdentity(
      DatabaseExecutor db, Map<String, dynamic> localInvoiceData) async {
    final hasSchoolId = await _tableHasColumn(db, 'invoices', 'school_id');
    final writeData = Map<String, dynamic>.from(localInvoiceData);
    if (!hasSchoolId) {
      writeData.remove('school_id');
    }

    final invoiceNumber =
        (localInvoiceData['invoice_number'] ?? '').toString().trim();
    if (invoiceNumber.isEmpty) {
      await db.insert('invoices', writeData,
          conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }

    final incomingSchoolId = localInvoiceData['school_id']?.toString();
    String where = 'TRIM(invoice_number) = TRIM(?)';
    final whereArgs = <Object?>[invoiceNumber];

    if (hasSchoolId) {
      where +=
          " AND COALESCE(CAST(school_id AS TEXT), '') = COALESCE(CAST(? AS TEXT), '')";
      whereArgs.add(incomingSchoolId);
    }

    final existing = await db.query('invoices',
        columns: ['id'], where: where, whereArgs: whereArgs, limit: 1);

    if (existing.isNotEmpty) {
      final existingId = _toIntOrNull(existing.first['id']);
      if (existingId != null) {
        final updateData = Map<String, dynamic>.from(writeData)
          ..['id'] = existingId;
        await db.update('invoices', updateData,
            where: 'id = ?', whereArgs: [existingId]);
        return;
      }
    }

    await db.insert('invoices', writeData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _upsertPaymentByIdentity(
      DatabaseExecutor db, Map<String, dynamic> localPaymentData) async {
    final writeData = Map<String, dynamic>.from(localPaymentData);

    final invoiceId = _toIntOrNull(localPaymentData['invoiceId']);
    final amount = _toDoubleOrNull(localPaymentData['amount']) ?? 0.0;
    final paymentDate = (localPaymentData['paymentDate'] ?? '').toString();
    final reference = (localPaymentData['reference'] ?? '').toString();

    writeData['amount'] = amount;
    if (invoiceId != null) {
      writeData['invoiceId'] = invoiceId;
    }

    if (invoiceId == null) {
      await db.insert('payments', writeData,
          conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }

    final existing = await db.query(
      'payments',
      columns: ['id'],
      where:
          'invoiceId = ? AND COALESCE(reference, "") = COALESCE(?, "") AND paymentDate = ? AND ABS(COALESCE(amount, 0) - ?) < 0.0001',
      whereArgs: [invoiceId, reference, paymentDate, amount],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingId = _toIntOrNull(existing.first['id']);
      if (existingId != null) {
        final updateData = Map<String, dynamic>.from(writeData)
          ..['id'] = existingId;
        await db.update('payments', updateData,
            where: 'id = ?', whereArgs: [existingId]);
        return;
      }
    }

    await db.insert('payments', writeData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _upsertScheduleByIdentity(
      DatabaseExecutor db, Map<String, dynamic> localScheduleData) async {
    final hasSchoolId = await _tableHasColumn(db, 'schedules', 'school_id');
    final writeData = Map<String, dynamic>.from(localScheduleData);
    if (!hasSchoolId) {
      writeData.remove('school_id');
    }

    final student = _toIntOrNull(localScheduleData['student']);
    final instructor = _toIntOrNull(localScheduleData['instructor']);
    final course = _toIntOrNull(localScheduleData['course']);
    final start = (localScheduleData['start'] ?? '').toString();
    final end = (localScheduleData['end'] ?? '').toString();

    if (student == null ||
        instructor == null ||
        course == null ||
        start.isEmpty ||
        end.isEmpty) {
      await db.insert('schedules', writeData,
          conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }

    String where =
        'student = ? AND instructor = ? AND course = ? AND start = ? AND end = ?';
    final whereArgs = <Object?>[student, instructor, course, start, end];

    if (hasSchoolId) {
      where +=
          " AND COALESCE(CAST(school_id AS TEXT), '') = COALESCE(CAST(? AS TEXT), '')";
      whereArgs.add(localScheduleData['school_id']?.toString());
    }

    final existing = await db.query('schedules',
        columns: ['id'], where: where, whereArgs: whereArgs, limit: 1);

    if (existing.isNotEmpty) {
      final existingId = _toIntOrNull(existing.first['id']);
      if (existingId != null) {
        final updateData = Map<String, dynamic>.from(writeData)
          ..['id'] = existingId;
        await db.update('schedules', updateData,
            where: 'id = ?', whereArgs: [existingId]);
        return;
      }
    }

    await db.insert('schedules', writeData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<bool> _tableHasColumn(
      DatabaseExecutor db, String table, String column) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.any((c) => c['name']?.toString() == column);
  }

  static int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static Map<String, dynamic> _convertScheduleApiToLocal(
      Map<String, dynamic> scheduleData) {
    return {
      'id': scheduleData['id'],
      'student': scheduleData['student'],
      'instructor': scheduleData['instructor'],
      'course': scheduleData['course'],
      'car': scheduleData['car'] ?? scheduleData['vehicle'],
      'start': scheduleData['start'],
      'end': scheduleData['end'],
      'is_recurring': _convertBoolToInt(scheduleData['is_recurring']),
      'recurrence_pattern': scheduleData['recurring_pattern'] ?? '',
      'recurrence_end_date': scheduleData['recurring_end_date'] ?? '',
      'attended': _convertBoolToInt(scheduleData['attended']),
      'lessonsCompleted': scheduleData['lessons_completed'] ?? 0,
      'lessonsDeducted': scheduleData['lessons_deducted'] ?? 0,
      'status': scheduleData['status'] ?? 'scheduled',
      'class_type': scheduleData['class_type'] ?? 'Practical',
    };
  }

  // Helper method to convert boolean values to integers for SQLite
  static int _convertBoolToInt(dynamic value) {
    if (value == null) return 0;
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value;
    if (value is String) {
      return (value.toLowerCase() == 'true' || value == '1') ? 1 : 0;
    }
    return 0;
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
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'invoiceId': apiData['invoiceId'] ?? apiData['invoice_id'],
      'amount': _toDoubleOrNull(apiData['amount']) ?? 0.0,
      'method': apiData['method'] ?? 'cash',
      'paymentDate': apiData['paymentDate'] ??
          apiData['payment_date'] ??
          apiData['created_at'] ??
          DateTime.now().toIso8601String(),
      'status': apiData['status'] ?? 'completed',
      'notes': apiData['notes'] ?? '',
      'reference': apiData['reference'],
      'receipt_path': apiData['receipt_path'],
      // ✅ FIX: Convert boolean to integer (0 or 1)
      'receipt_generated': (apiData['receipt_generated'] == true ||
              apiData['receipt_generated'] == 1)
          ? 1
          : 0,
      'receipt_generated_at': apiData['receipt_generated_at'],
      'cloud_storage_path': apiData['cloud_storage_path'],
      'receipt_file_size': apiData['receipt_file_size'],
      'receipt_type': apiData['receipt_type'],
      'userId': _toIntOrNull(apiData['userId'] ?? apiData['user_id']),
    };
  }

  static Map<String, dynamic> _convertFleetApiToLocal(
      Map<String, dynamic> fleetData) {
    return {
      'id': fleetData['id'],
      'make': fleetData['make'],
      'model': fleetData['model'],
      'modelyear': fleetData['modelyear'],
      'carplate': fleetData['carplate'] ?? fleetData['carPlate'],
      'status': fleetData['status'] ?? 'available',
      'instructor': fleetData['instructor'],
      'school_id': fleetData['school_id'],
    };
  }

  static Future<void> clearAllSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear all sync-related data
      await prefs.remove('sync_pending_changes');
      await prefs.remove('last_sync_timestamp');
      await prefs.remove('sync_debug_logs');
      await prefs.remove('sync_last_error');

      debugPrint('🧹 All sync data cleared successfully');
      debugPrint('✅ Pending changes cleared');
      debugPrint('✅ Sync timestamps cleared');
      debugPrint('✅ Debug logs cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear sync data: $e');
    }
  }

  static Future<void> clearAllPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove the pending changes
      await prefs.remove('sync_pending_changes');

      // Also clear related sync data
      await prefs.remove('last_sync_timestamp');
      await prefs.remove('sync_debug_log');
      await prefs.remove('sync_last_error');

      debugPrint('✅ Cleared all pending sync changes from SharedPreferences');
      debugPrint('✅ Your next sync will start fresh!');

      return;
    } catch (e) {
      debugPrint('❌ Error clearing pending changes: $e');
      rethrow;
    }
  }

  // Upsert methods for individual records
  static Future<void> upsertUser(Map<String, dynamic> userData) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localUserData = _convertUserApiToLocalFixed(userData);
      await db.insert(
        'users',
        localUserData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Failed to upsert user: $e');
      rethrow;
    }
  }

  static Future<void> upsertCourse(Map<String, dynamic> courseData) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localCourseData = _convertCourseApiToLocal(courseData);
      await _upsertCourseByIdentity(db, localCourseData);
    } catch (e) {
      debugPrint('❌ Failed to upsert course: $e');
      rethrow;
    }
  }

  static Future<void> upsertFleet(Map<String, dynamic> fleetData) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localFleetData = _convertFleetApiToLocal(fleetData);
      await db.insert(
        'fleet',
        localFleetData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Failed to upsert fleet: $e');
      rethrow;
    }
  }

  static Future<void> upsertSchedule(Map<String, dynamic> scheduleData) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localScheduleData = _convertScheduleApiToLocal(scheduleData);
      await db.insert(
        'schedules',
        localScheduleData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Failed to upsert schedule: $e');
      rethrow;
    }
  }

  static Future<void> upsertInvoice(Map<String, dynamic> invoiceData) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localInvoiceData = _convertInvoiceApiToLocal(invoiceData);
      await db.insert(
        'invoices',
        localInvoiceData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Failed to upsert invoice: $e');
      rethrow;
    }
  }

  static Future<void> upsertPayment(Map<String, dynamic> paymentData) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localPaymentData = _convertPaymentApiToLocal(paymentData);
      await db.insert(
        'payments',
        localPaymentData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Failed to upsert payment: $e');
      rethrow;
    }
  }

  /// Get pending changes info (for debugging)
  static Future<Map<String, dynamic>> getPendingChangesInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingChangesJson = prefs.getString('sync_pending_changes');

      if (pendingChangesJson == null || pendingChangesJson.isEmpty) {
        return {
          'has_pending': false,
          'count': 0,
          'message': 'No pending changes found'
        };
      }

      final pendingChanges = json.decode(pendingChangesJson);

      int totalCount = 0;
      Map<String, int> breakdown = {};

      if (pendingChanges is Map) {
        for (final entry in pendingChanges.entries) {
          final table = entry.key;
          final items = entry.value as List;
          breakdown[table] = items.length;
          totalCount += items.length;
        }
      }

      return {
        'has_pending': true,
        'count': totalCount,
        'breakdown': breakdown,
        'message': 'Found $totalCount pending changes'
      };
    } catch (e) {
      return {
        'has_pending': false,
        'count': 0,
        'error': e.toString(),
        'message': 'Error reading pending changes'
      };
    }
  }
}
