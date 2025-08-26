import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
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
  final AuthController _authController = Get.find<AuthController>();

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
        filteredUsers =
            users
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

  /// ENHANCED handleUser method - LOCAL FIRST approach
  Future<void> handleUser(User user, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      error('');

      print(
        'UserController: ${isUpdate ? 'Updating' : 'Adding'} user (LOCAL FIRST): ${user.fname} ${user.lname}',
      );

      // Step 1: Handle updates (always local)
      if (isUpdate && user.id != null) {
        await _handleUserUpdate(user);
        return;
      }

      // Step 2: Handle new user creation - LOCAL FIRST approach
      if (!isUpdate) {
        await _handleNewUserCreationLocalFirst(user);
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

  Future<void> deleteMultipleUsers(List<int> userIds) async {
    try {
      isLoading(true);
      error('');

      print('UserController: Deleting ${userIds.length} users');

      for (int id in userIds) {
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

  // Search functionality
  void searchUsers(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      searchedUser.clear();
    } else {
      final results =
          _users
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

  Future<void> _handleNewUserCreationLocalFirst(User user) async {
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

    // Step 2: Save to LOCAL database FIRST using existing method
    print('💾 Saving to local database first (will trigger automatic sync)...');

    // Your existing insertUser method already uses sync-aware extension
    final newUserId = await DatabaseHelper.instance.insertUser(user);
    final createdUser = user.copyWith(id: newUserId);

    // Add to local observable list for immediate UI update
    _users.add(createdUser);

    print('✅ User saved locally with ID: $newUserId (marked for sync)');

    // Step 3: Show success message immediately (based on local save)
    Get.snackbar(
      'Success',
      '${user.fname} ${user.lname} saved successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    // Step 4: Sync happens automatically via DatabaseHelperSyncExtension._triggerSmartSync()
    print('🔄 Automatic sync will be triggered in background');
  }

  // 3. REPLACE YOUR _handleUserUpdate METHOD:
  /// Handle user updates - FIXED version
  Future<void> _handleUserUpdate(User user) async {
    // Check for duplicates first (excluding the current user)
    final duplicateErrors = await checkForDuplicates(user, isUpdate: true);
    if (duplicateErrors.isNotEmpty) {
      final errorMessage = duplicateErrors.values.first;
      throw Exception(errorMessage);
    }

    // Update in local database FIRST using existing method
    // Your existing updateUser method already uses sync-aware extension
    await DatabaseHelper.instance.updateUser(user);

    // Update the user in the local observable list
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
    }

    print('✅ User updated locally successfully (marked for sync)');

    Get.snackbar(
      'Success',
      '${user.fname} ${user.lname} updated successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    // Sync happens automatically via DatabaseHelperSyncExtension._triggerSmartSync()
    print('🔄 Automatic sync will be triggered in background');
  }

  // 4. ADD THIS NEW METHOD FOR MANUAL SYNC TESTING:
  /// Manually trigger sync for testing
  Future<void> manualSyncTrigger() async {
    try {
      if (Get.isRegistered<FixedLocalFirstSyncService>()) {
        final syncService = Get.find<FixedLocalFirstSyncService>();

        if (syncService.isSyncing.value) {
          Get.snackbar('Info', 'Sync already in progress...');
          return;
        }

        Get.snackbar('Sync Started', 'Syncing data with Firebase...');

        await syncService.syncWithFirebase();

        Get.snackbar(
          'Success',
          'Sync completed successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar('Error', 'Fixed sync service not available');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Sync failed: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // 5. ADD DEBUG METHODS:
  /// Get sync status for debugging
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      return await DatabaseHelper.instance.getDetailedSyncStatus();
    } catch (e) {
      print('Error getting sync status: $e');
      return {'error': e.toString()};
    }
  }

  /// Get sync conflicts for debugging
  Future<List<Map<String, dynamic>>> getSyncConflicts() async {
    try {
      return await DatabaseHelper.instance.getConflictHistory();
    } catch (e) {
      print('Error getting conflict history: $e');
      return [];
    }
  }

  // 6. UPDATE YOUR deleteUser METHOD (if it exists):
  /// Delete user - FIXED version
  Future<void> deleteUser(int userId) async {
    try {
      isLoading(true);
      error('');

      final userToDelete = _users.firstWhere(
        (user) => user.id == userId,
        orElse:
            () => User(
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

      // Use existing delete method (already uses sync-aware extension)
      await DatabaseHelper.instance.deleteUser(userId);

      // Remove from local observable list
      _users.removeWhere((user) => user.id == userId);

      print('UserController: User deleted successfully (marked for sync)');

      Get.snackbar(
        'Success',
        '${userToDelete.fname} ${userToDelete.lname != 'User' ? userToDelete.lname : ''} deleted successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Sync happens automatically via DatabaseHelperSyncExtension._triggerSmartSync()
      print('🔄 Automatic sync will be triggered in background');
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
