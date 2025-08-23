// lib/controllers/simple_school_join_controller.dart
import 'package:driving/controllers/auth_controller_extension.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:driving/models/user.dart' as app_user;

class SchoolJoinController extends GetxController {
  // Form key
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Text controllers
  final schoolNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Reactive variables
  final RxBool isLoading = false.obs;
  final RxBool isDownloading = false.obs;
  final RxString statusMessage = ''.obs;
  final RxString errorMessage = ''.obs;
  final RxBool obscurePassword = true.obs;
  final RxDouble downloadProgress = 0.0.obs;

  // Firebase instances
  FirebaseFirestore? _firestore;
  firebase_auth.FirebaseAuth? _firebaseAuth;

  @override
  void onInit() {
    super.onInit();
    _initializeFirebase();
  }

  @override
  void onClose() {
    schoolNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  /// Initialize Firebase services
  void _initializeFirebase() {
    try {
      _firestore = FirebaseFirestore.instance;
      _firebaseAuth = firebase_auth.FirebaseAuth.instance;
      print('✅ Firebase services initialized for school join');
    } catch (e) {
      print('❌ Firebase initialization failed: $e');
    }
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  // Validation methods
  String? validateSchoolName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter school name or ID';
    }
    if (value.trim().length < 3) {
      return 'School name must be at least 3 characters';
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

  /// Main method to join school - simplified flow
  Future<void> joinSchool() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (_firestore == null || _firebaseAuth == null) {
      errorMessage.value =
          'Firebase not available. Please check your internet connection.';
      return;
    }

    isLoading.value = true;
    isDownloading.value = false;
    errorMessage.value = '';
    statusMessage.value = 'Searching for school...';

    try {
      print('🏫 === STARTING SIMPLE SCHOOL JOIN ===');

      // Step 1: Search for school in Firebase
      final schoolData = await _searchSchoolInFirebase();
      if (schoolData == null) {
        throw Exception(
            'School not found. Please check the school name or ID.');
      }

      statusMessage.value = 'School found! Checking credentials...';

      // Step 2: Authenticate user in Firebase
      final userData = await _authenticateUserInFirebase(schoolData);
      if (userData == null) {
        throw Exception('Invalid email or password for this school.');
      }

      statusMessage.value =
          'Authentication successful! Setting up local environment...';

      // Step 3: Set up local school configuration
      await _setupLocalSchoolConfig(schoolData);

      statusMessage.value = 'Downloading school data...';
      isDownloading.value = true;

      // Step 4: Download and sync all school data to offline database
      await _downloadSchoolDataToOffline(schoolData, userData);

      statusMessage.value = 'Finalizing setup...';

      // Step 5: Set up local authentication
      await _setupLocalAuthentication(userData);

      // Step 6: Complete setup and navigate
      await _completeSetupAndNavigate(schoolData);
    } catch (e) {
      print('❌ School join failed: $e');
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
      isDownloading.value = false;
      statusMessage.value = '';
      downloadProgress.value = 0.0;
    }
  }

  /// Step 1: Search for school in Firebase
  Future<Map<String, dynamic>?> _searchSchoolInFirebase() async {
    try {
      final searchTerm = schoolNameController.text.trim().toLowerCase();

      // First try to find by exact school ID
      QuerySnapshot schoolSnapshot = await _firestore!
          .collection('schools')
          .where('schoolId', isEqualTo: searchTerm)
          .limit(1)
          .get();

      if (schoolSnapshot.docs.isNotEmpty) {
        final schoolDoc = schoolSnapshot.docs.first;
        return {
          'id': schoolDoc.id,
          'schoolId': schoolDoc.data() as Map<String, dynamic>,
          ...schoolDoc.data() as Map<String, dynamic>,
        };
      }

      // If not found by ID, search by school name (case-insensitive)
      schoolSnapshot = await _firestore!
          .collection('schools')
          .where('schoolName_lower', isEqualTo: searchTerm)
          .limit(1)
          .get();

      if (schoolSnapshot.docs.isNotEmpty) {
        final schoolDoc = schoolSnapshot.docs.first;
        return {
          'id': schoolDoc.id,
          'schoolId': schoolDoc.data() as Map<String, dynamic>,
          ...schoolDoc.data() as Map<String, dynamic>,
        };
      }

      // If still not found, try partial name matching
      schoolSnapshot = await _firestore!
          .collection('schools')
          .orderBy('schoolName_lower')
          .startAt([searchTerm])
          .endAt([searchTerm + '\uf8ff'])
          .limit(5)
          .get();

      if (schoolSnapshot.docs.isNotEmpty) {
        // Return the first match
        final schoolDoc = schoolSnapshot.docs.first;
        return {
          'id': schoolDoc.id,
          'schoolId': schoolDoc.data() as Map<String, dynamic>,
          ...schoolDoc.data() as Map<String, dynamic>,
        };
      }

      return null;
    } catch (e) {
      print('❌ Error searching school in Firebase: $e');
      throw Exception(
          'Failed to search for school. Please check your internet connection.');
    }
  }

  /// Step 2: Authenticate user in Firebase
  Future<Map<String, dynamic>?> _authenticateUserInFirebase(
      Map<String, dynamic> schoolData) async {
    try {
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text;
      final schoolId = schoolData['schoolId'] as String;

      // Check if user exists in the school's users collection
      final usersSnapshot = await _firestore!
          .collection('schools')
          .doc(schoolData['id'])
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        return null; // User not found in this school
      }

      final userDoc = usersSnapshot.docs.first;
      final userData = userDoc.data();

      // Verify password (in real implementation, this should use proper password hashing)
      if (userData['password'] != password) {
        return null; // Invalid password
      }

      // Try to authenticate with Firebase Auth as well
      try {
        await _firebaseAuth!.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Firebase Auth successful');
      } catch (authError) {
        print(
            '⚠️ Firebase Auth failed (continuing with document auth): $authError');
        // Continue anyway - document authentication was successful
      }

      return {
        'id': userDoc.id,
        'schoolId': schoolId,
        ...userData,
      };
    } catch (e) {
      print('❌ Error authenticating user: $e');
      throw Exception('Authentication failed. Please check your credentials.');
    }
  }

  /// Step 3: Set up local school configuration
  Future<void> _setupLocalSchoolConfig(Map<String, dynamic> schoolData) async {
    try {
      // Update settings with school information
      final settingsController = Get.find<SettingsController>();

      settingsController.businessName.value = schoolData['schoolName'] ?? '';
      settingsController.businessAddress.value = schoolData['address'] ?? '';
      settingsController.businessPhone.value = schoolData['phone'] ?? '';
      settingsController.businessEmail.value = schoolData['email'] ?? '';
      settingsController.businessCity.value = schoolData['city'] ?? '';
      settingsController.businessCountry.value = schoolData['country'] ?? '';

      // Enable multi-tenant features
      settingsController.enableMultiTenant.value = true;
      settingsController.enableCloudSync.value = true;

      // Save all settings to local database
      await settingsController.saveAllBusinessSettings();

      // Reset and reinitialize school configuration
      final schoolConfig = Get.find<SchoolConfigService>();
      await schoolConfig.resetSchoolConfig();

      if (!schoolConfig.isValidConfiguration()) {
        throw Exception('Failed to set up school configuration');
      }

      print('✅ Local school configuration set up:');
      print('   School ID: ${schoolConfig.schoolId.value}');
      print('   School Name: ${schoolConfig.schoolName.value}');
    } catch (e) {
      print('❌ Error setting up local school config: $e');
      throw Exception('Failed to configure school settings.');
    }
  }

  /// Step 4: Download and sync all school data to offline database
  Future<void> _downloadSchoolDataToOffline(
      Map<String, dynamic> schoolData, Map<String, dynamic> userData) async {
    try {
      final schoolDocId = schoolData['id'] as String;
      final schoolRef = _firestore!.collection('schools').doc(schoolDocId);

      // Collections to sync
      final collectionsToSync = [
        'users',
        'courses',
        'fleet',
        'schedules',
        'invoices',
        'payments',
        'billing_records',
        'notes',
        'notifications',
        'attachments',
        'currencies',
        'settings'
      ];

      double progressPerCollection = 1.0 / collectionsToSync.length;
      double currentProgress = 0.0;

      for (String collectionName in collectionsToSync) {
        statusMessage.value = 'Downloading $collectionName...';

        try {
          final collectionSnapshot =
              await schoolRef.collection(collectionName).get();

          // Process each document in the collection
          for (var doc in collectionSnapshot.docs) {
            final data = doc.data();
            data['firebase_doc_id'] = doc.id; // Store Firebase document ID

            // Save to local database based on collection type
            await _saveToLocalDatabase(collectionName, data);
          }

          currentProgress += progressPerCollection;
          downloadProgress.value = currentProgress;

          print(
              '✅ Downloaded ${collectionSnapshot.docs.length} $collectionName records');
        } catch (e) {
          print('⚠️ Failed to download $collectionName: $e');
          // Continue with other collections
        }
      }

      downloadProgress.value = 1.0;
      statusMessage.value = 'Data download complete!';
    } catch (e) {
      print('❌ Error downloading school data: $e');
      throw Exception('Failed to download school data.');
    }
  }

  /// Save data to local database based on collection type
  Future<void> _saveToLocalDatabase(
      String collectionName, Map<String, dynamic> data) async {
    try {
      final db = DatabaseHelper.instance;

      switch (collectionName) {
        case 'users':
          // Convert to User model and save
          final user = app_user.User(
            fname: data['fname'] ?? '',
            lname: data['lname'] ?? '',
            email: data['email'] ?? '',
            password: data['password'] ?? '',
            phone: data['phone'] ?? '',
            address: data['address'] ?? '',
            gender: data['gender'] ?? 'Not Specified',
            idnumber: data['idnumber'] ?? '',
            role: data['role'] ?? 'user',
            status: data['status'] ?? 'Active',
            date_of_birth: data['date_of_birth'] != null
                ? DateTime.tryParse(data['date_of_birth'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
            created_at: data['created_at'] != null
                ? DateTime.tryParse(data['created_at'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
          );
          await db.insertUser(user);
          break;

        case 'courses':
          await db.insertCourse(data);
          break;

        case 'fleet':
          await db.insertFleet(data);
          break;

        case 'schedules':
          await db.insertSchedule(data);
          break;

        case 'invoices':
          await db.insertInvoice(data);
          break;

        case 'payments':
          await db.insertPayment(data);
          break;

        // Add more cases as needed for other collections
        default:
          // For collections without specific models, save as generic data
          print('ℹ️ Skipping $collectionName - no specific handler');
      }
    } catch (e) {
      print('⚠️ Error saving $collectionName data to local DB: $e');
      // Don't throw error - continue with other data
    }
  }

  /// Step 5: Set up local authentication
  Future<void> _setupLocalAuthentication(Map<String, dynamic> userData) async {
    try {
      final authController = Get.find<AuthController>();

      // Set current user data
      authController.setCurrentUserFromData(userData);

      print('✅ Local authentication set up for user: ${userData['email']}');
    } catch (e) {
      print('❌ Error setting up local authentication: $e');
      throw Exception('Failed to set up user authentication.');
    }
  }

  /// Step 6: Complete setup and navigate
  Future<void> _completeSetupAndNavigate(
      Map<String, dynamic> schoolData) async {
    try {
      // Initialize Firebase sync service
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      if (syncService.firebaseAvailable.value) {
        await syncService.initializeUserSync();
        print('✅ Firebase sync initialized');
      }

      // Show success message
      Get.snackbar(
        'Welcome!',
        'Successfully joined ${schoolData['schoolName']}. Please set up your PIN for quick access.',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        duration: const Duration(seconds: 4),
      );

      // Navigate to PIN setup
      Get.offAllNamed('/pin-setup');
    } catch (e) {
      print('❌ Error completing setup: $e');
      // Still navigate to PIN setup even if sync fails
      Get.snackbar(
        'Almost Done!',
        'Successfully joined ${schoolData['schoolName']}. Setting up PIN...',
        backgroundColor: Colors.orange.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      Get.offAllNamed('/pin-setup');
    }
  }

  /// Method to retry join if failed
  void retryJoin() {
    errorMessage.value = '';
    joinSchool();
  }

  /// Clear all form data
  void clearForm() {
    schoolNameController.clear();
    emailController.clear();
    passwordController.clear();
    errorMessage.value = '';
    statusMessage.value = '';
    downloadProgress.value = 0.0;
  }
}
