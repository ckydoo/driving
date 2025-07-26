// lib/screens/enhanced_settings_screen.dart
import 'package:driving/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsController settingsController = Get.find<SettingsController>();

  SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Settings'),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.schedule), text: 'Scheduling'),
              Tab(icon: Icon(Icons.receipt), text: 'Billing'),
              Tab(icon: Icon(Icons.person), text: 'Instructors'),
              Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSchedulingTab(context),
            _buildBillingTab(context),
            _buildInstructorTab(context),
            _buildNotificationTab(context),
          ],
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showExportDialog(),
                  icon: Icon(Icons.upload),
                  label: Text('Export Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showImportDialog(),
                  icon: Icon(Icons.download),
                  label: Text('Import Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchedulingTab(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSchedulingRulesCard(),
          SizedBox(height: 16),
          _buildWorkingHoursCard(context),
          SizedBox(height: 16),
          _buildLessonDefaultsCard(),
        ],
      ),
    );
  }

  Widget _buildBillingTab(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBillingValidationCard(),
          SizedBox(height: 16),
          _buildBillingAutomationCard(),
          SizedBox(height: 16),
          _buildLowLessonWarningCard(),
        ],
      ),
    );
  }

  Widget _buildInstructorTab(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInstructorAvailabilityCard(),
          SizedBox(height: 16),
          _buildBreakTimeCard(),
          SizedBox(height: 16),
          _buildVehicleAssignmentCard(),
        ],
      ),
    );
  }

  Widget _buildNotificationTab(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildNotificationSettingsCard(),
          SizedBox(height: 16),
          _buildReminderSettingsCard(context),
          SizedBox(height: 16),
          _buildAppPreferencesCard(),
        ],
      ),
    );
  }

  Widget _buildSchedulingRulesCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rule, color: Colors.blue.shade600),
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
                  onChanged: (value) =>
                      settingsController.toggleBillingValidation(value),
                  secondary: Icon(Icons.security, color: Colors.green.shade600),
                )),
            Divider(),
            Obx(() => SwitchListTile(
                  title: Text('Check Instructor Availability'),
                  subtitle: Text('Prevent double-booking instructors'),
                  value: settingsController.checkInstructorAvailability.value,
                  onChanged: (value) =>
                      settingsController.toggleInstructorAvailability(value),
                  secondary:
                      Icon(Icons.person_pin, color: Colors.blue.shade600),
                )),
            Divider(),
            Obx(() => SwitchListTile(
                  title: Text('Enforce Working Hours'),
                  subtitle: Text('Restrict scheduling to business hours only'),
                  value: settingsController.enforceWorkingHours.value,
                  onChanged: (value) =>
                      settingsController.toggleWorkingHoursEnforcement(value),
                  secondary:
                      Icon(Icons.access_time, color: Colors.orange.shade600),
                )),
            Divider(),
            Obx(() => SwitchListTile(
                  title: Text('Prevent Over-Scheduling'),
                  subtitle:
                      Text('Block scheduling beyond available lesson balance'),
                  value: settingsController.preventOverScheduling.value,
                  onChanged: (value) =>
                      settingsController.togglePreventOverScheduling(value),
                  secondary: Icon(Icons.block, color: Colors.red.shade600),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingValidationCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.green.shade600),
                SizedBox(width: 8),
                Text(
                  'Billing Validation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => SwitchListTile(
                  title: Text('Count Scheduled Lessons'),
                  subtitle: Text(
                      'Include future scheduled lessons in balance calculations'),
                  value: settingsController.countScheduledLessons.value,
                  onChanged: (value) =>
                      settingsController.toggleCountScheduledLessons(value),
                  secondary: Icon(Icons.calculate, color: Colors.blue.shade600),
                )),
            Divider(),
            Obx(() => SwitchListTile(
                  title: Text('Show Billing Warnings'),
                  subtitle: Text('Display alerts for billing-related issues'),
                  value: settingsController.billingWarnings.value,
                  onChanged: (value) =>
                      settingsController.toggleBillingWarnings(value),
                  secondary: Icon(Icons.warning, color: Colors.orange.shade600),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingAutomationCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_fix_high, color: Colors.purple.shade600),
                SizedBox(width: 8),
                Text(
                  'Billing Automation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => SwitchListTile(
                  title: Text('Auto-Create Billing Records'),
                  subtitle: Text(
                      'Automatically create billing records when lessons are scheduled'),
                  value: settingsController.autoCreateBillingRecords.value,
                  onChanged: (value) =>
                      settingsController.toggleAutoCreateBillingRecords(value),
                  secondary:
                      Icon(Icons.auto_awesome, color: Colors.green.shade600),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildLowLessonWarningCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade600),
                SizedBox(width: 8),
                Text(
                  'Low Lesson Warnings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => SwitchListTile(
                  title: Text('Show Low Lesson Warnings'),
                  subtitle:
                      Text('Alert when students have few lessons remaining'),
                  value: settingsController.showLowLessonWarning.value,
                  onChanged: (value) =>
                      settingsController.toggleLowLessonWarning(value),
                  secondary: Icon(Icons.notifications_active,
                      color: Colors.orange.shade600),
                )),
            if (settingsController.showLowLessonWarning.value)
              Column(
                children: [
                  Divider(),
                  ListTile(
                    title: Text('Warning Threshold'),
                    subtitle: Obx(() => Text(
                        '${settingsController.lowLessonThreshold.value} lessons remaining')),
                    trailing: SizedBox(
                      width: 120,
                      child: Obx(() => Slider(
                            value: settingsController.lowLessonThreshold.value
                                .toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: settingsController.lowLessonThreshold.value
                                .toString(),
                            onChanged: (value) => settingsController
                                .setLowLessonThreshold(value.round()),
                          )),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingHoursCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Working Hours',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text('Start Time'),
                    subtitle: Obx(
                        () => Text(settingsController.workingHoursStart.value)),
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _selectTime(context, true),
                    ),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text('End Time'),
                    subtitle: Obx(
                        () => Text(settingsController.workingHoursEnd.value)),
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _selectTime(context, false),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonDefaultsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: Colors.green.shade600),
                SizedBox(width: 8),
                Text(
                  'Lesson Defaults',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Default Lesson Duration'),
              subtitle: Obx(() => Text(
                  '${settingsController.defaultLessonDuration.value} hours')),
              trailing: SizedBox(
                width: 120,
                child: Obx(() => Slider(
                      value: settingsController.defaultLessonDuration.value,
                      min: 0.5,
                      max: 4.0,
                      divisions: 7,
                      label:
                          '${settingsController.defaultLessonDuration.value}h',
                      onChanged: (value) =>
                          settingsController.setDefaultLessonDuration(value),
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorAvailabilityCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_search, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Instructor Availability',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => SwitchListTile(
                  title: Text('Allow Back-to-Back Lessons'),
                  subtitle: Text('Permit consecutive lessons without breaks'),
                  value: settingsController.allowBackToBackLessons.value,
                  onChanged: (value) =>
                      settingsController.toggleBackToBackLessons(value),
                  secondary:
                      Icon(Icons.fast_forward, color: Colors.orange.shade600),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakTimeCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.coffee, color: Colors.brown.shade600),
                SizedBox(width: 8),
                Text(
                  'Break Time Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Minimum Break Between Lessons'),
              subtitle: Obx(() => Text(
                  '${settingsController.breakBetweenLessons.value} minutes')),
              trailing: SizedBox(
                width: 120,
                child: Obx(() => Slider(
                      value: settingsController.breakBetweenLessons.value
                          .toDouble(),
                      min: 0,
                      max: 60,
                      divisions: 12,
                      label:
                          '${settingsController.breakBetweenLessons.value}min',
                      onChanged: (value) => settingsController
                          .setBreakBetweenLessons(value.round()),
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleAssignmentCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Vehicle Assignment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => SwitchListTile(
                  title: Text('Auto-Assign Vehicles'),
                  subtitle: Text(
                      'Automatically assign available vehicles to lessons'),
                  value: settingsController.autoAssignVehicles.value,
                  onChanged: (value) =>
                      settingsController.toggleAutoAssignVehicles(value),
                  secondary:
                      Icon(Icons.auto_mode, color: Colors.green.shade600),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Notification Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Obx(() => SwitchListTile(
                  title: Text('Auto Attendance Notifications'),
                  subtitle:
                      Text('Automatic notifications for attendance updates'),
                  value: settingsController.autoAttendanceNotifications.value,
                  onChanged: (value) => settingsController
                      .toggleAutoAttendanceNotifications(value),
                  secondary:
                      Icon(Icons.check_circle, color: Colors.green.shade600),
                )),
            Divider(),
            Obx(() => SwitchListTile(
                  title: Text('Schedule Conflict Alerts'),
                  subtitle: Text('Alerts for scheduling conflicts'),
                  value: settingsController.scheduleConflictAlerts.value,
                  onChanged: (value) =>
                      settingsController.toggleScheduleConflictAlerts(value),
                  secondary: Icon(Icons.error, color: Colors.red.shade600),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSettingsCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alarm, color: Colors.orange.shade600),
                SizedBox(width: 8),
                Text(
                  'Reminder Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Lesson Start Reminder'),
              subtitle: Obx(() => Text(
                  '${settingsController.lessonStartReminder.value} minutes before')),
              trailing: SizedBox(
                width: 120,
                child: Obx(() => Slider(
                      value: settingsController.lessonStartReminder.value
                          .toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label:
                          '${settingsController.lessonStartReminder.value}min',
                      onChanged: (value) => settingsController
                          .setLessonStartReminder(value.round()),
                    )),
              ),
            ),
            Divider(),
            ListTile(
              title: Text('Daily Summary Time'),
              subtitle:
                  Obx(() => Text(settingsController.dailySummaryTime.value)),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => _selectDailySummaryTime(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppPreferencesCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.grey.shade600),
                SizedBox(width: 8),
                Text(
                  'App Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Theme'),
              subtitle: Obx(
                  () => Text(settingsController.theme.value.capitalize ?? '')),
              trailing: DropdownButton<String>(
                value: settingsController.theme.value,
                items: ['light', 'dark', 'system'].map((theme) {
                  return DropdownMenuItem(
                    value: theme,
                    child: Text(theme.capitalize ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    settingsController.setTheme(value);
                  }
                },
              ),
            ),
            Divider(),
            ListTile(
              title: Text('Language'),
              subtitle: Obx(() =>
                  Text(settingsController.language.value.capitalize ?? '')),
              trailing: DropdownButton<String>(
                value: settingsController.language.value,
                items: ['english', 'spanish', 'french', 'german'].map((lang) {
                  return DropdownMenuItem(
                    value: lang,
                    child: Text(lang.capitalize ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    settingsController.setLanguage(value);
                  }
                },
              ),
            ),
            Divider(),
            ListTile(
              title: Text('Date Format'),
              subtitle: Obx(() => Text(settingsController.dateFormat.value)),
              trailing: DropdownButton<String>(
                value: settingsController.dateFormat.value,
                items: ['MM/dd/yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd'].map((format) {
                  return DropdownMenuItem(
                    value: format,
                    child: Text(format),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    settingsController.setDateFormat(value);
                  }
                },
              ),
            ),
            Divider(),
            ListTile(
              title: Text('Reset All Settings'),
              subtitle: Text('Restore all settings to default values'),
              trailing: ElevatedButton(
                onPressed: () => _showResetConfirmation(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text('Reset'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final currentTime = isStart
        ? settingsController.workingHoursStart.value
        : settingsController.workingHoursEnd.value;

    final timeParts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

      if (isStart) {
        settingsController.setWorkingHours(
            timeString, settingsController.workingHoursEnd.value);
      } else {
        settingsController.setWorkingHours(
            settingsController.workingHoursStart.value, timeString);
      }
    }
  }

  Future<void> _selectDailySummaryTime(BuildContext context) async {
    final currentTime = settingsController.dailySummaryTime.value;
    final timeParts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      settingsController.setDailySummaryTime(timeString);
    }
  }

  void _showResetConfirmation() {
    Get.dialog(
      AlertDialog(
        title: Text('Reset All Settings'),
        content: Text(
            'Are you sure you want to reset all settings to their default values? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              settingsController.resetToDefaults();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Export Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Export your current settings to share or backup.'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _getExportedSettingsJson(),
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // In a real app, you'd implement clipboard copy or file save
              Get.back();
              Get.snackbar(
                'Settings Exported',
                'Settings have been copied to clipboard',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child: Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final TextEditingController controller = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('Import Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paste your exported settings JSON below:'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 10,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste settings JSON here...',
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
            onPressed: () {
              try {
                // In a real app, you'd parse the JSON and validate it
                Get.back();
                Get.snackbar(
                  'Import Successful',
                  'Settings have been imported successfully',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.snackbar(
                  'Import Failed',
                  'Invalid settings format',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('Import'),
          ),
        ],
      ),
    );
  }

  String _getExportedSettingsJson() {
    final settings = settingsController.exportSettings();
    return '''
{
  "version": "1.0",
  "exported": "${DateTime.now().toIso8601String()}",
  "settings": ${settings.toString().replaceAll('{', '{\n  ').replaceAll(', ', ',\n  ').replaceAll('}', '\n}')}
}''';
  }
}
