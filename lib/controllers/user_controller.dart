import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserController extends GetxController {
  final RxList<User> _users = <User>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  // ignore: unused_field
  String? _lastFetchedRole;

  List<User> get users => _users;
  List<User> get students => _users.where((u) => u.role == 'student').toList();
  List<User> get instructors =>
      _users.where((u) => u.role == 'instructor').toList();

  RxList<User> searchedUser = <User>[].obs;
  RxList<int> selectedUser = <int>[].obs;
  final searchQuery = ''.obs;
  RxBool isAllSelected = false.obs;

  // Pagination variables
  final int _rowsPerPage = 10;
  final RxInt _currentPage = 1.obs;
  int get currentPage => _currentPage.value;
  int get totalPages => (_users.length / _rowsPerPage).ceil();
  final Rx<User?> currentUser = Rx<User?>(null);
  final ValueNotifier<bool> isMultiSelectionActive = ValueNotifier<bool>(false);

  @override
  void onInit() {
    super.onInit();
    ever(_users, (_) => print('Users list updated: ${_users.length} users'));
  }

  @override
  void onReady() {
    // Don't automatically fetch users here - let screens request what they need
    super.onReady();
  }

  Future<List<User>> fetchUsers({String? role}) async {
    try {
      isLoading(true);
      error('');

      print('UserController: Fetching users with role: $role');

      // Always fetch fresh data, especially when role changes
      final data = await DatabaseHelper.instance.getUsers(
        role: role?.toLowerCase(),
      );
      final List<User> users = data.map((json) => User.fromJson(json)).toList();

      print('UserController: Fetched ${users.length} users from database');

      // If a specific role is requested, filter and return only those users
      List<User> filteredUsers;
      if (role != null) {
        filteredUsers = users
            .where((user) => user.role.toLowerCase() == role.toLowerCase())
            .toList();
        print('UserController: Filtered to ${filteredUsers.length} ${role}s');
      } else {
        filteredUsers = users;
      }

      // Update the observable list with ALL users (for global access)
      _users.assignAll(users);

      // Update the last fetched role
      _lastFetchedRole = role;

      // Clear any previous search results when fetching new data
      searchedUser.clear();
      selectedUser.clear();
      isAllSelected(false);
      isMultiSelectionActive.value = false;

      print(
        'UserController: Updated observable list with ${_users.length} total users, returning ${filteredUsers.length} filtered users',
      );

      return filteredUsers;
    } catch (e) {
      error(e.toString());
      print('UserController: Error fetching users - ${e.toString()}');
      Get.snackbar(
        'Error',
        'Failed to load users: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return [];
    } finally {
      isLoading(false);
    }
  }

  // Add a method to get users by role from the existing list (avoid refetch)
  List<User> getUsersByRole(String role) {
    return _users
        .where((user) => user.role.toLowerCase() == role.toLowerCase())
        .toList();
  }

  // Add a method to refresh users for a specific role
  Future<List<User>> refreshUsersForRole(String role) async {
    print('UserController: Refreshing users for role: $role');
    return await fetchUsers(role: role);
  }

  /// Handle user operations - LOCAL ONLY approach
  Future<void> handleUser(User user, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      error('');

      print(
        'UserController: ${isUpdate ? 'Updating' : 'Adding'} user (LOCAL ONLY): ${user.fname} ${user.lname}',
      );

      // Step 1: Handle updates (always local)
      if (isUpdate && user.id != null) {
        await _handleUserUpdate(user);
        return;
      }

      // Step 2: Handle new user creation - LOCAL ONLY approach
      if (!isUpdate) {
        await _handleNewUserCreation(user);
      }
    } catch (e) {
      error(e.toString());
      print(
        'UserController: Error ${isUpdate ? 'updating' : 'adding'} user - ${e.toString()}',
      );

      // Parse user-friendly error messages
      String userFriendlyError = _parseError(e.toString());

      Get.snackbar(
        'Error',
        userFriendlyError,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

      // Re-throw the error so calling code knows it failed
      rethrow;
    } finally {
      isLoading(false);
    }
  }

  /// Parse database errors to provide user-friendly messages
  String _parseError(String error) {
    if (error.contains('UNIQUE constraint failed: users.email')) {
      return 'Email address already registered';
    } else if (error.contains('UNIQUE constraint failed: users.phone')) {
      return 'Phone number already registered';
    } else if (error.contains('UNIQUE constraint failed: users.idnumber')) {
      return 'ID number already registered';
    } else if (error.toLowerCase().contains('null')) {
      return 'Missing required information. Please fill in all required fields.';
    } else if (error.contains('Failed to save user')) {
      return 'Failed to save student. Please try again.';
    } else {
      return 'Failed to save student. Please check your information and try again.';
    }
  }

  /// Check for duplicate user data before saving
  Future<Map<String, String>> checkForDuplicates(
    User user, {
    bool isUpdate = false,
  }) async {
    final duplicateErrors = <String, String>{};

    try {
      final allUsers = await DatabaseHelper.instance.getUsers();

      for (final existingUserData in allUsers) {
        final existingUser = User.fromJson(existingUserData);

        // Skip checking against the same user when updating
        if (isUpdate && existingUser.id == user.id) {
          continue;
        }

        // Check for duplicate email
        if (existingUser.email.toLowerCase() == user.email.toLowerCase()) {
          duplicateErrors['email'] =
              'Email already used by ${existingUser.fname} ${existingUser.lname}';
        }

        // Check for duplicate ID number
        if (existingUser.idnumber.isNotEmpty && user.idnumber.isNotEmpty) {
          if (existingUser.idnumber.toUpperCase() ==
              user.idnumber.toUpperCase()) {
            duplicateErrors['idnumber'] =
                'ID number already used by ${existingUser.fname} ${existingUser.lname}';
          }
        }

        // Check for duplicate phone
        if (existingUser.phone.isNotEmpty && user.phone.isNotEmpty) {
          if (existingUser.phone == user.phone) {
            duplicateErrors['phone'] =
                'Phone already used by ${existingUser.fname} ${existingUser.lname}';
          }
        }
      }

      return duplicateErrors;
    } catch (e) {
      print('Error checking for duplicates: $e');
      return {};
    }
  }

  // Search functionality
  void searchUsers(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      searchedUser.clear();
    } else {
      final results = _users
          .where(
            (user) =>
                user.fname.toLowerCase().contains(query.toLowerCase()) ||
                user.lname.toLowerCase().contains(query.toLowerCase()) ||
                user.email.toLowerCase().contains(query.toLowerCase()) ||
                user.phone.contains(query) ||
                user.idnumber.contains(query),
          )
          .toList();
      searchedUser.assignAll(results);
    }
  }

  // Method to get users for the current page
  List<User> get usersForCurrentPage {
    final userList = searchedUser.isNotEmpty ? searchedUser : _users;
    final startIndex = (_currentPage.value - 1) * _rowsPerPage;
    var endIndex = startIndex + _rowsPerPage;
    if (endIndex > userList.length) {
      endIndex = userList.length;
    }
    return userList.sublist(startIndex, endIndex);
  }

  int get totalPagesForCurrentView {
    final userList = searchedUser.isNotEmpty ? searchedUser : _users;
    return (userList.length / _rowsPerPage).ceil();
  }

  void nextPage() {
    if (_currentPage.value < totalPagesForCurrentView) {
      _currentPage.value++;
    }
  }

  void previousPage() {
    if (_currentPage.value > 1) {
      _currentPage.value--;
    }
  }

  void goToPage(int page) {
    if (page >= 1 && page <= totalPagesForCurrentView) {
      _currentPage.value = page;
    }
  }

// 1. In _handleUserUpdate method - track user updates
// Fixed _handleUserUpdate method in UserController

  Future<void> _handleUserUpdate(User user) async {
    // Check for duplicates first (excluding the current user)
    final duplicateErrors = await checkForDuplicates(user, isUpdate: true);
    if (duplicateErrors.isNotEmpty) {
      final errorMessage = duplicateErrors.values.first;
      throw Exception(errorMessage);
    }

    // 🔧 FIX: Ensure the user has a school_id before updating
    User userToUpdate = user;

    // If the user doesn't have a schoolId, get it from current context or existing user
    if (user.schoolId == null || user.schoolId!.isEmpty) {
      // Option 1: Get from AuthController
      final authController = Get.find<AuthController>();
      final currentSchoolId = authController.currentUser.value?.schoolId ?? '1';

      // Option 2: Get from existing user in database (safer approach)
      try {
        final existingUsers = await DatabaseHelper.instance.getUsers();
        final existingUser = existingUsers.firstWhere(
          (u) => u['id'] == user.id,
          orElse: () => <String, dynamic>{},
        );

        final schoolIdToUse = existingUser['school_id'] ?? currentSchoolId;
        userToUpdate = user.copyWith(schoolId: schoolIdToUse.toString());

        print(
            '🔧 Added missing school_id: $schoolIdToUse to user ${user.email}');
      } catch (e) {
        print(
            '⚠️ Could not get existing user, using current school: $currentSchoolId');
        userToUpdate = user.copyWith(schoolId: currentSchoolId);
      }
    }

    // Convert User to Map for database operation
    final userMap = userToUpdate.toJson();

    // 🔧 ADDITIONAL SAFETY: Ensure school_id is not null in the map
    if (userMap['school_id'] == null) {
      userMap['school_id'] = '1'; // Default fallback
      print('⚠️ Applied fallback school_id: 1');
    }

    print('📝 Updating user with school_id: ${userMap['school_id']}');

    // Update in local database
    await DatabaseHelper.instance.updateUser(userMap);

    // 🔄 TRACK THE USER UPDATE FOR SYNC
    await SyncService.trackChange('users', userMap, 'update');
    print('📝 Tracked user update for sync');

    // Update the user in the local observable list
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = userToUpdate; // Use the updated user with school_id
    }

    print('✅ User updated locally successfully');

    Get.snackbar(
      'Success',
      '${user.fname} ${user.lname} updated successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

// 2. In _handleNewUserCreation method - track user creation
  Future<void> _handleNewUserCreation(User user) async {
    // Step 1: Check for duplicates first
    final duplicateErrors = await checkForDuplicates(user, isUpdate: false);
    if (duplicateErrors.isNotEmpty) {
      final errorMessages = duplicateErrors.values.join('\n');
      Get.snackbar(
        'Duplicate Found',
        errorMessages,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      throw Exception(duplicateErrors.values.first);
    }

    // Step 2: Get current school ID
    final authController = Get.find<AuthController>();
    final currentSchoolId = authController.currentUser.value?.schoolId ??
        '1'; // Default to 1 for local

    // Step 3: Add school_id to user
    final userWithSchool = user.copyWith(schoolId: currentSchoolId);

    // Step 4: Save to LOCAL database
    print('💾 Saving to local database...');

    // Convert User to Map for database operation
    final userMap = userWithSchool.toJson();
    final newUserId = await DatabaseHelper.instance.insertUser(userMap);

    final createdUser = userWithSchool.copyWith(id: newUserId);

    // 🔄 TRACK THE USER CREATION FOR SYNC
    await SyncService.trackChange('users', createdUser.toJson(), 'create');
    print('📝 Tracked user creation for sync');

    // Add to local observable list for immediate UI update
    _users.add(createdUser);
    print('✅ User saved locally with ID: $newUserId');

    // Step 5: Show success message
    Get.snackbar(
      'Success',
      '${user.fname} ${user.lname} saved successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    print('✅ User creation completed');
  }

// 3. In deleteUser method - track user deletion
  Future<void> deleteUser(int userId) async {
    try {
      isLoading(true);
      error('');

      final userToDelete = _users.firstWhere(
        (user) => user.id == userId,
        orElse: () => User(
          fname: 'Unknown',
          lname: 'User',
          id: userId,
          email: '',
          password: '',
          gender: '',
          phone: '',
          address: '',
          date_of_birth: DateTime.now(),
          role: '',
          status: '',
          idnumber: '',
          created_at: DateTime.now(),
        ),
      );

      print(
        'UserController: Deleting user: ${userToDelete.fname} ${userToDelete.lname}',
      );

      // 🔄 TRACK THE USER DELETION FOR SYNC
      await SyncService.trackChange('users', {'id': userId}, 'delete');
      print('📝 Tracked user deletion for sync');

      // Delete from local database
      await DatabaseHelper.instance.deleteUser(userId);

      // Remove from local observable list
      _users.removeWhere((user) => user.id == userId);

      print('UserController: User deleted successfully');

      Get.snackbar(
        'Success',
        '${userToDelete.fname} ${userToDelete.lname != 'User' ? userToDelete.lname : ''} deleted successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      error(e.toString());
      Get.snackbar(
        'Error',
        'Failed to delete user: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

// 4. In deleteMultipleUsers method - track multiple user deletions
  Future<void> deleteMultipleUsers(List<int> userIds) async {
    try {
      isLoading(true);
      error('');

      print('UserController: Deleting ${userIds.length} users');

      for (int id in userIds) {
        // 🔄 TRACK EACH USER DELETION FOR SYNC
        await SyncService.trackChange('users', {'id': id}, 'delete');
        print('📝 Tracked user deletion for sync: $id');

        await DatabaseHelper.instance.deleteUser(id);
        _users.removeWhere((user) => user.id == id);
      }

      // Clear selections
      selectedUser.clear();
      isMultiSelectionActive.value = false;
      isAllSelected(false);

      print('UserController: Successfully deleted ${userIds.length} users');

      Get.snackbar(
        'Success',
        'Successfully deleted ${userIds.length} users',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      error(e.toString());
      print('UserController: Error deleting multiple users - ${e.toString()}');
      Get.snackbar(
        'Error',
        'Failed to delete users: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      rethrow;
    } finally {
      isLoading(false);
    }
  }

// Don't forget to import SyncService at the top of your file:
// import 'package:driving/services/sync_service.dart';

  // Clear all data (useful for logout)
  void clearData() {
    _users.clear();
    searchedUser.clear();
    selectedUser.clear();
    searchQuery.value = '';
    isAllSelected.value = false;
    isMultiSelectionActive.value = false;
    _currentPage.value = 1;
    _lastFetchedRole = null;
    error.value = '';
  }
}
