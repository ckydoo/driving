import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:get/get.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DatabaseHelper(), fenix: true);
    Get.lazyPut(() => UserController(), fenix: true); // Keep instance alive
    Get.lazyPut(() => CourseController(), fenix: true);
    Get.lazyPut(() => FleetController(), fenix: true);
    Get.lazyPut(() => ScheduleController(), fenix: true);
    Get.lazyPut(() => BillingController(), fenix: true);
  }
}
