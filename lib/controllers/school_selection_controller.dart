import 'package:driving/models/user.dart';
import 'package:driving/services/school_api_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_helper.dart';
import '../controllers/auth_controller.dart';
import '../controllers/settings_controller.dart';
import '../services/school_config_service.dart';

class SchoolSelectionController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Controllers for join school form
  final TextEditingController schoolNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isAuthenticating = false.obs;
  final RxBool isSettingUpAccount = false.obs;
  final RxString loadingMessage = ''.obs;
  final RxBool obscurePassword = true.obs;
  final RxString selectedSchoolId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _ensureSchoolsTableExists();
  }

  @override
  void onClose() {
    schoolNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  /// Toggle password visibility
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  Future<void> joinSchool() async {
    final schoolName = schoolNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (schoolName.isEmpty || email.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Error',
        'Please fill in all fields',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // Step 1: Start loading
      isLoading(true);
      isAuthenticating(true);

      // ❌ REMOVED: Don't call ensureSchoolDataPersistence here
      // It doesn't have an ID yet!

      // Close the join dialog first
      Get.back();

      // Step 2: Show loading dialog
      _showLoadingDialog();

      // Step 3: Check connectivity
      loadingMessage.value = 'Checking connection...';
      final isOnline = await SchoolApiService.isOnline();

      if (isOnline) {
        loadingMessage.value = 'Authenticating with school...';
        print('🌐 Attempting online school authentication...');
        await _joinSchoolOnline(schoolName, email, password);
      } else {
        loadingMessage.value = 'Authenticating offline...';
        print('📱 Using offline authentication...');
        await _joinSchoolOffline(schoolName, email, password);
      }
    } catch (e) {
      print('❌ School join failed: $e');

      // Close loading dialog
      _closeLoadingDialog();

      // Try offline fallback
      try {
        loadingMessage.value = 'Trying offline authentication...';
        _showLoadingDialog();
        print('🔄 Trying offline fallback authentication...');
        await _joinSchoolOffline(schoolName, email, password);
      } catch (offlineError) {
        _closeLoadingDialog();
        Get.snackbar(
          'Authentication Failed',
          'Unable to authenticate: $offlineError',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }
    } finally {
      isLoading(false);
      isAuthenticating(false);
      isSettingUpAccount(false);
      loadingMessage.value = '';
    }
  }

  /// Show enhanced loading dialog
  void _showLoadingDialog() {
    Get.dialog(
      Obx(() => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  loadingMessage.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isSettingUpAccount.value) ...[
                  SizedBox(height: 12),
                  Text(
                    'Please wait while we prepare your account...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          )),
      barrierDismissible: false,
    );
  }

  /// Close loading dialog
  void _closeLoadingDialog() {
    if (Get.isDialogOpen == true) {
      Get.back();
    }
  }

  /// Enhanced offline authentication
  Future<void> _joinSchoolOffline(
      String schoolName, String email, String password) async {
    try {
      loadingMessage.value = 'Finding school locally...';

      // Find school by name or invitation code
      final school = await _findSchoolByNameOrCode(schoolName);

      if (school == null) {
        throw Exception('No school found with name or code: $schoolName');
      }

      loadingMessage.value = 'Verifying credentials...';

      // Authenticate user locally
      final isAuthenticated =
          await _authenticateUser(school['id'], email, password);

      if (isAuthenticated) {
        loadingMessage.value = 'Setting up offline access...';
        isAuthenticating(false);
        isSettingUpAccount(true);

        await Future.delayed(Duration(milliseconds: 500));

        await _setCurrentSchool(school);

        // Set user as authenticated in AuthController
        final authController = Get.find<AuthController>();
        final db = await DatabaseHelper.instance.database;
        final userData = await db.query(
          'users',
          where: 'email = ? AND school_id = ?',
          whereArgs: [email, school['id']],
          limit: 1,
        );

        if (userData.isNotEmpty) {
          final user = User.fromJson(userData.first);
          authController.currentUser.value = user;
          authController.isLoggedIn.value = true;
          authController.userEmail.value = email;
          print('✅ User authenticated offline: $email');
        }

        _clearForm();
        _closeLoadingDialog();

        // Show success dialog for offline mode
        await _showSuccessDialogAndNavigate(
          schoolName: school['name'],
          isOnline: false,
        );
      } else {
        throw Exception('Invalid credentials for this school');
      }
    } catch (e) {
      _closeLoadingDialog();
      print('❌ Offline authentication failed: $e');
      rethrow;
    }
  }

  /// Enhanced success dialog with smooth navigation
  Future<void> _showSuccessDialogAndNavigate({
    required String schoolName,
    required bool isOnline,
    int trialDays = 0,
  }) async {
    await Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: isOnline ? Colors.green.shade600 : Colors.orange.shade600,
              size: 32,
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Welcome!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOnline
                  ? trialDays > 0
                      ? 'Successfully joined $schoolName. $trialDays trial days remaining.'
                      : 'Successfully joined $schoolName.'
                  : 'Successfully joined $schoolName (offline mode).',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security,
                          color: Colors.blue.shade600, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Quick Access Setup',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Set up a 4-digit PIN for instant access to your account. '
                    'No more typing email and password every time!',
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
          ElevatedButton(
            onPressed: () {
              Get.back(); // Close dialog
              // Small delay for smooth transition
              Future.delayed(Duration(milliseconds: 200), () {
                Get.offAllNamed('/pin-setup');
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isOnline ? Colors.green.shade600 : Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Set Up PIN'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // Rest of your existing methods remain the same...
  void _clearForm() {
    schoolNameController.clear();
    emailController.clear();
    passwordController.clear();
  }

  // Replace these methods in your school_selection_controller.dart

  /// Save online authentication result locally - FIXED VERSION
  Future<void> _saveOnlineResultLocally(Map<String, dynamic> result) async {
    try {
      print('🔍 === SAVING ONLINE RESULT ===');
      print('Result keys: ${result.keys.toList()}');
      print('School data: ${result['school']}');
      print('User data: ${result['user']}');

      final db = await _dbHelper.database;
      final school = result['school'];
      final user = result['user'];

      // CRITICAL FIX: Handle integer IDs and convert to string
      final schoolId = school['id']?.toString() ?? '';
      final userId = user['id']?.toString() ?? '';

      if (schoolId.isEmpty || schoolId == 'null') {
        print('❌ School data: $school');
        throw Exception('School ID is missing or empty');
      }
      if (userId.isEmpty || userId == 'null') {
        print('❌ User data: $user');
        throw Exception('User ID is missing or empty');
      }

      print('💾 Saving school: ID=$schoolId, Name=${school['name']}');

      // Save school - Handle missing optional fields
      await db.insert(
        'schools',
        {
          'id': schoolId,
          'name': school['name']?.toString() ?? 'Unknown School',
          'address': school['address']?.toString() ?? '',
          'location':
              '${school['city'] ?? ''}, ${school['country'] ?? ''}'.trim(),
          'phone': school['phone']?.toString() ?? '',
          'email': school['email']?.toString() ?? '',
          'website': school['website']?.toString() ?? '',
          'start_time': school['start_time']?.toString() ?? '09:00',
          'end_time': school['end_time']?.toString() ?? '17:00',
          'operating_days': school['operating_days'] != null
              ? (school['operating_days'] is List
                  ? (school['operating_days'] as List).join(',')
                  : school['operating_days'].toString())
              : 'Mon,Tue,Wed,Thu,Fri',
          'invitation_code': school['invitation_code']?.toString() ?? '',
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm:
            ConflictAlgorithm.replace, // Use replace instead of ignore
      );

      print('💾 Saving user: ID=$userId, Email=${user['email']}');

      // CRITICAL FIX: Handle combined name field from API
      String firstName = '';
      String lastName = '';

      if (user['fname'] != null && user['lname'] != null) {
        // If API provides separate fname/lname
        firstName = user['fname'].toString();
        lastName = user['lname'].toString();
      } else if (user['name'] != null) {
        // If API provides combined name (like "Myla Chikso")
        final nameParts = user['name'].toString().split(' ');
        firstName = nameParts.first;
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      }

      // Save user
      await db.insert(
        'users',
        {
          'id': userId,
          'school_id': schoolId,
          'email': user['email']?.toString() ?? '',
          'password': 'online_authenticated', // Placeholder for online users
          'role': user['role']?.toString() ?? 'staff',
          'fname': firstName,
          'lname': lastName,
          'phone': user['phone']?.toString() ?? '',
          'date_of_birth':
              user['date_of_birth']?.toString() ?? '2000-01-01', // ✅ ADDED
          'gender':
              user['gender']?.toString() ?? 'other', // ✅ ADDED (if needed)
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm:
            ConflictAlgorithm.replace, // Use replace instead of ignore
      );

      print('✅ Online result saved locally for offline access');
    } catch (e) {
      print('❌ Failed to save online result locally: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      // Don't throw - this is just for offline access
    }
  }

  /// Enhanced online authentication - FIXED VERSION
  Future<void> _joinSchoolOnline(
      String schoolName, String email, String password) async {
    try {
      loadingMessage.value = 'Verifying school credentials...';

      // Authenticate with API
      final result = await SchoolApiService.authenticateSchoolUser(
        schoolIdentifier: schoolName,
        email: email,
        password: password,
      );

      print('🔍 API Result received: ${result.keys.toList()}');

      // CRITICAL: Validate response structure
      if (result['school'] == null) {
        throw Exception('API response missing school data');
      }
      if (result['user'] == null) {
        throw Exception('API response missing user data');
      }
      if (result['school']['id'] == null) {
        throw Exception('School data missing ID');
      }
      if (result['user']['id'] == null) {
        throw Exception('User data missing ID');
      }

      loadingMessage.value = 'Setting up your account...';
      isAuthenticating(false);
      isSettingUpAccount(true);

      // Give UI time to update
      await Future.delayed(Duration(milliseconds: 500));

      // ✅ NOW call ensureSchoolDataPersistence with FULL school data (has ID)
      await ensureSchoolDataPersistence({
        'id': result['school']['id'].toString(),
        'name': result['school']['name'],
        'invitation_code': result['school']['invitation_code'],
        'address': result['school']['address'] ?? '',
        'phone': result['school']['phone'] ?? '',
        'email': result['school']['email'] ?? '',
        'location':
            '${result['school']['city'] ?? ''}, ${result['school']['country'] ?? ''}'
                .trim(),
      });

      // Save school and user info locally for offline access
      await _saveOnlineResultLocally(result);

      // Update settings controller
      await _setCurrentSchool(result['school']);

      // Set user as authenticated in AuthController
      final authController = Get.find<AuthController>();

      // FIXED: Handle combined name field
      String firstName = '';
      String lastName = '';

      if (result['user']['fname'] != null && result['user']['lname'] != null) {
        firstName = result['user']['fname'].toString();
        lastName = result['user']['lname'].toString();
      } else if (result['user']['name'] != null) {
        final nameParts = result['user']['name'].toString().split(' ');
        firstName = nameParts.first;
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      }

      final user = User.fromJson({
        'id': result['user']['id']?.toString() ?? '',
        'email': result['user']['email']?.toString() ?? '',
        'fname': firstName,
        'lname': lastName,
        'role': result['user']['role']?.toString() ?? 'staff',
        'phone': result['user']['phone']?.toString() ?? '',
        'status': 'active',
        'school_id': result['school']['id']?.toString() ?? '',
      });

      authController.currentUser.value = user;
      authController.isLoggedIn.value = true;
      authController.userEmail.value =
          result['user']['email']?.toString() ?? '';

      print('✅ User authenticated after joining: ${result['user']['email']}');

      _clearForm();
      _closeLoadingDialog();

      // Show success dialog with smooth transition
      await _showSuccessDialogAndNavigate(
        schoolName: result['school']['name']?.toString() ?? 'School',
        isOnline: true,
        trialDays: result['trial_days_remaining'] ?? 0,
      );
    } catch (e) {
      _closeLoadingDialog();
      print('❌ Online authentication failed: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      throw Exception('Online authentication failed: $e');
    }
  }

  /// Find school by name or invitation code
  Future<Map<String, dynamic>?> _findSchoolByNameOrCode(
      String searchTerm) async {
    try {
      final db = await _dbHelper.database;

      // Search by name first (case insensitive)
      var result = await db.query(
        'schools',
        where: 'LOWER(name) LIKE ? AND status = ?',
        whereArgs: ['%${searchTerm.toLowerCase()}%', 'active'],
      );

      if (result.isNotEmpty) {
        return result.first;
      }

      // If not found by name, search by invitation code
      result = await db.query(
        'schools',
        where: 'invitation_code = ? AND status = ?',
        whereArgs: [searchTerm.toUpperCase(), 'active'],
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ Error finding school: $e');
      return null;
    }
  }

  /// Authenticate user (simulate for now)
  Future<bool> _authenticateUser(
      String schoolId, String email, String password) async {
    try {
      // In a real app, this would make an API call to your backend
      // For demo purposes, we'll check against a users table or use demo credentials

      final db = await _dbHelper.database;

      // Create users table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          school_id TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          role TEXT DEFAULT 'staff',
          status TEXT DEFAULT 'active',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (school_id) REFERENCES schools (id)
        )
      ''');

      // For demo: allow admin@school.com with password 'admin123' for any school
      if (email.toLowerCase() == 'admin@school.com' && password == 'admin123') {
        return true;
      }

      // Check against users table (in real app, you'd hash the password)
      final userResult = await db.query(
        'users',
        where: 'school_id = ? AND email = ? AND status = ?',
        whereArgs: [schoolId, email.toLowerCase(), 'active'],
      );

      if (userResult.isNotEmpty) {
        final user = userResult.first;
        // In real app: return BCrypt.checkpw(password, user['password_hash']);
        return user['password'] == password; // Simplified for demo
      }

      return false;
    } catch (e) {
      print('❌ Error authenticating user: $e');
      return false;
    }
  }

  /// CRITICAL FIX: Ensure school data is saved to BOTH tables
  Future<void> ensureSchoolDataPersistence(Map<String, dynamic> school) async {
    try {
      print('🔧 Ensuring school data persistence...');
      final db = await _dbHelper.database;
      final schoolIdString = school['id']?.toString() ?? '';

      if (schoolIdString.isEmpty) {
        throw Exception('School ID is empty');
      }

      // STEP 1: Verify school exists in schools table
      final schoolCheck = await db.query(
        'schools',
        where: 'id = ?',
        whereArgs: [schoolIdString],
      );

      if (schoolCheck.isEmpty) {
        print('⚠️ School not in schools table, inserting...');
        await db.insert('schools', {
          'id': schoolIdString,
          'name': school['name'],
          'location': school['location'],
          'phone': school['phone'],
          'email': school['email'],
          'address': school['address'] ?? '',
          'status': 'active',
          'invitation_code': school['invitation_code'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // STEP 2: Verify school_id exists in settings table
      final settingsCheck = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['school_id'],
      );

      if (settingsCheck.isEmpty ||
          settingsCheck.first['value'] != schoolIdString) {
        print('⚠️ School ID not in settings, inserting...');
        await db.insert(
          'settings',
          {'key': 'school_id', 'value': schoolIdString},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // STEP 3: Verify business_name exists in settings
      final businessNameCheck = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['business_name'],
      );

      if (businessNameCheck.isEmpty) {
        print('⚠️ Business name not in settings, inserting...');
        await db.insert(
          'settings',
          {'key': 'business_name', 'value': school['name']},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // STEP 4: Verify first_run_completed flag
      await db.insert(
        'settings',
        {'key': 'first_run_completed', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // STEP 5: Update SettingsController
      final settingsController = Get.find<SettingsController>();
      settingsController.schoolId(schoolIdString);
      settingsController.setBusinessName(school['name'] ?? '');
      settingsController.setBusinessAddress(school['address'] ?? '');
      settingsController.setBusinessPhone(school['phone'] ?? '');
      settingsController.setBusinessEmail(school['email'] ?? '');

      print('✅ School data persistence verified');

      // STEP 6: Verify the data was saved
      await _verifySchoolDataSaved(schoolIdString);
    } catch (e) {
      print('❌ Error ensuring school data persistence: $e');
      throw Exception('Failed to persist school data: $e');
    }
  }

  /// Verify school data is actually saved
  Future<void> _verifySchoolDataSaved(String schoolId) async {
    try {
      final db = await _dbHelper.database;

      // Check schools table
      final schoolResult = await db.query(
        'schools',
        where: 'id = ?',
        whereArgs: [schoolId],
      );

      // Check settings table
      final settingsResult = await db.query(
        'settings',
        where: 'key IN (?, ?)',
        whereArgs: ['school_id', 'business_name'],
      );

      print('🔍 Verification Results:');
      print('   Schools table: ${schoolResult.isNotEmpty ? "✅" : "❌"}');
      print('   Settings table entries: ${settingsResult.length}');

      for (var setting in settingsResult) {
        print('   - ${setting['key']}: ${setting['value']}');
      }

      if (schoolResult.isEmpty || settingsResult.length < 2) {
        throw Exception('School data verification failed');
      }
    } catch (e) {
      print('❌ Verification failed: $e');
      throw e;
    }
  }

  /// Set current school in settings
  Future<void> _setCurrentSchool(Map<String, dynamic> school) async {
    try {
      // ✅ FIXED: Convert school ID to String properly
      final schoolIdValue = school['id'];
      String schoolIdString;

      if (schoolIdValue is int) {
        schoolIdString = schoolIdValue.toString();
      } else if (schoolIdValue is String) {
        schoolIdString = schoolIdValue;
      } else {
        throw Exception('Invalid school ID type: ${schoolIdValue.runtimeType}');
      }

      print(
          '🏫 Setting current school ID: $schoolIdString (converted from ${schoolIdValue.runtimeType})');

      selectedSchoolId(schoolIdString); // Now passing String instead of int

      // Update settings controller
      final settingsController = Get.find<SettingsController>();
      settingsController.schoolId.value = schoolIdString; // ✅ String conversion
      settingsController.schoolDisplayName.value = school['name'].toString();
      settingsController.enableMultiTenant.value = true;

      // Update business info from school data
      settingsController.setBusinessName(school['name'].toString());
      settingsController
          .setBusinessAddress(school['address']?.toString() ?? '');
      settingsController.setBusinessPhone(school['phone']?.toString() ?? '');
      settingsController.setBusinessEmail(school['email']?.toString() ?? '');

      // Save to database with String ID
      await _dbHelper.setCurrentSchoolId(schoolIdString);

      // Update school configuration service if available
      if (Get.isRegistered<SchoolConfigService>()) {
        final schoolConfig = Get.find<SchoolConfigService>();
        await schoolConfig.updateSchoolConfig();
      }

      print(
          '✅ Current school set successfully: ${school['name']} (ID: $schoolIdString)');
    } catch (e) {
      print('❌ Error setting current school: $e');
      throw Exception('Failed to set current school: $e');
    }
  }

  /// Ensure schools table exists
  Future<void> _ensureSchoolsTableExists() async {
    try {
      final db = await _dbHelper.database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schools (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          location TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          status TEXT DEFAULT 'active',
          invitation_code TEXT UNIQUE,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      print('✅ Schools table ensured');
    } catch (e) {
      print('❌ Error creating schools table: $e');
    }
  }

  /// Navigate to school registration
  void navigateToSchoolRegistration() {
    Get.toNamed('/school-registration');
  }

  static Future<bool> isFirstRun() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Method 1: Check first_run flag in settings
      final settings = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['first_run_completed'],
      );

      if (settings.isNotEmpty) {
        final isCompleted = settings.first['value'] == '1';
        print('🔍 First run completed flag: $isCompleted');

        if (isCompleted) {
          // Double-check we have school data
          final hasSchoolData = await _hasValidSchoolData(db);
          print('🔍 Has valid school data: $hasSchoolData');
          return !hasSchoolData; // Return true if we DON'T have valid data
        }
        return true; // First run not completed
      }

      // Method 2: Check if we have any school configuration
      final hasSchoolData = await _hasValidSchoolData(db);
      print('🔍 Has school data (no flag): $hasSchoolData');

      return !hasSchoolData; // First run if no school data
    } catch (e) {
      print('❌ Error checking first run: $e');
      return true; // Assume first run on error
    }
  }

  /// Check if we have valid school data in any table
  static Future<bool> _hasValidSchoolData(dynamic db) async {
    try {
      // Check settings table
      final businessNameResult = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['business_name'],
      );

      if (businessNameResult.isNotEmpty) {
        final businessName = businessNameResult.first['value']?.toString();
        if (businessName != null && businessName.isNotEmpty) {
          print('✅ Found business name in settings: $businessName');
          return true;
        }
      }

      // Check schools table
      final schoolsResult = await db.query('schools', limit: 1);
      if (schoolsResult.isNotEmpty) {
        final schoolName = schoolsResult.first['name']?.toString();
        print('✅ Found school in schools table: $schoolName');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error checking school data: $e');
      return false;
    }
  }

  /// Mark first run as completed - ENHANCED VERSION
  static Future<void> markFirstRunCompleted() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'settings',
        {'key': 'first_run_completed', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ First run marked as completed');
    } catch (e) {
      print('❌ Error marking first run completed: $e');
    }
  }
}
