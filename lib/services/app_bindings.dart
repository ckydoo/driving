// lib/services/app_bindings.dart - Updated for Firebase-First architecture
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
import 'package:get/get.dart';

/// Enhanced App Bindings with Firebase-First Architecture
class EnhancedAppBindings extends Bindings {
  @override
  Future<void> dependencies() async {
    print('🚀 === STARTING FIREBASE-FIRST APP BINDINGS ===');

    try {
      // STEP 1: Initialize core services first
      await emergencyTriggerFix(); // EMERGENCY: Drop problematic trigger
      // STEP 2: Initialize PIN authentication (before auth controller)
      await _initializePinAuthentication();

      // STEP 3: Initialize settings and school configuration
      await _initializeConfiguration();

      // STEP 6: Initialize UI controllers
      await _initializeUIControllers();

      // STEP 7: Initialize business logic controllers
      await _initializeBusinessControllers();

      // STEP 8: Initialize service controllers
      await _initializeServiceControllers();

      // STEP 10: Print summary
      _printInitializationSummary();

      print('✅ === FIREBASE-FIRST APP BINDINGS COMPLETED SUCCESSFULLY ===');
    } catch (e) {
      print('❌ === FIREBASE-FIRST APP BINDINGS FAILED ===');
      print('Error: $e');

      // Attempt emergency initialization
      await _attemptEmergencyInitialization();
    }
  }

// Add this to your app startup or call it immediately:
  Future<void> emergencyTriggerFix() async {
    final db = await DatabaseHelper.instance.database;

    // Drop the problematic fleet trigger immediately
    await db.execute('DROP TRIGGER IF EXISTS update_fleet_timestamp');

    print('🚨 EMERGENCY: Dropped problematic fleet trigger');
    print('✅ Your next sync should work correctly');
  }

  /// STEP 2: Initialize PIN authentication (before auth controller)
  Future<void> _initializePinAuthentication() async {
    print('🔐 Initializing PIN authentication...');

    try {
      // PIN Controller - must be initialized before AuthController
      if (!Get.isRegistered<PinController>()) {
        Get.put<PinController>(PinController(), permanent: true);
        print('✅ PinController initialized');
      }

      print('✅ PIN authentication initialization completed');
    } catch (e) {
      print('❌ PIN authentication initialization failed: $e');
      // Don't throw - PIN is convenience feature
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

        // Load settings from database
        final settingsController = Get.find<SettingsController>();
        await settingsController.loadSettingsFromDatabase();
        await settingsController.testSettingsPersistence();
        await settingsController.forceFixAllSettings();
        await DatabaseMigration.instance.runFullMigration();
        print('   Settings loaded and tested');
        print('✅ SettingsController initialized and loaded');
      }

      print('✅ Firebase services registered');
      // School Config Service (depends on settings)
      if (!Get.isRegistered<SchoolConfigService>()) {
        Get.put<SchoolConfigService>(SchoolConfigService(), permanent: true);

        // Initialize school configuration
        final schoolConfig = Get.find<SchoolConfigService>();
        await schoolConfig.initializeSchoolConfig();

        if (schoolConfig.isValidConfiguration()) {
          print('✅ SchoolConfigService initialized successfully');
          print('   School ID: ${schoolConfig.schoolId.value}');
          print('   School Name: ${schoolConfig.schoolName.value}');
        } else {
          print('⚠️ School configuration incomplete - using fallback values');
        }
      }

      print('✅ Configuration initialization completed');
    } catch (e) {
      print('❌ Configuration initialization failed: $e');
      throw Exception('Configuration failed to initialize: $e');
    }
  }

  /// STEP 6: Initialize UI controllers
  Future<void> _initializeUIControllers() async {
    print('🎨 Initializing UI controllers...');

    try {
      // Navigation Controller (depends on AuthController)
      if (!Get.isRegistered<NavigationController>()) {
        Get.put<NavigationController>(NavigationController(), permanent: true);
        print('✅ NavigationController initialized');
      }

      print('✅ UI controllers initialization completed');
    } catch (e) {
      print('❌ UI controllers initialization failed: $e');
      print('⚠️ App will continue with limited UI functionality');
      // Don't throw - app can still work
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

      // Schedule Controller (depends on User and Course controllers)
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
      // Don't throw - core functionality should still work
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
      // Don't throw - these are optional services
    }
  }

  void _printInitializationSummary() {
    print('\n📊 === INITIALIZATION SUMMARY ===');

    final services = [
      'DatabaseHelper',
      'PinController',
      'SettingsController',
      'SchoolConfigService',
      'AuthController',
      'FixedLocalFirstSyncService', // CHANGED FROM FixedLocalFirstSyncService
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

    print('\n🚀 === FIXED APP READY FOR USE ===');
  }

// 5. ADD/UPDATE HELPER METHOD:
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
      // Initialize only critical services for basic app functionality
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
      print('💀 App may have severe functionality issues');
    }
  }

  /// Initialize a critical service during emergency initialization
  Future<void> _initializeCriticalService(String serviceName) async {
    try {
      switch (serviceName) {
        case 'DatabaseHelper':
          Get.put<DatabaseHelper>(DatabaseHelper.instance, permanent: true);
          print('🚨 Emergency: DatabaseHelper initialized');
          break;
        case 'PinController':
          Get.put<PinController>(PinController(), permanent: true);
          print('🚨 Emergency: PinController initialized');
          break;
        case 'SettingsController':
          Get.put<SettingsController>(SettingsController(), permanent: true);
          print('🚨 Emergency: SettingsController initialized');
          break;
        case 'AuthController':
          Get.put<AuthController>(AuthController(), permanent: true);
          print('🚨 Emergency: AuthController initialized');
          break;
        case 'NavigationController':
          Get.put<NavigationController>(NavigationController(),
              permanent: true);
          print('🚨 Emergency: NavigationController initialized');
          break;
        default:
          print('🚨 Unknown critical service: $serviceName');
      }
    } catch (e) {
      print('❌ Failed to initialize critical service $serviceName: $e');
    }
  }
}

/// Emergency bindings for critical services only
class EmergencyBindings {
  static void initializeMissingControllers() {
    print('🚨 === EMERGENCY BINDINGS ===');
    print('🚨 Initializing missing critical controllers...');

    final criticalControllers = {
      'DatabaseHelper': () =>
          Get.put<DatabaseHelper>(DatabaseHelper.instance, permanent: true),
      'PinController': () =>
          Get.put<PinController>(PinController(), permanent: true),
      'AuthController': () =>
          Get.put<AuthController>(AuthController(), permanent: true),
      'NavigationController': () => Get.put<NavigationController>(
          NavigationController(),
          permanent: true),
    };

    int successCount = 0;

    criticalControllers.forEach((name, initializer) {
      try {
        if (!Get.isRegistered(tag: name)) {
          initializer();
          print('✅ Emergency: $name initialized');
          successCount++;
        } else {
          print('ℹ️ Emergency: $name already exists');
          successCount++;
        }
      } catch (e) {
        print('❌ Emergency: Failed to initialize $name: $e');
      }
    });

    if (successCount >= 3) {
      print('✅ Emergency controllers initialized successfully');
    } else {
      print('❌ Emergency controller initialization insufficient');
      print('💀 App functionality will be severely limited');
    }
  }
}
