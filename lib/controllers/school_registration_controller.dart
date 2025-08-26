// lib/controllers/enhanced_school_registration_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driving/services/firebase_school_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/models/user.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  FirebaseFirestore? _firestore;

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

  // Fix for _createAdministratorAccount method in school_registration_controller.dart
// Replace your existing _createAdministratorAccount method with this:

  Future<void> _createAdministratorAccount() async {
    print('👤 Creating administrator account for multi-tenant system...');

    try {
      final email = adminEmailController.text.trim().toLowerCase();
      final password = passwordController.text;

      // Step 1: Create Firebase user first (for Firebase-first approach)
      print('🔥 Creating Firebase user account...');
      firebase_auth.FirebaseAuth? firebaseAuth;
      firebase_auth.User? firebaseUser;

      try {
        firebaseAuth = firebase_auth.FirebaseAuth.instance;
        final credential = await firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        firebaseUser = credential.user;
        print('✅ Firebase user created: ${firebaseUser?.uid}');
      } catch (e) {
        print('⚠️ Firebase user creation failed: $e');
        print('⚠️ Continuing with local-only account');
        // Continue with local account creation
      }

      // Step 2: Create local User object
      final adminUser = User(
        fname: adminFirstNameController.text.trim(),
        lname: adminLastNameController.text.trim(),
        email: email,
        password: password, // Will be hashed by the database layer
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        gender: 'Male',
        idnumber: '',
        role: 'admin',
        status: 'Active',
        date_of_birth: DateTime.now().subtract(const Duration(days: 25 * 365)),
        created_at: DateTime.now(),
      );

      print('📝 User object created successfully');
      print('👤 Email: ${adminUser.email}');
      print('🔑 Role: ${adminUser.role}');

      // Step 3: Insert user into local database
      await DatabaseHelper.instance.insertUser(adminUser);
      print('✅ Administrator account created successfully in local database');

      // Step 4: Save user to Firebase Firestore if Firebase user was created
      if (firebaseUser != null) {
        await _saveUserToFirestore(firebaseUser, adminUser);
        print('✅ Administrator account saved to Firebase Firestore');
      }
    } catch (e) {
      print('❌ Error creating administrator account: $e');
      print('📄 Stack trace: ${StackTrace.current}');
      throw Exception('Failed to create administrator account: $e');
    }
  }

// FIXED: Replace your existing _saveUserToFirestore method with this
  Future<void> _saveUserToFirestore(
      firebase_auth.User firebaseUser, User localUser) async {
    try {
      final schoolConfig = Get.find<SchoolConfigService>();
      final schoolId = schoolConfig.schoolId.value;

      if (schoolId.isEmpty) {
        print('⚠️ No school ID found, skipping Firestore save');
        return;
      }

      print('💾 Saving user to Firestore with consistent ID strategy...');

      // Prepare user data for Firebase
      final userData = {
        'firebase_uid': firebaseUser.uid,
        'local_id': localUser.id, // Store local ID for reference
        'fname': localUser.fname,
        'lname': localUser.lname,
        'email': localUser.email.toLowerCase(),
        'phone': localUser.phone,
        'address': localUser.address,
        'gender': localUser.gender,
        'idnumber': localUser.idnumber,
        'role': localUser.role,
        'status': localUser.status,
        'date_of_birth': localUser.date_of_birth?.toIso8601String(),
        'created_at': localUser.created_at?.toIso8601String(),
        'last_modified': DateTime.now().toIso8601String(),
        'firebase_synced': 1,
        'school_id': schoolId,
        'sync_source': 'registration', // Mark as created during registration
      };

      // Use Firebase UID as the document ID for consistency
      final userDocRef = _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(firebaseUser
              .uid); // CONSISTENT: Always use Firebase UID as doc ID

      // Check if document already exists
      final existingDoc = await userDocRef.get();

      if (existingDoc.exists) {
        print('📝 Updating existing user document: ${firebaseUser.uid}');
        await userDocRef.update(userData);
      } else {
        print('➕ Creating new user document: ${firebaseUser.uid}');
        await userDocRef.set(userData);
      }

      // CRITICAL: Mark local user as synced to prevent duplicate sync
      if (localUser.id != null) {
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'users',
          {'firebase_synced': 1, 'firebase_uid': firebaseUser.uid},
          where: 'id = ?',
          whereArgs: [localUser.id],
        );
        print('✅ Local user marked as synced: ${localUser.id}');
      }

      print('✅ User saved to Firestore successfully');
      print('   Document ID: ${firebaseUser.uid}');
      print('   Local ID: ${localUser.id}');
      print('   Email: ${firebaseUser.email}');
    } catch (e) {
      print('❌ Error saving user data to Firestore: $e');
      throw Exception('Failed to save user data to cloud: $e');
    }
  }

// Also update your _finalizeSetupAndLogin method:
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
        print('✅ Auto-login successful');

        // Initialize user-specific sync
        final syncService = Get.find<FixedLocalFirstSyncService>();
        if (syncService.firebaseAvailable.value) {
          try {
            await syncService.syncWithFirebase();
            print('✅ User sync initialized');
          } catch (e) {
            print('⚠️ User sync initialization failed: $e');
          }
        }

        _showSuccessAndNavigate();
      } else {
        print('⚠️ Auto-login failed, but registration was successful');
        // Still show success but navigate to login
        _showSuccessAndNavigateToLogin();
      }
    } catch (e) {
      print('⚠️ Auto-login failed: $e');
      // Still show success but navigate to login
      _showSuccessAndNavigateToLogin();
    }
  }

// Replace your _initializeFirebaseSync method in school_registration_controller.dart

// Step 4: Initialize Firebase sync for the new school
  Future<void> _initializeFirebaseSync() async {
    print('🔄 Initializing Firebase sync for new school...');

    try {
      final syncService = Get.find<FixedLocalFirstSyncService>();

      if (!syncService.firebaseAvailable.value) {
        print('⚠️ Firebase not available, skipping sync setup');
        return;
      }

      // Get school configuration
      final schoolConfig = Get.find<SchoolConfigService>();
      final settingsController = Get.find<SettingsController>();

      print('🔄 School ID: ${schoolConfig.schoolId.value}');
      print('🔄 Business Name: ${settingsController.businessName.value}');
      print('🔄 Business Address: ${settingsController.businessAddress.value}');

      // Prepare admin user data for Firebase
      final adminUserData = {
        'firebase_uid': '', // Will be updated later
        'fname': adminFirstNameController.text.trim(),
        'lname': adminLastNameController.text.trim(),
        'email': adminEmailController.text.trim().toLowerCase(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'role': 'admin',
        'status': 'active',
        'created_during_registration': true,
      };

      print('👥 Admin user data prepared');

      print('✅ Firebase school creation completed successfully');
    } catch (e) {
      print('❌ Firebase sync initialization failed: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      // Don't throw - allow registration to continue without Firebase
      print('⚠️ Continuing registration without Firebase sync');
    }
  }

// Helper method to store Firebase school ID locally
  Future<void> _storeFirebaseSchoolId(String firebaseSchoolId) async {
    try {
      print('💾 Storing Firebase school ID locally: $firebaseSchoolId');

      final db = await DatabaseHelper.instance.database;

      // Store in app_settings table
      await db.insert(
          'settings',
          {
            'key': 'firebase_school_id',
            'value': firebaseSchoolId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      // Also store in a dedicated firebase_config table if it exists
      try {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS firebase_config (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          school_id TEXT,
          firebase_school_id TEXT,
          created_at TEXT,
          UNIQUE(school_id)
        )
      ''');

        final schoolConfig = Get.find<SchoolConfigService>();
        await db.insert(
            'firebase_config',
            {
              'school_id': schoolConfig.schoolId.value,
              'firebase_school_id': firebaseSchoolId,
              'created_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        print('⚠️ Could not create firebase_config table: $e');
      }

      print('✅ Firebase school ID stored successfully');
    } catch (e) {
      print('❌ Failed to store Firebase school ID: $e');
      // Don't throw - this is not critical
    }
  }

  // Step 5: Create initial shared data in Firebase
  Future<void> _createInitialSharedData() async {
    print('📦 Creating initial shared data in Firebase...');

    try {
      final syncService = Get.find<FixedLocalFirstSyncService>();

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
