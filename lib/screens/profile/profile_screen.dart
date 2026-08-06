import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/screens/auth/enhanced_pin_login_screen.dart';
import 'package:driving/screens/auth/pin_setup_screen.dart';
import 'package:driving/widgets/change_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatelessWidget {
  final bool embeddedInShell;
  final VoidCallback? onClose;

  const ProfileScreen({
    Key? key,
    this.embeddedInShell = false,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: embeddedInShell
          ? null
          : AppBar(
              title: const Text(
                'My Profile',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              elevation: 0,
              leading: onClose != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onClose,
                    )
                  : null,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.primary.withOpacity(0.82)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.24),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        '${user.fname[0]}${user.lname[0]}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${user.fname} ${user.lname}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
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
                          Icon(Icons.person, color: cs.primary),
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
                      _buildInfoRow(context, 'Email', user.email, Icons.email),
                      _buildInfoRow(context, 'Phone', user.phone, Icons.phone),
                      _buildInfoRow(
                          context, 'ID Number', user.idnumber, Icons.badge),
                      _buildInfoRow(
                          context, 'Gender', user.gender, Icons.person_outline),
                      _buildInfoRow(
                        context,
                        'Date of Birth',
                        DateFormat('MMM dd, yyyy').format(user.date_of_birth),
                        Icons.cake,
                      ),
                      _buildInfoRow(
                          context, 'Address', user.address, Icons.location_on),
                      _buildInfoRow(
                        context,
                        'Status',
                        user.status,
                        Icons.info,
                        statusColor: user.status.toLowerCase() == 'active'
                            ? cs.primary
                            : cs.error,
                      ),
                      _buildInfoRow(
                        context,
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
                          Icon(Icons.settings, color: cs.primary),
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
                          color: cs.primary,
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
                          Icons.pin,
                          color: cs.primary,
                        ),
                        title: const Text('Change Pin'),
                        subtitle: const Text('Update your account pin'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Get.to(const PinSetupScreen());
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? statusColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: cs.onSurfaceVariant,
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
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: statusColor ?? cs.onSurface,
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
}
