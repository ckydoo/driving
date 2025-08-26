// lib/services/enhanced_database_helper.dart
// Extension to your existing DatabaseHelper class
// Add these methods to your existing database_helper.dart file

import 'dart:async';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelperSyncExtension {
  /// Add sync tracking triggers to existing tables
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
      //'settings',
    ];

    for (String table in tables) {
      try {
        // Add sync columns if they don't exist
        await db.execute('''
          ALTER TABLE $table ADD COLUMN last_modified INTEGER DEFAULT ${DateTime.now().toUtc().millisecondsSinceEpoch}
        ''');
      } catch (e) {
        // Column might already exist
        print('last_modified column may already exist in $table');
      }

      try {
        await db.execute('''
          ALTER TABLE $table ADD COLUMN firebase_synced INTEGER DEFAULT 0
        ''');
      } catch (e) {
        // Column might already exist
        print('firebase_synced column may already exist in $table');
      }

      // Create trigger to update last_modified on changes
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS update_${table}_timestamp
        AFTER UPDATE ON $table
        BEGIN
          UPDATE $table SET 
            last_modified = ${DateTime.now().toUtc().millisecondsSinceEpoch},
            firebase_synced = 0
          WHERE id = NEW.id;
        END;
      ''');

      // Create trigger for inserts
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS insert_${table}_timestamp
        AFTER INSERT ON $table
        BEGIN
          UPDATE $table SET 
            last_modified = ${DateTime.now().toUtc().millisecondsSinceEpoch},
            firebase_synced = 0
          WHERE id = NEW.id;
        END;
      ''');
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

  // REPLACE THE insertWithSync METHOD WITH THIS:
  static Future<int> insertWithSync(
      Database db, String table, Map<String, dynamic> values) async {
    // Add sync tracking data
    values['last_modified'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    values['firebase_synced'] = 0;

    // ✅ ADD DEVICE TRACKING:
    values['last_modified_device'] = await DatabaseHelper.getDeviceId();

    // Add firebase_user_id if not present and user is authenticated
    if (values['firebase_user_id'] == null) {
      try {
        final authController = Get.find<AuthController>();
        if (authController.isFirebaseAuthenticated) {
          values['firebase_user_id'] = authController.currentFirebaseUserId;
        }
      } catch (e) {
        print('⚠️ Could not get Firebase user ID: $e');
      }
    }

    final result = await db.insert(table, values);

    // ✅ TRIGGER SMART SYNC (replaces immediate sync)
    _triggerSmartSync();

    return result;
  }

// REPLACE THE updateWithSync METHOD WITH THIS:
  static Future<int> updateWithSync(
      Database db,
      String table,
      Map<String, dynamic> values,
      String where,
      List<dynamic> whereArgs) async {
    // Add sync tracking data
    values['last_modified'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    values['firebase_synced'] = 0;

    // ✅ ADD DEVICE TRACKING:
    values['last_modified_device'] = await DatabaseHelper.getDeviceId();

    final result =
        await db.update(table, values, where: where, whereArgs: whereArgs);

    // ✅ TRIGGER SMART SYNC (replaces immediate sync)
    _triggerSmartSync();

    return result;
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
        // Try to use the new fixed sync service first
        if (Get.isRegistered<FixedLocalFirstSyncService>()) {
          final syncService = Get.find<FixedLocalFirstSyncService>();
          if (!syncService.isSyncing.value &&
              syncService.isOnline.value &&
              syncService.firebaseAvailable.value) {
            syncService.syncWithFirebase().catchError((e) {
              print('⚠️ Smart sync failed: $e');
            });
          }
        } else if (Get.isRegistered<MultiTenantFirebaseSyncService>()) {
          // Fallback to old sync service if new one not available
          final syncService = Get.find<MultiTenantFirebaseSyncService>();
          if (!syncService.isSyncing.value &&
              syncService.isOnline.value &&
              syncService.firebaseAvailable.value) {
            syncService.triggerManualSync().catchError((e) {
              print('⚠️ Legacy sync failed: $e');
            });
          }
        }
      } catch (e) {
        print('⚠️ Could not trigger smart sync: $e');
      }
    });
  }
}
