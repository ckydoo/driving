// lib/controllers/auth_controller_extension.dart
import 'package:get/get.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/models/user.dart'; // Add this import

/// Extension to AuthController to support the new simple school join flow
extension SimpleSchoolJoinExtension on AuthController {
  /// Set current user from Firebase data (used by SimpleSchoolJoinController)
  void setCurrentUserFromData(Map<String, dynamic> userData) {
    try {
      // Create a User object using the fromJson factory
      currentUser.value = User.fromJson(userData);

      // Set authentication state
      isLoggedIn(true);

      print('✅ User data set in AuthController: ${userData['email']}');
    } catch (e) {
      print('❌ Error setting user data in AuthController: $e');
      throw Exception('Failed to set user authentication data');
    }
  }

  /// Validate if user has required permissions for school
  bool hasSchoolPermission(String schoolId) {
    if (!isLoggedIn.value || currentUser.value == null) return false;

    // You'll need to add schoolId to your User model or handle this differently
    // For now, return true if user is logged in
    return true;
  }

  /// Get current user's school ID
  String? getCurrentUserSchoolId() {
    if (!isLoggedIn.value || currentUser.value == null) return null;
    // You'll need to add schoolId to your User model
    return null;
  }

  /// Check if current user is admin
  bool isCurrentUserAdmin() {
    if (!isLoggedIn.value || currentUser.value == null) return false;
    final role = currentUser.value!.role;
    return role.toLowerCase() == 'admin';
  }

  /// Get current user's full name
  String getCurrentUserFullName() {
    if (!isLoggedIn.value || currentUser.value == null) return 'Guest';

    final fname = currentUser.value!.fname;
    final lname = currentUser.value!.lname;

    if (fname.isEmpty && lname.isEmpty) {
      return currentUser.value!.email;
    }

    return '$fname $lname'.trim();
  }

  /// Refresh user data from local database
  Future<void> refreshUserData() async {
    if (!isLoggedIn.value || currentUser.value == null) return;

    try {
      final email = currentUser.value!.email;
      if (email.isEmpty) return;

      // Use a simple database query to refresh user data
      final users = await DatabaseHelper.instance.getUsers();
      final userData = users.firstWhere(
        (u) => u['email']?.toString().toLowerCase() == email.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      if (userData.isNotEmpty) {
        setCurrentUserFromData(userData);
        print('✅ User data refreshed successfully');
      }
    } catch (e) {
      print('⚠️ Failed to refresh user data: $e');
    }
  }

  /// Clear all user session data
  void clearUserSession() {
    currentUser.value = null;
    isLoggedIn(false);
    error.value = '';
    print('🔐 User session cleared');
  }

  /// Quick login validation for PIN-based authentication
  Future<bool> validateQuickLogin(String email) async {
    try {
      if (email.isEmpty) return false;

      // Check if user exists in local database
      final users = await DatabaseHelper.instance.getUsers();
      final userData = users.firstWhere(
        (u) => u['email']?.toString().toLowerCase() == email.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      if (userData.isEmpty) return false;

      // Set user data without password validation
      setCurrentUserFromData(userData);

      return true;
    } catch (e) {
      print('❌ Quick login validation failed: $e');
      return false;
    }
  }

  /// Helper method to get user email
  String? get currentUserEmail {
    return currentUser.value?.email;
  }
}
