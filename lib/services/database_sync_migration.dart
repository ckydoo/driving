
import 'package:sqflite/sqflite.dart';

class DatabaseSyncMigration {
  /// Run sync migrations (add timestamp fields only)
  static Future<void> runSyncMigrations(Database db) async {
    print('🔄 Running sync migrations (timestamps only)...');

    try {
      // Add timestamp fields to all existing tables
      final tables = [
        'users',
        'courses',
        'schedules',
        'invoices',
        'payments',
        'fleet'
      ];

      for (String table in tables) {
        await _addTimestampFields(db, table);
      }

      print('✅ Sync migrations completed');
    } catch (e) {
      print('❌ Sync migrations failed: $e');
      throw e;
    }
  }

  /// Add timestamp fields to a table if they don't exist
  static Future<void> _addTimestampFields(Database db, String tableName) async {
    try {
      // Check if table exists
      final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName]);

      if (tableExists.isEmpty) {
        print('ℹ️ Table $tableName does not exist, skipping timestamps');
        return;
      }

      final columns = await _getTableColumns(db, tableName);
      final now = DateTime.now().toIso8601String();

      // Add created_at if it doesn't exist
      if (!columns.contains('created_at')) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN created_at TEXT');
        await db.execute(
            'UPDATE $tableName SET created_at = ? WHERE created_at IS NULL',
            [now]);
        print('✅ Added created_at to $tableName');
      }

      // Add updated_at if it doesn't exist
      if (!columns.contains('updated_at')) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN updated_at TEXT');
        await db.execute(
            'UPDATE $tableName SET updated_at = ? WHERE updated_at IS NULL',
            [now]);
        print('✅ Added updated_at to $tableName');
      }

      if (!columns.contains('created_at') || !columns.contains('updated_at')) {
        print('ℹ️ Timestamp fields already exist in $tableName');
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

  /// Create indexes for better sync performance - REMOVED PROBLEMATIC INDEXES
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

      // ONLY create indexes for columns we know exist
      try {
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)');
        print('✅ Created email index for users');
      } catch (e) {
        print('⚠️ Failed to create email index: $e');
      }

      // Check if schedules has 'start' column before creating index
      final scheduleColumns = await _getTableColumns(db, 'schedules');
      if (scheduleColumns.contains('start')) {
        try {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_schedules_start ON schedules(start)');
          print('✅ Created start index for schedules');
        } catch (e) {
          print('⚠️ Failed to create start index: $e');
        }
      } else {
        print('ℹ️ Skipping schedules start index - column does not exist');
      }

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
        // Check if table exists
        final tableExists = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            [table]);

        if (tableExists.isEmpty) {
          continue; // Skip non-existent tables
        }

        result['tables_checked']++;
        final columns = await _getTableColumns(db, table);

        final missingColumns = <String>[];

        if (!columns.contains('created_at')) {
          missingColumns.add('created_at');
        }

        if (!columns.contains('updated_at')) {
          missingColumns.add('updated_at');
        }

        if (missingColumns.isNotEmpty) {
          result['all_tables_have_timestamps'] = false;
          result['missing_timestamps'][table] = missingColumns;
        }

        print(
            '✅ Verified $table: ${missingColumns.isEmpty ? 'OK' : 'Missing: ${missingColumns.join(', ')}'}');
      } catch (e) {
        print('❌ Failed to verify $table: $e');
        result['all_tables_have_timestamps'] = false;
      }
    }

    print(
        '🔍 Verification complete: ${result['tables_checked']} tables checked');
    return result;
  }
}
