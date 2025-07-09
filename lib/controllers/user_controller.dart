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
  List<User> get user => _users;
  // Pagination variables
  final int _rowsPerPage = 10;
  final RxInt _currentPage = 1.obs;
  int get currentPage => _currentPage.value;
  int get totalPages => (_users.length / _rowsPerPage).ceil();
  // Add this ValueNotifier
  final ValueNotifier<bool> isMultiSelectionActive = ValueNotifier<bool>(false);

  @override
  void onReady() {
    fetchUsers();
    super.onReady();
  }

  Future<List<User>> fetchUsers({String? role}) async {
    try {
      isLoading(true);
      error('');
      final data =
          await DatabaseHelper.instance.getUsers(role: role?.toLowerCase());
      final List<User> users = data.map((json) => User.fromJson(json)).toList();
      _users.assignAll(users); // Update the observable list
      return Future.value(users); // Return the list of users
    } catch (e) {
      error(e.toString());
      Get.snackbar('Error', 'Failed to load users: ${e.toString()}');
      return Future.error(e.toString()); // Return an error
    } finally {
      isLoading(false);
    }
  }

  Future<void> handleUser(User user, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      // Ensure the toJson method in User model correctly handles new fields
      // and DatabaseHelper.instance.updateUser/insertUser can process them.
      isUpdate
          ? await DatabaseHelper.instance.updateUser(user)
          : await DatabaseHelper.instance.insertUser(user);

      await fetchUsers();
    } catch (e) {
      error(e.toString());
      Get.snackbar('Error', 'User operation failed: ${e.toString()}');
      print(e.toString());
    } finally {
      isLoading(false);
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      isLoading(true);
      await DatabaseHelper.instance.deleteUser(id);
      _users.removeWhere((user) => user.id == id);
    } catch (e) {
      error(e.toString());
      Get.snackbar('Error', 'Delete failed: ${e.toString()}');
      print(e.toString());
    } finally {
      isLoading(false);
    }
  }

  // Method to get users for the current page
  List<User> get usersForCurrentPage {
    final startIndex = (_currentPage.value - 1) * _rowsPerPage;
    var endIndex = startIndex + _rowsPerPage;
    if (endIndex > _users.length) {
      endIndex = _users.length;
    }
    return _users.sublist(startIndex, endIndex);
  }

  void goToPreviousPage() {
    if (_currentPage.value > 1) {
      _currentPage.value--;
    }
  }

  void goToNextPage() {
    if (_currentPage.value < totalPages) {
      _currentPage.value++;
    }
  }

  void toggleUserSelection(int id) {
    if (selectedUser.contains(id)) {
      selectedUser.remove(id);
    } else {
      selectedUser.add(id);
    }
    isMultiSelectionActive.value = selectedUser.isNotEmpty;
  }

  void toggleSelectAll(bool value) {
    isAllSelected.value = value;
    if (value) {
      selectedUser.assignAll(_users.map((user) => user.id!));
    } else {
      selectedUser.clear();
    }
    isMultiSelectionActive.value = selectedUser.isNotEmpty;
  }
}
