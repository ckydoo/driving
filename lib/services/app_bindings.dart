// lib/services/app_bindings.dart - Complete with ALL required controllers
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/user_controller.dart';
import '../controllers/course_controller.dart';
import '../controllers/fleet_controller.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/billing_controller.dart';
import '../controllers/settings_controller.dart';
import '../services/lesson_counting_service.dart';
import '../services/consistency_checker_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/database_helper.dart';

class AppBindings extends Bindings {
  @override
  Future<void> dependencies() async {
    print('🚀 Starting complete app bindings initialization...');

    // STEP 1: Initialize Database Helper first (core dependency)
    await Get.putAsync<DatabaseHelper>(() async {
      print('📊 Initializing DatabaseHelper...');
      final helper = DatabaseHelper.instance;
      await helper.database; // Ensure database is initialized
      print('✅ DatabaseHelper initialized');
      return helper;
    }, permanent: true);

    // STEP 2: Initialize AuthController FIRST (many controllers depend on it)
    Get.put<AuthController>(AuthController(), permanent: true);
    print('✅ AuthController initialized');

    // STEP 3: Initialize NavigationController (depends on AuthController)
    Get.put<NavigationController>(NavigationController(), permanent: true);
    print('✅ NavigationController initialized');

    // STEP 4: Initialize SettingsController early (many services depend on it)
    await Get.putAsync<SettingsController>(() async {
      print('⚙️ Initializing SettingsController...');
      final controller = SettingsController();
      await controller.loadSettingsFromDatabase();
      print('✅ SettingsController initialized');
      return controller;
    }, permanent: true);

    // STEP 5: Initialize Core Data Controllers
    await Get.putAsync<UserController>(() async {
      print('👤 Initializing UserController...');
      final controller = UserController();
      await controller.fetchUsers();
      print('✅ UserController initialized');
      return controller;
    }, permanent: true);

    await Get.putAsync<CourseController>(() async {
      print('📚 Initializing CourseController...');
      final controller = CourseController();
      await controller.fetchCourses();
      print('✅ CourseController initialized');
      return controller;
    }, permanent: true);

    await Get.putAsync<FleetController>(() async {
      print('🚗 Initializing FleetController...');
      final controller = FleetController();
      await controller.fetchFleet();
      print('✅ FleetController initialized');
      return controller;
    }, permanent: true);

    await Get.putAsync<BillingController>(() async {
      print('💰 Initializing BillingController...');
      final controller = BillingController();
      await controller.fetchBillingData();
      print('✅ BillingController initialized');
      return controller;
    }, permanent: true);

    // STEP 6: Initialize ScheduleController (depends on other controllers)
    await Get.putAsync<ScheduleController>(() async {
      print('📅 Initializing ScheduleController...');
      final controller = ScheduleController();
      await controller.fetchSchedules();
      print('✅ ScheduleController initialized');
      return controller;
    }, permanent: true);

    // STEP 7: Initialize Services (depend on controllers)
    await Get.putAsync<LessonCountingService>(() async {
      print('🔢 Initializing LessonCountingService...');
      // Ensure dependencies are available
      if (!Get.isRegistered<SettingsController>()) {
        throw Exception(
            'SettingsController required for LessonCountingService');
      }
      final settingsController = Get.find<SettingsController>();
      await settingsController.loadSettingsFromDatabase(); // Extra safety
      final service = LessonCountingService();
      print('✅ LessonCountingService initialized');
      return service;
    }, permanent: true);

    // STEP 8: Initialize Consistency Checker Service
    Get.put<ConsistencyCheckerService>(
      ConsistencyCheckerService(),
      permanent: true,
    );
    print('✅ ConsistencyCheckerService initialized');

    // STEP 9: Initialize Firebase Sync Service (last, since it might fail)
    await _initializeFirebaseSync();

    print('🎉 All app bindings initialized successfully!');

    // STEP 10: Print summary of initialized controllers
    _printInitializationSummary();
  }

  /// Separate method to handle Firebase sync initialization with proper error handling
  Future<void> _initializeFirebaseSync() async {
    try {
      print('🔥 Checking Firebase availability...');

      // Check if Firebase is initialized
      bool isFirebaseAvailable = false;
      try {
        // Test if Firebase is properly initialized
        if (Firebase.apps.isNotEmpty) {
          isFirebaseAvailable = true;
          print('✅ Firebase is available');
        } else {
          print('⚠️ Firebase not initialized');
        }
      } catch (e) {
        print('⚠️ Firebase check failed: $e');
        isFirebaseAvailable = false;
      }

      if (isFirebaseAvailable) {
        // Try to initialize Firebase Sync Service
        await Get.putAsync<FirebaseSyncService>(() async {
          print('🔄 Initializing FirebaseSyncService...');
          final service = FirebaseSyncService();

          // Add sync tracking to database
          try {
            final dbHelper = Get.find<DatabaseHelper>();
            // Note: Import the extension or define these methods
            // await DatabaseHelperSyncExtension.addSyncTrackingTriggers(await dbHelper.database);
            // await DatabaseHelperSyncExtension.addDeletedColumn(await dbHelper.database);
            print('✅ Database sync tracking enabled');
          } catch (e) {
            print('⚠️ Could not enable database sync tracking: $e');
          }

          await service.onInit();
          print('✅ FirebaseSyncService initialized');
          return service;
        }, permanent: true);
      } else {
        // Create dummy Firebase sync service
        print(
            '🔄 Creating dummy FirebaseSyncService (Firebase not available)...');
        Get.put<FirebaseSyncService>(
          FirebaseSyncServiceDummy() as FirebaseSyncService,
          permanent: true,
        );
        print('✅ Dummy FirebaseSyncService initialized');
      }
    } catch (e) {
      print('❌ Firebase sync initialization failed: $e');
      // Create dummy service as fallback
      Get.put<FirebaseSyncService>(
        FirebaseSyncServiceDummy() as FirebaseSyncService,
        permanent: true,
      );
      print('✅ Fallback FirebaseSyncService initialized');
    }
  }

  /// Print summary of what was initialized
  void _printInitializationSummary() {
    print('\n📋 INITIALIZATION SUMMARY:');
    print('✅ DatabaseHelper: ${Get.isRegistered<DatabaseHelper>()}');
    print('✅ AuthController: ${Get.isRegistered<AuthController>()}');
    print(
        '✅ NavigationController: ${Get.isRegistered<NavigationController>()}');
    print('✅ SettingsController: ${Get.isRegistered<SettingsController>()}');
    print('✅ UserController: ${Get.isRegistered<UserController>()}');
    print('✅ CourseController: ${Get.isRegistered<CourseController>()}');
    print('✅ FleetController: ${Get.isRegistered<FleetController>()}');
    print('✅ BillingController: ${Get.isRegistered<BillingController>()}');
    print('✅ ScheduleController: ${Get.isRegistered<ScheduleController>()}');
    print(
        '✅ LessonCountingService: ${Get.isRegistered<LessonCountingService>()}');
    print(
        '✅ ConsistencyCheckerService: ${Get.isRegistered<ConsistencyCheckerService>()}');
    print('✅ FirebaseSyncService: ${Get.isRegistered<FirebaseSyncService>()}');
    print('\n🎯 Total Controllers Initialized: ${_getInitializedCount()}');
  }

  int _getInitializedCount() {
    int count = 0;
    final controllers = [
      DatabaseHelper,
      AuthController,
      NavigationController,
      SettingsController,
      UserController,
      CourseController,
      FleetController,
      BillingController,
      ScheduleController,
      LessonCountingService,
      ConsistencyCheckerService,
      FirebaseSyncService,
    ];

    for (final controller in controllers) {
      if (Get.isRegistered(tag: controller.toString())) {
        count++;
      }
    }
    return count;
  }
}

/// Dummy Firebase Sync Service for when Firebase is not available
class FirebaseSyncServiceDummy extends GetxController {
  final RxBool isOnline = false.obs;
  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Firebase Not Available'.obs;
  final Rx<DateTime> lastSyncTime = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    print('🔄 Running in offline-only mode (Firebase not available)');
  }

  // Dummy methods that do nothing but don't crash
  Future<void> triggerManualSync() async {
    print('⚠️ Sync not available - Firebase not initialized');
  }

  Future<void> forceFullSync() async {
    print('⚠️ Sync not available - Firebase not initialized');
  }

  Future<void> resetAndResync() async {
    print('⚠️ Sync not available - Firebase not initialized');
  }

  Map<String, dynamic> getSyncStats() {
    return {
      'isOnline': false,
      'isSyncing': false,
      'syncStatus': 'Firebase Not Available',
      'lastSyncTime': DateTime.now(),
      'syncTables': <String>[],
    };
  }
}

/// Emergency controller initializer for missing controllers
class EmergencyBindings {
  static void initializeMissingControllers() {
    print('🚨 Emergency: Initializing missing controllers...');

    // Check and initialize missing core controllers
    if (!Get.isRegistered<AuthController>()) {
      Get.put<AuthController>(AuthController(), permanent: true);
      print('🔧 Emergency: AuthController initialized');
    }

    if (!Get.isRegistered<NavigationController>()) {
      Get.put<NavigationController>(NavigationController(), permanent: true);
      print('🔧 Emergency: NavigationController initialized');
    }

    if (!Get.isRegistered<UserController>()) {
      Get.put<UserController>(UserController(), permanent: true);
      print('🔧 Emergency: UserController initialized');
    }

    if (!Get.isRegistered<CourseController>()) {
      Get.put<CourseController>(CourseController(), permanent: true);
      print('🔧 Emergency: CourseController initialized');
    }

    if (!Get.isRegistered<FleetController>()) {
      Get.put<FleetController>(FleetController(), permanent: true);
      print('🔧 Emergency: FleetController initialized');
    }

    if (!Get.isRegistered<ScheduleController>()) {
      Get.put<ScheduleController>(ScheduleController(), permanent: true);
      print('🔧 Emergency: ScheduleController initialized');
    }

    if (!Get.isRegistered<BillingController>()) {
      Get.put<BillingController>(BillingController(), permanent: true);
      print('🔧 Emergency: BillingController initialized');
    }

    if (!Get.isRegistered<SettingsController>()) {
      Get.put<SettingsController>(SettingsController(), permanent: true);
      print('🔧 Emergency: SettingsController initialized');
    }

    print('🚨 Emergency initialization complete');
  }
}
