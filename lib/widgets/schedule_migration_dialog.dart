// lib/widgets/schedule_migration_dialog.dart
import 'package:driving/constant/schedule_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/schedule_controller.dart';
import '../services/schedule_status_migration.dart';

class ScheduleMigrationDialog extends StatefulWidget {
  @override
  _ScheduleMigrationDialogState createState() =>
      _ScheduleMigrationDialogState();
}

class _ScheduleMigrationDialogState extends State<ScheduleMigrationDialog> {
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  bool _isLoading = false;
  Map<String, dynamic>? _migrationStats;

  @override
  void initState() {
    super.initState();
    _loadMigrationStats();
  }

  Future<void> _loadMigrationStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await ScheduleStatusMigration.instance.getMigrationStats();
      setState(() => _migrationStats = stats);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load migration stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runMigration() async {
    setState(() => _isLoading = true);
    try {
      await scheduleController.runStatusMigration();
      await _loadMigrationStats(); // Reload stats after migration
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.build, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Schedule Status Migration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close),
                ),
              ],
            ),

            SizedBox(height: 16),

            Text(
              'This migration will fix inconsistencies in your schedule statuses and attendance markings.',
              style: TextStyle(color: Colors.grey[600]),
            ),

            SizedBox(height: 24),

            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading migration data...'),
                  ],
                ),
              )
            else if (_migrationStats != null) ...[
              // Current Status Distribution
              _buildSection(
                'Current Status Distribution',
                Icons.pie_chart,
                Colors.blue,
                _buildStatusDistribution(),
              ),

              SizedBox(height: 20),

              // Issues Found
              _buildSection(
                'Issues Found',
                Icons.warning,
                Colors.orange,
                _buildIssuesFound(),
              ),

              SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loadMigrationStats,
                      child: Text('Refresh Stats'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _runMigration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Run Migration'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, Widget child) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusDistribution() {
    final distribution =
        _migrationStats!['statusDistribution'] as Map<String, dynamic>;

    if (distribution.isEmpty) {
      return Text('No schedules found');
    }

    return Column(
      children: distribution.entries.map((entry) {
        final status = entry.key;
        final count = entry.value as int;
        final isValidStatus = ScheduleStatus.isValidStatus(status);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isValidStatus
                      ? Color(ScheduleStatus.statusColors[status] ?? 0xFF9E9E9E)
                      : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: isValidStatus ? null : Colors.red,
                    fontWeight: isValidStatus ? null : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                count.toString(),
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              if (!isValidStatus) ...[
                SizedBox(width: 8),
                Icon(Icons.error, color: Colors.red, size: 16),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIssuesFound() {
    final inconsistentRecords = _migrationStats!['inconsistentRecords'] as int;
    final shouldBeMissed = _migrationStats!['shouldBeMissed'] as int;

    final issues = [
      if (inconsistentRecords > 0)
        _buildIssueItem(
          'Inconsistent attendance/status',
          inconsistentRecords,
          'Records where attended status doesn\'t match the status field',
          Icons.sync_problem,
        ),
      if (shouldBeMissed > 0)
        _buildIssueItem(
          'Should be marked as missed',
          shouldBeMissed,
          'Past lessons that weren\'t attended but not marked as missed',
          Icons.access_time,
        ),
    ];

    if (issues.isEmpty) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Text(
            'No issues found!',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Column(children: issues);
  }

  Widget _buildIssueItem(
      String title, int count, String description, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title ($count)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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

// Helper function to show the dialog
void showScheduleMigrationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => ScheduleMigrationDialog(),
  );
}
