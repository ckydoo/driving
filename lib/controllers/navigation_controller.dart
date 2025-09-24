// lib/controllers/navigation_controller.dart - Fix null check operators

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

  // Get navigation items based on current user's role
  List<NavigationItem> get navigationItems {
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
      icon: Icons.payment,
      route: '/pos',
      pageKey: 'pos',
      requiredRoles: ['admin', 'instructor'],
    ),
    NavigationItem(
      title: 'Users',
      icon: Icons.people,
      route: '/users',
      pageKey: 'users',
      requiredRoles: ['admin'],
    ),
    NavigationItem(
      title: 'Alumni',
      icon: Icons.school,
      route: '/alumni',
      pageKey: 'alumni',
      requiredRoles: ['admin', 'instructor'],
    ),
    NavigationItem(
      title: 'Quick Search',
      icon: Icons.search,
      route: '/quick-search',
      pageKey: 'quick_search',
      requiredRoles: ['admin', 'instructor', 'student'],
    ),
    NavigationItem(
      title: 'Reports',
      icon: Icons.bar_chart,
      route: '/reports',
      pageKey: 'reports',
      requiredRoles: [
        'admin',
        'instructor',
      ],
      isDropdown: true,
      children: [
        NavigationItem(
          title: 'Financial Reports',
          icon: Icons.pie_chart,
          route: '/financial_reports',
          pageKey: 'financial_reports',
          requiredRoles: ['admin'],
        ),
        NavigationItem(
          title: 'User Reports',
          icon: Icons.person_search,
          route: '/user_reports',
          pageKey: 'user_reports',
          requiredRoles: ['admin'],
        ),
      ],
    ),
    NavigationItem(
      title: 'Settings',
      icon: Icons.settings,
      route: '/settings',
      pageKey: 'settings',
      requiredRoles: ['admin', 'instructor', 'student'],
    ),
  ];

  // Toggle dropdown expansion
  void toggleDropdown(String pageKey) {
    if (expandedDropdowns.contains(pageKey)) {
      expandedDropdowns.remove(pageKey);
    } else {
      expandedDropdowns.add(pageKey);
    }
  }

  // Check if dropdown is expanded
  bool isDropdownExpanded(String pageKey) {
    return expandedDropdowns.contains(pageKey);
  }

  @override
  void onInit() {
    super.onInit();

    // Listen to authentication state changes
    ever(authController.isLoggedIn, (bool loggedIn) {
      if (!loggedIn) {
        currentPage.value = 'login';
        expandedDropdowns.clear();
      } else {
        currentPage.value = 'dashboard';
      }
    });

    // Set initial page to dashboard for authenticated users
    if (authController.isLoggedIn.value) {
      currentPage.value = 'dashboard';
    }
  }

  // Navigate to page with role checking - SAFE VERSION
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
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        icon: const Icon(Icons.block, color: Colors.white),
      );
      return;
    }

    // Update current page
    currentPage.value = pageKey;

    // Auto-expand parent dropdown if navigating to a child page
    _autoExpandParentDropdown(pageKey);
  }

  // Auto-expand parent dropdown when navigating to child page
  void _autoExpandParentDropdown(String childPageKey) {
    for (final item in allNavigationItems) {
      if (item.isDropdown && item.children != null) {
        final hasChild =
            item.children!.any((child) => child.pageKey == childPageKey);
        if (hasChild && !expandedDropdowns.contains(item.pageKey)) {
          expandedDropdowns.add(item.pageKey);
        }
      }
    }
  }

  // Navigate directly by route (for external calls)
  void navigateToRoute(String route) {
    final pageKey = routeToPageKey[route];
    if (pageKey != null) {
      navigateToPage(pageKey);
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

  // Logout with proper cleanup
  Future<void> logout() async {
    try {
      await authController.signOut();
      currentPage.value = 'login';
      expandedDropdowns.clear();
      Get.offAllNamed('/login');
    } catch (e) {
      print('Error during logout: $e');
      Get.snackbar(
        'Logout Error',
        'An error occurred during logout.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

// NavigationItem class
class NavigationItem {
  final String title;
  final IconData icon;
  final String route;
  final String pageKey;
  final List<String> requiredRoles;
  final bool isDropdown;
  final List<NavigationItem>? children;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.pageKey,
    required this.requiredRoles,
    this.isDropdown = false,
    this.children,
  });
}
