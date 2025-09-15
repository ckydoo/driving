// lib/services/database_sync_migration.dart - SIMPLIFIED VERSION
import 'package:sqflite/sqflite.dart';

class DatabaseSyncMigration {
  static const int _targetVersion = 2;

  /// Run sync migrations - only add missing timestamp fields
  static Future<void> runSyncMigrations(Database db) async {
    print('🔄 Running sync migrations (timestamp fields only)...');

    final currentVersion = await db.getVersion();
    print('📊 Current database version: $currentVersion');
    print('📊 Target database version: $_targetVersion');

    if (currentVersion < 2) {
      await _addTimestampFields(db);
    }

    // Set the new version
    await db.setVersion(_targetVersion);
    print('✅ Sync migrations completed. Database version: $_targetVersion');
  }

  /// Add created_at and updated_at fields to all tables for sync
  static Future<void> _addTimestampFields(Database db) async {
    print('⏰ Adding timestamp fields for sync...');

    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet'
    ];

    for (String table in tables) {
      try {
        await _addTimestampsToTable(db, table);
      } catch (e) {
        print('⚠️ Failed to add timestamps to $table: $e');
        // Continue with other tables
      }
    }

    print('✅ Timestamp fields migration completed');
  }

  /// Add timestamp fields to a specific table
  static Future<void> _addTimestampsToTable(
      Database db, String tableName) async {
    try {
      // Get current table structure
      final columns = await _getTableColumns(db, tableName);

      // Add created_at if missing
      if (!columns.contains('created_at')) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN created_at TEXT');
        print('✅ Added created_at to $tableName table');
      }

      // Add updated_at if missing
      if (!columns.contains('updated_at')) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN updated_at TEXT');
        print('✅ Added updated_at to $tableName table');
      }

      // Set default timestamp for existing records
      final now = DateTime.now().toIso8601String();

      if (!columns.contains('created_at')) {
        await db.execute(
            'UPDATE $tableName SET created_at = ? WHERE created_at IS NULL',
            [now]);
      }

      if (!columns.contains('updated_at')) {
        await db.execute(
            'UPDATE $tableName SET updated_at = ? WHERE updated_at IS NULL',
            [now]);
      }
    } catch (e) {
      print('❌ Failed to add timestamps to $tableName: $e');
    }
  }

  /// Helper method to get table columns
  static Future<List<String>> _getTableColumns(
      Database db, String tableName) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      return result.map((row) => row['name'] as String).toList();
    } catch (e) {
      print('❌ Failed to get columns for table $tableName: $e');
      return [];
    }
  }

  /// Create indexes for better sync performance
  static Future<void> createSyncIndexes(Database db) async {
    print('📈 Creating sync performance indexes...');

    try {
      // Index on updated_at for all tables (used for incremental sync)
      final tables = [
        'users',
        'courses',
        'schedules',
        'invoices',
        'payments',
        'fleet'
      ];

      for (String table in tables) {
        try {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_${table}_updated_at ON $table(updated_at)');
          print('✅ Created updated_at index for $table');
        } catch (e) {
          print('⚠️ Failed to create index for $table: $e');
        }
      }

      // Additional useful indexes
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_schedules_date ON schedules(lesson_date)');

      print('✅ Sync indexes created successfully');
    } catch (e) {
      print('❌ Failed to create sync indexes: $e');
    }
  }

  /// Verify timestamp fields exist
  static Future<Map<String, dynamic>> verifyTimestampFields(Database db) async {
    print('🔍 Verifying timestamp fields...');

    final result = <String, dynamic>{
      'all_tables_have_timestamps': true,
      'missing_timestamps': <String, List<String>>{},
      'tables_checked': 0,
    };

    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet'
    ];

    for (String table in tables) {
      try {
        final columns = await _getTableColumns(db, table);
        final missing = <String>[];

        if (!columns.contains('created_at')) {
          missing.add('created_at');
          result['all_tables_have_timestamps'] = false;
        }

        if (!columns.contains('updated_at')) {
          missing.add('updated_at');
          result['all_tables_have_timestamps'] = false;
        }

        if (missing.isNotEmpty) {
          result['missing_timestamps'][table] = missing;
        }

        result['tables_checked'] = (result['tables_checked'] as int) + 1;
      } catch (e) {
        print('❌ Failed to check table $table: $e');
        result['all_tables_have_timestamps'] = false;
      }
    }

    if (result['all_tables_have_timestamps']) {
      print('✅ All tables have timestamp fields for sync');
    } else {
      print(
          '⚠️ Some tables missing timestamp fields: ${result['missing_timestamps']}');
    }

    return result;
  }
}
