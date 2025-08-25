// lib/controllers/auth_controller.dart - Updated to Firebase-First with backward compatibility
import 'package:crypto/crypto.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class AuthController extends GetxController {
  // Core state
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoggedIn = false.obs;
  final RxBool rememberMe = false.obs;
  final RxString userEmail = ''.obs;

  // Firebase - now primary auth system
  firebase_auth.FirebaseAuth? _firebaseAuth;
  FirebaseFirestore? _firestore;
  final Rx<firebase_auth.User?> firebaseUser = Rx<firebase_auth.User?>(null);
  final RxBool firebaseAvailable = false.obs;
  final RxString firebaseError = ''.obs;

  // Migration flag - remove after full migration
  final RxBool isUsingFirebaseFirst = true.obs;

  // Get PIN controller
  PinController get _pinController => Get.find<PinController>();

  @override
  void onInit() {
    super.onInit();
    Get.lazyPut(() => PinController());
    _initializeFirebaseAuth();
  }

  /// Initialize Firebase as primary auth system
  Future<void> _initializeFirebaseAuth() async {
    try {
      print('🔥 Initializing Firebase-first authentication...');

      _firebaseAuth = firebase_auth.FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Test Firebase connection
      await _testFirebaseConnection();
      firebaseAvailable.value = true;

      // Set up auth state listener
      _firebaseAuth!.authStateChanges().listen(_onFirebaseAuthStateChanged);

      print('✅ Firebase-first auth initialized');

      // Handle initial auth state
      await _handleInitialAuthState();
    } catch (e) {
      print('❌ Firebase initialization failed: $e');
      firebaseAvailable.value = false;
      firebaseError.value =
          'Firebase connection failed. Please check internet connection.';

      // Fallback to old system temporarily during migration
      await _checkLoginStatusLegacy();
    }
  }

  /// Test Firebase connection
  Future<void> _testFirebaseConnection() async {
    final currentFirebaseUser = _firebaseAuth?.currentUser;
    print(
        '🔥 Firebase connection test - Current user: ${currentFirebaseUser?.email ?? "none"}');

    // Try to access Firestore
    await _firestore?.collection('test').limit(1).get();
    print('✅ Firebase connection test passed');
  }

  /// Handle initial auth state on app startup
  Future<void> _handleInitialAuthState() async {
    final currentFirebaseUser = _firebaseAuth?.currentUser;

    if (currentFirebaseUser != null) {
      print('🔥 Found existing Firebase user: ${currentFirebaseUser.email}');
      await _syncUserDataFromFirebase(currentFirebaseUser);
    } else {
      print('ℹ️ No existing Firebase user found');
    }
  }

  /// Firebase auth state change handler
  Future<void> _onFirebaseAuthStateChanged(firebase_auth.User? user) async {
    try {
      firebaseUser.value = user;

      if (user != null) {
        print('🔥 Firebase user signed in: ${user.email}');

        // CRITICAL: Always sync user data when Firebase user changes
        await _syncUserDataFromFirebase(user);

        _startSyncService();
      } else {
        print('🔥 Firebase user signed out');
        await _handleSignOut();
      }
    } catch (e) {
      print('❌ Auth state change error: $e');
      error.value = 'Authentication error: ${e.toString()}';
    }
  }

  /// Sync user data from Firebase to local cache
  Future<void> _syncUserDataFromFirebase(
      firebase_auth.User firebaseUser) async {
    try {
      print('🔄 Syncing user data for: ${firebaseUser.email}');

      // Get school config to know which collection to use
      final schoolConfig = Get.find<SchoolConfigService>();
      final schoolId = schoolConfig.schoolId.value;

      if (schoolId.isEmpty) {
        print('⚠️ No school ID found, trying to load from local cache');
        await _loadFromLocalCache(firebaseUser.email);
        return;
      }

      // Debug: Check if user exists locally first
      await _debugUserInLocalDatabase(firebaseUser.email!);

      // Get user data from Firebase
      final userDoc = await _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) {
        print('⚠️ User doc not found in Firebase, trying local cache');
        await _loadFromLocalCache(firebaseUser.email);
        return;
      }

      final userData = userDoc.data()!;
      print('📥 Firebase user data retrieved: ${userData.keys}');

      // Create local user object
      final user = User.fromJson(userData);
      currentUser.value = user;
      isLoggedIn.value = true; // IMPORTANT: Set this explicitly

      // Cache user data locally for offline access
      await _cacheUserLocally(user);

      print('✅ User data synced from Firebase: ${user.email}');
      print('✅ Local login state updated: ${isLoggedIn.value}');
    } catch (e) {
      print('❌ Error syncing user data from Firebase: $e');
      // Try to load from local cache for offline access
      await _loadFromLocalCache(firebaseUser.email);
    }
  }

  /// Debug method to check if user exists in local database
  Future<void> _debugUserInLocalDatabase(String email) async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      print('🔍 Checking local database for user: $email');
      print('📊 Total users in database: ${users.length}');

      final matchingUser = users
          .where((u) =>
              u['email']?.toString().toLowerCase() == email.toLowerCase())
          .firstOrNull;

      if (matchingUser != null) {
        print('✅ User found in local database:');
        print('   Name: ${matchingUser['fname']} ${matchingUser['lname']}');
        print('   Email: ${matchingUser['email']}');
        print('   Role: ${matchingUser['role']}');
      } else {
        print('❌ User NOT found in local database');
        print('📝 Available emails:');
        for (var user in users.take(5)) {
          print('   - ${user['email']}');
        }
      }
    } catch (e) {
      print('❌ Error checking local database: $e');
    }
  }

  /// Cache user data locally for offline access
  Future<void> _cacheUserLocally(User user) async {
    try {
      final existingUsers = await DatabaseHelper.instance.getUsers();
      final existingUser =
          existingUsers.where((u) => u['email'] == user.email).firstOrNull;

      if (existingUser == null) {
        await DatabaseHelper.instance.insertUser(user);
        print('✅ User cached locally for offline access');
      } else {
        await DatabaseHelper.instance.updateUser(user);
        print('✅ Local user cache updated');
      }
    } catch (e) {
      print('⚠️ Could not cache user locally: $e');
    }
  }

  /// Load user from local cache (offline mode)
  Future<void> _loadFromLocalCache(String? email) async {
    if (email == null) return;

    try {
      final users = await DatabaseHelper.instance.getUsers();
      final userData = users.where((u) => u['email'] == email).firstOrNull;

      if (userData != null) {
        final user = User.fromJson(userData);
        currentUser.value = user;
        isLoggedIn.value = true;
        print('✅ Loaded user from offline cache: ${user.email}');
        print('✅ Local login state set: ${isLoggedIn.value}');
      } else {
        print('❌ User not found in local cache for email: $email');
      }
    } catch (e) {
      print('❌ Could not load from offline cache: $e');
    }
  }

  /// Start sync service after successful authentication
  void _startSyncService() {
    try {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      Future.delayed(const Duration(seconds: 1), () {
        syncService.triggerManualSync();
      });
    } catch (e) {
      print('⚠️ Could not start sync service: $e');
    }
  }

  /// PRIMARY LOGIN METHOD - Firebase first, with legacy fallback during migration
  Future<bool> login(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('\n🔐 === FIREBASE-FIRST LOGIN ATTEMPT ===');
      print('📧 Email: $email');

      if (email.isEmpty || password.isEmpty) {
        error.value = 'Email and password are required';
        return false;
      }

      // Try Firebase authentication first
      if (firebaseAvailable.value) {
        try {
          final credential = await _firebaseAuth!.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          if (credential.user != null) {
            print('✅ Firebase authentication successful');

            // CRITICAL: Force immediate sync of user data
            await _syncUserDataFromFirebase(credential.user!);

            print('✅ Local sync status: ${isLoggedIn.value}');

            // User data sync happens automatically in auth state change
            return true;
          }
        } on firebase_auth.FirebaseAuthException catch (e) {
          print('❌ Firebase auth failed: ${e.code}');

          // If user-not-found, try legacy authentication during migration period
          if (e.code == 'user-not-found') {
            print('🔄 User not in Firebase, trying legacy authentication...');
            return await _authenticateLocallyDuringMigration(email, password);
          }

          _handleFirebaseAuthError(e);
          return false;
        }
      } else {
        // Firebase not available, use legacy authentication
        print('⚠️ Firebase unavailable, using legacy authentication');
        return await _authenticateLocallyDuringMigration(email, password);
      }

      return false;
    } catch (e) {
      print('❌ Login error: $e');
      error.value = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Legacy authentication for migration period - REMOVE AFTER MIGRATION
  Future<bool> _authenticateLocallyDuringMigration(
      String email, String password) async {
    try {
      print('🔄 Using legacy local authentication');

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

      // Try different password formats
      if (storedPassword == password) {
        passwordValid = true; // Plain text match
      } else if (storedPassword == _hashPassword(password)) {
        passwordValid = true; // Hashed password match
      }

      if (!passwordValid) {
        error.value = 'Invalid password';
        return false;
      }

      // Set user as logged in
      final user = User.fromJson(userData);
      currentUser.value = user;
      isLoggedIn.value = true;

      print('✅ Legacy authentication successful');

      // Show migration notice
      _showMigrationNotice(email);

      return true;
    } catch (e) {
      print('❌ Legacy authentication error: $e');
      error.value = 'Authentication failed: ${e.toString()}';
      return false;
    }
  }

  /// Show migration notice to user
  void _showMigrationNotice(String email) {
    Get.snackbar(
      'Account Migration Available',
      'Your account can be migrated to the cloud for better sync. Tap to migrate now.',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      mainButton: TextButton(
        onPressed: () => _showMigrationDialog(email),
        child: const Text('MIGRATE', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  /// Show migration dialog
  void _showMigrationDialog(String email) {
    Get.dialog(
      AlertDialog(
        title: const Text('Migrate to Cloud Account'),
        content: const Text(
          'Migrate your account to the cloud for automatic sync across devices. '
          'You\'ll need to create a new password for security.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _startUserMigration(email);
            },
            child: const Text('Migrate Now'),
          ),
        ],
      ),
    );
  }

  /// Start user migration process
  Future<void> _startUserMigration(String email) async {
    // This would open a migration screen where user enters new password
    // For now, just show coming soon
    Get.snackbar(
      'Migration Coming Soon',
      'Account migration will be available in the next update.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
  }

  /// Register new user - Firebase first
  Future<bool> registerWithEmailPassword(
      String email, String password, Map<String, dynamic> userData) async {
    if (!firebaseAvailable.value) {
      error.value = 'Firebase not available. Please check internet connection.';
      return false;
    }

    try {
      isLoading.value = true;
      error.value = '';

      print('🔐 Firebase registration attempt: $email');

      // Create Firebase user
      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Save user data to Firebase
        await _saveUserDataToFirebase(credential.user!, userData);
        print('✅ Firebase registration successful');
        return true;
      }

      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('❌ Firebase registration error: ${e.code}');
      _handleFirebaseAuthError(e);
      return false;
    } catch (e) {
      print('❌ Registration error: $e');
      error.value = 'Registration failed: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Save user data to Firebase
  Future<void> _saveUserDataToFirebase(
      firebase_auth.User firebaseUser, Map<String, dynamic> userData) async {
    try {
      final schoolConfig = Get.find<SchoolConfigService>();
      final schoolId = schoolConfig.schoolId.value;

      // Add Firebase UID and timestamps
      userData['firebase_user_id'] = firebaseUser.uid;
      userData['email'] = firebaseUser.email;
      userData['created_at'] = DateTime.now().toIso8601String();
      userData['last_modified'] = DateTime.now().toIso8601String();
      userData['firebase_synced'] = 1;

      // Save to school's users collection
      await _firestore!
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(firebaseUser.uid)
          .set(userData);

      print('✅ User data saved to Firebase');
    } catch (e) {
      print('❌ Error saving user data to Firebase: $e');
      throw e;
    }
  }

  /// PIN authentication for subsequent logins
  Future<bool> authenticateWithPin(String pin) async {
    try {
      print('🔐 PIN authentication attempt');

      // Verify PIN
      final isValidPin = await _pinController.verifyPin(pin);
      if (!isValidPin) {
        return false;
      }

      // Get email associated with PIN
      final pinUserEmail = await _pinController.getPinUserEmail();
      if (pinUserEmail == null) {
        error.value = 'No user associated with PIN';
        return false;
      }

      // Try to sign in silently with cached Firebase credentials
      final currentFirebaseUser = _firebaseAuth?.currentUser;

      if (currentFirebaseUser?.email?.toLowerCase() ==
          pinUserEmail.toLowerCase()) {
        // Firebase user already signed in
        await _syncUserDataFromFirebase(currentFirebaseUser!);
        print('✅ PIN authentication successful (Firebase active)');
        return true;
      } else {
        // Load from local cache for offline access
        await _loadFromLocalCache(pinUserEmail);
        if (isLoggedIn.value) {
          print('✅ PIN authentication successful (offline mode)');
          return true;
        }
      }

      error.value =
          'Authentication failed. Please sign in with email and password.';
      return false;
    } catch (e) {
      print('❌ PIN authentication error: $e');
      error.value = 'PIN authentication failed: ${e.toString()}';
      return false;
    }
  }

  /// Setup PIN after successful login
  Future<bool> setupPinFromSettings(String pin) async {
    if (currentUser.value?.email == null) {
      error.value = 'No user logged in';
      return false;
    }

    return await _pinController.setupPin(pin,
        userEmail: currentUser.value!.email);
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      isLoading.value = true;

      // Sign out from Firebase
      await _firebaseAuth?.signOut();

      // Clear local state happens in auth state change handler
    } catch (e) {
      print('❌ Sign out error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Handle sign out
  Future<void> _handleSignOut() async {
    currentUser.value = null;
    isLoggedIn.value = false;

    // Don't clear local cache - keep for offline access
    print('✅ User signed out');
  }

  /// Legacy check login status - REMOVE AFTER MIGRATION
  Future<void> _checkLoginStatusLegacy() async {
    try {
      await DatabaseHelper.instance.ensureDefaultUsersExist();
      await _handleInitialAuthFlow();
    } catch (e) {
      print('Error checking login status: $e');
      isLoggedIn.value = false;
    }
  }

  /// Legacy auth flow handler - REMOVE AFTER MIGRATION
  Future<void> _handleInitialAuthFlow() async {
    final isUserVerified = await _pinController.isUserVerified();

    if (isUserVerified) {
      if (_pinController.shouldUsePinAuth()) {
        isLoggedIn.value = false;
      } else {
        isLoggedIn.value = false;
      }
    } else {
      isLoggedIn.value = false;
    }
  }

  /// Get initial route
  Future<String> determineInitialRoute() async {
    // Check if user is already signed into Firebase
    if (_firebaseAuth?.currentUser != null) {
      if (shouldUsePinAuth) {
        return '/pin-login';
      } else {
        return '/main';
      }
    }

    // Check for school configuration
    final schoolConfig = Get.find<SchoolConfigService>();
    if (!schoolConfig.isValidConfiguration()) {
      return '/school-selection';
    }

    return '/login';
  }

  /// Handle Firebase auth errors
  void _handleFirebaseAuthError(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        error.value = 'No account found with this email address.';
        break;
      case 'wrong-password':
        error.value = 'Incorrect password.';
        break;
      case 'user-disabled':
        error.value = 'This account has been disabled.';
        break;
      case 'email-already-in-use':
        error.value = 'An account already exists with this email address.';
        break;
      case 'weak-password':
        error.value = 'Password is too weak.';
        break;
      case 'invalid-email':
        error.value = 'Invalid email address.';
        break;
      case 'network-request-failed':
        error.value = 'Network error. Please check your internet connection.';
        break;
      default:
        error.value = 'Authentication error: ${e.message}';
    }
  }

  /// Helper methods for password hashing
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

  String get currentUserName {
    if (currentUser.value == null) return 'Guest';
    return '${currentUser.value!.fname} ${currentUser.value!.lname}';
  }

  // Get current user's role
  String get currentUserRole {
    return currentUser.value?.role ?? 'Guest';
  }

  /// Compatibility properties
  bool get shouldUsePinAuth => _pinController.shouldUsePinAuth();
  bool get hasPinSetup => _pinController.isPinSet.value;
  bool get isFirebaseAuthenticated => firebaseUser.value != null;
  String? get currentFirebaseUserId => firebaseUser.value?.uid;

  /// Role checking methods (kept for compatibility)
  bool hasAnyRole(List<String> roles) {
    if (!isLoggedIn.value || currentUser.value == null) return false;
    final userRole = currentUser.value!.role.toLowerCase();
    return roles.any((role) => role.toLowerCase() == userRole);
  }

  bool get isAdmin => hasAnyRole(['admin']);
  bool get isInstructor => hasAnyRole(['admin', 'instructor']);
}
