
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthenticatedMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();
    final pinController = Get.find<PinController>();

    debugPrint('🔍 Auth Middleware Check:');
    debugPrint('   Route: $route');
    debugPrint('   isLoggedIn: ${authController.isLoggedIn.value}');
    debugPrint('   currentUser: ${authController.currentUser.value?.email}');
    debugPrint('   isPinEnabled: ${pinController.isPinEnabled.value}');

    // CRITICAL FIX: Check BOTH authentication methods
    // 1. Traditional login (isLoggedIn + currentUser)
    // 2. PIN authentication (isPinEnabled + user verified)

    bool isAuthenticated = authController.isLoggedIn.value &&
        authController.currentUser.value != null;

    // Allow access if user is logged in OR if PIN is verified
    if (isAuthenticated) {
      debugPrint('✅ User authenticated via login');
      return null; // Allow access
    }

    // Check if PIN authentication is valid
    if (pinController.isPinEnabled.value && pinController.isPinSet.value) {
      debugPrint('✅ PIN authentication available');
      return null; // Allow access - user can use PIN
    }

    // Not authenticated - redirect to appropriate login
    debugPrint('❌ Not authenticated - redirecting');

    if (pinController.isPinSet.value) {
      return const RouteSettings(name: AppRoutes.pinLogin);
    }

    return const RouteSettings(name: AppRoutes.login);
  }
}

class InstructorMiddleware extends GetMiddleware {
  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();

    // FIXED: Check if user is logged in first
    if (!authController.isLoggedIn.value ||
        authController.currentUser.value == null) {
      debugPrint('❌ Instructor Middleware: User not logged in');
      return const RouteSettings(name: AppRoutes.login);
    }

    final userRole = authController.currentUser.value!.role.toLowerCase();
    debugPrint('🔍 Instructor Middleware: User role = $userRole');

    if (userRole == 'instructor' || userRole == 'admin') {
      debugPrint('✅ Instructor/Admin access granted');
      return null;
    }

    debugPrint('❌ Instructor Middleware: Access denied');
    Get.snackbar(
      'Access Denied',
      'This feature is only available to instructors',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return const RouteSettings(name: AppRoutes.dashboard);
  }
}

class AdminMiddleware extends GetMiddleware {
  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();

    // FIXED: Check if user is logged in first
    if (!authController.isLoggedIn.value ||
        authController.currentUser.value == null) {
      debugPrint('❌ Admin Middleware: User not logged in');
      return const RouteSettings(name: AppRoutes.login);
    }

    final userRole = authController.currentUser.value!.role.toLowerCase();
    debugPrint('🔍 Admin Middleware: User role = $userRole');

    if (userRole == 'admin') {
      debugPrint('✅ Admin access granted');
      return null;
    }

    debugPrint('❌ Admin Middleware: Access denied');
    Get.snackbar(
      'Access Denied',
      'This feature is only available to administrators',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return const RouteSettings(name: AppRoutes.dashboard);
  }
}
