// lib/services/database_migration.dart
import 'dart:io';

import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/services/auto_seed_initializer.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/test_data_seeder.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'database_helper.dart';

class DatabaseMigration {
  static final DatabaseMigration instance = DatabaseMigration._internal();
  DatabaseMigration._internal();

  /// Migrates the database to ensure all required columns exist
  Future<void> migrateDatabase() async {
    final db = await DatabaseHelper.instance.database;

    // Check and add missing columns to schedules table
    await _migrateSchedulesTable(db);
    migrateToCloudReceipts();
  }

  Future<void> _migrateSchedulesTable(Database db) async {
    try {
      // Get current table structure
      final columns = await db.rawQuery('PRAGMA table_info(schedules)');
      final columnNames = columns.map((col) => col['name'] as String).toSet();

      // Add lessonsDeducted column if it doesn't exist
      if (!columnNames.contains('lessonsDeducted')) {
        await db.execute('''
          ALTER TABLE schedules 
          ADD COLUMN lessonsDeducted INTEGER DEFAULT 1
        ''');
        print('Added lessonsDeducted column to schedules table');
      }

      // Add is_recurring column if it doesn't exist
      if (!columnNames.contains('is_recurring')) {
        await db.execute('''
          ALTER TABLE schedules 
          ADD COLUMN is_recurring INTEGER DEFAULT 0
        ''');
        print('Added is_recurring column to schedules table');
      }

      // Add recurrence_pattern column if it doesn't exist
      if (!columnNames.contains('recurrence_pattern')) {
        await db.execute('''
          ALTER TABLE schedules 
          ADD COLUMN recurrence_pattern TEXT
        ''');
        print('Added recurrence_pattern column to schedules table');
      }

      // Add recurrence_end_date column if it doesn't exist
      if (!columnNames.contains('recurrence_end_date')) {
        await db.execute('''
          ALTER TABLE schedules 
          ADD COLUMN recurrence_end_date TEXT
        ''');
        print('Added recurrence_end_date column to schedules table');
      }

      print('Schedules table migration completed successfully');
    } catch (e) {
      print('Error migrating schedules table: $e');
      // Don't throw error to prevent app crash
    }
  }

  /// Clean up old or invalid data
  Future<void> cleanupData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Remove schedules with invalid dates
      await db.delete(
        'schedules',
        where: 'start IS NULL OR end IS NULL OR start = "" OR end = ""',
      );

      // Update null lessonsDeducted values to 1
      await db.update(
        'schedules',
        {'lessonsDeducted': 1},
        where: 'lessonsDeducted IS NULL',
      );

      // Update null lessonsCompleted values to 0
      await db.update(
        'schedules',
        {'lessonsCompleted': 0},
        where: 'lessonsCompleted IS NULL',
      );

      print('Database cleanup completed successfully');
    } catch (e) {
      print('Error during database cleanup: $e');
    }
  }

  /// Update existing schedules to have proper default values
  Future<void> updateExistingSchedules() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Update schedules that don't have lessonsDeducted set
      await db.rawUpdate('''
        UPDATE schedules 
        SET lessonsDeducted = 1 
        WHERE lessonsDeducted IS NULL OR lessonsDeducted = 0
      ''');

      // Update schedules that don't have proper status
      await db.rawUpdate('''
        UPDATE schedules 
        SET status = 'Scheduled' 
        WHERE status IS NULL OR status = ''
      ''');

      // Update old boolean values for attended column
      await db.rawUpdate('''
        UPDATE schedules 
        SET attended = 0 
        WHERE attended IS NULL
      ''');

      print('Existing schedules updated successfully');
    } catch (e) {
      print('Error updating existing schedules: $e');
    }
  }

  /// Run all migration steps
  Future<void> runFullMigration() async {
    print('Starting database migration...');

    await migrateDatabase();
    await updateExistingSchedules();
    await cleanupData();
    await checkAndFixTriggers();
    await migrateToCloudReceipts();

    print('Database migration completed successfully');
  }

  /// ✅ FIX 3: Add missing firebase_doc_id column to fleet table
  static Future<void> addMissingColumns(Database db) async {
    try {
      print('🔧 Checking for missing columns...');

      // Check if firebase_doc_id column exists in fleet table
      final fleetColumns = await db.rawQuery("PRAGMA table_info(fleet)");
      final hasFirebaseDocId =
          fleetColumns.any((column) => column['name'] == 'firebase_doc_id');

      if (!hasFirebaseDocId) {
        print('➕ Adding firebase_doc_id column to fleet table');
        await db.execute('ALTER TABLE fleet ADD COLUMN firebase_doc_id TEXT');
        print('✅ Added firebase_doc_id column to fleet table');
      }

      // Add any other missing sync columns to all tables
      final tables = [
        'users',
        'courses',
        'schedules',
        'invoices',
        'payments',
        'fleet'
      ];

      for (String table in tables) {
        await _ensureSyncColumns(db, table);
      }

      print('✅ All missing columns have been added');
    } catch (e) {
      print('❌ Error adding missing columns: $e');
    }
  }

  /// Ensure all sync-related columns exist
  static Future<void> _ensureSyncColumns(Database db, String tableName) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info($tableName)");
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      final requiredSyncColumns = {
        'firebase_synced': 'INTEGER DEFAULT 0',
        'last_modified': 'INTEGER DEFAULT 0',
        'last_modified_device': 'TEXT',
        'firebase_doc_id': 'TEXT'
      };

      for (String columnName in requiredSyncColumns.keys) {
        if (!columnNames.contains(columnName)) {
          final columnDef = requiredSyncColumns[columnName]!;
          print('➕ Adding $columnName to $tableName');
          await db.execute(
              'ALTER TABLE $tableName ADD COLUMN $columnName $columnDef');
        }
      }
    } catch (e) {
      print('⚠️ Error ensuring sync columns for $tableName: $e');
    }
  }

  /// Run this during app startup to fix existing database
  static Future<void> runMigrations(Database db) async {
    print('🔄 Running database migrations...');
    await addMissingColumns(db);
    print('✅ Database migrations completed');
    // For immediate seeding (useful in development)
    await TestDataSeeder.instance.seedAllTestData();

// Check what exists
    final status = await AutoSeedInitializer.instance.getStatus();
    print('Database status: $status');

// Seed only users for auth testing
    await TestDataSeeder.instance.seedUsersOnly();
  }

// Add this method to your DatabaseMigration class
  Future<void> checkAndFixTriggers() async {
    print('🔍 Checking for problematic database triggers...');

    final db = await DatabaseHelper.instance.database;

    try {
      // Get all triggers
      final triggers = await db.rawQuery('''
      SELECT name, sql 
      FROM sqlite_master 
      WHERE type = 'trigger' 
      AND tbl_name = 'payments'
    ''');

      print('Found ${triggers.length} triggers on payments table');

      for (final trigger in triggers) {
        final triggerName = trigger['name'] as String;
        final triggerSQL = trigger['sql'] as String;

        print('Trigger: $triggerName');
        print('SQL: $triggerSQL');

        // Check if trigger references non-existent columns
        if (triggerSQL.contains('NEW.name') ||
            triggerSQL.contains('OLD.name')) {
          print('⚠️ Found problematic trigger: $triggerName');

          // Drop the problematic trigger
          await db.execute('DROP TRIGGER IF EXISTS $triggerName');
          print('✅ Dropped trigger: $triggerName');
        }
      }
    } catch (e) {
      print('❌ Error checking triggers: $e');
    }
  }

// Updated migrateToCloudReceipts method with trigger fix
  Future<void> migrateToCloudReceipts() async {
    print('🔄 Starting cloud receipts migration...');

    final db = await DatabaseHelper.instance.database;

    // First, check and fix any problematic triggers
    await checkAndFixTriggers();

    try {
      // Check existing columns first
      final columns = await db.rawQuery('PRAGMA table_info(payments)');
      final columnNames = columns.map((col) => col['name'] as String).toSet();

      // Add new columns for cloud receipts only if they don't exist
      if (!columnNames.contains('receipt_type')) {
        await db.execute(
          'ALTER TABLE payments ADD COLUMN receipt_type TEXT DEFAULT "local"',
        );
        print('✅ Added receipt_type column');
      } else {
        print('ℹ️ receipt_type column already exists');
      }

      if (!columnNames.contains('receipt_generated_at')) {
        await db.execute(
          'ALTER TABLE payments ADD COLUMN receipt_generated_at TEXT',
        );
        print('✅ Added receipt_generated_at column');
      } else {
        print('ℹ️ receipt_generated_at column already exists');
      }

      if (!columnNames.contains('cloud_storage_path')) {
        await db.execute(
          'ALTER TABLE payments ADD COLUMN cloud_storage_path TEXT',
        );
        print('✅ Added cloud_storage_path column');
      } else {
        print('ℹ️ cloud_storage_path column already exists');
      }

      if (!columnNames.contains('receipt_file_size')) {
        await db.execute(
          'ALTER TABLE payments ADD COLUMN receipt_file_size INTEGER',
        );
        print('✅ Added receipt_file_size column');
      } else {
        print('ℹ️ receipt_file_size column already exists');
      }

      // Update existing receipts to mark them as local type
      // Use a transaction to ensure atomicity
      await db.transaction((txn) async {
        await txn.execute('''
        UPDATE payments 
        SET receipt_type = 'local' 
        WHERE receipt_generated = 1 
        AND receipt_type IS NULL
      ''');
      });

      print('✅ Cloud receipts migration completed');
    } catch (e) {
      print('❌ Error in cloud receipts migration: $e');
      rethrow;
    }
  }

  // Call this in your database initialization
  Future<void> _onCreate(Database db, int version) async {
    // Your existing table creation code...

    // Payments table with cloud receipt support
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        amount REAL NOT NULL,
        paymentDate TEXT NOT NULL,
        method TEXT,
        reference TEXT,
        notes TEXT,
        receipt_path TEXT,
        receipt_generated INTEGER DEFAULT 0,
        receipt_type TEXT DEFAULT 'local',
        cloud_storage_path TEXT,
        receipt_file_size INTEGER,
        receipt_generated_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        last_modified INTEGER DEFAULT 0,
        firebase_synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        last_modified_device TEXT,
        firebase_user_id TEXT,
        sync_version INTEGER DEFAULT 1,
        FOREIGN KEY (invoiceId) REFERENCES invoices (id)
      )
    ''');
  }
}

// 3. Migration Utility Class
class CloudReceiptMigrationService {
  /// Check migration status
  static Future<Map<String, dynamic>> checkMigrationStatus() async {
    print('🔍 Checking cloud receipt migration status...');

    final db = await DatabaseHelper.instance.database;

    // Count total receipts
    final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM payments WHERE receipt_generated = 1');
    final totalReceipts = (totalResult.first['count'] as int?) ?? 0;

    // Count cloud receipts
    final cloudResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM payments 
      WHERE receipt_generated = 1 
      AND receipt_type = 'cloud' 
      AND receipt_path LIKE 'https://%'
    ''');
    final cloudReceipts = (cloudResult.first['count'] as int?) ?? 0;

    // Count local receipts
    final localResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM payments 
      WHERE receipt_generated = 1 
      AND (receipt_type = 'local' OR receipt_type IS NULL)
    ''');
    final localReceipts = (localResult.first['count'] as int?) ?? 0;

    final migrationPercentage =
        totalReceipts > 0 ? (cloudReceipts / totalReceipts * 100).round() : 100;

    final status = {
      'total_receipts': totalReceipts,
      'cloud_receipts': cloudReceipts,
      'local_receipts': localReceipts,
      'migration_percentage': migrationPercentage,
      'migration_complete': migrationPercentage == 100,
      'needs_migration': localReceipts > 0,
    };

    print('📊 Migration Status:');
    print('   Total Receipts: $totalReceipts');
    print('   Cloud Receipts: $cloudReceipts');
    print('   Local Receipts: $localReceipts');
    print('   Migration: $migrationPercentage%');

    return status;
  }

  /// Clean up local receipt files after migration
  static Future<Map<String, dynamic>> cleanupLocalReceipts() async {
    print('🧹 Cleaning up local receipt files...');

    try {
      final db = await DatabaseHelper.instance.database;

      // Get all payments with cloud receipts
      final cloudReceipts = await db.rawQuery('''
        SELECT receipt_path FROM payments 
        WHERE receipt_type = 'cloud' 
        AND receipt_path LIKE 'https://%'
      ''');

      // Get receipts directory
      final directory = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${directory.path}/receipts');

      if (!await receiptsDir.exists()) {
        return {
          'message': 'No local receipts directory found',
          'files_deleted': 0,
          'space_saved_mb': '0.00',
        };
      }

      final files = receiptsDir.listSync();
      int deletedCount = 0;
      int totalSizeBytes = 0;

      for (final file in files) {
        if (file is File && file.path.endsWith('.pdf')) {
          try {
            final stat = await file.stat();
            totalSizeBytes += stat.size;

            await file.delete();
            deletedCount++;

            print('🗑️ Deleted local receipt: ${file.path}');
          } catch (e) {
            print('❌ Failed to delete ${file.path}: $e');
          }
        }
      }

      final spaceSavedMB = (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2);

      final result = {
        'files_deleted': deletedCount,
        'space_saved_bytes': totalSizeBytes,
        'space_saved_mb': spaceSavedMB,
        'cloud_receipts_count': cloudReceipts.length,
      };

      print('🧹 Local cleanup completed:');
      print('   Files deleted: $deletedCount');
      print('   Space saved: $spaceSavedMB MB');

      return result;
    } catch (e) {
      print('❌ Local cleanup failed: $e');
      rethrow;
    }
  }
}
