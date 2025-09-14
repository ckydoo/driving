// lib/services/app_initialization.dart
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/services/auto_seed_initializer.dart'
    show AutoSeedInitializer;
import 'package:driving/services/schedule_status_migration.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/user_controller.dart';
import '../controllers/course_controller.dart';
import '../controllers/fleet_controller.dart';
import '../controllers/billing_controller.dart';
import '../services/database_helper.dart';
import '../services/database_migration.dart';

class AppInitialization {
  static Future<void> initialize() async {
    try {
      print('Initializing app...');

      // Initialize database helper first
      Get.put(DatabaseHelper.instance, permanent: true);

      // IMPORTANT: Initialize AuthController early - this was missing!
      Get.put(AuthController(), permanent: true);

      // Run database migration
      await DatabaseMigration.instance.runFullMigration();
      print('Enhanced schedules table created');
      // await ScheduleStatusMigration.instance.runStatusMigration();
      print('Database migration completed successfully');
      print('Schedule status migration completed');
      // Initialize controllers in proper order
      await _initializeControllers();
      // Add auto-seeding for development/testing
      await AutoSeedInitializer.instance.developmentInit();
      print('App initialization completed successfully');
    } catch (e) {
      print('Error during app initialization: $e');
      // Show error to user but don't crash the app
      Get.snackbar(
        'Initialization Error',
        'Some features may not work properly. Please restart the app.',
        duration: Duration(seconds: 5),
      );
    }
  }

  static Future<void> _initializeControllers() async {
    try {
      // Initialize core controllers
      Get.put(UserController(), permanent: true);
      Get.put(CourseController(), permanent: true);
      Get.put(FleetController(), permanent: true);
      Get.put(BillingController(), permanent: true);
      Get.put(NavigationController(), permanent: true);

      // Initialize schedule controller last since it depends on others
      Get.put(ScheduleController(), permanent: true);

      // Wait for controllers to load their data
      await Future.wait([
        Get.find<UserController>().fetchUsers(),
        Get.find<CourseController>().fetchCourses(),
        Get.find<FleetController>().fetchFleet(),
        Get.find<BillingController>().fetchBillingData(),
      ]);

      // Initialize schedule controller after dependencies are ready
      await Get.find<ScheduleController>().fetchSchedules();
    } catch (e) {
      print('Error initializing controllers: $e');
    }
  }

  /// Reinitialize controllers if needed
  static Future<void> reinitialize() async {
    try {
      // Clear existing controllers
      Get.delete<ScheduleController>();
      Get.delete<BillingController>();
      Get.delete<FleetController>();
      Get.delete<CourseController>();
      Get.delete<UserController>();

      // Reinitialize
      await _initializeControllers();
    } catch (e) {
      print('Error during reinitialization: $e');
    }
  }
}
