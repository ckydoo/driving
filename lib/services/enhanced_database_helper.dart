// lib/services/enhanced_database_helper.dart
// Extension to your existing DatabaseHelper class
// Add these methods to your existing database_helper.dart file

import 'dart:async';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:sqflite/sqflite.dart';
import 'firebase_sync_service.dart';

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

  /// Enhanced insert method with automatic sync triggering
  static Future<int> insertWithSync(
      Database db, String table, Map<String, dynamic> values) async {
    // Add sync tracking data
    values['last_modified'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    values['firebase_synced'] = 0;

    final result = await db.insert(table, values);

    // Trigger sync if online
    if (MultiTenantFirebaseSyncService.instance.isOnline.value &&
        !MultiTenantFirebaseSyncService.instance.isSyncing.value) {
      Timer(const Duration(seconds: 2), () {
        MultiTenantFirebaseSyncService.instance.triggerManualSync();
      });
    }

    return result;
  }

  /// Enhanced update method with automatic sync triggering
  static Future<int> updateWithSync(
      Database db,
      String table,
      Map<String, dynamic> values,
      String where,
      List<dynamic> whereArgs) async {
    // Add sync tracking data
    values['last_modified'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    values['firebase_synced'] = 0;

    final result =
        await db.update(table, values, where: where, whereArgs: whereArgs);

    // Trigger sync if online
    if (MultiTenantFirebaseSyncService.instance.isOnline.value &&
        !MultiTenantFirebaseSyncService.instance.isSyncing.value) {
      Timer(const Duration(seconds: 2), () {
        MultiTenantFirebaseSyncService.instance.triggerManualSync();
      });
    }

    return result;
  }

  /// Enhanced delete method with sync support
  static Future<int> deleteWithSync(
      Database db, String table, String where, List<dynamic> whereArgs) async {
    // For deletes, we might want to mark as deleted rather than actually delete
    // This allows sync to propagate deletions to Firebase

    try {
      // Try to mark as deleted first
      final result = await db.update(
          table,
          {
            'deleted': 1,
            'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
            'firebase_synced': 0,
          },
          where: where,
          whereArgs: whereArgs);

      // Trigger sync if online
      if (MultiTenantFirebaseSyncService.instance.isOnline.value &&
          !MultiTenantFirebaseSyncService.instance.isSyncing.value) {
        Timer(const Duration(seconds: 2), () {
          MultiTenantFirebaseSyncService.instance.triggerManualSync();
        });
      }

      return result;
    } catch (e) {
      // If table doesn't have deleted column, do actual delete
      return await db.delete(table, where: where, whereArgs: whereArgs);
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
}
