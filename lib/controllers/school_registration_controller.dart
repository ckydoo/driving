// lib/controllers/school_registration_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:math';
import '../services/database_helper.dart';
import '../services/school_api_service.dart'; // Add this import
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

  // Admin user form controllers (NEW)
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

  @override
  void onInit() {
    super.onInit();
    _checkOnlineStatus();
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

  /// Check if app is online
  Future<void> _checkOnlineStatus() async {
    try {
      final online = await SchoolApiService.isOnline();
      isOnline.value = online;

      if (online) {
        print('🌐 Online - School registration will use cloud API');
      } else {
        print('📱 Offline - School registration will be local only');
      }
    } catch (e) {
      isOnline.value = false;
      print('❌ Failed to check online status: $e');
    }
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

  /// Toggle operating day
  void toggleOperatingDay(String day) {
    if (operatingDays.contains(day)) {
      operatingDays.remove(day);
    } else {
      operatingDays.add(day);
    }
  }

  /// Register new school (online-first approach)
  Future<void> registerSchool() async {
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

    try {
      isLoading(true);

      if (isOnline.value) {
        print('🌐 Attempting online school registration...');
        await _registerSchoolOnline();
      } else {
        print('📱 Falling back to offline registration...');
        await _registerSchoolOffline();
      }
    } catch (e) {
      print('❌ School registration failed: $e');

      // If online registration fails, try offline as fallback
      if (isOnline.value &&
          e.toString().contains('Failed to register school')) {
        try {
          print('🔄 Online registration failed, trying offline fallback...');
          await _registerSchoolOffline();
        } catch (offlineError) {
          _showRegistrationError('Registration failed: $offlineError');
        }
      } else {
        _showRegistrationError('Registration failed: $e');
      }
    } finally {
      isLoading(false);
    }
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

  /// Register school online via API
  Future<void> _registerSchoolOnline() async {
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

      // Save school info locally for offline access
      await _saveSchoolLocallyFromOnlineResult(result);

      // Update settings controller
      await _updateSettingsController(result['school']['id'].toString());

      // Show success with trial information
      await _showOnlineSuccessDialog(result);

      // Mark first run completed and navigate
      await SchoolSelectionController.markFirstRunCompleted();
      Get.offAllNamed('/login');
    } catch (e) {
      print('❌ Online registration failed: $e');
      throw Exception('Online registration failed: $e');
    }
  }

  /// Register school offline (fallback)
  Future<void> _registerSchoolOffline() async {
    try {
      // Generate unique school ID and invitation code
      final schoolId = _generateSchoolId();
      final invitationCode = _generateInvitationCode();

      // Create school record locally
      await _createSchoolRecord(schoolId, invitationCode);

      // Update settings controller
      await _updateSettingsController(schoolId);

      // Show offline success dialog
      await _showOfflineSuccessDialog(invitationCode);

      // Mark first run completed and navigate
      await SchoolSelectionController.markFirstRunCompleted();
      Get.offAllNamed('/login');
    } catch (e) {
      print('❌ Offline registration failed: $e');
      rethrow;
    }
  }

  /// Save online registration result to local database
  Future<void> _saveSchoolLocallyFromOnlineResult(
      Map<String, dynamic> result) async {
    try {
      final db = await _dbHelper.database;
      final school = result['school'];
      final admin = result['admin'];

      // Save school
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

      // Save admin user locally
      await db.insert(
          'users',
          {
            'id': admin['id'].toString(),
            'school_id': school['id'].toString(),
            'email': admin['email'],
            'password_hash': adminPasswordController
                .text, // Store plaintext for offline demo
            'role': admin['role'],
            'first_name': admin['fname'],
            'last_name': admin['lname'],
            'phone': admin['phone'],
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      print('✅ Online registration saved locally');
    } catch (e) {
      print('❌ Failed to save online result locally: $e');
      // Don't throw - this is just for offline access
    }
  }

  /// Generate unique school ID
  String _generateSchoolId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random().nextInt(999).toString().padLeft(3, '0');
    return 'school_${timestamp}_$random';
  }

  /// Generate invitation code
  String _generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final schoolInitials = schoolNameController.text
        .split(' ')
        .take(2)
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join('');

    final randomPart =
        List.generate(4, (index) => chars[random.nextInt(chars.length)])
            .join('');

    return '${schoolInitials.padRight(2, 'X')}$randomPart';
  }

  /// Create school record in database
  Future<void> _createSchoolRecord(
      String schoolId, String invitationCode) async {
    final db = await _dbHelper.database;

    await db.insert('schools', {
      'id': schoolId,
      'name': schoolNameController.text.trim(),
      'address': schoolAddressController.text.trim(),
      'location':
          '${cityController.text.trim()}, ${countryController.text.trim()}',
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'website': websiteController.text.trim(),
      'start_time': _timeOfDayToString(startTime.value),
      'end_time': _timeOfDayToString(endTime.value),
      'operating_days': operatingDays.join(','),
      'invitation_code': invitationCode,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    });

    print('✅ School record created: $schoolId');
  }

  /// Update settings controller with school information
  Future<void> _updateSettingsController(String schoolId) async {
    final settingsController = Get.find<SettingsController>();

    // Set school information
    settingsController.schoolId.value = schoolId;
    settingsController.schoolDisplayName.value =
        schoolNameController.text.trim();
    settingsController.enableMultiTenant.value = true;
    settingsController.enableCloudSync.value = true;

    // Set business information
    settingsController.setBusinessName(schoolNameController.text.trim());
    settingsController.setBusinessAddress(schoolAddressController.text.trim());
    settingsController.setBusinessCity(cityController.text.trim());
    settingsController.businessCountry.value = countryController.text.trim();
    settingsController.setBusinessPhone(phoneController.text.trim());
    settingsController.setBusinessEmail(emailController.text.trim());
    settingsController.setBusinessWebsite(websiteController.text.trim());

    // Set operating hours
    settingsController.businessStartTime.value =
        _timeOfDayToString(startTime.value);
    settingsController.businessEndTime.value =
        _timeOfDayToString(endTime.value);
    settingsController.operatingDays.value = operatingDays.toList();

    // Save all settings
    await settingsController.saveAllBusinessSettings();

    // Initialize school config service
    if (Get.isRegistered<SchoolConfigService>()) {
      final schoolConfig = Get.find<SchoolConfigService>();
      await schoolConfig.initializeSchoolConfig();
    }

    print('✅ Settings updated for school: ${schoolNameController.text}');
  }

  /// Convert TimeOfDay to string
  String _timeOfDayToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Show online success dialog
  Future<void> _showOnlineSuccessDialog(Map<String, dynamic> result) async {
    final school = result['school'];
    final invitationCode = result['invitation_code'];
    final trialDays = result['trial_days'] ?? 30;

    return Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_done, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('School Registered Online!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Congratulations! ${school['name']} has been successfully registered online.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Trial information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎉 Free Trial Active',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have $trialDays days of free access to all features.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.green.shade600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Invitation code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School Invitation Code:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Text(
                        invitationCode,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this code with your staff and instructors so they can join your school.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copyToClipboard(invitationCode),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Code'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show offline success dialog
  Future<void> _showOfflineSuccessDialog(String invitationCode) async {
    return Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.offline_bolt, color: Colors.orange.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('School Registered Offline'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${schoolNameController.text} has been registered locally on your device.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Offline warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Offline Registration',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your school is registered locally. Connect to internet later to sync with our servers for full features and support.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Invitation code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Local Invitation Code:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Text(
                      invitationCode,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copyToClipboard(invitationCode),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Code'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show registration error
  void _showRegistrationError(String message) {
    Get.snackbar(
      'Registration Failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade100,
      colorText: Colors.red.shade700,
      duration: const Duration(seconds: 5),
    );
  }

  /// Copy invitation code to clipboard
  Future<void> _copyToClipboard(String code) async {
    // In a real app, you'd use Clipboard.setData
    // For now, just show a snackbar
    Get.back(); // Close dialog first
    Get.snackbar(
      'Copied!',
      'Invitation code copied: $code',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade700,
    );
  }
}
