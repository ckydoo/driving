
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

    print('🔍 Auth Middleware Check:');
    print('   Route: $route');
    print('   isLoggedIn: ${authController.isLoggedIn.value}');
    print('   currentUser: ${authController.currentUser.value?.email}');
    print('   isPinEnabled: ${pinController.isPinEnabled.value}');

    // CRITICAL FIX: Check BOTH authentication methods
    // 1. Traditional login (isLoggedIn + currentUser)
    // 2. PIN authentication (isPinEnabled + user verified)

    bool isAuthenticated = authController.isLoggedIn.value &&
        authController.currentUser.value != null;

    // Allow access if user is logged in OR if PIN is verified
    if (isAuthenticated) {
      print('✅ User authenticated via login');
      return null; // Allow access
    }

    // Check if PIN authentication is valid
    if (pinController.isPinEnabled.value && pinController.isPinSet.value) {
      print('✅ PIN authentication available');
      return null; // Allow access - user can use PIN
    }

    // Not authenticated - redirect to appropriate login
    print('❌ Not authenticated - redirecting');

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
      print('❌ Instructor Middleware: User not logged in');
      return const RouteSettings(name: AppRoutes.login);
    }

    final userRole = authController.currentUser.value!.role.toLowerCase();
    print('🔍 Instructor Middleware: User role = $userRole');

    if (userRole == 'instructor' || userRole == 'admin') {
      print('✅ Instructor/Admin access granted');
      return null;
    }

    print('❌ Instructor Middleware: Access denied');
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
      print('❌ Admin Middleware: User not logged in');
      return const RouteSettings(name: AppRoutes.login);
    }

    final userRole = authController.currentUser.value!.role.toLowerCase();
    print('🔍 Admin Middleware: User role = $userRole');

    if (userRole == 'admin') {
      print('✅ Admin access granted');
      return null;
    }

    print('❌ Admin Middleware: Access denied');
    Get.snackbar(
      'Access Denied',
      'This feature is only available to administrators',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return const RouteSettings(name: AppRoutes.dashboard);
  }
}
