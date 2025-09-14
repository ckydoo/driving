// lib/controllers/navigation_controller.dart - FIXED NULL SAFETY VERSION
import 'package:driving/controllers/auth_controller.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class NavigationController extends GetxController {
  var currentPage = 'dashboard'.obs;
  var expandedDropdowns = <String>{}.obs;

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
    '/pos': 'pos',
    '/users': 'users',
    '/financial_reports': 'financial_reports',
    '/user_reports': 'user_reports',
    '/quick-search': 'quick_search',
    '/settings': 'settings',
    '/financial': 'financial_group',
    '/reports': 'reports',
    'alumni': 'alumni',
    '/main': 'dashboard',
  };

  // Get navigation items based on current user's role - SAFE VERSION
  List<NavigationItem> get navigationItems {
    // SAFE: Check authentication and user existence
    if (!authController.isLoggedIn.value ||
        authController.currentUser.value == null) {
      return [];
    }

    // SAFE: Use null-safe navigation here
    final userRole =
        authController.currentUser.value?.role?.toLowerCase() ?? '';

    return allNavigationItems.where((item) {
      return item.requiredRoles.contains(userRole);
    }).toList();
  }

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
      title: 'Courses',
      icon: Icons.book,
      route: '/courses',
      pageKey: 'courses',
      requiredRoles: ['admin', 'instructor'],
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
      title: 'Vehicles',
      icon: Icons.directions_car,
      route: '/fleet',
      pageKey: 'vehicles',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'Schedules',
      icon: Icons.schedule,
      route: '/schedules',
      pageKey: 'schedules',
      requiredRoles: ['admin', 'instructor'],
    ),
    NavigationItem(
      title: 'Billing',
      icon: Icons.attach_money,
      route: '/billing',
      pageKey: 'billing',
      requiredRoles: ['admin', 'instructor'],
    ),
    NavigationItem(
      title: 'Receipts',
      icon: Icons.receipt,
      route: '/receipts',
      pageKey: 'receipts',
      requiredRoles: ['admin', 'instructor'],
    ),
    NavigationItem(
      title: 'POS',
      icon: Icons.point_of_sale,
      route: '/pos',
      pageKey: 'pos',
      requiredRoles: ['admin', 'instructor'],
    ),
    NavigationItem(
      title: 'Financial Reports',
      icon: Icons.assessment,
      route: '/financial_reports',
      pageKey: 'financial_reports',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'User Reports',
      icon: Icons.people_alt,
      route: '/user_reports',
      pageKey: 'user_reports',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'Users',
      icon: Icons.manage_accounts,
      route: '/users',
      pageKey: 'users',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'Quick Search',
      icon: Icons.search,
      route: '/quick-search',
      pageKey: 'quick_search',
      requiredRoles: ['admin', 'instructor'],
    ),
    NavigationItem(
      title: 'Settings',
      icon: Icons.settings,
      route: '/settings',
      pageKey: 'settings',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'Alumni',
      icon: Icons.school_outlined,
      route: '/alumni',
      pageKey: 'alumni',
      requiredRoles: ['admin', 'instructor'],
    ),
  ];

  // SAFE: Navigate to page method
  void navigateToPage(String pageKey) {
    // Check if user is still authenticated
    if (!authController.isLoggedIn.value ||
        authController.currentUser.value == null) {
      // Redirect to login if not authenticated
      Get.offAllNamed('/login');
      return;
    }

    currentPage.value = pageKey;

    // Map page key to route for navigation
    final route = routeToPageKey.entries
        .firstWhere(
          (entry) => entry.value == pageKey,
          orElse: () => const MapEntry('/main', 'dashboard'),
        )
        .key;

    // Navigate to the route if it's different from current
    if (Get.currentRoute != route) {
      Get.toNamed(route);
    }
  }

  // Check if current user has access to a specific page - SAFE VERSION
  bool hasAccessToPage(String pageKey) {
    if (!authController.isLoggedIn.value ||
        authController.currentUser.value == null) {
      return false;
    }

    // SAFE: Use null-safe navigation
    final userRole =
        authController.currentUser.value?.role?.toLowerCase() ?? '';

    // Check in main items
    final item = allNavigationItems.firstWhereOrNull(
      (item) => item.pageKey == pageKey,
    );

    if (item != null) {
      return item.requiredRoles.contains(userRole);
    }

    // Check in dropdown children
    for (final parentItem in allNavigationItems) {
      if (parentItem.children != null) {
        final childItem = parentItem.children!.firstWhereOrNull(
          (child) => child.pageKey == pageKey,
        );
        if (childItem != null) {
          return childItem.requiredRoles.contains(userRole);
        }
      }
    }

    return false;
  }

  // Get current page title safely
  String getCurrentPageTitle() {
    final pageKey = currentPage.value;

    // Find the navigation item
    final item = allNavigationItems.firstWhereOrNull(
      (item) => item.pageKey == pageKey,
    );

    if (item != null) {
      return item.title;
    }

    // Check in dropdown children
    for (final parentItem in allNavigationItems) {
      if (parentItem.children != null) {
        final childItem = parentItem.children!.firstWhereOrNull(
          (child) => child.pageKey == pageKey,
        );
        if (childItem != null) {
          return childItem.title;
        }
      }
    }

    // Default fallback
    return pageKey
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  // SAFE: Toggle dropdown method
  void toggleDropdown(String dropdownKey) {
    if (expandedDropdowns.contains(dropdownKey)) {
      expandedDropdowns.remove(dropdownKey);
    } else {
      expandedDropdowns.add(dropdownKey);
    }
  }

  // SAFE: Check if dropdown is expanded
  bool isDropdownExpanded(String dropdownKey) {
    return expandedDropdowns.contains(dropdownKey);
  }

  // SAFE: Set page from route
  void setPageFromRoute(String route) {
    final pageKey = routeToPageKey[route] ?? 'dashboard';
    currentPage.value = pageKey;
  }

  // SAFE: Get current user role
  String get currentUserRole {
    if (!authController.isLoggedIn.value ||
        authController.currentUser.value == null) {
      return 'guest';
    }
    return authController.currentUser.value?.role?.toLowerCase() ?? 'guest';
  }

  // SAFE: Check if user can access page
  bool canAccessPage(String pageKey) {
    final navigationItem = allNavigationItems.firstWhere(
      (item) => item.pageKey == pageKey,
      orElse: () => NavigationItem(
        title: 'Unknown',
        icon: Icons.error,
        route: '/main',
        pageKey: 'dashboard',
        requiredRoles: ['admin'],
      ),
    );

    final userRole = currentUserRole;
    return navigationItem.requiredRoles.contains(userRole);
  }
}

// Navigation item model
class NavigationItem {
  final String title;
  final IconData icon;
  final String route;
  final String pageKey;
  final List<String> requiredRoles;
  final List<NavigationItem>? children;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.pageKey,
    required this.requiredRoles,
    this.children,
  });
}
