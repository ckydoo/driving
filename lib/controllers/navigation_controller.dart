// lib/controllers/navigation_controller.dart
import 'package:get/get.dart';

class NavigationController extends GetxController {
  var currentPage = 'dashboard'.obs;
  var currentUser = Rxn<Map<String, String>>();

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
      case 'students':
        return 'Student Management';
      case 'instructors':
        return 'Instructor Management';
      case 'vehicles':
        return 'Vehicle Management';
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
