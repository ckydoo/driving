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

  String get userFirstName {
    final user = currentUser.value;
    if (user?.fname?.isNotEmpty == true) return user!.fname!;
    if (user?.email?.isNotEmpty == true) return user!.email!.split('@').first;
    return 'User';
  }

  // Safe getter for user's full name
  String get userFullName {
    final user = currentUser.value;
    if (user == null) return 'User';

    final fname = user.fname ?? '';
    final lname = user.lname ?? '';

    if (fname.isEmpty && lname.isEmpty) {
      return user.email ?? 'User';
    }

    return '$fname $lname'.trim();
  }

  // Safe getter for user initials
  String get userInitials {
    final user = currentUser.value;
    if (user == null) return 'U';

    String initials = '';

    if (user.fname?.isNotEmpty == true) {
      initials += user.fname![0].toUpperCase();
    }

    if (user.lname?.isNotEmpty == true && initials.length < 2) {
      initials += user.lname![0].toUpperCase();
    }

    if (initials.isEmpty && user.email?.isNotEmpty == true) {
      initials = user.email![0].toUpperCase();
    }

    return initials.isNotEmpty ? initials : 'U';
  }

  // Safe method to check if user data is available
  bool get isUserDataAvailable {
    return isLoggedIn.value && currentUser.value != null;
  }

  // Safe method to get user role
  String get userRole {
    final user = currentUser.value;
    return user?.role?.toLowerCase() ?? 'guest';
  }

  // Safe method to check specific roles - FIXED VERSION
  bool hasRole(String role) {
    if (!isUserDataAvailable) return false;
    final currentUserRole = currentUser.value?.role?.toLowerCase() ?? '';
    return currentUserRole == role.toLowerCase();
  }

  // Safe method to check multiple roles - FIXED VERSION
  bool hasAnyRole(List<String> roles) {
    if (!isUserDataAvailable) return false;
    final currentUserRole = currentUser.value?.role?.toLowerCase() ?? '';
    return roles.any((role) => currentUserRole == role.toLowerCase());
  }

  // Safe method to check if user is admin
  bool get isAdmin {
    return hasRole('admin');
  }

  // Safe method to check if user is instructor
  bool get isInstructor {
    return hasRole('instructor');
  }

  // Safe method to check if user is student
  bool get isStudent {
    return hasRole('student');
  }

  // Safe method to check if user can access admin features
  bool get canAccessAdminFeatures {
    return hasAnyRole(['admin']);
  }

  // Safe method to check if user can access instructor features
  bool get canAccessInstructorFeatures {
    return hasAnyRole(['admin', 'instructor']);
  }

  // Safe method to get user email
  String get userEmail {
    return currentUser.value?.email ?? '';
  }

  // Safe method to get user ID
  String? get userId {
    return currentUser.value?.id?.toString();
  }
}
