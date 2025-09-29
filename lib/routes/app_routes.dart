// lib/routes/app_routes.dart - FIXED WITH SUBSCRIPTION CHECK
import 'package:driving/main.dart';
import 'package:driving/middleware/auth_middleware.dart';
import 'package:driving/middleware/subscription_guard.dart'; // ADD THIS
import 'package:driving/screens/startup/subscription_check_screen.dart'; // ADD THIS
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/screens/auth/enhanced_pin_login_screen.dart';
import 'package:driving/screens/auth/pin_setup_screen.dart';
import 'package:driving/screens/auth/school_registration_screen.dart';
import 'package:driving/screens/auth/school_selection_screen.dart';
import 'package:driving/screens/subscription/subscription_screen.dart'; // ADD THIS
import 'package:driving/widgets/main_layout.dart';
import 'package:get/get.dart';

class AppRoutes {
  // === ROUTE CONSTANTS ===
  // School Management Routes
  static const String schoolSelection = '/school-selection';
  static const String schoolRegistration = '/school-registration';

  // Authentication flow
  static const String initial = '/';
  static const String login = '/login';
  static const String pinLogin = '/pin-login';
  static const String pinSetup = '/pin-setup';

  // Main application
  static const String main = '/main';
  static const String dashboard = '/dashboard';

  // ADD THIS
  static const String subscription = '/subscription';

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

    // NEW: Initial route now goes through subscription check
    GetPage(
      name: initial,
      page: () => const SubscriptionCheckScreen(nextRoute: '/main'),
    ),

    GetPage(
      name: schoolSelection,
      page: () => const SchoolSelectionScreen(),
    ),

    GetPage(
      name: schoolRegistration,
      page: () => const SchoolRegistrationScreen(),
    ),

    // === AUTHENTICATION ROUTES (No subscription check) ===

    // Traditional email/password login
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // PIN-based login
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

    // === SUBSCRIPTION ROUTES (Always accessible) ===

    GetPage(
      name: subscription,
      page: () => SubscriptionScreen(),
      middlewares: [
        AuthenticatedMiddleware(),
        // NO SubscriptionGuard - must be accessible even when suspended
      ],
      transition: Transition.fadeIn,
    ),

    // === MAIN APPLICATION ROUTES (ALL WITH SUBSCRIPTION CHECK) ===

    // Main application entry point - NOW WITH SUBSCRIPTION GUARD
    GetPage(
      name: main,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),

    // Dashboard - NOW WITH SUBSCRIPTION GUARD
    GetPage(
      name: dashboard,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // === FEATURE ROUTES (All use ResponsiveMainLayout with subscription check) ===

    // Student Management (Instructors & Admins)
    GetPage(
      name: students,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        InstructorMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // Instructor Management (Admins only)
    GetPage(
      name: instructors,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AdminMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // User Management (Admins only)
    GetPage(
      name: users,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AdminMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // Course Management (Instructors & Admins)
    GetPage(
      name: courses,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        InstructorMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // Fleet Management (Admins only)
    GetPage(
      name: fleet,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AdminMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // Schedule Management (Instructors & Admins)
    GetPage(
      name: schedules,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        InstructorMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // Billing Management (Admins only)
    GetPage(
      name: billing,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AdminMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // Settings (All authenticated users)
    GetPage(
      name: settings,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // Quick Search (All authenticated users)
    GetPage(
      name: quickSearch,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // Receipts (Instructors & Admins)
    GetPage(
      name: receipts,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        InstructorMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),

    // Point of Sale (All authenticated users)
    GetPage(
      name: pos,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(), // ADD THIS
      ],
      transition: Transition.noTransition,
    ),
  ];

  // === NAVIGATION HELPERS ===

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

  /// Navigate to main application (goes through subscription check)
  static void toMain() {
    Get.offAllNamed(main);
  }

  /// Navigate to subscription screen
  static void toSubscription() {
    Get.toNamed(subscription);
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
