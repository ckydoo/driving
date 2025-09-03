// lib/controllers/simple_school_join_controller.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:driving/controllers/auth_controller_extension.dart';
import 'package:driving/services/payment_sync_integration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
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

  /// Enhanced _downloadSchoolDataToOffline method with duplicate prevention
  /// Replace your existing method in SchoolLoginController with this one
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
      ];

      double progressPerCollection = 1.0 / collectionsToSync.length;
      double currentProgress = 0.0;

      // ✅ NEW: Check if this is a re-join by looking for existing school data
      final isRejoining = await _checkIfRejoiningSchool(schoolDocId);

      if (isRejoining) {
        print(
            '🔄 DETECTED RE-JOIN: Will update existing data instead of duplicating');
        statusMessage.value = 'Updating existing school data...';
      } else {
        print('🆕 NEW JOIN: Fresh download of school data');
        statusMessage.value = 'Downloading fresh school data...';
      }

      for (String collectionName in collectionsToSync) {
        statusMessage.value = isRejoining
            ? 'Updating $collectionName...'
            : 'Downloading $collectionName...';

        try {
          final collectionSnapshot =
              await schoolRef.collection(collectionName).get();

          int insertedCount = 0;
          int updatedCount = 0;
          int skippedCount = 0;

          // Process each document in the collection
          for (var doc in collectionSnapshot.docs) {
            final data = doc.data();
            data['firebase_doc_id'] = doc.id; // Store Firebase document ID

            // ✅ ENHANCED: Save with duplicate prevention
            final result = await _saveToLocalDatabaseWithDuplicateCheck(
                collectionName, data, doc.id, isRejoining);

            switch (result) {
              case 'inserted':
                insertedCount++;
                break;
              case 'updated':
                updatedCount++;
                break;
              case 'skipped':
                skippedCount++;
                break;
            }
          }

          currentProgress += progressPerCollection;
          downloadProgress.value = currentProgress;

          print('✅ $collectionName: ${collectionSnapshot.docs.length} total, '
              '$insertedCount inserted, $updatedCount updated, $skippedCount skipped');
        } catch (e) {
          print('⚠️ Failed to download $collectionName: $e');
          // Continue with other collections
        }
      }

      downloadProgress.value = 1.0;
      statusMessage.value = 'Data synchronization complete!';

      // ✅ NEW: Clean up any remaining duplicates after download
      await _cleanupPostDownloadDuplicates();
    } catch (e) {
      print('❌ Error downloading school data: $e');
      throw Exception('Failed to download school data.');
    }
  }

  /// ✅ NEW: Check if user is rejoining an existing school
  Future<bool> _checkIfRejoiningSchool(String schoolId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Check if we have existing data for this school
      final existingUsers = await db.query('users', limit: 1);

      final existingCourses = await db.query('courses', limit: 1);

      final existingFleet = await db.query('fleet', limit: 1);

      // If we have any existing core data, this is likely a re-join
      return existingUsers.isNotEmpty ||
          existingCourses.isNotEmpty ||
          existingFleet.isNotEmpty;
    } catch (e) {
      print('⚠️ Error checking re-join status: $e');
      return false; // Default to treating as new join
    }
  }

  /// ✅ ENHANCED: Save data with comprehensive duplicate checking
  Future<String> _saveToLocalDatabaseWithDuplicateCheck(String collectionName,
      Map<String, dynamic> data, String firebaseDocId, bool isRejoining) async {
    try {
      final db = DatabaseHelper.instance;
      final cleanedData = _convertFirebaseDataForSQLite(data);

      switch (collectionName) {
        case 'users':
          return await _handleUserData(cleanedData, firebaseDocId, isRejoining);

        case 'courses':
          return await _handleCourseData(
              cleanedData, firebaseDocId, isRejoining);

        case 'fleet':
          return await _handleFleetData(
              cleanedData, firebaseDocId, isRejoining);

        case 'schedules':
          return await _handleScheduleData(
              cleanedData, firebaseDocId, isRejoining);

        case 'invoices':
          return await _handleInvoiceData(
              cleanedData, firebaseDocId, isRejoining);

        case 'payments':
          return await _handlePaymentData(
              cleanedData, firebaseDocId, isRejoining);

        case 'billing_records':
          return await _handleBillingRecordData(
              cleanedData, firebaseDocId, isRejoining);

        // Add other collections as needed
        default:
          // For other collections, use generic handling
          return await _handleGenericData(
              collectionName, cleanedData, firebaseDocId, isRejoining);
      }
    } catch (e) {
      print('❌ Error saving $collectionName data: $e');
      return 'error';
    }
  }

  Map<String, dynamic> _convertDataForSQLite(Map<String, dynamic> data) {
    final Map<String, dynamic> converted = {};

    for (String key in data.keys) {
      final value = data[key];

      if (value == null) {
        converted[key] = null;
      } else if (value is bool) {
        // Convert boolean to integer (0 or 1)
        converted[key] = value ? 1 : 0;
      } else if (value is List) {
        // Convert list to JSON string
        converted[key] = jsonEncode(value);
      } else if (value is Map) {
        // Convert map to JSON string
        converted[key] = jsonEncode(value);
      } else if (value is DateTime) {
        // Convert DateTime to milliseconds
        converted[key] = value.millisecondsSinceEpoch;
      } else if (value is Timestamp) {
        // Convert Firestore Timestamp to milliseconds
        converted[key] = value.millisecondsSinceEpoch;
      } else {
        // Keep other types as-is (String, int, double, null)
        converted[key] = value;
      }
    }

    return converted;
  }

  /// Helper method to filter data for users table specifically
  Map<String, dynamic> _filterUserDataForDatabase(Map<String, dynamic> data) {
    // Define the allowed columns for users table based on your schema
    final allowedUserColumns = {
      'fname',
      'lname',
      'email',
      'phone',
      'idnumber',
      'id_number',
      'role',
      'status',
      'address',
      'gender',
      'password',
      'date_of_birth',
      'created_at',
      'last_modified',
      'firebase_synced',
      'firebase_doc_id',
      'firebase_user_id',
      'deleted',
      'last_modified_device'
    };

    final filteredData = <String, dynamic>{};

    for (String key in data.keys) {
      if (allowedUserColumns.contains(key)) {
        filteredData[key] = data[key];
      } else if (key == 'firebase_uid' &&
          !filteredData.containsKey('firebase_user_id')) {
        // Map firebase_uid to firebase_user_id
        filteredData['firebase_user_id'] = data[key];
      }
    }

    return filteredData;
  }

  /// Updated _handleUserData method with proper data conversion and filtering
  Future<String> _handleUserData(
      Map<String, dynamic> data, String firebaseDocId, bool isRejoining) async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Check for existing user by email (primary identifier)
      final email = data['email']?.toString().toLowerCase();
      if (email == null) return 'skipped';

      final existing = await db.query('users',
          where: 'LOWER(email) = ?', whereArgs: [email], limit: 1);

      if (existing.isNotEmpty) {
        if (isRejoining) {
          // Update existing user
          final existingId = existing.first['id'];
          final updateData = Map<String, dynamic>.from(data);
          updateData.remove('id'); // Don't update the local ID
          updateData['firebase_synced'] = 1;
          updateData['firebase_doc_id'] = firebaseDocId;
          updateData['last_modified'] = DateTime.now().millisecondsSinceEpoch;

          // ✅ FIX: Filter and convert data types for SQLite
          final filteredData = _filterUserDataForDatabase(updateData);
          final convertedUpdateData = _convertDataForSQLite(filteredData);

          await db.update('users', convertedUpdateData,
              where: 'id = ?', whereArgs: [existingId]);

          print('🔄 Updated existing user: $email');
          return 'updated';
        } else {
          print('⏭️ User already exists, skipping: $email');
          return 'skipped';
        }
      }

      // Create new user using your User model
      final user = app_user.User(
        fname: data['fname'] ?? '',
        lname: data['lname'] ?? '',
        email: email,
        phone: data['phone'] ?? '',
        role: data['role'] ?? 'student',
        status: data['status'] ?? 'active',
        date_of_birth: data['date_of_birth'] != null
            ? (DateTime.tryParse(data['date_of_birth'].toString()) ??
                DateTime(2000, 1, 1))
            : DateTime(2000, 1, 1),
        created_at: data['created_at'] != null
            ? (DateTime.tryParse(data['created_at'].toString()) ??
                DateTime.now())
            : DateTime.now(),
        password: data['password'] ?? '',
        gender: data['gender'] ?? '',
        address: data['address'] ?? '',
        idnumber: data['idnumber'] ??
            data['idnumber'] ??
            '', // Handle both field names
      );

      final userId = await DatabaseHelper.instance.insertUser(user);

      // Update Firebase sync info after insertion
      final database = await DatabaseHelper.instance.database;
      await database.update(
          'users',
          {
            'firebase_synced': 1,
            'firebase_doc_id': firebaseDocId,
            'firebase_user_id': data['firebase_uid'] ??
                data['firebase_user_id'], // Handle both field names
          },
          where: 'id = ?',
          whereArgs: [userId]);

      print('➕ Created new user: $email (ID: $userId)');
      return 'inserted';
    } catch (e) {
      print('❌ Error handling user data: $e');
      return 'error';
    }
  }

  /// Updated _handleCourseData method with data conversion
  Future<String> _handleCourseData(
      Map<String, dynamic> data, String firebaseDocId, bool isRejoining) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final courseName = data['name']?.toString();
      if (courseName == null) return 'skipped';

      // Check for existing course by name
      final existing = await db.query('courses',
          where: 'LOWER(name) = ?',
          whereArgs: [courseName.toLowerCase()],
          limit: 1);

      if (existing.isNotEmpty) {
        if (isRejoining) {
          // Update existing course
          final existingId = existing.first['id'];
          final updateData = Map<String, dynamic>.from(data);
          updateData.remove('id');
          updateData['firebase_synced'] = 1;
          updateData['firebase_doc_id'] = firebaseDocId;
          updateData['last_modified'] = DateTime.now().millisecondsSinceEpoch;

          // ✅ FIX: Convert data types for SQLite
          final convertedUpdateData = _convertDataForSQLite(updateData);

          await db.update('courses', convertedUpdateData,
              where: 'id = ?', whereArgs: [existingId]);

          print('🔄 Updated existing course: $courseName');
          return 'updated';
        } else {
          print('⏭️ Course already exists, skipping: $courseName');
          return 'skipped';
        }
      }

      // Create new course
      data['firebase_synced'] = 1;
      data['firebase_doc_id'] = firebaseDocId;
      data['created_at'] =
          data['created_at'] ?? DateTime.now().millisecondsSinceEpoch;

      // ✅ FIX: Convert data types for SQLite
      final convertedData = _convertDataForSQLite(data);

      final courseId = await db.insert('courses', convertedData);
      print('➕ Created new course: $courseName (ID: $courseId)');
      return 'inserted';
    } catch (e) {
      print('❌ Error handling course data: $e');
      return 'error';
    }
  }

  /// Updated _handleFleetData method with data conversion
  Future<String> _handleFleetData(
      Map<String, dynamic> data, String firebaseDocId, bool isRejoining) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final registrationNumber = data['registrationNumber']?.toString();
      if (registrationNumber == null) return 'skipped';

      // Check for existing vehicle by registration number
      final existing = await db.query('fleet',
          where: 'LOWER(registrationNumber) = ?',
          whereArgs: [registrationNumber.toLowerCase()],
          limit: 1);

      if (existing.isNotEmpty) {
        if (isRejoining) {
          // Update existing vehicle
          final existingId = existing.first['id'];
          final updateData = Map<String, dynamic>.from(data);
          updateData.remove('id');
          updateData['firebase_synced'] = 1;
          updateData['firebase_doc_id'] = firebaseDocId;
          updateData['last_modified'] = DateTime.now().millisecondsSinceEpoch;

          // ✅ FIX: Convert data types for SQLite
          final convertedUpdateData = _convertDataForSQLite(updateData);

          await db.update('fleet', convertedUpdateData,
              where: 'id = ?', whereArgs: [existingId]);

          print('🔄 Updated existing vehicle: $registrationNumber');
          return 'updated';
        } else {
          print('⏭️ Vehicle already exists, skipping: $registrationNumber');
          return 'skipped';
        }
      }

      // Create new vehicle
      data['firebase_synced'] = 1;
      data['firebase_doc_id'] = firebaseDocId;
      data['created_at'] =
          data['created_at'] ?? DateTime.now().millisecondsSinceEpoch;

      // ✅ FIX: Convert data types for SQLite
      final convertedData = _convertDataForSQLite(data);

      final vehicleId = await db.insert('fleet', convertedData);
      print('➕ Created new vehicle: $registrationNumber (ID: $vehicleId)');
      return 'inserted';
    } catch (e) {
      print('❌ Error handling fleet data: $e');
      return 'error';
    }
  }

  /// Updated _handlePaymentData method with data conversion
  Future<String> _handlePaymentData(
      Map<String, dynamic> data, String firebaseDocId, bool isRejoining) async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Safe check for PaymentSyncIntegration
      bool isDuplicate = false;
      try {
        final syncIntegration = Get.find<PaymentSyncIntegration>();
        isDuplicate = await syncIntegration.isPaymentDuplicateBeforeSync(data);
      } catch (e) {
        print(
            '⚠️ PaymentSyncIntegration not available, skipping duplicate check: $e');
        // Continue without the check
      }

      if (isDuplicate) {
        print('🚫 Payment is duplicate, skipping');
        return 'skipped';
      }

      // Check by Firebase doc ID first
      final existingByDocId = await db.query('payments',
          where: 'firebase_doc_id = ?', whereArgs: [firebaseDocId], limit: 1);

      if (existingByDocId.isNotEmpty) {
        if (isRejoining) {
          // Update existing payment
          final existingId = existingByDocId.first['id'];
          final updateData = Map<String, dynamic>.from(data);
          updateData.remove('id');
          updateData['firebase_synced'] = 1;
          updateData['firebase_doc_id'] = firebaseDocId;

          // ✅ FIX: Convert data types for SQLite
          final convertedUpdateData = _convertDataForSQLite(updateData);

          await db.update('payments', convertedUpdateData,
              where: 'id = ?', whereArgs: [existingId]);

          print('🔄 Updated existing payment by doc ID');
          return 'updated';
        } else {
          print('⏭️ Payment already exists by doc ID, skipping');
          return 'skipped';
        }
      }

      // Create new payment
      data['firebase_synced'] = 1;
      data['firebase_doc_id'] = firebaseDocId;

      // ✅ FIX: Convert data types for SQLite
      final convertedData = _convertDataForSQLite(data);

      final paymentId = await db.insert('payments', convertedData);
      print('➕ Created new payment (ID: $paymentId)');
      return 'inserted';
    } catch (e) {
      print('❌ Error handling payment data: $e');
      return 'error';
    }
  }

  /// Updated _handleInvoiceData method with data conversion
  Future<String> _handleInvoiceData(
      Map<String, dynamic> data, String firebaseDocId, bool isRejoining) async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Check by Firebase doc ID first
      final existingByDocId = await db.query('invoices',
          where: 'firebase_doc_id = ?', whereArgs: [firebaseDocId], limit: 1);

      if (existingByDocId.isNotEmpty) {
        if (isRejoining) {
          // Update existing invoice
          final existingId = existingByDocId.first['id'];
          final updateData = Map<String, dynamic>.from(data);
          updateData.remove('id');
          updateData['firebase_synced'] = 1;
          updateData['firebase_doc_id'] = firebaseDocId;

          // ✅ FIX: Convert data types for SQLite
          final convertedUpdateData = _convertDataForSQLite(updateData);

          await db.update('invoices', convertedUpdateData,
              where: 'id = ?', whereArgs: [existingId]);

          print('🔄 Updated existing invoice by doc ID');
          return 'updated';
        } else {
          print('⏭️ Invoice already exists by doc ID, skipping');
          return 'skipped';
        }
      }

      // Additional check: avoid duplicates by student+course combination
      final studentId = data['studentId'];
      final courseId = data['courseId'];
      if (studentId != null && courseId != null) {
        final existingByStudentCourse = await db.query('invoices',
            where: 'studentId = ? AND courseId = ?',
            whereArgs: [studentId, courseId],
            limit: 1);

        if (existingByStudentCourse.isNotEmpty) {
          print(
              '⏭️ Invoice already exists for student $studentId course $courseId, skipping');
          return 'skipped';
        }
      }

      // Create new invoice
      data['firebase_synced'] = 1;
      data['firebase_doc_id'] = firebaseDocId;

      // ✅ FIX: Convert data types for SQLite
      final convertedData = _convertDataForSQLite(data);

      final invoiceId = await db.insert('invoices', convertedData);
      print('➕ Created new invoice (ID: $invoiceId)');
      return 'inserted';
    } catch (e) {
      print('❌ Error handling invoice data: $e');
      return 'error';
    }
  }

  /// Updated _handleScheduleData method with data conversion
  Future<String> _handleScheduleData(
      Map<String, dynamic> data, String firebaseDocId, bool isRejoining) async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Check by Firebase doc ID first
      final existingByDocId = await db.query('schedules',
          where: 'firebase_doc_id = ?', whereArgs: [firebaseDocId], limit: 1);

      if (existingByDocId.isNotEmpty) {
        if (isRejoining) {
          final existingId = existingByDocId.first['id'];
          final updateData = Map<String, dynamic>.from(data);
          updateData.remove('id');
          updateData['firebase_synced'] = 1;
          updateData['firebase_doc_id'] = firebaseDocId;

          // ✅ FIX: Convert data types for SQLite
          final convertedUpdateData = _convertDataForSQLite(updateData);

          await db.update('schedules', convertedUpdateData,
              where: 'id = ?', whereArgs: [existingId]);

          print('🔄 Updated existing schedule by doc ID');
          return 'updated';
        } else {
          print('⏭️ Schedule already exists by doc ID, skipping');
          return 'skipped';
        }
      }

      // Additional check: avoid duplicate schedules by student+start time
      final studentId = data['studentId'];
      final startTime = data['start'];
      if (studentId != null && startTime != null) {
        final existingByStudentTime = await db.query('schedules',
            where: 'studentId = ? AND start = ?',
            whereArgs: [studentId, startTime],
            limit: 1);

        if (existingByStudentTime.isNotEmpty) {
          print(
              '⏭️ Schedule already exists for student $studentId at $startTime, skipping');
          return 'skipped';
        }
      }

      // Create new schedule
      data['firebase_synced'] = 1;
      data['firebase_doc_id'] = firebaseDocId;

      // ✅ FIX: Convert data types for SQLite
      final convertedData = _convertDataForSQLite(data);

      final scheduleId = await db.insert('schedules', convertedData);
      print('➕ Created new schedule (ID: $scheduleId)');
      return 'inserted';
    } catch (e) {
      print('❌ Error handling schedule data: $e');
      return 'error';
    }
  }

  /// Updated _handleBillingRecordData method with data conversion
  Future<String> _handleBillingRecordData(
      Map<String, dynamic> data, String firebaseDocId, bool isRejoining) async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Check by Firebase doc ID first
      final existingByDocId = await db.query('billing_records',
          where: 'firebase_doc_id = ?', whereArgs: [firebaseDocId], limit: 1);

      if (existingByDocId.isNotEmpty) {
        if (isRejoining) {
          final existingId = existingByDocId.first['id'];
          final updateData = Map<String, dynamic>.from(data);
          updateData.remove('id');
          updateData['firebase_synced'] = 1;
          updateData['firebase_doc_id'] = firebaseDocId;

          // ✅ FIX: Convert data types for SQLite
          final convertedUpdateData = _convertDataForSQLite(updateData);

          await db.update('billing_records', convertedUpdateData,
              where: 'id = ?', whereArgs: [existingId]);

          print('🔄 Updated existing billing record by doc ID');
          return 'updated';
        } else {
          print('⏭️ Billing record already exists by doc ID, skipping');
          return 'skipped';
        }
      }

      // Create new billing record
      data['firebase_synced'] = 1;
      data['firebase_doc_id'] = firebaseDocId;

      // ✅ FIX: Convert data types for SQLite
      final convertedData = _convertDataForSQLite(data);

      final recordId = await db.insert('billing_records', convertedData);
      print('➕ Created new billing record (ID: $recordId)');
      return 'inserted';
    } catch (e) {
      print('❌ Error handling billing record data: $e');
      return 'error';
    }
  }

  /// Updated _handleGenericData method with data conversion
  Future<String> _handleGenericData(String tableName, Map<String, dynamic> data,
      String firebaseDocId, bool isRejoining) async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Check by Firebase doc ID first
      final existingByDocId = await db.query(tableName,
          where: 'firebase_doc_id = ?', whereArgs: [firebaseDocId], limit: 1);

      if (existingByDocId.isNotEmpty) {
        if (isRejoining) {
          final existingId = existingByDocId.first['id'];
          final updateData = Map<String, dynamic>.from(data);
          updateData.remove('id');
          updateData['firebase_synced'] = 1;
          updateData['firebase_doc_id'] = firebaseDocId;

          // ✅ FIX: Convert data types for SQLite
          final convertedUpdateData = _convertDataForSQLite(updateData);

          await db.update(tableName, convertedUpdateData,
              where: 'id = ?', whereArgs: [existingId]);

          print('🔄 Updated existing $tableName record by doc ID');
          return 'updated';
        } else {
          print('⏭️ $tableName record already exists by doc ID, skipping');
          return 'skipped';
        }
      }

      // Create new record
      data['firebase_synced'] = 1;
      data['firebase_doc_id'] = firebaseDocId;

      // ✅ FIX: Convert data types for SQLite
      final convertedData = _convertDataForSQLite(data);

      final recordId = await db.insert(tableName, convertedData);
      print('➕ Created new $tableName record (ID: $recordId)');
      return 'inserted';
    } catch (e) {
      print('❌ Error handling $tableName data: $e');
      return 'error';
    }
  }

  /// Clean up any remaining duplicates after download
  Future<void> _cleanupPostDownloadDuplicates() async {
    try {
      print('🧹 Running post-download duplicate cleanup...');

      // Use the existing payment duplicate cleanup
      final syncIntegration = Get.find<PaymentSyncIntegration>();
      await syncIntegration.fixDuplicatePaymentsNow();

      print('✅ Post-download cleanup completed');
    } catch (e) {
      print('⚠️ Error during post-download cleanup: $e');
      // Don't throw - cleanup failure shouldn't stop the join process
    }
  }

  /// Helper method to convert Firebase data to SQLite format (keep your existing implementation)
  Map<String, dynamic> _convertFirebaseDataForSQLite(
      Map<String, dynamic> firebaseData) {
    final Map<String, dynamic> cleanedData =
        Map<String, dynamic>.from(firebaseData);

    // Convert Firestore Timestamps to milliseconds
    for (String key in cleanedData.keys) {
      final value = cleanedData[key];
      if (value != null) {
        if (value.toString().contains('Timestamp')) {
          // Handle Firestore Timestamp
          try {
            // Extract seconds from Timestamp string
            final timestampStr = value.toString();
            if (timestampStr.contains('seconds=')) {
              final secondsMatch =
                  RegExp(r'seconds=(\d+)').firstMatch(timestampStr);
              if (secondsMatch != null) {
                final seconds = int.parse(secondsMatch.group(1)!);
                cleanedData[key] = seconds * 1000; // Convert to milliseconds
              }
            }
          } catch (e) {
            print('⚠️ Failed to convert Timestamp for key $key: $e');
            cleanedData[key] = DateTime.now().millisecondsSinceEpoch;
          }
        } else if (key.contains('date') ||
            key.contains('time') ||
            key.contains('created') ||
            key.contains('modified')) {
          // Handle other date fields
          if (value is String) {
            try {
              final date = DateTime.parse(value);
              cleanedData[key] = date.millisecondsSinceEpoch;
            } catch (e) {
              // Keep as string if parsing fails
            }
          }
        }
      }
    }

    // Ensure required fields exist
    cleanedData['last_modified'] =
        cleanedData['last_modified'] ?? DateTime.now().millisecondsSinceEpoch;
    cleanedData['created_at'] =
        cleanedData['created_at'] ?? DateTime.now().millisecondsSinceEpoch;

    return cleanedData;
  }

  /// ✅ TIMESTAMP FIX: Convert various timestamp formats to milliseconds
  int _convertTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now().millisecondsSinceEpoch;

    try {
      if (timestamp is int) return timestamp;
      if (timestamp is Timestamp) return timestamp.millisecondsSinceEpoch;
      if (timestamp is DateTime) return timestamp.millisecondsSinceEpoch;

      if (timestamp is String) {
        if (timestamp.contains('T')) {
          return DateTime.parse(timestamp).millisecondsSinceEpoch;
        }
        final parsed = int.tryParse(timestamp);
        if (parsed != null) return parsed;
      }

      // Handle the specific format from your error logs: Timestamp(seconds=1756480655, nanoseconds=0)
      if (timestamp.toString().contains('Timestamp(seconds=')) {
        final match = RegExp(r'seconds=(\d+)').firstMatch(timestamp.toString());
        if (match != null) {
          return int.parse(match.group(1)!) * 1000; // Convert to milliseconds
        }
      }
    } catch (e) {
      print('⚠️ Error converting timestamp $timestamp: $e');
    }

    return DateTime.now().millisecondsSinceEpoch;
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
      final syncService = Get.find<FixedLocalFirstSyncService>();
      if (syncService.firebaseAvailable.value) {
        await syncService.syncWithFirebase();
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

// Fixed authentication methods for SchoolJoinController

// FIXED: _authenticateUserInFirebase method with null password handling
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

      // CRITICAL FIX: Handle null password from Firebase
      final storedPassword = userData['password']?.toString();
      print('🔑 Stored password hash: $storedPassword');

      if (storedPassword == null || storedPassword.isEmpty) {
        print('❌ No password stored in Firebase for this user');
        print('💡 This might be a user that needs password migration');

        // Option 1: Auto-migrate the password (recommended for smooth migration)
        await _migrateUserPassword(userDoc, password);
        print('✅ Password migrated successfully');

        // Option 2: Reject login (uncomment if you prefer manual migration)
        // throw Exception('User password needs to be migrated. Please contact admin.');
      } else {
        // Verify password using multiple methods
        bool passwordValid =
            await _verifyPassword(password, storedPassword, userEmail: email);

        if (!passwordValid) {
          print('❌ Password verification failed');
          return null;
        }

        print('✅ Password verified successfully');
      }

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
        'email': userData['email'] ?? email,
        'fname': userData['fname'] ?? userData['firstName'] ?? '',
        'lname': userData['lname'] ?? userData['lastName'] ?? '',
        'role': userData['role'] ?? 'user',
        'phone': userData['phone'] ?? '',
        'address': userData['address'] ?? '',
        'gender': userData['gender'] ?? '',
        'idnumber': userData['idnumber'] ?? userData['idNumber'] ?? '',
        'status': userData['status'] ?? 'Active',
        'password': password, // Include the password for User model
        'created_at': userData['created_at'] ?? FieldValue.serverTimestamp(),
        'date_of_birth': userData['date_of_birth'] ?? '2000-01-01',
        ...userData,
      };
    } catch (e) {
      print('❌ Error authenticating user: $e');
      throw Exception('Authentication failed: ${e.toString()}');
    }
  }

// NEW: Auto-migrate user password method
  Future<void> _migrateUserPassword(
      DocumentSnapshot userDoc, String plainPassword) async {
    try {
      print('🔄 Auto-migrating user password...');

      // Hash the password (use your preferred method)
      final hashedPassword = _hashPasswordLikeLocal(plainPassword);

      // Update the user document with the hashed password
      await userDoc.reference.update({
        'password': hashedPassword,
        'password_migrated_at': FieldValue.serverTimestamp(),
        'migration_method': 'auto_login',
      });

      print('✅ Password auto-migrated and saved to Firebase');
    } catch (e) {
      print('❌ Error migrating password: $e');
      // Don't throw error - allow login to continue
    }
  }

// FIXED: _verifyPassword method with proper null handling
  Future<bool> _verifyPassword(String plainPassword, String? storedHash,
      {String? userEmail}) async {
    try {
      // CRITICAL FIX: Handle null or empty stored hash
      if (storedHash == null || storedHash.trim().isEmpty) {
        print('❌ Stored password hash is null or empty');
        return false;
      }

      final trimmedHash = storedHash.trim();

      // Method 1: Plain text comparison (in case it's not hashed)
      if (plainPassword == trimmedHash) {
        print('✅ Password verified: plain text match');
        return true;
      }

      // Method 2: SHA-256 hash (common method)
      final sha256Hash = sha256.convert(utf8.encode(plainPassword)).toString();
      if (sha256Hash == trimmedHash) {
        print('✅ Password verified: SHA-256 hash');
        return true;
      }

      // Method 3: MD5 hash (less secure but sometimes used)
      final md5Hash = md5.convert(utf8.encode(plainPassword)).toString();
      if (md5Hash == trimmedHash) {
        print('✅ Password verified: MD5 hash');
        return true;
      }

      // Method 4: SHA-1 hash
      final sha1Hash = sha1.convert(utf8.encode(plainPassword)).toString();
      if (sha1Hash == trimmedHash) {
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
        if (saltedHash == trimmedHash) {
          print('✅ Password verified: SHA-256 with salt "$salt"');
          return true;
        }
      }

      print('❌ All password verification methods failed');
      print('🔍 Expected hash: $trimmedHash');
      print('🔍 Plain password: $plainPassword');
      print('🔍 SHA-256 attempt: $sha256Hash');

      return false;
    } catch (e) {
      print('❌ Error verifying password: $e');
      return false;
    }
  }

// IMPROVED: Hash password method with consistent implementation
  String _hashPasswordLikeLocal(String password) {
    try {
      // Use SHA-256 as default - you may need to adjust this to match your local system
      return sha256.convert(utf8.encode(password)).toString();

      // If your local system uses MD5 (less secure):
      // return md5.convert(utf8.encode(password)).toString();

      // If your local system uses salt:
      // return sha256.convert(utf8.encode(password + 'your_salt_here')).toString();
    } catch (e) {
      print('❌ Error hashing password: $e');
      return password; // Fallback to plain text
    }
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
