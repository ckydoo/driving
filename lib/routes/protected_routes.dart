// lib/routes/protected_routes.dart (Updated with School Selection)
import 'package:driving/dashboard.dart';
import 'package:driving/middleware/auth_middleware.dart';
import 'package:driving/middleware/subscription_middleware.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/screens/auth/pin_login_screen.dart';
import 'package:driving/screens/auth/pin_setup_screen.dart';
import 'package:driving/screens/auth/school_selection_screen.dart';
import 'package:driving/screens/auth/school_registration_screen.dart';
import 'package:driving/screens/auth/school_login_screen.dart';
import 'package:driving/widgets/main_layout.dart';
import 'package:get/get.dart';

class ProtectedRoutes {
  // Auth routes
  static const String schoolSelection = '/school-selection';
  static const String schoolRegistration = '/school-registration';
  static const String schoolLogin = '/school-login';
  static const String login = '/login';
  static const String pinLogin = '/pin-login';
  static const String pinSetup = '/pin-setup';
  static const String main = '/main';

  static final routes = [
    // === PUBLIC ROUTES (No authentication required) ===

    // School selection - first screen for multi-school setup
    GetPage(
      name: schoolSelection,
      page: () => const SchoolSelectionScreen(),
    ),

    // New school registration
    GetPage(
      name: schoolRegistration,
      page: () => const SchoolRegistrationScreen(),
    ),

    // Existing school login
    GetPage(
      name: schoolLogin,
      page: () => const SchoolLoginScreen(),
    ),

    // Traditional login (for existing users)
    GetPage(
      name: login,
      page: () => const LoginScreen(),
    ),

    // PIN authentication routes
    GetPage(
      name: pinLogin,
      page: () => const PinLoginScreen(),
    ),

    // === AUTHENTICATED ROUTES ===

    // PIN setup (requires authentication)
    GetPage(
      name: pinSetup,
      page: () => const PinSetupScreen(isInitialSetup: true),
      middlewares: [AuthenticatedMiddleware()],
    ),
    GetPage(
      name: '/dashboard',
      page: () => FixedDashboardScreen(),
      middlewares: [SubscriptionMiddleware()],
    ),
    // PIN setup from settings (after login)
    GetPage(
      name: '/pin-setup-settings',
      page: () => const PinSetupScreen(isInitialSetup: false),
      middlewares: [AuthenticatedMiddleware()],
    ),

    // === MAIN APPLICATION ===

    // ALL protected routes go through the main layout
    GetPage(
      name: main,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthMiddleware(),
        SubscriptionMiddleware()
      ], // Add SubscriptionMiddleware
    ),

    // === FEATURE ROUTES (All redirect to main layout with role checking) ===

    // Dashboard
    GetPage(
      name: '/dashboard',
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthMiddleware(),
        SubscriptionMiddleware()
      ], // Add SubscriptionMiddleware
    ),

    // Student management
    GetPage(
      name: '/students',
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
    ),

    // Instructor management
    GetPage(
      name: '/instructors',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
    ),

    // User management
    GetPage(
      name: '/users',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
    ),

    // Course management
    GetPage(
      name: '/courses',
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
    ),

    // Fleet management
    GetPage(
      name: '/fleet',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
    ),

    // Schedule management
    GetPage(
      name: '/schedules',
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
    ),

    // Billing management
    GetPage(
      name: '/billing',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
    ),

    // Settings
    GetPage(
      name: '/settings',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
    ),

    // Quick search
    GetPage(
      name: '/quick-search',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
    ),

    // Receipts
    GetPage(
      name: '/receipts',
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
    ),

    // Point of Sale
    GetPage(
      name: '/pos',
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
    ),
  ];
}
