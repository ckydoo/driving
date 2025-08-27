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
  final idnumberController = TextEditingController();

  // Reactive variables
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;
  final RxString currentStep = ''.obs;

  FirebaseFirestore? _firestore;
  firebase_auth.FirebaseAuth? _firebaseAuth;
  final RxBool firebaseInitialized = false.obs;
  @override
  void onInit() {
    super.onInit();
    _initializeFirebase();
  }

  // NEW: Proper Firebase initialization
  Future<void> _initializeFirebase() async {
    try {
      print('🔥 Initializing Firebase for school registration...');

      _firebaseAuth = firebase_auth.FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Test the connection
      await _firestore!.settings; // This will throw if not connected

      firebaseInitialized.value = true;
      print('✅ Firebase initialized successfully for school registration');
    } catch (e) {
      print('⚠️ Firebase initialization failed: $e');
      firebaseInitialized.value = false;

      // Don't throw here - allow local-only registration
      print('⚠️ Will proceed with local-only registration');
    }
  }

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
    idnumberController.dispose();
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

  String? validateIDNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Id Number is required';
    }
    if (value.trim().length < 7) {
      return 'Last name must be at least 7 characters';
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

  Future<void> registerSchool() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      print('🏫 === STARTING SCHOOL REGISTRATION ===');

      // Step 1: Update business/school settings
      currentStep.value = 'Updating school settings...';
      await _updateSchoolSettings();

      // Step 2: Initialize school configuration
      currentStep.value = 'Configuring school system...';
      await _initializeSchoolConfig();

      // Step 3: Create administrator account
      currentStep.value = 'Creating administrator account...';
      await _createAdministratorAccount();

      // Step 4: Initialize Firebase sync for this school (if available)
      if (firebaseInitialized.value) {
        currentStep.value = 'Setting up cloud synchronization...';
        await _initializeFirebaseSync();

        // Step 5: Create initial shared data in Firebase (if available)
        currentStep.value = 'Creating initial school data...';
        await _createInitialSharedData();
      } else {
        print('⚠️ Skipping Firebase steps - not available');
      }

      // Step 6: Auto-login and setup sync
      currentStep.value = 'Completing setup...';
      await _finalizeSetupAndLogin();

      print('🎉 School registration completed successfully!');
    } catch (e) {
      print('❌ School registration failed: $e');
      errorMessage.value = 'Registration failed: ${e.toString()}';
    } finally {
      isLoading.value = false;
      currentStep.value = '';
    }
  }

  // FIXED: Create administrator account with better error handling
  Future<void> _createAdministratorAccount() async {
    print('👤 Creating administrator account...');

    try {
      final email = adminEmailController.text.trim().toLowerCase();
      final password = passwordController.text;

      // Step 1: Try to create Firebase user (if Firebase is available)
      firebase_auth.User? firebaseUser;

      if (firebaseInitialized.value && _firebaseAuth != null) {
        try {
          print('🔥 Creating Firebase user account...');
          final credential =
              await _firebaseAuth!.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          firebaseUser = credential.user;
          print('✅ Firebase user created: ${firebaseUser?.uid}');
        } catch (e) {
          print('⚠️ Firebase user creation failed: $e');
          print('⚠️ Continuing with local-only account');
          // Continue with local account creation - don't fail here
        }
      } else {
        print('⚠️ Firebase not available, creating local-only account');
      }

      // Step 2: Create local User object
      final adminUser = User(
        fname: adminFirstNameController.text.trim(),
        lname: adminLastNameController.text.trim(),
        idnumber: idnumberController.text.trim().isNotEmpty
            ? idnumberController.text.trim()
            : '', // Handle empty ID number
        email: email,
        password: password, // Will be hashed by the database layer
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        gender: 'Male', // Default - can be updated later
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

      // Step 4: Save user to Firebase Firestore (only if Firebase user was created)
      if (firebaseUser != null && firebaseInitialized.value) {
        try {
          await _saveUserToFirestore(firebaseUser, adminUser);
          print('✅ Administrator account saved to Firebase Firestore');
        } catch (e) {
          print('⚠️ Failed to save to Firestore, but local user created: $e');
          // Don't fail the registration - user was created locally
        }
      }

      print('✅ Administrator account creation completed');
    } catch (e) {
      print('❌ Error creating administrator account: $e');
      print('📄 Stack trace: ${StackTrace.current}');
      throw Exception('Failed to create administrator account: $e');
    }
  }

  // FIXED: Save user to Firestore with proper null checking
  Future<void> _saveUserToFirestore(
      firebase_auth.User firebaseUser, User localUser) async {
    // CRITICAL: Check if Firestore is available before proceeding
    if (_firestore == null || !firebaseInitialized.value) {
      print('⚠️ Firestore not available, skipping cloud save');
      return; // Don't throw - this is optional
    }

    try {
      print('💾 Saving user to Firestore...');

      final schoolConfig = Get.find<SchoolConfigService>();
      final schoolId = schoolConfig.schoolId.value;

      if (schoolId.isEmpty) {
        print('⚠️ No school ID found, skipping Firestore save');
        return; // Don't throw - this is optional
      }

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
        'idnumber': localUser.idnumber ?? '', // Handle null ID number
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
          .doc(firebaseUser.uid); // Use Firebase UID as doc ID

      // Check if document already exists
      final existingDoc = await userDocRef.get();

      if (existingDoc.exists) {
        print('📝 Updating existing user document: ${firebaseUser.uid}');
        await userDocRef.update(userData);
      } else {
        print('➕ Creating new user document: ${firebaseUser.uid}');
        await userDocRef.set(userData);
      }

      // Mark local user as synced to prevent duplicate sync
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
      // IMPORTANT: Don't throw here - allow registration to continue
      // The user was created locally, which is the most important part
      print('⚠️ Registration will continue with local-only user');
    }
  }

// 1. FIXED: _initializeFirebaseSync method
  Future<void> _initializeFirebaseSync() async {
    if (!firebaseInitialized.value) {
      print('⚠️ Firebase not available, skipping sync initialization');
      return;
    }

    try {
      print('🔄 Setting up Firebase sync for new school...');

      // Check if sync service is available
      if (!Get.isRegistered<FixedLocalFirstSyncService>()) {
        print('⚠️ Sync service not registered, skipping sync initialization');
        return;
      }

      final syncService = Get.find<FixedLocalFirstSyncService>();

      // Verify sync service is ready
      if (!syncService.firebaseAvailable.value) {
        print('⚠️ Sync service Firebase not available');
        return;
      }

      // Create initial Firebase structure for the school
      await _createInitialFirebaseStructure();

      // Initialize sync for the new school
      print('📦 Creating initial shared data...');
      try {
        await syncService.createInitialSharedData();
        print('✅ Initial shared data created');
      } catch (e) {
        print('⚠️ Failed to create initial shared data: $e');
      }

      // Trigger initial sync
      print('🔄 Performing initial sync...');
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await syncService.triggerManualSync();
          print('✅ Initial sync completed');
        } catch (e) {
          print('⚠️ Initial sync failed (non-critical): $e');
        }
      });

      print('✅ Firebase sync initialization completed');
    } catch (e) {
      print('⚠️ Firebase sync setup failed: $e');
      // Don't throw - registration should continue
    }
  }

// 2. NEW: Helper method to create initial Firebase structure
  Future<void> _createInitialFirebaseStructure() async {
    if (_firestore == null || !firebaseInitialized.value) {
      print('⚠️ Firestore not available for structure creation');
      return;
    }

    try {
      final schoolConfig = Get.find<SchoolConfigService>();
      final schoolId = schoolConfig.schoolId.value;

      if (schoolId.isEmpty) {
        print('⚠️ School ID empty, cannot create Firebase structure');
        return;
      }

      print('🏫 Creating Firebase structure for school: $schoolId');

      // Create school metadata document
      final schoolDocRef = _firestore!.collection('schools').doc(schoolId);
      final settingsController = Get.find<SettingsController>();

      final schoolMetadata = {
        'school_id': schoolId,
        'school_name': settingsController.businessName.value,
        'business_address': settingsController.businessAddress.value,
        'business_phone': settingsController.businessPhone.value,
        'business_email': settingsController.businessEmail.value,
        'business_city': settingsController.businessCity.value,
        'business_country': settingsController.businessCountry.value,
        'created_at': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp(),
        'status': 'active',
        'subscription_status': 'active',
        'version': 1,
      };

      await schoolDocRef.set(schoolMetadata, SetOptions(merge: true));
      print('✅ School metadata created in Firebase');
    } catch (e) {
      print('❌ Failed to create Firebase structure: $e');
      // Don't throw - this is not critical
    }
  }

// 3. FIXED: _createInitialSharedData method
  Future<void> _createInitialSharedData() async {
    if (!firebaseInitialized.value) {
      print('⚠️ Firebase not available, skipping initial data creation');
      return;
    }

    try {
      print('📦 Creating initial shared data in Firebase...');

      // Check if sync service is available and use it
      if (Get.isRegistered<FixedLocalFirstSyncService>()) {
        final syncService = Get.find<FixedLocalFirstSyncService>();

        if (syncService.firebaseAvailable.value) {
          await syncService.createInitialSharedData();
          print('✅ Initial shared data created via sync service');
        } else {
          print('⚠️ Sync service Firebase not available');
          // Create basic structure manually
          await _createBasicFirebaseStructure();
        }
      } else {
        print('⚠️ Sync service not available, creating basic structure');
        // Create basic structure manually
        await _createBasicFirebaseStructure();
      }
    } catch (e) {
      print('⚠️ Failed to create initial shared data: $e');
      // Don't fail registration for this
    }
  }

// 4. NEW: Create basic Firebase structure manually if sync service fails
  Future<void> _createBasicFirebaseStructure() async {
    if (_firestore == null) return;

    try {
      final schoolConfig = Get.find<SchoolConfigService>();
      final schoolId = schoolConfig.schoolId.value;

      if (schoolId.isEmpty) return;

      print('📦 Creating basic Firebase structure manually...');

      final schoolRef = _firestore!.collection('schools').doc(schoolId);

      // Create essential collections with initial documents
      final collections = [
        'users',
        'courses',
        'fleet',
        'schedules',
        'invoices'
      ];

      final batch = _firestore!.batch();

      for (String collection in collections) {
        // Create a system document to establish the collection
        final systemDocRef = schoolRef.collection(collection).doc('_system');
        batch.set(systemDocRef, {
          'collection': collection,
          'created_at': FieldValue.serverTimestamp(),
          'initialized': true,
        });
      }

      await batch.commit();
      print('✅ Basic Firebase structure created');
    } catch (e) {
      print('❌ Failed to create basic Firebase structure: $e');
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

  bool get canUseFirebase => firebaseInitialized.value;

  // NEW: Get Firebase status for debugging
  String get firebaseStatus {
    if (firebaseInitialized.value) {
      return 'Connected';
    } else {
      return 'Not Available';
    }
  }
}
