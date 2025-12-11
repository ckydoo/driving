import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/sync_service.dart';
import 'package:driving/services/lazy_loading_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserController extends GetxController {
  // ============================================================
  // LAZY LOADING: Paginated lists instead of loading everything
  // ============================================================
  final RxList<User> visibleUsers = <User>[].obs;
  final RxBool hasMoreUsers = true.obs;
  final RxBool isLoadingMore = false.obs;
  int _usersOffset = 0;

  // Separate pagination for students and instructors
  final RxList<User> visibleStudents = <User>[].obs;
  final RxList<User> visibleInstructors = <User>[].obs;
  final RxBool hasMoreStudents = true.obs;
  final RxBool hasMoreInstructors = true.obs;
  int _studentsOffset = 0;
  int _instructorsOffset = 0;

  // School ID for multi-tenant support
  String? get _schoolId {
    try {
      if (Get.isRegistered<AuthController>()) {
        final auth = Get.find<AuthController>();
        return auth.currentUser.value?.schoolId;
      }
    } catch (e) {
      print('Error getting school ID: $e');
    }
    return null;
  }

  // Backward compatibility
  final RxList<User> _users = <User>[].obs;
  List<User> get users => visibleUsers;
  List<User> get students => visibleStudents;
  List<User> get instructors => visibleInstructors;

  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  String? _lastFetchedRole;

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
    ever(visibleUsers, (_) => print('Users list updated: ${visibleUsers.length} users'));
  }

  @override
  void onReady() {
    // Don't automatically fetch users here - let screens request what they need
    super.onReady();
  }

  // ============================================================
  // LAZY LOADING METHODS
  // ============================================================

  /// Load initial users (all roles - first 50)
  Future<void> _loadInitialUsers() async {
    try {
      final result = await LazyLoadingService.loadInitialUsers(
        schoolId: _schoolId,
      );

      visibleUsers.value = result['users'];
      hasMoreUsers.value = result['hasMore'];
      _usersOffset = result['offset'];

      print('✅ Loaded ${visibleUsers.length} users (hasMore: ${hasMoreUsers.value})');
    } catch (e) {
      print('Error loading initial users: $e');
      rethrow;
    }
  }

  /// Load initial students (first 50)
  Future<void> _loadInitialStudents() async {
    try {
      final result = await LazyLoadingService.loadInitialUsers(
        schoolId: _schoolId,
        role: 'student',
      );

      visibleStudents.value = result['users'];
      hasMoreStudents.value = result['hasMore'];
      _studentsOffset = result['offset'];

      print('✅ Loaded ${visibleStudents.length} students (hasMore: ${hasMoreStudents.value})');
    } catch (e) {
      print('Error loading initial students: $e');
      rethrow;
    }
  }

  /// Load initial instructors (first 50)
  Future<void> _loadInitialInstructors() async {
    try {
      final result = await LazyLoadingService.loadInitialUsers(
        schoolId: _schoolId,
        role: 'instructor',
      );

      visibleInstructors.value = result['users'];
      hasMoreInstructors.value = result['hasMore'];
      _instructorsOffset = result['offset'];

      print('✅ Loaded ${visibleInstructors.length} instructors (hasMore: ${hasMoreInstructors.value})');
    } catch (e) {
      print('Error loading initial instructors: $e');
      rethrow;
    }
  }

  /// Load more users (next 25)
  Future<void> loadMoreUsers() async {
    if (!hasMoreUsers.value || isLoadingMore.value) return;

    isLoadingMore(true);

    try {
      final result = await LazyLoadingService.loadMoreUsers(
        schoolId: _schoolId,
        offset: _usersOffset,
      );

      visibleUsers.addAll(result['users']);
      hasMoreUsers.value = result['hasMore'];
      _usersOffset = result['offset'];

      print('✅ Loaded ${result['users'].length} more users (total: ${visibleUsers.length})');
    } catch (e) {
      print('Error loading more users: $e');
      Get.snackbar(
        'Error',
        'Failed to load more users',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoadingMore(false);
    }
  }

  /// Load more students (next 25)
  Future<void> loadMoreStudents() async {
    if (!hasMoreStudents.value || isLoadingMore.value) return;

    isLoadingMore(true);

    try {
      final result = await LazyLoadingService.loadMoreUsers(
        schoolId: _schoolId,
        offset: _studentsOffset,
        role: 'student',
      );

      visibleStudents.addAll(result['users']);
      hasMoreStudents.value = result['hasMore'];
      _studentsOffset = result['offset'];

      print('✅ Loaded ${result['users'].length} more students (total: ${visibleStudents.length})');
    } catch (e) {
      print('Error loading more students: $e');
      Get.snackbar(
        'Error',
        'Failed to load more students',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoadingMore(false);
    }
  }

  /// Load more instructors (next 25)
  Future<void> loadMoreInstructors() async {
    if (!hasMoreInstructors.value || isLoadingMore.value) return;

    isLoadingMore(true);

    try {
      final result = await LazyLoadingService.loadMoreUsers(
        schoolId: _schoolId,
        offset: _instructorsOffset,
        role: 'instructor',
      );

      visibleInstructors.addAll(result['users']);
      hasMoreInstructors.value = result['hasMore'];
      _instructorsOffset = result['offset'];

      print('✅ Loaded ${result['users'].length} more instructors (total: ${visibleInstructors.length})');
    } catch (e) {
      print('Error loading more instructors: $e');
      Get.snackbar(
        'Error',
        'Failed to load more instructors',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoadingMore(false);
    }
  }

  /// Search users using lazy loading service
  Future<void> searchUsersLazy(String query, {String? role}) async {
    searchQuery.value = query;
    if (query.isEmpty) {
      searchedUser.clear();
    } else {
      try {
        final results = await LazyLoadingService.searchUsers(
          query: query,
          schoolId: _schoolId,
          role: role,
          limit: 50,
        );
        searchedUser.assignAll(results);
      } catch (e) {
        print('Error searching users: $e');
      }
    }
  }

  /// Refresh all users data
  Future<void> refreshUsers({String? role}) async {
    if (role == 'student') {
      _studentsOffset = 0;
      hasMoreStudents.value = true;
      await _loadInitialStudents();
    } else if (role == 'instructor') {
      _instructorsOffset = 0;
      hasMoreInstructors.value = true;
      await _loadInitialInstructors();
    } else {
      _usersOffset = 0;
      hasMoreUsers.value = true;
      await _loadInitialUsers();
    }
  }

  /// Legacy method - now uses lazy loading under the hood
  Future<List<User>> fetchUsers({String? role}) async {
    print('UserController: fetchUsers called with role: $role (redirecting to lazy loading)');

    try {
      isLoading(true);
      error('');

      // Load based on role
      if (role == 'student') {
        await _loadInitialStudents();
        _lastFetchedRole = role;
        return visibleStudents;
      } else if (role == 'instructor') {
        await _loadInitialInstructors();
        _lastFetchedRole = role;
        return visibleInstructors;
      } else {
        await _loadInitialUsers();
        _lastFetchedRole = role;
        return visibleUsers;
      }
    } catch (e) {
      error(e.toString());
      print('UserController: Error fetching users - ${e.toString()}');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Unable to Load Users',
        'Could not load the user list. Please check your connection and try again.',
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
      if (isUpdate && user.id != null) {
        await _handleUserUpdate(user);
        return;
      }
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
        snackPosition: SnackPosition.BOTTOM,
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

  String _parseError(String error) {
    if (error.contains('UNIQUE constraint failed: users.email')) {
      return 'This email address is already registered. Please use a different email.';
    } else if (error.contains('UNIQUE constraint failed: users.phone')) {
      return 'This phone number is already registered. Please use a different phone number.';
    } else if (error.contains('UNIQUE constraint failed: users.idnumber')) {
      return 'This ID number is already registered. Please use a different ID number.';
    } else if (error.toLowerCase().contains('null')) {
      return 'Some required information is missing. Please fill in all required fields.';
    } else if (error.contains('Failed to save user')) {
      return 'Could not save the user. Please check your information and try again.';
    } else {
      return 'Something went wrong while saving. Please check your information and try again.';
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

  Future<void> _handleUserUpdate(User user) async {
    final duplicateErrors = await checkForDuplicates(user, isUpdate: true);
    if (duplicateErrors.isNotEmpty) {
      final errorMessage = duplicateErrors.values.first;
      throw Exception(errorMessage);
    }

    User userToUpdate = user;

    if (user.schoolId == null || user.schoolId!.isEmpty) {
      final authController = Get.find<AuthController>();
      final currentSchoolId = authController.currentUser.value?.schoolId ?? '1';

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

    final userMap = userToUpdate.toJson();

    if (userMap['school_id'] == null) {
      userMap['school_id'] = '1';
      print('⚠️ Applied fallback school_id: 1');
    }

    print('📝 Updating user with school_id: ${userMap['school_id']}');

    await DatabaseHelper.instance.updateUser(userMap);

    await SyncService.trackChange('users', userMap, 'update');
    print('📝 Tracked user update for sync');

    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = userToUpdate;
    }

    print('✅ User updated locally successfully');

    Get.snackbar(
      snackPosition: SnackPosition.BOTTOM,
      'Success',
      '${user.fname} ${user.lname} updated successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _handleNewUserCreation(User user) async {
    final duplicateErrors = await checkForDuplicates(user, isUpdate: false);
    if (duplicateErrors.isNotEmpty) {
      final errorMessages = duplicateErrors.values.join('\n');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Duplicate Information',
        errorMessages,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      throw Exception(duplicateErrors.values.first);
    }
    final authController = Get.find<AuthController>();
    final currentSchoolId = authController.currentUser.value?.schoolId ?? '1';
    final userWithSchool = user.copyWith(schoolId: currentSchoolId);
    print('💾 Saving to local database...');

    final userMap = userWithSchool.toJson();
    final newUserId = await DatabaseHelper.instance.insertUser(userMap);

    final createdUser = userWithSchool.copyWith(id: newUserId);

    await SyncService.trackChange('users', createdUser.toJson(), 'create');
    print('📝 Tracked user creation for sync');

    _users.add(createdUser);
    print('✅ User saved locally with ID: $newUserId');
    Get.snackbar(
      snackPosition: SnackPosition.BOTTOM,
      'Success',
      '${user.fname} ${user.lname} saved successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    print('✅ User creation completed');
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
        snackPosition: SnackPosition.BOTTOM,
        'Success',
        '${userToDelete.fname} ${userToDelete.lname != 'User' ? userToDelete.lname : ''} deleted successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      error(e.toString());
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Unable to Delete',
        'Could not delete the user. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
        await SyncService.trackChange('users', {'id': id}, 'delete');
        print('📝 Tracked user deletion for sync: $id');

        await DatabaseHelper.instance.deleteUser(id);
        _users.removeWhere((user) => user.id == id);
      }

      selectedUser.clear();
      isMultiSelectionActive.value = false;
      isAllSelected(false);

      print('UserController: Successfully deleted ${userIds.length} users');

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
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
        snackPosition: SnackPosition.BOTTOM,
        'Unable to Delete Users',
        'Could not delete the selected users. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      rethrow;
    } finally {
      isLoading(false);
    }
  }

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
