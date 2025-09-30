// lib/screens/settings/main_settings_screen.dart
import 'package:driving/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/subscription_controller.dart';
import '../../controllers/auth_controller.dart';
import 'subscription_settings_screen.dart';

class MainSettingsScreen extends StatelessWidget {
  final SettingsController settingsController = Get.find<SettingsController>();
  final SubscriptionController subscriptionController =
      Get.find<SubscriptionController>();
  final AuthController authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Subscription Section
          _buildSubscriptionSection(),
          SizedBox(height: 20),

          // App Settings
          _buildSectionHeader('App Settings'),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.palette_outlined,
              title: 'Theme',
              subtitle: 'Light, Dark, or System',
              trailing: _buildThemeDropdown(),
            ),
            _buildSettingsTile(
              icon: Icons.language_outlined,
              title: 'Language',
              subtitle: 'English',
              onTap: () => _showLanguageDialog(),
            ),
            _buildSettingsTile(
              icon: Icons.date_range_outlined,
              title: 'Date Format',
              subtitle: settingsController.dateFormat.value,
              onTap: () => _showDateFormatDialog(),
            ),
          ]),

          SizedBox(height: 20),

          // School Settings
          _buildSectionHeader('School Settings'),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.schedule_outlined,
              title: 'Working Hours',
              subtitle:
                  '${settingsController.workingHoursStart.value} - ${settingsController.workingHoursEnd.value}',
              onTap: () => _showWorkingHoursDialog(),
            ),
            _buildSettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Manage alerts and reminders',
              onTap: () => _showNotificationsSettings(),
            ),
            _buildSettingsTile(
              icon: Icons.schedule_send_outlined,
              title: 'Auto Scheduling',
              subtitle: 'Configure automatic scheduling',
              onTap: () => _showSchedulingSettings(),
            ),
          ]),

          SizedBox(height: 20),

          // Billing Settings
          _buildSectionHeader('Billing Settings'),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.warning_outlined,
              title: 'Low Lesson Warning',
              subtitle: 'Alert when lessons are low',
              trailing: Obx(() => Switch(
                    value: settingsController.showLowLessonWarning.value,
                    onChanged: settingsController.toggleLowLessonWarning,
                  )),
            ),
            _buildSettingsTile(
              icon: Icons.block_outlined,
              title: 'Prevent Over-scheduling',
              subtitle: 'Block scheduling without sufficient lessons',
              trailing: Obx(() => Switch(
                    value: settingsController.preventOverScheduling.value,
                    onChanged: settingsController.togglePreventOverScheduling,
                  )),
            ),
            _buildSettingsTile(
              icon: Icons.auto_awesome_outlined,
              title: 'Auto-create Billing Records',
              subtitle: 'Automatically track completed lessons',
              trailing: Obx(() => Switch(
                    value: settingsController.autoCreateBillingRecords.value,
                    onChanged:
                        settingsController.toggleAutoCreateBillingRecords,
                  )),
            ),
          ]),

          SizedBox(height: 20),

          // Data & Privacy
          _buildSectionHeader('Data & Privacy'),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.backup_outlined,
              title: 'Data Backup',
              subtitle: 'Automatic cloud backup',
              trailing: Obx(() => Switch(
                    value: settingsController.enableDataBackup.value,
                    onChanged: (value) => settingsController.updateSetting(
                        'enable_data_backup',
                        value,
                        settingsController.enableDataBackup),
                  )),
            ),
            _buildSettingsTile(
              icon: Icons.save_outlined,
              title: 'Auto Save',
              subtitle: 'Save changes automatically',
              trailing: Obx(() => Switch(
                    value: settingsController.enableAutoSave.value,
                    onChanged: (value) => settingsController.updateSetting(
                        'enable_auto_save',
                        value,
                        settingsController.enableAutoSave),
                  )),
            ),
            _buildSettingsTile(
              icon: Icons.download_outlined,
              title: 'Export Data',
              subtitle: 'Download your school data',
              onTap: () => _showExportDialog(),
            ),
          ]),

          SizedBox(height: 20),

          // Support & About
          _buildSectionHeader('Support & About'),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get help with DriveSync Pro',
              onTap: () => _showHelpDialog(),
            ),
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'App version and information',
              onTap: () => _showAboutDialog(),
            ),
            _buildSettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Learn about our privacy practices',
              onTap: () => _openPrivacyPolicy(),
            ),
            _buildSettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'View terms and conditions',
              onTap: () => _openTermsOfService(),
            ),
          ]),

          SizedBox(height: 40),

          // Sign Out Button
          Container(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showSignOutDialog(),
              icon: Icon(Icons.logout, color: Colors.red),
              label: Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return Obx(() {
      final status = subscriptionController.subscriptionStatus.value;
      final daysLeft = subscriptionController.remainingTrialDays.value;
      final isTrialExpiring = status == 'trial' && daysLeft <= 7;

      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: isTrialExpiring
                  ? [Colors.orange[600]!, Colors.red[600]!]
                  : status == 'active'
                      ? [Colors.green[600]!, Colors.green[700]!]
                      : [Colors.blue[600]!, Colors.blue[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      status == 'active' ? Icons.verified : Icons.access_time,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      status == 'active' ? 'Pro Subscription' : 'Free Trial',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    if (isTrialExpiring)
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.yellow[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'EXPIRING',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12),
                if (status == 'trial') ...[
                  Text(
                    'Trial ends in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _getTrialEndDate(),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ] else if (status == 'active') ...[
                  Text(
                    '\$${subscriptionController.currentPackage.value?.monthlyPrice?.toStringAsFixed(0) ?? '20'}/month',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Next billing: ${_getNextBillingDate()}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.to(() => SubscriptionScreen()),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Manage Subscription',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    if (status == 'trial') ...[
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Get.to(() => SubscriptionScreen()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: isTrialExpiring
                                ? Colors.red[600]
                                : Colors.blue[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Upgrade Now'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue[600], size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  Widget _buildThemeDropdown() {
    return Obx(() => DropdownButton<String>(
          value: settingsController.theme.value,
          underline: SizedBox.shrink(),
          items: [
            DropdownMenuItem(value: 'light', child: Text('Light')),
            DropdownMenuItem(value: 'dark', child: Text('Dark')),
            DropdownMenuItem(value: 'system', child: Text('System')),
          ],
          onChanged: (value) {
            if (value != null) {
              settingsController.updateSetting(
                  'theme', value, settingsController.theme);
            }
          },
        ));
  }

  // Helper methods for subscription info
  String _getTrialEndDate() {
    final endDate = DateTime.now()
        .add(Duration(days: subscriptionController.remainingTrialDays.value));
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[endDate.month - 1]} ${endDate.day}, ${endDate.year}';
  }

  String _getNextBillingDate() {
    final nextBilling = DateTime.now().add(Duration(days: 15)); // Placeholder
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[nextBilling.month - 1]} ${nextBilling.day}';
  }

  // Dialog methods
  void _showLanguageDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('English'),
              trailing: Icon(Icons.check, color: Colors.blue),
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateFormatDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Date Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'MM/dd/yyyy',
            'dd/MM/yyyy',
            'yyyy-MM-dd',
          ]
              .map((format) => ListTile(
                    title: Text(format),
                    trailing: settingsController.dateFormat.value == format
                        ? Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      settingsController.updateSetting(
                          'date_format', format, settingsController.dateFormat);
                      Get.back();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showWorkingHoursDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Working Hours'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start Time'),
            SizedBox(height: 8),
            Obx(() => DropdownButton<String>(
                  value: settingsController.workingHoursStart.value,
                  isExpanded: true,
                  items: _generateTimeList()
                      .map((time) =>
                          DropdownMenuItem(value: time, child: Text(time)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      settingsController.updateSetting('working_hours_start',
                          value, settingsController.workingHoursStart);
                    }
                  },
                )),
            SizedBox(height: 16),
            Text('End Time'),
            SizedBox(height: 8),
            Obx(() => DropdownButton<String>(
                  value: settingsController.workingHoursEnd.value,
                  isExpanded: true,
                  items: _generateTimeList()
                      .map((time) =>
                          DropdownMenuItem(value: time, child: Text(time)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      settingsController.updateSetting('working_hours_end',
                          value, settingsController.workingHoursEnd);
                    }
                  },
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSettings() {
    Get.dialog(
      AlertDialog(
        title: Text('Notification Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => SwitchListTile(
                  title: Text('Schedule Conflicts'),
                  subtitle: Text('Alert when scheduling conflicts occur'),
                  value: settingsController.scheduleConflictAlerts.value,
                  onChanged: (value) => settingsController.updateSetting(
                      'schedule_conflict_alerts',
                      value,
                      settingsController.scheduleConflictAlerts),
                )),
            Obx(() => SwitchListTile(
                  title: Text('Billing Warnings'),
                  subtitle: Text('Show billing-related warnings'),
                  value: settingsController.billingWarnings.value,
                  onChanged: (value) => settingsController.updateSetting(
                      'billing_warnings',
                      value,
                      settingsController.billingWarnings),
                )),
            Obx(() => SwitchListTile(
                  title: Text('Auto Attendance'),
                  subtitle: Text('Automatic attendance notifications'),
                  value: settingsController.autoAttendanceNotifications.value,
                  onChanged: (value) => settingsController.updateSetting(
                      'auto_attendance_notifications',
                      value,
                      settingsController.autoAttendanceNotifications),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSchedulingSettings() {
    Get.dialog(
      AlertDialog(
        title: Text('Auto Scheduling Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => SwitchListTile(
                  title: Text('Check Instructor Availability'),
                  subtitle:
                      Text('Verify instructor is available when scheduling'),
                  value: settingsController.checkInstructorAvailability.value,
                  onChanged: (value) => settingsController.updateSetting(
                      'check_instructor_availability',
                      value,
                      settingsController.checkInstructorAvailability),
                )),
            Obx(() => SwitchListTile(
                  title: Text('Enforce Working Hours'),
                  subtitle: Text('Only allow scheduling during working hours'),
                  value: settingsController.enforceWorkingHours.value,
                  onChanged: (value) => settingsController.updateSetting(
                      'enforce_working_hours',
                      value,
                      settingsController.enforceWorkingHours),
                )),
            Obx(() => SwitchListTile(
                  title: Text('Auto Assign Vehicles'),
                  subtitle: Text('Automatically assign available vehicles'),
                  value: settingsController.autoAssignVehicles.value,
                  onChanged: settingsController.toggleAutoAssignVehicles,
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Export Data'),
        content: Text('Choose what data you want to export:'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                'Export Started',
                'Your data export has been queued. You\'ll receive an email when it\'s ready.',
                backgroundColor: Colors.blue,
                colorText: Colors.white,
              );
            },
            child: Text('Export All Data'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.book),
              title: Text('User Guide'),
              onTap: () {
                Get.back();
                Get.snackbar(
                    'Coming Soon', 'User guide will be available soon.');
              },
            ),
            ListTile(
              leading: Icon(Icons.video_library),
              title: Text('Video Tutorials'),
              onTap: () {
                Get.back();
                Get.snackbar(
                    'Coming Soon', 'Video tutorials will be available soon.');
              },
            ),
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Contact Support'),
              onTap: () {
                Get.back();
                Get.snackbar(
                    'Contact Support', 'Email us at support@drivesyncpro.com');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('About DriveSync Pro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Build: 2024.12.15'),
            SizedBox(height: 16),
            Text(
                'DriveSync Pro is a comprehensive driving school management system designed to streamline operations and enhance learning experiences.'),
            SizedBox(height: 16),
            Text('© 2025 DriveSync Pro. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openPrivacyPolicy() {
    Get.snackbar(
      'Privacy Policy',
      'Opening privacy policy...',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _openTermsOfService() {
    Get.snackbar(
      'Terms of Service',
      'Opening terms of service...',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _showSignOutDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              authController.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  List<String> _generateTimeList() {
    List<String> times = [];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute in [0, 30]) {
        String time =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        times.add(time);
      }
    }
    return times;
  }

  Widget _buildSyncManagementSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.cloud_sync,
            title: 'Clear Pending Sync',
            subtitle: 'Clear old sync data stored locally',
            trailing: ElevatedButton.icon(
              onPressed: () => _showClearSyncDialog(),
              icon: Icon(Icons.delete_sweep, size: 20),
              label: Text('Clear'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'View Pending Changes',
            subtitle: 'See what\'s waiting to sync',
            trailing: Icon(Icons.chevron_right),
            onTap: () => _showPendingChangesInfo(),
          ),
        ],
      ),
    );
  }

  void _showClearSyncDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Clear Pending Sync?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will clear all pending sync data stored locally.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ WARNING:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Any unsynced changes will be lost. Make sure your data is already synced to the server.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[900],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back(); // Close dialog
              await _clearPendingSync();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Clear Sync Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearPendingSync() async {
    try {
      // Show loading
      Get.dialog(
        Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Clearing sync data...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Clear pending changes
      await SyncService.clearAllPendingChanges();

      // Close loading dialog
      Get.back();

      // Show success
      Get.snackbar(
        'Success',
        'Pending sync data cleared successfully',
        backgroundColor: Colors.green[100],
        colorText: Colors.green[900],
        icon: Icon(Icons.check_circle, color: Colors.green[900]),
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      // Show error
      Get.snackbar(
        'Error',
        'Failed to clear sync data: $e',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        icon: Icon(Icons.error_outline, color: Colors.red[900]),
        duration: Duration(seconds: 3),
      );
    }
  }

  Future<void> _showPendingChangesInfo() async {
    try {
      // Show loading
      Get.dialog(
        Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Get pending changes info
      final info = await SyncService.getPendingChangesInfo();

      // Close loading
      Get.back();

      // Show info dialog
      Get.dialog(
        AlertDialog(
          title: Text('Pending Sync Changes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info['has_pending'] == false) ...[
                Icon(Icons.check_circle, color: Colors.green, size: 48),
                SizedBox(height: 12),
                Text(
                  'No pending changes!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('All data is synced.'),
              ] else ...[
                Text(
                  'Total: ${info['count']} items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text('Breakdown by table:'),
                SizedBox(height: 8),
                ...((info['breakdown'] as Map<String, int>?)?.entries.map((e) =>
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${e.key}:'),
                              Text(
                                '${e.value} items',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )) ??
                    []),
              ],
            ],
          ),
          actions: [
            if (info['has_pending'] == true)
              TextButton(
                onPressed: () {
                  Get.back();
                  _showClearSyncDialog();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: Text('Clear This Data'),
              ),
            ElevatedButton(
              onPressed: () => Get.back(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to get pending changes info: $e',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    }
  }
}
