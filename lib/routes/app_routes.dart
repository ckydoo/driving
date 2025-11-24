import 'package:driving/main.dart';
import 'package:driving/middleware/auth_middleware.dart';
import 'package:driving/middleware/subscription_guard.dart';
import 'package:driving/screens/startup/subscription_check_screen.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/screens/auth/enhanced_pin_login_screen.dart';
import 'package:driving/screens/auth/pin_setup_screen.dart';
import 'package:driving/screens/auth/school_registration_screen.dart';
import 'package:driving/screens/auth/school_selection_screen.dart';
import 'package:driving/widgets/main_layout.dart';
import 'package:get/get.dart';

class AppRoutes {
  static const String schoolSelection = '/school-selection';
  static const String schoolRegistration = '/school-registration';

  static const String initial = '/';
  static const String login = '/login';
  static const String pinLogin = '/pin-login';
  static const String pinSetup = '/pin-setup';

  static const String main = '/main';
  static const String dashboard = '/dashboard';

  static const String subscription = '/subscription';

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

  static final routes = [
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

    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: pinLogin,
      page: () => const EnhancedPinLoginScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: pinSetup,
      page: () => const PinSetupScreen(isInitialSetup: true),
      middlewares: [AuthenticatedMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/pin-setup-settings',
      page: () => const PinSetupScreen(isInitialSetup: false),
      middlewares: [AuthenticatedMiddleware()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: main,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),

    GetPage(
      name: dashboard,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: students,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        InstructorMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: instructors,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AdminMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: users,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AdminMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: courses,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        InstructorMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: fleet,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AdminMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: schedules,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        InstructorMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: billing,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AdminMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: settings,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: quickSearch,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: receipts,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        InstructorMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),

    GetPage(
      name: pos,
      page: () => const ResponsiveMainLayout(),
      middlewares: [
        AuthenticatedMiddleware(),
        SubscriptionGuard(),
      ],
      transition: Transition.noTransition,
    ),
  ];

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
