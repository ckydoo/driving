// lib/controllers/enhanced_settings_controller.dart
import 'package:driving/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SettingsController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Scheduling Settings
  final RxBool enforceBillingValidation = true.obs;
  final RxBool checkInstructorAvailability = true.obs;
  final RxBool enforceWorkingHours = true.obs;
  final RxBool autoAssignVehicles = true.obs;
  final RxDouble defaultLessonDuration = 1.5.obs; // hours

  // Billing Settings
  final RxBool showLowLessonWarning = true.obs;
  final RxInt lowLessonThreshold = 3.obs;
  final RxBool preventOverScheduling = true.obs;
  final RxBool autoCreateBillingRecords = true.obs;
  final RxBool countScheduledLessons = true.obs;

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
  final RxString dateFormat = 'MM/dd/yyyy'.obs;

  // NEW: Advanced Settings
  final RxBool enableDataBackup = true.obs;
  final RxBool enableAutoSave = true.obs;
  final RxInt autoSaveInterval = 5.obs; // minutes
  final RxBool enableAdvancedLogging = false.obs;
  final RxString defaultCurrency = 'USD'.obs;
  final RxBool showDeveloperOptions = false.obs;

  // Business Information
  final RxString businessName = ''.obs;
  final RxString businessAddress = ''.obs;
  final RxString businessCity = ''.obs;
  final RxString businessCountry = 'Zimbabwe'.obs;

  // Contact Information
  final RxString businessPhone = ''.obs;
  final RxString businessEmail = ''.obs;
  final RxString businessWebsite = ''.obs;

  // Operating Schedule
  final RxList<String> operatingDays = <String>[].obs;
  final RxString businessStartTime = '09:00'.obs;
  final RxString businessEndTime = '17:00'.obs;

  final RxInt _tempBreakBetweenLessons = 15.obs;
  final RxInt _tempLessonStartReminder = 15.obs;
  final RxInt _tempLowLessonThreshold = 3.obs;
  final RxInt _tempAutoSaveInterval = 5.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    // Initialize temp values
    _tempBreakBetweenLessons.value = breakBetweenLessons.value;
    _tempLessonStartReminder.value = lessonStartReminder.value;
    _tempLowLessonThreshold.value = lowLessonThreshold.value;
    _tempAutoSaveInterval.value = autoSaveInterval.value;
    loadSettingsFromDatabase();
  }

  // Enhanced methods for smooth slider experience
  void updateBreakBetweenLessonsTemp(int minutes) {
    _tempBreakBetweenLessons.value = minutes;
  }

  void commitBreakBetweenLessons() {
    updateSetting('break_between_lessons', _tempBreakBetweenLessons.value,
        breakBetweenLessons);
  }

  void updateLessonStartReminderTemp(int minutes) {
    _tempLessonStartReminder.value = minutes;
  }

  void commitLessonStartReminder() {
    updateSetting('lesson_start_reminder', _tempLessonStartReminder.value,
        lessonStartReminder);
  }

  void updateLowLessonThresholdTemp(int threshold) {
    _tempLowLessonThreshold.value = threshold;
  }

  void commitLowLessonThreshold() {
    updateSetting('low_lesson_threshold', _tempLowLessonThreshold.value,
        lowLessonThreshold);
  }

  void updateAutoSaveIntervalTemp(int interval) {
    _tempAutoSaveInterval.value = interval;
  }

  void commitAutoSaveInterval() {
    updateSetting(
        'auto_save_interval', _tempAutoSaveInterval.value, autoSaveInterval);
  }

  // Getters for temp values
  RxInt get tempBreakBetweenLessons => _tempBreakBetweenLessons;
  RxInt get tempLessonStartReminder => _tempLessonStartReminder;
  RxInt get tempLowLessonThreshold => _tempLowLessonThreshold;
  RxInt get tempAutoSaveInterval => _tempAutoSaveInterval;

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Scheduling Settings
      enforceBillingValidation.value =
          prefs.getBool('enforce_billing_validation') ?? true;
      checkInstructorAvailability.value =
          prefs.getBool('check_instructor_availability') ?? true;
      enforceWorkingHours.value =
          prefs.getBool('enforce_working_hours') ?? true;
      autoAssignVehicles.value = prefs.getBool('auto_assign_vehicles') ?? true;
      defaultLessonDuration.value =
          prefs.getDouble('default_lesson_duration') ?? 1.5;

      // Billing Settings
      showLowLessonWarning.value =
          prefs.getBool('show_low_lesson_warning') ?? true;
      lowLessonThreshold.value = prefs.getInt('low_lesson_threshold') ?? 3;
      preventOverScheduling.value =
          prefs.getBool('prevent_over_scheduling') ?? true;
      autoCreateBillingRecords.value =
          prefs.getBool('auto_create_billing_records') ?? true;
      countScheduledLessons.value =
          prefs.getBool('count_scheduled_lessons') ?? true;

      // Instructor Settings
      workingHoursStart.value =
          prefs.getString('working_hours_start') ?? '09:00';
      workingHoursEnd.value = prefs.getString('working_hours_end') ?? '18:00';
      breakBetweenLessons.value = prefs.getInt('break_between_lessons') ?? 15;
      allowBackToBackLessons.value =
          prefs.getBool('allow_back_to_back_lessons') ?? false;

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
      dateFormat.value = prefs.getString('date_format') ?? 'MM/dd/yyyy';

      // Advanced Settings
      enableDataBackup.value = prefs.getBool('enable_data_backup') ?? true;
      enableAutoSave.value = prefs.getBool('enable_auto_save') ?? true;
      autoSaveInterval.value = prefs.getInt('auto_save_interval') ?? 5;
      enableAdvancedLogging.value =
          prefs.getBool('enable_advanced_logging') ?? false;
      defaultCurrency.value = prefs.getString('default_currency') ?? 'USD';
      showDeveloperOptions.value =
          prefs.getBool('show_developer_options') ?? false;
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

  // Enhanced utility methods for easy setting management
  void updateSetting(String key, dynamic value, dynamic observableValue) {
    if (observableValue is RxList) {
      observableValue.assignAll(value);
    } else if (observableValue is Rx) {
      observableValue.value = value;
    }
    _saveSetting(key, value);
    _showSettingUpdatedSnackbar(key);
  }

  void _showSettingUpdatedSnackbar(String key) {
    Get.snackbar(
      'Setting Updated',
      'Setting "$key" has been updated successfully',
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // Scheduling Settings Methods
  void toggleBillingValidation(bool value) => updateSetting(
      'enforce_billing_validation', value, enforceBillingValidation);

  void toggleInstructorAvailabilityCheck(bool value) => updateSetting(
      'check_instructor_availability', value, checkInstructorAvailability);

  void toggleWorkingHours(bool value) =>
      updateSetting('enforce_working_hours', value, enforceWorkingHours);

  void toggleAutoAssignVehicles(bool value) =>
      updateSetting('auto_assign_vehicles', value, autoAssignVehicles);

  void setDefaultLessonDuration(double value) =>
      updateSetting('default_lesson_duration', value, defaultLessonDuration);

  // Billing Settings Methods
  void toggleLowLessonWarning(bool value) =>
      updateSetting('show_low_lesson_warning', value, showLowLessonWarning);

  void setLowLessonThreshold(int value) =>
      updateSetting('low_lesson_threshold', value, lowLessonThreshold);

  void togglePreventOverScheduling(bool value) =>
      updateSetting('prevent_over_scheduling', value, preventOverScheduling);

  void toggleAutoCreateBillingRecords(bool value) => updateSetting(
      'auto_create_billing_records', value, autoCreateBillingRecords);

  void toggleCountScheduledLessons(bool value) =>
      updateSetting('count_scheduled_lessons', value, countScheduledLessons);

  // Instructor Settings Methods
  void setWorkingHours(String startTime, String endTime) {
    workingHoursStart.value = startTime;
    workingHoursEnd.value = endTime;
    _saveSetting('working_hours_start', startTime);
    _saveSetting('working_hours_end', endTime);
    _showSettingUpdatedSnackbar('working_hours');
  }

  void setBreakBetweenLessons(int minutes) =>
      updateSetting('break_between_lessons', minutes, breakBetweenLessons);

  void toggleBackToBackLessons(bool value) => updateSetting(
      'allow_back_to_back_lessons', value, allowBackToBackLessons);

  // Notification Settings Methods
  void toggleAutoAttendanceNotifications(bool value) => updateSetting(
      'auto_attendance_notifications', value, autoAttendanceNotifications);

  void toggleScheduleConflictAlerts(bool value) =>
      updateSetting('schedule_conflict_alerts', value, scheduleConflictAlerts);

  void toggleBillingWarnings(bool value) =>
      updateSetting('billing_warnings', value, billingWarnings);

  void setLessonStartReminder(int minutes) =>
      updateSetting('lesson_start_reminder', minutes, lessonStartReminder);

  void setDailySummaryTime(String time) =>
      updateSetting('daily_summary_time', time, dailySummaryTime);

  // App Preferences Methods
  void setTheme(String newTheme) {
    updateSetting('theme', newTheme, theme);
    _applyTheme(newTheme);
  }

  void _applyTheme(String themeName) {
    // This would integrate with your theme system
    switch (themeName) {
      case 'dark':
        Get.changeThemeMode(ThemeMode.dark);
        break;
      case 'light':
        Get.changeThemeMode(ThemeMode.light);
        break;
      case 'system':
        Get.changeThemeMode(ThemeMode.system);
        break;
    }
  }

  void setDateFormat(String format) =>
      updateSetting('date_format', format, dateFormat);

  // Advanced Settings Methods
  void toggleDataBackup(bool value) =>
      updateSetting('enable_data_backup', value, enableDataBackup);

  void toggleAutoSave(bool value) =>
      updateSetting('enable_auto_save', value, enableAutoSave);

  void setAutoSaveInterval(int minutes) =>
      updateSetting('auto_save_interval', minutes, autoSaveInterval);

  void toggleAdvancedLogging(bool value) =>
      updateSetting('enable_advanced_logging', value, enableAdvancedLogging);

  void setDefaultCurrency(String currency) =>
      updateSetting('default_currency', currency, defaultCurrency);

  void toggleDeveloperOptions(bool value) =>
      updateSetting('show_developer_options', value, showDeveloperOptions);

  // Export settings to JSON
  String exportSettings() {
    final settings = {
      // Scheduling
      'enforce_billing_validation': enforceBillingValidation.value,
      'check_instructor_availability': checkInstructorAvailability.value,
      'enforce_working_hours': enforceWorkingHours.value,
      'auto_assign_vehicles': autoAssignVehicles.value,
      'default_lesson_duration': defaultLessonDuration.value,

      // Billing
      'show_low_lesson_warning': showLowLessonWarning.value,
      'low_lesson_threshold': lowLessonThreshold.value,
      'prevent_over_scheduling': preventOverScheduling.value,
      'auto_create_billing_records': autoCreateBillingRecords.value,
      'count_scheduled_lessons': countScheduledLessons.value,

      // Instructor
      'working_hours_start': workingHoursStart.value,
      'working_hours_end': workingHoursEnd.value,
      'break_between_lessons': breakBetweenLessons.value,
      'allow_back_to_back_lessons': allowBackToBackLessons.value,

      // Notifications
      'auto_attendance_notifications': autoAttendanceNotifications.value,
      'schedule_conflict_alerts': scheduleConflictAlerts.value,
      'billing_warnings': billingWarnings.value,
      'lesson_start_reminder': lessonStartReminder.value,
      'daily_summary_time': dailySummaryTime.value,

      // App Preferences
      'theme': theme.value,
      'date_format': dateFormat.value,

      // Advanced
      'enable_data_backup': enableDataBackup.value,
      'enable_auto_save': enableAutoSave.value,
      'auto_save_interval': autoSaveInterval.value,
      'enable_advanced_logging': enableAdvancedLogging.value,
      'default_currency': defaultCurrency.value,
      'show_developer_options': showDeveloperOptions.value,
    };

    return jsonEncode(settings);
  }

  // Import settings from JSON
  Future<void> importSettings(String jsonString) async {
    try {
      final Map<String, dynamic> settings = jsonDecode(jsonString);
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
        'Failed to import settings: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Reset all observable values to defaults
      enforceBillingValidation.value = true;
      checkInstructorAvailability.value = true;
      enforceWorkingHours.value = true;
      autoAssignVehicles.value = true;
      defaultLessonDuration.value = 1.5;

      showLowLessonWarning.value = true;
      lowLessonThreshold.value = 3;
      preventOverScheduling.value = true;
      autoCreateBillingRecords.value = true;
      countScheduledLessons.value = true;

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
      dateFormat.value = 'MM/dd/yyyy';

      enableDataBackup.value = true;
      enableAutoSave.value = true;
      autoSaveInterval.value = 5;
      enableAdvancedLogging.value = false;
      defaultCurrency.value = 'USD';
      showDeveloperOptions.value = false;

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

  // Utility method to easily add new settings in the future
  void addNewSetting<T>(String key, T defaultValue, Rx<T> observable) {
    // This method can be used to dynamically add new settings
    observable.value = defaultValue;
    _saveSetting(key, defaultValue);
  }

  // Get all current settings as a map (useful for debugging)
  Map<String, dynamic> getAllSettings() {
    return {
      'scheduling': {
        'enforceBillingValidation': enforceBillingValidation.value,
        'checkInstructorAvailability': checkInstructorAvailability.value,
        'enforceWorkingHours': enforceWorkingHours.value,
        'autoAssignVehicles': autoAssignVehicles.value,
        'defaultLessonDuration': defaultLessonDuration.value,
      },
      'billing': {
        'showLowLessonWarning': showLowLessonWarning.value,
        'lowLessonThreshold': lowLessonThreshold.value,
        'preventOverScheduling': preventOverScheduling.value,
        'autoCreateBillingRecords': autoCreateBillingRecords.value,
        'countScheduledLessons': countScheduledLessons.value,
      },
      'instructor': {
        'workingHoursStart': workingHoursStart.value,
        'workingHoursEnd': workingHoursEnd.value,
        'breakBetweenLessons': breakBetweenLessons.value,
        'allowBackToBackLessons': allowBackToBackLessons.value,
      },
      'notifications': {
        'autoAttendanceNotifications': autoAttendanceNotifications.value,
        'scheduleConflictAlerts': scheduleConflictAlerts.value,
        'billingWarnings': billingWarnings.value,
        'lessonStartReminder': lessonStartReminder.value,
        'dailySummaryTime': dailySummaryTime.value,
      },
      'app': {
        'theme': theme.value,
        'dateFormat': dateFormat.value,
      },
      'advanced': {
        'enableDataBackup': enableDataBackup.value,
        'enableAutoSave': enableAutoSave.value,
        'autoSaveInterval': autoSaveInterval.value,
        'enableAdvancedLogging': enableAdvancedLogging.value,
        'defaultCurrency': defaultCurrency.value,
        'showDeveloperOptions': showDeveloperOptions.value,
      },
    };
  }

  Future<void> loadSettingsFromDatabase() async {
    try {
      final db = await _dbHelper.database;
      final settings = await db.query('settings');

      if (settings.isNotEmpty) {
        final settingsMap = {
          for (var setting in settings) setting['key']: setting['value']
        };

        // Business Information
        businessName.value = (settingsMap['business_name'] as String?) ?? '';
        businessAddress.value =
            (settingsMap['business_address'] as String?) ?? '';
        businessCity.value = (settingsMap['business_city'] as String?) ?? '';
        businessCountry.value =
            (settingsMap['business_country'] as String?) ?? 'Zimbabwe';

        // Contact Information
        businessPhone.value = (settingsMap['business_phone'] as String?) ?? '';
        businessEmail.value = (settingsMap['business_email'] as String?) ?? '';
        businessWebsite.value =
            (settingsMap['business_website'] as String?) ?? '';

        // Operating Schedule
        businessStartTime.value =
            (settingsMap['business_start_time'] as String?) ?? '09:00';
        businessEndTime.value =
            (settingsMap['business_end_time'] as String?) ?? '17:00';

        // Operating Days (stored as comma-separated string)
        final operatingDaysString =
            (settingsMap['operating_days'] as String?) ?? '';
        if (operatingDaysString.isNotEmpty) {
          operatingDays.value = operatingDaysString.split(',');
        }
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

// Save business settings to database
  Future<void> saveBusinessSettings() async {
    try {
      print('Starting to save business settings...');
      final db = await _dbHelper.database;
      print('Database connection established');

      final businessSettingsMap = {
        'business_name': businessName.value,
        'business_address': businessAddress.value,
        'business_city': businessCity.value,
        'business_country': businessCountry.value,
        'business_phone': businessPhone.value,
        'business_email': businessEmail.value,
        'business_website': businessWebsite.value,
        'business_start_time': businessStartTime.value,
        'business_end_time': businessEndTime.value,
        'operating_days': operatingDays.join(','),
      };

      print('Settings to save: $businessSettingsMap');

      for (final entry in businessSettingsMap.entries) {
        print('Saving: ${entry.key} = ${entry.value}');
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      print('All business settings saved successfully');
    } catch (e) {
      print('Error saving business settings: $e');
      rethrow; // Re-throw to be caught by calling method
    }
  }

// Enhanced save method that ensures all current values are saved
// Enhanced save method that ensures all current values are saved
  Future<void> saveAllBusinessSettings() async {
    try {
      print('Starting saveAllBusinessSettings...');
      await saveBusinessSettings();
      print('Business settings saved successfully');

      // Don't show snackbar here - let the UI handle it
      // This prevents conflicts with the loading dialog
    } catch (e) {
      print('Error in saveAllBusinessSettings: $e');
      rethrow; // Re-throw so the UI can handle it
    }
  }

// Individual setters for text fields
  void setBusinessName(String name) {
    businessName.value = name;
  }

  void setBusinessAddress(String address) {
    businessAddress.value = address;
  }

  void setBusinessCity(String city) {
    businessCity.value = city;
  }

  void setBusinessPhone(String phone) {
    businessPhone.value = phone;
  }

  void setBusinessEmail(String email) {
    businessEmail.value = email;
  }

  void setBusinessWebsite(String website) {
    businessWebsite.value = website;
  }
}
