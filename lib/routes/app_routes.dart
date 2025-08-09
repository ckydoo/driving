// lib/routes/app_routes.dart
import 'package:driving/dashboard.dart';
import 'package:driving/overview/quick_search_screen.dart';
import 'package:get/get.dart';
import '../widgets/main_layout.dart';

class AppRoutes {
  static const String dashboard = '/dashboard';
  static const String students = '/students';
  static const String instructors = '/instructors';
  static const String courses = '/courses';
  static const String fleet = '/fleet';
  static const String receipts = '/receipts';
  static const String schedules = '/schedules';
  static const String billing = '/billing';
  static const String quickSearch = '/quick-search';
  static const String pos = '/pos';
  static const String settings = '/settings';

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
    GetPage(
      name: settings,
      page: () => CompleteMainLayout(),
    ),
    GetPage(
      name: quickSearch,
      page: () => QuickSearchScreen(),
    ),
    GetPage(
      name: receipts,
      page: () => CompleteMainLayout(),
    ),
    GetPage(
      name: pos,
      page: () => CompleteMainLayout(),
    ),
  ];
}
