import 'package:driving/controllers/utils/timestamp_converter.dart';
import 'package:driving/services/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class DeduplicationSyncService {
  /// ✅ FIX 4: Save records with duplication prevention
  static Future<void> saveToLocalDatabaseWithDeduplication(
      String table, List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;

    print('💾 Saving ${records.length} $table records with deduplication...');

    final db = await DatabaseHelper.instance.database;
    int insertedCount = 0;
    int updatedCount = 0;
    int duplicateCount = 0;

    for (var record in records) {
      try {
        final convertedRecord = TimestampConverter.prepareForSQLite(record);
        final recordId = convertedRecord['id'];

        if (recordId == null) {
          print('⚠️ Record missing ID, skipping: $record');
          continue;
        }

        // Check for existing record
        final existing =
            await db.query(table, where: 'id = ?', whereArgs: [recordId]);

        if (existing.isEmpty) {
          // Insert new record
          await db.insert(table, convertedRecord);
          insertedCount++;
          print('📥 Inserted new $table record ID: $recordId');
        } else {
          // Check if we should update based on last_modified timestamp
          final existingRecord = existing.first;
          final existingModified = existingRecord['last_modified'] as int? ?? 0;
          final newModified = convertedRecord['last_modified'] as int? ?? 0;

          if (newModified > existingModified) {
            // Update with newer data
            await db.update(table, convertedRecord,
                where: 'id = ?', whereArgs: [recordId]);
            updatedCount++;
            print('🔄 Updated $table record ID: $recordId with newer data');
          } else {
            duplicateCount++;
            print(
                '⚠️ Skipped $table record ID: $recordId (local version is newer)');
          }
        }
      } catch (e) {
        print('❌ Error saving $table record: $e');
        print('🔍 Problematic record: $record');
      }
    }

    print('✅ Deduplication results for $table:');
    print('   📥 Inserted: $insertedCount');
    print('   🔄 Updated: $updatedCount');
    print('   ⚠️ Duplicates skipped: $duplicateCount');
  }

  /// ✅ FIX 5: Fleet-specific deduplication by carplate
  static Future<void> saveFleetWithPlateDeduplication(
      List<Map<String, dynamic>> fleetRecords) async {
    if (fleetRecords.isEmpty) return;

    print(
        '🚗 Saving ${fleetRecords.length} fleet records with plate deduplication...');

    final db = await DatabaseHelper.instance.database;
    int insertedCount = 0;
    int updatedCount = 0;
    int duplicateCount = 0;

    for (var record in fleetRecords) {
      try {
        final convertedRecord = TimestampConverter.prepareForSQLite(record);
        final carplate = convertedRecord['carplate'];

        if (carplate == null || carplate == '') {
          print('⚠️ Fleet record missing carplate, skipping: $record');
          continue;
        }

        // Check for existing fleet by carplate (more reliable than ID)
        final existingFleet = await db
            .query('fleet', where: 'carplate = ?', whereArgs: [carplate]);

        if (existingFleet.isEmpty) {
          // Insert new fleet record
          await db.insert('fleet', convertedRecord);
          insertedCount++;
          print('🚗 Inserted new fleet: $carplate');
        } else {
          // Check timestamps to decide whether to update
          final existingRecord = existingFleet.first;
          final existingModified = existingRecord['last_modified'] as int? ?? 0;
          final newModified = convertedRecord['last_modified'] as int? ?? 0;

          if (newModified > existingModified) {
            // Update the existing fleet record with newer data
            await db.update('fleet', convertedRecord,
                where: 'carplate = ?', whereArgs: [carplate]);
            updatedCount++;
            print('🔄 Updated fleet: $carplate with newer data');
          } else {
            duplicateCount++;
            print('⚠️ Skipped fleet: $carplate (local version is newer)');
          }
        }
      } catch (e) {
        print('❌ Error saving fleet record: $e');
        print('🔍 Problematic record: $record');
      }
    }

    print('✅ Fleet deduplication results:');
    print('   📥 Inserted: $insertedCount');
    print('   🔄 Updated: $updatedCount');
    print('   ⚠️ Duplicates skipped: $duplicateCount');
  }

  /// ✅ FIX 6: Clean existing duplicates
  static Future<void> cleanExistingDuplicates() async {
    final db = await DatabaseHelper.instance.database;

    print('🧹 Cleaning existing duplicate records...');

    // Clean duplicate fleet records by carplate
    await _cleanFleetDuplicates(db);

    // Clean other table duplicates by ID
    final tablesToClean = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments'
    ];
    for (String table in tablesToClean) {
      await _cleanTableDuplicates(db, table);
    }

    print('✅ Duplicate cleaning completed');
  }

  static Future<void> _cleanFleetDuplicates(Database db) async {
    try {
      // Find duplicate carplates
      final duplicates = await db.rawQuery('''
        SELECT carplate, COUNT(*) as count, MIN(id) as keep_id
        FROM fleet 
        WHERE carplate IS NOT NULL AND carplate != ''
        GROUP BY carplate 
        HAVING COUNT(*) > 1
      ''');

      for (final duplicate in duplicates) {
        final carplate = duplicate['carplate'];
        final keepId = duplicate['keep_id'];
        final count = duplicate['count'];

        // Delete all except the first one (keep_id)
        final deleteCount = await db.delete(
          'fleet',
          where: 'carplate = ? AND id != ?',
          whereArgs: [carplate, keepId],
        );

        print(
            '🧹 Cleaned ${deleteCount} duplicate fleet records for carplate: $carplate');
      }
    } catch (e) {
      print('⚠️ Error cleaning fleet duplicates: $e');
    }
  }

  static Future<void> _cleanTableDuplicates(Database db, String table) async {
    try {
      // This is a more complex query - find records with same natural keys
      // For now, just clean obvious ID duplicates (shouldn't happen but just in case)
      final duplicates = await db.rawQuery('''
        SELECT id, COUNT(*) as count
        FROM $table 
        GROUP BY id 
        HAVING COUNT(*) > 1
      ''');

      for (final duplicate in duplicates) {
        final id = duplicate['id'];
        final count = duplicate['count'] as int;

        if (count > 1) {
          // Keep only one record and delete the rest
          final records =
              await db.query(table, where: 'id = ?', whereArgs: [id]);

          // Delete all but the first record
          for (int i = 1; i < records.length; i++) {
            await db.delete(table,
                where: 'rowid = ?', whereArgs: [records[i]['rowid']]);
          }

          print('🧹 Cleaned ${count - 1} duplicate records for $table ID: $id');
        }
      }
    } catch (e) {
      print('⚠️ Error cleaning $table duplicates: $e');
    }
  }
}
