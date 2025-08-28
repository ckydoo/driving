// lib/services/database_migration.dart
import 'dart:io';

import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/services/receipt_service.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  /// Initialize sample data if the database is empty
  Future<void> initializeSampleData() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final schedules = await dbHelper.getSchedules();

      if (schedules.isEmpty) {
        print('No schedules found. Consider adding sample data for testing.');
        // Optionally add sample schedules here
        await _addSampleSchedules();
      }
    } catch (e) {
      print('Error checking for sample data: $e');
    }
  }

  Future<void> _addSampleSchedules() async {
    try {
      final dbHelper = DatabaseHelper.instance;

      // Sample schedule data
      final sampleSchedules = [
        {
          'start': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
          'end': DateTime.now().add(Duration(hours: 2)).toIso8601String(),
          'course': 1,
          'student': 1,
          'instructor': 1,
          'car': 1,
          'class_type': 'Practical',
          'status': 'Scheduled',
          'attended': 0,
          'lessonsCompleted': 0,
          'lessonsDeducted': 1,
          'is_recurring': 0,
        },
        {
          'start':
              DateTime.now().add(Duration(days: 1, hours: 2)).toIso8601String(),
          'end':
              DateTime.now().add(Duration(days: 1, hours: 3)).toIso8601String(),
          'course': 1,
          'student': 2,
          'instructor': 1,
          'car': 1,
          'class_type': 'Theory',
          'status': 'Scheduled',
          'attended': 0,
          'lessonsCompleted': 0,
          'lessonsDeducted': 1,
          'is_recurring': 0,
        },
        {
          'start': DateTime.now()
              .subtract(Duration(days: 1, hours: 1))
              .toIso8601String(),
          'end': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
          'course': 1,
          'student': 1,
          'instructor': 1,
          'car': 1,
          'class_type': 'Practical',
          'status': 'Completed',
          'attended': 1,
          'lessonsCompleted': 1,
          'lessonsDeducted': 1,
          'is_recurring': 0,
        },
      ];

      for (final schedule in sampleSchedules) {
        await dbHelper.insertSchedule(schedule);
      }

      print('Sample schedules added successfully');
    } catch (e) {
      print('Error adding sample schedules: $e');
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
    await initializeSampleData();
    await migrateToCloudReceipts();

    print('Database migration completed successfully');
  }

  Future<void> migrateToCloudReceipts() async {
    print('🔄 Starting cloud receipts migration...');

    final db = await DatabaseHelper.instance.database;

    try {
      // Add new columns for cloud receipts
      await db.execute(
        'ALTER TABLE payments ADD COLUMN receipt_type TEXT DEFAULT "local"',
      );
      print('✅ Added receipt_type column');
    } catch (e) {
      print('⚠️ receipt_type column may already exist: $e');
    }
    try {
      // Add new columns for cloud receipts
      await db.execute(
        'ALTER TABLE payments ADD COLUMN receipt_generated_at TEXT',
      );
      print('✅ Added receipt_generated_at column');
    } catch (e) {
      print('⚠️ receipt_generated_at column may already exist: $e');
    }
    try {
      await db.execute(
        'ALTER TABLE payments ADD COLUMN cloud_storage_path TEXT',
      );
      print('✅ Added cloud_storage_path column');
    } catch (e) {
      print('⚠️ cloud_storage_path column may already exist: $e');
    }

    try {
      await db.execute(
        'ALTER TABLE payments ADD COLUMN receipt_file_size INTEGER',
      );
      print('✅ Added receipt_file_size column');
    } catch (e) {
      print('⚠️ receipt_file_size column may already exist: $e');
    }

    // Update existing receipts to mark them as local type
    await db.execute('''
      UPDATE payments 
      SET receipt_type = 'local' 
      WHERE receipt_generated = 1 
      AND receipt_type IS NULL
    ''');

    print('✅ Cloud receipts migration completed');
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

  /// Perform automatic migration
  static Future<Map<String, dynamic>> performAutoMigration() async {
    print('🚀 Starting automatic cloud migration...');

    try {
      // Check if Firebase Storage is available
      if (!ReceiptService.isStorageAvailable) {
        throw Exception('Firebase Storage not available');
      }

      final db = await DatabaseHelper.instance.database;

      // Get all local receipts that need migration
      final localReceipts = await db.rawQuery('''
        SELECT * FROM payments 
        WHERE receipt_generated = 1 
        AND (receipt_type = 'local' OR receipt_type IS NULL)
        AND (receipt_path IS NOT NULL AND receipt_path != '')
        ORDER BY paymentDate DESC
      ''');

      if (localReceipts.isEmpty) {
        return {
          'message': 'No receipts need migration',
          'total_processed': 0,
          'success_count': 0,
          'failure_count': 0,
        };
      }

      print('📄 Found ${localReceipts.length} receipts to migrate');

      int successCount = 0;
      int failureCount = 0;
      final errors = <String, String>{};

      for (int i = 0; i < localReceipts.length; i++) {
        try {
          final paymentData = localReceipts[i];
          final payment = Payment.fromJson(paymentData);

          print(
              '🔄 Migrating receipt for payment ${payment.id} ($i/${localReceipts.length})');

          // Check if local file exists
          final localPath = payment.receiptPath;
          if (localPath != null && localPath.isNotEmpty) {
            final localFile = File(localPath);

            if (await localFile.exists()) {
              // Read local file and upload to cloud
              final pdfBytes = await localFile.readAsBytes();

              // Generate cloud path
              final schoolConfig = Get.find<SchoolConfigService>();
              final schoolId = schoolConfig.schoolId.value;
              final cloudPath =
                  ReceiptService.generateCloudReceiptPath(payment, schoolId);

              // Upload to Firebase Storage
              final ref = FirebaseStorage.instance.ref().child(cloudPath);
              final uploadTask = ref.putData(
                pdfBytes,
                SettableMetadata(
                  contentType: 'application/pdf',
                  customMetadata: {
                    'migrated_at': DateTime.now().toIso8601String(),
                    'original_path': localPath,
                    'payment_id': payment.id.toString(),
                  },
                ),
              );

              final snapshot = await uploadTask;
              final downloadUrl = await snapshot.ref.getDownloadURL();

              // Update database record
              await db.update(
                'payments',
                {
                  'receipt_path': downloadUrl,
                  'receipt_type': 'cloud',
                  'cloud_storage_path': cloudPath,
                  'receipt_file_size': pdfBytes.length,
                  'last_modified': DateTime.now().millisecondsSinceEpoch,
                  'firebase_synced': 0,
                },
                where: 'id = ?',
                whereArgs: [payment.id],
              );

              // Optionally delete local file after successful upload
              // await localFile.delete();

              successCount++;
              print('✅ Migrated payment ${payment.id}');
            } else {
              // Local file doesn't exist, regenerate as cloud receipt
              final downloadUrl =
                  await ReceiptService.generateReceiptSmart(payment);

              await db.update(
                'payments',
                {
                  'receipt_path': downloadUrl,
                  'receipt_type': 'cloud',
                  'last_modified': DateTime.now().millisecondsSinceEpoch,
                  'firebase_synced': 0,
                },
                where: 'id = ?',
                whereArgs: [payment.id],
              );

              successCount++;
              print('✅ Regenerated cloud receipt for payment ${payment.id}');
            }
          } else {
            // No local path, generate new cloud receipt
            final downloadUrl =
                await ReceiptService.generateReceiptSmart(payment);

            await db.update(
              'payments',
              {
                'receipt_path': downloadUrl,
                'receipt_type': 'cloud',
                'last_modified': DateTime.now().millisecondsSinceEpoch,
                'firebase_synced': 0,
              },
              where: 'id = ?',
              whereArgs: [payment.id],
            );

            successCount++;
            print('✅ Generated new cloud receipt for payment ${payment.id}');
          }
        } catch (e) {
          failureCount++;
          errors[localReceipts[i]['id'].toString()] = e.toString();
          print('❌ Failed to migrate payment ${localReceipts[i]['id']}: $e');
        }
      }

      final result = {
        'total_processed': localReceipts.length,
        'success_count': successCount,
        'failure_count': failureCount,
        'errors': errors,
        'success_rate': localReceipts.isNotEmpty
            ? (successCount / localReceipts.length * 100).round()
            : 100,
      };

      print('🚀 Auto migration completed:');
      print('   Processed: ${result['total_processed']}');
      print('   Success: ${result['success_count']}');
      print('   Failed: ${result['failure_count']}');
      print('   Success Rate: ${result['success_rate']}%');

      return result;
    } catch (e) {
      print('❌ Auto migration failed: $e');
      rethrow;
    }
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
