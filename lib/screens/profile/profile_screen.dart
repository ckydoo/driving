// lib/screens/profile/profile_screen.dart
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/widgets/change_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        final user = authController.currentUser.value;

        if (user == null) {
          return const Center(
            child: Text('No user data available'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Profile Header
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade600,
                        Colors.blue.shade800,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          '${user.fname[0]}${user.lname[0]}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name
                      Text(
                        '${user.fname} ${user.lname}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Personal Information
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Email', user.email, Icons.email),
                      _buildInfoRow('Phone', user.phone, Icons.phone),
                      _buildInfoRow('ID Number', user.idnumber, Icons.badge),
                      _buildInfoRow(
                          'Gender', user.gender, Icons.person_outline),
                      _buildInfoRow(
                        'Date of Birth',
                        DateFormat('MMM dd, yyyy').format(user.date_of_birth),
                        Icons.cake,
                      ),
                      _buildInfoRow('Address', user.address, Icons.location_on),
                      _buildInfoRow(
                        'Status',
                        user.status,
                        Icons.info,
                        statusColor: user.status.toLowerCase() == 'active'
                            ? Colors.green
                            : Colors.red,
                      ),
                      _buildInfoRow(
                        'Member Since',
                        DateFormat('MMM dd, yyyy').format(user.created_at),
                        Icons.schedule,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Account Actions
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.settings, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          const Text(
                            'Account Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Change Password Button
                      ListTile(
                        leading: Icon(
                          Icons.lock_outline,
                          color: Colors.blue.shade600,
                        ),
                        title: const Text('Change Password'),
                        subtitle: const Text('Update your account password'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Get.dialog(const ChangePasswordDialog());
                        },
                      ),

                      const Divider(),

                      // Edit Profile Button (if you want to add this feature)
                      ListTile(
                        leading: Icon(
                          Icons.edit,
                          color: Colors.blue.shade600,
                        ),
                        title: const Text('Edit Profile'),
                        subtitle:
                            const Text('Update your personal information'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // TODO: Implement edit profile functionality
                          Get.snackbar(
                            'Coming Soon',
                            'Profile editing will be available in the next update',
                            backgroundColor: Colors.blue.shade100,
                            colorText: Colors.blue.shade800,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(authController),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: statusColor ?? Colors.black87,
                    fontWeight: statusColor != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
// Enhanced Logout Dialog - Replace your existing _showLogoutDialog method

  void _showLogoutDialog(AuthController authController) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout,
              color: Colors.red.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirm Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to logout?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Internet connectivity warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.wifi_off,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Internet Required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You may need internet connection to log back in to your account.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sync status info (if applicable)
            Obx(() {
              final syncService = Get.find<FixedLocalFirstSyncService>();
              final isSyncing = syncService.isSyncing.value;
              final isOnline = syncService.isOnline.value;

              if (isSyncing) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Data is currently syncing...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else if (!isOnline) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(
                          color: Colors.red.shade200,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_off,
                            color: Colors.red.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Currently offline - some data may not be synced.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            }),
          ],
        ),
        actions: [
          // Cancel Button
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Logout Button
          Obx(() {
            final syncService = Get.find<FixedLocalFirstSyncService>();
            final isSyncing = syncService.isSyncing.value;

            return ElevatedButton.icon(
              onPressed: isSyncing
                  ? null // Disable if syncing
                  : () async {
                      Get.back(); // Close dialog
                      await _performEnhancedLogout(authController, syncService);
                    },
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.logout),
              label: Text(isSyncing ? 'Syncing...' : 'Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isSyncing ? Colors.grey.shade400 : Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ],
      ),
      barrierDismissible: false, // Prevent accidental dismissal
    );
  }

// Enhanced logout method with proper sync handling
  Future<void> _performEnhancedLogout(
    AuthController authController,
    FixedLocalFirstSyncService syncService,
  ) async {
    try {
      // Show loading dialog
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Logging out...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Finalizing data sync',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Step 1: Try to complete any pending sync (with timeout)
      if (syncService.firebaseAvailable.value && syncService.isOnline.value) {
        try {
          print('🔄 Attempting final sync before logout...');

          // Set a reasonable timeout for final sync
          await syncService.triggerManualSync().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⚠️ Final sync timed out - proceeding with logout');
            },
          );

          print('✅ Final sync completed');
        } catch (e) {
          print('⚠️ Final sync failed: $e - proceeding with logout');
        }
      }

      // Step 2: Perform the actual logout
      await authController.signOut();

      // Step 3: Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      // Step 4: Show success message
      Get.snackbar(
        'Logged Out',
        'You have been successfully logged out',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        icon: Icon(
          Icons.check_circle,
          color: Colors.green.shade600,
        ),
        duration: const Duration(seconds: 2),
      );

      // Step 5: Navigate to login
      Get.offAllNamed('/login');
    } catch (e) {
      print('❌ Error during logout: $e');

      // Close loading dialog on error
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      // Show error message
      Get.snackbar(
        'Logout Error',
        'Failed to logout properly: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        icon: Icon(
          Icons.error,
          color: Colors.red.shade600,
        ),
        duration: const Duration(seconds: 4),
      );
    }
  }
}
