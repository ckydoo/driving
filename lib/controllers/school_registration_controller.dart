// lib/controllers/school_registration_controller.dart - INTERNET-FIRST APPROACH

import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/routes/app_routes.dart';
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

      // ✅ FIXED: Use form data since API doesn't return all fields
      final operatingDaysString = operatingDays.join(',');
      final location =
          '${cityController.text.trim()}, ${countryController.text.trim()}';

      // Save school data using both API response and form data
      await db.insert(
          'schools',
          {
            'id': school['id'].toString(),
            'name': school['name'],
            // ✅ Use form data for fields not returned by API
            'address': schoolAddressController.text.trim(),
            'location': location,
            'phone': phoneController.text.trim(),
            'email': emailController.text.trim(),
            'website': websiteController.text.trim().isEmpty
                ? null
                : websiteController.text.trim(),
            'start_time': _timeOfDayToString(startTime.value),
            'end_time': _timeOfDayToString(endTime.value),
            'operating_days': operatingDaysString, // ✅ Use local form data
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
      final adminUser =
          result['admin_user']; // ✅ Changed from 'admin' to 'admin_user'
      final school = result['school'];

      // Create users table if it doesn't exist
      await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        school_id TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT DEFAULT 'staff',
        fname TEXT,
        lname TEXT,
        phone TEXT,
        date_of_birth TEXT,
        gender TEXT DEFAULT 'other',
        status TEXT DEFAULT 'active',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (school_id) REFERENCES schools (id)
      )
    ''');

      // ✅ Parse the admin user name from the API response
      final fullName = adminUser['name']?.toString() ?? '';
      final nameParts = fullName.split(' ');
      final firstName = nameParts.isNotEmpty
          ? nameParts.first
          : adminFirstNameController.text.trim();
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : adminLastNameController.text.trim();

      // Save admin user for local authentication
      await db.insert(
          'users',
          {
            'id': adminUser['id'].toString(),
            'school_id': school['id'].toString(),
            'email': adminUser['email'],
            'password':
                adminPasswordController.text, // Store the password from form
            'role': 'admin', // Default to admin role
            'fname': firstName,
            'lname': lastName,
            'phone': adminPhoneController.text.trim(),
            'status': 'active',
            'date_of_birth': DateTime.now()
                .subtract(Duration(days: 365 * 30))
                .toIso8601String()
                .split('T')[0], // Just date part
            'gender': 'other', // Default value
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      print('✅ Step 3 Complete: Local authentication setup');
    } catch (e) {
      print('❌ Step 3 Failed: Failed to setup local auth - $e');
      throw Exception('Failed to setup local authentication: $e');
    }
  }

  /// Helper method: Convert TimeOfDay to string
  String _timeOfDayToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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

      // Save settings to local database FIRST
      await settingsController.saveAllBusinessSettings();

      // Then initialize/update school configuration
      if (Get.isRegistered<SchoolConfigService>()) {
        final schoolConfig = Get.find<SchoolConfigService>();
        await schoolConfig.updateSchoolConfig();
      } else {
        // Create instance - it will auto-initialize from the saved settings
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
    print('🎉 Step 5: Registration complete - redirecting to PIN setup...');

    try {
      final school = result['school'];
      final adminUser = result['admin_user'];
      final trialDays = 30; // Default trial days

      // ✅ CRITICAL: Auto-login the user after registration
      await _autoLoginUser(adminUser, school);

      // Show success dialog with corrected navigation
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.celebration, color: Colors.green.shade600),
              const SizedBox(width: 12),
              const Text('🎉 Registration Complete!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to ${school['name']}!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Your $trialDays-day trial is now active',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explore all features and see how our platform can help manage your driving school.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔐 Next Step: Set up your PIN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a 4-digit PIN for secure and quick access to your account.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Add "Skip for now" option
            TextButton(
              onPressed: () {
                Get.back();
                _navigateToMain(); // Skip PIN setup, go directly to main
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: const Text('Skip for now'),
            ),
            // Primary action: Setup PIN
            ElevatedButton(
              onPressed: () {
                Get.back();
                _navigateToPinSetup(); // ✅ Fixed: Go to PIN setup instead of main
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Set up PIN'),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      print('✅ Step 5 Complete: User ready for PIN setup or main app');
    } catch (e) {
      print('❌ Step 5 Failed: Navigation error - $e');
      // Fallback: still try to navigate to PIN setup
      _navigateToPinSetup();
    }
  }

  /// Navigate to PIN setup (NEW METHOD)
  void _navigateToPinSetup() {
    print('🔐 Navigating to PIN setup...');
    try {
      // Navigate to PIN setup screen
      Get.offAllNamed('/pin-setup');
    } catch (e) {
      print('❌ Navigation to PIN setup failed: $e');
      // Fallback: go to main app
      _navigateToMain();
    }
  }

  /// Navigate to main application (existing method)
  void _navigateToMain() {
    print('🏠 Navigating to main application...');
    try {
      // Clear all previous routes and go to main
      AppRoutes.toMain();
    } catch (e) {
      print('❌ Navigation to main failed: $e');
      // Fallback: go to dashboard
      Get.offAllNamed('/dashboard');
    }
  }

  /// Auto-login the newly registered user
  Future<void> _autoLoginUser(
      Map<String, dynamic> adminUser, Map<String, dynamic> school) async {
    try {
      print('🔐 Auto-logging in registered user...');

      // Get AuthController and login the user
      final authController = Get.find<AuthController>();

      // Create user object from registration data
      final user = User(
          id: adminUser['id'],
          schoolId: school['id'].toString(),
          email: adminUser['email'],
          role: 'admin',
          fname: _extractFirstName(adminUser['name'] ?? ''),
          lname: _extractLastName(adminUser['name'] ?? ''),
          phone: adminPhoneController.text.trim(),
          status: 'active',
          date_of_birth: DateTime.now().subtract(Duration(days: 365 * 30)),
          gender: 'other',
          password: '',
          address: '',
          idnumber: '',
          created_at: DateTime.now() // Not needed for authenticated user
          );

      // Set the user as authenticated
      authController.currentUser(user);
      authController.isLoggedIn(true);

      // Mark first run as completed
      await SchoolSelectionController.markFirstRunCompleted();

      print('✅ User auto-logged in successfully');
    } catch (e) {
      print('❌ Auto-login failed: $e');
      // Don't throw - let the navigation continue
    }
  }

  /// Extract first name from full name
  String _extractFirstName(String fullName) {
    if (fullName.isEmpty) return adminFirstNameController.text.trim();
    return fullName.split(' ').first;
  }

  /// Extract last name from full name
  String _extractLastName(String fullName) {
    if (fullName.isEmpty) return adminLastNameController.text.trim();
    final parts = fullName.split(' ');
    return parts.length > 1
        ? parts.sublist(1).join(' ')
        : adminLastNameController.text.trim();
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
}
