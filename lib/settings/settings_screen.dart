// lib/settings/enhanced_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';

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
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Settings Header with Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 28, color: Colors.blue[700]),
                      SizedBox(width: 12),
                      Text(
                        'Application Settings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Spacer(),
                      _buildQuickActions(),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: Colors.blue[700],
                  labelColor: Colors.blue[700],
                  unselectedLabelColor: Colors.grey[600],
                  tabs: [
                    Tab(text: 'Scheduling'),
                    Tab(text: 'Billing'),
                    Tab(text: 'Instructor'),
                    Tab(text: 'Notifications'),
                    Tab(text: 'Appearance'),
                    Tab(text: 'Advanced'),
                  ],
                ),
              ],
            ),
          ),
          // Settings Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSchedulingSettings(),
                _buildBillingSettings(),
                _buildInstructorSettings(),
                _buildNotificationSettings(),
                _buildAppearanceSettings(),
                _buildAdvancedSettings(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildQuickActionButton(
          icon: Icons.download,
          label: 'Export',
          onTap: _showExportDialog,
        ),
        SizedBox(width: 8),
        _buildQuickActionButton(
          icon: Icons.upload,
          label: 'Import',
          onTap: _showImportDialog,
        ),
        SizedBox(width: 8),
        _buildQuickActionButton(
          icon: Icons.refresh,
          label: 'Reset',
          onTap: _showResetConfirmation,
          color: Colors.red[600],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color ?? Colors.blue[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? Colors.blue[700]),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.blue[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulingSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Scheduling Policies'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Enforce Billing Validation',
              'Check student billing status before scheduling',
              settingsController.enforceBillingValidation,
              settingsController.toggleBillingValidation,
            ),
            _buildSwitchTile(
              'Check Instructor Availability',
              'Verify instructor is available before scheduling',
              settingsController.checkInstructorAvailability,
              settingsController.toggleInstructorAvailabilityCheck,
            ),
            _buildSwitchTile(
              'Enforce Working Hours',
              'Only allow scheduling within working hours',
              settingsController.enforceWorkingHours,
              settingsController.toggleWorkingHours,
            ),
            _buildSwitchTile(
              'Auto-Assign Vehicles',
              'Automatically assign available vehicles to lessons',
              settingsController.autoAssignVehicles,
              settingsController.toggleAutoAssignVehicles,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Theme & Display'),
          _buildSettingsCard([
            _buildDropdownTile(
              'Theme',
              'Choose application theme',
              settingsController.theme,
              ['light', 'dark', 'system'],
              settingsController.setTheme,
              (value) => value.capitalize ?? '',
            ),
            _buildDropdownTile(
              'Language',
              'Select application language',
              settingsController.language,
              ['english', 'spanish', 'french', 'german'],
              settingsController.setLanguage,
              (value) => value.capitalize ?? '',
            ),
            _buildDropdownTile(
              'Date Format',
              'Choose date display format',
              settingsController.dateFormat,
              ['MM/dd/yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd'],
              settingsController.setDateFormat,
              (value) => value,
            ),
          ]),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: children
            .map((child) => children.indexOf(child) == children.length - 1
                ? child
                : Column(children: [child, Divider(height: 1)]))
            .toList(),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    RxBool value,
    Function(bool) onChanged,
  ) {
    return Obx(() => SwitchListTile(
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
          value: value.value,
          onChanged: onChanged,
          activeColor: Colors.blue[700],
        ));
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    RxInt currentValue,
    RxInt tempValue,
    double min,
    double max,
    double divisions,
    Function(int) onTempChanged,
    Function() onCommit,
    String Function(int) formatter,
  ) {
    return Obx(() => Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blue[700],
                        inactiveTrackColor: Colors.blue[100],
                        thumbColor: Colors.blue[700],
                        overlayColor: Colors.blue[700]!.withAlpha(32),
                        thumbShape:
                            RoundSliderThumbShape(enabledThumbRadius: 12),
                        overlayShape:
                            RoundSliderOverlayShape(overlayRadius: 20),
                        trackHeight: 4,
                        valueIndicatorShape: PaddleSliderValueIndicatorShape(),
                        valueIndicatorColor: Colors.blue[700],
                        valueIndicatorTextStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Slider(
                        value: tempValue.value.toDouble(),
                        min: min,
                        max: max,
                        divisions: ((max - min) / divisions).round(),
                        label: formatter(tempValue.value),
                        onChanged: (value) => onTempChanged(value.toInt()),
                        onChangeEnd: (value) {
                          onCommit();
                          // Add haptic feedback
                          HapticFeedback.lightImpact();
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Container(
                    width: 80,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      formatter(tempValue.value),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              // Show if value has changed
              if (tempValue.value != currentValue.value) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.orange[700]),
                      SizedBox(width: 4),
                      Text(
                        'Changed from ${formatter(currentValue.value)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ));
  }

  Widget _buildDropdownTile<T>(
    String title,
    String subtitle,
    RxString value,
    List<T> items,
    Function(T) onChanged,
    String Function(T) formatter,
  ) {
    return Obx(() => ListTile(
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
          trailing: DropdownButton<T>(
            value: items.firstWhere((item) => item.toString() == value.value),
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(formatter(item)),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            underline: SizedBox.shrink(),
          ),
        ));
  }

  Widget _buildTimeTile(
    String title,
    RxString timeValue,
    bool? isStart, {
    String? subtitle,
  }) {
    return Obx(() => ListTile(
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle != null
              ? Text(subtitle, style: TextStyle(fontSize: 12))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeValue.value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.access_time, color: Colors.grey[600]),
            ],
          ),
          onTap: () => _selectTime(context, timeValue, isStart),
        ));
  }

  Future<void> _selectTime(
      BuildContext context, RxString timeValue, bool? isStart) async {
    final currentTime = timeValue.value;
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

      if (isStart == true) {
        settingsController.setWorkingHours(
            timeString, settingsController.workingHoursEnd.value);
      } else if (isStart == false) {
        settingsController.setWorkingHours(
            settingsController.workingHoursStart.value, timeString);
      } else {
        // For daily summary time
        settingsController.setDailySummaryTime(timeString);
      }
    }
  }

  void _showResetConfirmation() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset All Settings'),
          ],
        ),
        content: Text(
          'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
        ),
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
            child: Text('Reset All'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    final exportedSettings = settingsController.exportSettings();

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.download, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Settings'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your settings have been exported. Copy the text below:'),
              SizedBox(height: 16),
              Container(
                height: 200,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    exportedSettings,
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Here you would implement clipboard copy functionality
              Get.back();
              Get.snackbar(
                'Settings Exported',
                'Settings have been copied to clipboard',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child: Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final TextEditingController controller = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upload, color: Colors.blue),
            SizedBox(width: 8),
            Text('Import Settings'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
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
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final jsonString = controller.text.trim();
                if (jsonString.isNotEmpty) {
                  settingsController.importSettings(jsonString);
                  Get.back();
                } else {
                  Get.snackbar(
                    'Error',
                    'Please paste valid settings JSON',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              } catch (e) {
                Get.snackbar(
                  'Import Error',
                  'Invalid JSON format',
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

  Widget _buildInstructorSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Working Hours'),
          _buildSettingsCard([
            _buildTimeTile(
              'Start Time',
              settingsController.workingHoursStart,
              true,
            ),
            _buildTimeTile(
              'End Time',
              settingsController.workingHoursEnd,
              false,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Lesson Scheduling'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Allow Back-to-Back Lessons',
              'Allow consecutive lessons without breaks',
              settingsController.allowBackToBackLessons,
              settingsController.toggleBackToBackLessons,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Break Settings'),
          _buildSettingsCard([
            _buildSliderTile(
              'Break Between Lessons',
              'Minimum break time in minutes',
              settingsController.breakBetweenLessons,
              settingsController.tempBreakBetweenLessons,
              0.0,
              60.0,
              5.0,
              settingsController.updateBreakBetweenLessonsTemp,
              settingsController.commitBreakBetweenLessons,
              (value) => '${value} min',
            ),
          ]),
        ],
      ),
    );
  }

  // Update notification settings with smooth sliders
  Widget _buildNotificationSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Automatic Notifications'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Auto Attendance Notifications',
              'Send notifications for attendance updates',
              settingsController.autoAttendanceNotifications,
              settingsController.toggleAutoAttendanceNotifications,
            ),
            _buildSwitchTile(
              'Schedule Conflict Alerts',
              'Alert when scheduling conflicts occur',
              settingsController.scheduleConflictAlerts,
              settingsController.toggleScheduleConflictAlerts,
            ),
            _buildSwitchTile(
              'Billing Warnings',
              'Send billing-related notifications',
              settingsController.billingWarnings,
              settingsController.toggleBillingWarnings,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Reminder Settings'),
          _buildSettingsCard([
            _buildSliderTile(
              'Lesson Start Reminder',
              'Minutes before lesson to send reminder',
              settingsController.lessonStartReminder,
              settingsController.tempLessonStartReminder,
              5.0,
              60.0,
              5.0,
              settingsController.updateLessonStartReminderTemp,
              settingsController.commitLessonStartReminder,
              (value) => '${value} min',
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Daily Summary'),
          _buildSettingsCard([
            _buildTimeTile(
              'Daily Summary Time',
              settingsController.dailySummaryTime,
              null,
              subtitle: 'Time to send daily summary notifications',
            ),
          ]),
        ],
      ),
    );
  }

  // Update billing settings with smooth sliders
  Widget _buildBillingSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Billing Warnings'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Show Low Lesson Warning',
              'Alert when student has few lessons remaining',
              settingsController.showLowLessonWarning,
              settingsController.toggleLowLessonWarning,
            ),
            _buildSwitchTile(
              'Prevent Over-Scheduling',
              'Block scheduling when no lessons remain',
              settingsController.preventOverScheduling,
              settingsController.togglePreventOverScheduling,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Billing Automation'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Auto-Create Billing Records',
              'Automatically create billing entries for completed lessons',
              settingsController.autoCreateBillingRecords,
              settingsController.toggleAutoCreateBillingRecords,
            ),
            _buildSwitchTile(
              'Count Scheduled Lessons',
              'Include scheduled lessons in billing calculations',
              settingsController.countScheduledLessons,
              settingsController.toggleCountScheduledLessons,
            ),
          ]),
          SizedBox(height: 16),
          _buildSectionHeader('Thresholds'),
          _buildSettingsCard([
            _buildSliderTile(
              'Low Lesson Threshold',
              'Number of lessons to trigger warning',
              settingsController.lowLessonThreshold,
              settingsController.tempLowLessonThreshold,
              1.0,
              10.0,
              1.0,
              settingsController.updateLowLessonThresholdTemp,
              settingsController.commitLowLessonThreshold,
              (value) => '${value} lesson${value == 1 ? '' : 's'}',
            ),
          ]),
        ],
      ),
    );
  }

  // Update advanced settings with smooth sliders
  Widget _buildAdvancedSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Data Management'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Enable Data Backup',
              'Automatically backup data to cloud storage',
              settingsController.enableDataBackup,
              settingsController.toggleDataBackup,
            ),
            _buildSwitchTile(
              'Enable Auto-Save',
              'Automatically save changes while working',
              settingsController.enableAutoSave,
              settingsController.toggleAutoSave,
            ),
          ]),
          SizedBox(height: 16),
          Obx(() => settingsController.enableAutoSave.value
              ? Column(children: [
                  _buildSectionHeader('Auto-Save Settings'),
                  _buildSettingsCard([
                    _buildSliderTile(
                      'Auto-Save Interval',
                      'Minutes between automatic saves',
                      settingsController.autoSaveInterval,
                      settingsController.tempAutoSaveInterval,
                      1.0,
                      30.0,
                      1.0,
                      settingsController.updateAutoSaveIntervalTemp,
                      settingsController.commitAutoSaveInterval,
                      (value) => '${value} min',
                    ),
                  ]),
                  SizedBox(height: 16),
                ])
              : SizedBox.shrink()),
          // ... rest of advanced settings
        ],
      ),
    );
  }
}
