import 'package:driving/constant/schedule_status.dart';
import 'database_helper.dart';

class ScheduleStatusMigration {
  static final ScheduleStatusMigration instance =
      ScheduleStatusMigration._internal();
  ScheduleStatusMigration._internal();

  /// Run complete schedule status cleanup and migration
  Future<void> runStatusMigration() async {
    print('Starting schedule status migration...');

    try {
      await _fixInconsistentStatuses();
      await _updateCompletedLessons();
      await _updateMissedLessons();
      await _updateInProgressLessons();
      await _cleanupInvalidStatuses();
      await _validateMigration();

      print('Schedule status migration completed successfully');
    } catch (e) {
      print('Error during schedule status migration: $e');
      throw e;
    }
  }

  /// Fix schedules where attended=1 but status is not 'Completed'
  Future<void> _fixInconsistentStatuses() async {
    final db = await DatabaseHelper.instance.database;

    print('Fixing inconsistent attended/status combinations...');

    // Fix attended lessons that aren't marked as completed
    final updatedCompleted = await db.rawUpdate('''
      UPDATE schedules 
      SET status = ? 
      WHERE attended = 1 AND status != ?
    ''', [ScheduleStatus.completed, ScheduleStatus.completed]);

    print('Fixed $updatedCompleted completed lessons');

    // Fix cancelled lessons that are marked as attended
    final fixedCancelled = await db.rawUpdate('''
      UPDATE schedules 
      SET attended = 0 
      WHERE status = ? AND attended = 1
    ''', [ScheduleStatus.cancelled]);

    print(
        'Fixed $fixedCancelled cancelled lessons that were incorrectly marked attended');
  }

  /// Update lessons that should be marked as missed
  Future<void> _updateMissedLessons() async {
    final db = await DatabaseHelper.instance.database;

    print('Updating missed lessons...');

    // Mark past lessons as missed if they weren't attended and aren't cancelled
    final now = DateTime.now().toIso8601String();
    final updatedMissed = await db.rawUpdate('''
      UPDATE schedules 
      SET status = ? 
      WHERE datetime(end) < datetime(?) 
        AND attended = 0 
        AND status != ? 
        AND status != ?
    ''', [
      ScheduleStatus.missed,
      now,
      ScheduleStatus.cancelled,
      ScheduleStatus.missed
    ]);

    print('Updated $updatedMissed missed lessons');
  }

  /// Update lessons that are currently in progress
  Future<void> _updateInProgressLessons() async {
    final db = await DatabaseHelper.instance.database;

    print('Updating in-progress lessons...');

    final now = DateTime.now().toIso8601String();

    // First, reset any old "in progress" status for lessons that have ended
    await db.rawUpdate('''
      UPDATE schedules 
      SET status = ? 
      WHERE status = ? 
        AND datetime(end) < datetime(?)
        AND attended = 0
    ''', [ScheduleStatus.missed, ScheduleStatus.inProgress, now]);

    // Mark current lessons as in progress
    final updatedInProgress = await db.rawUpdate('''
      UPDATE schedules 
      SET status = ? 
      WHERE datetime(start) <= datetime(?) 
        AND datetime(end) > datetime(?) 
        AND attended = 0 
        AND status != ?
    ''', [ScheduleStatus.inProgress, now, now, ScheduleStatus.cancelled]);

    print('Updated $updatedInProgress in-progress lessons');
  }

  /// Update completed lessons counter based on actual attendance
  Future<void> _updateCompletedLessons() async {
    final db = await DatabaseHelper.instance.database;

    print('Recalculating completed lessons...');

    // Reset all lessonsCompleted to 0 first
    await db.rawUpdate('UPDATE schedules SET lessonsCompleted = 0');

    // Update lessonsCompleted for attended lessons based on their duration
    final updated = await db.rawUpdate('''
      UPDATE schedules 
      SET lessonsCompleted = 
        CASE 
          WHEN attended = 1 THEN 
            CAST((
              (strftime('%s', end) - strftime('%s', start)) / 1800.0
            ) AS INTEGER)
          ELSE 0
        END
    ''');

    print('Recalculated completed lessons for $updated schedules');
  }

  /// Clean up invalid status values
  Future<void> _cleanupInvalidStatuses() async {
    final db = await DatabaseHelper.instance.database;

    print('Cleaning up invalid status values...');

    // Get all unique status values
    final statusResults = await db.rawQuery(
        'SELECT DISTINCT status FROM schedules WHERE status IS NOT NULL');
    final existingStatuses =
        statusResults.map((row) => row['status'] as String).toSet();

    // Find invalid statuses
    final invalidStatuses = existingStatuses
        .where((status) => !ScheduleStatus.isValidStatus(status))
        .toList();

    if (invalidStatuses.isNotEmpty) {
      print('Found invalid statuses: $invalidStatuses');

      // Update invalid statuses to 'Scheduled'
      for (final invalidStatus in invalidStatuses) {
        final updated = await db.rawUpdate('''
          UPDATE schedules 
          SET status = ? 
          WHERE status = ?
        ''', [ScheduleStatus.scheduled, invalidStatus]);

        print(
            'Updated $updated schedules from "$invalidStatus" to "${ScheduleStatus.scheduled}"');
      }
    }
  }

  /// Validate migration results
  Future<void> _validateMigration() async {
    final db = await DatabaseHelper.instance.database;

    print('Validating migration results...');

    // Check for inconsistencies
    final inconsistentResults = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM schedules 
      WHERE (attended = 1 AND status != ?) 
         OR (status = ? AND attended = 0)
    ''', [ScheduleStatus.completed, ScheduleStatus.completed]);

    final inconsistentCount = inconsistentResults.first['count'] as int;

    if (inconsistentCount > 0) {
      print(
          'WARNING: Found $inconsistentCount inconsistent records after migration');
    } else {
      print('✓ No inconsistencies found');
    }

    // Show migration summary
    final summaryResults = await db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM schedules 
      GROUP BY status 
      ORDER BY count DESC
    ''');

    print('Migration summary by status:');
    for (final row in summaryResults) {
      print('  ${row['status']}: ${row['count']} schedules');
    }

    // Check attended vs status alignment
    final attendedResults = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN attended = 1 THEN 1 ELSE 0 END) as attended_count,
        SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as completed_count
      FROM schedules
    ''', [ScheduleStatus.completed]);

    final attendedCount = attendedResults.first['attended_count'] as int;
    final completedCount = attendedResults.first['completed_count'] as int;

    print('Attended lessons: $attendedCount');
    print('Completed status: $completedCount');

    if (attendedCount == completedCount) {
      print('✓ Attended and completed counts match');
    } else {
      print(
          'WARNING: Attended ($attendedCount) and completed ($completedCount) counts do not match');
    }
  }

  /// Get migration statistics before running
  Future<Map<String, dynamic>> getMigrationStats() async {
    final db = await DatabaseHelper.instance.database;

    // Get current status distribution
    final statusResults = await db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM schedules 
      GROUP BY status
    ''');

    // Get inconsistent records
    final inconsistentResults = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM schedules 
      WHERE (attended = 1 AND status != ?) 
         OR (status = ? AND attended = 0)
    ''', [ScheduleStatus.completed, ScheduleStatus.completed]);

    // Get lessons that should be missed
    final now = DateTime.now().toIso8601String();
    final shouldBeMissedResults = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM schedules 
      WHERE datetime(end) < datetime(?) 
        AND attended = 0 
        AND status != ? 
        AND status != ?
    ''', [now, ScheduleStatus.cancelled, ScheduleStatus.missed]);

    return {
      'statusDistribution': Map.fromEntries(statusResults.map(
          (row) => MapEntry(row['status'] as String, row['count'] as int))),
      'inconsistentRecords': inconsistentResults.first['count'] as int,
      'shouldBeMissed': shouldBeMissedResults.first['count'] as int,
    };
  }
}
