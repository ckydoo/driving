import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/subscription_controller.dart';
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
    print('🚀 === STARTING APP BINDINGS ===');

    try {
      await _verifyDatabase();
      await _initializePinAuthentication();
      await _initializeConfiguration();
      await _initializeSyncServices();
      await _initializeAuthController();
      await _initializeDataControllers();
      await _startBackgroundSync();
      _printInitializationSummary();

      print('✅ === APP BINDINGS COMPLETED SUCCESSFULLY ===');
    } catch (e) {
      print('❌ === APP BINDINGS FAILED ===');
      print('Error: $e');
      await _attemptEmergencyInitialization();
    }
  }

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

  Future<void> _initializePinAuthentication() async {
    print('🔐 Initializing PIN authentication...');

    try {
      if (!Get.isRegistered<PinController>()) {
        Get.put<PinController>(PinController(), permanent: true);
        print('✅ PinController initialized');
        Get.put(SubscriptionController(),
            permanent: true); // Initialize subscription controller
      }
      print('✅ PIN authentication initialization completed');
    } catch (e) {
      print('❌ PIN authentication initialization failed: $e');
      print('⚠️ App will continue without PIN authentication');
    }
  }

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

  Future<void> _initializeAuthController() async {
    print('👤 Initializing auth controller...');

    try {
      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
        print('✅ AuthController initialized');

        _setupAuthSyncIntegration();

        print('✅ Auth-Sync integration configured');
      }

      print('✅ Auth controller initialization completed');
    } catch (e) {
      print('❌ Auth controller initialization failed: $e');
      throw e; // Auth is critical
    }
  }

  void _setupAuthSyncIntegration() {
    try {
      final authController = Get.find<AuthController>();
      final syncController = Get.find<SyncController>();

      ever(authController.isLoggedIn, (bool isLoggedIn) {
        print('🔄 Auth state changed: isLoggedIn=$isLoggedIn');
        syncController.onAuthStateChanged(isLoggedIn);
      });

      print('✅ Auth-Sync integration configured');
    } catch (e) {
      print('❌ Auth-Sync integration failed: $e');
    }
  }

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

  Future<void> _startBackgroundSync() async {
    print('🔄 Starting background sync...');

    try {
      final syncController = Get.find<SyncController>();
      final authController = Get.find<AuthController>();

      if (authController.isLoggedIn.value) {
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
