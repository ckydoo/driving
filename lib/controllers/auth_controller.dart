import 'package:crypto/crypto.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/sync_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/auth/initial_sync_screen.dart';
import 'package:driving/services/api_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AuthController extends GetxController {
  // UI Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  // Core authentication state
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoggedIn = false.obs;
  final RxBool rememberMe = false.obs;
  final RxString userEmail = ''.obs;

  // Get PIN controller
  PinController get _pinController => Get.find<PinController>();

  @override
  void onInit() {
    super.onInit();
    Get.lazyPut(() => PinController());
    _checkExistingLogin();
  }

  /// Check if user is already logged in on app start
  Future<void> _checkExistingLogin() async {
    try {
      // Check if user was previously logged in and should use PIN
      if (_pinController.shouldUsePinAuth()) {
        // User should authenticate with PIN
        isLoggedIn.value = false;
        print('🔐 PIN authentication required');
        return;
      }

      // Check for remembered user
      final savedEmail = userEmail.value;
      if (savedEmail.isNotEmpty) {
        await _loadUserFromCache(savedEmail);
      }
    } catch (e) {
      print('❌ Error checking existing login: $e');
      isLoggedIn.value = false;
    }
  }

  Future<bool> loginWithEmail(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('\n🔐 === EMAIL/PASSWORD LOGIN ===');
      print('📧 Email: $email');

      // Try API login first
      final apiSuccess = await loginWithApi(email, password);

      if (apiSuccess) {
        // ✅ FIRST: Check if PIN is setup
        final pinController = Get.find<PinController>();
        final hasPinSetup = await pinController.isPinSet();

        if (!hasPinSetup) {
          // No PIN - go to PIN setup first
          Get.offAllNamed('/pin-setup');
          return true;
        }

        // ✅ SECOND: PIN exists, now check sync
        final prefs = await SharedPreferences.getInstance();
        final hasCompletedSync =
            prefs.getBool('initial_sync_complete') ?? false;

        if (!hasCompletedSync) {
          Get.offAll(() => InitialSyncScreen());
        } else {
          _triggerPostLoginSync();
        }

        return true;
      }
      // If API login fails, try local login
      print('⚠️ API login failed, trying local login...');
      final localSuccess = await login(email, password);

      if (localSuccess) {
        // Same logic for local login
        final prefs = await SharedPreferences.getInstance();
        final hasCompletedSync =
            prefs.getBool('initial_sync_complete') ?? false;

        if (!hasCompletedSync) {
          Get.offAll(() => InitialSyncScreen());
        } else {
          _triggerPostLoginSync();
        }
      }

      return localSuccess;
    } catch (e) {
      print('❌ Login error: $e');
      error.value = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Validate email and password inputs
  bool _validateInputs() {
    if (emailController.text.trim().isEmpty) {
      error.value = 'Email is required';
      return false;
    }

    if (passwordController.text.isEmpty) {
      error.value = 'Password is required';
      return false;
    }

    return true;
  }

  /// Main login handler - decides online vs offline
  Future<void> handleLogin() async {
    try {
      isLoading.value = true;
      error.value = '';

      // Validate inputs
      if (!_validateInputs()) {
        return;
      }

      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text;

      print('\n🔐 === LOGIN ATTEMPT ===');
      print('📧 Email: $email');

      // Check if user exists locally
      final userExistsLocally = await _checkUserExistsLocally(email);

      if (userExistsLocally) {
        // User exists locally - try offline login first
        print('📂 User found locally - attempting offline login');
        final offlineSuccess = await _loginOffline(email, password);

        if (offlineSuccess) {
          // Offline login successful
          await _handleSuccessfulLogin(email);

          // Try online sync in background (don't wait for it)
          _attemptBackgroundSync(email, password);
          return;
        } else {
          // Offline login failed - try online
          print('⚠️ Offline login failed - attempting online login');
          final onlineSuccess = await _loginOnline(email, password);

          if (onlineSuccess) {
            await _handleSuccessfulLogin(email);
            return;
          }
        }
      } else {
        // User doesn't exist locally - must login online
        print('🌐 User not found locally - attempting online login');
        final onlineSuccess = await _loginOnline(email, password);

        if (onlineSuccess) {
          await _handleSuccessfulLogin(email);
          return;
        }
      }

      // If we get here, both failed
      error.value = 'Login failed. Please check your credentials.';
    } catch (e) {
      print('❌ Login error: $e');
      error.value = 'Login failed: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if user exists in local database
  Future<bool> _checkUserExistsLocally(String email) async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      final userData = users
          .where((user) =>
              user['email']?.toString().toLowerCase() == email.toLowerCase())
          .firstOrNull;
      return userData != null;
    } catch (e) {
      print('❌ Error checking local user: $e');
      return false;
    }
  }

  /// Attempt offline login with local credentials
  Future<bool> _loginOffline(String email, String password) async {
    try {
      print('📂 Attempting offline login...');
      return await login(email, password);
    } catch (e) {
      print('❌ Offline login error: $e');
      return false;
    }
  }

  /// Attempt online login via API
  Future<bool> _loginOnline(String email, String password) async {
    try {
      print('🌐 Attempting online login...');
      return await loginWithApi(email, password);
    } catch (e) {
      print('❌ Online login error: $e');
      return false;
    }
  }

  /// Handle successful login (common cleanup)
  Future<void> _handleSuccessfulLogin(String email) async {
    try {
      print('✅ Login successful for: $email');

      // Save email if remember me is enabled
      if (rememberMe.value) {
        userEmail.value = email;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remembered_email', email);
      }

      // Clear sync auth requirement
      await _setSyncAuthenticationRequired(false);

      print('✅ Post-login setup complete');
    } catch (e) {
      print('⚠️ Post-login setup error: $e');
      // Don't fail the login if post-setup fails
    }
  }

  /// Attempt background sync after login (non-blocking)
  Future<void> _attemptBackgroundSync(String email, String password) async {
    try {
      print('🔄 Attempting background sync...');

      // Try to sync with API in the background
      Future.delayed(Duration(milliseconds: 500), () async {
        try {
          await loginWithApi(email, password);
          print('✅ Background sync successful');
        } catch (e) {
          print('⚠️ Background sync failed: $e');
          // Ignore sync failures - user is already logged in offline
        }
      });
    } catch (e) {
      print('⚠️ Background sync setup error: $e');
    }
  }

  /// PRIMARY LOGIN METHOD - Local database only
  Future<bool> login(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('\n🔐 === LOCAL LOGIN ATTEMPT ===');
      print('📧 Email: $email');

      if (email.isEmpty || password.isEmpty) {
        error.value = 'Email and password are required';
        return false;
      }

      // Get users from local database
      final users = await DatabaseHelper.instance.getUsers();
      final userData = users
          .where((user) =>
              user['email']?.toString().toLowerCase() == email.toLowerCase())
          .firstOrNull;

      if (userData == null) {
        error.value = 'User not found. Please register first.';
        return false;
      }

      // Verify password
      final storedPassword = userData['password']?.toString() ?? '';
      bool passwordValid = false;

      // Support both plain text and hashed passwords for backward compatibility
      if (storedPassword == password) {
        passwordValid = true; // Plain text match
        print('🔓 Password matched (plain text)');
      } else if (storedPassword == _hashPassword(password)) {
        passwordValid = true; // Hashed password match
        print('🔓 Password matched (hashed)');
      }

      if (!passwordValid) {
        error.value = 'Invalid password';
        return false;
      }

      // Set user as logged in
      final user = User.fromJson(userData);
      currentUser.value = user;
      isLoggedIn.value = true;

      // Save email for future sessions if remember me is enabled
      if (rememberMe.value) {
        userEmail.value = email;
      }

      print('✅ Local authentication successful');
      print('✅ User: ${user.fname} ${user.lname} (${user.role})');

      return true;
    } catch (e) {
      print('❌ Login error: $e');
      error.value = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Register new user - Local database only
  Future<bool> registerWithEmailPassword(
      String email, String password, Map<String, dynamic> userData) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('🔐 Local registration attempt: $email');

      // Validate input
      if (email.isEmpty || password.isEmpty) {
        error.value = 'Email and password are required';
        return false;
      }

      if (password.length < 6) {
        error.value = 'Password must be at least 6 characters';
        return false;
      }

      // Check if user already exists
      final existingUsers = await DatabaseHelper.instance.getUsers();
      final existingUser = existingUsers
          .where((user) =>
              user['email']?.toString().toLowerCase() == email.toLowerCase())
          .firstOrNull;

      if (existingUser != null) {
        error.value = 'User with this email already exists';
        return false;
      }

      // Hash password for security
      userData['email'] = email.toLowerCase();
      userData['password'] = _hashPassword(password);
      userData['created_at'] = DateTime.now().toIso8601String();
      userData['last_modified'] = DateTime.now().toIso8601String();

      // Create and save user
      final user = User.fromJson(userData);
      final userId = await DatabaseHelper.instance.insertUser(user.toJson());

      print('✅ User registered locally with ID: $userId');
      print('✅ User: ${user.fname} ${user.lname} (${user.role})');

      return true;
    } catch (e) {
      print('❌ Registration error: $e');
      error.value = 'Registration failed: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Load remembered email if exists
  Future<void> _loadRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('remembered_email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        emailController.text = savedEmail;
        rememberMe.value = true;
      }
    } catch (e) {
      print('Error loading remembered email: $e');
    }
  }

  /// Get current API token from SharedPreferences
  Future<String?> _getCurrentApiToken() async {
    try {
      final user = currentUser.value;
      if (user?.email != null) {
        return await _getStoredApiToken(user!.email);
      }
      return null;
    } catch (e) {
      print('Error getting current API token: $e');
      return null;
    }
  }

  /// Set flag that sync needs authentication
  Future<void> _setSyncAuthenticationRequired(bool required) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_auth_required', required);
      print('🔄 Sync auth required flag set to: $required');
    } catch (e) {
      print('Error setting sync auth flag: $e');
    }
  }

  /// Check if sync needs authentication
  Future<bool> _isSyncAuthenticationRequired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('sync_auth_required') ?? false;
    } catch (e) {
      print('Error checking sync auth flag: $e');
      return false;
    }
  }

  /// Enhanced logout method - Clear stored tokens
  Future<void> logout() async {
    try {
      print('🚪 === LOGOUT START ===');

      final user = currentUser.value;

      // Try to logout from API if we have a token
      if (user?.email != null) {
        final token = await _getStoredApiToken(user!.email);
        if (token != null) {
          try {
            print('🔄 Logging out from API...');
            await ApiService.logout();
          } catch (e) {
            print('⚠️ API logout failed (continuing): $e');
          }

          // Clear stored token
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('api_token_${user.email}');
          print('✅ Stored API token cleared');
        }
      }

      // Clear API service token
      ApiService.clearToken();

      // Clear authentication state
      currentUser.value = null;
      isLoggedIn.value = false;
      error.value = '';

      // Clear PIN verification
      await _pinController.setUserVerified(false);

      // Set sync auth required
      await _setSyncAuthenticationRequired(true);

      print('✅ === LOGOUT COMPLETE ===');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  /// Setup PIN after successful login
  Future<bool> setupPinFromSettings(String pin) async {
    if (currentUser.value?.email == null) {
      error.value = 'No user logged in';
      return false;
    }

    try {
      final email = currentUser.value!.email;

      print('🔐 === SETTING UP PIN ===');
      print('📧 Email: $email');

      // Setup the PIN
      final success = await _pinController.setupPin(pin, userEmail: email);

      if (success) {
        print('✅ PIN setup successful for $email');
        await _ensureTokenIsAvailable(email);
      }

      return success;
    } catch (e) {
      print('❌ PIN setup error: $e');
      error.value = 'PIN setup failed: ${e.toString()}';
      return false;
    }
  }

  Future<void> _ensureTokenIsAvailable(String email) async {
    try {
      print('🔑 === ENSURING TOKEN IS AVAILABLE ===');

      // Check if ApiService already has a token
      if (ApiService.hasToken && ApiService.currentToken != null) {
        print(
            '✅ ApiService already has token: ${ApiService.currentToken!.substring(0, 10)}...');

        // Make sure it's also in storage for future sessions
        final storedToken = await _getStoredApiToken(email);
        if (storedToken == null || storedToken != ApiService.currentToken) {
          print('💾 Saving current ApiService token to storage...');
          await _storeApiToken(email, ApiService.currentToken!);
        }
        return;
      }

      print('⚠️ ApiService has no token, checking storage...');

      // Try to get from storage
      final storedToken = await _getStoredApiToken(email);

      if (storedToken != null && storedToken.isNotEmpty) {
        print('✅ Token found in storage: ${storedToken.substring(0, 10)}...');

        // Set it in ApiService
        ApiService.setToken(storedToken);
        print('✅ Token set in ApiService');

        // Verify
        if (ApiService.hasToken && ApiService.currentToken != null) {
          print('✅ Token verified and ready for API calls');
        } else {
          print('❌ Failed to set token in ApiService');
        }
      } else {
        print('❌ No token found anywhere!');
        print(
            '⚠️ This means the initial login did not save the token properly');
        print('💡 User will need to re-login with email/password');
      }
    } catch (e) {
      print('❌ Error ensuring token: $e');
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      if (currentUser.value == null) {
        error.value = 'No user logged in';
        return false;
      }

      isLoading.value = true;

      // Add last modified timestamp
      updates['last_modified'] = DateTime.now().toIso8601String();

      // Update in database
      final updatedUser = currentUser.value!.copyWith();
      await DatabaseHelper.instance.updateUser(updatedUser.toJson());

      // Update current user state
      currentUser.value = updatedUser;

      print('✅ User profile updated');
      return true;
    } catch (e) {
      print('❌ Profile update error: $e');
      error.value = 'Profile update failed: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Change password
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      if (currentUser.value == null) {
        error.value = 'No user logged in';
        return false;
      }

      isLoading.value = true;

      // Get current user data from database
      final users = await DatabaseHelper.instance.getUsers();
      final userData = users
          .where((user) => user['id'] == currentUser.value!.id)
          .firstOrNull;

      if (userData == null) {
        error.value = 'User not found';
        return false;
      }

      // Verify current password
      final storedPassword = userData['password']?.toString() ?? '';
      bool currentPasswordValid = false;

      if (storedPassword == currentPassword) {
        currentPasswordValid = true; // Plain text match
      } else if (storedPassword == _hashPassword(currentPassword)) {
        currentPasswordValid = true; // Hashed password match
      }

      if (!currentPasswordValid) {
        error.value = 'Current password is incorrect';
        return false;
      }

      // Validate new password
      if (newPassword.length < 6) {
        error.value = 'New password must be at least 6 characters';
        return false;
      }

      // Update password
      final hashedNewPassword = _hashPassword(newPassword);
      await updateUserProfile({'password': hashedNewPassword});

      print('✅ Password changed successfully');
      return true;
    } catch (e) {
      print('❌ Password change error: $e');
      error.value = 'Password change failed: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      isLoading.value = true;

      // Clear user state
      currentUser.value = null;
      isLoggedIn.value = false;

      // Clear remembered email if not persistent
      if (!rememberMe.value) {
        userEmail.value = '';
      }

      // Clear PIN if set to not remember
      if (!_pinController.isPinEnabled()) {
        await _pinController.clearAllPinData();
      }

      print('✅ User signed out successfully');
    } catch (e) {
      print('❌ Sign out error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete user account
  Future<bool> deleteAccount(String password) async {
    try {
      if (currentUser.value == null) {
        error.value = 'No user logged in';
        return false;
      }

      isLoading.value = true;

      // Verify password before deletion
      final users = await DatabaseHelper.instance.getUsers();
      final userData = users
          .where((user) => user['id'] == currentUser.value!.id)
          .firstOrNull;

      if (userData == null) {
        error.value = 'User not found';
        return false;
      }

      // Verify password
      final storedPassword = userData['password']?.toString() ?? '';
      bool passwordValid = false;

      if (storedPassword == password) {
        passwordValid = true;
      } else if (storedPassword == _hashPassword(password)) {
        passwordValid = true;
      }

      if (!passwordValid) {
        error.value = 'Password is incorrect';
        return false;
      }

      // Delete user from database
      await DatabaseHelper.instance.deleteUser(currentUser.value!.id!);

      // Clear all user data and PIN
      await signOut();
      await _pinController.clearAllPinData();

      print('✅ User account deleted successfully');
      return true;
    } catch (e) {
      print('❌ Account deletion error: $e');
      error.value = 'Account deletion failed: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get initial route based on authentication state
  Future<String> determineInitialRoute() async {
    try {
      // Check if PIN authentication should be used
      if (_pinController.shouldUsePinAuth()) {
        return '/pin-login';
      }

      // Check if user is already logged in
      if (isLoggedIn.value) {
        return '/main';
      }

      // Default to login screen
      return '/login';
    } catch (e) {
      print('❌ Error determining initial route: $e');
      return '/login';
    }
  }

  /// Hash password for security
  String _hashPassword(String password) {
    try {
      var bytes = utf8.encode(password);
      var digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('❌ Error hashing password: $e');
      return password; // Fallback to plain text (not recommended)
    }
  }

  /// Utility getters
  String get currentUserName {
    if (currentUser.value == null) return 'Guest';
    return '${currentUser.value!.fname} ${currentUser.value!.lname}';
  }

  String get currentUserRole {
    return currentUser.value?.role ?? 'Guest';
  }

  String? get currentUserId {
    return currentUser.value?.id?.toString();
  }

  /// PIN-related properties (for compatibility)
  bool get shouldUsePinAuth => _pinController.shouldUsePinAuth();
  bool get hasPinSetup => _pinController.isPinSet.value;

  /// Check if user has permission for specific school
  bool hasSchoolPermission(String schoolId) {
    if (!isLoggedIn.value || currentUser.value == null) return false;

    // You can implement school-specific permission logic here
    // For now, return true if user is logged in
    return true;
  }

  /// Get current user's school ID (if applicable)
  String? getCurrentUserSchoolId() {
    // Implement based on your User model structure
    // Return the school ID associated with the current user
    return currentUser.value?.schoolId;
  }

  /// Validate user session
  bool isValidSession() {
    return isLoggedIn.value && currentUser.value != null;
  }

  /// Refresh user data from database
  Future<void> refreshUserData() async {
    if (currentUser.value?.email == null) return;

    try {
      await _loadUserFromCache(currentUser.value!.email);
      print('✅ User data refreshed');
    } catch (e) {
      print('❌ Error refreshing user data: $e');
    }
  }

  bool hasAnyRole(List<String> roles) {
    try {
      // Check authentication first
      if (!isLoggedIn.value) {
        print('🚫 hasAnyRole: User not logged in');
        return false;
      }

      // Check if user object exists
      if (currentUser.value == null) {
        print('🚫 hasAnyRole: User object is null');
        return false;
      }

      // SAFE: Use null-aware access for role property
      final userRole = currentUser.value?.role?.toLowerCase();
      if (userRole == null || userRole.isEmpty) {
        print('🚫 hasAnyRole: User role is null or empty');
        return false;
      }

      // Check if user has any of the specified roles
      final hasRole = roles.any((role) => userRole == role.toLowerCase());
      print(
          '✅ hasAnyRole: User role "$userRole" - Has required role: $hasRole');
      return hasRole;
    } catch (e) {
      print('❌ hasAnyRole Error: $e');
      return false;
    }
  }

  bool hasRole(String role) {
    try {
      if (!isLoggedIn.value || currentUser.value == null) {
        return false;
      }

      final currentUserRole = currentUser.value?.role?.toLowerCase();
      if (currentUserRole == null) return false;

      return currentUserRole == role.toLowerCase();
    } catch (e) {
      print('❌ hasRole Error: $e');
      return false;
    }
  }

  /// Safe getter for user data availability
  bool get isUserDataAvailable {
    try {
      return isLoggedIn.value &&
          currentUser.value != null &&
          currentUser.value!.email?.isNotEmpty == true;
    } catch (e) {
      print('❌ isUserDataAvailable Error: $e');
      return false;
    }
  }

  String get userFullName {
    try {
      final user = currentUser.value;
      if (user == null) return 'User';

      final fname = user.fname ?? '';
      final lname = user.lname ?? '';

      if (fname.isEmpty && lname.isEmpty) {
        return user.email?.split('@').first ?? 'User';
      }

      return '$fname $lname'.trim();
    } catch (e) {
      print('❌ userFullName Error: $e');
      return 'User';
    }
  }

  String get userFirstName {
    try {
      final user = currentUser.value;
      if (user?.fname?.isNotEmpty == true) {
        return user!.fname!;
      }
      if (user?.email?.isNotEmpty == true) {
        return user!.email!.split('@').first;
      }
      return 'User';
    } catch (e) {
      print('❌ userFirstName Error: $e');
      return 'User';
    }
  }

  String get userInitials {
    try {
      final user = currentUser.value;
      if (user == null) return 'U';

      String initials = '';

      if (user.fname?.isNotEmpty == true) {
        initials += user.fname![0].toUpperCase();
      }

      if (user.lname?.isNotEmpty == true && initials.length < 2) {
        initials += user.lname![0].toUpperCase();
      }

      if (initials.isEmpty && user.email?.isNotEmpty == true) {
        initials = user.email![0].toUpperCase();
      }

      return initials.isNotEmpty ? initials : 'U';
    } catch (e) {
      print('❌ userInitials Error: $e');
      return 'U';
    }
  }

  String get userRole {
    try {
      return currentUser.value?.role?.toLowerCase() ?? 'guest';
    } catch (e) {
      print('❌ userRole Error: $e');
      return 'guest';
    }
  }

  /// Save user to local database for offline access
  Future<void> _saveUserToLocal(Map<String, dynamic> userData) async {
    try {
      print('📝 Preparing user data for local storage: ${userData['email']}');

      // CRITICAL FIX: Transform API user data to match local schema
      // API sends 'name' field, but local DB expects 'fname' and 'lname'

      String firstName = '';
      String lastName = '';

      if (userData['fname'] != null && userData['lname'] != null) {
        // If API provides separate fname/lname (shouldn't happen but handle it)
        firstName = userData['fname'].toString();
        lastName = userData['lname'].toString();
      } else if (userData['name'] != null) {
        // API provides combined name (like "Admin User")
        final nameParts = userData['name'].toString().split(' ');
        firstName = nameParts.first;
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      } else {
        // Fallback to email username
        firstName = userData['email']?.toString().split('@').first ?? 'User';
        lastName = '';
      }

      // Create a clean user data map for local storage
      final localUserData = {
        'id': userData['id'],
        'school_id': userData['school_id'],
        'email': userData['email'],
        'fname': firstName,
        'lname': lastName,
        'role': userData['role'] ?? 'student',
        'phone': userData['phone'] ?? '',
        'date_of_birth': userData['date_of_birth'] ?? '2000-01-01',
        'gender': userData['gender'] ?? 'other',
        'status': userData['status'] ?? 'active',
        'address': userData['address'] ?? '',
        'idnumber': userData['idnumber'] ?? '',
        'password': 'online_authenticated', // Placeholder for online users
        'created_at':
            userData['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Remove the 'name' field if it exists (not in local schema)
      localUserData.remove('name');

      print('📝 Transformed user data: fname=$firstName, lname=$lastName');
      print('📝 Inserting user data into local database...');

      await DatabaseHelper.instance.insertUser(localUserData);
      print('✅ User saved to local database successfully');

      // CRITICAL: Save school_id to settings for sync operations
      if (userData['school_id'] != null &&
          userData['school_id'].toString().isNotEmpty) {
        final schoolId = userData['school_id'].toString();
        print('🏫 Saving school ID to settings: $schoolId');

        final db = await DatabaseHelper.instance.database;
        await db.insert(
          'settings',
          {'key': 'school_id', 'value': schoolId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('✅ School ID saved to settings for sync operations');

        // Also update SettingsController
        try {
          if (Get.isRegistered<SettingsController>()) {
            final settingsController = Get.find<SettingsController>();
            settingsController.schoolId.value = schoolId;
            print('✅ SettingsController updated with school ID');
          }
        } catch (e) {
          print('⚠️ Could not update SettingsController: $e');
        }
      }
    } catch (e) {
      print('! Failed to save user locally: $e');
      print('! User data keys: ${userData.keys.toList()}');
      // Don't throw error - local save is optional for API users
    }
  }

  /// Enhanced logout with API call
  Future<void> logoutWithApi() async {
    try {
      isLoading.value = true;

      // Call API logout
      await ApiService.logout();

      // Clear local state
      currentUser.value = null;
      isLoggedIn.value = false;

      print('✅ Logged out successfully');
    } catch (e) {
      print('❌ Logout error: $e');
      // Clear local state even if API call fails
      currentUser.value = null;
      isLoggedIn.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  String? get userId {
    try {
      return currentUser.value?.id?.toString();
    } catch (e) {
      print('❌ userId Error: $e');
      return null;
    }
  }

  /// Load remembered email from storage
  Future<void> loadRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('remembered_email') ?? '';
      userEmail.value = email;
    } catch (e) {
      print('Failed to load remembered email: $e');
    }
  }

  /// Store API token with EXTENSIVE DEBUGGING
  Future<void> _storeApiToken(String email, String token) async {
    try {
      print('💾 === STORING API TOKEN ===');
      print('📧 Email: $email');
      print('🔑 Token length: ${token.length}');
      print(
          '🔑 Token preview: ${token.substring(0, min(30, token.length))}...');

      final prefs = await SharedPreferences.getInstance();
      final key = 'api_token_$email';

      print('🗝️ Storage key: $key');

      // Store the token
      final success = await prefs.setString(key, token);
      print('💾 SharedPreferences.setString returned: $success');

      // Verify it was stored
      final storedToken = prefs.getString(key);
      if (storedToken != null && storedToken == token) {
        print('✅ TOKEN VERIFIED IN STORAGE!');
      } else {
        print('❌ TOKEN STORAGE FAILED!');
      }

      // ALSO set it in ApiService immediately
      ApiService.setToken(token);
      print('✅ Token also set in ApiService');

      print('✅ === TOKEN STORAGE COMPLETE ===');
    } catch (e, stackTrace) {
      print('❌ ERROR STORING TOKEN: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  /// Enhanced email/password login - SIMPLIFIED: Email/Password only
  /// School data comes from API response automatically
  Future<bool> loginWithApi(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('\n🔐 === API LOGIN ATTEMPT ===');
      print('📧 Email: $email');

      if (email.isEmpty || password.isEmpty) {
        error.value = 'Email and password are required';
        return false;
      }

      // Call Laravel API for authentication
      final loginResponse = await ApiService.login(email, password);

      print('✅ API Response received');

      // Extract user data and token
      final userData = loginResponse['user'];
      final token = loginResponse['token'];

      if (token == null || token.isEmpty) {
        print('❌ No token in response!');
        error.value = 'No authentication token received';
        return false;
      }

      print('✅ Token received: ${token.substring(0, 10)}...');
      print('💾 Storing token...');
      await _storeApiToken(email, token);
      print('✅ Token storage complete');

      // Set user as logged in
      final user = User.fromJson(userData);
      currentUser.value = user;
      isLoggedIn.value = true;

      print('✅ Login complete for: ${user.fname} ${user.lname}');

      // Save email if remember me
      if (rememberMe.value) {
        userEmail.value = email;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remembered_email', email);
      }

      // Save to local database
      await _saveUserToLocal(userData);

      // Save school data if available in response (for offline-first)
      if (loginResponse['school'] != null) {
        await _saveSchoolDataFromLogin(loginResponse['school']);
      } else if (user.schoolId != null) {
        // If school data not in response but we have school_id, fetch it
        await _fetchAndSaveSchoolData(user.schoolId!);
      }

      await _triggerPostLoginSync();

      // FINAL VERIFICATION
      print('🔍 === FINAL TOKEN VERIFICATION ===');
      print('   ApiService.hasToken: ${ApiService.hasToken}');
      if (ApiService.currentToken != null) {
        print(
            '   ApiService.currentToken: ${ApiService.currentToken!.substring(0, 10)}...');
      }

      final verifyStored = await _getStoredApiToken(email);
      if (verifyStored != null) {
        print('   Stored token: ${verifyStored.substring(0, 10)}...');
        print('   ✅ Token is properly stored and available');
      } else {
        print('   ❌ WARNING: Token not in storage!');
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ API LOGIN ERROR: $e');
      error.value = 'Login failed: ${e.toString()}';

      // Fallback to local login
      return await login(email, password);
    } finally {
      isLoading.value = false;
    }
  }

  /// Get stored API token with DEBUGGING
  Future<String?> _getStoredApiToken(String email) async {
    try {
      print('🔍 === GETTING STORED TOKEN ===');
      print('📧 Looking for token for: $email');

      final prefs = await SharedPreferences.getInstance();
      final key = 'api_token_$email';

      print('🗝️ Storage key: $key');

      final token = prefs.getString(key);

      if (token != null && token.isNotEmpty) {
        print('✅ Token FOUND: ${token.substring(0, min(30, token.length))}...');
        print('   Token length: ${token.length}');
        return token;
      } else {
        print('❌ Token NOT FOUND');

        // Debug: List all keys
        final allKeys = prefs.getKeys();
        final tokenKeys = allKeys.where((k) => k.startsWith('api_token_'));
        print('📋 Available token keys: $tokenKeys');

        if (tokenKeys.isNotEmpty) {
          print('⚠️ Found tokens for other emails:');
          for (var k in tokenKeys) {
            final t = prefs.getString(k);
            if (t != null) {
              print('   $k: ${t.substring(0, min(20, t.length))}...');
            }
          }
        } else {
          print('⚠️ NO tokens stored at all!');
        }

        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error reading stored token: $e');
      print('❌ Stack trace: $stackTrace');
      return null;
    }
  }

// Helper function
  int min(int a, int b) => a < b ? a : b;
  Future<void> _restoreApiTokenForSync(String email) async {
    try {
      print('🔄 === RESTORING API TOKEN ===');

      // Try to get stored API token
      final storedToken = await _getStoredApiToken(email);

      if (storedToken != null && storedToken.isNotEmpty) {
        print('✅ Token found in storage: ${storedToken.substring(0, 10)}...');

        // Set the token in ApiService
        ApiService.setToken(storedToken);
        print('✅ Token set in ApiService');

        // Verify it was set correctly
        print('🔍 Verifying token was set...');
        print('   hasToken: ${ApiService.hasToken}');
        print(
            '   currentToken: ${ApiService.currentToken?.substring(0, 10)}...');

        // Test if the token actually works
        final isWorking = await _testApiConnection();

        if (isWorking) {
          print('✅ API token is valid and working');
        } else {
          print('⚠️ Token exists but may be expired');
          print('💡 User can still use app offline, will re-login when needed');
        }
      } else {
        print('⚠️ No stored token found for $email');
        print('💡 User can still use app offline, but sync will be limited');
      }
    } catch (e) {
      print('⚠️ Error restoring token: $e');
      print('💡 Continuing anyway - user can work offline');
    }
  }

  Future<bool> _testApiConnection() async {
    try {
      print('🧪 Testing API connection...');
      print('🧪 Token available: ${ApiService.hasToken}');

      if (!ApiService.hasToken || ApiService.currentToken == null) {
        print('❌ No token to test');
        return false;
      }

      // Make a simple authenticated request to test the token
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/user'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${ApiService.currentToken}',
        },
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () => http.Response('Timeout', 408),
      );

      print('🧪 API test response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Token is valid and working');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Token is invalid or expired (401)');
        return false;
      } else if (response.statusCode == 403) {
        // FIXED: 403 means token is VALID but user doesn't have permission
        // This is OK - the token works for authentication!
        print('✅ Token is valid (403 = authenticated but limited permissions)');
        return true; // Changed from false to true!
      } else if (response.statusCode == 408) {
        print('⏱️ Request timeout');
        return false;
      } else {
        print('⚠️ Unexpected response: ${response.statusCode}');
        // Assume token might still be valid
        return true;
      }
    } catch (e) {
      print('❌ Error testing connection: $e');
      return false;
    }
  }

  Future<bool> authenticateWithPin(String pin) async {
    try {
      print('🔐 === PIN AUTHENTICATION ===');

      final success = await _pinController.verifyPin(pin);

      if (success) {
        print('✅ PIN verified successfully');
        await _pinController.setUserVerified(true);

        // NEW: Check if sync needed
        final prefs = await SharedPreferences.getInstance();
        final lastSyncStr = prefs.getString('last_full_sync');

        if (lastSyncStr != null) {
          final lastSync = DateTime.parse(lastSyncStr);
          final hoursSinceSync = DateTime.now().difference(lastSync).inHours;

          if (hoursSinceSync > 24) {
            // Need sync - show sync screen
            Get.offAll(() => InitialSyncScreen());
            return true;
          }
        }

        // Don't need sync - trigger background sync
        _triggerPostLoginSync();
        return true;
      }

      return false;
    } catch (e) {
      print('❌ PIN authentication error: $e');
      error.value = 'PIN authentication failed: ${e.toString()}';
      return false;
    }
  }

  /// Get user data from local database
  Future<Map<String, dynamic>?> _getUserFromLocal(String email) async {
    try {
      print('📂 Getting user from local database: $email');

      final users = await DatabaseHelper.instance.getUsers();
      final userData = users
          .where((u) =>
              u['email']?.toString().toLowerCase() == email.toLowerCase())
          .firstOrNull;

      if (userData != null) {
        print('✅ User found in local database');
        return userData;
      } else {
        print('❌ User not found in local database');
        return null;
      }
    } catch (e) {
      print('❌ Error getting user from local database: $e');
      return null;
    }
  }

  /// Load user from local cache - ENHANCED VERSION
  Future<void> _loadUserFromCache(String email) async {
    try {
      print('📂 Loading user from cache: $email');

      final users = await DatabaseHelper.instance.getUsers();
      final userData = users
          .where((u) =>
              u['email']?.toString().toLowerCase() == email.toLowerCase())
          .firstOrNull;

      if (userData != null) {
        final user = User.fromJson(userData);
        currentUser.value = user;
        userEmail.value = email;
        isLoggedIn.value = true;

        print('✅ User loaded from cache: ${user.email}');
        print('   Name: ${user.fname} ${user.lname}');
        print('   Role: ${user.role}');
        print('   School ID: ${user.schoolId}');
      } else {
        print('❌ No user found in cache for: $email');
        currentUser.value = null;
        isLoggedIn.value = false;
      }
    } catch (e) {
      print('❌ Error loading user from cache: $e');
      currentUser.value = null;
      isLoggedIn.value = false;
      rethrow;
    }
  }

  /// Clear stored token for user
  Future<void> _clearStoredToken(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('api_token_$email');
      ApiService.clearToken();
      print('🧹 Cleared stored token for: $email');
    } catch (e) {
      print('❌ Error clearing token: $e');
    }
  }

  /// Trigger sync after successful login
  Future<void> _triggerPostLoginSync() async {
    try {
      print('🔄 === POST-LOGIN AUTO-SYNC ===');

      if (!Get.isRegistered<SyncController>()) {
        print('⚠️ SyncController not registered');
        return;
      }

      final syncController = Get.find<SyncController>();

      if (!syncController.isOnline.value) {
        print('⚠️ Offline - skipping auto-sync');
        return;
      }

      if (syncController.isSyncing.value) {
        print('⚠️ Sync already in progress');
        return;
      }

      print('✅ Triggering auto-sync after login...');

      Future.delayed(Duration(milliseconds: 800), () {
        if (Get.isRegistered<SyncController>()) {
          Get.find<SyncController>().performFullSync();
          print('✅ Auto-sync triggered');
        }
      });
    } catch (e) {
      print('⚠️ Error triggering auto-sync: $e');
    }
  }

  /// Convenience role check methods - COMPLETELY SAFE
  bool get isAdmin => hasRole('admin');
  bool get isInstructor => hasAnyRole(['admin', 'instructor']);
  bool get isStudent => hasRole('student');
  bool get canAccessAdminFeatures => hasRole('admin');
  bool get canAccessInstructorFeatures => hasAnyRole(['admin', 'instructor']);

  /// Save school data from login response (for offline-first)
  Future<void> _saveSchoolDataFromLogin(Map<String, dynamic> schoolData) async {
    try {
      print('🏫 Saving school data from login response...');
      final db = await DatabaseHelper.instance.database;
      final schoolId = schoolData['id']?.toString() ?? '';

      if (schoolId.isEmpty) {
        print('⚠️ School ID missing, skipping school save');
        return;
      }

      // Check if school already exists
      final existing = await db.query(
        'schools',
        where: 'id = ?',
        whereArgs: [schoolId],
      );

      if (existing.isEmpty) {
        // Insert new school
        await db.insert('schools', {
          'id': schoolId,
          'name': schoolData['name']?.toString() ?? '',
          'location': schoolData['location']?.toString() ?? '',
          'phone': schoolData['phone']?.toString() ?? '',
          'email': schoolData['email']?.toString() ?? '',
          'address': schoolData['address']?.toString() ?? '',
          'status': 'active',
          'invitation_code': schoolData['invitation_code']?.toString() ?? '',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('✅ School saved to local database');
      } else {
        // Update existing school
        await db.update(
          'schools',
          {
            'name': schoolData['name']?.toString() ?? '',
            'location': schoolData['location']?.toString() ?? '',
            'phone': schoolData['phone']?.toString() ?? '',
            'email': schoolData['email']?.toString() ?? '',
            'address': schoolData['address']?.toString() ?? '',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [schoolId],
        );
        print('✅ School updated in local database');
      }

      // Also save to settings for quick access
      if (schoolData['name'] != null) {
        await db.insert(
          'settings',
          {'key': 'school_id', 'value': schoolId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await db.insert(
          'settings',
          {
            'key': 'business_name',
            'value': schoolData['name']?.toString() ?? ''
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      print('⚠️ Error saving school data: $e');
      // Don't throw - school data save is not critical for login
    }
  }

  /// Fetch and save school data using school_id (if not in login response)
  Future<void> _fetchAndSaveSchoolData(String schoolId) async {
    try {
      print('🏫 Fetching school data for ID: $schoolId');
      // This would call an API endpoint to get school details
      // For now, we'll just ensure the school_id is saved in settings
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'settings',
        {'key': 'school_id', 'value': schoolId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ School ID saved to settings');
    } catch (e) {
      print('⚠️ Error fetching school data: $e');
    }
  }
}
