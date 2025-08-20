// lib/services/app_bindings.dart - Updated with proper Firebase integration
import 'dart:async';

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

    // STEP 3: Initialize Firebase Sync Service with proper integration
    await _initializeFirebaseSyncService();
    Future<void> initializeAppSyncSystem() async {
      print('🚀 === INITIALIZING APP SYNC SYSTEM ===');

      try {
        // Wait for services to be ready
        await Future.delayed(const Duration(seconds: 2));

        // Set up enhanced automatic sync
        final syncService = Get.find<FirebaseSyncService>();
        await syncService.setupAutomaticSync();

        // If user is already authenticated, trigger initial sync
        final authController = Get.find<AuthController>();
        if (authController.isLoggedIn.value &&
            authController.isFirebaseAuthenticated) {
          print('🔐 User already authenticated - scheduling initial sync');

          // Schedule initial sync after a short delay
          Timer(const Duration(seconds: 5), () async {
            try {
              await syncService.triggerManualSync();
              print('✅ Initial app sync completed');
            } catch (e) {
              print('⚠️ Initial app sync failed: $e');
            }
          });
        }

        print('🚀 === APP SYNC SYSTEM INITIALIZED ===');
      } catch (e) {
        print('❌ Error initializing app sync system: $e');
      }
    }

    // STEP 4: Initialize NavigationController (depends on AuthController)
    Get.put<NavigationController>(NavigationController(), permanent: true);
    print('✅ NavigationController initialized');

    // STEP 5: Initialize SettingsController
    Get.put<SettingsController>(SettingsController(), permanent: true);
    print('✅ SettingsController initialized');

    // STEP 6: Initialize business logic controllers
    Get.put<UserController>(UserController(), permanent: true);
    print('✅ UserController initialized');

    Get.put<CourseController>(CourseController(), permanent: true);
    print('✅ CourseController initialized');

    Get.put<FleetController>(FleetController(), permanent: true);
    print('✅ FleetController initialized');

    Get.put<BillingController>(BillingController(), permanent: true);
    print('✅ BillingController initialized');

    Get.put<ScheduleController>(ScheduleController(), permanent: true);
    print('✅ ScheduleController initialized');

    // STEP 7: Initialize service controllers
    Get.put<LessonCountingService>(LessonCountingService(), permanent: true);
    print('✅ LessonCountingService initialized');
    Get.put<ConsistencyCheckerService>(ConsistencyCheckerService(),
        permanent: true);
    print('✅ ConsistencyCheckerService initialized');

    // STEP 8: Set up Firebase sync integration with AuthController
    await _setupFirebaseSyncIntegration();

    // STEP 9: Print summary of initialized controllers
    _printInitializationSummary();
  }

  /// Enhanced Firebase Sync Service initialization
  Future<void> _initializeFirebaseSyncService() async {
    try {
      print('🔥 Initializing Firebase Sync Service...');

      // Check if Firebase is available
      bool isFirebaseAvailable = false;
      try {
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
        // Initialize real Firebase Sync Service
        await Get.putAsync<FirebaseSyncService>(() async {
          print('🔄 Creating FirebaseSyncService...');
          final service = FirebaseSyncService();

          // Add sync tracking to database
          try {
            await _addSyncTrackingToDatabase();
            print('✅ Database sync tracking enabled');
          } catch (e) {
            print('⚠️ Could not enable database sync tracking: $e');
          }

          service.onInit();
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

  /// Add sync tracking columns to database tables
  Future<void> _addSyncTrackingToDatabase() async {
    final db = await DatabaseHelper.instance.database;
    final syncTables = [
      'users',
      'courses',
      'fleet',
      'schedules',
      'lessons',
      'billing',
      'payments'
    ];

    for (String table in syncTables) {
      try {
        // Add last_modified column
        await db.execute(
            'ALTER TABLE $table ADD COLUMN last_modified INTEGER DEFAULT 0');
      } catch (e) {
        // Column might already exist
      }

      try {
        // Add firebase_synced column
        await db.execute(
            'ALTER TABLE $table ADD COLUMN firebase_synced INTEGER DEFAULT 0');
      } catch (e) {
        // Column might already exist
      }

      try {
        // Add firebase_uid column for linking
        await db.execute('ALTER TABLE $table ADD COLUMN firebase_uid TEXT');
      } catch (e) {
        // Column might already exist
      }

      print('✅ Sync tracking added to $table');
    }
  }

  /// Set up integration between Firebase Sync and Auth Controller
  Future<void> _setupFirebaseSyncIntegration() async {
    try {
      final authController = Get.find<AuthController>();
      final syncService = Get.find<FirebaseSyncService>();

      // Listen for authentication state changes
      ever(authController.isLoggedIn, (bool isLoggedIn) {
        print('🔄 Auth state changed - Logged in: $isLoggedIn');
        if (isLoggedIn && authController.isFirebaseAuthenticated) {
          print('🔄 User logged in with Firebase - initializing sync');
          Future.delayed(const Duration(seconds: 1), () {
            syncService.initializeUserSync();
          });
        }
      });

      // Listen for Firebase authentication changes
      ever(authController.firebaseUser, (firebaseUser) {
        print('🔄 Firebase user changed: ${firebaseUser?.email ?? 'null'}');
        if (firebaseUser != null && authController.isLoggedIn.value) {
          print('🔄 Firebase user authenticated - initializing sync');
          Future.delayed(const Duration(seconds: 1), () {
            syncService.initializeUserSync();
          });
        }
      });

      print('✅ Firebase sync integration set up');
    } catch (e) {
      print('⚠️ Could not set up Firebase sync integration: $e');
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

    final authController = Get.find<AuthController>();
    print('\n🔐 AUTHENTICATION STATUS:');
    print('   Local Auth: ${authController.isLoggedIn.value}');
    print('   Firebase Auth: ${authController.isFirebaseAuthenticated}');
    print(
        '   Current User: ${authController.currentUser.value?.email ?? 'None'}');
    print(
        '   Firebase User ID: ${authController.currentFirebaseUserId ?? 'None'}');

    final syncService = Get.find<FirebaseSyncService>();
    print('\n🔄 SYNC STATUS:');
    final stats = syncService.getSyncStats();
    print('   Online: ${stats['isOnline']}');
    print('   Syncing: ${stats['isSyncing']}');
    print('   Status: ${stats['syncStatus']}');
    print('   Firebase Ready: ${stats['isFirebaseAuthenticated']}');

    print('\n🎯 Total Controllers Initialized: ${_getInitializedCount()}');
  }

  int _getInitializedCount() {
    int count = 0;

    // Check each controller individually
    try {
      Get.find<DatabaseHelper>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<AuthController>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<NavigationController>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<SettingsController>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<UserController>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<CourseController>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<FleetController>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<BillingController>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<ScheduleController>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<LessonCountingService>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<ConsistencyCheckerService>();
      count++;
    } catch (e) {
      // Controller not found
    }

    try {
      Get.find<FirebaseSyncService>();
      count++;
    } catch (e) {
      // Controller not found
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
    Get.snackbar(
      'Sync Unavailable',
      'Firebase sync is not available in this configuration',
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
    );
  }

  Future<void> forceFullSync() async {
    print('⚠️ Full sync not available - Firebase not initialized');
    await triggerManualSync();
  }

  Future<void> resetAndResync() async {
    print('⚠️ Reset sync not available - Firebase not initialized');
    await triggerManualSync();
  }

  Future<void> initializeUserSync() async {
    print('⚠️ User sync not available - Firebase not initialized');
  }

  void listenToRealtimeChanges() {
    print('⚠️ Real-time sync not available - Firebase not initialized');
  }

  Map<String, dynamic> getSyncStats() {
    return {
      'isOnline': false,
      'isSyncing': false,
      'syncStatus': 'Firebase Not Available',
      'lastSyncTime': DateTime.now(),
      'isFirebaseAuthenticated': false,
      'currentUser': null,
      'firebaseUserId': null,
      'syncTables': <String>[],
    };
  }
}
