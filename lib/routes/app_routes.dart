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
      page: () => FixedDashboardScreen(),
    ),
    GetPage(
      name: students,
      page: () => ResponsiveMainLayout(),
    ),
    GetPage(
      name: instructors,
      page: () => ResponsiveMainLayout(),
    ),
    GetPage(
      name: courses,
      page: () => ResponsiveMainLayout(),
    ),
    GetPage(
      name: fleet,
      page: () => ResponsiveMainLayout(),
    ),
    GetPage(
      name: schedules,
      page: () => ResponsiveMainLayout(),
    ),
    GetPage(
      name: billing,
      page: () => ResponsiveMainLayout(),
    ),
    GetPage(
      name: settings,
      page: () => ResponsiveMainLayout(),
    ),
    GetPage(
      name: quickSearch,
      page: () => QuickSearchScreen(),
    ),
    GetPage(
      name: receipts,
      page: () => ResponsiveMainLayout(),
    ),
    GetPage(
      name: pos,
      page: () => ResponsiveMainLayout(),
    ),
  ];
}
