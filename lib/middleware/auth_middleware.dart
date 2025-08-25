// lib/middleware/auth_middleware.dart - Updated for Firebase-First authentication
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    try {
      final authController = Get.find<AuthController>();

      // For Firebase-first: Check both local and Firebase authentication
      final isAuthenticated = authController.isLoggedIn.value ||
          authController.isFirebaseAuthenticated;

      print('🔐 Auth Middleware Check:');
      print('   Route: $route');
      print('   Local Auth: ${authController.isLoggedIn.value}');
      print('   Firebase Auth: ${authController.isFirebaseAuthenticated}');
      print('   Final Decision: ${isAuthenticated ? "ALLOW" : "REDIRECT"}');

      // If user is not authenticated at all, redirect to login
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

      // For Firebase-first: Check both local and Firebase authentication
      final isAuthenticated = authController.isLoggedIn.value ||
          authController.isFirebaseAuthenticated;

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

// Updated Role-based middleware
class RoleMiddleware extends GetMiddleware {
  final List<String> allowedRoles;

  RoleMiddleware({required this.allowedRoles});

  @override
  RouteSettings? redirect(String? route) {
    try {
      final authController = Get.find<AuthController>();

      // Check authentication first (Firebase-first compatible)
      final isAuthenticated = authController.isLoggedIn.value ||
          authController.isFirebaseAuthenticated;

      if (!isAuthenticated) {
        print(
            '🚫 Role Middleware: User not authenticated, redirecting to login');
        return const RouteSettings(name: '/login');
      }

      // If Firebase authenticated but not locally authenticated, wait for sync
      if (authController.isFirebaseAuthenticated &&
          !authController.isLoggedIn.value) {
        print(
            '⏳ Role Middleware: Firebase user found, waiting for local sync...');
        // Give some time for user data to sync from Firebase
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!authController.isLoggedIn.value) {
            print(
                '⚠️ Local sync timeout, but allowing access with Firebase auth');
          }
        });
        // Allow access for now - Firebase user is authenticated
        return null;
      }

      // Check user role
      if (authController.currentUser.value != null) {
        final userRole = authController.currentUser.value!.role.toLowerCase();
        final hasRequiredRole =
            allowedRoles.any((role) => role.toLowerCase() == userRole);

        if (!hasRequiredRole) {
          print(
              '🚫 Role Middleware: Access denied for role "$userRole" to route $route');
          Get.snackbar(
            'Access Denied',
            'You do not have permission to access this page',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return const RouteSettings(
              name: '/main'); // Redirect to main instead of dashboard
        }
      } else {
        print('⚠️ Role Middleware: User object not available, allowing access');
        // If user object not available but Firebase authenticated, allow access
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
