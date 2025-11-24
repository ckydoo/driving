import 'package:driving/constant/schedule_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/billing_controller.dart';
import '../models/schedule.dart';
import '../services/database_helper.dart';
import '../services/lesson_counting_service.dart';

/// Service for checking and fixing data consistency issues
class ConsistencyCheckerService extends GetxService {
  static ConsistencyCheckerService get instance =>
      Get.find<ConsistencyCheckerService>();

  final RxBool isRunning = false.obs;
  final RxString currentOperation = ''.obs;

  /// Run comprehensive consistency check on all data
  Future<Map<String, dynamic>> runFullConsistencyCheck() async {
    try {
      isRunning(true);
      currentOperation('Starting consistency check...');

      final results = <String, dynamic>{};

      // Check 1: Status/Attendance Synchronization
      currentOperation('Checking attendance/status sync...');
      results['attendance_status_mismatches'] =
          await _checkAttendanceStatusSync();

      // Check 2: Lesson Count Validation
      currentOperation('Validating lesson counts...');
      results['lesson_count_issues'] = await _checkLessonCounts();

      // Check 3: Billing Record Consistency
      currentOperation('Checking billing records...');
      results['billing_record_issues'] = await _checkBillingRecords();

      // Check 4: Orphaned Records
      currentOperation('Checking for orphaned records...');
      results['orphaned_records'] = await _checkOrphanedRecords();

      // Check 5: Duplicate Schedules
      currentOperation('Checking for duplicate schedules...');
      results['duplicate_schedules'] = await _checkDuplicateSchedules();

      currentOperation('Consistency check completed');

      return results;
    } catch (e) {
      print('Error in consistency check: $e');
      rethrow;
    } finally {
      isRunning(false);
      currentOperation('');
    }
  }

  /// Check for attendance/status synchronization issues
  Future<List<Map<String, dynamic>>> _checkAttendanceStatusSync() async {
    final db = await DatabaseHelper.instance.database;

    // Find records where attended=1 but status != 'Completed'
    // OR status='Completed' but attended=0
    final mismatched = await db.rawQuery('''
      SELECT id, studentId, courseId, status, attended, start, end, notes
      FROM schedules 
      WHERE (attended = 1 AND status != ?) 
         OR (status = ? AND attended = 0)
      ORDER BY start DESC
    ''', [ScheduleStatus.completed, ScheduleStatus.completed]);

    return mismatched;
  }

  /// Check for lesson count issues (over-allocation, etc.)
  Future<List<Map<String, dynamic>>> _checkLessonCounts() async {
    final scheduleController = Get.find<ScheduleController>();
    final billingController = Get.find<BillingController>();
    final issues = <Map<String, dynamic>>[];

    // Group schedules by student and course
    final grouped = <String, List<Schedule>>{};
    for (final schedule in scheduleController.schedules) {
      final key = '${schedule.studentId}_${schedule.courseId}';
      grouped[key] ??= [];
      grouped[key]!.add(schedule);
    }

    // Check each group for over-allocation
    for (final entry in grouped.entries) {
      final parts = entry.key.split('_');
      final studentId = int.parse(parts[0]);
      final courseId = int.parse(parts[1]);

      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) => inv.studentId == studentId && inv.courseId == courseId,
      );

      if (invoice != null) {
        final usedLessons =
            LessonCountingService.instance.getUsedLessons(studentId, courseId);

        if (usedLessons > invoice.lessons) {
          issues.add({
            'type': 'over_allocation',
            'studentId': studentId,
            'courseId': courseId,
            'totalLessons': invoice.lessons,
            'usedLessons': usedLessons,
            'excess': usedLessons - invoice.lessons,
            'schedules': entry.value.length,
          });
        }

        // Check for negative remaining lessons
        final remaining = LessonCountingService.instance
            .getRemainingLessons(studentId, courseId);
        if (remaining < 0) {
          issues.add({
            'type': 'negative_remaining',
            'studentId': studentId,
            'courseId': courseId,
            'totalLessons': invoice.lessons,
            'usedLessons': usedLessons,
            'remaining': remaining,
          });
        }
      } else {
        // Schedules without corresponding invoice
        issues.add({
          'type': 'missing_invoice',
          'studentId': studentId,
          'courseId': courseId,
          'scheduleCount': entry.value.length,
          'totalLessonsUsed':
              entry.value.fold<int>(0, (sum, s) => sum + s.lessonsDeducted),
        });
      }
    }

    return issues;
  }

  /// Check for billing record consistency
  Future<List<Map<String, dynamic>>> _checkBillingRecords() async {
    final db = await DatabaseHelper.instance.database;
    final issues = <Map<String, dynamic>>[];

    // Check for billing records without corresponding schedules
    final orphanedBillingRecords = await db.rawQuery('''
      SELECT br.id, br.invoiceId, br.scheduleId, br.status
      FROM billing_records br
      LEFT JOIN schedules s ON br.scheduleId = s.id
      WHERE s.id IS NULL
    ''');

    for (final record in orphanedBillingRecords) {
      issues.add({
        'type': 'orphaned_billing_record',
        'billingRecordId': record['id'],
        'invoiceId': record['invoiceId'],
        'scheduleId': record['scheduleId'],
        'status': record['status'],
      });
    }

    // Check for schedules without billing records (if auto-create is enabled)
    final schedulesWithoutBilling = await db.rawQuery('''
      SELECT s.id, s.studentId, s.courseId, s.status, s.attended
      FROM schedules s
      LEFT JOIN billing_records br ON s.id = br.scheduleId
      WHERE br.id IS NULL AND s.status != 'Cancelled'
    ''');

    for (final schedule in schedulesWithoutBilling) {
      issues.add({
        'type': 'missing_billing_record',
        'scheduleId': schedule['id'],
        'studentId': schedule['studentId'],
        'courseId': schedule['courseId'],
        'status': schedule['status'],
        'attended': schedule['attended'],
      });
    }

    return issues;
  }

  /// Check for orphaned records (schedules without students, courses, etc.)
  Future<List<Map<String, dynamic>>> _checkOrphanedRecords() async {
    final db = await DatabaseHelper.instance.database;
    final issues = <Map<String, dynamic>>[];

    // Schedules with non-existent students
    final orphanedByStudent = await db.rawQuery('''
      SELECT s.id, s.studentId, s.courseId
      FROM schedules s
      LEFT JOIN users u ON s.studentId = u.id
      WHERE u.id IS NULL
    ''');

    for (final record in orphanedByStudent) {
      issues.add({
        'type': 'orphaned_by_student',
        'scheduleId': record['id'],
        'studentId': record['studentId'],
        'courseId': record['courseId'],
      });
    }

    // Schedules with non-existent courses
    final orphanedByCourse = await db.rawQuery('''
      SELECT s.id, s.studentId, s.courseId
      FROM schedules s
      LEFT JOIN courses c ON s.courseId = c.id
      WHERE c.id IS NULL
    ''');

    for (final record in orphanedByCourse) {
      issues.add({
        'type': 'orphaned_by_course',
        'scheduleId': record['id'],
        'studentId': record['studentId'],
        'courseId': record['courseId'],
      });
    }

    return issues;
  }

  /// Check for duplicate schedules
  Future<List<Map<String, dynamic>>> _checkDuplicateSchedules() async {
    final db = await DatabaseHelper.instance.database;

    // Find schedules with same student, instructor, start time
    final duplicates = await db.rawQuery('''
      SELECT studentId, instructorId, start, COUNT(*) as count,
             GROUP_CONCAT(id) as ids
      FROM schedules
      GROUP BY studentId, instructorId, start
      HAVING COUNT(*) > 1
    ''');

    return duplicates
        .map((d) => {
              'studentId': d['studentId'],
              'instructorId': d['instructorId'],
              'start': d['start'],
              'count': d['count'],
              'scheduleIds': d['ids'].toString().split(','),
            })
        .toList();
  }

  /// Fix all detectable inconsistencies
  Future<Map<String, int>> fixAllInconsistencies() async {
    try {
      isRunning(true);
      final fixCounts = <String, int>{};

      // Run consistency check first
      final report = await runFullConsistencyCheck();
      currentOperation('Fixing attendance/status mismatches...');
      final attendanceFixed = await _fixAttendanceStatusMismatches(
          List<Map<String, dynamic>>.from(
              report['attendance_status_mismatches']));
      fixCounts['attendance_status_fixed'] = attendanceFixed;

      // Clean up orphaned billing records
      currentOperation('Cleaning orphaned billing records...');
      final billingCleaned = await _cleanOrphanedBillingRecords(
          List<Map<String, dynamic>>.from(report['billing_record_issues']));
      fixCounts['billing_records_cleaned'] = billingCleaned;

      // Remove duplicate schedules (keeping the first one)
      currentOperation('Removing duplicate schedules...');
      final duplicatesRemoved = await _removeDuplicateSchedules(
          List<Map<String, dynamic>>.from(report['duplicate_schedules']));
      fixCounts['duplicates_removed'] = duplicatesRemoved;

      // Refresh controllers to reflect changes
      await _refreshControllers();

      currentOperation('All fixes completed');

      // Show summary
      _showFixSummary(fixCounts, report);

      return fixCounts;
    } catch (e) {
      print('Error fixing inconsistencies: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Fix Error',
        'Some fixes failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    } finally {
      isRunning(false);
      currentOperation('');
    }
  }

  /// Fix attendance and status mismatches
  Future<int> _fixAttendanceStatusMismatches(
      List<Map<String, dynamic>> mismatches) async {
    final db = await DatabaseHelper.instance.database;
    int fixCount = 0;

    for (final mismatch in mismatches) {
      final id = mismatch['id'];
      final attended = mismatch['attended'] == 1;
      final currentStatus = mismatch['status'];

      // Determine correct status based on attendance and timing
      String correctStatus;
      if (attended) {
        correctStatus = ScheduleStatus.completed;
      } else {
        final endTime = DateTime.parse(mismatch['end']);
        correctStatus = endTime.isBefore(DateTime.now())
            ? ScheduleStatus.missed
            : ScheduleStatus.scheduled;
      }

      if (currentStatus != correctStatus) {
        await db.update(
          'schedules',
          {'status': correctStatus},
          where: 'id = ?',
          whereArgs: [id],
        );

        print(
            'Fixed schedule $id: $currentStatus -> $correctStatus (attended: $attended)');
        fixCount++;
      }
    }

    return fixCount;
  }

  /// Clean up orphaned billing records
  Future<int> _cleanOrphanedBillingRecords(
      List<Map<String, dynamic>> issues) async {
    final db = await DatabaseHelper.instance.database;
    int cleanCount = 0;

    for (final issue in issues) {
      if (issue['type'] == 'orphaned_billing_record') {
        await db.delete(
          'billing_records',
          where: 'id = ?',
          whereArgs: [issue['billingRecordId']],
        );

        print('Removed orphaned billing record: ${issue['billingRecordId']}');
        cleanCount++;
      }
    }

    return cleanCount;
  }

  /// Remove duplicate schedules (keeps the first occurrence)
  Future<int> _removeDuplicateSchedules(
      List<Map<String, dynamic>> duplicates) async {
    final db = await DatabaseHelper.instance.database;
    int removeCount = 0;

    for (final duplicate in duplicates) {
      final scheduleIds = List<String>.from(duplicate['scheduleIds']);

      // Keep the first ID, remove the rest
      for (int i = 1; i < scheduleIds.length; i++) {
        await db.delete(
          'schedules',
          where: 'id = ?',
          whereArgs: [int.parse(scheduleIds[i])],
        );

        print('Removed duplicate schedule: ${scheduleIds[i]}');
        removeCount++;
      }
    }

    return removeCount;
  }

  /// Refresh all controllers after database changes
  Future<void> _refreshControllers() async {
    try {
      final scheduleController = Get.find<ScheduleController>();
      final billingController = Get.find<BillingController>();

      await scheduleController.fetchSchedules();
      await billingController.fetchBillingData();
    } catch (e) {
      print('Error refreshing controllers: $e');
    }
  }

  /// Show summary of fixes applied
  void _showFixSummary(
      Map<String, int> fixCounts, Map<String, dynamic> report) {
    final totalFixed =
        fixCounts.values.fold<int>(0, (sum, count) => sum + count);
    final lessonIssues =
        List<Map<String, dynamic>>.from(report['lesson_count_issues']);
    final orphanedRecords =
        List<Map<String, dynamic>>.from(report['orphaned_records']);

    String message = 'Consistency fixes completed:\n';
    message +=
        '✓ ${fixCounts['attendance_status_fixed']} attendance/status issues fixed\n';
    message +=
        '✓ ${fixCounts['billing_records_cleaned']} orphaned billing records removed\n';
    message +=
        '✓ ${fixCounts['duplicates_removed']} duplicate schedules removed\n';

    if (lessonIssues.isNotEmpty) {
      message +=
          '\n⚠️ ${lessonIssues.length} lesson count issues need manual review';
    }

    if (orphanedRecords.isNotEmpty) {
      message +=
          '\n⚠️ ${orphanedRecords.length} orphaned records need manual review';
    }

    Get.snackbar(
      snackPosition: SnackPosition.BOTTOM,
      'Consistency Check Complete',
      message,
      backgroundColor: totalFixed > 0 ? Colors.green : Colors.blue,
      colorText: Colors.white,
      duration: Duration(seconds: 7),
      maxWidth: 400,
    );
  }

  /// Generate detailed report for manual review
  String generateDetailedReport(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    buffer.writeln('SCHEDULING & BILLING CONSISTENCY REPORT');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('=' * 50);

    // Attendance/Status Issues
    final attendanceIssues = List<Map<String, dynamic>>.from(
        results['attendance_status_mismatches']);
    buffer
        .writeln('\nATTENDANCE/STATUS MISMATCHES: ${attendanceIssues.length}');
    for (final issue in attendanceIssues) {
      buffer.writeln(
          '  Schedule ${issue['id']}: attended=${issue['attended']}, status=${issue['status']}');
    }

    // Lesson Count Issues
    final lessonIssues =
        List<Map<String, dynamic>>.from(results['lesson_count_issues']);
    buffer.writeln('\nLESSON COUNT ISSUES: ${lessonIssues.length}');
    for (final issue in lessonIssues) {
      buffer.writeln(
          '  ${issue['type']}: Student ${issue['studentId']}, Course ${issue['courseId']}');
      if (issue['type'] == 'over_allocation') {
        buffer.writeln(
            '    Total: ${issue['totalLessons']}, Used: ${issue['usedLessons']}, Excess: ${issue['excess']}');
      }
    }

    // Billing Issues
    final billingIssues =
        List<Map<String, dynamic>>.from(results['billing_record_issues']);
    buffer.writeln('\nBILLING RECORD ISSUES: ${billingIssues.length}');
    for (final issue in billingIssues) {
      buffer.writeln('  ${issue['type']}: ${issue}');
    }

    // Orphaned Records
    final orphanedIssues =
        List<Map<String, dynamic>>.from(results['orphaned_records']);
    buffer.writeln('\nORPHANED RECORDS: ${orphanedIssues.length}');
    for (final issue in orphanedIssues) {
      buffer.writeln('  ${issue['type']}: Schedule ${issue['scheduleId']}');
    }

    // Duplicates
    final duplicateIssues =
        List<Map<String, dynamic>>.from(results['duplicate_schedules']);
    buffer.writeln('\nDUPLICATE SCHEDULES: ${duplicateIssues.length}');
    for (final issue in duplicateIssues) {
      buffer.writeln(
          '  Student ${issue['studentId']}, ${issue['start']}: ${issue['count']} duplicates');
    }

    return buffer.toString();
  }
}
