import 'package:flutter/foundation.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/subscription_controller.dart';
import 'package:driving/controllers/sync_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/engagement_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:get/get.dart';

class AppBindings extends Bindings {
  @override
  Future<void> dependencies() async {
    debugPrint('🚀 === STARTING APP BINDINGS (PARALLEL MODE) ===');
    final stopwatch = Stopwatch()..start();

    try {
      // Phase 1: Critical dependencies only (sequential - must complete first)
      debugPrint('⚡ Phase 1: Critical initialization...');
      await _verifyDatabase();
      await _initializeAuthController();

      debugPrint('⚡ Phase 2: Parallel initialization...');
      // Phase 2: Everything else in parallel for maximum speed
      await Future.wait([
        _initializePinAuthentication(),
        _initializeConfiguration(),
        _initializeSyncServices(),
        _initializeDataControllers(),
      ], eagerError: false); // Don't fail if one controller has issues

      // Phase 3: Background tasks (fire and forget - don't wait)
      _startBackgroundSync();

      stopwatch.stop();
      debugPrint(
          '✅ === APP BINDINGS COMPLETED IN ${stopwatch.elapsedMilliseconds}ms ===');
      _printInitializationSummary();
    } catch (e) {
      stopwatch.stop();
      debugPrint(
          '❌ === APP BINDINGS FAILED (${stopwatch.elapsedMilliseconds}ms) ===');
      debugPrint('Error: $e');
      await _attemptEmergencyInitialization();
    }
  }

  Future<void> _verifyDatabase() async {
    debugPrint('🗄️ Verifying database is ready...');

    try {
      // Just verify we can access the database
      final db = await DatabaseHelper.instance.database;
      debugPrint('✅ Database verification completed - ready for use');
    } catch (e) {
      debugPrint('❌ Database verification failed: $e');
      debugPrint('⚠️ Database may not be properly initialized');

      // Don't throw the error - let the app continue with emergency mode
    }
  }

  Future<void> _initializePinAuthentication() async {
    debugPrint('🔐 Initializing PIN authentication...');

    try {
      if (!Get.isRegistered<PinController>()) {
        Get.put<PinController>(PinController(), permanent: true);
        debugPrint('✅ PinController initialized');
        Get.put(SubscriptionController(),
            permanent: true); // Initialize subscription controller
      }
      debugPrint('✅ PIN authentication initialization completed');
    } catch (e) {
      debugPrint('❌ PIN authentication initialization failed: $e');
      debugPrint('⚠️ App will continue without PIN authentication');
    }
  }

  Future<void> _initializeConfiguration() async {
    debugPrint('⚙️ Initializing configuration...');

    try {
      // Settings Controller
      if (!Get.isRegistered<SettingsController>()) {
        Get.put<SettingsController>(SettingsController(), permanent: true);

        final settingsController = Get.find<SettingsController>();
        await settingsController.loadSettingsFromDatabase();
        debugPrint('✅ SettingsController initialized and loaded');
      }

      debugPrint('✅ Configuration initialization completed');
    } catch (e) {
      debugPrint('❌ Configuration initialization failed: $e');
      debugPrint('⚠️ App will continue with default settings');
    }
  }

  Future<void> _initializeSyncServices() async {
    debugPrint('🔄 Initializing sync services...');

    try {
      // Initialize SyncController (manages sync state and UI)
      if (!Get.isRegistered<SyncController>()) {
        Get.put<SyncController>(SyncController(), permanent: true);
        debugPrint('✅ SyncController initialized');
      }

      // SyncService is static, so no initialization needed
      debugPrint('✅ SyncService available (static methods)');

      debugPrint('✅ Sync services initialization completed');
    } catch (e) {
      debugPrint('❌ Sync services initialization failed: $e');
      debugPrint('⚠️ App will continue without sync functionality');
    }
  }

  Future<void> _initializeAuthController() async {
    debugPrint('👤 Initializing auth controller...');

    try {
      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
        debugPrint('✅ AuthController initialized');

        _setupAuthSyncIntegration();

        debugPrint('✅ Auth-Sync integration configured');
      }

      debugPrint('✅ Auth controller initialization completed');
    } catch (e) {
      debugPrint('❌ Auth controller initialization failed: $e');
      throw e; // Auth is critical
    }
  }

  void _setupAuthSyncIntegration() {
    try {
      final authController = Get.find<AuthController>();
      final syncController = Get.find<SyncController>();

      ever(authController.isLoggedIn, (bool isLoggedIn) {
        debugPrint('🔄 Auth state changed: isLoggedIn=$isLoggedIn');
        syncController.onAuthStateChanged(isLoggedIn);
      });

      debugPrint('✅ Auth-Sync integration configured');
    } catch (e) {
      debugPrint('❌ Auth-Sync integration failed: $e');
    }
  }

  Future<void> _initializeDataControllers() async {
    debugPrint('📊 Initializing data controllers in parallel...');

    try {
      // Initialize all data controllers in parallel for maximum speed
      await Future.wait([
        Future(() {
          if (!Get.isRegistered<UserController>()) {
            Get.put<UserController>(UserController(), permanent: true);
            debugPrint('✅ UserController initialized');
          }
        }),
        Future(() {
          if (!Get.isRegistered<CourseController>()) {
            Get.put<CourseController>(CourseController(), permanent: true);
            debugPrint('✅ CourseController initialized');
          }
        }),
        Future(() {
          if (!Get.isRegistered<ScheduleController>()) {
            Get.put<ScheduleController>(ScheduleController(), permanent: true);
            debugPrint('✅ ScheduleController initialized');
          }
        }),
        Future(() {
          if (!Get.isRegistered<BillingController>()) {
            Get.put<BillingController>(BillingController(), permanent: true);
            debugPrint('✅ BillingController initialized');
          }
        }),
        Future(() {
          if (!Get.isRegistered<FleetController>()) {
            Get.put<FleetController>(FleetController(), permanent: true);
            debugPrint('✅ FleetController initialized');
          }
        }),
        Future(() {
          if (!Get.isRegistered<EngagementController>()) {
            Get.put<EngagementController>(EngagementController(),
                permanent: true);
            debugPrint('✅ EngagementController initialized');
          }
        }),
      ], eagerError: false);

      debugPrint('✅ Data controllers initialization completed');
    } catch (e) {
      debugPrint('❌ Data controllers initialization failed: $e');
      debugPrint('⚠️ Some features may not work properly');
    }
  }

  Future<void> _startBackgroundSync() async {
    debugPrint('🔄 Starting background sync...');

    try {
      final syncController = Get.find<SyncController>();
      final authController = Get.find<AuthController>();

      if (authController.isLoggedIn.value) {
        syncController.onAuthStateChanged(true);
        debugPrint('✅ Background sync started for logged-in user');
      } else {
        debugPrint('ℹ️ User not logged in - sync will start after login');
      }

      debugPrint('✅ Background sync initialization completed');
    } catch (e) {
      debugPrint('❌ Background sync initialization failed: $e');
      debugPrint('⚠️ Manual sync will still be available');
    }
  }

  /// Print initialization summary
  void _printInitializationSummary() {
    debugPrint('📋 === INITIALIZATION SUMMARY ===');
    debugPrint(
        '✅ Database: ${DatabaseHelper.instance != null ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ Auth: ${Get.isRegistered<AuthController>() ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ Sync: ${Get.isRegistered<SyncController>() ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ Settings: ${Get.isRegistered<SettingsController>() ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ Users: ${Get.isRegistered<UserController>() ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ Courses: ${Get.isRegistered<CourseController>() ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ Schedule: ${Get.isRegistered<ScheduleController>() ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ Billing: ${Get.isRegistered<BillingController>() ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ Fleet: ${Get.isRegistered<FleetController>() ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ Engagement: ${Get.isRegistered<EngagementController>() ? 'Ready' : 'Failed'}');
    debugPrint(
        '✅ PIN: ${Get.isRegistered<PinController>() ? 'Ready' : 'Failed'}');
    debugPrint('=================================');
  }

  /// Emergency initialization for critical failures
  Future<void> _attemptEmergencyInitialization() async {
    debugPrint('🚨 Attempting emergency initialization...');

    try {
      // Ensure minimal controllers for app to function
      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
      }

      if (!Get.isRegistered<SettingsController>()) {
        Get.put<SettingsController>(SettingsController(), permanent: true);
      }

      debugPrint('✅ Emergency initialization completed');
    } catch (e) {
      debugPrint('❌ Emergency initialization failed: $e');
      debugPrint('💥 App may not function properly');
    }
  }

  /// Emergency trigger fix method
  Future<void> emergencyTriggerFix() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.execute('DROP TRIGGER IF EXISTS update_fleet_timestamp');
      debugPrint('🚨 EMERGENCY: Dropped problematic fleet trigger');
    } catch (e) {
      debugPrint('❌ Emergency trigger fix failed: $e');
    }
  }
}
