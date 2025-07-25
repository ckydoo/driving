// lib/services/final_app_bindings.dart
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/enhanced_schedule_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:get/get.dart';

class FinalAppBindings extends Bindings {
  @override
  void dependencies() {
    // Core services
    Get.lazyPut(() => DatabaseHelper(), fenix: true);

    // Navigation
    Get.put(NavigationController(), permanent: true);
    Get.put(EnhancedScheduleController());

    // Controllers - Use the original UserController but ensure proper filtering
    Get.lazyPut(() => UserController(), fenix: true);
    Get.lazyPut(() => CourseController(), fenix: true);
    Get.lazyPut(() => FleetController(), fenix: true);
    Get.lazyPut(() => ScheduleController(), fenix: true);
    Get.lazyPut(() => BillingController(), fenix: true);
  }
}
