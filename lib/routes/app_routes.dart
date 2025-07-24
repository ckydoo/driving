// lib/routes/app_routes.dart
import 'package:driving/dashboard.dart';
import 'package:get/get.dart';
import '../screens/users/enhanced_users_screen.dart';
import '../screens/course/course_screen.dart';
import '../screens/fleet/fleet_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/billing/billing_screen.dart';
import '../widgets/main_layout.dart';

class AppRoutes {
  static const String dashboard = '/dashboard';
  static const String students = '/students';
  static const String instructors = '/instructors';
  static const String courses = '/courses';
  static const String fleet = '/fleet';
  static const String schedules = '/schedules';
  static const String billing = '/billing';

  static final routes = [
    GetPage(
      name: dashboard,
      page: () => UpdatedDashboardScreen(),
    ),
    GetPage(
      name: students,
      page: () => CompleteMainLayout(),
    ),
    GetPage(
      name: instructors,
      page: () => CompleteMainLayout(),
    ),
    GetPage(
      name: courses,
      page: () => CompleteMainLayout(),
    ),
    GetPage(
      name: fleet,
      page: () => CompleteMainLayout(),
    ),
    GetPage(
      name: schedules,
      page: () => CompleteMainLayout(),
    ),
    GetPage(
      name: billing,
      page: () => CompleteMainLayout(),
    ),
  ];
}
