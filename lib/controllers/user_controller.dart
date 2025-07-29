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

  Future<void> handleUser(User user, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      error('');

      print(
          'UserController: ${isUpdate ? 'Updating' : 'Adding'} user: ${user.fname} ${user.lname}');

      if (isUpdate && user.id != null) {
        await DatabaseHelper.instance.updateUser(user);
        // Update the user in the local list
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _users[index] = user;
        }
        print('UserController: User updated successfully');
      } else {
        final newUserId = await DatabaseHelper.instance.insertUser(user);
        user.id = newUserId;
        // Add the new user to the local list
        _users.add(user);
        print('UserController: User added successfully with ID: $newUserId');
      }

      Get.snackbar(
        'Success',
        '${user.fname} ${user.lname} ${isUpdate ? 'updated' : 'added'} successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      error(e.toString());
      print(
          'UserController: Error ${isUpdate ? 'updating' : 'adding'} user - ${e.toString()}');
      Get.snackbar(
        'Error',
        '${isUpdate ? 'Update' : 'Add'} failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      rethrow;
    } finally {
      isLoading(false);
    }
  }

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
