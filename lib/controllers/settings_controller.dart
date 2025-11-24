import 'package:driving/services/database_helper.dart';
import 'package:driving/services/school_config_service.dart';
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

  String get businessNameValue => businessName.value;
  set businessNameValue(String value) => businessName.value = value;
  String get businessAddressValue => businessAddress.value;
  set businessAddressValue(String value) => businessAddress.value = value;
  String get businessCityValue => businessCity.value;
  set businessCityValue(String value) => businessCity.value = value;
  String get businessCountryValue => businessCountry.value;
  set businessCountryValue(String value) => businessCountry.value = value;
  String get businessPhoneValue => businessPhone.value;
  set businessPhoneValue(String value) => businessPhone.value = value;

  final RxInt _tempBreakBetweenLessons = 15.obs;
  final RxInt _tempLessonStartReminder = 15.obs;
  final RxInt _tempLowLessonThreshold = 3.obs;
  final RxInt _tempAutoSaveInterval = 5.obs;

  var printerName = ''.obs;
  var printerPaperSize = '80mm'.obs;
  var autoPrintReceipt = false.obs;
  var receiptCopies = '1'.obs;
  var receiptHeader = 'Thank You!'.obs;
  var receiptFooter = 'Visit us again'.obs;

// ============ PRINTER GETTERS ============

  String get printerNameValue => printerName.value;
  String get printerPaperSizeValue => printerPaperSize.value;
  bool get autoPrintReceiptValue => autoPrintReceipt.value;
  int get receiptCopiesValue => int.tryParse(receiptCopies.value) ?? 1;
  String get receiptHeaderValue => receiptHeader.value;
  String get receiptFooterValue => receiptFooter.value;

  final RxBool _isInitialized = false.obs;
  bool isBusinessInfoComplete() {
    // Check both local settings AND schools table
    return _isLocalBusinessInfoComplete() || _isSchoolRecordComplete();
  }

  /// Check if local settings business info is complete
  bool _isLocalBusinessInfoComplete() {
    return businessName.value.isNotEmpty &&
        businessAddress.value.isNotEmpty &&
        businessPhone.value.isNotEmpty &&
        businessEmail.value.isNotEmpty;
  }

  /// Check if we have complete school record in schools table
  bool _isSchoolRecordComplete() {
    // This will be checked by looking at schools table
    return schoolId.value.isNotEmpty && schoolDisplayName.value.isNotEmpty;
  }

// Lesson duration options (in hours)
  static const List<double> lessonDurationOptions = [0.5, 1.0, 1.5, 2.0];
  static Map<double, String> lessonDurationLabels = {
    0.5: '30 minutes',
    1.0: '1 hour',
    1.5: '1.5 hours',
    2.0: '2 hours',
  };
  // UPDATED: Enhanced initialization sequence
  @override
  void onInit() {
    super.onInit();

    print('🚀 SettingsController onInit started');

    // Initialize temp values first
    _tempBreakBetweenLessons.value = breakBetweenLessons.value;
    _tempLessonStartReminder.value = lessonStartReminder.value;
    _tempLowLessonThreshold.value = lowLessonThreshold.value;
    _tempAutoSaveInterval.value = autoSaveInterval.value;

    // Initialize settings asynchronously to avoid blocking
    _initializeSettingsWithDefaults().then((_) {
      // Mark as initialized after settings are loaded
      _isInitialized.value = true;

      print('🎯 SettingsController fully initialized');
    }).catchError((e) {
      print('❌ Settings initialization failed: $e');
      _isInitialized.value =
          true; // Still mark as initialized to allow UI interaction
    });

    // Set up business information change listeners
    _setupBusinessInfoListeners();
  }

  // Method to set lesson duration
  void setDefaultLessonDuration(double duration) {
    if (lessonDurationOptions.contains(duration)) {
      updateSetting('default_lesson_duration', duration, defaultLessonDuration);
      _showSettingUpdatedSnackbar('lesson_duration');
    }
  }

  // Helper method to get duration label
  String getLessonDurationLabel(double duration) {
    return lessonDurationLabels[duration] ?? '${duration} hours';
  }

  // Method to format duration for display
  String formatLessonDuration(double hours) {
    if (hours == 0.5) return '30 min';
    if (hours == 1.0) return '1 hr';
    if (hours == 1.5) return '1.5 hrs';
    if (hours == 2.0) return '2 hrs';
    return '${hours} hrs';
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

  Future<void> ensureDefaultSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if settings have been initialized before
      bool isFirstLaunch = prefs.getBool('settings_initialized') ?? true;

      if (isFirstLaunch) {
        print('🎯 First launch detected - setting up default settings');

        // Force save all default settings
        await _saveDefaultSettings();

        // Mark settings as initialized
        await prefs.setBool('settings_initialized', false);

        print('✅ Default settings saved on first launch');
      }
    } catch (e) {
      print('❌ Error ensuring default settings: $e');
    }
  }

  // Instructor Settings Methods
  void setWorkingHours(String startTime, String endTime) {
    workingHoursStart.value = startTime;
    workingHoursEnd.value = endTime;
    _saveSetting('working_hours_start', startTime);
    _saveSetting('working_hours_end', endTime);
    _showSettingUpdatedSnackbar('working_hours');
  }

  Future<void> _saveDefaultSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save scheduling defaults (all TRUE)
      await prefs.setBool('enforce_billing_validation', true);
      await prefs.setBool('check_instructor_availability', true);
      await prefs.setBool('enforce_working_hours', true);
      await prefs.setBool('auto_assign_vehicles', true);
      await prefs.setDouble('default_lesson_duration', 1.5);

      // Save billing defaults (all TRUE)
      await prefs.setBool('show_low_lesson_warning', true);
      await prefs.setInt('low_lesson_threshold', 3);
      await prefs.setBool('prevent_over_scheduling', true);
      await prefs.setBool('auto_create_billing_records', true);
      await prefs.setBool('count_scheduled_lessons', true);

      // Save other defaults...
      await prefs.setString('working_hours_start', '09:00');
      await prefs.setString('working_hours_end', '18:00');
      await prefs.setInt('break_between_lessons', 15);
      await prefs.setBool('allow_back_to_back_lessons', false);

      // Notification defaults
      await prefs.setBool('auto_attendance_notifications', true);
      await prefs.setBool('schedule_conflict_alerts', true);
      await prefs.setBool('billing_warnings', true);
      await prefs.setInt('lesson_start_reminder', 15);
      await prefs.setString('daily_summary_time', '08:00');

      // App preferences
      await prefs.setString('theme', 'light');
      await prefs.setString('date_format', 'MM/dd/yyyy');

      // Advanced settings
      await prefs.setBool('enable_data_backup', true);
      await prefs.setBool('enable_auto_save', true);
      await prefs.setInt('auto_save_interval', 5);
      await prefs.setBool('enable_advanced_logging', false);
      await prefs.setString('default_currency', 'USD');
      await prefs.setBool('show_developer_options', false);

      print('💾 All default settings saved to SharedPreferences');
    } catch (e) {
      print('❌ Error saving default settings: $e');
    }
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
        snackPosition: SnackPosition.BOTTOM,
        'Settings Imported',
        'Settings have been successfully imported',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error importing settings: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
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
        snackPosition: SnackPosition.BOTTOM,
        'Settings Reset',
        'All settings have been reset to defaults',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error resetting settings: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
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

  final RxBool enableMultiTenant = true.obs;
  final RxBool enableCloudSync = true.obs;
  final RxString schoolId = ''.obs;
  final RxString schoolDisplayName = ''.obs;
  final RxBool schoolConfigComplete = false.obs;

  /// Set up listeners for business information changes
  void _setupBusinessInfoListeners() {
    // Listen to critical business fields that affect school identity
    ever(businessName,
        (String name) => _onBusinessInfoChanged('businessName', name));
    ever(businessAddress,
        (String address) => _onBusinessInfoChanged('businessAddress', address));
    ever(businessPhone,
        (String phone) => _onBusinessInfoChanged('businessPhone', phone));
    ever(businessEmail,
        (String email) => _onBusinessInfoChanged('businessEmail', email));
  }

  /// Handle business information changes
  void _onBusinessInfoChanged(String field, String value) {
    print('📝 Business info changed: $field = $value');

    // Update school configuration status
    _updateSchoolConfigStatus();

    // Notify school config service if it's registered
    try {
      if (Get.isRegistered<SchoolConfigService>()) {
        final schoolConfig = Get.find<SchoolConfigService>();
        schoolConfig.updateSchoolConfig();
      }
    } catch (e) {
      print('⚠️ Could not update school config: $e');
    }
  }

  /// Update school configuration status
  void _updateSchoolConfigStatus() {
    final isComplete = businessName.value.isNotEmpty &&
        businessAddress.value.isNotEmpty &&
        businessPhone.value.isNotEmpty;

    schoolConfigComplete.value = isComplete;

    if (isComplete) {
      schoolDisplayName.value = businessName.value;
      print('✅ School configuration is complete');
    } else {
      print('⚠️ School configuration is incomplete');
    }
  }

  /// Enhanced save business settings with multi-tenant support
  Future<void> saveBusinessSettings() async {
    try {
      print('💾 Starting to save enhanced business settings...');
      final db = await _dbHelper.database;
      print('📁 Database connection established');

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
        // Multi-tenant settings
        'enable_multi_tenant': enableMultiTenant.value ? '1' : '0',
        'enable_cloud_sync': enableCloudSync.value ? '1' : '0',
        'school_id': schoolId.value,
        'school_display_name': schoolDisplayName.value,
      };

      print('📋 Settings to save: $businessSettingsMap');

      for (final entry in businessSettingsMap.entries) {
        print('💾 Saving: ${entry.key} = ${entry.value}');
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Update school configuration status
      _updateSchoolConfigStatus();

      print('✅ All enhanced business settings saved successfully');
    } catch (e) {
      print('❌ Error saving enhanced business settings: $e');
      rethrow;
    }
  }

  /// Enhanced load settings with multi-tenant support
  Future<void> loadSettingsFromDatabase() async {
    try {
      print('📖 Loading enhanced settings from database...');
      final db = await _dbHelper.database;

      // First load from settings table
      await _loadFromSettingsTable(db);

      // Then check and merge from schools table if needed
      await _mergeFromSchoolsTable(db);

      // Update school configuration status
      _updateSchoolConfigStatus();

      print('✅ Enhanced settings loaded successfully');
    } catch (e) {
      print('❌ Error loading enhanced settings: $e');
      rethrow;
    }
  }

  /// Load from settings table (existing logic)
  Future<void> _loadFromSettingsTable(dynamic db) async {
    final settings = await db.query('settings');

    if (settings.isNotEmpty) {
      final settingsMap = {
        for (var setting in settings) setting['key']: setting['value']
      };

      // Load all existing settings...
      businessName.value = (settingsMap['business_name'] as String?) ?? '';
      businessAddress.value =
          (settingsMap['business_address'] as String?) ?? '';
      businessCity.value = (settingsMap['business_city'] as String?) ?? '';
      businessCountry.value =
          (settingsMap['business_country'] as String?) ?? 'Zimbabwe';
      businessPhone.value = (settingsMap['business_phone'] as String?) ?? '';
      businessEmail.value = (settingsMap['business_email'] as String?) ?? '';
      businessWebsite.value =
          (settingsMap['business_website'] as String?) ?? '';

      // Multi-tenant settings
      enableMultiTenant.value =
          (settingsMap['enable_multi_tenant'] as String?) == '1';
      enableCloudSync.value =
          (settingsMap['enable_cloud_sync'] as String?) == '1';
      schoolId.value = (settingsMap['school_id'] as String?) ?? '';
      schoolDisplayName.value =
          (settingsMap['school_display_name'] as String?) ?? '';

      print(
          '📋 Loaded from settings: name=${businessName.value}, id=${schoolId.value}');
    }
  }

  /// Merge data from schools table if settings are incomplete
  Future<void> _mergeFromSchoolsTable(dynamic db) async {
    try {
      // Check if we have a current school ID
      String? currentSchoolId;

      // Try to get from settings first
      if (schoolId.value.isNotEmpty) {
        currentSchoolId = schoolId.value;
      } else {
        // Try to get from database helper
        try {
          currentSchoolId = await _dbHelper.getCurrentSchoolId();
        } catch (e) {
          print('⚠️ No current school ID found: $e');
        }
      }

      if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
        print('🔍 Checking schools table for ID: $currentSchoolId');

        // Query schools table
        final schoolRecords = await db.query(
          'schools',
          where: 'id = ?',
          whereArgs: [currentSchoolId],
          limit: 1,
        );

        if (schoolRecords.isNotEmpty) {
          final schoolData = schoolRecords.first;
          print('🏫 Found school record: ${schoolData['name']}');

          // FIXED: Always populate from schools table (remove isEmpty checks)
          if (schoolData['name'] != null) {
            businessName.value = schoolData['name'].toString();
            print('✅ Updated business name: ${businessName.value}');
          }

          if (schoolData['address'] != null) {
            businessAddress.value = schoolData['address'].toString();
            print('✅ Updated business address: ${businessAddress.value}');
          }

          if (schoolData['phone'] != null) {
            businessPhone.value = schoolData['phone'].toString();
            print('✅ Updated business phone: ${businessPhone.value}');
          }

          if (schoolData['email'] != null) {
            businessEmail.value = schoolData['email'].toString();
            print('✅ Updated business email: ${businessEmail.value}');
          }

          if (schoolData['city'] != null) {
            businessCity.value = schoolData['city'].toString();
            print('✅ Updated business city: ${businessCity.value}');
          }

          if (schoolData['country'] != null) {
            businessCountry.value = schoolData['country'].toString();
            print('✅ Updated business country: ${businessCountry.value}');
          }

          if (schoolData['website'] != null) {
            businessWebsite.value = schoolData['website'].toString();
            print('✅ Updated business website: ${businessWebsite.value}');
          }

          if (schoolData['start_time'] != null) {
            businessStartTime.value = schoolData['start_time'].toString();
            print('✅ Updated business start time: ${businessStartTime.value}');
          }

          if (schoolData['end_time'] != null) {
            businessEndTime.value = schoolData['end_time'].toString();
            print('✅ Updated business end time: ${businessEndTime.value}');
          }

          if (schoolData['operating_days'] != null) {
            // Parse operating days if it's stored as JSON string
            final operatingDaysData = schoolData['operating_days'];
            if (operatingDaysData is String) {
              try {
                final decoded = jsonDecode(operatingDaysData);
                if (decoded is List) {
                  operatingDays.value =
                      decoded.map((e) => e.toString()).toList();
                }
              } catch (e) {
                // If not JSON, treat as comma-separated
                operatingDays.value =
                    operatingDaysData.split(',').map((e) => e.trim()).toList();
              }
            }
            print('✅ Updated operating days: ${operatingDays.value}');
          }

          if (schoolData['license_number'] != null) {
            // You might want to add a license_number field to your settings
            print(
                'ℹ️ License number available: ${schoolData['license_number']}');
          }

          // Update school-specific settings
          schoolId.value = currentSchoolId;
          schoolDisplayName.value = schoolData['name']?.toString() ?? '';

          // Save merged data to settings table
          print('💾 Saving merged school data to settings...');
          await _saveMergedData();

          print('✅ Successfully merged ALL school data into settings');
        } else {
          print('⚠️ No school record found for ID: $currentSchoolId');
        }
      } else {
        print('ℹ️ No school ID available for merging');
      }
    } catch (e) {
      print('❌ Error merging from schools table: $e');
      // Don't throw - this is a fallback operation
    }
  }

  /// Save merged data to settings table
  Future<void> _saveMergedData() async {
    try {
      final db = await _dbHelper.database;

      final mergedSettings = {
        'business_name': businessName.value,
        'business_address': businessAddress.value,
        'business_phone': businessPhone.value,
        'business_email': businessEmail.value,
        'school_id': schoolId.value,
        'school_display_name': schoolDisplayName.value,
        'enable_multi_tenant': '1',
        'enable_cloud_sync': '1',
      };

      for (final entry in mergedSettings.entries) {
        if (entry.value.isNotEmpty) {
          await db.insert(
            'settings',
            {'key': entry.key, 'value': entry.value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      print('✅ Merged settings saved to database');
    } catch (e) {
      print('❌ Error saving merged data: $e');
    }
  }

  /// Enhanced save all business settings
  Future<void> saveAllBusinessSettings() async {
    try {
      print('💾 Starting saveAllBusinessSettings (enhanced)...');
      await saveBusinessSettings();
      print('✅ Enhanced business settings saved successfully');

      // Trigger school config update if service is available
      try {
        if (Get.isRegistered<SchoolConfigService>()) {
          final schoolConfig = Get.find<SchoolConfigService>();
          await schoolConfig.updateSchoolConfig();
          print('🏫 School configuration updated');
        }
      } catch (e) {
        print('⚠️ Could not update school configuration: $e');
      }
    } catch (e) {
      print('❌ Error in saveAllBusinessSettings (enhanced): $e');
      rethrow;
    }
  }

  /// Get business information summary for school configuration
  Map<String, String> getBusinessInfoSummary() {
    return {
      'name': businessName.value,
      'address': businessAddress.value,
      'city': businessCity.value,
      'country': businessCountry.value,
      'phone': businessPhone.value,
      'email': businessEmail.value,
      'website': businessWebsite.value,
    };
  }

  /// Toggle multi-tenant mode
  void toggleMultiTenant(bool enabled) {
    enableMultiTenant.value = enabled;
    saveBusinessSettings();

    if (enabled) {
      print('🏫 Multi-tenant mode enabled');
      // Trigger school config initialization if needed
      try {
        if (Get.isRegistered<SchoolConfigService>()) {
          Get.find<SchoolConfigService>().initializeSchoolConfig();
        }
      } catch (e) {
        print('⚠️ Could not initialize school config: $e');
      }
    } else {
      print('🏫 Multi-tenant mode disabled');
    }
  }

  /// Toggle cloud sync
  void toggleCloudSync(bool enabled) {
    enableCloudSync.value = enabled;
    saveBusinessSettings();

    print('☁️ Cloud sync ${enabled ? "enabled" : "disabled"}');
  }

  Future<void> _initializeSettings() async {
    try {
      print('🔧 Initializing settings...');

      // Load from SharedPreferences first (faster)
      await _loadSettings();

      // Then load from database (more complete data)
      await loadSettingsFromDatabase();

      print('✅ Settings initialized successfully');
    } catch (e) {
      print('❌ Error initializing settings: $e');
      // Fallback to defaults if both fail
      await _setDefaultSettings();
    }
  }

  Future<void> _setDefaultSettings() async {
    print('⚠️ Setting default values due to loading failure');

    // Set all scheduling defaults to true
    enforceBillingValidation.value = true;
    checkInstructorAvailability.value = true;
    enforceWorkingHours.value = true;
    autoAssignVehicles.value = true;
    defaultLessonDuration.value = 1.5;

    // Set all billing defaults to true
    showLowLessonWarning.value = true;
    lowLessonThreshold.value = 3;
    preventOverScheduling.value = true;
    autoCreateBillingRecords.value = true;
    countScheduledLessons.value = true;

    // Save defaults to SharedPreferences
    await _saveAllSettingsToPreferences();
  }

// FIXED: Proper async save method
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool success = false;

      if (value is bool) {
        success = await prefs.setBool(key, value);
      } else if (value is int) {
        success = await prefs.setInt(key, value);
      } else if (value is double) {
        success = await prefs.setDouble(key, value);
      } else if (value is String) {
        success = await prefs.setString(key, value);
      }

      if (!success) {
        throw Exception('Failed to save $key to SharedPreferences');
      }

      print('✅ Successfully saved $key = $value to SharedPreferences');
    } catch (e) {
      print('❌ Error saving setting $key to SharedPreferences: $e');
      throw e; // Re-throw so updateSetting can handle it
    }
  }

  void toggleAutoAssignVehicles(bool value) async {
    try {
      print('🔧 Toggling auto assign vehicles to: $value');
      await updateSetting('auto_assign_vehicles', value, autoAssignVehicles);
    } catch (e) {
      print('❌ Failed to toggle auto assign vehicles: $e');
      autoAssignVehicles.value = !value;
    }
  }

// Repeat for all other toggle methods...
  void toggleLowLessonWarning(bool value) async {
    try {
      await updateSetting(
          'show_low_lesson_warning', value, showLowLessonWarning);
    } catch (e) {
      showLowLessonWarning.value = !value;
    }
  }

  void togglePreventOverScheduling(bool value) async {
    try {
      await updateSetting(
          'prevent_over_scheduling', value, preventOverScheduling);
    } catch (e) {
      preventOverScheduling.value = !value;
    }
  }

  void toggleAutoCreateBillingRecords(bool value) async {
    try {
      await updateSetting(
          'auto_create_billing_records', value, autoCreateBillingRecords);
    } catch (e) {
      autoCreateBillingRecords.value = !value;
    }
  }

  void toggleCountScheduledLessons(bool value) async {
    try {
      await updateSetting(
          'count_scheduled_lessons', value, countScheduledLessons);
    } catch (e) {
      countScheduledLessons.value = !value;
    }
  }

  Future<void> debugSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      print('🔍 === SHARED PREFERENCES DEBUG ===');
      print('Total keys: ${keys.length}');

      for (String key in keys) {
        if (key.contains('billing') ||
            key.contains('scheduling') ||
            key.contains('instructor')) {
          final value = prefs.get(key);
          print('$key = $value (${value.runtimeType})');
        }
      }
      print('🔍 === END SHARED PREFERENCES DEBUG ===');
    } catch (e) {
      print('❌ Error debugging SharedPreferences: $e');
    }
  }

  // FIXED: Safe snackbar method that checks if context is ready
  void _showSettingUpdatedSnackbar(String key) {
    // Only show snackbar if app is fully initialized and has context
    if (_isInitialized.value && Get.context != null) {
      try {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Setting Updated',
          'Setting "$key" has been updated successfully',
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      } catch (e) {
        print('⚠️ Could not show snackbar for $key: $e');
      }
    } else {
      print('ℹ️ Setting $key updated (snackbar skipped during initialization)');
    }
  }

  // FIXED: Enhanced updateSetting method without snackbar during init
  Future<void> updateSetting(
      String key, dynamic value, dynamic observableValue) async {
    try {
      print('💾 Updating setting: $key = $value');

      // Update the observable value first
      if (observableValue is RxList) {
        observableValue.assignAll(value);
      } else if (observableValue is Rx) {
        observableValue.value = value;
      }

      // Save to SharedPreferences
      await _saveSetting(key, value);

      // Also save to database for backup (don't block on this)
      _saveSettingToDatabase(key, value).catchError((e) {
        print('⚠️ Database backup failed for $key: $e');
      });

      // Only show snackbar if not during initialization
      if (_isInitialized.value) {
        _showSettingUpdatedSnackbar(key);
      }

      print('✅ Setting $key saved successfully');
    } catch (e) {
      print('❌ Error updating setting $key: $e');

      // Revert the observable value on error
      if (observableValue is Rx) {
        // You might want to revert to previous value here
        print('⚠️ Consider reverting $key due to save failure');
      }

      // Only show error snackbar if initialized
      if (_isInitialized.value && Get.context != null) {
        try {
          Get.snackbar(
            'Settings Error',
            'Failed to save setting: $key',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );
        } catch (snackbarError) {
          print('⚠️ Could not show error snackbar: $snackbarError');
        }
      }

      throw e; // Re-throw for caller to handle
    }
  }

  // FIXED: Toggle methods without snackbar during init
  void toggleBillingValidation(bool value) async {
    try {
      print('🔧 Toggling billing validation to: $value');

      // Update UI immediately
      enforceBillingValidation.value = value;

      // Save to SharedPreferences immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enforce_billing_validation', value);

      // Also backup to database (async, don't wait)
      _saveSettingToDatabase('enforce_billing_validation', value)
          .catchError((e) {
        print('⚠️ Database backup failed: $e');
      });

      // Only show snackbar if initialized
      if (_isInitialized.value) {
        _showSettingUpdatedSnackbar('enforce_billing_validation');
      }

      print('✅ Billing validation saved: $value');
    } catch (e) {
      print('❌ Failed to toggle billing validation: $e');
      // Revert UI if save failed
      enforceBillingValidation.value = !value;
    }
  }

  void toggleInstructorAvailabilityCheck(bool value) async {
    try {
      print('🔧 Toggling instructor availability to: $value');

      // Update UI immediately
      checkInstructorAvailability.value = value;

      // Save to SharedPreferences immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('check_instructor_availability', value);

      // Backup to database (async)
      _saveSettingToDatabase('check_instructor_availability', value)
          .catchError((e) {
        print('⚠️ Database backup failed: $e');
      });

      // Only show snackbar if initialized
      if (_isInitialized.value) {
        _showSettingUpdatedSnackbar('check_instructor_availability');
      }

      print('✅ Instructor availability saved: $value');
    } catch (e) {
      print('❌ Failed to toggle instructor availability: $e');
      checkInstructorAvailability.value = !value;
    }
  }

  void toggleWorkingHours(bool value) async {
    try {
      print('🔧 Toggling working hours to: $value');

      // Update UI immediately
      enforceWorkingHours.value = value;

      // Save to SharedPreferences immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enforce_working_hours', value);

      // Backup to database (async)
      _saveSettingToDatabase('enforce_working_hours', value).catchError((e) {
        print('⚠️ Database backup failed: $e');
      });

      // Only show snackbar if initialized
      if (_isInitialized.value) {
        _showSettingUpdatedSnackbar('enforce_working_hours');
      }

      print('✅ Working hours saved: $value');
    } catch (e) {
      print('❌ Failed to toggle working hours: $e');
      enforceWorkingHours.value = !value;
    }
  }

  // UPDATED: Initialize settings with proper defaults - no snackbars during init
  Future<void> _initializeSettingsWithDefaults() async {
    try {
      print('🚀 Starting settings initialization with defaults...');
      await ensureDefaultSettings();
      await _loadSettings();
      await loadSettingsFromDatabase();
      await loadPrinterSettings();
      bool verified = await verifySettingsPersistence();
      if (!verified) {
        print('⚠️ Settings verification failed, forcing save...');
        await _saveAllSettingsToPreferences();
      }

      print('✅ Settings initialized with defaults successfully');
    } catch (e) {
      print('❌ Error initializing settings: $e');
      // Force defaults as last resort
      await _setDefaultSettings();
    }
  }

  // FIXED: Safer method to save to database without blocking
  Future<void> _saveSettingToDatabase(String key, dynamic value) async {
    try {
      final db = await _dbHelper.database;

      await db.insert(
        'settings',
        {
          'key': key,
          'value': value.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Setting $key backed up to database');
    } catch (e) {
      print('⚠️ Failed to backup setting $key to database: $e');
      // Don't throw - database backup is optional
    }
  }

  void enableSnackbars() {
    _isInitialized.value = true;
    print('📢 Snackbars enabled for settings updates');
  }

  void disableSnackbars() {
    _isInitialized.value = false;
    print('🔇 Snackbars disabled for settings updates');
  }

  Future<bool> verifySettingsPersistence() async {
    try {
      print('🔍 Verifying settings persistence...');
      final prefs = await SharedPreferences.getInstance();

      // Check key settings using the SAME defaults as _loadSettings()
      bool billingValidation = prefs.getBool('enforce_billing_validation') ??
          true; // ← FIXED: true instead of false
      bool instructorAvailability =
          prefs.getBool('check_instructor_availability') ??
              true; // ← FIXED: true instead of false
      bool workingHours = prefs.getBool('enforce_working_hours') ??
          true; // ← FIXED: true instead of false

      // Compare with current UI values
      bool isMatch = billingValidation == enforceBillingValidation.value &&
          instructorAvailability == checkInstructorAvailability.value &&
          workingHours == enforceWorkingHours.value;

      if (isMatch) {
        print('✅ Settings persistence verified');
        return true;
      } else {
        print('❌ Settings persistence FAILED');
        print(
            'Expected: billing=$billingValidation, instructor=$instructorAvailability, hours=$workingHours');
        print(
            'Actual: billing=${enforceBillingValidation.value}, instructor=${checkInstructorAvailability.value}, hours=${enforceWorkingHours.value}');
        return false;
      }
    } catch (e) {
      print('❌ Error verifying settings persistence: $e');
      return false;
    }
  }

  // UPDATED: Enhanced test method with correct verification
  Future<void> testSettingsPersistence() async {
    print('🧪 === TESTING SETTINGS PERSISTENCE ===');
    final prefs = await SharedPreferences.getInstance();

    // Clear only the problematic keys for testing
    await prefs.remove('enforce_billing_validation');
    await prefs.remove('check_instructor_availability');
    await prefs.remove('enforce_working_hours');

    print('🧹 Cleared test settings');
    enforceBillingValidation.value = true;
    checkInstructorAvailability.value = true;
    enforceWorkingHours.value = true;
    toggleBillingValidation(true);
    toggleInstructorAvailabilityCheck(true);
    toggleWorkingHours(true);
    await Future.delayed(Duration(milliseconds: 500));
    bool billing = prefs.getBool('enforce_billing_validation') ??
        true; // ← Using true as default
    bool instructor = prefs.getBool('check_instructor_availability') ??
        true; // ← Using true as default
    bool hours = prefs.getBool('enforce_working_hours') ??
        true; // ← Using true as default

    print(
        '💾 Saved values: billing=$billing, instructor=$instructor, hours=$hours');
    print(
        '🎮 UI values: billing=${enforceBillingValidation.value}, instructor=${checkInstructorAvailability.value}, hours=${enforceWorkingHours.value}');

    if (billing && instructor && hours) {
      print('✅ Settings persistence test PASSED');
    } else {
      print('❌ Settings persistence test FAILED');
      await debugSharedPreferences();
    }

    print('🧪 === END PERSISTENCE TEST ===');
  }

  // OPTIONAL: Method to force fix all settings to proper defaults
  Future<void> forceFixAllSettings() async {
    print('🔧 Force fixing all settings to proper defaults...');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Force save all critical settings as TRUE
      await prefs.setBool('enforce_billing_validation', true);
      await prefs.setBool('check_instructor_availability', true);
      await prefs.setBool('enforce_working_hours', true);
      await prefs.setBool('auto_assign_vehicles', true);
      await prefs.setBool('show_low_lesson_warning', true);
      await prefs.setBool('prevent_over_scheduling', true);
      await prefs.setBool('auto_create_billing_records', true);
      await prefs.setBool('count_scheduled_lessons', true);
      await prefs.setBool('auto_attendance_notifications', true);
      await prefs.setBool('schedule_conflict_alerts', true);
      await prefs.setBool('billing_warnings', true);
      await prefs.setBool('enable_data_backup', true);
      await prefs.setBool('enable_auto_save', true);

      // Update UI values to match
      enforceBillingValidation.value = true;
      checkInstructorAvailability.value = true;
      enforceWorkingHours.value = true;
      autoAssignVehicles.value = true;
      showLowLessonWarning.value = true;
      preventOverScheduling.value = true;
      autoCreateBillingRecords.value = true;
      countScheduledLessons.value = true;
      autoAttendanceNotifications.value = true;
      scheduleConflictAlerts.value = true;
      billingWarnings.value = true;
      enableDataBackup.value = true;
      enableAutoSave.value = true;

      print('✅ All settings forced to proper defaults');

      // Verify the fix worked
      await debugSharedPreferences();
    } catch (e) {
      print('❌ Error force fixing settings: $e');
    }
  }

  // UPDATED: _saveAllSettingsToPreferences with explicit true values
  Future<void> _saveAllSettingsToPreferences() async {
    try {
      print(
          '💾 Saving all settings to SharedPreferences with TRUE defaults...');
      final prefs = await SharedPreferences.getInstance();

      // Save scheduling settings (EXPLICITLY TRUE)
      await prefs.setBool('enforce_billing_validation', true);
      await prefs.setBool('check_instructor_availability', true);
      await prefs.setBool('enforce_working_hours', true);
      await prefs.setBool('auto_assign_vehicles', true);
      await prefs.setDouble('default_lesson_duration', 1.5);

      // Save billing settings (EXPLICITLY TRUE)
      await prefs.setBool('show_low_lesson_warning', true);
      await prefs.setInt('low_lesson_threshold', 3);
      await prefs.setBool('prevent_over_scheduling', true);
      await prefs.setBool('auto_create_billing_records', true);
      await prefs.setBool('count_scheduled_lessons', true);

      // Update UI values to match what we saved
      enforceBillingValidation.value = true;
      checkInstructorAvailability.value = true;
      enforceWorkingHours.value = true;
      autoAssignVehicles.value = true;
      showLowLessonWarning.value = true;
      preventOverScheduling.value = true;
      autoCreateBillingRecords.value = true;
      countScheduledLessons.value = true;

      // Save other default settings...
      await prefs.setString('working_hours_start', '09:00');
      await prefs.setString('working_hours_end', '18:00');
      await prefs.setInt('break_between_lessons', 15);
      await prefs.setBool('allow_back_to_back_lessons', false);

      // Notification defaults
      await prefs.setBool('auto_attendance_notifications', true);
      await prefs.setBool('schedule_conflict_alerts', true);
      await prefs.setBool('billing_warnings', true);
      await prefs.setInt('lesson_start_reminder', 15);
      await prefs.setString('daily_summary_time', '08:00');

      // App preferences
      await prefs.setString('theme', 'light');
      await prefs.setString('date_format', 'MM/dd/yyyy');

      // Advanced settings
      await prefs.setBool('enable_data_backup', true);
      await prefs.setBool('enable_auto_save', true);
      await prefs.setInt('auto_save_interval', 5);
      await prefs.setBool('enable_advanced_logging', false);
      await prefs.setString('default_currency', 'USD');
      await prefs.setBool('show_developer_options', false);

      print('✅ All settings saved to SharedPreferences with proper defaults');
    } catch (e) {
      print('❌ Error saving all settings: $e');
      throw e;
    }
  }

  // ============ LOAD PRINTER SETTINGS ============

  Future<void> loadPrinterSettings() async {
    try {
      final db = await _dbHelper.database;
      print('📖 Loading printer settings...');

      final printerNameResult = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['printer_name'],
      );
      if (printerNameResult.isNotEmpty) {
        printerName.value = printerNameResult.first['value'] as String;
      }

      final paperSizeResult = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['printer_paper_size'],
      );
      if (paperSizeResult.isNotEmpty) {
        printerPaperSize.value = paperSizeResult.first['value'] as String;
      }

      final autoPrintResult = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['auto_print_receipt'],
      );
      if (autoPrintResult.isNotEmpty) {
        autoPrintReceipt.value =
            (autoPrintResult.first['value'] as String) == '1';
      }

      final copiesResult = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['receipt_copies'],
      );
      if (copiesResult.isNotEmpty) {
        receiptCopies.value = copiesResult.first['value'] as String;
      }

      final headerResult = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['receipt_header'],
      );
      if (headerResult.isNotEmpty) {
        receiptHeader.value = headerResult.first['value'] as String;
      }

      final footerResult = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['receipt_footer'],
      );
      if (footerResult.isNotEmpty) {
        receiptFooter.value = footerResult.first['value'] as String;
      }

      print('✅ Printer settings loaded successfully');
    } catch (e) {
      print('❌ Error loading printer settings: $e');
    }
  }

// ============ SAVE PRINTER SETTINGS ============

  Future<void> savePrinterSettings() async {
    try {
      final db = await _dbHelper.database;
      print('💾 Saving printer settings...');

      await db.insert(
        'settings',
        {'key': 'printer_name', 'value': printerName.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.insert(
        'settings',
        {'key': 'printer_paper_size', 'value': printerPaperSize.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.insert(
        'settings',
        {
          'key': 'auto_print_receipt',
          'value': autoPrintReceipt.value ? '1' : '0'
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.insert(
        'settings',
        {'key': 'receipt_copies', 'value': receiptCopies.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.insert(
        'settings',
        {'key': 'receipt_header', 'value': receiptHeader.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.insert(
        'settings',
        {'key': 'receipt_footer', 'value': receiptFooter.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Printer settings saved successfully');
    } catch (e) {
      print('❌ Error saving printer settings: $e');
    }
  }
}

// Quick fix method you can call immediately
Future<void> quickFixSettings() async {
  final settingsController = Get.find<SettingsController>();

  print('🚀 Running quick settings fix...');

  // Force fix all settings
  await settingsController.forceFixAllSettings();

  // Test to make sure it worked
  await settingsController.testSettingsPersistence();

  print('🎯 Quick fix complete!');
}
