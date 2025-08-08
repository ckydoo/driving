// lib/main.dart or lib/bindings/initial_binding.dart
// Updated dependency injection to include new services

import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:get/get.dart';
import '../services/lesson_counting_service.dart';
import '../services/consistency_checker_service.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/billing_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/course_controller.dart';

// ... other imports

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Core services first
    Get.put<DatabaseHelper>(DatabaseHelper(), permanent: true);

    // Settings controller (needed by other services)
    Get.put<SettingsController>(SettingsController(), permanent: true);

    // Billing controller (needed by lesson counting)
    Get.put<BillingController>(BillingController(), permanent: true);

    // Schedule controller
    Get.put<ScheduleController>(ScheduleController(), permanent: true);

    // NEW: Centralized lesson counting service
    Get.put<LessonCountingService>(LessonCountingService(), permanent: true);

    // NEW: Consistency checker service
    Get.put<ConsistencyCheckerService>(ConsistencyCheckerService(),
        permanent: true);

    // Other controllers...
    Get.put<UserController>(UserController(), permanent: true);
    Get.put<CourseController>(CourseController(), permanent: true);
    Get.put<FleetController>(FleetController(), permanent: true);
    Get.put(NavigationController());
  }
}

// Alternative approach if using Get.putAsync for async initialization
class AsyncInitialBinding extends Bindings {
  @override
  void dependencies() {
    // Core services
    Get.put<DatabaseHelper>(DatabaseHelper(), permanent: true);

    // Settings controller
    Get.putAsync<SettingsController>(() async {
      final controller = SettingsController();
      await controller.loadSettingsFromDatabase(); // Load settings first
      return controller;
    }, permanent: true);

    // Billing controller
    Get.putAsync<BillingController>(() async {
      final controller = BillingController();
      await controller.fetchBillingData(); // Load billing data
      return controller;
    }, permanent: true);

    // Schedule controller
    Get.putAsync<ScheduleController>(() async {
      final controller = ScheduleController();
      await controller.fetchSchedules(); // Load schedules
      return controller;
    }, permanent: true);

    // Lesson counting service (depends on settings and billing)
    Get.putAsync<LessonCountingService>(() async {
      // Ensure dependencies are loaded first
      await Get.find<SettingsController>().loadSettingsFromDatabase();
      return LessonCountingService();
    }, permanent: true);

    // Consistency checker service
    Get.put<ConsistencyCheckerService>(ConsistencyCheckerService(),
        permanent: true);
  }
}
