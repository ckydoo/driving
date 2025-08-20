// lib/services/app_bindings.dart - FIXED VERSION
import 'dart:async';
import 'package:driving/controllers/firebase_sync_service.dart';
import 'package:driving/settings/sync_settings_screen.dart';
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

    // STEP 3: Initialize Firebase Sync Service SYNCHRONOUSLY to avoid the error
    await _initializeFirebaseSyncServiceFixed();

    // STEP 4: Initialize NavigationController (depends on AuthController)
    Get.put<NavigationController>(NavigationController(), permanent: true);
    print('✅ NavigationController initialized');

    // STEP 5: Initialize SettingsController
    Get.put<SettingsController>(SettingsController(), permanent: true);
    print('✅ SettingsController initialized');

    // AUTO-SYNC CONTROLLER - Add this AFTER FirebaseSyncService
    Get.put(AutoSyncController(), permanent: true);
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

    // STEP 8: Set up Firebase sync integration AFTER everything is registered
    await _setupFirebaseSyncIntegration();

    // STEP 9: Initialize the automatic sync system
    await _initializeAppSyncSystem();

    // STEP 10: Print summary of initialized controllers
    _printInitializationSummary();
  }

  /// FIXED: Initialize Firebase Sync Service synchronously
  Future<void> _initializeFirebaseSyncServiceFixed() async {
    try {
      print('🔥 Initializing Firebase Sync Service (FIXED)...');

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
        // FIX: Use regular Get.put instead of Get.putAsync to ensure immediate registration
        print('🔄 Creating FirebaseSyncService...');
        final service = FirebaseSyncService();

        // Register the service IMMEDIATELY
        Get.put<FirebaseSyncService>(service, permanent: true);
        print('✅ FirebaseSyncService registered immediately');

        // THEN initialize it asynchronously
        Future.microtask(() async {
          try {
            await _addSyncTrackingToDatabase();
            print('✅ Database sync tracking enabled');

            // Initialize the service
            service.onInit();
            print('✅ FirebaseSyncService initialization completed');
          } catch (e) {
            print('⚠️ FirebaseSyncService async initialization failed: $e');
          }
        });
      } else {
        // Create dummy Firebase sync service
        print(
            '🔄 Creating dummy FirebaseSyncService (Firebase not available)...');
        Get.put<FirebaseSyncService>(
          _createDummyFirebaseSyncService(),
          permanent: true,
        );
        print('✅ Dummy FirebaseSyncService initialized');
      }
    } catch (e) {
      print('❌ Firebase sync initialization failed: $e');
      // Create dummy service as fallback
      Get.put<FirebaseSyncService>(
        _createDummyFirebaseSyncService(),
        permanent: true,
      );
      print('✅ Fallback dummy FirebaseSyncService created');
    }
  }

  /// Create a dummy FirebaseSyncService for when Firebase is not available
  FirebaseSyncService _createDummyFirebaseSyncService() {
    // Return a minimal implementation or use a factory pattern
    // You might need to create a DummyFirebaseSyncService class that extends/implements FirebaseSyncService
    return FirebaseSyncService(); // This might need to be adjusted based on your actual implementation
  }

  /// Set up Firebase sync integration with AuthController
  Future<void> _setupFirebaseSyncIntegration() async {
    try {
      print('🔗 Setting up Firebase sync integration...');

      // Ensure both controllers are available
      if (!Get.isRegistered<AuthController>() ||
          !Get.isRegistered<FirebaseSyncService>()) {
        print(
            '⚠️ Required controllers not registered yet, skipping sync integration');
        return;
      }

      final authController = Get.find<AuthController>();
      final syncService = Get.find<FirebaseSyncService>();

      // Set up auth state change listener
      authController.firebaseUser.listen((firebaseUser) {
        print(
            '🔐 Firebase auth state changed: ${firebaseUser?.email ?? 'null'}');
        if (firebaseUser != null && authController.isLoggedIn.value) {
          print(
              '🔄 Firebase user authenticated - scheduling sync initialization');
          Future.delayed(const Duration(seconds: 2), () {
            try {
              syncService.initializeUserSync();
            } catch (e) {
              print('⚠️ Error initializing user sync: $e');
            }
          });
        }
      });

      print('✅ Firebase sync integration set up');
    } catch (e) {
      print('⚠️ Could not set up Firebase sync integration: $e');
    }
  }

  /// Initialize the app sync system AFTER everything is registered
  Future<void> _initializeAppSyncSystem() async {
    print('🚀 === INITIALIZING APP SYNC SYSTEM ===');

    try {
      // Wait for services to be ready
      await Future.delayed(const Duration(seconds: 1));

      // Verify FirebaseSyncService is registered
      if (!Get.isRegistered<FirebaseSyncService>()) {
        print(
            '❌ FirebaseSyncService not registered, cannot set up automatic sync');
        return;
      }

      // Set up enhanced automatic sync
      final syncService = Get.find<FirebaseSyncService>();

      try {
        await syncService.setupAutomaticSync();
        print('✅ Automatic sync system initialized');
      } catch (e) {
        print('⚠️ Error setting up automatic sync: $e');
      }

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

  /// Add sync tracking to database
  Future<void> _addSyncTrackingToDatabase() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Add sync tracking columns if they don't exist
      const tables = [
        'users',
        'schedules',
        'invoices',
        'payments',
        'attachments',
        'notes',
        'notifications',
        'billing_records'
      ];

      for (final table in tables) {
        try {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN firebase_synced INTEGER DEFAULT 0');
        } catch (e) {
          // Column might already exist, ignore error
        }

        try {
          await db
              .execute('ALTER TABLE $table ADD COLUMN firebase_user_id TEXT');
        } catch (e) {
          // Column might already exist, ignore error
        }
      }

      print('✅ Sync tracking columns added to database');
    } catch (e) {
      print('⚠️ Error adding sync tracking to database: $e');
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

    if (Get.isRegistered<AuthController>()) {
      final authController = Get.find<AuthController>();
      print('\n🔐 AUTHENTICATION STATUS:');
      print('   Local Auth: ${authController.isLoggedIn.value}');
      print('   Firebase Auth: ${authController.isFirebaseAuthenticated}');
      print(
          '   Current User: ${authController.currentUser.value?.email ?? 'None'}');
      print(
          '   Firebase User ID: ${authController.currentFirebaseUserId ?? 'None'}');
    }

    print('\n🚀 === APP BINDINGS COMPLETE ===\n');
  }
}

/// Emergency bindings for fallback initialization
class EmergencyBindings {
  static void initializeMissingControllers() {
    print('🚨 Emergency controller initialization...');

    try {
      if (!Get.isRegistered<AuthController>()) {
        Get.put(AuthController(), permanent: true);
        print('🚨 Emergency AuthController initialized');
      }

      if (!Get.isRegistered<FirebaseSyncService>()) {
        Get.put(FirebaseSyncService(), permanent: true);
        print('🚨 Emergency FirebaseSyncService initialized');
      }

      // Add other critical controllers as needed
    } catch (e) {
      print('❌ Emergency initialization failed: $e');
    }
  }
}
