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
      loadingMessage.value = 'Connecting to server...';

      // Close the join dialog first
      Get.back();

      // Step 2: Show loading dialog
      _showLoadingDialog();

      // Step 3: Check connectivity
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

  /// Enhanced online authentication with loading states
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

      loadingMessage.value = 'Setting up your account...';
      isAuthenticating(false);
      isSettingUpAccount(true);

      // Give UI time to update
      await Future.delayed(Duration(milliseconds: 500));

      // Save school and user info locally for offline access
      await _saveOnlineResultLocally(result);

      // Update settings controller
      await _setCurrentSchool(result['school']);

      // Set user as authenticated in AuthController
      final authController = Get.find<AuthController>();
      final user = User.fromJson({
        'id': result['user']['id'],
        'email': result['user']['email'],
        'fname': result['user']['fname'] ?? '',
        'lname': result['user']['lname'] ?? '',
        'role': result['user']['role'],
        'phone': result['user']['phone'] ?? '',
        'status': 'active',
        'school_id': result['school']['id'].toString(),
      });

      authController.currentUser.value = user;
      authController.isLoggedIn.value = true;
      authController.userEmail.value = result['user']['email'];

      print('✅ User authenticated after joining: ${result['user']['email']}');

      _clearForm();
      _closeLoadingDialog();

      // Show success dialog with smooth transition
      await _showSuccessDialogAndNavigate(
        schoolName: result['school']['name'],
        isOnline: true,
        trialDays: result['trial_days_remaining'] ?? 0,
      );
    } catch (e) {
      _closeLoadingDialog();
      print('❌ Online authentication failed: $e');
      throw Exception('Online authentication failed: $e');
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

  /// Save online authentication result locally
  Future<void> _saveOnlineResultLocally(Map<String, dynamic> result) async {
    try {
      final db = await _dbHelper.database;
      final school = result['school'];
      final user = result['user'];

      // Save school if not exists
      await db.insert(
          'schools',
          {
            'id': school['id'].toString(),
            'name': school['name'],
            'address': school['address'] ?? '',
            'location': '${school['city'] ?? ''}, ${school['country'] ?? ''}',
            'phone': school['phone'] ?? '',
            'email': school['email'] ?? '',
            'website': school['website'] ?? '',
            'start_time': school['start_time'] ?? '09:00',
            'end_time': school['end_time'] ?? '17:00',
            'operating_days': (school['operating_days'] as List? ??
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'])
                .join(','),
            'invitation_code': school['invitation_code'] ?? '',
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);

      // Save user if not exists
      await db.insert(
          'users',
          {
            'id': user['id'].toString(),
            'school_id': school['id'].toString(),
            'email': user['email'],
            'password': 'online_user', // Placeholder for online users
            'role': user['role'],
            'fname': user['fname'] ?? '',
            'lname': user['lname'] ?? '',
            'phone': user['phone'] ?? '',
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);

      print('✅ Online result saved locally for offline access');
    } catch (e) {
      print('❌ Failed to save online result locally: $e');
      // Don't throw - this is just for offline access
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

  /// Check if app is running for the first time
  static Future<bool> isFirstRun() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final settings = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['first_run_completed'],
      );

      return settings.isEmpty;
    } catch (e) {
      print('❌ Error checking first run: $e');
      return true; // Assume first run if error
    }
  }

  /// Mark first run as completed
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

  /// Create sample schools for demonstration (for development only)
  Future<void> createSampleSchools() async {
    try {
      final db = await _dbHelper.database;

      final sampleSchools = [
        {
          'id': 'school_001',
          'name': 'Metro Driving School',
          'location': 'Harare, Zimbabwe',
          'phone': '+263 77 123 4567',
          'email': 'info@metrodriving.co.zw',
          'address': '123 Main Street, Harare',
          'invitation_code': 'METRO2024',
          'status': 'active',
        },
        {
          'id': 'school_002',
          'name': 'Safe Drive Academy',
          'location': 'Bulawayo, Zimbabwe',
          'phone': '+263 77 987 6543',
          'email': 'contact@safedrive.co.zw',
          'address': '456 Oak Avenue, Bulawayo',
          'invitation_code': 'SAFE2024',
          'status': 'active',
        },
      ];

      for (final school in sampleSchools) {
        await db.insert(
          'schools',
          school,
          conflictAlgorithm:
              ConflictAlgorithm.ignore, // Don't overwrite existing
        );
      }

      // Create sample users for demo
      final sampleUsers = [
        {
          'id': 'user_001',
          'school_id': 'school_001',
          'email': 'admin@metro.com',
          'password': 'admin123', // In real app, this would be hashed
          'role': 'admin',
          'status': 'active',
        },
        {
          'id': 'user_002',
          'school_id': 'school_002',
          'email': 'admin@safedrive.com',
          'password': 'admin123',
          'role': 'admin',
          'status': 'active',
        },
      ];

      for (final user in sampleUsers) {
        await db.insert(
          'users',
          user,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      print('✅ Sample schools and users created');
    } catch (e) {
      print('❌ Error creating sample schools: $e');
    }
  }
}
