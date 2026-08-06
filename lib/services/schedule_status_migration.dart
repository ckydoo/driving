import 'package:flutter/foundation.dart';
import 'package:driving/constant/schedule_status.dart';
import 'database_helper.dart';

class ScheduleStatusMigration {
  static final ScheduleStatusMigration instance =
      ScheduleStatusMigration._internal();
  ScheduleStatusMigration._internal();

  /// Run complete schedule status cleanup and migration
  Future<void> runStatusMigration() async {
    debugPrint('Starting schedule status migration...');

    try {
      // Check if schedules table exists first
      final hasSchedules = await _checkSchedulesTableExists();
      if (!hasSchedules) {
        debugPrint('Schedules table does not exist, skipping migration');
        return;
      }

      await _fixInconsistentStatuses();
      await _updateCompletedLessons();
      await _updateMissedLessons();
      await _updateInProgressLessons();
      await _cleanupInvalidStatuses();
      await _validateMigration();

      debugPrint('Schedule status migration completed successfully');
    } catch (e) {
      debugPrint('Error during schedule status migration: $e');
      // Don't rethrow - let app continue even if migration fails
    }
  }

  /// Check if schedules table exists
  Future<bool> _checkSchedulesTableExists() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name='schedules'
      ''');
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking schedules table: $e');
      return false;
    }
  }

  /// Fix schedules where attended=1 but status is not 'Completed'
  Future<void> _fixInconsistentStatuses() async {
    try {
      final db = await DatabaseHelper.instance.database;

      debugPrint('Fixing inconsistent attended/status combinations...');
      final updatedCompleted = await db.rawUpdate('''
        UPDATE schedules 
        SET status = ? 
        WHERE attended = 1 AND (status != ? OR status IS NULL)
      ''', [ScheduleStatus.completed, ScheduleStatus.completed]);

      debugPrint('Fixed $updatedCompleted completed lessons');
      final fixedCancelled = await db.rawUpdate('''
        UPDATE schedules 
        SET attended = 0 
        WHERE status = ? AND attended = 1
      ''', [ScheduleStatus.cancelled]);

      debugPrint(
          'Fixed $fixedCancelled cancelled lessons that were incorrectly marked attended');
    } catch (e) {
      debugPrint('Error fixing inconsistent statuses: $e');
    }
  }

  /// Update lessons that should be marked as missed
  Future<void> _updateMissedLessons() async {
    try {
      final db = await DatabaseHelper.instance.database;

      debugPrint('Updating missed lessons...');

      // Mark past lessons as missed if they weren't attended and aren't cancelled
      final now = DateTime.now().toIso8601String();
      final updatedMissed = await db.rawUpdate('''
        UPDATE schedules 
        SET status = ? 
        WHERE datetime(end) < datetime(?) 
          AND (attended = 0 OR attended IS NULL)
          AND status != ? 
          AND status != ?
          AND (status IS NOT NULL AND status != '')
      ''', [
        ScheduleStatus.missed,
        now,
        ScheduleStatus.cancelled,
        ScheduleStatus.missed
      ]);

      debugPrint('Updated $updatedMissed missed lessons');
    } catch (e) {
      debugPrint('Error updating missed lessons: $e');
    }
  }

  /// Update lessons that are currently in progress
  Future<void> _updateInProgressLessons() async {
    try {
      final db = await DatabaseHelper.instance.database;

      debugPrint('Updating in-progress lessons...');

      final now = DateTime.now().toIso8601String();

      // First, reset any old "in progress" status for lessons that have ended
      await db.rawUpdate('''
        UPDATE schedules 
        SET status = ? 
        WHERE status = ? 
          AND datetime(end) < datetime(?)
          AND (attended = 0 OR attended IS NULL)
      ''', [ScheduleStatus.missed, ScheduleStatus.inProgress, now]);

      // Mark current lessons as in progress
      final updatedInProgress = await db.rawUpdate('''
        UPDATE schedules 
        SET status = ? 
        WHERE datetime(start) <= datetime(?) 
          AND datetime(end) > datetime(?) 
          AND (attended = 0 OR attended IS NULL)
          AND (status != ? OR status IS NULL)
      ''', [ScheduleStatus.inProgress, now, now, ScheduleStatus.cancelled]);

      debugPrint('Updated $updatedInProgress in-progress lessons');
    } catch (e) {
      debugPrint('Error updating in-progress lessons: $e');
    }
  }

  /// Update completed lessons counter based on actual attendance
  Future<void> _updateCompletedLessons() async {
    try {
      final db = await DatabaseHelper.instance.database;

      debugPrint('Recalculating completed lessons...');

      // Reset all lessonsCompleted to 0 first
      await db.rawUpdate(
          'UPDATE schedules SET lessonsCompleted = 0 WHERE lessonsCompleted IS NULL');

      // Update lessonsCompleted for attended lessons based on their duration
      final updated = await db.rawUpdate('''
        UPDATE schedules 
        SET lessonsCompleted = 
          CASE 
            WHEN attended = 1 THEN 
              COALESCE(
                CAST((
                  (strftime('%s', end) - strftime('%s', start)) / 1800.0
                ) AS INTEGER),
                1
              )
            ELSE 0
          END
        WHERE start IS NOT NULL AND end IS NOT NULL
      ''');

      debugPrint('Recalculated completed lessons for $updated schedules');
    } catch (e) {
      debugPrint('Error updating completed lessons: $e');
    }
  }

  /// Clean up invalid status values
  Future<void> _cleanupInvalidStatuses() async {
    try {
      final db = await DatabaseHelper.instance.database;

      debugPrint('Cleaning up invalid status values...');

      // Get all unique status values (excluding null)
      final statusResults = await db.rawQuery(
          'SELECT DISTINCT status FROM schedules WHERE status IS NOT NULL AND status != ""');
      final existingStatuses =
          statusResults.map((row) => row['status'] as String).toSet();

      // Find invalid statuses
      final invalidStatuses = existingStatuses
          .where((status) => !ScheduleStatus.isValidStatus(status))
          .toList();

      if (invalidStatuses.isNotEmpty) {
        debugPrint('Found invalid statuses: $invalidStatuses');

        // Update invalid statuses to 'Scheduled'
        for (final invalidStatus in invalidStatuses) {
          final updated = await db.rawUpdate('''
            UPDATE schedules 
            SET status = ? 
            WHERE status = ?
          ''', [ScheduleStatus.scheduled, invalidStatus]);

          debugPrint(
              'Updated $updated schedules from "$invalidStatus" to "${ScheduleStatus.scheduled}"');
        }
      }

      // Set null or empty statuses to 'Scheduled'
      final nullStatusUpdated = await db.rawUpdate('''
        UPDATE schedules 
        SET status = ? 
        WHERE status IS NULL OR status = ''
      ''', [ScheduleStatus.scheduled]);

      if (nullStatusUpdated > 0) {
        debugPrint(
            'Updated $nullStatusUpdated schedules with null/empty status to "Scheduled"');
      }
    } catch (e) {
      debugPrint('Error cleaning up invalid statuses: $e');
    }
  }

  /// Validate migration results
  Future<void> _validateMigration() async {
    try {
      final db = await DatabaseHelper.instance.database;

      debugPrint('Validating migration results...');

      // Check for inconsistencies (with null safety)
      final inconsistentResults = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM schedules 
        WHERE ((attended = 1 OR attended IS NULL) AND (status != ? OR status IS NULL))
           OR ((status = ? OR status IS NULL) AND (attended = 0 OR attended IS NULL))
      ''', [ScheduleStatus.completed, ScheduleStatus.completed]);

      final inconsistentCount =
          (inconsistentResults.first['count'] as int?) ?? 0;

      if (inconsistentCount > 0) {
        debugPrint(
            'WARNING: Found $inconsistentCount inconsistent records after migration');
      } else {
        debugPrint('✓ No inconsistencies found');
      }

      // Show migration summary (with null safety)
      final summaryResults = await db.rawQuery('''
        SELECT 
          COALESCE(status, 'NULL') as status, 
          COUNT(*) as count 
        FROM schedules 
        GROUP BY status 
        ORDER BY count DESC
      ''');

      debugPrint('Migration summary by status:');
      for (final row in summaryResults) {
        final status = row['status'] as String? ?? 'NULL';
        final count = (row['count'] as int?) ?? 0;
        debugPrint('  $status: $count schedules');
      }

      // Check attended vs status alignment (with null safety)
      final attendedResults = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN attended = 1 THEN 1 ELSE 0 END) as attended_count,
          SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as completed_count
        FROM schedules
      ''', [ScheduleStatus.completed]);

      final attendedCount =
          (attendedResults.first['attended_count'] as int?) ?? 0;
      final completedCount =
          (attendedResults.first['completed_count'] as int?) ?? 0;

      debugPrint('Attended lessons: $attendedCount');
      debugPrint('Completed status: $completedCount');

      if (attendedCount == completedCount) {
        debugPrint('✓ Attended and completed counts match');
      } else {
        debugPrint(
            'WARNING: Attended ($attendedCount) and completed ($completedCount) counts do not match');
      }
    } catch (e) {
      debugPrint('Error validating migration: $e');
    }
  }

  /// Get migration statistics before running
  Future<Map<String, dynamic>> getMigrationStats() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Check if schedules table exists
      final hasSchedules = await _checkSchedulesTableExists();
      if (!hasSchedules) {
        return {
          'statusDistribution': <String, int>{},
          'inconsistentRecords': 0,
          'shouldBeMissed': 0,
          'hasSchedulesTable': false,
        };
      }

      // Get current status distribution (with null safety)
      final statusResults = await db.rawQuery('''
        SELECT 
          COALESCE(status, 'NULL') as status, 
          COUNT(*) as count 
        FROM schedules 
        GROUP BY status
      ''');

      // Get inconsistent records (with null safety)
      final inconsistentResults = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM schedules 
        WHERE ((attended = 1 OR attended IS NULL) AND (status != ? OR status IS NULL))
           OR ((status = ? OR status IS NULL) AND (attended = 0 OR attended IS NULL))
      ''', [ScheduleStatus.completed, ScheduleStatus.completed]);

      // Get lessons that should be missed (with null safety)
      final now = DateTime.now().toIso8601String();
      final shouldBeMissedResults = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM schedules 
        WHERE datetime(end) < datetime(?) 
          AND (attended = 0 OR attended IS NULL)
          AND (status != ? OR status IS NULL)
          AND (status != ? OR status IS NULL)
      ''', [now, ScheduleStatus.cancelled, ScheduleStatus.missed]);

      return {
        'statusDistribution': Map.fromEntries(statusResults.map((row) =>
            MapEntry(row['status'] as String? ?? 'NULL',
                (row['count'] as int?) ?? 0))),
        'inconsistentRecords':
            (inconsistentResults.first['count'] as int?) ?? 0,
        'shouldBeMissed': (shouldBeMissedResults.first['count'] as int?) ?? 0,
        'hasSchedulesTable': true,
      };
    } catch (e) {
      debugPrint('Error getting migration stats: $e');
      return {
        'statusDistribution': <String, int>{},
        'inconsistentRecords': 0,
        'shouldBeMissed': 0,
        'hasSchedulesTable': false,
        'error': e.toString(),
      };
    }
  }
}
