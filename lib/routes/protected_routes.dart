// lib/routes/protected_routes.dart (Updated with PIN routes)
import 'package:driving/middleware/auth_middleware.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/screens/auth/pin_login_screen.dart';
import 'package:driving/screens/auth/pin_setup_screen.dart';
import 'package:driving/widgets/main_layout.dart';
import 'package:get/get.dart';

class ProtectedRoutes {
  static const String login = '/login';
  static const String pinLogin = '/pin-login';
  static const String pinSetup = '/pin-setup';
  static const String main = '/main';

  static final routes = [
    // Public routes (no authentication required)
    GetPage(
      name: login,
      page: () => const LoginScreen(),
    ),

    // PIN authentication routes
    GetPage(
      name: pinLogin,
      page: () => const PinLoginScreen(),
    ),

    GetPage(
      name: pinSetup,
      page: () => const PinSetupScreen(isInitialSetup: true),
    ),

    // PIN setup from settings (after login)
    GetPage(
      name: '/pin-setup-settings',
      page: () => const PinSetupScreen(isInitialSetup: false),
      middlewares: [AuthenticatedMiddleware()],
    ),

    // ALL protected routes go through the main layout
    GetPage(
      name: main,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
    ),

    // Alternative routes that redirect to main layout
    GetPage(
      name: '/dashboard',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
    ),

    GetPage(
      name: '/students',
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
    ),

    GetPage(
      name: '/instructors',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
    ),

    GetPage(
      name: '/users',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
    ),

    GetPage(
      name: '/courses',
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
    ),

    GetPage(
      name: '/fleet',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
    ),

    GetPage(
      name: '/schedules',
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
    ),

    GetPage(
      name: '/billing',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
    ),

    GetPage(
      name: '/receipts',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
    ),

    GetPage(
      name: '/settings',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
    ),

    GetPage(
      name: '/quick-search',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
    ),

    GetPage(
      name: '/pos',
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
    ),
  ];
}

// Helper class to define access levels for different features
class AccessControl {
  static const Map<String, List<String>> featureAccess = {
    'dashboard': ['admin', 'instructor', 'student'],
    'students': ['admin', 'instructor'],
    'instructors': ['admin'],
    'users': ['admin'],
    'courses': ['admin', 'instructor'],
    'fleet': ['admin'],
    'schedules': ['admin', 'instructor'],
    'pos': ['admin', 'instructor'],
    'billing': ['admin'],
    'receipts': ['admin'],
    'settings': ['admin', 'instructor', 'student'],
    'quick_search': ['admin', 'instructor', 'student'],
  };

  static bool hasAccess(String userRole, String feature) {
    final allowedRoles = featureAccess[feature] ?? [];
    return allowedRoles.contains(userRole.toLowerCase());
  }

  static List<String> getAccessibleFeatures(String userRole) {
    List<String> accessible = [];
    featureAccess.forEach((feature, roles) {
      if (roles.contains(userRole.toLowerCase())) {
        accessible.add(feature);
      }
    });
    return accessible;
  }
}
