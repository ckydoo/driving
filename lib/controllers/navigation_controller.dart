import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class NavigationController extends GetxController {
  var currentPage = 'dashboard'.obs;
  var expandedDropdowns = <String>{}.obs;
  final selectedCourseId = RxnInt();
  final selectedFleetId = RxnInt();
  final selectedStudentId = RxnInt();
  final selectedInstructorId = RxnInt();
  final selectedInvoiceStudent = Rxn<User>();
  final selectedScheduleStudent = Rxn<User>();
  final selectedAddUserRole = 'student'.obs;
  final selectedGraduationStudent = Rxn<User>();

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
    '/subscription': 'subscription',
    '/sync': 'sync',
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

  void openCourseDetails(int courseId) {
    selectedCourseId.value = courseId;
    navigateToPage('course_details');
  }

  void closeCourseDetails() {
    selectedCourseId.value = null;
    navigateToPage('courses');
  }

  void openFleetDetails(int fleetId) {
    selectedFleetId.value = fleetId;
    navigateToPage('fleet_details');
  }

  void closeFleetDetails() {
    selectedFleetId.value = null;
    navigateToPage('vehicles');
  }

  void openStudentDetails(int studentId) {
    selectedStudentId.value = studentId;
    navigateToPage('student_details');
  }

  void closeStudentDetails() {
    selectedStudentId.value = null;
    navigateToPage('students');
  }

  void openInstructorDetails(int instructorId) {
    selectedInstructorId.value = instructorId;
    navigateToPage('instructor_details');
  }

  void closeInstructorDetails() {
    selectedInstructorId.value = null;
    navigateToPage('instructors');
  }

  void openStudentInvoice(User student) {
    selectedInvoiceStudent.value = student;
    navigateToPage('student_invoice');
  }

  void closeStudentInvoice() {
    selectedInvoiceStudent.value = null;
    navigateToPage('billing');
  }

  void openProfile() {
    navigateToPage('profile');
  }

  void closeProfile() {
    navigateToPage('dashboard');
  }

  void openScheduleBooking({User? student}) {
    selectedScheduleStudent.value = student;
    navigateToPage('schedule_booking');
  }

  void closeScheduleBooking() {
    selectedScheduleStudent.value = null;
    navigateToPage('schedules');
  }

  void openRecurringSchedule() {
    navigateToPage('recurring_schedule');
  }

  void closeRecurringSchedule() {
    navigateToPage('schedules');
  }

  void openAddUser(String role) {
    selectedAddUserRole.value = role;
    navigateToPage('add_user');
  }

  void closeAddUser() {
    final role = selectedAddUserRole.value.toLowerCase();
    if (role == 'instructor') {
      navigateToPage('instructors');
      return;
    }
    if (role == 'admin') {
      navigateToPage('users');
      return;
    }
    navigateToPage('students');
  }

  void openBulkStudentUpload() {
    navigateToPage('bulk_student_upload');
  }

  void closeBulkStudentUpload() {
    navigateToPage('students');
  }

  void openStudentGraduation(User student) {
    selectedGraduationStudent.value = student;
    navigateToPage('student_graduation');
  }

  void closeStudentGraduation() {
    selectedGraduationStudent.value = null;
    navigateToPage('students');
  }

  // Check if current user has access to a specific page - SAFE VERSION
  bool hasAccessToPage(String pageKey) {
    if (!authController.isLoggedIn.value ||
        authController.currentUser.value == null) {
      return false;
    }

    if (pageKey == 'course_details') {
      return hasAccessToPage('courses');
    }
    if (pageKey == 'fleet_details') {
      return hasAccessToPage('vehicles');
    }
    if (pageKey == 'student_details') {
      return hasAccessToPage('students');
    }
    if (pageKey == 'instructor_details') {
      return hasAccessToPage('instructors');
    }
    if (pageKey == 'student_invoice') {
      return hasAccessToPage('billing');
    }
    if (pageKey == 'profile') {
      return hasAccessToPage('settings');
    }
    if (pageKey == 'schedule_booking') {
      return hasAccessToPage('schedules');
    }
    if (pageKey == 'recurring_schedule') {
      return hasAccessToPage('schedules');
    }
    if (pageKey == 'add_user') {
      final role = selectedAddUserRole.value.toLowerCase();
      if (role == 'instructor') {
        return hasAccessToPage('instructors');
      }
      if (role == 'admin') {
        return hasAccessToPage('users');
      }
      return hasAccessToPage('students');
    }
    if (pageKey == 'bulk_student_upload') {
      return hasAccessToPage('students');
    }
    if (pageKey == 'student_graduation') {
      return hasAccessToPage('students');
    }
    if (pageKey == 'sync') {
      return authController.hasAnyRole(['admin', 'instructor']);
    }
    if (pageKey == 'subscription') {
      return authController.hasAnyRole(['admin', 'instructor']);
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

    if (pageKey == 'course_details') {
      return 'Course Details';
    }
    if (pageKey == 'fleet_details') {
      return 'Vehicle Details';
    }
    if (pageKey == 'student_details') {
      return 'Student Details';
    }
    if (pageKey == 'instructor_details') {
      return 'Instructor Details';
    }
    if (pageKey == 'student_invoice') {
      return 'Student Invoice';
    }
    if (pageKey == 'profile') {
      return 'My Profile';
    }
    if (pageKey == 'schedule_booking') {
      return 'Book a Lesson';
    }
    if (pageKey == 'recurring_schedule') {
      return 'Create Recurring Schedule';
    }
    if (pageKey == 'add_user') {
      return 'Add User';
    }
    if (pageKey == 'bulk_student_upload') {
      return 'Bulk Student Upload';
    }
    if (pageKey == 'student_graduation') {
      return 'Graduate Student';
    }
    if (pageKey == 'sync') {
      return AppTheme.syncPageTitle;
    }
    if (pageKey == 'subscription') {
      return AppTheme.subscriptionPageTitle;
    }

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
      await authController.signOutAndClearAllData();
      currentPage.value = 'login';
      expandedDropdowns.clear();
      Get.offAllNamed('/login');
    } catch (e) {
      debugPrint('Error during logout: $e');
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
