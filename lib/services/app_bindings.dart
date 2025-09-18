// lib/services/app_bindings.dart - FIXED VERSION
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/sync_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:get/get.dart';

class AppBindings extends Bindings {
  @override
  Future<void> dependencies() async {
    print('🚀 === STARTING APP BINDINGS WITH FIXED SYNC ===');

    try {
      // STEP 1: Verify database is ready (already initialized in main.dart)
      await _verifyDatabase();

      // STEP 2: Initialize PIN authentication
      await _initializePinAuthentication();

      // STEP 3: Initialize settings and configuration
      await _initializeConfiguration();

      // STEP 4: Initialize sync services
      await _initializeSyncServices();

      // STEP 5: Initialize auth controller AFTER sync setup
      await _initializeAuthController();

      // STEP 6: Initialize data controllers
      await _initializeDataControllers();

      // STEP 7: Start background sync (single integration point)
      await _startBackgroundSync();

      // STEP 8: Print summary
      _printInitializationSummary();

      print('✅ === APP BINDINGS COMPLETED SUCCESSFULLY ===');
    } catch (e) {
      print('❌ === APP BINDINGS FAILED ===');
      print('Error: $e');
      await _attemptEmergencyInitialization();
    }
  }

  /// STEP 1: Verify database is ready (don't initialize, just check)
  Future<void> _verifyDatabase() async {
    print('🗄️ Verifying database is ready...');

    try {
      // Just verify we can access the database
      final db = await DatabaseHelper.instance.database;
      print('✅ Database verification completed - ready for use');
    } catch (e) {
      print('❌ Database verification failed: $e');
      print('⚠️ Database may not be properly initialized');

      // Don't throw the error - let the app continue with emergency mode
    }
  }

  /// STEP 2: Initialize PIN authentication
  Future<void> _initializePinAuthentication() async {
    print('🔐 Initializing PIN authentication...');

    try {
      if (!Get.isRegistered<PinController>()) {
        Get.put<PinController>(PinController(), permanent: true);
        print('✅ PinController initialized');
      }
      print('✅ PIN authentication initialization completed');
    } catch (e) {
      print('❌ PIN authentication initialization failed: $e');
      print('⚠️ App will continue without PIN authentication');
    }
  }

  /// STEP 3: Initialize settings and school configuration
  Future<void> _initializeConfiguration() async {
    print('⚙️ Initializing configuration...');

    try {
      // Settings Controller
      if (!Get.isRegistered<SettingsController>()) {
        Get.put<SettingsController>(SettingsController(), permanent: true);

        final settingsController = Get.find<SettingsController>();
        await settingsController.loadSettingsFromDatabase();
        print('✅ SettingsController initialized and loaded');
      }

      print('✅ Configuration initialization completed');
    } catch (e) {
      print('❌ Configuration initialization failed: $e');
      print('⚠️ App will continue with default settings');
    }
  }

  /// STEP 4: Initialize sync services
  Future<void> _initializeSyncServices() async {
    print('🔄 Initializing sync services...');

    try {
      // Initialize SyncController (manages sync state and UI)
      if (!Get.isRegistered<SyncController>()) {
        Get.put<SyncController>(SyncController(), permanent: true);
        print('✅ SyncController initialized');
      }

      // SyncService is static, so no initialization needed
      print('✅ SyncService available (static methods)');

      print('✅ Sync services initialization completed');
    } catch (e) {
      print('❌ Sync services initialization failed: $e');
      print('⚠️ App will continue without sync functionality');
    }
  }

  /// STEP 5: Initialize Auth Controller with sync integration
  Future<void> _initializeAuthController() async {
    print('👤 Initializing auth controller...');

    try {
      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
        print('✅ AuthController initialized');

        // FIX: Single point of auth-sync integration
        _setupAuthSyncIntegration();

        print('✅ Auth-Sync integration configured');
      }

      print('✅ Auth controller initialization completed');
    } catch (e) {
      print('❌ Auth controller initialization failed: $e');
      throw e; // Auth is critical
    }
  }

  /// FIX: Single auth-sync integration method
  void _setupAuthSyncIntegration() {
    try {
      final authController = Get.find<AuthController>();
      final syncController = Get.find<SyncController>();

      // Listen to auth state changes for sync - SINGLE INTEGRATION POINT
      ever(authController.isLoggedIn, (bool isLoggedIn) {
        print('🔄 Auth state changed: isLoggedIn=$isLoggedIn');
        syncController.onAuthStateChanged(isLoggedIn);
      });

      print('✅ Auth-Sync integration configured (single point)');
    } catch (e) {
      print('❌ Auth-Sync integration failed: $e');
    }
  }

  /// STEP 6: Initialize data controllers
  Future<void> _initializeDataControllers() async {
    print('📊 Initializing data controllers...');

    try {
      // User Controller
      if (!Get.isRegistered<UserController>()) {
        Get.put<UserController>(UserController(), permanent: true);
        print('✅ UserController initialized');
      }

      // Course Controller
      if (!Get.isRegistered<CourseController>()) {
        Get.put<CourseController>(CourseController(), permanent: true);
        print('✅ CourseController initialized');
      }

      // Schedule Controller
      if (!Get.isRegistered<ScheduleController>()) {
        Get.put<ScheduleController>(ScheduleController(), permanent: true);
        print('✅ ScheduleController initialized');
      }

      // Billing Controller
      if (!Get.isRegistered<BillingController>()) {
        Get.put<BillingController>(BillingController(), permanent: true);
        print('✅ BillingController initialized');
      }

      // Fleet Controller
      if (!Get.isRegistered<FleetController>()) {
        Get.put<FleetController>(FleetController(), permanent: true);
        print('✅ FleetController initialized');
      }

      print('✅ Data controllers initialization completed');
    } catch (e) {
      print('❌ Data controllers initialization failed: $e');
      print('⚠️ Some features may not work properly');
    }
  }

  /// STEP 7: Start background sync (after everything is initialized)
  Future<void> _startBackgroundSync() async {
    print('🔄 Starting background sync...');

    try {
      final syncController = Get.find<SyncController>();
      final authController = Get.find<AuthController>();

      // Only start sync if user is logged in
      if (authController.isLoggedIn.value) {
        // FIX: Use the new onAuthStateChanged method instead of direct calls
        syncController.onAuthStateChanged(true);
        print('✅ Background sync started for logged-in user');
      } else {
        print('ℹ️ User not logged in - sync will start after login');
      }

      print('✅ Background sync initialization completed');
    } catch (e) {
      print('❌ Background sync initialization failed: $e');
      print('⚠️ Manual sync will still be available');
    }
  }

  /// Print initialization summary
  void _printInitializationSummary() {
    print('📋 === INITIALIZATION SUMMARY ===');
    print(
        '✅ Database: ${DatabaseHelper.instance != null ? 'Ready' : 'Failed'}');
    print('✅ Auth: ${Get.isRegistered<AuthController>() ? 'Ready' : 'Failed'}');
    print('✅ Sync: ${Get.isRegistered<SyncController>() ? 'Ready' : 'Failed'}');
    print(
        '✅ Settings: ${Get.isRegistered<SettingsController>() ? 'Ready' : 'Failed'}');
    print(
        '✅ Users: ${Get.isRegistered<UserController>() ? 'Ready' : 'Failed'}');
    print(
        '✅ Courses: ${Get.isRegistered<CourseController>() ? 'Ready' : 'Failed'}');
    print(
        '✅ Schedule: ${Get.isRegistered<ScheduleController>() ? 'Ready' : 'Failed'}');
    print(
        '✅ Billing: ${Get.isRegistered<BillingController>() ? 'Ready' : 'Failed'}');
    print(
        '✅ Fleet: ${Get.isRegistered<FleetController>() ? 'Ready' : 'Failed'}');
    print('✅ PIN: ${Get.isRegistered<PinController>() ? 'Ready' : 'Failed'}');
    print('=================================');
  }

  /// Emergency initialization for critical failures
  Future<void> _attemptEmergencyInitialization() async {
    print('🚨 Attempting emergency initialization...');

    try {
      // Ensure minimal controllers for app to function
      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
      }

      if (!Get.isRegistered<SettingsController>()) {
        Get.put<SettingsController>(SettingsController(), permanent: true);
      }

      print('✅ Emergency initialization completed');
    } catch (e) {
      print('❌ Emergency initialization failed: $e');
      print('💥 App may not function properly');
    }
  }

  /// Emergency trigger fix method
  Future<void> emergencyTriggerFix() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.execute('DROP TRIGGER IF EXISTS update_fleet_timestamp');
      print('🚨 EMERGENCY: Dropped problematic fleet trigger');
    } catch (e) {
      print('❌ Emergency trigger fix failed: $e');
    }
  }
}
