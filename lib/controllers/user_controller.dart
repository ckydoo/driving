import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
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

  // lib/controllers/user_controller.dart - LOCAL FIRST approach with Firebase sync

  /// ENHANCED handleUser method - LOCAL FIRST approach
  Future<void> handleUser(User user, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      error('');

      print(
          'UserController: ${isUpdate ? 'Updating' : 'Adding'} user (LOCAL FIRST): ${user.fname} ${user.lname}');

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
          'UserController: Error ${isUpdate ? 'updating' : 'adding'} user - ${e.toString()}');

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

  /// Handle user updates (always local first)
  Future<void> _handleUserUpdate(User user) async {
    // Check for duplicates first (excluding the current user)
    final duplicateErrors = await checkForDuplicates(user, isUpdate: true);
    if (duplicateErrors.isNotEmpty) {
      final errorMessage = duplicateErrors.values.first;
      throw Exception(errorMessage);
    }

    // Update in local database FIRST
    await DatabaseHelper.instance.updateUser(user);

    // Update the user in the local observable list
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
    }

    print('✅ User updated locally successfully');

    Get.snackbar(
      'Success',
      '${user.fname} ${user.lname} updated successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    // Try to sync to Firebase in background (non-blocking)
    _syncToFirebaseInBackground(user, isUpdate: true);
  }

  /// Handle new user creation - LOCAL FIRST approach
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

    // Step 2: Save to LOCAL database FIRST (this always succeeds)
    print('💾 Saving to local database first...');

    final newUserId = await DatabaseHelper.instance.insertUser(user);
    final createdUser = user.copyWith(id: newUserId);

    // Add to local observable list for immediate UI update
    _users.add(createdUser);

    print('✅ User saved locally with ID: $newUserId');

    // Step 3: Show success message immediately (based on local save)
    Get.snackbar(
      'Success',
      '${user.fname} ${user.lname} saved successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    // Step 4: Try to sync to Firebase in background (non-blocking)
    _syncToFirebaseInBackground(createdUser, isUpdate: false);
  }

  /// Sync user to Firebase in background (non-blocking)
  Future<void> _syncToFirebaseInBackground(User user,
      {required bool isUpdate}) async {
    try {
      // Don't block the UI - run in background
      Future.delayed(const Duration(milliseconds: 500), () async {
        await _attemptFirebaseSync(user, isUpdate: isUpdate);
      });
    } catch (e) {
      print('⚠️ Background Firebase sync scheduling failed: $e');
      // Don't throw - this shouldn't break the user experience
    }
  }

  /// Attempt to sync user to Firebase (background operation)
  Future<void> _attemptFirebaseSync(User user, {required bool isUpdate}) async {
    try {
      print('🔄 Attempting Firebase sync for user: ${user.email}');

      // Check if Firebase is available
      if (!_authController.firebaseAvailable.value) {
        print('⚠️ Firebase not available - user saved locally only');
        _showSyncStatusNotification(
            'User saved locally. Will sync when online.',
            isWarning: true);
        return;
      }

      if (isUpdate) {
        // For updates, just trigger general sync
        await _triggerFirebaseSync();
        print('✅ Update sync triggered');
      } else {
        // For new users, create Firebase auth + sync
        await _createFirebaseAuthAndSync(user);
      }
    } catch (e) {
      print('⚠️ Firebase sync failed: $e');
      _showSyncStatusNotification(
          'User saved locally. Sync failed: ${e.toString()}',
          isWarning: true);
      // Don't throw - local save already succeeded
    }
  }

  /// Create Firebase Authentication account and sync for new users
  Future<void> _createFirebaseAuthAndSync(User user) async {
    try {
      print('🔥 Creating Firebase Authentication account...');

      // Try to create Firebase auth user
      final firebaseSuccess =
          await _authController.createFirebaseUserForExistingLocal(
        user.email,
        user.password,
        user.toJson(),
      );

      if (firebaseSuccess) {
        print('✅ Firebase user created and synced successfully');
        _showSyncStatusNotification('User synced to cloud successfully!',
            isWarning: false);

        // Update local user to mark as Firebase synced
        await _markUserAsSynced(user.id!);
      } else {
        print('⚠️ Firebase user creation failed');
        _showSyncStatusNotification('User saved locally. Cloud sync failed.',
            isWarning: true);
      }
    } catch (e) {
      print('❌ Error creating Firebase user: $e');

      if (e.toString().contains('email-already-in-use')) {
        print('ℹ️ Email already exists in Firebase - just triggering sync');
        await _triggerFirebaseSync();
        _showSyncStatusNotification('User synced to existing cloud account!',
            isWarning: false);
      } else {
        _showSyncStatusNotification(
            'User saved locally. Cloud sync failed: ${e.toString()}',
            isWarning: true);
      }
    }
  }

  /// Mark user as synced in local database
  Future<void> _markUserAsSynced(int userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'users',
        {
          'firebase_synced': 1,
          'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      print('✅ User marked as Firebase synced');
    } catch (e) {
      print('⚠️ Could not mark user as synced: $e');
    }
  }

  /// Trigger Firebase sync service
  Future<void> _triggerFirebaseSync() async {
    try {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      await syncService.triggerManualSync();
      print('✅ Firebase sync triggered successfully');
    } catch (e) {
      print('⚠️ Could not trigger Firebase sync: $e');
    }
  }

  /// Show sync status notification to user (non-intrusive)
  void _showSyncStatusNotification(String message, {required bool isWarning}) {
    // Only show sync status notifications in debug mode or for important warnings
    if (isWarning) {
      print('🔄 Sync Status: $message');

      // Show brief, non-intrusive notification
      Get.rawSnackbar(
        title: 'Sync Status',
        message: message,
        backgroundColor: Colors.orange.shade600,
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        icon: Icon(Icons.cloud_off, color: Colors.white, size: 20),
      );
    } else {
      print('✅ Sync Status: $message');

      // Show success notification briefly
      Get.rawSnackbar(
        title: 'Cloud Sync',
        message: message,
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
        icon: Icon(Icons.cloud_done, color: Colors.white, size: 20),
      );
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
