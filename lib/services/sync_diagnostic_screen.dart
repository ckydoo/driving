// Create this new screen: lib/screens/debug/sync_diagnostic_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/sync_debug_helper.dart';
import '../../controllers/sync_controller.dart';

class SyncDiagnosticScreen extends StatefulWidget {
  @override
  _SyncDiagnosticScreenState createState() => _SyncDiagnosticScreenState();
}

class _SyncDiagnosticScreenState extends State<SyncDiagnosticScreen> {
  final syncController = Get.find<SyncController>();
  Map<String, dynamic>? diagnosticReport;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnosticReport();
  }

  Future<void> _loadDiagnosticReport() async {
    setState(() => isLoading = true);
    try {
      final report = await SyncDebugHelper.generateDiagnosticReport();
      setState(() => diagnosticReport = report);
    } catch (e) {
      print('Error loading diagnostic report: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sync Diagnostics'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDiagnosticReport,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : diagnosticReport == null
              ? Center(child: Text('No diagnostic data available'))
              : _buildDiagnosticView(),
    );
  }

  Widget _buildDiagnosticView() {
    final report = diagnosticReport!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(report),
          SizedBox(height: 16),
          _buildPendingChangesCard(report['pending_changes']),
          SizedBox(height: 16),
          _buildLastErrorCard(report['last_error']),
          SizedBox(height: 16),
          _buildRecentActivityCard(report['recent_activity']),
          SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> report) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Summary',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            _buildInfoRow('Last Sync', report['last_sync'] ?? 'Never'),
            _buildInfoRow(
                'Report Generated', _formatTimestamp(report['timestamp'])),
            _buildInfoRow('Total Log Entries', '${report['total_logs']}'),
            Obx(() => _buildInfoRow(
                'Current Status', syncController.syncStatus.value)),
            Obx(() => _buildInfoRow(
                'Is Syncing', '${syncController.isSyncing.value}')),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingChangesCard(Map<String, dynamic> pendingStatus) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pendingStatus['has_pending']
                      ? Icons.warning
                      : Icons.check_circle,
                  color: pendingStatus['has_pending']
                      ? Colors.orange
                      : Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  'Pending Changes',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(pendingStatus['details'] ?? 'No details available'),
            if (pendingStatus['has_pending']) ...[
              SizedBox(height: 8),
              Text(
                'Total Items: ${pendingStatus['count']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (pendingStatus['breakdown'] != null) ...[
                SizedBox(height: 4),
                ...((pendingStatus['breakdown'] as Map<String, dynamic>)
                    .entries
                    .map((entry) => Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Text('${entry.key}: ${entry.value} items'),
                        ))),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLastErrorCard(Map<String, dynamic>? lastError) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  lastError != null ? Icons.error : Icons.check_circle,
                  color: lastError != null ? Colors.red : Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  'Last Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            SizedBox(height: 8),
            if (lastError != null) ...[
              Text(
                lastError['error'] ?? 'Unknown error',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              if (lastError['context'] != null) ...[
                SizedBox(height: 4),
                Text('Context: ${lastError['context']}'),
              ],
              SizedBox(height: 4),
              Text('Time: ${_formatTimestamp(lastError['timestamp'])}'),
            ] else ...[
              Text(
                'No recent errors',
                style: TextStyle(color: Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(List<dynamic> recentActivity) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            if (recentActivity.isEmpty)
              Text('No recent activity')
            else
              ...recentActivity.reversed.take(10).map((activity) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            _formatTime(activity['timestamp']),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            activity['activity'] ?? 'Unknown activity',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            await syncController.debugSyncStatus();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Debug info printed to console')),
            );
          },
          icon: Icon(Icons.bug_report),
          label: Text('Print Debug to Console'),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () async {
            await syncController.uploadPendingChanges();
            await _loadDiagnosticReport();
          },
          icon: Icon(Icons.upload),
          label: Text('Force Upload Pending Changes'),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () async {
            await SyncDebugHelper.clearDebugData();
            await _loadDiagnosticReport();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Debug data cleared')),
            );
          },
          icon: Icon(Icons.clear),
          label: Text('Clear Debug Data'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.toLocal()}'.split('.')[0];
    } catch (e) {
      return timestamp;
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
