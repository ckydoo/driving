import 'package:crypto/crypto.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/subscription_controller.dart';
import 'package:driving/controllers/sync_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/auth/initial_sync_screen.dart';
import 'package:driving/services/api_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'dart:developer' as developer;

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
        debugPrint('🔐 PIN authentication required');
        return;
      }

      // Check for remembered user
      final savedEmail = userEmail.value;
      if (savedEmail.isNotEmpty) {
        await _loadUserFromCache(savedEmail);
      }
    } catch (e) {
      debugPrint('❌ Error checking existing login: $e');
      isLoggedIn.value = false;
    }
  }

  Future<bool> loginWithEmail(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      debugPrint('\n🔐 === EMAIL/PASSWORD LOGIN ===');
      debugPrint('📧 Email: $email');

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
        final schoolId = currentUser.value?.schoolId?.toString();
        final syncKey = (schoolId != null && schoolId.isNotEmpty)
            ? 'initial_sync_complete_$schoolId'
            : 'initial_sync_complete';
        final hasCompletedSync = prefs.getBool(syncKey) ?? false;

        if (!hasCompletedSync) {
          Get.offAll(() => InitialSyncScreen());
        } else {
          _triggerPostLoginSync();
        }

        return true;
      }
      // If API login fails, try local login
      debugPrint('⚠️ API login failed, trying local login...');
      final localSuccess = await login(email, password);

      if (localSuccess) {
        // Fetch business settings from server (non-blocking)
        _fetchBusinessSettingsInBackground();

        // Same logic for local login
        final prefs = await SharedPreferences.getInstance();
        final schoolId = currentUser.value?.schoolId?.toString();
        final syncKey = (schoolId != null && schoolId.isNotEmpty)
            ? 'initial_sync_complete_$schoolId'
            : 'initial_sync_complete';
        final hasCompletedSync = prefs.getBool(syncKey) ?? false;

        if (!hasCompletedSync) {
          Get.offAll(() => InitialSyncScreen());
        } else {
          _triggerPostLoginSync();
        }
      }

      return localSuccess;
    } catch (e, stackTrace) {
      developer.log('Login error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = ErrorHandler.getFriendlyMessage(e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Validate email and password inputs
  bool _validateInputs() {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty) {
      error.value = 'Please enter your email address';
      return false;
    }

    if (!_isValidEmail(email)) {
      error.value =
          'Please enter a valid email address (e.g., name@example.com)';
      return false;
    }

    if (password.isEmpty) {
      error.value = 'Please enter your password';
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

      debugPrint('\n🔐 === LOGIN ATTEMPT ===');
      debugPrint('📧 Email: $email');

      // Check if user exists locally
      final userExistsLocally = await _checkUserExistsLocally(email);

      if (userExistsLocally) {
        // User exists locally - try offline login first
        debugPrint('📂 User found locally - attempting offline login');
        final offlineSuccess = await _loginOffline(email, password);

        if (offlineSuccess) {
          // Offline login successful
          await _handleSuccessfulLogin(email);

          // Try online sync in background (don't wait for it)
          _attemptBackgroundSync(email, password);
          return;
        } else {
          // Offline login failed - try online
          debugPrint('⚠️ Offline login failed - attempting online login');
          final onlineSuccess = await _loginOnline(email, password);

          if (onlineSuccess) {
            await _handleSuccessfulLogin(email);
            return;
          }
        }
      } else {
        // User doesn't exist locally - must login online
        debugPrint('🌐 User not found locally - attempting online login');
        final onlineSuccess = await _loginOnline(email, password);

        if (onlineSuccess) {
          await _handleSuccessfulLogin(email);
          return;
        }
      }

      // If we get here, both failed
      error.value =
          'Login failed. Please check your email and password, or contact your administrator if you forgot your password.';
    } catch (e, stackTrace) {
      developer.log('Login error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = ErrorHandler.getFriendlyMessage(e);
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
      debugPrint('❌ Error checking local user: $e');
      return false;
    }
  }

  /// Attempt offline login with local credentials
  Future<bool> _loginOffline(String email, String password) async {
    try {
      debugPrint('📂 Attempting offline login...');
      return await login(email, password);
    } catch (e) {
      debugPrint('❌ Offline login error: $e');
      return false;
    }
  }

  /// Attempt online login via API
  Future<bool> _loginOnline(String email, String password) async {
    try {
      debugPrint('🌐 Attempting online login...');
      return await loginWithApi(email, password);
    } catch (e) {
      debugPrint('❌ Online login error: $e');
      return false;
    }
  }

  /// Handle successful login (common cleanup)
  Future<void> _handleSuccessfulLogin(String email) async {
    try {
      debugPrint('✅ Login successful for: $email');

      // Save email if remember me is enabled
      if (rememberMe.value) {
        userEmail.value = email;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remembered_email', email);
      }

      // Clear sync auth requirement
      await _setSyncAuthenticationRequired(false);

      // Fetch business settings from server (non-blocking)
      _fetchBusinessSettingsInBackground();

      debugPrint('✅ Post-login setup complete');
    } catch (e) {
      debugPrint('⚠️ Post-login setup error: $e');
      // Don't fail the login if post-setup fails
    }
  }

  /// Fetch business settings from server in background (non-blocking)
  Future<void> _fetchBusinessSettingsInBackground() async {
    try {
      debugPrint('🏢 Fetching business settings in background...');

      // Wait a bit to let other login processes complete
      await Future.delayed(Duration(milliseconds: 500));

      // Get settings controller
      if (Get.isRegistered<SettingsController>()) {
        final settingsController = Get.find<SettingsController>();

        // Fetch business settings from server
        await settingsController.fetchBusinessSettingsFromServer();

        debugPrint('✅ Business settings fetched successfully');
      } else {
        debugPrint(
            '⚠️ SettingsController not registered - skipping business settings fetch');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to fetch business settings: $e');
      // Don't block login if business settings fetch fails
    }
  }

  /// Attempt background sync after login (non-blocking)
  Future<void> _attemptBackgroundSync(String email, String password) async {
    try {
      debugPrint('🔄 Attempting background sync...');

      // Try to sync with API in the background
      Future.delayed(Duration(milliseconds: 500), () async {
        try {
          await loginWithApi(email, password);
          debugPrint('✅ Background sync successful');
        } catch (e) {
          debugPrint('⚠️ Background sync failed: $e');
          // Ignore sync failures - user is already logged in offline
        }
      });
    } catch (e) {
      debugPrint('⚠️ Background sync setup error: $e');
    }
  }

  /// PRIMARY LOGIN METHOD - Local database only
  Future<bool> login(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      debugPrint('\n🔐 === LOCAL LOGIN ATTEMPT ===');
      debugPrint('📧 Email: $email');

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
        error.value =
            'No account found with this email address. Please check your email or register a new account.';
        return false;
      }

      // Verify password
      final storedPassword = userData['password']?.toString() ?? '';
      bool passwordValid = false;

      // Support both plain text and hashed passwords for backward compatibility
      if (storedPassword == password) {
        passwordValid = true; // Plain text match
        debugPrint('🔓 Password matched (plain text)');
      } else if (storedPassword == _hashPassword(password)) {
        passwordValid = true; // Hashed password match
        debugPrint('🔓 Password matched (hashed)');
      }

      if (!passwordValid) {
        error.value = 'Incorrect password. Please try again.';
        return false;
      }

      // Set user as logged in
      final user = User.fromJson(userData);

      // ✅ ADMIN-ONLY CHECK
      if (user.role.toLowerCase() != 'admin') {
        error.value =
            'Access restricted. Only administrators can sign in at this time.';
        debugPrint('🚫 Non-admin user blocked: ${user.email} (${user.role})');
        return false;
      }

      currentUser.value = user;
      isLoggedIn.value = true;

      // Save email for future sessions if remember me is enabled
      if (rememberMe.value) {
        userEmail.value = email;
      }

      debugPrint('✅ Local authentication successful');
      debugPrint('✅ User: ${user.fname} ${user.lname} (${user.role})');

      return true;
    } catch (e, stackTrace) {
      developer.log('Local login error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = ErrorHandler.getFriendlyMessage(e);
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

      debugPrint('🔐 Local registration attempt: $email');

      // Validate input
      if (email.isEmpty || password.isEmpty) {
        error.value = 'Please enter both email and password to register';
        return false;
      }

      // Validate email format
      if (!_isValidEmail(email)) {
        error.value =
            'Please enter a valid email address (e.g., name@example.com)';
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
        error.value =
            'An account with this email already exists. Please log in instead or use a different email.';
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

      debugPrint('✅ User registered locally with ID: $userId');
      debugPrint('✅ User: ${user.fname} ${user.lname} (${user.role})');

      // Fetch business settings from server (non-blocking)
      _fetchBusinessSettingsInBackground();

      return true;
    } catch (e, stackTrace) {
      developer.log('Registration error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = ErrorHandler.getFriendlyMessage(e);
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
      debugPrint('Error loading remembered email: $e');
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
      debugPrint('Error getting current API token: $e');
      return null;
    }
  }

  /// Set flag that sync needs authentication
  Future<void> _setSyncAuthenticationRequired(bool required) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_auth_required', required);
      debugPrint('🔄 Sync auth required flag set to: $required');
    } catch (e) {
      debugPrint('Error setting sync auth flag: $e');
    }
  }

  /// Check if sync needs authentication
  Future<bool> _isSyncAuthenticationRequired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('sync_auth_required') ?? false;
    } catch (e) {
      debugPrint('Error checking sync auth flag: $e');
      return false;
    }
  }

  /// Enhanced logout method - Clear stored tokens
  Future<void> logout() async {
    try {
      debugPrint('🚪 === LOGOUT START ===');

      final user = currentUser.value;

      // Try to logout from API if we have a token
      if (user?.email != null) {
        final token = await _getStoredApiToken(user!.email);
        if (token != null) {
          try {
            debugPrint('🔄 Logging out from API...');
            await ApiService.logout();
          } catch (e) {
            debugPrint('⚠️ API logout failed (continuing): $e');
          }

          // Clear stored token
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('api_token_${user.email}');
          debugPrint('✅ Stored token cleared');
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

      debugPrint('✅ === LOGOUT COMPLETE ===');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
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

      debugPrint('🔐 === SETTING UP PIN ===');
      debugPrint('📧 Email: $email');

      // Setup the PIN
      final success = await _pinController.setupPin(pin, userEmail: email);

      if (success) {
        debugPrint('✅ PIN setup successful for $email');
        await _ensureTokenIsAvailable(email);
      }

      return success;
    } catch (e, stackTrace) {
      developer.log('PIN setup error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = 'Failed to set up PIN. Please try again.';
      return false;
    }
  }

  Future<void> _ensureTokenIsAvailable(String email) async {
    try {
      debugPrint('🔑 === ENSURING TOKEN IS AVAILABLE ===');

      // Check if ApiService already has a token
      if (ApiService.hasToken && ApiService.currentToken != null) {
        debugPrint(
            '✅ ApiService already has token: ${ApiService.currentToken!.substring(0, 10)}...');

        // Make sure it's also in storage for future sessions
        final storedToken = await _getStoredApiToken(email);
        if (storedToken == null || storedToken != ApiService.currentToken) {
          debugPrint('💾 Saving current ApiService token to storage...');
          await _storeApiToken(email, ApiService.currentToken!);
        }
        return;
      }

      debugPrint('⚠️ ApiService has no token, checking storage...');

      // Try to get from storage
      final storedToken = await _getStoredApiToken(email);

      if (storedToken != null && storedToken.isNotEmpty) {
        debugPrint(
            '✅ Token found in storage: ${storedToken.substring(0, 10)}...');

        // Set it in ApiService
        ApiService.setToken(storedToken);
        debugPrint('✅ Token set in ApiService');

        // Verify
        if (ApiService.hasToken && ApiService.currentToken != null) {
          debugPrint('✅ Token verified and ready for API calls');
        } else {
          debugPrint('❌ Failed to set token in ApiService');
        }
      } else {
        debugPrint('❌ No token found anywhere!');
        debugPrint(
            '⚠️ This means the initial login did not save the token properly');
        debugPrint('💡 User will need to re-login with email/password');
      }
    } catch (e) {
      debugPrint('❌ Error ensuring token: $e');
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

      debugPrint('✅ User profile updated');
      return true;
    } catch (e, stackTrace) {
      developer.log('Profile update error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = 'Failed to update profile. Please try again.';
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

      debugPrint('✅ Password changed successfully');
      return true;
    } catch (e, stackTrace) {
      developer.log('Password change error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = 'Failed to change password. Please try again.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sign out and clear ALL data (HARD LOGOUT for switching schools)
  /// This is a COMPLETE wipe of all local data
  Future<void> signOutAndClearAllData() async {
    try {
      isLoading.value = true;

      debugPrint('🚨 === HARD LOGOUT: CLEARING ALL DATA ===');

      // 1. Clear API token first
      ApiService.clearToken();
      debugPrint('✅ API token cleared');

      // 2. Clear all local database data
      await DatabaseHelper.instance.clearAllSchoolData();
      debugPrint('✅ All SQLite data cleared');

      // 3. Clear SharedPreferences (except known schools list)
      final prefs = await SharedPreferences.getInstance();
      final knownSchoolsKey = 'known_schools';
      final knownSchoolsData = prefs.getString(knownSchoolsKey);

      await prefs.clear();

      // Restore known schools list if it exists
      if (knownSchoolsData != null) {
        await prefs.setString(knownSchoolsKey, knownSchoolsData);
      }
      debugPrint('✅ SharedPreferences cleared (preserved known_schools)');

      // 4. Clear all GetX controllers state
      currentUser.value = null;
      isLoggedIn.value = false;
      userEmail.value = '';
      rememberMe.value = false;
      debugPrint('✅ AuthController state cleared');

      // 5. Clear PIN data
      await _pinController.clearAllPinData();
      debugPrint('✅ PIN data cleared');

      // 6. Clear SettingsController data
      try {
        if (Get.isRegistered<SettingsController>()) {
          final settingsController = Get.find<SettingsController>();
          settingsController.schoolId.value = '';
          settingsController.schoolDisplayName.value = '';
          settingsController.businessName.value = '';
          settingsController.businessAddress.value = '';
          settingsController.businessPhone.value = '';
          settingsController.businessEmail.value = '';
          debugPrint('✅ SettingsController data cleared');
        }
      } catch (e) {
        debugPrint('⚠️ Could not clear SettingsController: $e');
      }

      debugPrint('✅ === HARD LOGOUT COMPLETE ===');
    } catch (e) {
      debugPrint('❌ Hard logout error: $e');
      // Even on error, force clear critical state
      currentUser.value = null;
      isLoggedIn.value = false;
      ApiService.clearToken();
    } finally {
      isLoading.value = false;
    }
  }

  /// Sign out (regular logout - keeps local data)
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

      // ✅ CRITICAL FIX: Clear API token
      ApiService.clearToken();

      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
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

      debugPrint('✅ User account deleted successfully');
      return true;
    } catch (e, stackTrace) {
      developer.log('Account deletion error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = 'Failed to delete account. Please try again.';
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
      debugPrint('❌ Error determining initial route: $e');
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
      debugPrint('❌ Error hashing password: $e');
      return password; // Fallback to plain text (not recommended)
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;

    // Basic email regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    return emailRegex.hasMatch(email);
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
      debugPrint('✅ User data refreshed');
    } catch (e) {
      debugPrint('❌ Error refreshing user data: $e');
    }
  }

  bool hasAnyRole(List<String> roles) {
    try {
      // Check authentication first
      if (!isLoggedIn.value) {
        debugPrint('🚫 hasAnyRole: User not logged in');
        return false;
      }

      // Check if user object exists
      if (currentUser.value == null) {
        debugPrint('🚫 hasAnyRole: User object is null');
        return false;
      }

      // SAFE: Use null-aware access for role property
      final userRole = currentUser.value?.role?.toLowerCase();
      if (userRole == null || userRole.isEmpty) {
        debugPrint('🚫 hasAnyRole: User role is null or empty');
        return false;
      }

      // Check if user has any of the specified roles
      final hasRole = roles.any((role) => userRole == role.toLowerCase());
      debugPrint(
          '✅ hasAnyRole: User role "$userRole" - Has required role: $hasRole');
      return hasRole;
    } catch (e) {
      debugPrint('❌ hasAnyRole Error: $e');
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
      debugPrint('❌ hasRole Error: $e');
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
      debugPrint('❌ isUserDataAvailable Error: $e');
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
      debugPrint('❌ userFullName Error: $e');
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
      debugPrint('❌ userFirstName Error: $e');
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
      debugPrint('❌ userInitials Error: $e');
      return 'U';
    }
  }

  String get userRole {
    try {
      return currentUser.value?.role?.toLowerCase() ?? 'guest';
    } catch (e) {
      debugPrint('❌ userRole Error: $e');
      return 'guest';
    }
  }

  /// Save user to local database for offline access
  Future<void> _saveUserToLocal(Map<String, dynamic> userData) async {
    try {
      debugPrint(
          '📝 Preparing user data for local storage: ${userData['email']}');

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

      debugPrint('📝 Transformed user data: fname=$firstName, lname=$lastName');
      debugPrint('📝 Inserting user data into local database...');

      await DatabaseHelper.instance.insertUser(localUserData);
      debugPrint('✅ User saved to local database successfully');

      // CRITICAL: Save school_id to settings for sync operations
      if (userData['school_id'] != null &&
          userData['school_id'].toString().isNotEmpty) {
        final schoolId = userData['school_id'].toString();
        debugPrint('🏫 Saving school ID to settings: $schoolId');

        final db = await DatabaseHelper.instance.database;
        await db.insert(
          'settings',
          {'key': 'school_id', 'value': schoolId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        debugPrint('✅ School ID saved to settings for sync operations');

        // Also update SettingsController
        try {
          if (Get.isRegistered<SettingsController>()) {
            final settingsController = Get.find<SettingsController>();
            settingsController.schoolId.value = schoolId;
            debugPrint('✅ SettingsController updated with school ID');
          }
        } catch (e) {
          debugPrint('⚠️ Could not update SettingsController: $e');
        }
      }
    } catch (e) {
      debugPrint('! Failed to save user locally: $e');
      debugPrint('! User data keys: ${userData.keys.toList()}');
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

      debugPrint('✅ Logged out successfully');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
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
      debugPrint('❌ userId Error: $e');
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
      debugPrint('Failed to load remembered email: $e');
    }
  }

  /// Store API token with EXTENSIVE DEBUGGING
  Future<void> _storeApiToken(String email, String token) async {
    try {
      debugPrint('💾 === STORING API TOKEN ===');
      debugPrint('📧 Email: $email');
      debugPrint('🔑 Token length: ${token.length}');
      debugPrint(
          '🔑 Token preview: ${token.substring(0, min(30, token.length))}...');

      final prefs = await SharedPreferences.getInstance();
      final key = 'api_token_$email';

      debugPrint('🗝️ Storage key: $key');

      // Store the token
      final success = await prefs.setString(key, token);
      debugPrint('💾 SharedPreferences.setString returned: $success');

      // Verify it was stored
      final storedToken = prefs.getString(key);
      if (storedToken != null && storedToken == token) {
        debugPrint('✅ TOKEN VERIFIED IN STORAGE!');
      } else {
        debugPrint('❌ TOKEN STORAGE FAILED!');
      }

      // ALSO set it in ApiService immediately
      ApiService.setToken(token);
      debugPrint('✅ Token also set in ApiService');

      debugPrint('✅ === TOKEN STORAGE COMPLETE ===');
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR STORING TOKEN: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  /// Enhanced email/password login - SIMPLIFIED: Email/Password only
  /// School data comes from API response automatically
  Future<bool> loginWithApi(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      debugPrint('\n🔐 === API LOGIN ATTEMPT ===');
      debugPrint('📧 Email: $email');

      if (email.isEmpty || password.isEmpty) {
        error.value = 'Email and password are required';
        return false;
      }

      // Call Laravel API for authentication
      final loginResponse = await ApiService.login(email, password);

      debugPrint('✅ API Response received');

      // Extract user data and token
      final userData = loginResponse['user'];
      final token = loginResponse['token'];

      if (token == null || token.isEmpty) {
        debugPrint('❌ No token in response!');
        error.value = 'No authentication token received';
        return false;
      }

      debugPrint('✅ Token received: ${token.substring(0, 10)}...');
      debugPrint('💾 Storing token...');
      await _storeApiToken(email, token);
      debugPrint('✅ Token storage complete');

      // Set user as logged in
      final user = User.fromJson(userData);

      // ✅ ADMIN-ONLY CHECK
      if (user.role.toLowerCase() != 'admin') {
        error.value =
            'Access restricted. Only administrators can sign in at this time.';
        debugPrint('🚫 Non-admin user blocked: ${user.email} (${user.role})');
        return false;
      }

      currentUser.value = user;
      isLoggedIn.value = true;

      debugPrint('✅ Login complete for: ${user.fname} ${user.lname}');

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

      // Fetch business settings from server (non-blocking)
      _fetchBusinessSettingsInBackground();

      await _triggerPostLoginSync();

      // FINAL VERIFICATION
      debugPrint('🔍 === FINAL TOKEN VERIFICATION ===');
      debugPrint('   ApiService.hasToken: ${ApiService.hasToken}');
      if (ApiService.currentToken != null) {
        debugPrint(
            '   ApiService.currentToken: ${ApiService.currentToken!.substring(0, 10)}...');
      }

      final verifyStored = await _getStoredApiToken(email);
      if (verifyStored != null) {
        debugPrint('   Stored token: ${verifyStored.substring(0, 10)}...');
        debugPrint('   ✅ Token is properly stored and available');
      } else {
        debugPrint('   ❌ WARNING: Token not in storage!');
      }

      return true;
    } catch (e, stackTrace) {
      developer.log('API login error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = ErrorHandler.getFriendlyMessage(e);

      // Fallback to local login
      return await login(email, password);
    } finally {
      isLoading.value = false;
    }
  }

  /// Get stored API token with DEBUGGING
  Future<String?> _getStoredApiToken(String email) async {
    try {
      debugPrint('🔍 === GETTING STORED TOKEN ===');
      debugPrint('📧 Looking for token for: $email');

      final prefs = await SharedPreferences.getInstance();
      final key = 'api_token_$email';

      debugPrint('🗝️ Storage key: $key');

      final token = prefs.getString(key);

      if (token != null && token.isNotEmpty) {
        debugPrint(
            '✅ Token FOUND: ${token.substring(0, min(30, token.length))}...');
        debugPrint('   Token length: ${token.length}');
        return token;
      } else {
        debugPrint('❌ Token NOT FOUND');

        // Debug: List all keys
        final allKeys = prefs.getKeys();
        final tokenKeys = allKeys.where((k) => k.startsWith('api_token_'));
        debugPrint('📋 Available token keys: $tokenKeys');

        if (tokenKeys.isNotEmpty) {
          debugPrint('⚠️ Found tokens for other emails:');
          for (var k in tokenKeys) {
            final t = prefs.getString(k);
            if (t != null) {
              debugPrint('   $k: ${t.substring(0, min(20, t.length))}...');
            }
          }
        } else {
          debugPrint('⚠️ NO tokens stored at all!');
        }

        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error reading stored token: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }

// Helper function
  int min(int a, int b) => a < b ? a : b;
  Future<void> _restoreApiTokenForSync(String email) async {
    try {
      debugPrint('🔄 === RESTORING API TOKEN ===');

      // Try to get stored API token
      final storedToken = await _getStoredApiToken(email);

      if (storedToken != null && storedToken.isNotEmpty) {
        debugPrint(
            '✅ Token found in storage: ${storedToken.substring(0, 10)}...');

        // Set the token in ApiService
        ApiService.setToken(storedToken);
        debugPrint('✅ Token set in ApiService');

        // Verify it was set correctly
        debugPrint('🔍 Verifying token was set...');
        debugPrint('   hasToken: ${ApiService.hasToken}');
        debugPrint(
            '   currentToken: ${ApiService.currentToken?.substring(0, 10)}...');

        // Test if the token actually works
        final isWorking = await _testApiConnection();

        if (isWorking) {
          debugPrint('✅ API token is valid and working');
        } else {
          debugPrint('⚠️ Token exists but may be expired');
          debugPrint(
              '💡 User can still use app offline, will re-login when needed');
        }
      } else {
        debugPrint('⚠️ No stored token found for $email');
        debugPrint(
            '💡 User can still use app offline, but sync will be limited');
      }
    } catch (e) {
      debugPrint('⚠️ Error restoring token: $e');
      debugPrint('💡 Continuing anyway - user can work offline');
    }
  }

  Future<bool> _testApiConnection() async {
    try {
      debugPrint('🧪 Testing API connection...');
      debugPrint('🧪 Token available: ${ApiService.hasToken}');

      if (!ApiService.hasToken || ApiService.currentToken == null) {
        debugPrint('❌ No token to test');
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

      debugPrint('🧪 API test response: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ Token is valid and working');
        return true;
      } else if (response.statusCode == 401) {
        debugPrint('❌ Token is invalid or expired (401)');
        return false;
      } else if (response.statusCode == 403) {
        // FIXED: 403 means token is VALID but user doesn't have permission
        // This is OK - the token works for authentication!
        debugPrint(
            '✅ Token is valid (403 = authenticated but limited permissions)');
        return true; // Changed from false to true!
      } else if (response.statusCode == 408) {
        debugPrint('⏱️ Request timeout');
        return false;
      } else {
        debugPrint('⚠️ Unexpected response: ${response.statusCode}');
        // Assume token might still be valid
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error testing connection: $e');
      return false;
    }
  }

  Future<bool> authenticateWithPin(String pin) async {
    try {
      debugPrint('🔐 === PIN AUTHENTICATION ===');

      final success = await _pinController.verifyPin(pin);

      if (success) {
        debugPrint('✅ PIN verified successfully');
        await _pinController.setUserVerified(true);

        // CRITICAL FIX: Load user data from database
        final pinUserEmail = await _pinController.getPinUserEmail();

        if (pinUserEmail == null || pinUserEmail.isEmpty) {
          debugPrint('❌ No user email associated with PIN');
          error.value = 'PIN configuration error. Please login with password.';
          return false;
        }

        debugPrint('📧 Loading user data for: $pinUserEmail');

        // Load user from database and set authentication state
        await _loadUserFromCache(pinUserEmail);

        // Verify user was loaded successfully
        if (!isLoggedIn.value || currentUser.value == null) {
          debugPrint('❌ Failed to load user data');
          error.value = 'Unable to load user data. Please login with password.';
          return false;
        }

        // ✅ ADMIN-ONLY CHECK
        if (currentUser.value!.role.toLowerCase() != 'admin') {
          error.value =
              'Access restricted. Only administrators can sign in at this time.';
          debugPrint(
              '🚫 Non-admin user blocked via PIN: ${currentUser.value!.email} (${currentUser.value!.role})');
          currentUser.value = null;
          isLoggedIn.value = false;
          return false;
        }

        debugPrint('✅ User loaded: ${currentUser.value!.email}');
        debugPrint(
            '✅ Authentication state set - isLoggedIn: ${isLoggedIn.value}');

        // Restore API token if available for sync
        await _restoreApiTokenForSync(pinUserEmail);

        // ✅ NEW: PRE-LOAD SUBSCRIPTION CACHE BEFORE NAVIGATION
        debugPrint('📦 Pre-loading subscription cache...');
        if (Get.isRegistered<SubscriptionController>()) {
          final subscriptionController = Get.find<SubscriptionController>();

          // Load from cache immediately (instant, no API call)
          try {
            await subscriptionController.loadFromCache();
            debugPrint('✅ Subscription cache pre-loaded');
          } catch (e) {
            debugPrint('⚠️ Failed to pre-load subscription cache: $e');
            // Continue anyway - not critical for login
          }
        }

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
    } catch (e, stackTrace) {
      developer.log('PIN authentication error',
          error: e, stackTrace: stackTrace, name: 'AuthController');
      error.value = 'PIN authentication failed. Please try again.';
      return false;
    }
  }

  /// Get user data from local database
  Future<Map<String, dynamic>?> _getUserFromLocal(String email) async {
    try {
      debugPrint('📂 Getting user from local database: $email');

      final users = await DatabaseHelper.instance.getUsers();
      final userData = users
          .where((u) =>
              u['email']?.toString().toLowerCase() == email.toLowerCase())
          .firstOrNull;

      if (userData != null) {
        debugPrint('✅ User found in local database');
        return userData;
      } else {
        debugPrint('❌ User not found in local database');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting user from local database: $e');
      return null;
    }
  }

  /// Load user from local cache - ENHANCED VERSION
  Future<void> _loadUserFromCache(String email) async {
    try {
      debugPrint('📂 Loading user from cache: $email');

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

        debugPrint('✅ User loaded from cache: ${user.email}');
        debugPrint('   Name: ${user.fname} ${user.lname}');
        debugPrint('   Role: ${user.role}');
        debugPrint('   School ID: ${user.schoolId}');
      } else {
        debugPrint('❌ No user found in cache for: $email');
        currentUser.value = null;
        isLoggedIn.value = false;
      }
    } catch (e) {
      debugPrint('❌ Error loading user from cache: $e');
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
      debugPrint('🧹 Cleared stored token for: $email');
    } catch (e) {
      debugPrint('❌ Error clearing token: $e');
    }
  }

  /// Trigger sync after successful login
  Future<void> _triggerPostLoginSync() async {
    try {
      debugPrint('🔄 === POST-LOGIN AUTO-SYNC ===');

      if (!Get.isRegistered<SyncController>()) {
        debugPrint('⚠️ SyncController not registered');
        return;
      }

      final syncController = Get.find<SyncController>();

      if (!syncController.isOnline.value) {
        debugPrint('⚠️ Offline - skipping auto-sync');
        return;
      }

      if (syncController.isSyncing.value) {
        debugPrint('⚠️ Sync already in progress');
        return;
      }

      debugPrint('✅ Triggering auto-sync after login...');

      Future.delayed(Duration(milliseconds: 800), () {
        if (Get.isRegistered<SyncController>()) {
          Get.find<SyncController>().performFullSync();
          debugPrint('✅ Auto-sync triggered');
        }
      });
    } catch (e) {
      debugPrint('⚠️ Error triggering auto-sync: $e');
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
      debugPrint('🏫 Saving school data from login response...');
      final db = await DatabaseHelper.instance.database;
      final schoolId = schoolData['id']?.toString() ?? '';

      if (schoolId.isEmpty) {
        debugPrint('⚠️ School ID missing, skipping school save');
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
        debugPrint('✅ School saved to local database');
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
        debugPrint('✅ School updated in local database');
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
      debugPrint('⚠️ Error saving school data: $e');
      // Don't throw - school data save is not critical for login
    }
  }

  /// Fetch and save school data using school_id (if not in login response)
  Future<void> _fetchAndSaveSchoolData(String schoolId) async {
    try {
      debugPrint('🏫 Fetching school data for ID: $schoolId');
      // This would call an API endpoint to get school details
      // For now, we'll just ensure the school_id is saved in settings
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'settings',
        {'key': 'school_id', 'value': schoolId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('✅ School ID saved to settings');
    } catch (e) {
      debugPrint('⚠️ Error fetching school data: $e');
    }
  }
}
