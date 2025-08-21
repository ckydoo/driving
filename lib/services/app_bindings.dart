// lib/services/enhanced_app_bindings.dart
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/school_registration_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/services/consistency_checker_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/lesson_counting_service.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:driving/services/school_management_service.dart';
import 'package:get/get.dart';

/// Enhanced App Bindings with Multi-Tenant Support
class EnhancedAppBindings extends Bindings {
  @override
  Future<void> dependencies() async {
    print('🚀 === STARTING ENHANCED APP BINDINGS (Multi-Tenant) ===');

    try {
      // STEP 1: Initialize core services first
      await _initializeCoreServices();

      // STEP 2: Initialize PIN authentication
      await _initializePinAuthentication();

      // STEP 3: Initialize settings (contains business information)
      await _initializeSettings();

      // STEP 4: Initialize school configuration (AFTER settings)
      await _initializeSchoolConfig();

      // STEP 5: Initialize multi-tenant Firebase sync
      await _initializeMultiTenantFirebaseSync();

      // STEP 6: Initialize authentication controller
      await _initializeAuthController();

      // STEP 7: Initialize UI controllers
      await _initializeUIControllers();

      // STEP 8: Initialize business logic controllers
      await _initializeBusinessControllers();

      // STEP 9: Initialize service controllers
      await _initializeServiceControllers();

      // STEP 10: Set up integration and automatic sync
      await _setupIntegrationAndSync();

      // STEP 11: Print summary
      _printInitializationSummary();

      print('✅ === ENHANCED APP BINDINGS COMPLETED SUCCESSFULLY ===');
    } catch (e) {
      print('❌ === ENHANCED APP BINDINGS FAILED ===');
      print('Error: $e');

      // Attempt emergency initialization
      await _attemptEmergencyInitialization();
    }
  }

  /// STEP 1: Initialize core services
  Future<void> _initializeCoreServices() async {
    print('📋 Initializing core services...');

    // Database Helper
    Get.put<DatabaseHelper>(DatabaseHelper(), permanent: true);
    print('✅ DatabaseHelper initialized');
  }

  /// STEP 2: Initialize PIN authentication
  Future<void> _initializePinAuthentication() async {
    Get.put<SchoolManagementService>(SchoolManagementService(),
        permanent: true);
    Get.put<SchoolRegistrationController>(SchoolRegistrationController(),
        permanent: true);
    print('✅ SchoolManagementService initialized');
    print('🔐 Initializing PIN authentication...');

    // PIN Controller (must be first for auth dependencies)
    Get.put<PinController>(PinController(), permanent: true);
    print('✅ PinController initialized');
  }

  /// STEP 3: Initialize settings
  Future<void> _initializeSettings() async {
    print('⚙️ Initializing settings controller...');

    // Settings Controller
    Get.put<SettingsController>(SettingsController(), permanent: true);
    print('✅ SettingsController initialized');

    // Load settings from database
    final settingsController = Get.find<SettingsController>();
    await settingsController.loadSettingsFromDatabase();
    print('📋 Settings loaded from database');
  }

  /// STEP 4: Initialize school configuration
  Future<void> _initializeSchoolConfig() async {
    print('🏫 Initializing school configuration...');

    // School Config Service (depends on settings)
    Get.put<SchoolConfigService>(SchoolConfigService(), permanent: true);
    print('✅ SchoolConfigService initialized');

    // Wait for school configuration to complete
    final schoolConfig = Get.find<SchoolConfigService>();
    await schoolConfig.initializeSchoolConfig();

    if (schoolConfig.isValidConfiguration()) {
      print('✅ School configuration completed successfully');
      print('   School ID: ${schoolConfig.schoolId.value}');
      print('   School Name: ${schoolConfig.schoolName.value}');
    } else {
      print('⚠️ School configuration incomplete - using fallback values');
    }
  }

  /// STEP 5: Initialize multi-tenant Firebase sync
  Future<void> _initializeMultiTenantFirebaseSync() async {
    print('🔄 Initializing multi-tenant Firebase sync...');

    try {
      // Multi-Tenant Firebase Sync Service (depends on school config)
      Get.put<MultiTenantFirebaseSyncService>(MultiTenantFirebaseSyncService(),
          permanent: true);
      print('✅ MultiTenantFirebaseSyncService initialized');

      // Set up automatic sync
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      await syncService.setupAutomaticSync();
      print('✅ Multi-tenant automatic sync configured');
    } catch (e) {
      print('⚠️ Multi-tenant Firebase sync initialization failed: $e');
      print('   App will continue with local-only mode');
    }
  }

  /// STEP 6: Initialize authentication controller
  Future<void> _initializeAuthController() async {
    print('🔑 Initializing authentication...');

    // Auth Controller (depends on PIN and Firebase sync)
    Get.put<AuthController>(AuthController(), permanent: true);
    print('✅ AuthController initialized');
  }

  /// STEP 7: Initialize UI controllers
  Future<void> _initializeUIControllers() async {
    print('🎨 Initializing UI controllers...');

    // Navigation Controller (depends on AuthController)
    Get.put<NavigationController>(NavigationController(), permanent: true);
    print('✅ NavigationController initialized');
  }

  /// STEP 8: Initialize business logic controllers
  Future<void> _initializeBusinessControllers() async {
    print('💼 Initializing business logic controllers...');

    // User Controller
    Get.put<UserController>(UserController(), permanent: true);
    print('✅ UserController initialized');

    // Course Controller
    Get.put<CourseController>(CourseController(), permanent: true);
    print('✅ CourseController initialized');

    // Fleet Controller
    Get.put<FleetController>(FleetController(), permanent: true);
    print('✅ FleetController initialized');

    // Billing Controller
    Get.put<BillingController>(BillingController(), permanent: true);
    print('✅ BillingController initialized');

    // Schedule Controller
    Get.put<ScheduleController>(ScheduleController(), permanent: true);
    print('✅ ScheduleController initialized');
  }

  /// STEP 9: Initialize service controllers
  Future<void> _initializeServiceControllers() async {
    print('🔧 Initializing service controllers...');

    // Lesson Counting Service
    Get.put<LessonCountingService>(LessonCountingService(), permanent: true);
    print('✅ LessonCountingService initialized');

    // Consistency Checker Service
    Get.put<ConsistencyCheckerService>(ConsistencyCheckerService(),
        permanent: true);
    print('✅ ConsistencyCheckerService initialized');
  }

  /// STEP 10: Set up integration and automatic sync
  Future<void> _setupIntegrationAndSync() async {
    print('🔗 Setting up integration and sync...');

    try {
      // Set up settings change listener for school config updates
      _setupSettingsChangeListener();

      // Initialize the automatic sync system
      await _initializeAppSyncSystem();

      // Create initial shared data if needed
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      await syncService.createInitialSharedData();

      print('✅ Integration and sync setup completed');
    } catch (e) {
      print('⚠️ Integration and sync setup failed: $e');
      print('   App will continue with reduced functionality');
    }
  }

  /// Set up listener for settings changes to update school config
  void _setupSettingsChangeListener() {
    final settingsController = Get.find<SettingsController>();
    final schoolConfig = Get.find<SchoolConfigService>();

    // Listen to business name changes
    ever(settingsController.businessName, (String businessName) {
      if (businessName.isNotEmpty) {
        print('📝 Business name changed, updating school config...');
        schoolConfig.updateSchoolConfig();
      }
    });

    // Listen to business address changes
    ever(settingsController.businessAddress, (String businessAddress) {
      print('📍 Business address changed, updating school config...');
      schoolConfig.updateSchoolConfig();
    });

    print('👂 Settings change listeners configured');
  }

  /// Initialize the automatic sync system
  /// Initialize the automatic sync system
  Future<void> _initializeAppSyncSystem() async {
    try {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();

      // Set up automatic sync (this method exists in the base class)
      await syncService.setupAutomaticSync();

      print('✅ Automatic sync system initialized');
    } catch (e) {
      print('⚠️ Automatic sync system initialization failed: $e');
    }
  }

  /// Print initialization summary
  void _printInitializationSummary() {
    print('');
    print('📊 === INITIALIZATION SUMMARY ===');

    // Check all critical services
    final services = [
      'DatabaseHelper',
      'PinController',
      'SettingsController',
      'SchoolConfigService',
      'MultiTenantFirebaseSyncService',
      'AuthController',
      'NavigationController',
      'UserController',
      'CourseController',
      'FleetController',
      'BillingController',
      'ScheduleController',
      'LessonCountingService',
      'ConsistencyCheckerService',
    ];

    print('✅ Successfully initialized ${services.length} services:');
    for (final service in services) {
      final isRegistered = Get.isRegistered<dynamic>(tag: service) ||
          _checkServiceRegistration(service);
      print('   ${isRegistered ? "✅" : "❌"} $service');
    }

    // School configuration status
    try {
      final schoolConfig = Get.find<SchoolConfigService>();
      print('');
      print('🏫 School Configuration:');
      print('   School ID: ${schoolConfig.schoolId.value}');
      print('   School Name: ${schoolConfig.schoolName.value}');
      print(
          '   Status: ${schoolConfig.isValidConfiguration() ? "Valid" : "Invalid"}');
    } catch (e) {
      print('❌ School configuration not available');
    }

    // Firebase sync status
    try {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      print('');
      print('🔄 Firebase Sync:');
      print('   Service: Available');
      print('   Multi-tenant: Enabled');
    } catch (e) {
      print('❌ Firebase sync not available');
    }

    print('');
    print('🎉 Multi-tenant driving school system ready!');
  }

  /// Check if a service is registered (helper method)
  bool _checkServiceRegistration(String serviceName) {
    try {
      switch (serviceName) {
        case 'DatabaseHelper':
          Get.find<DatabaseHelper>();
          return true;
        case 'PinController':
          Get.find<PinController>();
          return true;
        case 'SettingsController':
          Get.find<SettingsController>();
          return true;
        case 'SchoolConfigService':
          Get.find<SchoolConfigService>();
          return true;
        case 'MultiTenantFirebaseSyncService':
          Get.find<MultiTenantFirebaseSyncService>();
          return true;
        case 'AuthController':
          Get.find<AuthController>();
          return true;
        case 'NavigationController':
          Get.find<NavigationController>();
          return true;
        case 'UserController':
          Get.find<UserController>();
          return true;
        case 'CourseController':
          Get.find<CourseController>();
          return true;
        case 'FleetController':
          Get.find<FleetController>();
          return true;
        case 'BillingController':
          Get.find<BillingController>();
          return true;
        case 'ScheduleController':
          Get.find<ScheduleController>();
          return true;
        case 'LessonCountingService':
          Get.find<LessonCountingService>();
          return true;
        case 'ConsistencyCheckerService':
          Get.find<ConsistencyCheckerService>();
          return true;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Attempt emergency initialization if main process fails
  Future<void> _attemptEmergencyInitialization() async {
    print('🚨 Attempting emergency initialization...');

    try {
      // Initialize only critical services
      if (!Get.isRegistered<DatabaseHelper>()) {
        Get.put<DatabaseHelper>(DatabaseHelper(), permanent: true);
        print('🚨 Emergency: DatabaseHelper initialized');
      }

      if (!Get.isRegistered<PinController>()) {
        Get.put<PinController>(PinController(), permanent: true);
        print('🚨 Emergency: PinController initialized');
      }

      if (!Get.isRegistered<SettingsController>()) {
        Get.put<SettingsController>(SettingsController(), permanent: true);
        print('🚨 Emergency: SettingsController initialized');
      }

      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
        print('🚨 Emergency: AuthController initialized');
      }

      if (!Get.isRegistered<NavigationController>()) {
        Get.put<NavigationController>(NavigationController(), permanent: true);
        print('🚨 Emergency: NavigationController initialized');
      }

      print('✅ Emergency initialization completed');
    } catch (e) {
      print('❌ Emergency initialization failed: $e');
      print('💀 App may have limited functionality');
    }
  }
}

/// Emergency bindings for critical services only
class EmergencyBindings {
  static void initializeMissingControllers() {
    print('🚨 Emergency bindings - initializing missing controllers...');

    try {
      // Critical controllers only
      if (!Get.isRegistered<PinController>()) {
        Get.put<PinController>(PinController(), permanent: true);
        print('🚨 PinController emergency init');
      }

      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
        print('🚨 AuthController emergency init');
      }

      if (!Get.isRegistered<NavigationController>()) {
        Get.put<NavigationController>(NavigationController(), permanent: true);
        print('🚨 NavigationController emergency init');
      }

      print('✅ Emergency controllers initialized');
    } catch (e) {
      print('❌ Emergency controller initialization failed: $e');
    }
  }
}
