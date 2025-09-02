// lib/services/enhanced_database_helper.dart
// Extension to your existing DatabaseHelper class
// Add these methods to your existing database_helper.dart file

import 'dart:async';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/utils/timestamp_converter.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/services/schedule_data_validator.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelperSyncExtension {
  static Future<void> addSyncTrackingTriggers(Database db) async {
    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'billings',
      'attachments',
      'notes',
      'fleet',
      'notifications',
      'timeline',
      'usermessages',
      'currencies',
      'billing_records',
    ];

    for (String table in tables) {
      // Drop existing triggers first
      await db.execute('DROP TRIGGER IF EXISTS update_${table}_timestamp');
      await db.execute('DROP TRIGGER IF EXISTS insert_${table}_timestamp');

      // Create table-specific smart triggers
      await _createTableSpecificTrigger(db, table);
    }
  }

  /// Create table-specific triggers based on actual columns
  static Future<void> _createTableSpecificTrigger(
      Database db, String table) async {
    try {
      // Get actual columns for this table
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final columnNames = columns.map((col) => col['name'] as String).toSet();

      // Build conditional checks only for columns that exist
      List<String> conditions = [];

      // Check common columns that might exist

      if (columnNames.contains('fname')) {
        conditions.add("COALESCE(OLD.fname, '') != COALESCE(NEW.fname, '')");
      }
      if (columnNames.contains('lname')) {
        conditions.add("COALESCE(OLD.lname, '') != COALESCE(NEW.lname, '')");
      }
      if (columnNames.contains('email')) {
        conditions.add("COALESCE(OLD.email, '') != COALESCE(NEW.email, '')");
      }
      if (columnNames.contains('phone')) {
        conditions.add("COALESCE(OLD.phone, '') != COALESCE(NEW.phone, '')");
      }
      if (columnNames.contains('status')) {
        conditions.add("COALESCE(OLD.status, '') != COALESCE(NEW.status, '')");
      }
      if (columnNames.contains('amount')) {
        conditions.add("COALESCE(OLD.amount, 0) != COALESCE(NEW.amount, 0)");
      }
      if (columnNames.contains('start')) {
        conditions.add("COALESCE(OLD.start, '') != COALESCE(NEW.start, '')");
      }
      if (columnNames.contains('end')) {
        conditions.add("COALESCE(OLD.end, '') != COALESCE(NEW.end, '')");
      }
      if (columnNames.contains('deleted')) {
        conditions.add("OLD.deleted != NEW.deleted");
      }

      // If no specific conditions, just check if firebase_synced was already 1
      String dataChangeCondition = conditions.isNotEmpty
          ? conditions.join(' OR ')
          : "1=1"; // Always true if no specific columns to check

      // Create the UPDATE trigger
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS update_${table}_timestamp
        AFTER UPDATE ON $table
        WHEN (
          -- Only reset firebase_synced if actual data changed and it was previously synced
          OLD.firebase_synced = 1 AND ($dataChangeCondition)
        )
        BEGIN
          UPDATE $table SET 
            last_modified = (strftime('%s', 'now') * 1000),
            firebase_synced = 0
          WHERE id = NEW.id;
        END;
      ''');

      // Create the INSERT trigger (simpler - always mark as unsynced)
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

      print(
          '✅ Created smart triggers for $table (${conditions.length} conditions)');
    } catch (e) {
      print('❌ Error creating triggers for $table: $e');

      // Fallback: create simple trigger without column checks
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

      print('⚠️ Created fallback triggers for $table');
    }
  }

  /// Emergency method to drop all problematic triggers
  static Future<void> dropAllTriggers(Database db) async {
    print('🗑️ Dropping all triggers...');

    try {
      final triggers = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'trigger'
      ''');

      for (final trigger in triggers) {
        final triggerName = trigger['name'] as String;
        await db.execute('DROP TRIGGER IF EXISTS $triggerName');
        print('✅ Dropped trigger: $triggerName');
      }

      print('✅ All triggers dropped successfully');
    } catch (e) {
      print('❌ Error dropping triggers: $e');
    }
  }

  /// Add deleted column to tables for soft deletes
  static Future<void> addDeletedColumn(Database db) async {
    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'billings',
      'attachments',
      'notes',
      'fleet',
      'notifications',
      'timeline',
      'usermessages',
      'currencies',
      'billing_records',
      //'settings',
    ];

    for (String table in tables) {
      try {
        await db.execute('''
          ALTER TABLE $table ADD COLUMN deleted INTEGER DEFAULT 0
        ''');
        print('Added deleted column to $table');
      } catch (e) {
        print('deleted column may already exist in $table');
      }
      try {
        await db.execute('''
          ALTER TABLE $table ADD COLUMN local_id INTEGER DEFAULT 0
        ''');
        print('Added local_id column to $table');
      } catch (e) {
        print('local_id column may already exist in $table');
      }
    }
  }

  /// Get records excluding soft-deleted ones
  static Future<List<Map<String, dynamic>>> queryWithoutDeleted(
    Database db,
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    // Add deleted = 0 condition to where clause
    String finalWhere = 'deleted = 0';
    List<Object?> finalWhereArgs = [];

    if (where != null && where.isNotEmpty) {
      finalWhere = '($where) AND deleted = 0';
      finalWhereArgs = whereArgs ?? [];
    }

    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: finalWhere,
      whereArgs: finalWhereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  static Future<int> insertWithSync(
    Database db,
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      // Special validation for schedules table
      Map<String, dynamic> validatedData;
      if (table == 'schedules') {
        validatedData = ScheduleDataValidator.validateScheduleData(data);
      } else {
        validatedData = Map<String, dynamic>.from(data);
      }

      // Convert timestamps before inserting
      final convertedData = TimestampConverter.prepareForSQLite(validatedData);

      // Set sync tracking fields
      convertedData['firebase_synced'] = 0;
      convertedData['last_modified'] = DateTime.now().millisecondsSinceEpoch;
      convertedData['last_modified_device'] =
          await DatabaseHelper.getDeviceId();

      // Add firebase_user_id if authenticated
      if (convertedData['firebase_user_id'] == null) {
        try {
          final authController = Get.find<AuthController>();
          if (authController.isFirebaseAuthenticated) {
            convertedData['firebase_user_id'] =
                authController.currentFirebaseUserId;
          }
        } catch (e) {
          print('⚠️ Could not get Firebase user ID: $e');
        }
      }

      final result = await db.insert(table, convertedData);
      print('✅ Successfully inserted into $table with ID: $result');

      return result;
    } catch (e) {
      print('❌ Error in insertWithSync for $table: $e');
      print('🔍 Data: $data');
      rethrow;
    }
  }

  // ✅ FIX 3: Enhanced updateWithSync method with validation
  static Future<int> updateWithSync(
    Database db,
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    try {
      // Special validation for schedules table
      Map<String, dynamic> validatedData;
      if (table == 'schedules') {
        // For updates, only validate if start/end are being changed
        if (data.containsKey('start') || data.containsKey('end')) {
          validatedData = ScheduleDataValidator.validateScheduleData(data);
        } else {
          validatedData = Map<String, dynamic>.from(data);
        }
      } else {
        validatedData = Map<String, dynamic>.from(data);
      }

      // Convert timestamps before updating
      final convertedData = TimestampConverter.prepareForSQLite(validatedData);

      // Set sync tracking fields
      convertedData['firebase_synced'] = 0;
      convertedData['last_modified'] = DateTime.now().millisecondsSinceEpoch;
      convertedData['last_modified_device'] =
          await DatabaseHelper.getDeviceId();

      final result = await db.update(table, convertedData,
          where: where, whereArgs: whereArgs);

      if (result > 0) {
        print('✅ Successfully updated $result row(s) in $table');
      }

      return result;
    } catch (e) {
      print('❌ Error in updateWithSync for $table: $e');
      print('🔍 Data: $data');
      rethrow;
    }
  }

// REPLACE THE deleteWithSync METHOD WITH THIS:
  static Future<int> deleteWithSync(
      Database db, String table, String where, List<dynamic> whereArgs) async {
    try {
      // Soft delete with device tracking
      final result = await db.update(
          table,
          {
            'deleted': 1,
            'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
            'firebase_synced': 0,
            'last_modified_device': await DatabaseHelper.getDeviceId(),
          },
          where: where,
          whereArgs: whereArgs);

      // ✅ TRIGGER SMART SYNC
      _triggerSmartSync();

      return result;
    } catch (e) {
      // Fallback to hard delete if soft delete fails
      final result = await db.delete(table, where: where, whereArgs: whereArgs);
      _triggerSmartSync();
      return result;
    }
  }

// ✅ ADD SMART SYNC TRIGGER (REPLACES OLD IMMEDIATE SYNC):
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
}
