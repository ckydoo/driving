// lib/middleware/auth_middleware.dart - COMPLETELY FIXED VERSION
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    try {
      final authController = Get.find<AuthController>();

      // Check only local authentication (Firebase removed)
      final isAuthenticated = authController.isLoggedIn.value;

      print('🔐 Auth Middleware Check:');
      print('   Route: $route');
      print('   Local Auth: ${authController.isLoggedIn.value}');
      print('   Final Decision: ${isAuthenticated ? "ALLOW" : "REDIRECT"}');

      // If user is not authenticated, redirect to login
      if (!isAuthenticated) {
        return const RouteSettings(name: '/login');
      }

      return null; // Allow access
    } catch (e) {
      print('❌ Auth Middleware Error: $e');
      // If there's an error accessing auth controller, redirect to login
      return const RouteSettings(name: '/login');
    }
  }

  @override
  GetPage? onPageCalled(GetPage? page) {
    try {
      final authController = Get.find<AuthController>();

      // Check only local authentication (Firebase removed)
      final isAuthenticated = authController.isLoggedIn.value;

      // If user is not authenticated and trying to access protected route
      if (!isAuthenticated && page?.name != '/login') {
        print('🚫 Blocking access to ${page?.name} - not authenticated');
        return GetPage(
          name: '/login',
          page: () => const LoginScreen(),
        );
      }

      return page;
    } catch (e) {
      print('❌ Auth Middleware onPageCalled Error: $e');
      return GetPage(
        name: '/login',
        page: () => const LoginScreen(),
      );
    }
  }
}

// Updated Role-based middleware - FIXED NULL SAFETY
class RoleMiddleware extends GetMiddleware {
  final List<String> allowedRoles;

  RoleMiddleware({required this.allowedRoles});

  @override
  RouteSettings? redirect(String? route) {
    try {
      final authController = Get.find<AuthController>();

      // Check local authentication only
      final isAuthenticated = authController.isLoggedIn.value;

      if (!isAuthenticated) {
        print(
            '🚫 Role Middleware: User not authenticated, redirecting to login');
        return const RouteSettings(name: '/login');
      }

      // Check user role - FIXED: Use safe null-aware access
      if (authController.currentUser.value != null) {
        // FIXED: Replace ! with safe null-aware operator
        final userRole =
            authController.currentUser.value?.role?.toLowerCase() ?? 'guest';
        final hasRequiredRole =
            allowedRoles.any((role) => role.toLowerCase() == userRole);

        if (!hasRequiredRole) {
          print(
              '🚫 Role Middleware: Access denied for role "$userRole" to route $route');
          Get.snackbar(
            snackPosition: SnackPosition.BOTTOM,
            'Access Denied',
            'You do not have permission to access this page',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return const RouteSettings(name: '/main'); // Redirect to main
        }
      } else {
        print(
            '⚠️ Role Middleware: User object not available, redirecting to login');
        return const RouteSettings(name: '/login');
      }

      return null;
    } catch (e) {
      print('❌ Role Middleware Error: $e');
      return const RouteSettings(name: '/login');
    }
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
