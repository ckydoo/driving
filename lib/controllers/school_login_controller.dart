// lib/controllers/school_login_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/database_helper.dart';

class SchoolLoginController extends GetxController {
  // Form key
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Text controllers
  final schoolIdentifierController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Reactive variables
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool obscurePassword = true.obs;
  final RxList<Map<String, String>> searchResults = <Map<String, String>>[].obs;
  final RxMap<String, String> selectedSchool = <String, String>{}.obs;

  @override
  void onClose() {
    schoolIdentifierController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  // Validation methods
  String? validateSchoolIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter school name or ID';
    }
    if (value.trim().length < 3) {
      return 'School identifier must be at least 3 characters';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  // Search for schools
  void onSchoolIdentifierChanged(String value) {
    if (value.trim().length >= 3) {
      _performSchoolSearch(value.trim());
    } else {
      searchResults.clear();
      selectedSchool.clear();
    }
  }

  void searchSchools() {
    final query = schoolIdentifierController.text.trim();
    if (query.length >= 3) {
      _performSchoolSearch(query);
    } else {
      Get.snackbar(
        'Search Query Too Short',
        'Please enter at least 3 characters to search',
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade800,
      );
    }
  }

  // Perform school search (mock implementation - replace with real search)
  void _performSchoolSearch(String query) {
    // Mock school data - in real implementation, this would search:
    // 1. Local known schools
    // 2. Firebase collections
    // 3. Cache of previously accessed schools

    final mockSchools = [
      {
        'id': 'abc_driving_123',
        'name': 'ABC Driving School',
        'city': 'New York'
      },
      {
        'id': 'xyz_academy_456',
        'name': 'XYZ Driving Academy',
        'city': 'Los Angeles'
      },
      {
        'id': 'safe_drive_789',
        'name': 'Safe Drive Institute',
        'city': 'Chicago'
      },
      {
        'id': 'pro_drivers_101',
        'name': 'Pro Drivers School',
        'city': 'Houston'
      },
    ];

    final results = mockSchools.where((school) {
      final name = school['name']!.toLowerCase();
      final id = school['id']!.toLowerCase();
      final searchQuery = query.toLowerCase();

      return name.contains(searchQuery) || id.contains(searchQuery);
    }).toList();

    searchResults.value = results
        .map((school) => {
              'id': school['id']!,
              'name': school['name']!,
              'city': school['city']!,
            })
        .toList();
  }

  // Select a school from search results
  void selectSchool(Map<String, String> school) {
    selectedSchool.value = school;
    schoolIdentifierController.text = school['name']!;
    searchResults.clear();
  }

  // Clear selected school
  void clearSelectedSchool() {
    selectedSchool.clear();
    schoolIdentifierController.clear();
    searchResults.clear();
  }

  // Main login method
  Future<void> loginToSchool() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    // Check if school is selected or identifier is provided
    if (selectedSchool.isEmpty &&
        schoolIdentifierController.text.trim().isEmpty) {
      errorMessage.value = 'Please select a school or enter school details';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      print('🏫 === STARTING SCHOOL LOGIN ===');

      // Step 1: Load school configuration
      await _loadSchoolConfiguration();

      // Step 2: Authenticate user
      await _authenticateUser();

      // Step 3: Show success and navigate to PIN setup
      _showSuccessAndNavigate();
    } catch (e) {
      print('❌ School login failed: $e');
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // Step 1: Load school configuration
  Future<void> _loadSchoolConfiguration() async {
    print('🏫 Loading school configuration...');

    // In a real implementation, this would:
    // 1. Fetch school details from Firebase using school ID
    // 2. Load school settings and configuration
    // 3. Update local settings with school information

    String schoolId;
    String schoolName;

    if (selectedSchool.isNotEmpty) {
      schoolId = selectedSchool['id']!;
      schoolName = selectedSchool['name']!;
    } else {
      // Try to parse identifier as school ID or name
      final identifier = schoolIdentifierController.text.trim();

      // Mock parsing - in real implementation, search for school by name/ID
      if (identifier.contains('_')) {
        schoolId = identifier;
        schoolName = identifier
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1)
                : '')
            .join(' ');
      } else {
        schoolName = identifier;
        schoolId = identifier.toLowerCase().replaceAll(' ', '_') + '_auto';
      }
    }

    // Update settings with school information
    final settingsController = Get.find<SettingsController>();
    settingsController.businessName.value = schoolName;

    // You might also load other school settings from Firebase here
    settingsController.businessAddress.value =
        'School Address'; // Load from Firebase
    settingsController.businessPhone.value =
        'School Phone'; // Load from Firebase
    settingsController.businessEmail.value =
        'school@email.com'; // Load from Firebase

    await settingsController.saveAllBusinessSettings();

    // Reset and reinitialize school configuration
    final schoolConfig = Get.find<SchoolConfigService>();
    await schoolConfig.resetSchoolConfig();

    if (!schoolConfig.isValidConfiguration()) {
      throw Exception('Failed to load school configuration');
    }

    print('✅ School configuration loaded:');
    print('   School ID: ${schoolConfig.schoolId.value}');
    print('   School Name: ${schoolConfig.schoolName.value}');
  }

  // Step 2: Authenticate user
  Future<void> _authenticateUser() async {
    print('🔐 Authenticating user...');

    final authController = Get.find<AuthController>();

    final success = await authController.login(
      emailController.text.trim(),
      passwordController.text,
    );

    if (!success) {
      throw Exception('Invalid email or password');
    }

    print('✅ User authenticated successfully');
  }

  // Step 3: Show success and navigate
  void _showSuccessAndNavigate() {
    final schoolName = selectedSchool.isNotEmpty
        ? selectedSchool['name']!
        : schoolIdentifierController.text.trim();

    Get.snackbar(
      'Welcome!',
      'Successfully joined $schoolName. Please set up your PIN for quick access.',
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle, color: Colors.white),
      duration: const Duration(seconds: 3),
    );

    // Navigate to PIN setup
    Get.offAllNamed('/pin-setup');
  }

  // Show QR code scanner
  void showQRScanner() {
    Get.dialog(
      AlertDialog(
        title: const Text('QR Code Scanner'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              'QR Code scanning feature will be implemented here.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Ask your school administrator for a QR code to quickly join the school.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              // Mock QR code result
              _handleQRCodeResult(
                  'abc_driving_123|ABC Driving School|New York');
            },
            child: const Text('Simulate Scan'),
          ),
        ],
      ),
    );
  }

  // Handle QR code scan result
  void _handleQRCodeResult(String qrData) {
    try {
      // Parse QR code data (format: school_id|school_name|location)
      final parts = qrData.split('|');
      if (parts.length >= 2) {
        final school = {
          'id': parts[0],
          'name': parts[1],
          'city': parts.length > 2 ? parts[2] : 'Unknown',
        };

        selectSchool(school);

        Get.snackbar(
          'School Found!',
          'Selected ${school['name']} from QR code',
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
          icon: const Icon(Icons.check_circle, color: Colors.green),
        );
      } else {
        throw Exception('Invalid QR code format');
      }
    } catch (e) {
      Get.snackbar(
        'QR Code Error',
        'Unable to parse QR code. Please try again or enter school details manually.',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        icon: const Icon(Icons.error, color: Colors.red),
      );
    }
  }
}
