// lib/services/app_bindings.dart - Updated with Sync Service Integration
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/services/consistency_checker_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/database_migration.dart';
import 'package:driving/services/lesson_counting_service.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/sync_service.dart'; // ADD THIS
import 'package:driving/controllers/sync_controller.dart'; // ADD THIS
import 'package:get/get.dart';

/// Enhanced App Bindings with Sync Service Integration
class EnhancedAppBindings extends Bindings {
  @override
  Future<void> dependencies() async {
    print('🚀 === STARTING APP BINDINGS WITH SYNC ===');

    try {
      // STEP 1: Initialize core services first
      await emergencyTriggerFix();

      // STEP 2: Initialize PIN authentication (before auth controller)
      await _initializePinAuthentication();

      // STEP 3: Initialize settings and school configuration
      await _initializeConfiguration();

      // STEP 4: Initialize sync services (NEW STEP)
      await _initializeSyncServices();

      // STEP 5: Initialize Auth Controller (after sync setup)
      await _initializeAuthController();

      // STEP 6: Initialize UI controllers
      await _initializeUIControllers();

      // STEP 7: Initialize business logic controllers
      await _initializeBusinessControllers();

      // STEP 8: Initialize service controllers
      await _initializeServiceControllers();

      // STEP 9: Start background sync (NEW STEP)
      await _startBackgroundSync();

      // STEP 10: Print summary
      _printInitializationSummary();

      print('✅ === APP BINDINGS WITH SYNC COMPLETED SUCCESSFULLY ===');
    } catch (e) {
      print('❌ === APP BINDINGS FAILED ===');
      print('Error: $e');
      await _attemptEmergencyInitialization();
    }
  }

  // NEW: Initialize sync services
  Future<void> _initializeSyncServices() async {
    print('🔄 Initializing sync services...');

    try {
      // Initialize SyncController (manages sync state and UI)
      if (!Get.isRegistered<SyncController>()) {
        Get.put<SyncController>(SyncController(), permanent: true);
        print('✅ SyncController initialized');
      }

      // Initialize sync service (actual sync operations)
      // Note: SyncService is static, so no initialization needed
      print('✅ SyncService available (static methods)');

      print('✅ Sync services initialization completed');
    } catch (e) {
      print('❌ Sync services initialization failed: $e');
      print('⚠️ App will continue without sync functionality');
    }
  }

  // UPDATED: Initialize Auth Controller after sync setup
  Future<void> _initializeAuthController() async {
    print('👤 Initializing auth controller...');

    try {
      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
        print('✅ AuthController initialized');

        // Connect auth events to sync
        final authController = Get.find<AuthController>();
        final syncController = Get.find<SyncController>();

        // Listen to auth state changes for sync
        ever(authController.isLoggedIn, (bool isLoggedIn) {
          if (isLoggedIn) {
            print('🔄 User logged in - starting initial sync...');
            syncController.performInitialSync();
          } else {
            print('🔄 User logged out - stopping sync...');
            syncController.stopSync();
          }
        });

        print('✅ Auth-Sync integration configured');
      }

      print('✅ Auth controller initialization completed');
    } catch (e) {
      print('❌ Auth controller initialization failed: $e');
      throw e; // Auth is critical
    }
  }

  // NEW: Start background sync after everything is initialized
  Future<void> _startBackgroundSync() async {
    print('🔄 Starting background sync...');

    try {
      final syncController = Get.find<SyncController>();
      final authController = Get.find<AuthController>();

      // Only start sync if user is logged in
      if (authController.isLoggedIn.value) {
        await syncController.performInitialSync();
        syncController.startPeriodicSync();
        print('✅ Background sync started');
      } else {
        print('ℹ️ User not logged in - sync will start after login');
      }

      print('✅ Background sync initialization completed');
    } catch (e) {
      print('❌ Background sync initialization failed: $e');
      print('⚠️ Manual sync will still be available');
    }
  }

  // Emergency trigger fix method
  Future<void> emergencyTriggerFix() async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('DROP TRIGGER IF EXISTS update_fleet_timestamp');
    print('🚨 EMERGENCY: Dropped problematic fleet trigger');
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
        await settingsController.testSettingsPersistence();
        await settingsController.forceFixAllSettings();
        await DatabaseMigration.instance.runFullMigration();
        print('✅ SettingsController initialized and loaded');
      }

      // School Config Service
      if (!Get.isRegistered<SchoolConfigService>()) {
        Get.put<SchoolConfigService>(SchoolConfigService(), permanent: true);

        final schoolConfig = Get.find<SchoolConfigService>();
        await schoolConfig.initializeSchoolConfig();
        print('✅ SchoolConfigService initialized');
      }

      print('✅ Configuration initialization completed');
    } catch (e) {
      print('❌ Configuration initialization failed: $e');
      print('⚠️ App will continue with default settings');
    }
  }

  /// STEP 6: Initialize UI controllers
  Future<void> _initializeUIControllers() async {
    print('🎨 Initializing UI controllers...');

    try {
      // Navigation Controller
      if (!Get.isRegistered<NavigationController>()) {
        Get.put<NavigationController>(NavigationController(), permanent: true);
        print('✅ NavigationController initialized');
      }

      print('✅ UI controllers initialization completed');
    } catch (e) {
      print('❌ UI controllers initialization failed: $e');
      print('⚠️ Navigation may not work properly');
    }
  }

  /// STEP 7: Initialize business logic controllers
  Future<void> _initializeBusinessControllers() async {
    print('💼 Initializing business logic controllers...');

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

      // Fleet Controller
      if (!Get.isRegistered<FleetController>()) {
        Get.put<FleetController>(FleetController(), permanent: true);
        print('✅ FleetController initialized');
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

      print('✅ Business logic controllers initialization completed');
    } catch (e) {
      print('❌ Business logic controllers initialization failed: $e');
      print('⚠️ Some app features may not work properly');
    }
  }

  /// STEP 8: Initialize service controllers
  Future<void> _initializeServiceControllers() async {
    print('🔧 Initializing service controllers...');

    try {
      // Lesson Counting Service
      if (!Get.isRegistered<LessonCountingService>()) {
        Get.put<LessonCountingService>(LessonCountingService(),
            permanent: true);
        print('✅ LessonCountingService initialized');
      }

      // Consistency Checker Service
      if (!Get.isRegistered<ConsistencyCheckerService>()) {
        Get.put<ConsistencyCheckerService>(ConsistencyCheckerService(),
            permanent: true);
        print('✅ ConsistencyCheckerService initialized');
      }

      print('✅ Service controllers initialization completed');
    } catch (e) {
      print('❌ Service controllers initialization failed: $e');
      print('⚠️ Some background services may not work');
    }
  }

  void _printInitializationSummary() {
    print('\n📊 === INITIALIZATION SUMMARY ===');

    final services = [
      'DatabaseHelper',
      'PinController',
      'SettingsController',
      'SchoolConfigService',
      'SyncController', // NEW
      'AuthController',
      'NavigationController',
      'UserController',
      'CourseController',
      'FleetController',
      'ScheduleController',
      'BillingController',
    ];

    int successCount = 0;
    int totalCount = services.length;

    for (String service in services) {
      bool isInitialized = _isServiceInitialized(service);
      String status = isInitialized ? '✅' : '❌';
      print('$status $service: ${isInitialized ? 'Ready' : 'Failed'}');
      if (isInitialized) successCount++;
    }

    print(
        '\n📈 Success Rate: $successCount/$totalCount (${((successCount / totalCount) * 100).toStringAsFixed(1)}%)');

    if (successCount == totalCount) {
      print('🎉 All services initialized successfully!');
    } else if (successCount >= (totalCount * 0.8)) {
      print('⚠️ Most services initialized - app should work normally');
    } else {
      print(
          '🚨 Multiple service failures - app may have limited functionality');
    }

    print('\n🚀 === APP READY FOR USE WITH SYNC ===');
  }

  /// Check if a service is initialized
  bool _isServiceInitialized(String serviceName) {
    try {
      switch (serviceName) {
        case 'DatabaseHelper':
          return Get.isRegistered<DatabaseHelper>();
        case 'PinController':
          return Get.isRegistered<PinController>();
        case 'SettingsController':
          return Get.isRegistered<SettingsController>();
        case 'SchoolConfigService':
          return Get.isRegistered<SchoolConfigService>();
        case 'SyncController': // NEW
          return Get.isRegistered<SyncController>();
        case 'AuthController':
          return Get.isRegistered<AuthController>();
        case 'NavigationController':
          return Get.isRegistered<NavigationController>();
        case 'UserController':
          return Get.isRegistered<UserController>();
        case 'CourseController':
          return Get.isRegistered<CourseController>();
        case 'FleetController':
          return Get.isRegistered<FleetController>();
        case 'ScheduleController':
          return Get.isRegistered<ScheduleController>();
        case 'BillingController':
          return Get.isRegistered<BillingController>();
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Attempt emergency initialization if main process fails
  Future<void> _attemptEmergencyInitialization() async {
    print('🚨 === EMERGENCY INITIALIZATION ===');

    try {
      final criticalServices = [
        'DatabaseHelper',
        'PinController',
        'SettingsController',
        'AuthController',
        'NavigationController',
      ];

      for (String service in criticalServices) {
        if (!_isServiceInitialized(service)) {
          await _initializeCriticalService(service);
        }
      }

      int initializedCount =
          criticalServices.where(_isServiceInitialized).length;

      if (initializedCount >= 4) {
        print('✅ Emergency initialization successful');
        print('⚠️ App will run with limited functionality');
      } else {
        print('❌ Emergency initialization failed');
        print('💀 App may not function properly');
      }
    } catch (e) {
      print('❌ Emergency initialization failed: $e');
    }
  }

  /// Initialize a critical service during emergency initialization
  Future<void> _initializeCriticalService(String serviceName) async {
    try {
      switch (serviceName) {
        case 'DatabaseHelper':
          Get.put<DatabaseHelper>(DatabaseHelper.instance, permanent: true);
          break;
        case 'PinController':
          Get.put<PinController>(PinController(), permanent: true);
          break;
        case 'SettingsController':
          Get.put<SettingsController>(SettingsController(), permanent: true);
          break;
        case 'AuthController':
          Get.put<AuthController>(AuthController(), permanent: true);
          break;
        case 'NavigationController':
          Get.put<NavigationController>(NavigationController(),
              permanent: true);
          break;
      }
      print('🚨 Emergency: $serviceName initialized');
    } catch (e) {
      print('❌ Failed to initialize critical service $serviceName: $e');
    }
  }
}
