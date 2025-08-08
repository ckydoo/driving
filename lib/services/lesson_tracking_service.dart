// lib/services/lesson_tracking_service.dart

import 'package:driving/models/schedule.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/constant/schedule_status.dart';

/// Centralized service for lesson tracking and deduction logic
/// 
/// This service ensures consistent lesson counting across the entire application.
/// Key principle: Only attended/completed lessons are deducted from billing.
class LessonTrackingService {
  static const LessonTrackingService _instance = LessonTrackingService._internal();
  factory LessonTrackingService() => _instance;
  const LessonTrackingService._internal();

  /// Get lessons used (attended/completed only) for a student in a specific course
  /// 
  /// This is the central method that all other lesson counting should use.
  /// Only counts lessons that are both attended=true AND status=completed.
  int getUsedLessons(List<Schedule> schedules, int studentId, int courseId) {
    return schedules
        .where((schedule) =>
            schedule.studentId == studentId &&
            schedule.courseId == courseId &&
            schedule.attended &&
            schedule.status == ScheduleStatus.completed)
        .fold<int>(0, (sum, schedule) => sum + schedule.lessonsDeducted);
  }

  /// Get remaining lessons for a student in a specific course
  int getRemainingLessons(List<Schedule> schedules, Invoice? invoice, int studentId, int courseId) {
    if (invoice == null) return 0;
    
    final usedLessons = getUsedLessons(schedules, studentId, courseId);
    return (invoice.lessons - usedLessons).clamp(0, invoice.lessons);
  }

  /// Calculate progress percentage based on attended lessons only
  double calculateLessonProgress(List<Schedule> schedules, Invoice? invoice, int studentId, int courseId) {
    if (invoice == null || invoice.lessons == 0) return 0.0;

    final attendedLessons = getUsedLessons(schedules, studentId, courseId);
    final progress = (attendedLessons / invoice.lessons) * 100;
    return progress.clamp(0.0, 100.0);
  }

  /// Check if marking a lesson as attended would exceed billed lessons
  bool wouldExceedBilledLessons(List<Schedule> schedules, Invoice? invoice, Schedule scheduleToAttend) {
    if (invoice == null) return false;

    final currentUsedLessons = getUsedLessons(schedules, scheduleToAttend.studentId, scheduleToAttend.courseId);
    final potentialNewUsage = currentUsedLessons + scheduleToAttend.lessonsDeducted;
    
    return potentialNewUsage > invoice.lessons;
  }

  /// Check if enough lessons remain to create a new schedule
  bool canCreateSchedule(List<Schedule> schedules, Invoice? invoice, int studentId, int courseId, int lessonsRequired) {
    if (invoice == null) return false;
    
    final remainingLessons = getRemainingLessons(schedules, invoice, studentId, courseId);
    return lessonsRequired <= remainingLessons;
  }

  /// Get detailed lesson usage statistics for a student's course
  LessonUsageStats getLessonUsageStats(List<Schedule> schedules, Invoice? invoice, int studentId, int courseId) {
    if (invoice == null) {
      return LessonUsageStats(
        totalLessons: 0,
        usedLessons: 0,
        remainingLessons: 0,
        attendedLessons: 0,
        scheduledButNotAttendedLessons: 0,
        progressPercentage: 0.0,
      );
    }

    final attendedLessons = getUsedLessons(schedules, studentId, courseId);
    final scheduledButNotAttended = schedules
        .where((s) =>
            s.studentId == studentId &&
            s.courseId == courseId &&
            !s.attended &&
            s.status != ScheduleStatus.cancelled)
        .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

    return LessonUsageStats(
      totalLessons: invoice.lessons,
      usedLessons: attendedLessons,
      remainingLessons: getRemainingLessons(schedules, invoice, studentId, courseId),
      attendedLessons: attendedLessons,
      scheduledButNotAttendedLessons: scheduledButNotAttended,
      progressPercentage: calculateLessonProgress(schedules, invoice, studentId, courseId),
    );
  }

  /// Validate that a schedule has consistent status and attendance flags
  bool isScheduleStatusConsistent(Schedule schedule) {
    // If attended, must be completed
    if (schedule.attended && schedule.status != ScheduleStatus.completed) {
      return false;
    }

    // If not attended and completed, it's inconsistent
    if (!schedule.attended && schedule.status == ScheduleStatus.completed) {
      return false;
    }

    // Cancelled schedules should not be attended
    if (schedule.status == ScheduleStatus.cancelled && schedule.attended) {
      return false;
    }

    return true;
  }

  /// Get corrected schedule with consistent status and attendance
  Schedule getScheduleWithConsistentStatus(Schedule schedule) {
    if (isScheduleStatusConsistent(schedule)) {
      return schedule;
    }

    // Apply correction rules
    if (schedule.attended) {
      // If attended, must be completed
      return schedule.copyWith(status: ScheduleStatus.completed);
    } else if (schedule.status == ScheduleStatus.completed) {
      // If marked completed but not attended, determine correct status
      final now = DateTime.now();
      if (schedule.status == ScheduleStatus.cancelled) {
        return schedule.copyWith(attended: false);
      } else if (now.isAfter(schedule.end)) {
        return schedule.copyWith(status: ScheduleStatus.missed);
      } else {
        return schedule.copyWith(status: ScheduleStatus.scheduled);
      }
    }

    return schedule;
  }

  /// Find all schedules with inconsistent status/attendance
  List<Schedule> findInconsistentSchedules(List<Schedule> schedules) {
    return schedules.where((schedule) => !isScheduleStatusConsistent(schedule)).toList();
  }
}

/// Data class for lesson usage statistics
class LessonUsageStats {
  final int totalLessons;
  final int usedLessons;
  final int remainingLessons;
  final int attendedLessons;
  final int scheduledButNotAttendedLessons;
  final double progressPercentage;

  const LessonUsageStats({
    required this.totalLessons,
    required this.usedLessons,
    required this.remainingLessons,
    required this.attendedLessons,
    required this.scheduledButNotAttendedLessons,
    required this.progressPercentage,
  });

  @override
  String toString() {
    return 'LessonUsageStats(total: $totalLessons, used: $usedLessons, remaining: $remainingLessons, attended: $attendedLessons, scheduled: $scheduledButNotAttendedLessons, progress: ${progressPercentage.toStringAsFixed(1)}%)';
  }
}