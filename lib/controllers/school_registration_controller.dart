// lib/controllers/school_registration_controller.dart - INTERNET-FIRST APPROACH

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:math';
import '../services/database_helper.dart';
import '../services/school_api_service.dart';
import '../controllers/settings_controller.dart';
import '../controllers/school_selection_controller.dart';
import '../services/school_config_service.dart';

class SchoolRegistrationController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController schoolNameController = TextEditingController();
  final TextEditingController schoolAddressController = TextEditingController();
  final TextEditingController cityController =
      TextEditingController(text: 'Harare');
  final TextEditingController countryController =
      TextEditingController(text: 'Zimbabwe');
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();

  // Admin user form controllers
  final TextEditingController adminFirstNameController =
      TextEditingController();
  final TextEditingController adminLastNameController = TextEditingController();
  final TextEditingController adminEmailController = TextEditingController();
  final TextEditingController adminPasswordController = TextEditingController();
  final TextEditingController adminPhoneController = TextEditingController();

  // Observable properties
  final RxBool isLoading = false.obs;
  final RxBool isOnline = false.obs;
  final RxBool obscurePassword = true.obs;
  final Rx<TimeOfDay> startTime = TimeOfDay(hour: 9, minute: 0).obs;
  final Rx<TimeOfDay> endTime = TimeOfDay(hour: 17, minute: 0).obs;
  final RxList<String> operatingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].obs;
  final RxString registrationMode =
      'checking'.obs; // checking, online_required, online_ready

  @override
  void onInit() {
    super.onInit();
    _checkInternetAndSetMode();
  }

  @override
  void onClose() {
    schoolNameController.dispose();
    schoolAddressController.dispose();
    cityController.dispose();
    countryController.dispose();
    phoneController.dispose();
    emailController.dispose();
    websiteController.dispose();
    adminFirstNameController.dispose();
    adminLastNameController.dispose();
    adminEmailController.dispose();
    adminPasswordController.dispose();
    adminPhoneController.dispose();
    super.onClose();
  }

  /// Check internet connection and set registration mode
  Future<void> _checkInternetAndSetMode() async {
    try {
      print('🔍 Checking internet connectivity for registration...');

      final online = await SchoolApiService.isOnline();
      isOnline.value = online;

      if (online) {
        registrationMode.value = 'online_ready';
        print('🌐 Internet available - Online registration ready');
      } else {
        registrationMode.value = 'online_required';
        print('📵 No internet - Online registration required for first setup');
      }
    } catch (e) {
      isOnline.value = false;
      registrationMode.value = 'online_required';
      print('❌ Failed to check connectivity: $e');
    }
  }

  /// Retry internet connection
  Future<void> retryConnection() async {
    registrationMode.value = 'checking';
    await _checkInternetAndSetMode();
  }

  /// Toggle password visibility
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  /// Select start time
  Future<void> selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime.value,
    );
    if (picked != null) {
      startTime.value = picked;
    }
  }

  /// Select end time
  Future<void> selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: endTime.value,
    );
    if (picked != null) {
      endTime.value = picked;
    }
  }

  /// Register school (INTERNET-FIRST APPROACH)
  Future<void> registerSchool() async {
    // Validate form first
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (operatingDays.isEmpty) {
      Get.snackbar(
        'Error',
        'Please select at least one operating day',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Validate admin information
    if (!_validateAdminInfo()) {
      return;
    }

    // Check internet connection again before proceeding
    await _checkInternetAndSetMode();

    if (!isOnline.value) {
      _showNoInternetDialog();
      return;
    }

    try {
      isLoading(true);
      print('🌐 === INTERNET-FIRST SCHOOL REGISTRATION ===');

      // Step 1: Register school online (REQUIRED)
      final registrationResult = await _registerSchoolOnline();

      // Step 2: Download and save school data locally
      await _downloadAndSaveSchoolData(registrationResult);

      // Step 3: Setup local authentication
      await _setupLocalAuthentication(registrationResult);

      // Step 4: Update app settings
      await _updateAppSettings(registrationResult);

      // Step 5: Show success and navigate
      await _showSuccessAndNavigate(registrationResult);
    } catch (e) {
      print('❌ School registration failed: $e');
      _showRegistrationError('Registration failed: $e');
    } finally {
      isLoading(false);
    }
  }

  /// Step 1: Register school online (REQUIRED)
  Future<Map<String, dynamic>> _registerSchoolOnline() async {
    print('📡 Step 1: Registering school online...');

    try {
      final result = await SchoolApiService.registerSchool(
        schoolName: schoolNameController.text.trim(),
        schoolEmail: emailController.text.trim(),
        schoolPhone: phoneController.text.trim(),
        schoolAddress: schoolAddressController.text.trim(),
        schoolCity: cityController.text.trim(),
        schoolCountry: countryController.text.trim(),
        schoolWebsite: websiteController.text.trim().isEmpty
            ? null
            : websiteController.text.trim(),
        startTime: _timeOfDayToString(startTime.value),
        endTime: _timeOfDayToString(endTime.value),
        operatingDays: operatingDays.toList(),
        adminFirstName: adminFirstNameController.text.trim(),
        adminLastName: adminLastNameController.text.trim(),
        adminEmail: adminEmailController.text.trim(),
        adminPassword: adminPasswordController.text.trim(),
        adminPhone: adminPhoneController.text.trim(),
      );

      print('✅ Step 1 Complete: School registered online');
      return result;
    } catch (e) {
      print('❌ Step 1 Failed: Online registration failed - $e');
      throw Exception('Failed to register school online: $e');
    }
  }

  /// Step 2: Download and save school data locally
  Future<void> _downloadAndSaveSchoolData(Map<String, dynamic> result) async {
    print('💾 Step 2: Downloading school data locally...');

    try {
      final db = await _dbHelper.database;
      final school = result['school'];

      // Create schools table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schools (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          address TEXT,
          location TEXT,
          phone TEXT,
          email TEXT,
          website TEXT,
          start_time TEXT,
          end_time TEXT,
          operating_days TEXT,
          invitation_code TEXT UNIQUE,
          status TEXT DEFAULT 'active',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Save school data
      await db.insert(
          'schools',
          {
            'id': school['id'].toString(),
            'name': school['name'],
            'address': school['address'],
            'location': '${school['city']}, ${school['country']}',
            'phone': school['phone'],
            'email': school['email'],
            'website': school['website'] ?? '',
            'start_time': school['start_time'],
            'end_time': school['end_time'],
            'operating_days': (school['operating_days'] as List).join(','),
            'invitation_code': school['invitation_code'],
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      print('✅ Step 2 Complete: School data saved locally');
    } catch (e) {
      print('❌ Step 2 Failed: Failed to save school data - $e');
      throw Exception('Failed to save school data locally: $e');
    }
  }

  /// Step 3: Setup local authentication
  Future<void> _setupLocalAuthentication(Map<String, dynamic> result) async {
    print('🔐 Step 3: Setting up local authentication...');

    try {
      final db = await _dbHelper.database;
      final admin = result['admin'];
      final school = result['school'];

      // Create users table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          school_id TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          role TEXT DEFAULT 'staff',
          first_name TEXT,
          last_name TEXT,
          phone TEXT,
          status TEXT DEFAULT 'active',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (school_id) REFERENCES schools (id)
        )
      ''');

      // Save admin user for local authentication
      await db.insert(
          'users',
          {
            'id': admin['id'].toString(),
            'school_id': school['id'].toString(),
            'email': admin['email'],
            'password_hash':
                adminPasswordController.text, // Store for local auth
            'role': admin['role'],
            'first_name': admin['fname'],
            'last_name': admin['lname'],
            'phone': admin['phone'],
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      print('✅ Step 3 Complete: Local authentication setup');
    } catch (e) {
      print('❌ Step 3 Failed: Failed to setup local auth - $e');
      throw Exception('Failed to setup local authentication: $e');
    }
  }

  /// Step 4: Update app settings
  Future<void> _updateAppSettings(Map<String, dynamic> result) async {
    print('⚙️ Step 4: Updating app settings...');

    try {
      final school = result['school'];
      final schoolId = school['id'].toString();

      // Update settings controller
      final settingsController = Get.find<SettingsController>();

      settingsController.schoolId.value = schoolId;
      settingsController.schoolDisplayName.value = school['name'].toString();
      settingsController.enableMultiTenant.value = true;
      settingsController.enableCloudSync.value = true;

      // Update business info from school data
      settingsController.setBusinessName(school['name'].toString());
      settingsController
          .setBusinessAddress(school['address']?.toString() ?? '');
      settingsController.setBusinessPhone(school['phone']?.toString() ?? '');
      settingsController.setBusinessEmail(school['email']?.toString() ?? '');

      // Save settings to local database
      await settingsController.saveAllBusinessSettings();

      // Initialize or update school configuration
      if (Get.isRegistered<SchoolConfigService>()) {
        final schoolConfig = Get.find<SchoolConfigService>();
        await schoolConfig
            .updateSchoolConfig(); // Use updateSchoolConfig instead
      } else {
        // If not registered, create instance (it will auto-initialize)
        Get.put<SchoolConfigService>(SchoolConfigService(), permanent: true);
      }

      print('✅ Step 4 Complete: App settings updated');
    } catch (e) {
      print('❌ Step 4 Failed: Failed to update settings - $e');
      throw Exception('Failed to update app settings: $e');
    }
  }

  /// Step 5: Show success and navigate
  Future<void> _showSuccessAndNavigate(Map<String, dynamic> result) async {
    print('🎉 Step 5: Registration complete - showing success...');

    try {
      final school = result['school'];
      final trialDays = result['trial_days_remaining'] ?? 30;

      // Show success dialog
      await Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
              const SizedBox(width: 12),
              const Expanded(child: Text('Registration Successful!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🏫 School: ${school['name']}'),
              const SizedBox(height: 8),
              Text('🎫 Invitation Code: ${school['invitation_code']}'),
              const SizedBox(height: 8),
              Text('⏱️ Trial Period: $trialDays days'),
              const SizedBox(height: 16),
              Text(
                'Your school is now registered and data has been downloaded for offline access.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue to Login'),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      // Mark first run as completed and navigate
      await SchoolSelectionController.markFirstRunCompleted();
      Get.offAllNamed('/login');

      print('✅ Step 5 Complete: Registration successful!');
    } catch (e) {
      print('❌ Step 5 Failed: Navigation error - $e');
      // Still navigate even if dialog fails
      Get.offAllNamed('/login');
    }
  }

  /// Show no internet dialog
  void _showNoInternetDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Internet Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('School registration requires an internet connection for:'),
            SizedBox(height: 8),
            Text('• Creating your school account online'),
            Text('• Setting up administrator access'),
            Text('• Downloading school configuration'),
            Text('• Enabling cloud sync features'),
            SizedBox(height: 16),
            Text('Please connect to the internet and try again.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              retryConnection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Validate admin user information
  bool _validateAdminInfo() {
    if (adminFirstNameController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Admin first name is required',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (adminLastNameController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Admin last name is required',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (adminEmailController.text.trim().isEmpty ||
        !GetUtils.isEmail(adminEmailController.text.trim())) {
      Get.snackbar('Error', 'Valid admin email is required',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (adminPasswordController.text.length < 8) {
      Get.snackbar('Error', 'Admin password must be at least 8 characters',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (adminPhoneController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Admin phone number is required',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  /// Show registration error
  void _showRegistrationError(String message) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Registration Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text('Please check your internet connection and try again.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Convert TimeOfDay to string
  String _timeOfDayToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
