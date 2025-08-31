// lib/routes/app_routes.dart - Complete routing system
import 'package:driving/main.dart';
import 'package:driving/middleware/auth_middleware.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/screens/auth/enhanced_pin_login_screen.dart';
import 'package:driving/screens/auth/pin_setup_screen.dart';
import 'package:driving/screens/auth/school_selection_screen.dart';
import 'package:driving/screens/auth/school_registration_screen.dart';
import 'package:driving/screens/auth/school_login_screen.dart';
import 'package:driving/screens/subscription/subscription_screen.dart';
import 'package:driving/widgets/main_layout.dart';
import 'package:get/get.dart';

class AppRoutes {
  // === ROUTE CONSTANTS ===

  // Authentication flow
  static const String initial = '/';
  static const String schoolSelection = '/school-selection';
  static const String schoolRegistration = '/school-registration';
  static const String schoolLogin = '/school-login';
  static const String login = '/login';
  static const String pinLogin = '/pin-login';
  static const String pinSetup = '/pin-setup';

  // Main application
  static const String main = '/main';
  static const String dashboard = '/dashboard';

  // Feature routes
  static const String students = '/students';
  static const String instructors = '/instructors';
  static const String users = '/users';
  static const String courses = '/courses';
  static const String fleet = '/fleet';
  static const String schedules = '/schedules';
  static const String billing = '/billing';
  static const String settings = '/settings';
  static const String quickSearch = '/quick-search';
  static const String receipts = '/receipts';
  static const String pos = '/pos';

  // === ROUTE DEFINITIONS ===

  static final routes = [
    // === INITIALIZATION & SCHOOL SELECTION ===

    // Initial loading screen
    GetPage(
      name: initial,
      page: () => const AuthenticationWrapper(), // Your existing loading screen
    ),
    GetPage(name: '/subscription', page: () => SubscriptionScreen()),

    // School selection - entry point for multi-school setup
    GetPage(
      name: schoolSelection,
      page: () => const SchoolSelectionScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // === SCHOOL SETUP ROUTES ===

    // New school registration
    GetPage(
      name: schoolRegistration,
      page: () => const SchoolRegistrationScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Existing school login
    GetPage(
      name: schoolLogin,
      page: () => const SchoolLoginScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // === AUTHENTICATION ROUTES ===

    // Traditional email/password login
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // PIN-based login (enhanced with school context)
    GetPage(
      name: pinLogin,
      page: () => const EnhancedPinLoginScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // === PIN SETUP ROUTES ===

    // PIN setup after first login
    GetPage(
      name: pinSetup,
      page: () => const PinSetupScreen(isInitialSetup: true),
      middlewares: [AuthenticatedMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // PIN setup from settings
    GetPage(
      name: '/pin-setup-settings',
      page: () => const PinSetupScreen(isInitialSetup: false),
      middlewares: [AuthenticatedMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // === MAIN APPLICATION ROUTES ===

    // Main application entry point
    GetPage(
      name: main,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),

    // Dashboard
    GetPage(
      name: dashboard,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
      transition: Transition.noTransition,
    ),

    // === FEATURE ROUTES (All use main layout with role checking) ===

    // Student Management (Instructors & Admins)
    GetPage(
      name: students,
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
      transition: Transition.noTransition,
    ),

    // Instructor Management (Admins only)
    GetPage(
      name: instructors,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
      transition: Transition.noTransition,
    ),

    // User Management (Admins only)
    GetPage(
      name: users,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
      transition: Transition.noTransition,
    ),

    // Course Management (Instructors & Admins)
    GetPage(
      name: courses,
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
      transition: Transition.noTransition,
    ),

    // Fleet Management (Admins only)
    GetPage(
      name: fleet,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
      transition: Transition.noTransition,
    ),

    // Schedule Management (Instructors & Admins)
    GetPage(
      name: schedules,
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
      transition: Transition.noTransition,
    ),

    // Billing Management (Admins only)
    GetPage(
      name: billing,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AdminMiddleware()],
      transition: Transition.noTransition,
    ),

    // Settings (All authenticated users)
    GetPage(
      name: settings,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
      transition: Transition.noTransition,
    ),

    // Quick Search (All authenticated users)
    GetPage(
      name: quickSearch,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
      transition: Transition.noTransition,
    ),

    // Receipts (Instructors & Admins)
    GetPage(
      name: receipts,
      page: () => const ResponsiveMainLayout(),
      middlewares: [InstructorMiddleware()],
      transition: Transition.noTransition,
    ),

    // Point of Sale (All authenticated users)
    GetPage(
      name: pos,
      page: () => const ResponsiveMainLayout(),
      middlewares: [AuthenticatedMiddleware()],
      transition: Transition.noTransition,
    ),
  ];

  // === NAVIGATION HELPERS ===

  /// Navigate to school selection
  static void toSchoolSelection() {
    Get.offAllNamed(schoolSelection);
  }

  /// Navigate to school registration
  static void toSchoolRegistration() {
    Get.toNamed(schoolRegistration);
  }

  /// Navigate to existing school login
  static void toSchoolLogin() {
    Get.toNamed(schoolLogin);
  }

  /// Navigate to traditional login
  static void toLogin() {
    Get.offAllNamed(login);
  }

  /// Navigate to PIN login
  static void toPinLogin() {
    Get.offAllNamed(pinLogin);
  }

  /// Navigate to PIN setup
  static void toPinSetup({bool isInitialSetup = true}) {
    if (isInitialSetup) {
      Get.offAllNamed(pinSetup);
    } else {
      Get.toNamed('/pin-setup-settings');
    }
  }

  /// Navigate to main application
  static void toMain() {
    Get.offAllNamed(main);
  }

  /// Navigate to specific feature
  static void toFeature(String feature) {
    Get.toNamed('/$feature');
  }

  /// Get the current route name
  static String get currentRoute => Get.currentRoute;

  /// Check if currently on authentication flow
  static bool get isOnAuthFlow {
    final authRoutes = [
      schoolSelection,
      schoolRegistration,
      schoolLogin,
      login,
      pinLogin,
      pinSetup,
    ];
    return authRoutes.contains(currentRoute);
  }

  /// Check if currently on main application
  static bool get isOnMainApp {
    return currentRoute.startsWith('/') && !isOnAuthFlow;
  }
}
