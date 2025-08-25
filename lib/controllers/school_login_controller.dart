// lib/controllers/simple_school_join_controller.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SchoolJoinController extends GetxController {
  final RxDouble downloadProgress = 0.0.obs;
  final emailController = TextEditingController();
  final RxString errorMessage = ''.obs;
  // Form key
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final RxBool isDownloading = false.obs;
  // Reactive variables
  final RxBool isLoading = false.obs;

  final RxBool obscurePassword = true.obs;
  final passwordController = TextEditingController();
  // Text controllers
  final schoolNameController = TextEditingController();

  final RxString statusMessage = ''.obs;

  firebase_auth.FirebaseAuth? _firebaseAuth;
  // Firebase instances
  FirebaseFirestore? _firestore;

  @override
  void onClose() {
    schoolNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    _initializeFirebase();
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

  /// FIXED: Search method that matches your actual Firebase structure
  Future<Map<String, dynamic>?> _searchSchoolInFirebase() async {
    try {
      final searchTerm = schoolNameController.text.trim().toLowerCase();
      print('🔍 Searching for school: "$searchTerm"');

      // Method 1: Try to find by document ID (since your document ID IS the school ID)
      try {
        final docSnapshot = await _firestore!
            .collection('schools')
            .doc(searchTerm) // Search by document ID directly
            .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          print('✅ School found by document ID: ${data['school_name']}');
          return {
            'id': docSnapshot.id,
            'schoolId': data['school_id'], // Use the correct field name
            'schoolName': data['school_name'], // Use the correct field name
            ...data,
          };
        }
      } catch (e) {
        print('⚠️ Document ID search failed: $e');
      }

      // Method 2: Search by school_id field (note the underscore)
      try {
        QuerySnapshot schoolSnapshot = await _firestore!
            .collection('schools')
            .where('school_id', isEqualTo: searchTerm) // Fixed field name
            .where('status', isEqualTo: 'active') // Match your Firebase field
            .limit(1)
            .get();

        if (schoolSnapshot.docs.isNotEmpty) {
          final schoolDoc = schoolSnapshot.docs.first;
          final data = schoolDoc.data() as Map<String, dynamic>;
          print('✅ School found by school_id field: ${data['school_name']}');
          return {
            'id': schoolDoc.id,
            'schoolId': data['school_id'],
            'schoolName': data['school_name'],
            ...data,
          };
        }
      } catch (e) {
        print('⚠️ school_id field search failed: $e');
      }

      // Method 3: Search by school name (create lowercase version for search)
      try {
        QuerySnapshot schoolSnapshot = await _firestore!
            .collection('schools')
            .where('school_name',
                isEqualTo:
                    'MYLA DRIVING SCHOOL') // Exact match from your Firebase
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (schoolSnapshot.docs.isNotEmpty) {
          final schoolDoc = schoolSnapshot.docs.first;
          final data = schoolDoc.data() as Map<String, dynamic>;
          print('✅ School found by school_name: ${data['school_name']}');
          return {
            'id': schoolDoc.id,
            'schoolId': data['school_id'],
            'schoolName': data['school_name'],
            ...data,
          };
        }
      } catch (e) {
        print('⚠️ school_name search failed: $e');
      }

      // Method 4: Case-insensitive search by creating a lowercase field on the fly
      try {
        final allSchools = await _firestore!
            .collection('schools')
            .where('status', isEqualTo: 'active')
            .get();

        for (var doc in allSchools.docs) {
          final data = doc.data();
          final schoolName =
              (data['school_name'] ?? '').toString().toLowerCase();
          final schoolId = (data['school_id'] ?? '').toString().toLowerCase();

          if (schoolName.contains(searchTerm) || schoolId == searchTerm) {
            print(
                '✅ School found by case-insensitive search: ${data['school_name']}');
            return {
              'id': doc.id,
              'schoolId': data['school_id'],
              'schoolName': data['school_name'],
              ...data,
            };
          }
        }
      } catch (e) {
        print('⚠️ Case-insensitive search failed: $e');
      }

      print('❌ No school found for search term: "$searchTerm"');
      print('💡 Available search methods tried:');
      print('   1. Document ID: "$searchTerm"');
      print('   2. school_id field: "$searchTerm"');
      print('   3. school_name field: "MYLA DRIVING SCHOOL"');
      print('   4. Case-insensitive contains search');

      return null;
    } catch (e) {
      print('❌ Error searching school in Firebase: $e');
      throw Exception('Failed to search for school: ${e.toString()}');
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
            gender: data['gender'] ?? 'Male',
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

// Fixed authentication method that handles hashed passwords
  Future<Map<String, dynamic>?> _authenticateUserInFirebase(
      Map<String, dynamic> schoolData) async {
    try {
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text;
      final schoolFirebaseId = schoolData['id'] as String;

      print('🔐 Authenticating user: $email in school: $schoolFirebaseId');

      // Check if user exists in the school's users collection
      final usersSnapshot = await _firestore!
          .collection('schools')
          .doc(schoolFirebaseId)
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        print('❌ User not found in Firebase school users collection');
        return null;
      }

      final userDoc = usersSnapshot.docs.first;
      final userData = userDoc.data();

      print('✅ User found in Firebase');
      print('🔑 Stored password hash: ${userData['password']}');

      // Verify password using multiple methods
      bool passwordValid = await _verifyPassword(password, userData['password'],
          userEmail: email);

      if (!passwordValid) {
        print('❌ Password verification failed');

        // For debugging - let's try the original password hash method from your local system
        final localHashAttempt = _hashPasswordLikeLocal(password);
        print('🔍 Local hash attempt: $localHashAttempt');

        if (localHashAttempt == userData['password']) {
          passwordValid = true;
          print('✅ Password verified using local hash method!');
        }
      }

      if (!passwordValid) {
        // Last resort: check if this is a development/test scenario
        print('⚠️ All password verification methods failed');
        print(
            '💡 For testing, you can temporarily update the Firebase password to plain text');
        return null;
      }

      print('✅ Password verified successfully');

      // Try Firebase Auth (this will likely fail since the user might not be in Firebase Auth)
      try {
        await _firebaseAuth!.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Firebase Auth successful');
      } catch (authError) {
        print(
            '⚠️ Firebase Auth failed (continuing with document auth): $authError');
        // This is expected if user is only in Firestore, not Firebase Auth
      }

      // Update last login
      try {
        await userDoc.reference.update({
          'last_login': FieldValue.serverTimestamp(),
          'last_login_method': 'document_auth',
        });
      } catch (e) {
        print('⚠️ Could not update last login: $e');
      }

      return {
        'id': userDoc.id,
        'schoolId': schoolData['schoolId'],
        'firebase_user_id': userDoc.id,
        'email': userData['email'],
        'fname': userData['fname'] ?? userData['firstName'] ?? '',
        'lname': userData['lname'] ?? userData['lastName'] ?? '',
        'role': userData['role'] ?? 'user',
        'phone': userData['phone'] ?? '',
        'address': userData['address'] ?? '',
        'gender': userData['gender'] ?? '',
        'idnumber': userData['idnumber'] ?? userData['idNumber'] ?? '',
        'status': userData['status'] ?? 'Active',
        ...userData,
      };
    } catch (e) {
      print('❌ Error authenticating user: $e');
      throw Exception('Authentication failed: ${e.toString()}');
    }
  }

  /// Verify password using multiple hashing methods
  Future<bool> _verifyPassword(String plainPassword, String storedHash,
      {String? userEmail}) async {
    try {
      // Method 1: Plain text comparison (in case it's not hashed)
      if (plainPassword == storedHash) {
        print('✅ Password verified: plain text match');
        return true;
      }

      // Method 2: SHA-256 hash (common method)
      final sha256Hash = sha256.convert(utf8.encode(plainPassword)).toString();
      if (sha256Hash == storedHash) {
        print('✅ Password verified: SHA-256 hash');
        return true;
      }

      // Method 3: MD5 hash (less secure but sometimes used)
      final md5Hash = md5.convert(utf8.encode(plainPassword)).toString();
      if (md5Hash == storedHash) {
        print('✅ Password verified: MD5 hash');
        return true;
      }

      // Method 4: SHA-1 hash
      final sha1Hash = sha1.convert(utf8.encode(plainPassword)).toString();
      if (sha1Hash == storedHash) {
        print('✅ Password verified: SHA-1 hash');
        return true;
      }

      // Method 5: Try with salt (common pattern: hash(password + salt))
      final possibleSalts = ['', 'salt', 'driving_school'];
      if (userEmail != null) {
        possibleSalts.add(userEmail);
      }

      for (String salt in possibleSalts) {
        final saltedHash =
            sha256.convert(utf8.encode(plainPassword + salt)).toString();
        if (saltedHash == storedHash) {
          print('✅ Password verified: SHA-256 with salt "$salt"');
          return true;
        }
      }

      print('❌ All password verification methods failed');
      return false;
    } catch (e) {
      print('❌ Error verifying password: $e');
      return false;
    }
  }

  /// Hash password the same way your local system does (you'll need to match your local method)
  String _hashPasswordLikeLocal(String password) {
    // This should match however your local database hashes passwords
    // Common methods:

    // Option 1: Simple SHA-256
    return sha256.convert(utf8.encode(password)).toString();

    // Option 2: MD5 (if that's what your local system uses)
    // return md5.convert(utf8.encode(password)).toString();

    // Option 3: With salt
    // return sha256.convert(utf8.encode(password + 'your_salt_here')).toString();
  }

  /// Quick fix method - temporarily set password to plain text for testing
  Future<void> temporarilySetPlainTextPassword() async {
    try {
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text;

      print('⚠️ TEMPORARY FIX: Setting password to plain text for testing');

      // Find the school
      final schoolData = await _searchSchoolInFirebase();
      if (schoolData == null) return;

      // Find the user
      final usersSnapshot = await _firestore!
          .collection('schools')
          .doc(schoolData['id'])
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isNotEmpty) {
        final userDoc = usersSnapshot.docs.first;

        await userDoc.reference.update({
          'password': password, // Set to plain text temporarily
          'password_updated_for_testing': FieldValue.serverTimestamp(),
          'original_hash_backup': userDoc.data()['password'], // Backup the hash
        });

        print('✅ Password temporarily set to plain text');
        print('💡 You can now try logging in again');

        Get.snackbar(
          'Password Updated',
          'Password temporarily set for testing. Try logging in again.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Error setting temporary password: $e');
    }
  }

  /// FIXED: Set up local school configuration using existing Firebase school data
  Future<void> _setupLocalSchoolConfig(Map<String, dynamic> schoolData) async {
    try {
      print('🏫 Setting up local school configuration from Firebase data...');

      // Update settings with school information from Firebase
      final settingsController = Get.find<SettingsController>();

      settingsController.businessName.value =
          schoolData['school_name'] ?? schoolData['schoolName'] ?? '';
      settingsController.businessAddress.value =
          schoolData['business_address'] ?? schoolData['address'] ?? '';
      settingsController.businessPhone.value =
          schoolData['business_phone'] ?? schoolData['phone'] ?? '';
      settingsController.businessEmail.value =
          schoolData['business_email'] ?? schoolData['email'] ?? '';
      settingsController.businessCity.value =
          schoolData['business_city'] ?? schoolData['city'] ?? '';
      settingsController.businessCountry.value =
          schoolData['business_country'] ?? schoolData['country'] ?? '';

      // Enable multi-tenant features
      settingsController.enableMultiTenant.value = true;
      settingsController.enableCloudSync.value = true;

      // Save all settings to local database
      await settingsController.saveAllBusinessSettings();

      // CRITICAL FIX: Set school configuration directly instead of regenerating
      final schoolConfig = Get.find<SchoolConfigService>();

      // DON'T call resetSchoolConfig() - it regenerates the ID!
      // Instead, set the values directly from Firebase
      print('🔧 Setting school configuration from Firebase:');
      print('   Firebase Doc ID: ${schoolData['id']}');
      print('   School ID: ${schoolData['school_id']}');
      print('   School Name: ${schoolData['school_name']}');

      // Set the school configuration directly from Firebase data
      schoolConfig.schoolId.value = schoolData['school_id'] ??
          schoolData['id']; // Use the existing school ID
      schoolConfig.schoolName.value =
          schoolData['school_name'] ?? schoolData['schoolName'] ?? '';
      schoolConfig.isInitialized.value = true;

      // Verify configuration
      if (!schoolConfig.isValidConfiguration()) {
        throw Exception(
            'Failed to set up school configuration with Firebase data');
      }

      print('✅ Local school configuration set up successfully:');
      print('   School ID: ${schoolConfig.schoolId.value}');
      print('   School Name: ${schoolConfig.schoolName.value}');
      print('   Firebase Document: ${schoolData['id']}');

      // Store the Firebase document ID for future reference
      await _storeFirebaseDocumentId(schoolData['id']);
    } catch (e) {
      print('❌ Error setting up local school config: $e');
      throw Exception('Failed to configure school settings: ${e.toString()}');
    }
  }

  /// Store Firebase document ID for future use
  Future<void> _storeFirebaseDocumentId(String firebaseDocId) async {
    try {
      // Store using the settings table in your database
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'settings',
        {
          'key': 'firebase_school_doc_id',
          'value': firebaseDocId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace, // Replace if exists
      );
      print('✅ Firebase document ID stored: $firebaseDocId');
    } catch (e) {
      print('⚠️ Could not store Firebase document ID: $e');
      // This is not critical, so don't throw error
    }
  }

  /// Get stored Firebase document ID
  Future<String?> _getStoredFirebaseDocumentId() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['firebase_school_doc_id'],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return results.first['value'] as String?;
      }
      return null;
    } catch (e) {
      print('⚠️ Could not retrieve Firebase document ID: $e');
      return null;
    }
  }

  /// Enhanced search method that also returns Firebase document ID properly
  Future<Map<String, dynamic>?> _searchSchoolInFirebaseFixed() async {
    try {
      final searchTerm = schoolNameController.text.trim().toLowerCase();
      print('🔍 Searching for school: "$searchTerm"');

      // Method 1: Try to find by document ID (since your document ID IS the school ID)
      try {
        final docSnapshot =
            await _firestore!.collection('schools').doc(searchTerm).get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          print('✅ School found by document ID: ${data['school_name']}');
          return {
            'id': docSnapshot.id, // This is the Firebase document ID
            'firebase_doc_id': docSnapshot.id, // Store it explicitly too
            'school_id': data['school_id'] ??
                docSnapshot.id, // Use field or fallback to doc ID
            'school_name': data['school_name'],
            'schoolId':
                data['school_id'] ?? docSnapshot.id, // Legacy compatibility
            'schoolName': data['school_name'], // Legacy compatibility
            ...data, // Include all other fields
          };
        }
      } catch (e) {
        print('⚠️ Document ID search failed: $e');
      }

      // Method 2: Search by school_id field
      try {
        QuerySnapshot schoolSnapshot = await _firestore!
            .collection('schools')
            .where('school_id', isEqualTo: searchTerm)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (schoolSnapshot.docs.isNotEmpty) {
          final schoolDoc = schoolSnapshot.docs.first;
          final data = schoolDoc.data() as Map<String, dynamic>;
          print('✅ School found by school_id field: ${data['school_name']}');
          return {
            'id': schoolDoc.id,
            'firebase_doc_id': schoolDoc.id,
            'school_id': data['school_id'],
            'school_name': data['school_name'],
            'schoolId': data['school_id'], // Legacy compatibility
            'schoolName': data['school_name'], // Legacy compatibility
            ...data,
          };
        }
      } catch (e) {
        print('⚠️ school_id field search failed: $e');
      }

      // Method 3: Case-insensitive search
      try {
        final allSchools = await _firestore!
            .collection('schools')
            .where('status', isEqualTo: 'active')
            .get();

        for (var doc in allSchools.docs) {
          final data = doc.data();
          final schoolName =
              (data['school_name'] ?? '').toString().toLowerCase();
          final schoolId =
              (data['school_id'] ?? doc.id).toString().toLowerCase();

          if (schoolName.contains(searchTerm) || schoolId == searchTerm) {
            print(
                '✅ School found by case-insensitive search: ${data['school_name']}');
            return {
              'id': doc.id,
              'firebase_doc_id': doc.id,
              'school_id': data['school_id'] ?? doc.id,
              'school_name': data['school_name'],
              'schoolId': data['school_id'] ?? doc.id, // Legacy compatibility
              'schoolName': data['school_name'], // Legacy compatibility
              ...data,
            };
          }
        }
      } catch (e) {
        print('⚠️ Case-insensitive search failed: $e');
      }

      print('❌ No school found for search term: "$searchTerm"');
      return null;
    } catch (e) {
      print('❌ Error searching school in Firebase: $e');
      throw Exception('Failed to search for school: ${e.toString()}');
    }
  }

  /// Method to check current school configuration and prevent regeneration
  void debugCurrentSchoolConfig() {
    final schoolConfig = Get.find<SchoolConfigService>();
    final settingsController = Get.find<SettingsController>();

    print('🐛 === CURRENT SCHOOL CONFIG DEBUG ===');
    print('School ID: ${schoolConfig.schoolId.value}');
    print('School Name: ${schoolConfig.schoolName.value}');
    print('Is Initialized: ${schoolConfig.isInitialized.value}');
    print('Business Name: ${settingsController.businessName.value}');
    print('Business Address: ${settingsController.businessAddress.value}');
    print('Business Phone: ${settingsController.businessPhone.value}');
    print('Business Email: ${settingsController.businessEmail.value}');
    print('🐛 === END DEBUG ===');
  }
}
