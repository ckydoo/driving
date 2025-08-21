// lib/controllers/enhanced_school_registration_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:driving/models/user.dart';

class SchoolRegistrationController extends GetxController {
  // Form key
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Text controllers
  final schoolNameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final adminFirstNameController = TextEditingController();
  final adminLastNameController = TextEditingController();
  final adminEmailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Reactive variables
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;
  final RxString currentStep = ''.obs;

  @override
  void onClose() {
    schoolNameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    adminFirstNameController.dispose();
    adminLastNameController.dispose();
    adminEmailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword.value = !obscureConfirmPassword.value;
  }

  // Validation methods (same as before)
  String? validateSchoolName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'School name is required';
    }
    if (value.trim().length < 3) {
      return 'School name must be at least 3 characters';
    }
    return null;
  }

  String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required';
    }
    if (value.trim().length < 10) {
      return 'Please enter a complete address';
    }
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'First name is required';
    }
    if (value.trim().length < 2) {
      return 'First name must be at least 2 characters';
    }
    return null;
  }

  String? validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Last name is required';
    }
    if (value.trim().length < 2) {
      return 'Last name must be at least 2 characters';
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
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Enhanced registration method with Firebase sync
  Future<void> registerSchool() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      print('🏫 === STARTING ENHANCED SCHOOL REGISTRATION WITH FIREBASE ===');

      // Step 1: Update business/school settings
      currentStep.value = 'Updating school settings...';
      await _updateSchoolSettings();

      // Step 2: Initialize school configuration
      currentStep.value = 'Configuring school system...';
      await _initializeSchoolConfig();

      // Step 3: Create administrator account
      currentStep.value = 'Creating administrator account...';
      await _createAdministratorAccount();

      // Step 4: Initialize Firebase sync for this school
      currentStep.value = 'Setting up cloud synchronization...';
      await _initializeFirebaseSync();

      // Step 5: Create initial shared data in Firebase
      currentStep.value = 'Creating initial school data...';
      await _createInitialSharedData();

      // Step 6: Auto-login and setup sync
      currentStep.value = 'Completing setup...';
      await _finalizeSetupAndLogin();
    } catch (e) {
      print('❌ School registration failed: $e');
      errorMessage.value = 'Registration failed: ${e.toString()}';
    } finally {
      isLoading.value = false;
      currentStep.value = '';
    }
  }

  // Step 1: Update school settings with enhanced multi-tenant config
  Future<void> _updateSchoolSettings() async {
    print('📋 Updating enhanced school settings...');

    final settingsController = Get.find<SettingsController>();

    // Update business information
    settingsController.businessName.value = schoolNameController.text.trim();
    settingsController.businessAddress.value = addressController.text.trim();
    settingsController.businessPhone.value = phoneController.text.trim();
    settingsController.businessEmail.value = adminEmailController.text.trim();

    // Enable multi-tenant features
    settingsController.enableMultiTenant.value = true;
    settingsController.enableCloudSync.value = true;

    // Set default values for other fields if needed
    if (settingsController.businessCity.value.isEmpty) {
      settingsController.businessCity.value = 'City'; // Can be updated later
    }
    if (settingsController.businessCountry.value.isEmpty) {
      settingsController.businessCountry.value =
          'Country'; // Can be updated later
    }

    // Save all settings to database
    await settingsController.saveAllBusinessSettings();

    print('✅ Enhanced school settings updated successfully');
  }

  // Step 2: Initialize school configuration with Firebase preparation
  Future<void> _initializeSchoolConfig() async {
    print('🏫 Initializing school configuration for Firebase sync...');

    final schoolConfig = Get.find<SchoolConfigService>();

    // Force regenerate school configuration with new business info
    await schoolConfig.resetSchoolConfig();

    // Verify school configuration
    if (!schoolConfig.isValidConfiguration()) {
      throw Exception('Failed to generate valid school configuration');
    }

    print('✅ School configuration initialized for Firebase:');
    print('   School ID: ${schoolConfig.schoolId.value}');
    print('   School Name: ${schoolConfig.schoolName.value}');
    print('   Firebase Path: ${schoolConfig.getCollectionPath("users")}');
  }

  // Step 3: Create administrator account with Firebase sync ready
  Future<void> _createAdministratorAccount() async {
    print('👤 Creating administrator account for multi-tenant system...');

    final adminUser = User(
      fname: adminFirstNameController.text.trim(),
      lname: adminLastNameController.text.trim(),
      email: adminEmailController.text.trim().toLowerCase(),
      password: passwordController.text, // Will be hashed by the model
      phone: phoneController.text.trim(),
      address: addressController.text.trim(),
      gender: 'Not Specified', // Can be updated later in profile
      idnumber: 'ADMIN001', // Generate unique ID
      role: 'admin',
      status: 'Active',
      date_of_birth: DateTime.now().subtract(const Duration(days: 25 * 365)),
      created_at: DateTime.now(),
    );

    // Save admin user to local database
    await DatabaseHelper.instance.insertUser(adminUser.toJson() as User);

    print('✅ Administrator account created (ready for Firebase sync)');
  }

  // Step 4: Initialize Firebase sync for the new school
  Future<void> _initializeFirebaseSync() async {
    print('🔄 Initializing Firebase sync for new school...');

    try {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();

      if (syncService.firebaseAvailable.value) {
        // Ensure school config is properly set up for sync
        await syncService.setupAutomaticSync();
        print('✅ Firebase sync initialized for school');
      } else {
        print('⚠️ Firebase not available, will sync when online');
      }
    } catch (e) {
      print('⚠️ Firebase sync initialization failed: $e');
      // Don't fail the registration, just log the issue
    }
  }

  // Step 5: Create initial shared data in Firebase
  Future<void> _createInitialSharedData() async {
    print('📦 Creating initial shared data in Firebase...');

    try {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();

      if (syncService.firebaseAvailable.value) {
        await syncService.createInitialSharedData();
        print('✅ Initial shared data created in Firebase');
      } else {
        print('⚠️ Firebase not available, will create data when online');
      }
    } catch (e) {
      print('⚠️ Failed to create initial shared data: $e');
      // Don't fail registration for this
    }
  }

  // Step 6: Finalize setup and auto-login
  Future<void> _finalizeSetupAndLogin() async {
    print('🎯 Finalizing setup and performing auto-login...');

    try {
      // Auto-login the admin user
      final authController = Get.find<AuthController>();

      final success = await authController.login(
        adminEmailController.text.trim().toLowerCase(),
        passwordController.text,
      );

      if (success) {
        // Initialize user-specific sync
        final syncService = Get.find<MultiTenantFirebaseSyncService>();
        if (syncService.firebaseAvailable.value) {
          await syncService.initializeUserSync();
        }

        _showSuccessAndNavigate();
      } else {
        throw Exception('Auto-login failed after registration');
      }
    } catch (e) {
      print('⚠️ Auto-login failed: $e');
      // Still show success but navigate to login
      _showSuccessAndNavigateToLogin();
    }
  }

  // Show success and navigate to PIN setup
  void _showSuccessAndNavigate() {
    Get.snackbar(
      'School Created Successfully!',
      'Your school has been registered and cloud sync is enabled. Please set up your PIN for quick access.',
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle, color: Colors.white),
      duration: const Duration(seconds: 4),
    );

    // Navigate to PIN setup
    Get.offAllNamed('/pin-setup');
  }

  // Show success but navigate to login (fallback)
  void _showSuccessAndNavigateToLogin() {
    Get.snackbar(
      'School Created Successfully!',
      'Your school has been registered. Please log in with your credentials.',
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle, color: Colors.white),
      duration: const Duration(seconds: 4),
    );

    // Navigate to login
    Get.offAllNamed('/login');
  }
}
