// lib/controllers/settings_controller.dart
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends GetxController {
  // Scheduling Settings
  final RxBool enforceBillingValidation = true.obs;
  final RxBool checkInstructorAvailability = true.obs;
  final RxBool autoAssignVehicles = true.obs;
  final RxDouble defaultLessonDuration = 1.5.obs; // hours

  // Billing Settings
  final RxBool showLowLessonWarning = true.obs;
  final RxInt lowLessonThreshold = 3.obs;
  final RxBool preventOverScheduling = true.obs;

  // Instructor Settings
  final RxString workingHoursStart = '09:00'.obs;
  final RxString workingHoursEnd = '18:00'.obs;
  final RxInt breakBetweenLessons = 15.obs; // minutes
  final RxBool allowBackToBackLessons = false.obs;

  // Notification Settings
  final RxBool autoAttendanceNotifications = true.obs;
  final RxBool scheduleConflictAlerts = true.obs;
  final RxBool billingWarnings = true.obs;
  final RxInt lessonStartReminder = 15.obs; // minutes
  final RxString dailySummaryTime = '08:00'.obs;

  // App Preferences
  final RxString theme = 'light'.obs;
  final RxString language = 'english'.obs;
  final RxString dateFormat = 'MM/dd/yyyy'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Scheduling Settings
      enforceBillingValidation.value =
          prefs.getBool('enforce_billing_validation') ?? true;
      checkInstructorAvailability.value =
          prefs.getBool('check_instructor_availability') ?? true;
      autoAssignVehicles.value = prefs.getBool('auto_assign_vehicles') ?? true;
      defaultLessonDuration.value =
          prefs.getDouble('default_lesson_duration') ?? 1.5;

      // Billing Settings
      showLowLessonWarning.value =
          prefs.getBool('show_low_lesson_warning') ?? true;
      lowLessonThreshold.value = prefs.getInt('low_lesson_threshold') ?? 3;
      preventOverScheduling.value =
          prefs.getBool('prevent_over_scheduling') ?? true;

      // Instructor Settings
      workingHoursStart.value =
          prefs.getString('working_hours_start') ?? '09:00';
      workingHoursEnd.value = prefs.getString('working_hours_end') ?? '18:00';
      breakBetweenLessons.value = prefs.getInt('break_between_lessons') ?? 15;
      allowBackToBackLessons.value =
          prefs.getBool('allow_back_to_back') ?? false;

      // Notification Settings
      autoAttendanceNotifications.value =
          prefs.getBool('auto_attendance_notifications') ?? true;
      scheduleConflictAlerts.value =
          prefs.getBool('schedule_conflict_alerts') ?? true;
      billingWarnings.value = prefs.getBool('billing_warnings') ?? true;
      lessonStartReminder.value = prefs.getInt('lesson_start_reminder') ?? 15;
      dailySummaryTime.value = prefs.getString('daily_summary_time') ?? '08:00';

      // App Preferences
      theme.value = prefs.getString('theme') ?? 'light';
      language.value = prefs.getString('language') ?? 'english';
      dateFormat.value = prefs.getString('date_format') ?? 'MM/dd/yyyy';
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // Save individual setting
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      print('Error saving setting $key: $e');
    }
  }

  // Scheduling Settings Methods
  void toggleBillingValidation(bool value) {
    enforceBillingValidation.value = value;
    _saveSetting('enforce_billing_validation', value);
    Get.snackbar(
      'Setting Updated',
      value
          ? 'Billing validation enabled - students must have remaining lessons'
          : 'Billing validation disabled - students can be scheduled without lessons',
      backgroundColor: value ? Colors.green : Colors.orange,
      colorText: Colors.white,
    );
  }

  void toggleInstructorAvailability(bool value) {
    checkInstructorAvailability.value = value;
    _saveSetting('check_instructor_availability', value);
  }

  void toggleAutoAssignVehicles(bool value) {
    autoAssignVehicles.value = value;
    _saveSetting('auto_assign_vehicles', value);
  }

  void setDefaultLessonDuration(double hours) {
    defaultLessonDuration.value = hours;
    _saveSetting('default_lesson_duration', hours);
  }

  // Billing Settings Methods
  void toggleLowLessonWarning(bool value) {
    showLowLessonWarning.value = value;
    _saveSetting('show_low_lesson_warning', value);
  }

  void setLowLessonThreshold(int threshold) {
    lowLessonThreshold.value = threshold;
    _saveSetting('low_lesson_threshold', threshold);
  }

  void togglePreventOverScheduling(bool value) {
    preventOverScheduling.value = value;
    _saveSetting('prevent_over_scheduling', value);
  }

  // Instructor Settings Methods
  void setWorkingHours(String start, String end) {
    workingHoursStart.value = start;
    workingHoursEnd.value = end;
    _saveSetting('working_hours_start', start);
    _saveSetting('working_hours_end', end);
  }

  void setBreakBetweenLessons(int minutes) {
    breakBetweenLessons.value = minutes;
    _saveSetting('break_between_lessons', minutes);
  }

  void toggleBackToBackLessons(bool value) {
    allowBackToBackLessons.value = value;
    _saveSetting('allow_back_to_back', value);
  }

  // Notification Settings Methods
  void toggleAutoAttendanceNotifications(bool value) {
    autoAttendanceNotifications.value = value;
    _saveSetting('auto_attendance_notifications', value);
  }

  void toggleScheduleConflictAlerts(bool value) {
    scheduleConflictAlerts.value = value;
    _saveSetting('schedule_conflict_alerts', value);
  }

  void toggleBillingWarnings(bool value) {
    billingWarnings.value = value;
    _saveSetting('billing_warnings', value);
  }

  void setLessonStartReminder(int minutes) {
    lessonStartReminder.value = minutes;
    _saveSetting('lesson_start_reminder', minutes);
  }

  void setDailySummaryTime(String time) {
    dailySummaryTime.value = time;
    _saveSetting('daily_summary_time', time);
  }

  // App Preferences Methods
  void setTheme(String newTheme) {
    theme.value = newTheme;
    _saveSetting('theme', newTheme);
  }

  void setLanguage(String newLanguage) {
    language.value = newLanguage;
    _saveSetting('language', newLanguage);
  }

  void setDateFormat(String format) {
    dateFormat.value = format;
    _saveSetting('date_format', format);
  }

  // Validation Methods
  bool canScheduleStudent(int studentId, int courseId) {
    if (!enforceBillingValidation.value) {
      return true; // Skip validation if disabled
    }

    try {
      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) => inv.studentId == studentId && inv.courseId == courseId,
      );

      if (invoice == null) {
        return false; // No invoice found
      }

      final scheduleController = Get.find<ScheduleController>();
      final usedLessons = scheduleController.schedules
          .where((s) =>
              s.studentId == studentId && s.courseId == courseId && s.attended)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      final remainingLessons = invoice.lessons - usedLessons;
      return remainingLessons > 0;
    } catch (e) {
      print('Error checking student scheduling eligibility: $e');
      return false;
    }
  }

  bool isInstructorAvailable(int instructorId, DateTime start, DateTime end) {
    if (!checkInstructorAvailability.value) {
      return true; // Skip check if disabled
    }

    try {
      final scheduleController = Get.find<ScheduleController>();
      return !scheduleController.schedules.any((s) {
        return s.instructorId == instructorId &&
            start.isBefore(s.end) &&
            end.isAfter(s.start) &&
            s.status != 'Cancelled';
      });
    } catch (e) {
      print('Error checking instructor availability: $e');
      return false;
    }
  }

  bool isWithinWorkingHours(DateTime dateTime) {
    final startParts = workingHoursStart.value.split(':');
    final endParts = workingHoursEnd.value.split(':');

    final workStart = TimeOfDay(
      hour: int.parse(startParts[0]),
      minute: int.parse(startParts[1]),
    );
    final workEnd = TimeOfDay(
      hour: int.parse(endParts[0]),
      minute: int.parse(endParts[1]),
    );

    final lessonTime = TimeOfDay.fromDateTime(dateTime);

    final lessonMinutes = lessonTime.hour * 60 + lessonTime.minute;
    final startMinutes = workStart.hour * 60 + workStart.minute;
    final endMinutes = workEnd.hour * 60 + workEnd.minute;

    return lessonMinutes >= startMinutes && lessonMinutes <= endMinutes;
  }

  int getRemainingLessons(int studentId, int courseId) {
    try {
      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) => inv.studentId == studentId && inv.courseId == courseId,
      );

      if (invoice == null) return 0;

      final scheduleController = Get.find<ScheduleController>();
      final usedLessons = scheduleController.schedules
          .where((s) =>
              s.studentId == studentId && s.courseId == courseId && s.attended)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      return invoice.lessons - usedLessons;
    } catch (e) {
      print('Error getting remaining lessons: $e');
      return 0;
    }
  }

  bool shouldShowLowLessonWarning(int studentId, int courseId) {
    if (!showLowLessonWarning.value) return false;

    final remaining = getRemainingLessons(studentId, courseId);
    return remaining <= lowLessonThreshold.value && remaining > 0;
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Reset observable values to defaults
      enforceBillingValidation.value = true;
      checkInstructorAvailability.value = true;
      autoAssignVehicles.value = true;
      defaultLessonDuration.value = 1.5;

      showLowLessonWarning.value = true;
      lowLessonThreshold.value = 3;
      preventOverScheduling.value = true;

      workingHoursStart.value = '09:00';
      workingHoursEnd.value = '18:00';
      breakBetweenLessons.value = 15;
      allowBackToBackLessons.value = false;

      autoAttendanceNotifications.value = true;
      scheduleConflictAlerts.value = true;
      billingWarnings.value = true;
      lessonStartReminder.value = 15;
      dailySummaryTime.value = '08:00';

      theme.value = 'light';
      language.value = 'english';
      dateFormat.value = 'MM/dd/yyyy';

      Get.snackbar(
        'Settings Reset',
        'All settings have been reset to defaults',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error resetting settings: $e');
      Get.snackbar(
        'Error',
        'Failed to reset settings',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Export settings
  Map<String, dynamic> exportSettings() {
    return {
      'enforce_billing_validation': enforceBillingValidation.value,
      'check_instructor_availability': checkInstructorAvailability.value,
      'auto_assign_vehicles': autoAssignVehicles.value,
      'default_lesson_duration': defaultLessonDuration.value,
      'show_low_lesson_warning': showLowLessonWarning.value,
      'low_lesson_threshold': lowLessonThreshold.value,
      'prevent_over_scheduling': preventOverScheduling.value,
      'working_hours_start': workingHoursStart.value,
      'working_hours_end': workingHoursEnd.value,
      'break_between_lessons': breakBetweenLessons.value,
      'allow_back_to_back': allowBackToBackLessons.value,
      'auto_attendance_notifications': autoAttendanceNotifications.value,
      'schedule_conflict_alerts': scheduleConflictAlerts.value,
      'billing_warnings': billingWarnings.value,
      'lesson_start_reminder': lessonStartReminder.value,
      'daily_summary_time': dailySummaryTime.value,
      'theme': theme.value,
      'language': language.value,
      'date_format': dateFormat.value,
    };
  }

  // Import settings
  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      settings.forEach((key, value) async {
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        }
      });

      await _loadSettings(); // Reload to update observable values

      Get.snackbar(
        'Settings Imported',
        'Settings have been successfully imported',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error importing settings: $e');
      Get.snackbar(
        'Import Error',
        'Failed to import settings',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
