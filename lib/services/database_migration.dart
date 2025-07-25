// lib/services/database_migration.dart
import 'package:driving/services/database_helper_extensions.dart';
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
      await dbHelper.createEnhancedSchedulesTable();

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

    print('Database migration completed successfully');
  }
}
