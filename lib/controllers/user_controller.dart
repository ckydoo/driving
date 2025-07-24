import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserController extends GetxController {
  final RxList<User> _users = <User>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  List<User> get users => _users;
  List<User> get students => _users.where((u) => u.role == 'student').toList();
  List<User> get instructors =>
      _users.where((u) => u.role == 'instructor').toList();

  RxList<User> searchedUser = <User>[].obs;
  RxList<int> selectedUser = <int>[].obs;
  final searchQuery = ''.obs; // Observable search query
  RxBool isAllSelected = false.obs;

  // Pagination variables
  final int _rowsPerPage = 10;
  final RxInt _currentPage = 1.obs;
  int get currentPage => _currentPage.value;
  int get totalPages => (_users.length / _rowsPerPage).ceil();
  // Add this ValueNotifier
  final ValueNotifier<bool> isMultiSelectionActive = ValueNotifier<bool>(false);

  @override
  void onInit() {
    super.onInit();
    // Initialize users immediately when controller is created
    ever(_users, (_) => print('Users list updated: ${_users.length} users'));
  }

  @override
  void onReady() {
    // Fetch users when controller is ready
    fetchUsers();
    super.onReady();
  }

  Future<List<User>> fetchUsers({String? role}) async {
    try {
      isLoading(true);
      error('');

      print('UserController: Fetching users with role: $role');

      final data =
          await DatabaseHelper.instance.getUsers(role: role?.toLowerCase());
      final List<User> users = data.map((json) => User.fromJson(json)).toList();

      print('UserController: Fetched ${users.length} users from database');

      // Update the observable list - this will trigger UI updates
      _users.assignAll(users);

      // Clear any previous search results when fetching new data
      searchedUser.clear();
      selectedUser.clear();
      isAllSelected(false);
      isMultiSelectionActive.value = false;

      print(
          'UserController: Updated observable list with ${_users.length} users');

      return users;
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

  Future<void> handleUser(User user, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      error('');

      print(
          'UserController: ${isUpdate ? 'Updating' : 'Creating'} user: ${user.fname} ${user.lname}');

      if (isUpdate) {
        await DatabaseHelper.instance.updateUser(user);
        // Update the user in the local list
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _users[index] = user;
          print('UserController: Updated user in local list at index $index');
        }
      } else {
        final newUserId = await DatabaseHelper.instance.insertUser(user);
        // Add the new user to the local list with the generated ID
        final newUser = User(
          id: newUserId,
          fname: user.fname,
          lname: user.lname,
          email: user.email,
          password: user.password,
          gender: user.gender,
          phone: user.phone,
          address: user.address,
          date_of_birth: user.date_of_birth,
          role: user.role,
          status: user.status,
          idnumber: user.idnumber,
          created_at: user.created_at,
        );
        _users.add(newUser);
        print(
            'UserController: Added new user to local list with ID: $newUserId');
      }

      // Refresh the list to ensure consistency
      _users.refresh();
    } catch (e) {
      error(e.toString());
      print(
          'UserController: Error ${isUpdate ? 'updating' : 'creating'} user - ${e.toString()}');
      Get.snackbar(
        'Error',
        'User operation failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      rethrow; // Re-throw to allow UI to handle the error
    } finally {
      isLoading(false);
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      isLoading(true);
      error('');

      print('UserController: Deleting user with ID: $id');

      await DatabaseHelper.instance.deleteUser(id);

      // Remove from local list
      final removedUser = _users.firstWhereOrNull((user) => user.id == id);
      _users.removeWhere((user) => user.id == id);

      // Remove from selected users if it was selected
      selectedUser.remove(id);
      if (selectedUser.isEmpty) {
        isMultiSelectionActive.value = false;
        isAllSelected(false);
      }

      print(
          'UserController: Removed user ${removedUser?.fname ?? 'Unknown'} from local list');
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

  void goToPreviousPage() {
    if (_currentPage.value > 1) {
      _currentPage.value--;
    }
  }

  void goToNextPage() {
    if (_currentPage.value < totalPagesForCurrentView) {
      _currentPage.value++;
    }
  }

  void resetToFirstPage() {
    _currentPage.value = 1;
  }

  void toggleUserSelection(int id) {
    if (selectedUser.contains(id)) {
      selectedUser.remove(id);
    } else {
      selectedUser.add(id);
    }
    isMultiSelectionActive.value = selectedUser.isNotEmpty;

    // Update select all state
    final currentList = searchedUser.isNotEmpty ? searchedUser : _users;
    isAllSelected.value = selectedUser.length == currentList.length;
  }

  void toggleSelectAll(bool value) {
    isAllSelected.value = value;
    if (value) {
      final currentList = searchedUser.isNotEmpty ? searchedUser : _users;
      selectedUser.assignAll(currentList.map((user) => user.id!));
    } else {
      selectedUser.clear();
    }
    isMultiSelectionActive.value = selectedUser.isNotEmpty;
  }

  // Get user by ID
  User? getUserById(int id) {
    return _users.firstWhereOrNull((user) => user.id == id);
  }

  // Get users by role with real-time updates
  List<User> getUsersByRole(String role) {
    return _users
        .where((user) => user.role.toLowerCase() == role.toLowerCase())
        .toList();
  }

  // Get active users only
  List<User> get activeUsers =>
      _users.where((user) => user.status.toLowerCase() == 'active').toList();

  // Refresh users data
  Future<void> refreshUsers() async {
    await fetchUsers();
  }

  // Clear all data (useful for logout)
  void clearAllData() {
    _users.clear();
    searchedUser.clear();
    selectedUser.clear();
    searchQuery.value = '';
    isAllSelected.value = false;
    isMultiSelectionActive.value = false;
    _currentPage.value = 1;
    error.value = '';
  }
}
