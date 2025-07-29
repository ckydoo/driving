// lib/routes/protected_routes.dart
import 'package:driving/middleware/auth_middleware.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/widgets/main_layout.dart';
import 'package:get/get.dart';

class ProtectedRoutes {
  static const String login = '/login';
  static const String main = '/main';

  static final routes = [
    // Public routes (no authentication required)
    GetPage(
      name: login,
      page: () => const LoginScreen(),
    ),

    // ALL protected routes go through the main layout
    // The main layout will handle showing the correct content based on navigation state
    GetPage(
      name: main,
      page: () => const CompleteMainLayout(),
      middlewares: [AuthenticatedMiddleware()], // All authenticated users
    ),

    // Alternative routes that redirect to main layout
    GetPage(
      name: '/dashboard',
      page: () => const CompleteMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
    ),

    GetPage(
      name: '/students',
      page: () => const CompleteMainLayout(),
      middlewares: [InstructorMiddleware()], // Admin + Instructor
    ),

    GetPage(
      name: '/instructors',
      page: () => const CompleteMainLayout(),
      middlewares: [AdminMiddleware()], // Admin only
    ),

    GetPage(
      name: '/users',
      page: () => const CompleteMainLayout(),
      middlewares: [AdminMiddleware()], // Admin only
    ),

    GetPage(
      name: '/courses',
      page: () => const CompleteMainLayout(),
      middlewares: [InstructorMiddleware()], // Admin + Instructor
    ),

    GetPage(
      name: '/fleet',
      page: () => const CompleteMainLayout(),
      middlewares: [AdminMiddleware()], // Admin only
    ),

    GetPage(
      name: '/schedules',
      page: () => const CompleteMainLayout(),
      middlewares: [InstructorMiddleware()], // Admin + Instructor
    ),

    GetPage(
      name: '/billing',
      page: () => const CompleteMainLayout(),
      middlewares: [AdminMiddleware()], // Admin only
    ),

    GetPage(
      name: '/receipts',
      page: () => const CompleteMainLayout(),
      middlewares: [AdminMiddleware()], // Admin only
    ),

    GetPage(
      name: '/settings',
      page: () => const CompleteMainLayout(),
      middlewares: [AuthenticatedMiddleware()], // All authenticated users
    ),

    GetPage(
      name: '/quick-search',
      page: () => const CompleteMainLayout(),
      middlewares: [AuthenticatedMiddleware()], // All authenticated users
    ),
  ];
}

// Helper class to define access levels for different features
class AccessControl {
  // Define which roles can access which features
  static const Map<String, List<String>> featureAccess = {
    'dashboard': ['admin', 'instructor', 'student'],
    'students': ['admin', 'instructor'],
    'instructors': ['admin'],
    'users': ['admin'],
    'courses': ['admin', 'instructor'],
    'fleet': ['admin'],
    'schedules': ['admin', 'instructor'],
    'billing': ['admin'],
    'receipts': ['admin'],
    'settings': ['admin', 'instructor', 'student'],
    'quick_search': ['admin', 'instructor', 'student'],
  };

  // Check if user has access to a feature
  static bool hasAccess(String userRole, String feature) {
    final allowedRoles = featureAccess[feature] ?? [];
    return allowedRoles.contains(userRole.toLowerCase());
  }

  // Get accessible features for a role
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
