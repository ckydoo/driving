import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auto_attendance_service.dart';

class AutoAttendanceSettings extends StatelessWidget {
  const AutoAttendanceSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                Icon(Icons.smart_toy, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Auto-Attendance Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Enable/Disable Auto-Attendance
            Obx(() => SwitchListTile(
                  title: Text('Enable Auto-Attendance'),
                  subtitle: Text(
                    autoAttendanceService.isAutoAttendanceEnabled.value
                        ? 'Lessons will be automatically marked as attended when they end'
                        : 'Manual attendance marking required',
                  ),
                  value: autoAttendanceService.isAutoAttendanceEnabled.value,
                  onChanged: (value) {
                    autoAttendanceService.toggleAutoAttendance(value);
                  },
                  secondary: Icon(
                    autoAttendanceService.isAutoAttendanceEnabled.value
                        ? Icons.auto_awesome
                        : Icons.schedule,
                    color: autoAttendanceService.isAutoAttendanceEnabled.value
                        ? Colors.green
                        : Colors.grey,
                  ),
                )),

            Divider(),

            // Grace Period Setting
            Obx(() => ListTile(
                  leading: Icon(Icons.timer, color: Colors.orange),
                  title: Text('Grace Period'),
                  subtitle: Text(
                    'Wait ${autoAttendanceService.gracePeriosMinutes.value} minutes after lesson ends before auto-marking',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed:
                            autoAttendanceService.gracePeriosMinutes.value > 1
                                ? () => autoAttendanceService.setGracePeriod(
                                    autoAttendanceService
                                            .gracePeriosMinutes.value -
                                        1)
                                : null,
                        icon: Icon(Icons.remove),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${autoAttendanceService.gracePeriosMinutes.value}m',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            autoAttendanceService.gracePeriosMinutes.value < 30
                                ? () => autoAttendanceService.setGracePeriod(
                                    autoAttendanceService
                                            .gracePeriosMinutes.value +
                                        1)
                                : null,
                        icon: Icon(Icons.add),
                      ),
                    ],
                  ),
                )),

            Divider(),

            // Notification Settings
            Obx(() => SwitchListTile(
                  title: Text('Pre-Mark Notifications'),
                  subtitle: Text(
                    autoAttendanceService.notifyBeforeAutoMark.value
                        ? 'Show notification 30 seconds before auto-marking'
                        : 'Mark attendance silently without notification',
                  ),
                  value: autoAttendanceService.notifyBeforeAutoMark.value,
                  onChanged: (value) {
                    autoAttendanceService.toggleNotifications(value);
                  },
                  secondary: Icon(
                    Icons.notifications,
                    color: autoAttendanceService.notifyBeforeAutoMark.value
                        ? Colors.blue
                        : Colors.grey,
                  ),
                )),

            SizedBox(height: 20),

            // Statistics Section
            _buildStatsSection(autoAttendanceService),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(AutoAttendanceService service) {
    return Obx(() {
      final stats = service.getAutoAttendanceStats();

      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Auto-Attendance Stats',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Lessons',
                    '${stats['totalToday']}',
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Auto-Marked',
                    '${stats['autoAttended']}',
                    Icons.auto_awesome,
                    Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Manual',
                    '${stats['manuallyMarked']}',
                    Icons.touch_app,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Pending',
                    '${stats['pendingAutoMark']}',
                    Icons.pending,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
