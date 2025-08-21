// lib/controllers/auth_controller.dart - Enhanced with Firebase Authentication
import 'package:crypto/crypto.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/firebase_sync_service.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:flutter/material.dart';
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

  // Firebase Authentication
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Rx<firebase_auth.User?> firebaseUser = Rx<firebase_auth.User?>(null);

  // Get PIN controller
  PinController get _pinController => Get.find<PinController>();

  @override
  void onInit() {
    super.onInit();

    // Initialize PIN Controller first
    Get.lazyPut(() => PinController());

    // Listen to Firebase Auth state changes
    _firebaseAuth.authStateChanges().listen(_onFirebaseAuthStateChanged);

    _checkLoginStatus();
  }

  /// Handle Firebase Authentication state changes
  void _onFirebaseAuthStateChanged(firebase_auth.User? user) {
    firebaseUser.value = user;
    print(
        '🔥 Firebase Auth State Changed: ${user?.email ?? 'Not authenticated'}');

    if (user != null) {
      // User is signed in to Firebase
      _handleFirebaseUserSignedIn(user);
    } else {
      // User is signed out of Firebase
      _handleFirebaseUserSignedOut();
    }
  }

  /// Handle when Firebase user signs in
  Future<void> _handleFirebaseUserSignedIn(firebase_auth.User user) async {
    try {
      // Sync local user with Firebase user
      await _syncLocalUserWithFirebase(user);

      // Trigger data sync for this authenticated user
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      await syncService.triggerManualSync();
    } catch (e) {
      print('❌ Error handling Firebase user sign-in: $e');
    }
  }

  /// Handle when Firebase user signs out
  void _handleFirebaseUserSignedOut() {
    // Clear local authentication but don't force logout if user prefers local auth
    print('🔥 Firebase user signed out');
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

  Future<bool> changePinFromSettings(String currentPin, String newPin) async {
    return await _pinController.changePin(currentPin, newPin);
  }

  Future<void> disablePinFromSettings() async {
    await _pinController.disablePin();
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

  /// Sync local user data with Firebase user
  Future<void> _syncLocalUserWithFirebase(
      firebase_auth.User firebaseUser) async {
    try {
      if (currentUser.value == null) return;

      // Get or create user document in Firestore
      final userDoc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (!userDoc.exists) {
        // Create user document in Firestore
        await _createFirebaseUserDocument(firebaseUser);
      } else {
        // Update local user with any Firebase changes
        await _updateLocalUserFromFirebase(userDoc.data()!);
      }
    } catch (e) {
      print('❌ Error syncing local user with Firebase: $e');
    }
  }

  /// Create user document in Firestore
  Future<void> _createFirebaseUserDocument(
      firebase_auth.User firebaseUser) async {
    if (currentUser.value == null) return;

    final localUser = currentUser.value!;

    await _firestore.collection('users').doc(firebaseUser.uid).set({
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
  }

  /// Update local user from Firebase data
  Future<void> _updateLocalUserFromFirebase(
      Map<String, dynamic> firebaseData) async {
    // Implementation to update local user if needed
    print('📥 Updating local user from Firebase data');
  }

  /// Enhanced login with Firebase Authentication
  Future<bool> login(String email, String password) async {
    try {
      isLoading(true);
      error('');

      print('\n🔐 === LOGIN ATTEMPT ===');
      print('📧 Email: $email');

      if (email.isEmpty || password.isEmpty) {
        error('Email and password are required');
        return false;
      }

      // Step 1: Authenticate locally first (existing logic)
      final localAuthSuccess = await _authenticateLocally(email, password);
      if (!localAuthSuccess) {
        return false;
      }

      // Step 2: Try to authenticate with Firebase
      try {
        await _authenticateWithFirebase(email, password);
        print('✅ Firebase authentication successful');
      } catch (e) {
        print('⚠️ Firebase authentication failed: $e');
        // Continue with local auth only, but show warning
        Get.snackbar(
          'Sync Warning',
          'Local login successful, but cloud sync may be limited',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
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

  /// Authenticate locally (existing logic)
  Future<bool> _authenticateLocally(String email, String password) async {
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
  }

  /// Authenticate with Firebase
  Future<void> _authenticateWithFirebase(String email, String password) async {
    try {
      // Try to sign in with existing account
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase sign-in successful for ${credential.user?.email}');
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // User doesn't exist in Firebase, create account
        await _createFirebaseAccount(email, password);
      } else if (e.code == 'wrong-password') {
        // Password mismatch - this could be normal if local and Firebase passwords differ
        print('⚠️ Firebase password mismatch - creating new account');
        await _createFirebaseAccount(email, password);
      } else {
        throw e;
      }
    }
  }

  /// Create Firebase account for existing local user
  Future<void> _createFirebaseAccount(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase account created for ${credential.user?.email}');

      // The authStateChanges listener will handle the rest
    } catch (e) {
      print('❌ Failed to create Firebase account: $e');
      throw e;
    }
  }

  /// Enhanced logout with Firebase sign out
  Future<void> logout() async {
    try {
      isLoading(true);

      // Sign out from Firebase
      await _firebaseAuth.signOut();

      // Clear local session
      currentUser.value = null;
      isLoggedIn(false);
      firebaseUser.value = null;

      // Clear PIN session if used
      await _pinController.clearAllPinData();

      print('✅ Logout successful');
      Get.offAllNamed('/login');
    } catch (e) {
      print('❌ Logout error: $e');
      error('Logout failed: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  /// Get current Firebase user ID for sync purposes
  String? get currentFirebaseUserId => firebaseUser.value?.uid;

  /// Check if user is authenticated with Firebase
  bool get isFirebaseAuthenticated => firebaseUser.value != null;

  /// Force Firebase authentication for better sync
  Future<void> forceFirebaseAuthentication() async {
    if (currentUser.value == null || isFirebaseAuthenticated) return;

    try {
      isLoading(true);

      // Show dialog asking user to re-enter password for Firebase sync
      final password = await _showPasswordDialog();
      if (password != null) {
        await _authenticateWithFirebase(currentUser.value!.email, password);
        Get.snackbar(
          'Sync Enabled',
          'Cloud synchronization is now active',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Sync Error',
        'Failed to enable cloud sync: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  /// Show password dialog for Firebase authentication
  Future<String?> _showPasswordDialog() async {
    String? password;

    await Get.dialog(
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

    return password;
  }

  // Rest of your existing methods (PIN auth, password hashing, etc.)
  // ... keeping all your existing functionality

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

            // Try to authenticate with Firebase using stored credentials
            await _tryFirebaseAuthFromPin(userObj.email);

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

  Future<void> _tryFirebaseAuthFromPin(String email) async {
    try {
      // Check if already authenticated with Firebase
      if (isFirebaseAuthenticated) return;

      // For PIN login, we might not have the password
      // Show option to enable sync later
      Get.snackbar(
        'Sync Available',
        'Tap here to enable cloud synchronization',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        onTap: (_) => forceFirebaseAuthentication(),
      );
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

  bool get isAdmin => hasRole('admin');
  bool get isInstructor => hasRole('instructor');
  bool get isStudent => hasRole('student');
}
