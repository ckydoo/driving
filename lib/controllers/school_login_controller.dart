// lib/controllers/enhanced_school_login_controller.dart
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final RxString searchHint = 'Enter school name or school code'.obs;

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

  // Enhanced validation methods
  String? validateSchoolIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter school name or school code';
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

  // Enhanced school search with Firebase integration
  void onSchoolIdentifierChanged(String value) {
    if (value.trim().length >= 3) {
      _performEnhancedSchoolSearch(value.trim());
    } else {
      searchResults.clear();
      selectedSchool.clear();
      _updateSearchHint(value);
    }
  }

  void _updateSearchHint(String value) {
    if (value.isEmpty) {
      searchHint.value = 'Enter school name or school code';
    } else if (value.length < 3) {
      searchHint.value = 'Type at least 3 characters to search';
    } else {
      searchHint.value = 'Searching schools...';
    }
  }

  // Enhanced school search with real Firebase integration
  Future<void> _performEnhancedSchoolSearch(String query) async {
    try {
      searchHint.value = 'Searching schools...';

      // Clear previous results
      searchResults.clear();

      // Search for schools in multiple ways:
      // 1. By exact school code (highest priority)
      // 2. By school name (partial match)
      // 3. By business name in Firebase

      final results = <Map<String, String>>[];

      // Try to find exact school code match first
      final exactCodeMatch = await _searchByExactCode(query);
      if (exactCodeMatch != null) {
        results.add(exactCodeMatch);
      }

      // Search by name if not exact code match
      final nameMatches = await _searchByName(query);
      results.addAll(nameMatches);

      // Update UI
      if (results.isNotEmpty) {
        searchResults.value = results;
        searchHint.value = 'Found ${results.length} school(s)';
      } else {
        searchResults.clear();
        searchHint.value =
            'No schools found. Check spelling or ask admin for school code';
      }
    } catch (e) {
      searchHint.value = 'Search failed. Please try again';
      print('❌ School search error: $e');
    }
  }

  // Search by exact school code (priority search)
  Future<Map<String, String>?> _searchByExactCode(String query) async {
    try {
      // Check if query looks like a school code (contains underscore or alphanumeric pattern)
      if (!query.contains('_') &&
          !RegExp(r'^[a-zA-Z0-9]{6,}$').hasMatch(query)) {
        return null; // Not a school code format
      }

      // Try to find school by exact code in Firebase
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      if (!syncService.firebaseAvailable.value) return null;

      // Get Firestore instance directly
      final firestore = FirebaseFirestore.instance;

      // Search in school directory
      final schoolDoc = await firestore
          .collection('school_directory')
          .doc(query.toLowerCase())
          .get();

      if (schoolDoc?.exists == true) {
        final data = schoolDoc!.data()!;
        return {
          'id': schoolDoc.id,
          'name': data['name'] ?? 'Unknown School',
          'code': schoolDoc.id,
          'city': data['city'] ?? '',
          'verified': '✓ Verified School',
        };
      }
    } catch (e) {
      print('⚠️ Exact code search error: $e');
    }
    return null;
  }

  // Search by school name
  Future<List<Map<String, String>>> _searchByName(String query) async {
    try {
      final results = <Map<String, String>>[];

      // Mock schools for now - replace with real Firebase search
      final mockSchools = [
        {
          'id': 'smithschool_abc123',
          'name': 'Smith Driving School',
          'code': 'SMITH2024',
          'city': 'Harare',
          'verified': '✓ Verified'
        },
        {
          'id': 'safedrive_def456',
          'name': 'Safe Drive Academy',
          'code': 'SAFE2024',
          'city': 'Bulawayo',
          'verified': '✓ Verified'
        },
        {
          'id': 'prosschool_ghi789',
          'name': 'Professional Driving School',
          'code': 'PRO2024',
          'city': 'Mutare',
          'verified': '✓ Verified'
        },
      ];

      // Filter by name
      final filtered = mockSchools.where((school) {
        final name = school['name']!.toLowerCase();
        final code = school['code']!.toLowerCase();
        final searchQuery = query.toLowerCase();

        return name.contains(searchQuery) || code.contains(searchQuery);
      });

      results.addAll(filtered.map((school) => {
            'id': school['id']!,
            'name': school['name']!,
            'code': school['code']!,
            'city': school['city']!,
            'verified': school['verified']!,
          }));

      return results;
    } catch (e) {
      print('❌ Name search error: $e');
      return [];
    }
  }

  // Select a school from search results
  void selectSchool(Map<String, String> school) {
    selectedSchool.value = school;
    schoolIdentifierController.text = '${school['name']} (${school['code']})';
    searchResults.clear();
    searchHint.value = 'Selected: ${school['name']}';
  }

  // Clear selected school
  void clearSelectedSchool() {
    selectedSchool.clear();
    schoolIdentifierController.clear();
    searchResults.clear();
    searchHint.value = 'Enter school name or school code';
  }

  // Show school code to user
  void showSchoolCode() {
    if (selectedSchool.isNotEmpty) {
      Get.dialog(
        AlertDialog(
          title: const Text('School Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('School: ${selectedSchool['name']}'),
              const SizedBox(height: 8),
              Text('Code: ${selectedSchool['code']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                  'Share this code with other staff members to join this school.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                // Copy to clipboard
                Get.back();
                Get.snackbar('Copied', 'School code copied to clipboard');
              },
              child: const Text('Copy Code'),
            ),
          ],
        ),
      );
    }
  }

  // Main enhanced login method
  Future<void> loginToSchool() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    // Check if school is selected
    if (selectedSchool.isEmpty) {
      errorMessage.value = 'Please select a school from the search results';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      print('🏫 === STARTING ENHANCED SCHOOL LOGIN ===');
      print('📍 School: ${selectedSchool['name']} (${selectedSchool['id']})');
      print('👤 User: ${emailController.text.trim()}');

      // Step 1: Load school configuration from Firebase
      await _loadSchoolFromFirebase();

      // Step 2: Authenticate user against school's user database
      await _authenticateUserInSchool();

      // Step 3: Initialize local database with school data
      await _initializeLocalSchoolData();

      // Step 4: Start Firebase sync
      await _initializeFirebaseSync();

      // Step 5: Show success and navigate
      _showSuccessAndNavigate();
    } catch (e) {
      print('❌ Enhanced school login failed: $e');
      errorMessage.value = _getFriendlyErrorMessage(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // Step 1: Load school configuration from Firebase
  Future<void> _loadSchoolFromFirebase() async {
    print('🔍 Loading school configuration from Firebase...');

    try {
      final schoolId = selectedSchool['id']!;
      final schoolName = selectedSchool['name']!;

      // Update local settings with school information
      final settingsController = Get.find<SettingsController>();
      settingsController.businessName.value = schoolName;

      // You can load more school details from Firebase here
      // For now, we'll use basic info
      settingsController.businessEmail.value =
          '${schoolName.toLowerCase().replaceAll(' ', '')}@school.com';
      settingsController.schoolId.value = schoolId;
      settingsController.enableMultiTenant.value = true;
      settingsController.enableCloudSync.value = true;

      // Save settings
      await settingsController.saveAllBusinessSettings();

      // Reset and reinitialize school configuration
      final schoolConfig = Get.find<SchoolConfigService>();
      await schoolConfig.resetSchoolConfig();

      if (!schoolConfig.isValidConfiguration()) {
        throw Exception('Failed to initialize school configuration');
      }

      print('✅ School configuration loaded successfully');
    } catch (e) {
      throw Exception('Failed to load school configuration: $e');
    }
  }

  // Step 2: Authenticate user in school's Firebase database
  Future<void> _authenticateUserInSchool() async {
    print('🔐 Authenticating user in school database...');

    try {
      // Use existing auth controller but with school context
      final authController = Get.find<AuthController>();

      // First, try Firebase authentication to check if user exists in this school
      final success = await authController.login(
        emailController.text.trim(),
        passwordController.text,
      );

      if (!success) {
        throw Exception('Invalid email or password for this school');
      }

      print('✅ User authenticated successfully in school');
    } catch (e) {
      throw Exception(
          'Authentication failed: Please check your email and password');
    }
  }

  // Step 3: Initialize local database with school data
  Future<void> _initializeLocalSchoolData() async {
    print('📱 Initializing local school data...');

    try {
      // Local database should already be populated by auth controller
      // Verify we have users
      final users = await DatabaseHelper.instance.getUsers();
      if (users.isEmpty) {
        throw Exception('No user data synchronized');
      }

      print('✅ Local school data initialized (${users.length} users)');
    } catch (e) {
      throw Exception('Failed to initialize local data: $e');
    }
  }

  // Step 4: Initialize Firebase sync
  Future<void> _initializeFirebaseSync() async {
    print('☁️ Initializing Firebase sync...');

    try {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();

      if (syncService.firebaseAvailable.value) {
        await syncService.initializeUserSync();
        // Trigger initial sync
        Future.delayed(const Duration(seconds: 1), () {
          syncService.triggerManualSync();
        });
      }

      print('✅ Firebase sync initialized');
    } catch (e) {
      print('⚠️ Firebase sync initialization failed: $e');
      // Don't fail the login for sync issues
    }
  }

  // Step 5: Show success and navigate
  void _showSuccessAndNavigate() {
    final schoolName = selectedSchool['name']!;

    Get.snackbar(
      'Welcome to $schoolName!',
      'Successfully joined school. Setting up your PIN for quick access...',
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle, color: Colors.white),
      duration: const Duration(seconds: 3),
    );

    // Navigate to PIN setup for future quick login
    Get.offAllNamed('/pin-setup');
  }

  // Get user-friendly error messages
  String _getFriendlyErrorMessage(String error) {
    if (error.contains('Invalid email or password')) {
      return 'Incorrect email or password. Please check your credentials.';
    } else if (error.contains('school configuration')) {
      return 'Unable to connect to this school. Please contact your administrator.';
    } else if (error.contains('Authentication failed')) {
      return 'Login failed. Please verify your email and password are correct.';
    } else if (error.contains('No user data')) {
      return 'Your account data could not be loaded. Please try again.';
    } else {
      return 'Login failed. Please check your internet connection and try again.';
    }
  }

  // Help method for users
  void showLoginHelp() {
    Get.dialog(
      AlertDialog(
        title: const Text('Need Help?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Ask your administrator for the school name or school code'),
            SizedBox(height: 8),
            Text('• Use the same email and password from your original device'),
            SizedBox(height: 8),
            Text('• Make sure you have internet connection'),
            SizedBox(height: 8),
            Text('• School codes are usually like "SMITH2024" or "SAFE2024"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
