// lib/controllers/school_selection_controller.dart
import 'package:get/get.dart';

class SchoolSelectionController extends GetxController {
  /// Navigate to new school registration
  void navigateToNewSchoolRegistration() {
    Get.toNamed('/school-registration');
  }

  /// Navigate to existing school login
  void navigateToExistingSchoolLogin() {
    Get.toNamed('/school-login');
  }
}
