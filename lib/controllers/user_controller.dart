import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/models/user.dart' as firebase_auth;
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
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

  // Add this to your UserController class in lib/controllers/user_controller.dart

  /// Batch create Firebase Authentication for existing local users
  Future<void> batchCreateFirebaseAuthForExistingUsers() async {
    try {
      isLoading(true);

      // Get all users from local database that haven't been synced to Firebase Auth
      final allUsers = await DatabaseHelper.instance.getUsers();
      final usersToSync = allUsers.where((userData) {
        final firebaseSynced = userData['firebase_synced'] ?? 0;
        return firebaseSynced == 0; // Users not synced to Firebase
      }).toList();

      print(
          '🔄 Found ${usersToSync.length} users to sync to Firebase Authentication');

      if (usersToSync.isEmpty) {
        Get.snackbar(
          'Sync Complete',
          'All users are already synced to Firebase Authentication',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return;
      }

      final authController = Get.find<AuthController>();
      int successCount = 0;
      int failCount = 0;

      for (final userData in usersToSync) {
        try {
          final user = User.fromJson(userData);

          // Convert to map for Firebase
          final userDataMap = {
            'id': user.id,
            'fname': user.fname,
            'lname': user.lname,
            'email': user.email,
            'phone': user.phone,
            'address': user.address,
            'gender': user.gender,
            'idnumber': user.idnumber,
            'role': user.role,
            'status': user.status,
            'date_of_birth': user.date_of_birth?.toIso8601String(),
            'created_at': user.created_at?.toIso8601String(),
          };

          print('🔥 Creating Firebase Auth for: ${user.email}');

          final success =
              await authController.createFirebaseUserForExistingLocal(
            user.email,
            user.password,
            userDataMap,
          );

          if (success) {
            successCount++;
            print('✅ Firebase Auth created for: ${user.email}');
          } else {
            failCount++;
            print('❌ Failed to create Firebase Auth for: ${user.email}');
          }

          // Small delay to avoid rate limiting
          await Future.delayed(Duration(milliseconds: 500));
        } catch (e) {
          failCount++;
          print('❌ Error processing user ${userData['email']}: $e');
        }
      }

      // Show results
      Get.snackbar(
        'Sync Complete',
        'Firebase Authentication created for $successCount users. $failCount failed.',
        backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );

      print(
          '🏁 Batch sync completed: $successCount success, $failCount failed');
    } catch (e) {
      error(e.toString());
      Get.snackbar(
        'Sync Error',
        'Failed to sync users to Firebase Authentication: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  /// Method to manually trigger Firebase Auth creation for a specific user
  Future<bool> createFirebaseAuthForUser(User user) async {
    try {
      final authController = Get.find<AuthController>();

      final userData = {
        'id': user.id,
        'fname': user.fname,
        'lname': user.lname,
        'email': user.email,
        'phone': user.phone,
        'address': user.address,
        'gender': user.gender,
        'idnumber': user.idnumber,
        'role': user.role,
        'status': user.status,
        'date_of_birth': user.date_of_birth?.toIso8601String(),
        'created_at': user.created_at?.toIso8601String(),
      };

      return await authController.createFirebaseUserForExistingLocal(
        user.email,
        user.password,
        userData,
      );
    } catch (e) {
      print('❌ Error creating Firebase Auth for user: $e');
      return false;
    }
  }

  // 3. REPLACE YOUR _handleUserUpdate METHOD:
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

  /// ✅ IMMEDIATE FIX: Sync Tanaka and other unsynced users
  Future<void> fixTanakaAndOtherUsers() async {
    print('👤 === FIXING TANAKA AND OTHER UNSYNCED USERS ===');

    try {
      // Step 1: Fix mismatched documents in Firebase
      if (Get.isRegistered<FixedLocalFirstSyncService>()) {
        final syncService = Get.find<FixedLocalFirstSyncService>();
        await syncService.fixMismatchedUserDocuments();
      }

      // Step 2: Force sync to push any unsynced local users
      await forceSyncAllUsers();

      // Step 3: Refresh user list
      await fetchUsers();

      Get.snackbar(
        'Success',
        'User sync issues have been fixed. All users should now be available on all devices.',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        duration: Duration(seconds: 5),
      );
    } catch (e) {
      print('❌ Error fixing user sync: $e');
      Get.snackbar(
        'Error',
        'Failed to fix user sync: $e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: Duration(seconds: 5),
      );
    }
  }

  /// ✅ Force sync all local users to Firebase
  Future<void> forceSyncAllUsers() async {
    try {
      print('🔄 Force syncing all users...');

      final db = await DatabaseHelper.instance.database;

      // Get all users (including already synced ones to ensure consistency)
      final allUsers =
          await db.query('users', where: 'deleted IS NULL OR deleted = 0');

      print('👥 Found ${allUsers.length} users to sync');

      // Mark all as unsynced to force re-sync with correct document IDs
      for (final user in allUsers) {
        await db.update(
          'users',
          {'firebase_synced': 0},
          where: 'id = ?',
          whereArgs: [user['id']],
        );
      }

      // Trigger sync
      if (Get.isRegistered<FixedLocalFirstSyncService>()) {
        final syncService = Get.find<FixedLocalFirstSyncService>();
        await syncService.syncWithFirebase();
      }

      print('✅ All users marked for sync and sync triggered');
    } catch (e) {
      print('❌ Error force syncing users: $e');
      throw e;
    }
  }

  /// ✅ DIAGNOSTIC: Show detailed sync status for all users
  Future<void> showDetailedUserSyncStatus() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final users = await db.query('users',
          where: 'deleted IS NULL OR deleted = 0', orderBy: 'id ASC');

      print('👥 === DETAILED USER SYNC STATUS ===');
      print('Total users in local database: ${users.length}');
      print('');

      for (final user in users) {
        final id = user['id'];
        final name = '${user['fname']} ${user['lname']}';
        final email = user['email'];
        final synced = user['firebase_synced'] == 1;
        final lastModified = user['last_modified'];

        print('👤 User ID $id: $name');
        print('   Email: $email');
        print('   Synced: ${synced ? '✅' : '❌'}');
        print('   Last Modified:');
        print('');
      }

      // Show summary
      final syncedCount = users.where((u) => u['firebase_synced'] == 1).length;
      final unsyncedCount = users.length - syncedCount;

      print('📊 SUMMARY:');
      print('   ✅ Synced: $syncedCount');
      print('   ❌ Unsynced: $unsyncedCount');

      if (unsyncedCount > 0) {
        print('');
        print(
            '💡 To fix unsynced users, run: await userController.fixTanakaAndOtherUsers()');
      }
    } catch (e) {
      print('❌ Error showing user sync status: $e');
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

    // Step 2: Save to LOCAL database FIRST
    print('💾 Saving to local database first...');
    final newUserId = await DatabaseHelper.instance.insertUser(user);
    final createdUser = user.copyWith(id: newUserId);

    // Add to local observable list for immediate UI update
    _users.add(createdUser);
    print('✅ User saved locally with ID: $newUserId');

    // Step 3: **FIXED** - Create Firebase Authentication user AND use consistent document ID
    try {
      final authController = Get.find<AuthController>();

      print(
          '🔥 Creating Firebase Authentication user for: ${createdUser.email}');

      // Convert user to userData map for existing method
      final userData = {
        'id': createdUser.id,
        'fname': createdUser.fname,
        'lname': createdUser.lname,
        'email': createdUser.email,
        'phone': createdUser.phone,
        'address': createdUser.address,
        'gender': createdUser.gender,
        'idnumber': createdUser.idnumber,
        'role': createdUser.role,
        'status': createdUser.status,
        'date_of_birth': createdUser.date_of_birth?.toIso8601String(),
        'created_at': createdUser.created_at?.toIso8601String(),
      };

      // Use existing method but with improved Firestore saving
      final firebaseAuthCreated =
          await authController.createFirebaseUserForExistingLocal(
        createdUser.email,
        createdUser.password,
        userData,
      );

      if (firebaseAuthCreated) {
        print('✅ Firebase Authentication user created successfully');

        // Update local user to mark as firebase synced
        await DatabaseHelper.instance.database.then((db) => db.update(
              'users',
              {'firebase_synced': 1},
              where: 'id = ?',
              whereArgs: [newUserId],
            ));

        print('✅ User fully synced with Firebase');
      } else {
        print(
            '⚠️ Firebase Authentication creation failed, but user exists locally');
      }
    } catch (e) {
      print('⚠️ Firebase Authentication creation error: $e');
      // Don't fail the whole operation - user was created locally successfully
    }

    // Step 4: Show success message
    Get.snackbar(
      'Success',
      '${user.fname} ${user.lname} saved successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    print('🔄 User creation completed with Firebase Authentication attempt');
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
