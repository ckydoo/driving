// lib/middleware/auth_middleware.dart
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();

    // If user is not logged in, redirect to login
    if (!authController.isLoggedIn.value) {
      return const RouteSettings(name: '/login');
    }

    return null;
  }

  @override
  GetPage? onPageCalled(GetPage? page) {
    final authController = Get.find<AuthController>();

    // If user is not logged in and trying to access protected route
    if (!authController.isLoggedIn.value && page?.name != '/login') {
      return GetPage(
        name: '/login',
        page: () => const LoginScreen(),
      );
    }

    return page;
  }
}

// Role-based middleware
class RoleMiddleware extends GetMiddleware {
  final List<String> allowedRoles;

  RoleMiddleware({required this.allowedRoles});

  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();

    // Check if user is logged in
    if (!authController.isLoggedIn.value) {
      return const RouteSettings(name: '/login');
    }

    // Check if user has required role
    if (!authController.hasAnyRole(allowedRoles)) {
      Get.snackbar(
        'Access Denied',
        'You do not have permission to access this page',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return const RouteSettings(name: '/dashboard');
    }

    return null;
  }
}

// Admin-only middleware
class AdminMiddleware extends RoleMiddleware {
  AdminMiddleware() : super(allowedRoles: ['admin']);
}

// Instructor and Admin middleware
class InstructorMiddleware extends RoleMiddleware {
  InstructorMiddleware() : super(allowedRoles: ['admin', 'instructor']);
}

// All roles middleware (just authentication check)
class AuthenticatedMiddleware extends RoleMiddleware {
  AuthenticatedMiddleware()
      : super(allowedRoles: ['admin', 'instructor', 'student']);
}
