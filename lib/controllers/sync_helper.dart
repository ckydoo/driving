// lib/services/sync_helper.dart
// Simple helper functions for database sync without extensions

import 'package:sqflite_common/sqlite_api.dart';
import 'package:driving/services/database_helper.dart';

class SyncHelper {
  /// Convert Firebase Timestamp objects to SQLite-compatible format
  static Map<String, dynamic> convertFirebaseTimestamps(
      Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    for (final key in result.keys.toList()) {
      final value = result[key];

      // Handle Firebase Timestamp objects
      if (value != null && value.toString().contains('Timestamp(seconds=')) {
        try {
          // Extract seconds from Timestamp string
          final timestampStr = value.toString();
          final secondsMatch =
              RegExp(r'seconds=(\d+)').firstMatch(timestampStr);
          final nanosMatch =
              RegExp(r'nanoseconds=(\d+)').firstMatch(timestampStr);

          if (secondsMatch != null) {
            final seconds = int.parse(secondsMatch.group(1)!);
            final nanos =
                nanosMatch != null ? int.parse(nanosMatch.group(1)!) : 0;

            // Convert to milliseconds since epoch
            final milliseconds = seconds * 1000 + (nanos ~/ 1000000);
            result[key] = milliseconds;

            print('🔄 Converted timestamp $key: $value -> $milliseconds');
          }
        } catch (e) {
          print('⚠️ Failed to convert timestamp $key: $e');
          // Fallback to current time
          result[key] = DateTime.now().millisecondsSinceEpoch;
        }
      }

      // Handle other timestamp formats
      else if (value is Map && value.containsKey('seconds')) {
        try {
          final seconds = value['seconds'] as int;
          final nanoseconds = (value['nanoseconds'] as int?) ?? 0;
          result[key] = seconds * 1000 + (nanoseconds ~/ 1000000);
        } catch (e) {
          result[key] = DateTime.now().millisecondsSinceEpoch;
        }
      }
    }

    return result;
  }

  /// Safe insert with conflict resolution
  static Future<int?> safeInsert(
      Database db, String table, Map<String, dynamic> data) async {
    try {
      // Convert timestamps first
      final convertedData = convertFirebaseTimestamps(data);

      // Handle unique constraint conflicts for users
      if (table == 'users' && convertedData.containsKey('idnumber')) {
        final existingUser = await db.query(
          table,
          where: 'idnumber = ?',
          whereArgs: [convertedData['idnumber']],
          limit: 1,
        );

        if (existingUser.isNotEmpty) {
          print(
              '⚠️ User with ID ${convertedData['idnumber']} already exists, updating instead');
          final updateResult = await db.update(
            table,
            convertedData,
            where: 'idnumber = ?',
            whereArgs: [convertedData['idnumber']],
          );
          return updateResult;
        }
      }

      // Handle unique constraint conflicts for fleet
      if (table == 'fleet' && convertedData.containsKey('carplate')) {
        final existingFleet = await db.query(
          table,
          where: 'carplate = ?',
          whereArgs: [convertedData['carplate']],
          limit: 1,
        );

        if (existingFleet.isNotEmpty) {
          print(
              '⚠️ Fleet with plate ${convertedData['carplate']} already exists, updating instead');
          final updateResult = await db.update(
            table,
            convertedData,
            where: 'carplate = ?',
            whereArgs: [convertedData['carplate']],
          );
          return updateResult;
        }
      }

      // Add missing columns if needed
      await _ensureTableColumns(db, table, convertedData);

      // Perform the insert
      final result = await db.insert(
        table,
        convertedData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Inserted into $table: ${convertedData['id'] ?? 'new record'}');
      return result;
    } catch (e) {
      print('❌ Error inserting into $table: $e');
      print('📋 Failed data: ${data.toString().substring(0, 200)}...');
      return null;
    }
  }

  /// Ensure table has required columns
  static Future<void> _ensureTableColumns(
      Database db, String table, Map<String, dynamic> data) async {
    try {
      // Get existing columns
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final existingColumns =
          columns.map((col) => col['name'] as String).toSet();

      // Check for missing columns
      final missingColumns = <String>[];
      for (final key in data.keys) {
        if (!existingColumns.contains(key)) {
          missingColumns.add(key);
        }
      }

      // Add missing columns
      for (final column in missingColumns) {
        try {
          // Determine column type based on data
          String columnType = 'TEXT';
          final value = data[column];
          if (value is int) {
            columnType = 'INTEGER';
          } else if (value is double) {
            columnType = 'REAL';
          }

          await db.execute('ALTER TABLE $table ADD COLUMN $column $columnType');
          print('✅ Added missing column: $table.$column ($columnType)');
        } catch (e) {
          print('⚠️ Could not add column $table.$column: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error checking table structure for $table: $e');
    }
  }

  /// Clean duplicate records
  static Future<void> cleanDuplicates(
      Database db, String table, String uniqueField) async {
    try {
      // Find duplicates
      final duplicates = await db.rawQuery('''
        SELECT $uniqueField, COUNT(*) as count, MIN(id) as keep_id
        FROM $table 
        GROUP BY $uniqueField 
        HAVING COUNT(*) > 1
      ''');

      for (final duplicate in duplicates) {
        final uniqueValue = duplicate[uniqueField];
        final keepId = duplicate['keep_id'];

        // Delete all except the first one
        final deleteCount = await db.delete(
          table,
          where: '$uniqueField = ? AND id != ?',
          whereArgs: [uniqueValue, keepId],
        );

        print(
            '🧹 Cleaned $deleteCount duplicates for $uniqueField: $uniqueValue');
      }
    } catch (e) {
      print('⚠️ Error cleaning duplicates in $table: $e');
    }
  }
}
