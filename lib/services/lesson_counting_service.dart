import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../controllers/billing_controller.dart';
import '../controllers/schedule_controller.dart';
import '../models/schedule.dart';

/// Centralized service for all lesson counting logic
/// This ensures a single source of truth for lesson calculations
class LessonCountingService extends GetxService {
  static LessonCountingService get instance =>
      Get.find<LessonCountingService>();

  late final SettingsController _settings;
  late final BillingController _billing;
  late final ScheduleController _schedule;

  @override
  void onInit() {
    super.onInit();
    // Initialize controllers
    _settings = Get.find<SettingsController>();
    _billing = Get.find<BillingController>();
    _schedule = Get.find<ScheduleController>();
  }

  /// SINGLE SOURCE OF TRUTH for counting used lessons
  /// This method respects the countScheduledLessons setting
  int getUsedLessons(int studentId, int courseId) {
    try {
      if (_settings.countScheduledLessons.value) {
        // Count both scheduled and attended lessons (exclude cancelled)
        return _schedule.schedules
            .where((s) =>
                s.studentId == studentId &&
                s.courseId == courseId &&
                s.status.toLowerCase() != 'cancelled')
            .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);
      } else {
        // Only count attended lessons
        return _schedule.schedules
            .where((s) =>
                s.studentId == studentId &&
                s.courseId == courseId &&
                s.attended)
            .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);
      }
    } catch (e) {
      print('Error calculating used lessons: $e');
      return 0;
    }
  }

  /// Get remaining lessons for a student's course
  int getRemainingLessons(int studentId, int courseId) {
    try {
      final invoice = _billing.invoices.firstWhereOrNull(
        (inv) => inv.studentId == studentId && inv.courseId == courseId,
      );

      if (invoice == null) return 0;

      final used = getUsedLessons(studentId, courseId);
      return (invoice.lessons - used).clamp(0, invoice.lessons);
    } catch (e) {
      print('Error calculating remaining lessons: $e');
      return 0;
    }
  }

  /// Check if a student can schedule additional lessons
  bool canScheduleLessons(int studentId, int courseId, int lessonsToDeduct) {
    try {
      final remaining = getRemainingLessons(studentId, courseId);
      return lessonsToDeduct <= remaining;
    } catch (e) {
      print('Error checking lesson availability: $e');
      return false;
    }
  }

  /// Get detailed lesson usage statistics
  Map<String, int> getLessonUsageStats(int studentId, int courseId) {
    try {
      final invoice = _billing.invoices.firstWhereOrNull(
        (inv) => inv.studentId == studentId && inv.courseId == courseId,
      );

      if (invoice == null) {
        return {
          'total': 0,
          'used': 0,
          'remaining': 0,
          'attended': 0,
          'scheduled': 0,
        };
      }

      final used = getUsedLessons(studentId, courseId);

      final attendedLessons = _schedule.schedules
          .where((s) =>
              s.studentId == studentId && s.courseId == courseId && s.attended)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      final scheduledLessons = _schedule.schedules
          .where((s) =>
              s.studentId == studentId &&
              s.courseId == courseId &&
              !s.attended &&
              s.status.toLowerCase() != 'cancelled')
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      return {
        'total': invoice.lessons,
        'used': used,
        'remaining': (invoice.lessons - used).clamp(0, invoice.lessons),
        'attended': attendedLessons,
        'scheduled': scheduledLessons,
      };
    } catch (e) {
      print('Error getting lesson usage stats: $e');
      return {
        'total': 0,
        'used': 0,
        'remaining': 0,
        'attended': 0,
        'scheduled': 0,
      };
    }
  }

  /// Validate that a schedule change won't exceed lesson limits
  bool validateScheduleChange(Schedule schedule,
      {bool willBeAttended = false}) {
    try {
      // If marking as attended, check if we have enough lessons
      if (willBeAttended && !schedule.attended) {
        return canScheduleLessons(
            schedule.studentId, schedule.courseId, schedule.lessonsDeducted);
      }

      // If unmarking attendance, we're freeing up lessons (always valid)
      if (!willBeAttended && schedule.attended) {
        return true;
      }

      // For other changes, check current state
      return canScheduleLessons(schedule.studentId, schedule.courseId, 0);
    } catch (e) {
      print('Error validating schedule change: $e');
      return false;
    }
  }

  /// Get lesson count for a specific schedule based on current settings
  int getEffectiveLessonCount(Schedule schedule) {
    if (_settings.countScheduledLessons.value) {
      // Count if not cancelled
      return schedule.status.toLowerCase() != 'cancelled'
          ? schedule.lessonsDeducted
          : 0;
    } else {
      // Count only if attended
      return schedule.attended ? schedule.lessonsDeducted : 0;
    }
  }

  /// Calculate lessons needed for a time duration
  int calculateLessonsFromDuration(Duration duration) {
    final defaultLessonDuration = _settings.defaultLessonDuration.value;
    final hours = duration.inMinutes / 60.0;
    return (hours / defaultLessonDuration)
        .round()
        .clamp(1, 10); // Min 1, Max 10 lessons
  }

  /// Check if student has low lesson balance
  bool hasLowLessonBalance(int studentId, int courseId) {
    final remaining = getRemainingLessons(studentId, courseId);
    return remaining <= _settings.lowLessonThreshold.value && remaining > 0;
  }

  /// Get warning message for lesson status
  String? getLessonWarningMessage(int studentId, int courseId) {
    final remaining = getRemainingLessons(studentId, courseId);

    if (remaining <= 0) {
      return 'No lessons remaining. Cannot schedule more lessons.';
    } else if (remaining <= _settings.lowLessonThreshold.value) {
      return 'Low lesson balance: $remaining lessons remaining.';
    }

    return null; // No warning needed
  }
}
