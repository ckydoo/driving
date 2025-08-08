// lib/services/lesson_tracking_validator.dart

import 'package:driving/services/lesson_tracking_service.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/constant/schedule_status.dart';

/// Validation service to ensure lesson tracking consistency across the system
class LessonTrackingValidator {
  static const LessonTrackingValidator _instance = LessonTrackingValidator._internal();
  factory LessonTrackingValidator() => _instance;
  const LessonTrackingValidator._internal();

  final LessonTrackingService _lessonTracker = const LessonTrackingService();

  /// Comprehensive validation of the lesson tracking system
  ValidationResult validateSystem({
    required List<Schedule> schedules,
    required List<Invoice> invoices,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final stats = ValidationStats();

    // 1. Validate status-attendance consistency
    _validateStatusAttendanceConsistency(schedules, errors, warnings, stats);

    // 2. Validate billing accuracy
    _validateBillingAccuracy(schedules, invoices, errors, warnings, stats);

    // 3. Validate lesson deduction logic
    _validateLessonDeductionLogic(schedules, invoices, errors, warnings, stats);

    // 4. Validate progress calculations
    _validateProgressCalculations(schedules, invoices, errors, warnings, stats);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      stats: stats,
    );
  }

  /// Validate that all schedules have consistent status and attendance flags
  void _validateStatusAttendanceConsistency(
    List<Schedule> schedules,
    List<String> errors,
    List<String> warnings,
    ValidationStats stats,
  ) {
    final inconsistentSchedules = _lessonTracker.findInconsistentSchedules(schedules);
    
    stats.totalSchedules = schedules.length;
    stats.inconsistentSchedules = inconsistentSchedules.length;

    for (final schedule in inconsistentSchedules) {
      if (schedule.attended && schedule.status != ScheduleStatus.completed) {
        errors.add(
          'Schedule ${schedule.id}: Marked as attended but status is ${schedule.status}, should be ${ScheduleStatus.completed}'
        );
      }

      if (!schedule.attended && schedule.status == ScheduleStatus.completed) {
        errors.add(
          'Schedule ${schedule.id}: Status is ${ScheduleStatus.completed} but not marked as attended'
        );
      }

      if (schedule.status == ScheduleStatus.cancelled && schedule.attended) {
        errors.add(
          'Schedule ${schedule.id}: Status is ${ScheduleStatus.cancelled} but marked as attended'
        );
      }
    }

    if (inconsistentSchedules.isNotEmpty) {
      warnings.add(
        '${inconsistentSchedules.length} schedules have inconsistent status/attendance flags'
      );
    }
  }

  /// Validate that billing calculations are accurate
  void _validateBillingAccuracy(
    List<Schedule> schedules,
    List<Invoice> invoices,
    List<String> errors,
    List<String> warnings,
    ValidationStats stats,
  ) {
    stats.totalInvoices = invoices.length;

    for (final invoice in invoices) {
      final studentSchedules = schedules.where(
        (s) => s.studentId == invoice.studentId && s.courseId == invoice.courseId
      ).toList();

      // Only attended/completed lessons should count
      final attendedLessons = _lessonTracker.getUsedLessons(
        schedules, 
        invoice.studentId, 
        invoice.courseId
      );

      final scheduledButNotAttended = studentSchedules
          .where((s) => !s.attended && s.status != ScheduleStatus.cancelled)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      // Check for over-usage
      if (attendedLessons > invoice.lessons) {
        errors.add(
          'Invoice ${invoice.id}: Student ${invoice.studentId} has used $attendedLessons lessons but only paid for ${invoice.lessons}'
        );
        stats.overdraftInvoices++;
      }

      // Check for potential scheduling conflicts
      if (attendedLessons + scheduledButNotAttended > invoice.lessons) {
        warnings.add(
          'Invoice ${invoice.id}: Student ${invoice.studentId} has $scheduledButNotAttended scheduled lessons that would exceed their paid lessons ($attendedLessons used + $scheduledButNotAttended scheduled > ${invoice.lessons} paid)'
        );
      }
    }
  }

  /// Validate lesson deduction logic consistency
  void _validateLessonDeductionLogic(
    List<Schedule> schedules,
    List<Invoice> invoices,
    List<String> errors,
    List<String> warnings,
    ValidationStats stats,
  ) {
    // Group schedules by student-course combinations
    final studentCourseGroups = <String, List<Schedule>>{};
    for (final schedule in schedules) {
      final key = '${schedule.studentId}-${schedule.courseId}';
      studentCourseGroups[key] ??= [];
      studentCourseGroups[key]!.add(schedule);
    }

    for (final entry in studentCourseGroups.entries) {
      final scheduleList = entry.value;
      final studentId = scheduleList.first.studentId;
      final courseId = scheduleList.first.courseId;

      final invoice = invoices.firstWhere(
        (inv) => inv.studentId == studentId && inv.courseId == courseId,
        orElse: () => Invoice(
          studentId: studentId,
          courseId: courseId,
          lessons: 0,
          pricePerLesson: 0,
          createdAt: DateTime.now(),
          status: 'test',
          invoiceNumber: 'test',
          amountPaid: 0,
          totalAmount: 0,
        ),
      );

      // Validate that only attended lessons are counted
      final attendedCount = scheduleList.where((s) => s.attended).length;
      final trackedUsed = _lessonTracker.getUsedLessons(schedules, studentId, courseId);
      
      final attendedLessonDeductions = scheduleList
          .where((s) => s.attended)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      if (trackedUsed != attendedLessonDeductions) {
        errors.add(
          'Lesson tracking inconsistency for student $studentId course $courseId: Tracked $trackedUsed but calculated $attendedLessonDeductions from attended lessons'
        );
      }
    }
  }

  /// Validate progress calculations
  void _validateProgressCalculations(
    List<Schedule> schedules,
    List<Invoice> invoices,
    List<String> errors,
    List<String> warnings,
    ValidationStats stats,
  ) {
    for (final invoice in invoices) {
      final progress = _lessonTracker.calculateLessonProgress(
        schedules, 
        invoice, 
        invoice.studentId, 
        invoice.courseId
      );

      if (progress < 0 || progress > 100) {
        errors.add(
          'Invalid progress calculation for invoice ${invoice.id}: $progress% (should be 0-100%)'
        );
      }

      final usedLessons = _lessonTracker.getUsedLessons(
        schedules, 
        invoice.studentId, 
        invoice.courseId
      );

      final expectedProgress = invoice.lessons > 0 ? (usedLessons / invoice.lessons) * 100 : 0;
      if ((progress - expectedProgress).abs() > 0.1) {
        errors.add(
          'Progress calculation mismatch for invoice ${invoice.id}: calculated $progress% but expected $expectedProgress%'
        );
      }
    }
  }

  /// Quick validation for a single schedule
  ScheduleValidationResult validateSchedule(Schedule schedule) {
    final issues = <String>[];

    if (!_lessonTracker.isScheduleStatusConsistent(schedule)) {
      issues.add('Status and attendance flags are inconsistent');
    }

    if (schedule.attended && schedule.status != ScheduleStatus.completed) {
      issues.add('Attended lesson should have status = completed');
    }

    if (schedule.status == ScheduleStatus.cancelled && schedule.attended) {
      issues.add('Cancelled lesson should not be marked as attended');
    }

    return ScheduleValidationResult(
      schedule: schedule,
      isValid: issues.isEmpty,
      issues: issues,
    );
  }

  /// Generate a system health report
  String generateHealthReport(ValidationResult result) {
    final buffer = StringBuffer();
    
    buffer.writeln('=== LESSON TRACKING SYSTEM HEALTH REPORT ===');
    buffer.writeln();
    
    buffer.writeln('Overall Status: ${result.isValid ? "HEALTHY" : "ISSUES FOUND"}');
    buffer.writeln();
    
    buffer.writeln('Statistics:');
    buffer.writeln('- Total Schedules: ${result.stats.totalSchedules}');
    buffer.writeln('- Inconsistent Schedules: ${result.stats.inconsistentSchedules}');
    buffer.writeln('- Total Invoices: ${result.stats.totalInvoices}');
    buffer.writeln('- Overdraft Invoices: ${result.stats.overdraftInvoices}');
    buffer.writeln();

    if (result.errors.isNotEmpty) {
      buffer.writeln('ERRORS (${result.errors.length}):');
      for (int i = 0; i < result.errors.length; i++) {
        buffer.writeln('${i + 1}. ${result.errors[i]}');
      }
      buffer.writeln();
    }

    if (result.warnings.isNotEmpty) {
      buffer.writeln('WARNINGS (${result.warnings.length}):');
      for (int i = 0; i < result.warnings.length; i++) {
        buffer.writeln('${i + 1}. ${result.warnings[i]}');
      }
      buffer.writeln();
    }

    if (result.isValid) {
      buffer.writeln('✅ All validations passed. System is operating correctly.');
    } else {
      buffer.writeln('❌ Issues found. Please review and fix the errors above.');
    }

    return buffer.toString();
  }
}

/// Result of system validation
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final ValidationStats stats;

  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.stats,
  });
}

/// Validation statistics
class ValidationStats {
  int totalSchedules = 0;
  int inconsistentSchedules = 0;
  int totalInvoices = 0;
  int overdraftInvoices = 0;
}

/// Result of single schedule validation
class ScheduleValidationResult {
  final Schedule schedule;
  final bool isValid;
  final List<String> issues;

  const ScheduleValidationResult({
    required this.schedule,
    required this.isValid,
    required this.issues,
  });
}