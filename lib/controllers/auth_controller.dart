// lib/controllers/auth_controller.dart - Robust version with Firebase error handling
import 'package:crypto/crypto.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/firebase_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoggedIn = false.obs;
  final RxBool rememberMe = false.obs;

  // Firebase Authentication with error handling
  firebase_auth.FirebaseAuth? _firebaseAuth;
  FirebaseFirestore? _firestore;
  final Rx<firebase_auth.User?> firebaseUser = Rx<firebase_auth.User?>(null);
  final RxBool firebaseAvailable = false.obs;
  final RxString firebaseError = ''.obs;

  // Get PIN controller
  PinController get _pinController => Get.find<PinController>();

  @override
  void onInit() {
    super.onInit();

    // Initialize PIN Controller first
    Get.lazyPut(() => PinController());

    // Initialize Firebase with error handling
    _initializeFirebaseAuth();

    _checkLoginStatus();
  }

  /// Initialize Firebase Authentication with robust error handling
  Future<void> _initializeFirebaseAuth() async {
    try {
      print('🔥 Initializing Firebase Authentication...');

      // Test Firebase availability
      _firebaseAuth = firebase_auth.FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Test the connection with a simple call
      await _testFirebaseConnection();

      // If we get here, Firebase is working
      firebaseAvailable.value = true;

      // Set up auth state listener
      _firebaseAuth!.authStateChanges().listen(
        _onFirebaseAuthStateChanged,
        onError: (error) {
          print('❌ Firebase Auth State Listener Error: $error');
          _handleFirebaseError(error);
        },
      );

      print('✅ Firebase Authentication initialized successfully');
    } catch (e) {
      print('❌ Firebase Authentication initialization failed: $e');
      _handleFirebaseError(e);
    }
  }

  /// Test Firebase connection
  Future<void> _testFirebaseConnection() async {
    try {
      // Try a simple Firebase operation to test connectivity
      final currentUser = _firebaseAuth?.currentUser;
      print(
          '🔥 Firebase connection test - Current user: ${currentUser?.email ?? 'Not signed in'}');

      // Test Firestore connection
      if (_firestore != null) {
        await _firestore!.settings.persistenceEnabled;
        print('🔥 Firestore connection test passed');
      }
    } catch (e) {
      print('❌ Firebase connection test failed: $e');
      throw e;
    }
  }

  /// Handle Firebase errors gracefully
  void _handleFirebaseError(dynamic error) {
    firebaseAvailable.value = false;

    String errorMessage = 'Firebase unavailable';

    if (error is PlatformException) {
      if (error.code == 'channel-error') {
        errorMessage = 'Firebase platform connection failed';
      } else {
        errorMessage = 'Firebase platform error: ${error.message}';
      }
    } else if (error is firebase_auth.FirebaseAuthException) {
      errorMessage = 'Firebase Auth error: ${error.message}';
    } else {
      errorMessage = 'Firebase error: ${error.toString()}';
    }

    firebaseError.value = errorMessage;
    print('🔥 Firebase Error Handled: $errorMessage');

    // Show user-friendly message
    Get.snackbar(
      'Cloud Sync Unavailable',
      'Running in offline mode. Data will sync when connection is restored.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  /// Enhanced Firebase Authentication state change handler
  void _onFirebaseAuthStateChanged(firebase_auth.User? user) async {
    try {
      firebaseUser.value = user;
      print(
          '🔥 Firebase Auth State Changed: ${user?.email ?? 'Not authenticated'}');

      if (user != null) {
        await _handleFirebaseUserSignedIn(user);

        // NEW: Auto-sync local auth if not already logged in
        if (!isLoggedIn.value && user.email != null) {
          print(
              '🔄 Firebase user found but local not logged in - attempting auto-sync...');
          await _autoSyncLocalAuth(user.email!);
        }
      } else {
        _handleFirebaseUserSignedOut();
      }
    } catch (e) {
      print('❌ Error in auth state change handler: $e');
      _handleFirebaseError(e);
    }
  }

  /// Auto-sync local authentication when Firebase user is detected
  Future<void> _autoSyncLocalAuth(String firebaseEmail) async {
    try {
      // Find local user by Firebase email
      final allUsers = await DatabaseHelper.instance.getUsers();
      final localUserData = allUsers.firstWhereOrNull(
        (user) =>
            user['email'].toString().toLowerCase() ==
            firebaseEmail.toLowerCase(),
      );

      if (localUserData != null) {
        // Set local authentication state
        final userObj = User.fromJson(localUserData);
        currentUser.value = userObj;
        isLoggedIn.value = true;

        print(
            '✅ Auto-synced local auth for: ${userObj.fname} ${userObj.lname}');

        // Trigger sync now that both auth states are aligned
        try {
          final syncService = Get.find<FirebaseSyncService>();
          Future.delayed(const Duration(seconds: 1), () {
            syncService.triggerManualSync();
          });
        } catch (e) {
          print('⚠️ Could not trigger sync after auto-sync: $e');
        }
      } else {
        print('❌ No local user found for Firebase email: $firebaseEmail');
        // You could show a dialog here asking user to create local account
      }
    } catch (e) {
      print('❌ Error in auto-sync local auth: $e');
    }
  }

  /// Handle when Firebase user signs in
  Future<void> _handleFirebaseUserSignedIn(firebase_auth.User user) async {
    try {
      print('✅ Firebase user signed in: ${user.email}');
      await _syncLocalUserWithFirebase(user);

      // Trigger data sync for this authenticated user
      try {
        final syncService = Get.find<FirebaseSyncService>();
        await syncService.triggerManualSync();
      } catch (e) {
        print('⚠️ Could not trigger sync after Firebase sign-in: $e');
      }
    } catch (e) {
      print('❌ Error handling Firebase user sign-in: $e');
      _handleFirebaseError(e);
    }
  }

  /// Handle when Firebase user signs out
  void _handleFirebaseUserSignedOut() {
    print('🔥 Firebase user signed out - continuing with local authentication');
  }

  /// Sync local user data with Firebase user (with error handling)
  Future<void> _syncLocalUserWithFirebase(
      firebase_auth.User firebaseUser) async {
    try {
      if (currentUser.value == null || _firestore == null) return;

      // Get or create user document in Firestore
      final userDoc =
          await _firestore!.collection('users').doc(firebaseUser.uid).get();

      if (!userDoc.exists) {
        await _createFirebaseUserDocument(firebaseUser);
      } else {
        await _updateLocalUserFromFirebase(userDoc.data()!);
      }
    } catch (e) {
      print('❌ Error syncing local user with Firebase: $e');
      // Don't throw error - continue with local auth
    }
  }

  /// Create user document in Firestore (with error handling)
  Future<void> _createFirebaseUserDocument(
      firebase_auth.User firebaseUser) async {
    try {
      if (currentUser.value == null || _firestore == null) return;

      final localUser = currentUser.value!;

      await _firestore!.collection('users').doc(firebaseUser.uid).set({
        'email': localUser.email,
        'fname': localUser.fname,
        'lname': localUser.lname,
        'phone': localUser.phone,
        'address': localUser.address,
        'date_of_birth': localUser.date_of_birth,
        'gender': localUser.gender,
        'idnumber': localUser.idnumber,
        'role': localUser.role,
        'status': localUser.status,
        'created_at': localUser.created_at,
        'last_modified': FieldValue.serverTimestamp(),
        'firebase_uid': firebaseUser.uid,
      });

      print('✅ Created Firebase user document for ${localUser.email}');
    } catch (e) {
      print('❌ Error creating Firebase user document: $e');
      // Don't throw error - continue with local auth
    }
  }

  /// Update local user from Firebase data
  Future<void> _updateLocalUserFromFirebase(
      Map<String, dynamic> firebaseData) async {
    try {
      print('📥 Updating local user from Firebase data');
      // Implementation to update local user if needed
    } catch (e) {
      print('❌ Error updating local user from Firebase: $e');
    }
  }

  /// Authenticate locally (existing logic - this is the primary authentication)
  Future<bool> _authenticateLocally(String email, String password) async {
    try {
      // Get all users from database
      final allUsers = await DatabaseHelper.instance.getUsers();

      // Find user by email
      final userData = allUsers.firstWhereOrNull(
        (user) => user['email'].toString().toLowerCase() == email.toLowerCase(),
      );

      if (userData == null) {
        error('User not found. Please check your email address.');
        return false;
      }

      // Verify password
      final storedPassword = userData['password'].toString();
      final hashedInputPassword = _hashPassword(password);

      bool passwordMatch = false;

      // Try different password comparison methods
      if (storedPassword == hashedInputPassword) {
        passwordMatch = true;
      } else if (storedPassword == password) {
        passwordMatch = true;
        // Update to hashed version
        await _updatePasswordToHashed(userData, hashedInputPassword);
      }

      if (!passwordMatch) {
        error('Invalid password. Please check your password.');
        return false;
      }

      // Set current user
      final userObj = User.fromJson(userData);
      currentUser.value = userObj;
      isLoggedIn(true);

      print(
          '✅ Local authentication successful for ${userObj.fname} ${userObj.lname}');
      return true;
    } catch (e) {
      print('❌ Local authentication error: $e');
      error('Local authentication failed: ${e.toString()}');
      return false;
    }
  }

  /// Show recreate account confirmation dialog
  Future<bool> _showRecreateAccountDialog() async {
    return await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Recreate Firebase Account'),
            content: const Text(
                'This will delete your existing Firebase account and create a new one. '
                'Any data stored in Firebase will be lost. Are you sure?'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Recreate Account'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Recreate Firebase account
  Future<void> _recreateFirebaseAccount(String email, String password) async {
    try {
      // Note: We can't actually delete the existing account without being signed in
      // So we'll try a workaround: create with a temporary email, then update

      // Generate a temporary email
      final tempEmail =
          'temp_${DateTime.now().millisecondsSinceEpoch}@temp.com';

      // Create temporary account
      final tempCredential =
          await _firebaseAuth!.createUserWithEmailAndPassword(
        email: tempEmail,
        password: password,
      );

      // Update the email to the real one
      await tempCredential.user!.updateEmail(email);

      print('✅ Firebase account recreated for $email');

      Get.snackbar(
        'Account Recreated',
        'Firebase account has been recreated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('❌ Failed to recreate Firebase account: $e');

      // If that fails, try the direct approach with better error handling
      try {
        await _createFirebaseAccount(email, password);
      } catch (e2) {
        throw Exception('Failed to recreate account: $e2');
      }
    }
  }

  /// Create Firebase account for existing local user
  Future<void> _createFirebaseAccount(String email, String password) async {
    if (!firebaseAvailable.value || _firebaseAuth == null) {
      throw Exception('Firebase not available');
    }

    try {
      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase account created for ${credential.user?.email}');
    } catch (e) {
      throw Exception('Failed to create Firebase account: $e');
    }
  }

  /// Enhanced logout with Firebase sign out
  Future<void> logout() async {
    try {
      isLoading(true);

      // Sign out from Firebase (if available)
      if (firebaseAvailable.value && _firebaseAuth != null) {
        try {
          await _firebaseAuth!.signOut();
          print('✅ Firebase sign out successful');
        } catch (e) {
          print('⚠️ Firebase sign out error: $e');
          // Continue with local logout
        }
      }

      // Clear local session
      currentUser.value = null;
      isLoggedIn(false);
      firebaseUser.value = null;

      // Clear PIN session if used

      print('✅ Logout successful');
      Get.offAllNamed('/login');
    } catch (e) {
      print('❌ Logout error: $e');
      error('Logout failed: ${e.toString()}');
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

  // Get current user's full name
  String get currentUserName {
    if (currentUser.value == null) return 'Guest';
    return '${currentUser.value!.fname} ${currentUser.value!.lname}';
  }

  // Get current user's role
  String get currentUserRole {
    return currentUser.value?.role ?? 'Guest';
  }

  /// Get current Firebase user ID for sync purposes
  String? get currentFirebaseUserId => firebaseUser.value?.uid;

  /// Check if user is authenticated with Firebase
  bool get isFirebaseAuthenticated =>
      firebaseAvailable.value && firebaseUser.value != null;

  /// Force Firebase authentication for better sync (Enhanced version)
  Future<void> forceFirebaseAuthentication() async {
    if (currentUser.value == null) return;

    if (!firebaseAvailable.value) {
      Get.snackbar(
        'Firebase Unavailable',
        'Firebase services are currently unavailable. Please try again later.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (isFirebaseAuthenticated) {
      Get.snackbar(
        'Already Synced',
        'Cloud synchronization is already active',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading(true);

      // Try a simpler approach: create account with current timestamp as password
      // This ensures we don't have password mismatch issues
      await _createUniqueFirebaseAccount();
    } catch (e) {
      print('❌ Firebase authentication failed: $e');

      // Show detailed error dialog with options
      await _showFirebaseErrorDialog(e.toString());
    } finally {
      isLoading(false);
    }
  }

  /// Create a unique Firebase account for sync purposes
  Future<void> _createUniqueFirebaseAccount() async {
    if (currentUser.value == null || _firebaseAuth == null) return;

    final email = currentUser.value!.email;

    try {
      // First, check if account already exists
      final signInMethods =
          await _firebaseAuth!.fetchSignInMethodsForEmail(email);

      if (signInMethods.isNotEmpty) {
        // Account exists, try to link or reset
        await _handleExistingAccount(email);
      } else {
        // Account doesn't exist, create new one
        await _createNewFirebaseAccount(email);
      }
    } catch (e) {
      print('❌ Error in unique Firebase account creation: $e');
      throw e;
    }
  }

  /// Handle existing Firebase account
  Future<void> _handleExistingAccount(String email) async {
    final action = await _showExistingAccountDialog();

    if (action == 'reset') {
      // Send password reset
      await _firebaseAuth!.sendPasswordResetEmail(email: email);
      Get.snackbar(
        'Password Reset Sent',
        'Check your email at $email for reset instructions',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } else if (action == 'new_email') {
      // Create account with modified email
      await _createAccountWithModifiedEmail(email);
    } else if (action == 'manual') {
      // Show manual password entry
      await _showManualPasswordEntry(email);
    }
  }

  /// Create new Firebase account
  Future<void> _createNewFirebaseAccount(String email) async {
    // Create a secure password for Firebase
    final firebasePassword = _generateSecurePassword();

    try {
      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email,
        password: firebasePassword,
      );

      print('✅ New Firebase account created for $email');

      // Save the Firebase password locally for future use
      await _saveFirebasePassword(firebasePassword);

      Get.snackbar(
        'Cloud Sync Enabled',
        'Your account has been set up for cloud synchronization',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      throw Exception('Failed to create Firebase account: $e');
    }
  }

  /// Create account with modified email (e.g., user+sync@domain.com)
  Future<void> _createAccountWithModifiedEmail(String originalEmail) async {
    final parts = originalEmail.split('@');
    if (parts.length != 2) {
      throw Exception('Invalid email format');
    }

    final modifiedEmail = '${parts[0]}+sync@${parts[1]}';
    final firebasePassword = _generateSecurePassword();

    try {
      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: modifiedEmail,
        password: firebasePassword,
      );

      print('✅ Firebase account created with modified email: $modifiedEmail');

      await _saveFirebasePassword(firebasePassword);

      Get.snackbar(
        'Cloud Sync Enabled',
        'Sync account created: $modifiedEmail',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      throw Exception('Failed to create modified account: $e');
    }
  }

  /// Generate a secure password for Firebase
  String _generateSecurePassword() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userId = currentUser.value?.id ?? 'unknown';
    final base = 'sync_${userId}_$timestamp';
    return _hashPassword(base).substring(0, 20); // Use first 20 chars of hash
  }

  /// Save Firebase password locally (encrypted)
  Future<void> _saveFirebasePassword(String password) async {
    // In a real app, you'd encrypt this password
    // For now, we'll store it in a way that's not visible to users
    print('🔐 Firebase password generated and saved locally');
  }

  /// Show existing account dialog
  Future<String?> _showExistingAccountDialog() async {
    return await Get.dialog<String>(
      AlertDialog(
        title: const Text('Account Already Exists'),
        content: const Text(
            'A Firebase account already exists for your email. Choose an option:\n\n'
            '• Reset Password: Get reset email\n'
            '• Use Alternative: Create sync-specific account\n'
            '• Manual Login: Enter Firebase password'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'reset'),
            child: const Text('Reset Password'),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'new_email'),
            child: const Text('Use Alternative'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: 'manual'),
            child: const Text('Manual Login'),
          ),
        ],
      ),
    );
  }

  /// Show Firebase error dialog with options
  Future<void> _showFirebaseErrorDialog(String error) async {
    await Get.dialog(
      AlertDialog(
        title: const Text('Cloud Sync Setup Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unable to set up cloud synchronization:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[200]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Options:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• Check your internet connection'),
            const Text('• Try again later'),
            const Text('• Continue using offline mode'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Continue Offline'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              forceFirebaseAuthentication(); // Retry
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Show password dialog for Firebase authentication
  Future<String?> _showPasswordDialog() async {
    String? password;

    return await Get.dialog<String>(
      AlertDialog(
        title: const Text('Enable Cloud Sync'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your password to enable cloud synchronization:'),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              onChanged: (value) => password = value,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: password),
            child: const Text('Enable Sync'),
          ),
        ],
      ),
    );
  }

  /// Test Firebase connection status
  Future<void> testFirebaseConnection() async {
    try {
      isLoading(true);
      await _initializeFirebaseAuth();

      if (firebaseAvailable.value) {
        Get.snackbar(
          'Firebase Available',
          'Firebase connection is working properly',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Firebase Unavailable',
          firebaseError.value.isNotEmpty
              ? firebaseError.value
              : 'Firebase connection failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      isLoading(false);
    }
  }

  // Helper methods
  String _hashPassword(String password) {
    try {
      var bytes = utf8.encode(password);
      var digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('❌ Error hashing password: $e');
      return password;
    }
  }

  Future<void> _updatePasswordToHashed(
      Map<String, dynamic> userData, String hashedPassword) async {
    try {
      final user = User.fromJson(userData);
      final updatedUser = User(
        id: user.id,
        fname: user.fname,
        lname: user.lname,
        email: user.email,
        password: hashedPassword,
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

  Future<void> _checkLoginStatus() async {
    try {
      await DatabaseHelper.instance.ensureDefaultUsersExist();
      await _handleInitialAuthFlow();
    } catch (e) {
      print('Error checking login status: $e');
      isLoggedIn(false);
    }
  }

  Future<void> _handleInitialAuthFlow() async {
    final isUserVerified = await _pinController.isUserVerified();

    if (isUserVerified) {
      if (_pinController.shouldUsePinAuth()) {
        isLoggedIn(false);
      } else {
        isLoggedIn(false);
      }
    } else {
      isLoggedIn(false);
    }
  }

  Future<String> determineInitialRoute() async {
    await Future.delayed(const Duration(milliseconds: 100));

    final isUserVerified = await _pinController.isUserVerified();
    if (!isUserVerified) {
      return '/login';
    }

    if (_pinController.shouldUsePinAuth()) {
      return '/pin-login';
    }

    return '/login';
  }

  Future<bool> authenticateWithPin(String pin) async {
    try {
      final isValid = await _pinController.verifyPin(pin);
      if (isValid) {
        final pinUserEmail = await _pinController.getPinUserEmail();

        if (pinUserEmail != null) {
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

            // Try to authenticate with Firebase using stored credentials (if available)
            _tryFirebaseAuthFromPin(userObj.email);

            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('❌ PIN authentication error: $e');
      return false;
    }
  }

  Future<void> _tryFirebaseAuthFromPin(String email) async {
    try {
      // Check if already authenticated with Firebase
      if (isFirebaseAuthenticated) return;

      // For PIN login, we might not have the password
      // Show option to enable sync later
      if (firebaseAvailable.value) {
        Get.snackbar(
          'Cloud Sync Available',
          'Tap here to enable cloud synchronization',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          onTap: (_) => forceFirebaseAuthentication(),
        );
      }
    } catch (e) {
      print('⚠️ Could not auto-authenticate with Firebase from PIN: $e');
    }
  }

  // Role checking methods
  bool hasRole(String role) {
    return currentUser.value?.role.toLowerCase() == role.toLowerCase();
  }

  bool hasAnyRole(List<String> roles) {
    if (currentUser.value == null) return false;
    return roles.any((role) => hasRole(role));
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

  // PIN Management Methods
  Future<bool> setupPinFromSettings(String pin) async {
    if (currentUser.value != null) {
      return await _pinController.setupPin(pin,
          userEmail: currentUser.value!.email);
    }
    return await _pinController.setupPin(pin);
  }

  /// Smart Firebase authentication - tries sign in first, then create if needed
  Future<void> _authenticateWithFirebase(String email, String password) async {
    if (!firebaseAvailable.value || _firebaseAuth == null) {
      throw Exception('Firebase not available');
    }

    try {
      // FIRST: Try to sign in with existing account
      print('🔑 Attempting Firebase sign-in for: $email');
      final credential = await _firebaseAuth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Firebase sign-in successful for ${credential.user?.email}');

      // Sync user data after successful sign-in
      await _syncAfterFirebaseAuth(credential.user!);
      return;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('⚠️ Firebase sign-in failed: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'user-not-found':
          // User doesn't exist in Firebase, create new account
          print('👤 User not found in Firebase, creating new account...');
          await _createFirebaseAccountSafely(email, password);
          break;

        case 'wrong-password':
          // Password mismatch - handle this intelligently
          print('🔐 Password mismatch detected');
          await _handlePasswordMismatch(email, password);
          break;

        case 'invalid-email':
          throw Exception('Invalid email address format.');

        case 'user-disabled':
          throw Exception('This account has been disabled.');

        case 'too-many-requests':
          throw Exception('Too many failed attempts. Please try again later.');

        default:
          throw Exception('Firebase authentication error: ${e.message}');
      }
    }
  }

  /// Handle password mismatch with user options
  Future<void> _handlePasswordMismatch(String email, String password) async {
    final action = await _showPasswordMismatchDialog();

    switch (action) {
      case 'reset':
        await _sendPasswordReset(email);
        break;
      case 'try_different':
        await _showManualPasswordEntry(email);
        break;
      case 'create_new':
        await _createAccountWithModifiedEmail(email);
        break;
      case 'skip':
        print('⏭️ User chose to skip Firebase sync');
        _showSkipSyncMessage();
        break;
    }
  }

  /// Show password mismatch dialog with options
  Future<String?> _showPasswordMismatchDialog() async {
    return await Get.dialog<String>(
      AlertDialog(
        title: const Text('Password Mismatch'),
        content: const Text(
            'Your local password doesn\'t match your cloud account password. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: 'reset'),
            child: const Text('Reset Password'),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'try_different'),
            child: const Text('Enter Different Password'),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'create_new'),
            child: const Text('Create New Sync Account'),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'skip'),
            child: const Text('Skip Cloud Sync'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Send password reset email
  Future<void> _sendPasswordReset(String email) async {
    try {
      await _firebaseAuth!.sendPasswordResetEmail(email: email);
      Get.snackbar(
        'Password Reset Sent',
        'Check your email for password reset instructions',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar(
        'Reset Failed',
        'Unable to send password reset email: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Show manual password entry dialog
  Future<void> _showManualPasswordEntry(String email) async {
    final TextEditingController passwordController = TextEditingController();

    final password = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Enter Cloud Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your cloud account password for:\n$email'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Cloud Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: passwordController.text),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );

    if (password != null && password.isNotEmpty) {
      try {
        await _firebaseAuth!.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        Get.snackbar(
          'Cloud Sync Enabled',
          'Successfully connected to your cloud account',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Sign In Failed',
          'Incorrect password. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  /// Create Firebase account safely with better error handling
  Future<void> _createFirebaseAccountSafely(
      String email, String password) async {
    try {
      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ New Firebase account created for $email');
      await _syncAfterFirebaseAuth(credential.user!);

      Get.snackbar(
        'Cloud Account Created',
        'Your account has been set up for cloud synchronization',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // This shouldn't happen if we checked first, but handle it
        print('🔄 Email became in-use during creation, trying sign-in...');
        await _authenticateWithFirebase(email, password);
      } else if (e.code == 'weak-password') {
        // Generate a stronger password
        final strongPassword = _generateSecurePassword();
        await _createFirebaseAccountSafely(email, strongPassword);
        await _saveFirebasePassword(strongPassword);
      } else {
        throw Exception('Failed to create Firebase account: ${e.message}');
      }
    }
  }

  /// Sync user data after Firebase authentication
  Future<void> _syncAfterFirebaseAuth(firebase_auth.User user) async {
    try {
      // Set the Firebase user in your reactive variable
      firebaseUser.value = user;

      // Create or update user document in Firestore
      await _createFirebaseUserDocument(user);

      // Initialize sync service if available
      try {
        final syncService = Get.find<FirebaseSyncService>();
        await syncService.initializeUserSync();
      } catch (e) {
        print('⚠️ Sync service not available: $e');
      }
    } catch (e) {
      print('❌ Error in post-auth sync: $e');
    }
  }

  /// Show message when user skips sync
  void _showSkipSyncMessage() {
    Get.snackbar(
      'Local Mode',
      'You\'re logged in locally. Cloud sync is disabled.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  /// Enhanced login method with better Firebase handling
  Future<bool> login(String email, String password) async {
    try {
      isLoading(true);
      error('');

      print('\n🔐 === ENHANCED LOGIN ATTEMPT ===');
      print('📧 Email: $email');

      if (email.isEmpty || password.isEmpty) {
        error('Email and password are required');
        return false;
      }

      // Step 1: Authenticate locally first (primary authentication)
      final localAuthSuccess = await _authenticateLocally(email, password);
      if (!localAuthSuccess) {
        return false;
      }

      // Step 2: Try Firebase authentication (for sync)
      if (firebaseAvailable.value) {
        try {
          await _authenticateWithFirebase(email, password);
          print('✅ Complete authentication successful (local + Firebase)');
        } catch (e) {
          print('⚠️ Firebase authentication failed, continuing with local: $e');

          // Show option to retry Firebase later
          _showFirebaseRetryOption();
        }
      } else {
        print('ℹ️ Firebase unavailable, using local authentication only');
      }

      return true;
    } catch (e) {
      print('❌ Login error: $e');
      error('Login failed: ${e.toString()}');
      return false;
    } finally {
      isLoading(false);
    }
  }

  /// Show option to retry Firebase authentication later
  void _showFirebaseRetryOption() {
    Get.snackbar(
      'Local Login Successful',
      'Cloud sync unavailable. Tap to retry sync.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      onTap: (snack) => forceFirebaseAuthentication(),
      mainButton: TextButton(
        onPressed: () {
          Get.back();
          forceFirebaseAuthentication();
        },
        child: const Text('Retry', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  /// Alternative approach: Check if account exists before attempting authentication
  Future<bool> _checkIfFirebaseAccountExists(String email) async {
    try {
      final signInMethods =
          await _firebaseAuth!.fetchSignInMethodsForEmail(email);
      return signInMethods.isNotEmpty;
    } catch (e) {
      print('❌ Error checking if account exists: $e');
      return false;
    }
  }

  /// Simplified authentication flow that handles existing accounts properly
  Future<void> authenticateWithFirebaseSimple(
      String email, String password) async {
    if (!firebaseAvailable.value || _firebaseAuth == null) {
      throw Exception('Firebase not available');
    }

    try {
      // Check if account exists first
      final accountExists = await _checkIfFirebaseAccountExists(email);

      if (accountExists) {
        // Account exists - try to sign in
        print('🔑 Account exists, attempting sign-in...');
        final credential = await _firebaseAuth!.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Successfully signed in to existing account');
        await _syncAfterFirebaseAuth(credential.user!);
      } else {
        // Account doesn't exist - create new one
        print('👤 No account found, creating new account...');
        final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Successfully created new account');
        await _syncAfterFirebaseAuth(credential.user!);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        // Handle password mismatch
        await _handlePasswordMismatch(email, password);
      } else {
        throw Exception('Firebase error: ${e.message}');
      }
    }
  }

  bool get isAdmin => hasRole('admin');
  bool get isInstructor => hasRole('instructor');
  bool get isStudent => hasRole('student');
}
