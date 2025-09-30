// lib/controllers/auth_controller.dart - Local-Only Authentication
import 'package:crypto/crypto.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/api_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AuthController extends GetxController {
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

  /// Load user from local cache
  Future<void> _loadUserFromCache(String email) async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      final userData = users
          .where((u) =>
              u['email']?.toString().toLowerCase() == email.toLowerCase())
          .firstOrNull;

      if (userData != null) {
        final user = User.fromJson(userData);
        currentUser.value = user;
        isLoggedIn.value = true;
        userEmail.value = email;
        print('✅ User loaded from cache: ${user.email}');
      } else {
        print('❌ User not found in cache for email: $email');
      }
    } catch (e) {
      print('❌ Error loading user from cache: $e');
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
      final success = await _pinController.setupPin(pin,
          userEmail: currentUser.value!.email);

      if (success) {
        print('✅ PIN setup successful for ${currentUser.value!.email}');
      }

      return success;
    } catch (e) {
      print('❌ PIN setup error: $e');
      error.value = 'PIN setup failed: ${e.toString()}';
      return false;
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

  /// Safe method to check multiple roles - COMPLETELY FIXED VERSION
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

  /// Safe method to check specific role - COMPLETELY FIXED VERSION
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

  /// Safe getter for user's full name - COMPLETELY FIXED VERSION
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

  /// Safe getter for user first name - COMPLETELY FIXED VERSION
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

  /// Safe getter for user initials - COMPLETELY FIXED VERSION
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

  /// Safe getter for user role - COMPLETELY FIXED VERSION
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
      print('📝 Inserting user data: ${userData['email']}');

      // Add password placeholder for API users
      userData['password'] = 'admin123'; // Or any placeholder
      userData['updated_at'] = DateTime.now().toIso8601String();

      await DatabaseHelper.instance.insertUser(userData);
      print('✅ User saved to local database successfully');
    } catch (e) {
      print('! Failed to save user locally: $e');
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

  /// Safe getter for user ID - COMPLETELY FIXED VERSION
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

  /// Store API token using SharedPreferences
  Future<void> _storeApiToken(String email, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_token_$email', token);

      // Also set it in ApiService immediately
      ApiService.setToken(token);

      print('✅ API token stored and set for user: $email');
    } catch (e) {
      print('❌ Error storing token: $e');
    }
  }

  /// Get stored API token for user
  Future<String?> _getStoredApiToken(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('api_token_$email');
    } catch (e) {
      print('❌ Error reading stored token: $e');
      return null;
    }
  }

  /// Test if the current API token works
  Future<bool> _testApiConnection() async {
    try {
      print('🧪 Testing API connection...');

      // Make a simple authenticated request to test the token
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/user'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${ApiService.hasToken ?? ''}',
        },
      );

      print('🧪 API test response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('🧪 API connection test failed: $e');
      return false;
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

  /// Enhanced PIN authentication with proper token handling
  Future<bool> authenticateWithPin(String pin) async {
    try {
      print('🔐 PIN authentication attempt');

      // Verify PIN locally
      final isValidPin = await _pinController.verifyPin(pin);
      if (!isValidPin) {
        error.value = 'Invalid PIN';
        return false;
      }

      // Get email associated with PIN
      final pinUserEmail = await _pinController.getPinUserEmail();
      if (pinUserEmail == null) {
        error.value = 'No user associated with PIN';
        return false;
      }

      print('📧 PIN verified for user: $pinUserEmail');

      // Load user from local cache
      await _loadUserFromCache(pinUserEmail);

      // Check if user was loaded successfully
      if (currentUser.value == null) {
        error.value =
            'User data not found. Please sign in with email and password.';
        return false;
      }

      // User is now loaded, verify login state
      if (!isLoggedIn.value) {
        print(
            '⚠️ Warning: User loaded but isLoggedIn still false, setting to true');
        isLoggedIn.value = true;
      }

      print('✅ PIN authentication successful for ${currentUser.value!.email}');
      print('✅ User: ${currentUser.value!.fname} ${currentUser.value!.lname}');
      print('✅ Login status: ${isLoggedIn.value}');

      // CRITICAL: Restore API token for sync operations
      await _restoreApiTokenForSync(pinUserEmail);

      return true;
    } catch (e) {
      print('❌ PIN authentication error: $e');
      error.value = 'PIN authentication failed: ${e.toString()}';
      return false;
    }
  }

  /// Restore API token after PIN login
  Future<void> _restoreApiTokenForSync(String email) async {
    try {
      print('🔄 Restoring API token for sync operations...');

      // Try to get stored API token
      final storedToken = await _getStoredApiToken(email);

      if (storedToken != null && storedToken.isNotEmpty) {
        // Set the token in ApiService
        ApiService.setToken(storedToken);
        print('✅ API token restored: ${storedToken.substring(0, 10)}...');

        // Test if the token actually works
        final isWorking = await _testApiConnection();
        if (isWorking) {
          print('✅ API token is valid and working');
        } else {
          print('❌ Stored token is expired/invalid - clearing it');
          await _clearStoredToken(email);

          // Show user they need to re-authenticate with password for sync
          _showTokenExpiredDialog();
        }
      } else {
        print('⚠️ No stored API token found for user: $email');
        _showNoTokenDialog();
      }
    } catch (e) {
      print('⚠️ Could not restore API token: $e');
      _showTokenErrorDialog();
    }
  }

  /// Show dialog when token is expired
  void _showTokenExpiredDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Sync Authentication Required'),
        content: const Text(
          'Your session has expired. To sync data, you need to sign in with your password once.\n\n'
          'You can continue using the app offline, or sign in now to enable sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Continue Offline'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed('/login');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show dialog when no token is found
  void _showNoTokenDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Sync Not Available'),
        content: const Text(
          'To enable data sync, you need to sign in with your password at least once.\n\n'
          'You can continue using the app offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Continue Offline'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed('/login');
            },
            child: const Text('Enable Sync'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show dialog when token error occurs
  void _showTokenErrorDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Sync Error'),
        content: const Text(
          'There was an error setting up data sync. You can continue using the app offline.\n\n'
          'To resolve this, try signing in with your password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Continue Offline'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed('/login');
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Enhanced email/password login - ensure token storage
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

      // Extract user data and token
      final userData = loginResponse['user'];
      final token = loginResponse['token'];

      print('✅ API authentication successful');
      print('🔑 Token received: ${token.substring(0, 10)}...');

      // CRITICAL: Store token for future PIN logins
      await _storeApiToken(email, token);

      // Set user as logged in
      final user = User.fromJson(userData);
      currentUser.value = user;
      isLoggedIn.value = true;

      // Save email for future sessions if remember me is enabled
      if (rememberMe.value) {
        userEmail.value = email;
      }

      // Also save to local database for offline access
      await _saveUserToLocal(userData);

      print('✅ User: ${user.fname} ${user.lname} (${user.role})');
      print('✅ Token stored for future PIN logins');
      return true;
    } catch (e) {
      print('❌ API Login error: $e');
      error.value = 'Login failed: ${e.toString()}';

      // Fallback to local login if API fails
      print('🔄 Attempting local fallback login...');
      return await login(email, password);
    } finally {
      isLoading.value = false;
    }
  }

  /// Convenience role check methods - COMPLETELY SAFE
  bool get isAdmin => hasRole('admin');
  bool get isInstructor => hasAnyRole(['admin', 'instructor']);
  bool get isStudent => hasRole('student');
  bool get canAccessAdminFeatures => hasRole('admin');
  bool get canAccessInstructorFeatures => hasAnyRole(['admin', 'instructor']);
}
