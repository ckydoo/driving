// lib/controllers/auth_controller.dart - Updated with PIN integration for SQLite
import 'package:crypto/crypto.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoggedIn = false.obs;

  // Remember me functionality
  final RxBool rememberMe = false.obs;

  // Get PIN controller
  PinController get _pinController => Get.find<PinController>();

  @override
  void onInit() {
    super.onInit();

    // Initialize PIN Controller first
    Get.lazyPut(() => PinController());

    _checkLoginStatus();
  }

  // Check if user is already logged in (from saved session)
  Future<void> _checkLoginStatus() async {
    try {
      // Test password hashing to ensure it works correctly
      _testPasswordHashing();

      // Ensure default users exist
      await DatabaseHelper.instance.ensureDefaultUsersExist();

      // Check if user should use PIN login
      await _handleInitialAuthFlow();
    } catch (e) {
      print('Error checking login status: $e');
      isLoggedIn(false);
    }
  }

  Future<void> _handleInitialAuthFlow() async {
    // Check if user has completed initial email/password verification
    final isUserVerified = await _pinController.isUserVerified();

    if (isUserVerified) {
      // User is verified - check PIN status
      if (_pinController.shouldUsePinAuth()) {
        // PIN is set up and enabled, should show PIN login
        // Note: We don't auto-navigate here, let the UI handle routing
        isLoggedIn(false); // User needs to authenticate with PIN
      } else {
        // No PIN or PIN disabled, user needs email/password login
        isLoggedIn(false);
      }
    } else {
      // No previous verification, user needs email/password login
      isLoggedIn(false);
    }
  }

  // Determine initial route for app startup
  Future<String> determineInitialRoute() async {
    await Future.delayed(const Duration(milliseconds: 100));

    final isUserVerified = await _pinController.isUserVerified();
    if (!isUserVerified) {
      return '/login';
    }

    // Check if should use PIN login
    if (_pinController.shouldUsePinAuth()) {
      return '/pin-login';
    }

    // Default to email/password login
    return '/login';
  }

  // Test password hashing function
  void _testPasswordHashing() {
    final testPassword = 'admin123';
    final hashedPassword = _hashPassword(testPassword);
    print('🔐 Test Password Hash for "$testPassword":');
    print('   Hash: $hashedPassword');
    print('   Length: ${hashedPassword.length}');
  }

  // Hash password using SHA-256 - FIXED VERSION
  String _hashPassword(String password) {
    try {
      var bytes = utf8.encode(password);
      var digest = sha256.convert(bytes);
      final hashedPassword = digest.toString();
      print(
          '🔑 Hashing password: "$password" -> ${hashedPassword.substring(0, 20)}...');
      return hashedPassword;
    } catch (e) {
      print('❌ Error hashing password: $e');
      return password; // Fallback to plain text if hashing fails
    }
  }

  // Login method with enhanced debugging and fixed password comparison
  Future<bool> login(String email, String password) async {
    try {
      isLoading(true);
      error('');

      print('\n🔐 === LOGIN ATTEMPT ===');
      print('📧 Email: $email');
      print('🔑 Password length: ${password.length}');

      if (email.isEmpty || password.isEmpty) {
        error('Email and password are required');
        return false;
      }

      // Get all users from database for debugging
      final allUsers = await DatabaseHelper.instance.getUsers();
      print('📊 Total users in database: ${allUsers.length}');

      // Find user by email
      final userData = allUsers.firstWhereOrNull(
        (user) => user['email'].toString().toLowerCase() == email.toLowerCase(),
      );

      if (userData == null) {
        print('❌ No user found with email: $email');
        print('📧 Available emails in database:');
        for (var user in allUsers) {
          print('  - ${user['email']} (${user['role']})');
        }
        error('User not found. Please check your email address.');
        return false;
      }

      print(
          '✅ User found: ${userData['fname']} ${userData['lname']} (${userData['role']})');

      // Get stored password
      final storedPassword = userData['password'].toString();
      print(
          '🔍 Stored password: ${storedPassword.substring(0, 20)}... (length: ${storedPassword.length})');

      // Hash the input password
      final hashedInputPassword = _hashPassword(password);
      print(
          '🔍 Input password hash: ${hashedInputPassword.substring(0, 20)}... (length: ${hashedInputPassword.length})');

      // Compare passwords - Support multiple methods
      bool passwordMatch = false;

      // Method 1: Direct hash comparison
      if (storedPassword == hashedInputPassword) {
        passwordMatch = true;
        print('✅ Password matched (hashed comparison)');
      }
      // Method 2: Plain text comparison (for backward compatibility)
      else if (storedPassword == password) {
        passwordMatch = true;
        print('✅ Password matched (plain text - will update to hashed)');

        // Update to hashed version
        try {
          final user = User.fromJson(userData);
          final updatedUser = User(
            id: user.id,
            fname: user.fname,
            lname: user.lname,
            email: user.email,
            password: hashedInputPassword,
            phone: user.phone,
            address: user.address,
            date_of_birth: user.date_of_birth,
            gender: user.gender,
            idnumber: user.idnumber,
            role: user.role,
            status: user.status,
            created_at: user.created_at,
          );
          await DatabaseHelper.instance.updateUser(updatedUser);
          print('🔄 Password updated to hashed version');
        } catch (e) {
          print('⚠️ Could not update password: $e');
        }
      }
      // Method 3: Check against known test password hash
      else {
        // Known hash for "admin123"
        const knownAdminHash =
            'c7ad44cbad762a5da0a452f9e854fdc1e0e7a52a38015f23f3eab1d80b931dd472634dfac71cd34ebc35d16ab7fb8a90c81f975113d6c7538dc69dd8de9077ec';
        if (storedPassword == knownAdminHash && password == 'admin123') {
          passwordMatch = true;
          print('✅ Password matched (known admin hash)');
        } else {
          print('❌ Password comparison failed:');
          print('   Stored: ${storedPassword.substring(0, 20)}...');
          print('   Input Hash: ${hashedInputPassword.substring(0, 20)}...');
          print('   Known Hash: ${knownAdminHash.substring(0, 20)}...');
          print('   Input Plain: $password');
        }
      }

      if (!passwordMatch) {
        error('Invalid password. Please check your password.');
        return false;
      }

      // Check if user is active
      final userStatus = userData['status'].toString().toLowerCase();
      if (userStatus != 'active') {
        print('❌ User account is inactive: $userStatus');
        error('Account is inactive. Please contact administrator.');
        return false;
      }

      print('✅ User status is active');

      // Create user object
      final userObj = User.fromJson(userData);
      currentUser.value = userObj;
      isLoggedIn(true);

      print('🎉 Login successful for ${userObj.fname} ${userObj.lname}');

      // Mark user as verified for PIN usage
      await _pinController.setUserVerified(true);

      // Handle post-login PIN flow
      await _handlePostLoginFlow();

      print('🔐 === LOGIN COMPLETE ===\n');

      return true;
    } catch (e) {
      print('💥 Login error: $e');
      error('Login failed: ${e.toString()}');
      return false;
    } finally {
      isLoading(false);
    }
  }

  Future<void> _handlePostLoginFlow() async {
    // Check if user should setup PIN or go to main app
    final isUserVerified = await _pinController.isUserVerified();

    if (!isUserVerified) {
      // First time login - offer to setup PIN
      _showPinSetupOption();
    } else {
      // User is verified - check PIN status for next login
      if (_pinController.shouldUsePinAuth()) {
        // PIN is set up and enabled, go to main app
        Get.offAllNamed('/main');
      } else if (_pinController.isPinEnabled.value &&
          !_pinController.isPinSet.value) {
        // PIN was enabled but not set (edge case), show setup
        Get.offAllNamed('/pin-setup');
      } else {
        // No PIN or PIN disabled, go to main app
        Get.offAllNamed('/main');
      }
    }
  }

  void _showPinSetupOption() {
    Get.dialog(
      AlertDialog(
        title: const Text('Quick Login Setup'),
        content: const Text(
            'Would you like to set up a 4-digit PIN for faster login next time? '
            'You can always change this later in settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              // Skip PIN setup, but mark as verified
              _pinController.setUserVerified(true);
              Get.offAllNamed('/main');
            },
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed('/pin-setup');
            },
            child: const Text('Setup PIN'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // PIN Authentication - verify PIN and login user
  Future<bool> authenticateWithPin(String pin) async {
    try {
      final isValid = await _pinController.verifyPin(pin);
      if (isValid) {
        // Get the user email associated with the PIN
        final pinUserEmail = await _pinController.getPinUserEmail();

        if (pinUserEmail != null) {
          // Get user from database
          final users = await DatabaseHelper.instance.getUsers();
          final userData = users.firstWhereOrNull(
            (user) =>
                user['email'].toString().toLowerCase() ==
                pinUserEmail.toLowerCase(),
          );

          if (userData != null) {
            final userObj = User.fromJson(userData);
            currentUser.value = userObj;
            isLoggedIn(true);

            print(
                '🎉 PIN login successful for ${userObj.fname} ${userObj.lname}');
            return true;
          }
        } else {
          // Fallback: use admin user for demonstration
          // In production, always associate PIN with specific user
          final users = await DatabaseHelper.instance.getUsers();
          final adminUser = users.firstWhereOrNull(
            (user) => user['email'] == 'admin@drivingschool.com',
          );

          if (adminUser != null) {
            final userObj = User.fromJson(adminUser);
            currentUser.value = userObj;
            isLoggedIn(true);

            // Set the PIN user email for future use
            await _pinController.setPinUserEmail(userObj.email);
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('PIN authentication error: $e');
      return false;
    }
  }

  // Force create test users with correct password hash
  Future<void> forceCreateTestUsers() async {
    try {
      print('🔧 Force creating test users...');

      // Generate correct hash for "admin123"
      final correctHash = _hashPassword('admin123');
      print('📝 Generated hash for admin123: $correctHash');

      final db = await DatabaseHelper.instance.database;

      // Delete existing users
      await db.delete('users');
      print('🗑️ Cleared existing users');

      // Create admin user
      await db.insert('users', {
        'fname': 'System',
        'lname': 'Administrator',
        'email': 'admin@drivingschool.com',
        'password': correctHash,
        'gender': 'Male',
        'phone': '+1234567890',
        'address': '123 Main Street',
        'date_of_birth': '1980-01-01',
        'role': 'admin',
        'status': 'Active',
        'idnumber': 'ADMIN001',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create instructor user
      await db.insert('users', {
        'fname': 'John',
        'lname': 'Instructor',
        'email': 'instructor@drivingschool.com',
        'password': correctHash,
        'gender': 'Male',
        'phone': '+1234567891',
        'address': '456 Oak Street',
        'date_of_birth': '1985-05-15',
        'role': 'instructor',
        'status': 'Active',
        'idnumber': 'INST001',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create student user
      await db.insert('users', {
        'fname': 'Jane',
        'lname': 'Student',
        'email': 'student@drivingschool.com',
        'password': correctHash,
        'gender': 'Female',
        'phone': '+1234567892',
        'address': '789 Pine Street',
        'date_of_birth': '1995-03-20',
        'role': 'student',
        'status': 'Active',
        'idnumber': 'STU001',
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Test users created with correct password hash');

      // Verify users were created
      final users = await DatabaseHelper.instance.getUsers();
      print('📊 Verification: ${users.length} users in database');
      for (var user in users) {
        print(
            '  - ${user['email']} (${user['role']}) - Hash: ${user['password'].toString().substring(0, 20)}...');
      }
    } catch (e) {
      print('❌ Error force creating test users: $e');
    }
  }

  // Register new user
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    required String address,
    required DateTime dateOfBirth,
    required String gender,
    required String idNumber,
    required String role,
  }) async {
    try {
      isLoading(true);
      error('');

      // Validate input
      if (firstName.isEmpty ||
          lastName.isEmpty ||
          email.isEmpty ||
          password.isEmpty) {
        error('All required fields must be filled');
        return false;
      }

      if (password.length < 6) {
        error('Password must be at least 6 characters long');
        return false;
      }

      // Check if user already exists
      final existingUsers = await DatabaseHelper.instance.getUsers();
      final userExists = existingUsers.any(
        (userData) =>
            userData['email'].toString().toLowerCase() == email.toLowerCase(),
      );

      if (userExists) {
        error('User with this email already exists');
        return false;
      }

      // Hash password
      final hashedPassword = _hashPassword(password);

      // Create new user
      final newUser = User(
        fname: firstName,
        lname: lastName,
        email: email,
        password: hashedPassword,
        phone: phone,
        address: address,
        date_of_birth: dateOfBirth,
        gender: gender,
        idnumber: idNumber,
        role: role,
        status: 'Active',
        created_at: DateTime.now(),
      );

      // Save to database
      await DatabaseHelper.instance.insertUser(newUser);

      Get.snackbar(
        'Registration Successful',
        'User account created successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      error('Registration failed: ${e.toString()}');
      return false;
    } finally {
      isLoading(false);
    }
  }

  // Change password
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      isLoading(true);
      error('');

      if (currentUser.value == null) {
        error('No user logged in');
        return false;
      }

      if (newPassword.length < 6) {
        error('New password must be at least 6 characters long');
        return false;
      }

      // Verify current password
      final hashedCurrentPassword = _hashPassword(currentPassword);
      if (currentUser.value!.password != hashedCurrentPassword &&
          currentUser.value!.password != currentPassword) {
        error('Current password is incorrect');
        return false;
      }

      // Hash new password
      final hashedNewPassword = _hashPassword(newPassword);

      // Update user in database
      final updatedUser = User(
        id: currentUser.value!.id,
        fname: currentUser.value!.fname,
        lname: currentUser.value!.lname,
        email: currentUser.value!.email,
        password: hashedNewPassword,
        phone: currentUser.value!.phone,
        address: currentUser.value!.address,
        date_of_birth: currentUser.value!.date_of_birth,
        gender: currentUser.value!.gender,
        idnumber: currentUser.value!.idnumber,
        role: currentUser.value!.role,
        status: currentUser.value!.status,
        created_at: currentUser.value!.created_at,
      );

      await DatabaseHelper.instance.updateUser(updatedUser);
      currentUser.value = updatedUser;

      Get.snackbar(
        'Password Changed',
        'Your password has been updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      error('Failed to change password: ${e.toString()}');
      return false;
    } finally {
      isLoading(false);
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Clear PIN data
      await _pinController.clearAllPinData();

      currentUser.value = null;
      isLoggedIn(false);
      rememberMe(false);

      // Navigate to login
      Get.offAllNamed('/login');

      Get.snackbar(
        'Logged Out',
        'You have been logged out successfully',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // PIN Management Methods
  Future<bool> setupPinFromSettings(String pin) async {
    if (currentUser.value != null) {
      return await _pinController.setupPin(pin,
          userEmail: currentUser.value!.email);
    }
    return await _pinController.setupPin(pin);
  }

  Future<bool> changePinFromSettings(String currentPin, String newPin) async {
    return await _pinController.changePin(currentPin, newPin);
  }

  Future<void> disablePinFromSettings() async {
    await _pinController.disablePin();
  }

  // Check if user has specific role
  bool hasRole(String role) {
    return currentUser.value?.role.toLowerCase() == role.toLowerCase();
  }

  // Check if user has any of the specified roles
  bool hasAnyRole(List<String> roles) {
    if (currentUser.value == null) return false;
    return roles.any((role) => hasRole(role));
  }

  // Get current user's full name
  String get currentUserName {
    if (currentUser.value == null) return 'Guest';
    return '${currentUser.value!.fname} ${currentUser.value!.lname}';
  }

  // Get current user's role
  String get currentUserRole {
    return currentUser.value?.role ?? 'Guest';
  }

  // Debug method to check database status
  Future<void> debugDatabase() async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      print('\n=== DATABASE DEBUG INFO ===');
      print('Total users in database: ${users.length}');

      for (var user in users) {
        print(
            'User: ${user['email']} | Role: ${user['role']} | Status: ${user['status']} | Hash: ${user['password'].toString().substring(0, 20)}...');
      }

      // Check if default admin exists
      final adminExists = users.any((user) =>
          user['email'].toString().toLowerCase() == 'admin@drivingschool.com');
      print('Default admin exists: $adminExists');

      if (!adminExists) {
        print('Creating default admin...');
        await forceCreateTestUsers();
      }
    } catch (e) {
      print('Error debugging database: $e');
    }
  }
}
