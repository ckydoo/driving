// lib/controllers/navigation_controller.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class NavigationController extends GetxController {
  var currentPage = 'dashboard'.obs;
  var currentUser = Rxn<Map<String, String>>();

  final List<NavigationItem> navigationItems = [
    NavigationItem(
      title: 'Dashboard',
      icon: Icons.dashboard,
      route: '/dashboard',
    ),
    NavigationItem(
      title: 'Students',
      icon: Icons.people,
      route: '/students',
    ),
    NavigationItem(
      title: 'Schedule',
      icon: Icons.calendar_today,
      route: '/schedule',
    ),
    NavigationItem(
      title: 'Billing',
      icon: Icons.account_balance_wallet,
      route: '/billing',
    ),
    NavigationItem(
      title: 'Receipts', // New item
      icon: Icons.receipt_long,
      route: '/receipts',
    ),
    // ...other existing items...
  ];

  @override
  void onInit() {
    super.onInit();
    // Initialize with mock user data
    currentUser.value = {
      'name': 'Admin User',
      'email': 'admin@drivingschool.com',
      'role': 'Administrator',
    };
  }

  void navigateToPage(String page) {
    currentPage.value = page;
  }

  void logout() {
    // Clear user data
    currentUser.value = null;
    currentPage.value = 'login';

    // Clear all stored data if needed
    // Get.delete<UserController>();
    // Get.delete<CourseController>();
    // etc.

    // Navigate to login screen
    Get.offAllNamed('/login');
  }

  String getCurrentPageTitle() {
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
      case 'reports':
        return 'Reports';
      case 'settings':
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }
}

class NavigationItem {
  final String title;
  final IconData icon;
  final String route;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.route,
  });
}
