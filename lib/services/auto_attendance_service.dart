// lib/services/auto_attendance_service.dart
import 'dart:async';
import 'package:driving/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/billing_controller.dart';
import '../models/schedule.dart';

class AutoAttendanceService extends GetxService {
  Timer? _attendanceTimer;
  final ScheduleController _scheduleController = Get.find<ScheduleController>();
  final BillingController _billingController = Get.find<BillingController>();

  // Settings
  final RxBool isAutoAttendanceEnabled = true.obs;
  final RxInt gracePeriosMinutes = 5.obs; // Grace period after lesson ends
  final RxBool notifyBeforeAutoMark = true.obs; // Notify before auto-marking

  @override
  void onInit() {
    super.onInit();
    _startAutoAttendanceTimer();
  }

  @override
  void onClose() {
    _attendanceTimer?.cancel();
    super.onClose();
  }

  /// Start the automatic attendance checking timer
  void _startAutoAttendanceTimer() {
    // Check every minute for lessons that have ended
    _attendanceTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      if (isAutoAttendanceEnabled.value) {
        _checkAndProcessEndedLessons();
      }
    });
  }

  /// Check for lessons that have ended and process auto-attendance
  Future<void> _checkAndProcessEndedLessons() async {
    try {
      final now = DateTime.now();
      final endedLessons = _scheduleController.schedules.where((schedule) {
        // Find lessons that have ended but not yet marked
        final lessonEndTime =
            schedule.end.add(Duration(minutes: gracePeriosMinutes.value));

        return schedule.status != 'Cancelled' &&
            !schedule.attended &&
            now.isAfter(lessonEndTime) &&
            _hasValidBilling(schedule);
      }).toList();

      for (final lesson in endedLessons) {
        await _processAutoAttendance(lesson);
      }
    } catch (e) {
      print('Error in auto-attendance check: $e');
    }
  }

  /// Process auto-attendance for a specific lesson
  Future<void> _processAutoAttendance(Schedule lesson) async {
    try {
      // Since we now prevent scheduling without lessons, we can directly mark as attended
      // Show notification before auto-marking (if enabled)
      if (notifyBeforeAutoMark.value) {
        _showAutoAttendanceNotification(lesson);
      }

      // Wait a moment for potential manual override
      await Future.delayed(Duration(seconds: 30));

      // Check if lesson was manually marked in the meantime
      final updatedLesson = _scheduleController.schedules.firstWhereOrNull(
        (s) => s.id == lesson.id,
      );

      if (updatedLesson != null && !updatedLesson.attended) {
        await _markAsAttended(lesson, 'Auto-marked as attended');
      }
    } catch (e) {
      print('Error processing auto-attendance for lesson ${lesson.id}: $e');
    }
  }

  /// Mark lesson as attended automatically
  Future<void> _markAsAttended(Schedule lesson, String reason) async {
    try {
      await _scheduleController.toggleAttendance(lesson.id!, true);

      Get.snackbar(
        'Auto-Attendance',
        'Lesson automatically marked as attended',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      print('Error auto-marking attendance: $e');
    }
  }

  /// Show notification about upcoming auto-attendance
  void _showAutoAttendanceNotification(Schedule lesson) {
    final student = Get.find<UserController>().users.firstWhereOrNull(
          (user) => user.id == lesson.studentId,
        );

    Get.snackbar(
      'Auto-Attendance',
      'Lesson with ${student?.fname ?? 'Student'} will be marked attended in 30 seconds',
      backgroundColor: Colors.blue.withOpacity(0.9),
      colorText: Colors.white,
      duration: Duration(seconds: 25),
      snackPosition: SnackPosition.TOP,
      icon: Icon(Icons.timer, color: Colors.white),
      mainButton: TextButton(
        onPressed: () {
          Get.back(); // Close snackbar
          _showQuickMarkDialog(lesson);
        },
        child: Text(
          'MARK NOW',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Show quick mark dialog for manual override
  void _showQuickMarkDialog(Schedule lesson) {
    final student = Get.find<UserController>().users.firstWhereOrNull(
          (user) => user.id == lesson.studentId,
        );

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.access_time, color: Colors.blue),
            SizedBox(width: 8),
            Text('Mark Attendance'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Student: ${student?.fname ?? 'Unknown'} ${student?.lname ?? ''}'),
            SizedBox(height: 8),
            Text('Lesson ended ${_getTimeSinceEnd(lesson)}'),
            SizedBox(height: 16),
            Text(
              'How would you like to mark this lesson?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              // Just close dialog for absent - instructor can manually mark later
            },
            child: Text('Mark Later'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _markAsAttended(lesson, 'Manually marked as attended');
            },
            child: Text('Mark Attended'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Check if lesson has valid billing
  bool _hasValidBilling(Schedule lesson) {
    try {
      final invoice = _billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == lesson.studentId &&
            inv.courseId == lesson.courseId,
      );
      return invoice != null;
    } catch (e) {
      return false;
    }
  }

  /// Get human-readable time since lesson ended
  String _getTimeSinceEnd(Schedule lesson) {
    final now = DateTime.now();
    final difference = now.difference(lesson.end);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  /// Manual methods for settings
  void toggleAutoAttendance(bool enabled) {
    isAutoAttendanceEnabled.value = enabled;
    if (enabled) {
      _startAutoAttendanceTimer();
    } else {
      _attendanceTimer?.cancel();
    }
  }

  void setGracePeriod(int minutes) {
    gracePeriosMinutes.value = minutes;
  }

  void toggleNotifications(bool enabled) {
    notifyBeforeAutoMark.value = enabled;
  }

  /// Force check for ended lessons (useful for testing or manual trigger)
  Future<void> forceCheckEndedLessons() async {
    await _checkAndProcessEndedLessons();
  }

  /// Get lessons that will be auto-marked soon
  List<Schedule> getUpcomingAutoMarkLessons() {
    final now = DateTime.now();
    final cutoffTime = now.add(Duration(minutes: gracePeriosMinutes.value));

    return _scheduleController.schedules.where((schedule) {
      return schedule.status != 'Cancelled' &&
          !schedule.attended &&
          schedule.end.isBefore(cutoffTime) &&
          schedule.end
              .isAfter(now.subtract(Duration(hours: 1))); // Within last hour
    }).toList();
  }

  /// Get auto-attendance statistics
  Map<String, int> getAutoAttendanceStats() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final todaySchedules = _scheduleController.schedules
        .where((s) =>
            s.start.isAfter(startOfDay) &&
            s.start.isBefore(startOfDay.add(Duration(days: 1))))
        .toList();

    return {
      'totalToday': todaySchedules.length,
      'autoAttended': todaySchedules
          .where((s) => s.attended && s.status.contains('Auto'))
          .length,
      'manuallyMarked': todaySchedules
          .where((s) => s.attended && !s.status.contains('Auto'))
          .length,
      'pendingAutoMark': getUpcomingAutoMarkLessons().length,
    };
  }
}
