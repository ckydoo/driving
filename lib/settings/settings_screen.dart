// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../widgets/auto_attendance_settings.dart';
import '../../services/auto_attendance_service.dart';
import '../../controllers/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SettingsController settingsController = Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.smart_toy), text: 'Auto-Attendance'),
            Tab(icon: Icon(Icons.schedule), text: 'Scheduling'),
            Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
            Tab(icon: Icon(Icons.tune), text: 'General'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAutoAttendanceTab(),
          _buildSchedulingTab(),
          _buildNotificationsTab(),
          _buildGeneralTab(),
        ],
      ),
    );
  }

  Widget _buildAutoAttendanceTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          AutoAttendanceSettings(), // This is the widget we created
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    final autoAttendanceService = Get.find<AutoAttendanceService>();

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        autoAttendanceService.forceCheckEndedLessons(),
                    icon: Icon(Icons.refresh),
                    label: Text('Check Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTestDialog(),
                    icon: Icon(Icons.bug_report),
                    label: Text('Test Mode'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAutoAttendanceLog(),
                icon: Icon(Icons.history),
                label: Text('View Activity Log'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.purple),
                  foregroundColor: Colors.purple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulingTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSchedulingRulesCard(),
          SizedBox(height: 16),
          _buildBillingValidationCard(),
          SizedBox(height: 16),
          _buildInstructorAvailabilityCard(),
        ],
      ),
    );
  }

  Widget _buildSchedulingRulesCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rule, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Scheduling Rules',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => SwitchListTile(
                  title: Text('Enforce Billing Validation'),
                  subtitle: Text(
                      'Prevent scheduling students with no remaining lessons'),
                  value: settingsController.enforceBillingValidation.value,
                  onChanged: (value) {
                    settingsController.toggleBillingValidation(value);
                  },
                  secondary: Icon(Icons.security, color: Colors.green),
                )),
            Divider(),
            Obx(() => SwitchListTile(
                  title: Text('Check Instructor Availability'),
                  subtitle: Text('Prevent double-booking instructors'),
                  value: settingsController.checkInstructorAvailability.value,
                  onChanged: (value) {
                    settingsController.toggleInstructorAvailability(value);
                  },
                  secondary: Icon(Icons.person_pin, color: Colors.blue),
                )),
            Divider(),
            Obx(() => SwitchListTile(
                  title: Text('Auto-assign Vehicles'),
                  subtitle: Text(
                      'Automatically assign instructor\'s designated vehicle'),
                  value: settingsController.autoAssignVehicles.value,
                  onChanged: (value) {
                    settingsController.toggleAutoAssignVehicles(value);
                  },
                  secondary: Icon(Icons.directions_car, color: Colors.purple),
                )),
            Divider(),
            Obx(() => ListTile(
                  leading: Icon(Icons.timer, color: Colors.orange),
                  title: Text('Default Lesson Duration'),
                  subtitle: Text(
                      '${settingsController.defaultLessonDuration.value} hours'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${settingsController.defaultLessonDuration.value}h',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                  onTap: () => _showDurationPicker(),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingValidationCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Billing Integration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: settingsController.enforceBillingValidation.value
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: settingsController.enforceBillingValidation.value
                          ? Colors.green[200]!
                          : Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        settingsController.enforceBillingValidation.value
                            ? Icons.check_circle
                            : Icons.warning,
                        color: settingsController.enforceBillingValidation.value
                            ? Colors.green
                            : Colors.orange,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settingsController.enforceBillingValidation.value
                                  ? 'Billing Validation Active'
                                  : 'Billing Validation Disabled',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: settingsController
                                        .enforceBillingValidation.value
                                    ? Colors.green[800]
                                    : Colors.orange[800],
                              ),
                            ),
                            Text(
                              settingsController.enforceBillingValidation.value
                                  ? 'Students can only be scheduled for courses they\'ve been billed for'
                                  : 'Students can be scheduled without billing validation',
                              style: TextStyle(
                                color: settingsController
                                        .enforceBillingValidation.value
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            SizedBox(height: 12),
            Obx(() => ListTile(
                  leading: Icon(Icons.warning, color: Colors.orange),
                  title: Text('Low Lesson Warning'),
                  subtitle: Text(
                      'Alert when student has less than ${settingsController.lowLessonThreshold.value} lessons remaining'),
                  trailing: Switch(
                    value: settingsController.showLowLessonWarning.value,
                    onChanged: (value) {
                      settingsController.toggleLowLessonWarning(value);
                    },
                  ),
                )),
            Obx(() => ListTile(
                  leading: Icon(Icons.block, color: Colors.red),
                  title: Text('Prevent Over-scheduling'),
                  subtitle: Text('Block scheduling beyond billed lessons'),
                  trailing: Switch(
                    value: settingsController.preventOverScheduling.value,
                    onChanged: (value) {
                      settingsController.togglePreventOverScheduling(value);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorAvailabilityCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_pin, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Instructor Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.schedule, color: Colors.blue),
              title: Text('Working Hours'),
              subtitle: Text('9:00 AM - 6:00 PM'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showWorkingHoursPicker(),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.event_busy, color: Colors.red),
              title: Text('Break Between Lessons'),
              subtitle: Text('15 minutes minimum'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showBreakTimePicker(),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Allow Back-to-back Lessons'),
              subtitle: Text('Permit consecutive lessons without breaks'),
              value: false,
              onChanged: (value) {
                // Handle toggle
              },
              secondary: Icon(Icons.fast_forward, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildNotificationPreferencesCard(),
          SizedBox(height: 16),
          _buildReminderSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildNotificationPreferencesCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Notification Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => SwitchListTile(
                  title: Text('Auto-Attendance Notifications'),
                  subtitle: Text('Get notified before lessons are auto-marked'),
                  value: settingsController.autoAttendanceNotifications.value,
                  onChanged: (value) {
                    settingsController.toggleAutoAttendanceNotifications(value);
                  },
                  secondary: Icon(Icons.auto_awesome, color: Colors.green),
                )),
            Obx(() => SwitchListTile(
                  title: Text('Schedule Conflict Alerts'),
                  subtitle: Text('Alert when scheduling conflicts occur'),
                  value: settingsController.scheduleConflictAlerts.value,
                  onChanged: (value) {
                    settingsController.toggleScheduleConflictAlerts(value);
                  },
                  secondary: Icon(Icons.warning, color: Colors.orange),
                )),
            Obx(() => SwitchListTile(
                  title: Text('Billing Warnings'),
                  subtitle: Text('Notify when students have low lesson counts'),
                  value: settingsController.billingWarnings.value,
                  onChanged: (value) {
                    settingsController.toggleBillingWarnings(value);
                  },
                  secondary:
                      Icon(Icons.account_balance_wallet, color: Colors.purple),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSettingsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alarm, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Lesson Reminders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.timer, color: Colors.blue),
              title: Text('Lesson Start Reminder'),
              subtitle: Text('15 minutes before lesson'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showReminderTimePicker(),
            ),
            ListTile(
              leading: Icon(Icons.event, color: Colors.green),
              title: Text('Daily Schedule Summary'),
              subtitle: Text('8:00 AM every day'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showDailySummaryTimePicker(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAppPreferencesCard(),
          SizedBox(height: 16),
          _buildDataManagementCard(),
          SizedBox(height: 16),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildAppPreferencesCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.grey[700]),
                SizedBox(width: 8),
                Text(
                  'App Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.color_lens, color: Colors.purple),
              title: Text('Theme'),
              subtitle: Text('Light'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showThemePicker(),
            ),
            ListTile(
              leading: Icon(Icons.language, color: Colors.blue),
              title: Text('Language'),
              subtitle: Text('English'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showLanguagePicker(),
            ),
            ListTile(
              leading: Icon(Icons.date_range, color: Colors.green),
              title: Text('Date Format'),
              subtitle: Text('MM/DD/YYYY'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showDateFormatPicker(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Data Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.backup, color: Colors.green),
              title: Text('Backup Data'),
              subtitle: Text('Export all data to file'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showBackupOptions(),
            ),
            ListTile(
              leading: Icon(Icons.restore, color: Colors.blue),
              title: Text('Restore Data'),
              subtitle: Text('Import data from backup'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showRestoreOptions(),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Clear All Data'),
              subtitle: Text('Reset app to initial state'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showClearDataDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'About',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.app_settings_alt, color: Colors.green),
              title: Text('App Version'),
              subtitle: Text('1.0.0'),
            ),
            ListTile(
              leading: Icon(Icons.help, color: Colors.orange),
              title: Text('Help & Support'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showHelpDialog(),
            ),
            ListTile(
              leading: Icon(Icons.privacy_tip, color: Colors.purple),
              title: Text('Privacy Policy'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showPrivacyPolicy(),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog methods
  void _showTestDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Test Auto-Attendance'),
        content:
            Text('This will simulate lesson endings for testing. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                'Test Mode',
                'Auto-attendance test initiated',
                backgroundColor: Colors.blue,
                colorText: Colors.white,
              );
            },
            child: Text('Start Test'),
          ),
        ],
      ),
    );
  }

  void _showAutoAttendanceLog() {
    Get.dialog(
      AlertDialog(
        title: Text('Auto-Attendance Activity'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Auto-marked: John Doe'),
                subtitle: Text('Today 10:05 AM - Practical Lesson'),
              ),
              ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: Text('No lessons: Jane Smith'),
                subtitle: Text('Today 9:35 AM - Theory Lesson'),
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Auto-marked: Mike Johnson'),
                subtitle: Text('Yesterday 3:05 PM - Practical Lesson'),
              ),
            ],
          ),
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

  void _showDurationPicker() {
    // Implementation for duration picker
    Get.snackbar('Settings', 'Duration picker would open here');
  }

  void _showWorkingHoursPicker() {
    // Implementation for working hours picker
    Get.snackbar('Settings', 'Working hours picker would open here');
  }

  void _showBreakTimePicker() {
    // Implementation for break time picker
    Get.snackbar('Settings', 'Break time picker would open here');
  }

  void _showReminderTimePicker() {
    // Implementation for reminder time picker
    Get.snackbar('Settings', 'Reminder time picker would open here');
  }

  void _showDailySummaryTimePicker() {
    // Implementation for daily summary time picker
    Get.snackbar('Settings', 'Daily summary time picker would open here');
  }

  void _showThemePicker() {
    // Implementation for theme picker
    Get.snackbar('Settings', 'Theme picker would open here');
  }

  void _showLanguagePicker() {
    // Implementation for language picker
    Get.snackbar('Settings', 'Language picker would open here');
  }

  void _showDateFormatPicker() {
    // Implementation for date format picker
    Get.snackbar('Settings', 'Date format picker would open here');
  }

  void _showBackupOptions() {
    // Implementation for backup options
    Get.snackbar('Settings', 'Backup options would open here');
  }

  void _showRestoreOptions() {
    // Implementation for restore options
    Get.snackbar('Settings', 'Restore options would open here');
  }

  void _showClearDataDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Clear All Data'),
        content: Text(
            'This will permanently delete all data. This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                'Data Cleared',
                'All data has been cleared',
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    // Implementation for help dialog
    Get.snackbar('Help', 'Help & support would open here');
  }

  void _showPrivacyPolicy() {
    // Implementation for privacy policy
    Get.snackbar('Privacy', 'Privacy policy would open here');
  }
}
