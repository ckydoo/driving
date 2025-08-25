import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
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
      final data =
          await DatabaseHelper.instance.getUsers(role: role?.toLowerCase());
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
          'UserController: Updated observable list with ${_users.length} total users, returning ${filteredUsers.length} filtered users');

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
// lib/controllers/user_controller.dart - FIXED to prevent double saving

  /// ENHANCED handleUser method - prevents double saving when Firebase is used
  Future<void> handleUser(User user, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      error('');

      print(
          'UserController: ${isUpdate ? 'Updating' : 'Adding'} user: ${user.fname} ${user.lname}');

      // Step 1: For updates, handle locally first
      if (isUpdate && user.id != null) {
        await DatabaseHelper.instance.updateUser(user);
        // Update the user in the local list
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _users[index] = user;
        }
        print('UserController: User updated successfully');

        Get.snackbar(
          'Success',
          '${user.fname} ${user.lname} updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Step 2: For new users, try Firebase first
      bool firebaseAuthCreated = false;
      if (!isUpdate && _authController.firebaseAvailable.value) {
        try {
          print('🔥 Creating Firebase Authentication account...');

          final firebaseSuccess =
              await _authController.registerWithEmailPassword(
            user.email,
            user.password,
            user.toJson(),
          );

          firebaseAuthCreated = firebaseSuccess;

          if (firebaseSuccess) {
            print('✅ Firebase user created successfully');
            print('🔄 Firebase sync will handle local database insertion');

            // ✅ KEY FIX: Don't save to local database here!
            // The Firebase sync process will handle the local database insertion

            // Just add to local list for UI purposes (sync will update with proper ID)
            _users.add(user);

            Get.snackbar(
              'Success',
              '${user.fname} ${user.lname} added successfully with cloud authentication',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );

            return; // Exit early - no local database save needed
          } else {
            print('⚠️ Firebase creation failed, falling back to local-only');
          }
        } catch (e) {
          print('⚠️ Firebase error: $e');
          if (e.toString().contains('email-already-in-use')) {
            Get.snackbar(
              'Error',
              'Email ${user.email} is already registered',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );
            return;
          }
          print('⚠️ Falling back to local-only creation');
        }
      }

      // Step 3: Local-only creation (fallback when Firebase fails or unavailable)
      if (!firebaseAuthCreated) {
        print('💾 Creating local-only user account');

        // Check for duplicates first
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
          return;
        }

        final newUserId = await DatabaseHelper.instance.insertUser(user);
        user.id = newUserId;
        _users.add(user);

        print('UserController: Local user created with ID: $newUserId');

        Get.snackbar(
          'Success',
          '${user.fname} ${user.lname} added successfully (offline mode)',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      error(e.toString());
      print(
          'UserController: Error ${isUpdate ? 'updating' : 'adding'} user - ${e.toString()}');

      String userFriendlyError = _parseError(e.toString());
      Get.snackbar(
        'Error',
        userFriendlyError,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } finally {
      isLoading(false);
    }
  }

  /// Check for duplicate user data before saving
  Future<Map<String, String>> checkForDuplicates(User user,
      {bool isUpdate = false}) async {
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

  /// Parse database errors to provide user-friendly messages
  String _parseError(String error) {
    if (error.contains('UNIQUE constraint failed: users.email')) {
      return 'Email address already registered';
    } else if (error.contains('UNIQUE constraint failed: users.phone')) {
      return 'Phone number already registered';
    } else if (error.contains('UNIQUE constraint failed: users.idnumber')) {
      return 'ID number already registered';
    } else if (error.contains('email-already-in-use')) {
      return 'Email already registered in cloud system';
    } else {
      return 'Failed to save user';
    }
  }

// Add this import at the top of your user_controller.dart file:
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
          'UserController: Deleting user: ${userToDelete.fname} ${userToDelete.lname}');

      await DatabaseHelper.instance.deleteUser(userId);
      _users.removeWhere((user) => user.id == userId);

      print(
          'UserController: User deleted successfully from database and local list');

      Get.snackbar(
        'Success',
        '${userToDelete.fname} ${userToDelete.lname != 'User' ? userToDelete.lname : 'Unknown'} deleted successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      error(e.toString());
      print('UserController: Error deleting user - ${e.toString()}');
      Get.snackbar(
        'Error',
        'Delete failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      rethrow;
    } finally {
      isLoading(false);
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
      final results = _users
          .where((user) =>
              user.fname.toLowerCase().contains(query.toLowerCase()) ||
              user.lname.toLowerCase().contains(query.toLowerCase()) ||
              user.email.toLowerCase().contains(query.toLowerCase()) ||
              user.phone.contains(query) ||
              user.idnumber.contains(query))
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
