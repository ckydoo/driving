// lib/controllers/navigation_controller.dart
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/routes/protected_routes.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class NavigationController extends GetxController {
  var currentPage = 'dashboard'.obs;

  // Get current user from AuthController
  AuthController get authController => Get.find<AuthController>();

  // Map routes to page keys for consistent navigation
  final Map<String, String> routeToPageKey = {
    '/dashboard': 'dashboard',
    '/students': 'students',
    '/instructors': 'instructors',
    '/courses': 'courses',
    '/fleet': 'vehicles',
    '/schedules': 'schedules',
    '/billing': 'billing',
    '/receipts': 'receipts',
    '/users': 'users',
    '/quick-search': 'quick_search',
    '/settings': 'settings',
    '/main': 'dashboard',
  };

  // Define all navigation items with their required roles
  final List<NavigationItem> allNavigationItems = [
    NavigationItem(
      title: 'Dashboard',
      icon: Icons.dashboard,
      route: '/dashboard',
      pageKey: 'dashboard',
      requiredRoles: ['admin', 'instructor', 'student'],
    ),
    NavigationItem(
      title: 'Students',
      icon: Icons.people,
      route: '/students',
      pageKey: 'students',
      requiredRoles: ['admin', 'instructor'],
    ),
    NavigationItem(
      title: 'Instructors',
      icon: Icons.person,
      route: '/instructors',
      pageKey: 'instructors',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'Courses',
      icon: Icons.book,
      route: '/courses',
      pageKey: 'courses',
      requiredRoles: ['admin', 'instructor'],
    ),
    NavigationItem(
      title: 'Vehicles',
      icon: Icons.directions_car,
      route: '/fleet',
      pageKey: 'vehicles',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'Billing',
      icon: Icons.account_balance_wallet,
      route: '/billing',
      pageKey: 'billing',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'Receipts',
      icon: Icons.receipt_long,
      route: '/receipts',
      pageKey: 'receipts',
      requiredRoles: ['admin', 'instructor', 'student'],
    ),
    NavigationItem(
      title: 'Schedule',
      icon: Icons.calendar_today,
      route: '/schedules',
      pageKey: 'schedules',
      requiredRoles: ['admin', 'instructor', 'student'],
    ),
    NavigationItem(
      title: 'Users',
      icon: Icons.admin_panel_settings,
      route: '/users',
      pageKey: 'users',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'Settings',
      icon: Icons.settings,
      route: '/settings',
      pageKey: 'settings',
      requiredRoles: ['admin', 'instructor', 'student'],
    ),
  ];

  // Get navigation items based on current user's role
  List<NavigationItem> get navigationItems {
    if (!authController.isLoggedIn.value ||
        authController.currentUser.value == null) {
      return [];
    }

    final userRole = authController.currentUser.value!.role.toLowerCase();

    return allNavigationItems.where((item) {
      return item.requiredRoles.contains(userRole);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();

    // Listen to authentication state changes
    ever(authController.isLoggedIn, (bool loggedIn) {
      if (!loggedIn) {
        currentPage.value = 'login';
      } else {
        // Reset to dashboard when user logs in
        currentPage.value = 'dashboard';
      }
    });

    // Set initial page to dashboard for authenticated users
    if (authController.isLoggedIn.value) {
      currentPage.value = 'dashboard';
    }
  }

  // Navigate to page with role checking
  void navigateToPage(String pageKey) {
    if (!authController.isLoggedIn.value) {
      Get.offAllNamed('/login');
      return;
    }

    // Check if user has access to this page
    if (!hasAccessToPage(pageKey)) {
      Get.snackbar(
        'Access Denied',
        'You do not have permission to access this page',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.block, color: Colors.white),
      );
      return;
    }

    // Update current page - this will trigger the UI to update
    currentPage.value = pageKey;

    // No need to navigate to different routes since we're staying in the main layout
    // The main layout will handle showing the correct content based on currentPage
  }

  // Navigate directly by route (for external calls)
  void navigateToRoute(String route) {
    final pageKey = routeToPageKey[route];
    if (pageKey != null) {
      navigateToPage(pageKey);
    }
  }

  // Check if current user has access to a specific page
  bool hasAccessToPage(String pageKey) {
    if (!authController.isLoggedIn.value ||
        authController.currentUser.value == null) {
      return false;
    }

    final userRole = authController.currentUser.value!.role.toLowerCase();
    final item = allNavigationItems.firstWhereOrNull(
      (item) => item.pageKey == pageKey,
    );

    if (item == null) return false;

    return item.requiredRoles.contains(userRole);
  }

  // Logout with proper cleanup
  Future<void> logout() async {
    try {
      await authController.logout();
      currentPage.value = 'login';
      Get.offAllNamed('/login');
    } catch (e) {
      print('Error during logout: $e');
      Get.snackbar(
        'Error',
        'Failed to logout properly',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Get current page title
  String getCurrentPageTitle() {
    final item = allNavigationItems.firstWhereOrNull(
      (item) => item.pageKey == currentPage.value,
    );

    if (item != null) {
      return item.title;
    }

    // Fallback titles for custom pages
    switch (currentPage.value) {
      case 'dashboard':
        return 'Dashboard';
      case 'courses':
        return 'Course Management';
      case 'quick_search':
        return 'Quick Search & Overview';
      case 'students':
        return 'Student Management';
      case 'instructors':
        return 'Instructor Management';
      case 'vehicles':
        return 'Vehicle Management';
      case 'receipts':
        return 'Receipts Management';
      case 'billing':
        return 'Payments & Invoices';
      case 'schedules':
        return 'Schedule Management';
      case 'users':
        return 'User Management';
      case 'settings':
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }

  // Get user info for display
  String get currentUserName {
    return authController.currentUserName;
  }

  String get currentUserRole {
    return authController.currentUserRole;
  }

  String get currentUserEmail {
    return authController.currentUser.value?.email ?? 'No Email';
  }

  // Get role badge color
  Color getRoleBadgeColor() {
    final role = authController.currentUserRole.toLowerCase();
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'instructor':
        return Colors.blue;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class NavigationItem {
  final String title;
  final IconData icon;
  final String route;
  final String pageKey;
  final List<String> requiredRoles;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.pageKey,
    required this.requiredRoles,
  });
}
