// lib/screens/debug_sync_screen.dart
// CREATE THIS NEW FILE (Optional but highly recommended for monitoring)

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/services/database_helper.dart';

class DebugSyncScreen extends StatefulWidget {
  @override
  _DebugSyncScreenState createState() => _DebugSyncScreenState();
}

class _DebugSyncScreenState extends State<DebugSyncScreen> {
  Map<String, dynamic>? syncStatus;
  List<Map<String, dynamic>>? conflicts;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSyncData();
  }

  Future<void> _loadSyncData() async {
    setState(() => isLoading = true);

    try {
      final status = await DatabaseHelper.instance.getDetailedSyncStatus();
      final conflictHistory =
          await DatabaseHelper.instance.getConflictHistory();

      setState(() {
        syncStatus = status;
        conflicts = conflictHistory;
      });
    } catch (e) {
      print('Error loading sync data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sync Debug Dashboard'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSyncData,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSyncServiceStatus(),
                  SizedBox(height: 20),
                  _buildSyncButtons(),
                  SizedBox(height: 20),
                  _buildSyncStatusTable(),
                  SizedBox(height: 20),
                  _buildConflictHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildSyncServiceStatus() {
    try {
      final syncService = Get.find<FixedLocalFirstSyncService>();

      return Obx(() => Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sync Service Status',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 15),
                  _buildStatusRow(
                    Icons.cloud,
                    'Firebase Available',
                    syncService.firebaseAvailable.value,
                  ),
                  _buildStatusRow(
                    Icons.wifi,
                    'Online',
                    syncService.isOnline.value,
                  ),
                  _buildStatusRow(
                    Icons.sync,
                    'Currently Syncing',
                    syncService.isSyncing.value,
                  ),
                  SizedBox(height: 10),
                  Divider(),
                  SizedBox(height: 10),
                  Text('Status: ${syncService.syncStatus.value}',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  SizedBox(height: 5),
                  Text(
                      'Last Sync: ${_formatDateTime(syncService.lastSyncTime.value)}'),
                ],
              ),
            ),
          ));
    } catch (e) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sync service not available: $e'),
        ),
      );
    }
  }

  Widget _buildStatusRow(IconData icon, String label, bool isActive) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? Colors.green : Colors.red,
            size: 20,
          ),
          SizedBox(width: 12),
          Text('$label: ${isActive ? 'Yes' : 'No'}'),
        ],
      ),
    );
  }

  Widget _buildSyncButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _manualSync(),
                icon: Icon(Icons.sync),
                label: Text('Manual Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _forceResync(),
                icon: Icon(Icons.sync_alt),
                label: Text('Force Resync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _clearConflicts(),
                icon: Icon(Icons.clear_all),
                label: Text('Clear Conflicts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _exportLogs(),
                icon: Icon(Icons.download),
                label: Text('Export Logs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncStatusTable() {
    if (syncStatus == null) return SizedBox();

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync Status by Table',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 15),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(
                      label: Text('Table',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Synced',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Unsynced',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Progress',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: syncStatus!.entries.map((entry) {
                  final data = entry.value as Map<String, dynamic>;
                  final total = data['total'] ?? 0;
                  final synced = data['synced'] ?? 0;
                  final unsynced = data['unsynced'] ?? 0;
                  final percentage = data['sync_percentage'] ?? 0;

                  return DataRow(
                    cells: [
                      DataCell(Text(entry.key,
                          style: TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text('$total')),
                      DataCell(Text('$synced',
                          style: TextStyle(color: Colors.green))),
                      DataCell(Text('$unsynced',
                          style: TextStyle(
                              color: unsynced > 0 ? Colors.red : Colors.grey))),
                      DataCell(
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: percentage / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: percentage == 100
                                        ? Colors.green
                                        : Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('$percentage%',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictHistory() {
    if (conflicts == null) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conflict History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 15),
              Text('Loading conflict history...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (conflicts!.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Conflict History',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 15),
              Text('No conflicts found! 🎉',
                  style: TextStyle(color: Colors.green, fontSize: 16)),
              Text('Your data is syncing smoothly across all devices.'),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Recent Conflicts (${conflicts!.length})',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 15),
            ...conflicts!.take(10).map((conflict) {
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.warning, color: Colors.white, size: 16),
                  ),
                  title: Text(
                      '${conflict['table_name']} #${conflict['record_id']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Resolution: ${conflict['resolution']}'),
                      Text(
                          '${_formatDateTime(DateTime.tryParse(conflict['created_at'] ?? '') ?? DateTime.now())}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  isThreeLine: true,
                  dense: true,
                ),
              );
            }).toList(),
            if (conflicts!.length > 10)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('... and ${conflicts!.length - 10} more conflicts',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _manualSync() async {
    try {
      final syncService = Get.find<FixedLocalFirstSyncService>();

      if (syncService.isSyncing.value) {
        Get.snackbar('Info', 'Sync already in progress...',
            backgroundColor: Colors.blue.shade100);
        return;
      }

      Get.snackbar('Sync Started', 'Manual sync initiated...',
          backgroundColor: Colors.blue.shade100);

      await syncService.syncWithFirebase();

      Get.snackbar(
        'Success',
        'Manual sync completed successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
      );

      await _loadSyncData();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Manual sync failed: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error, color: Colors.white),
      );
    }
  }

  Future<void> _forceResync() async {
    try {
      // Show confirmation dialog
      final confirm = await Get.dialog<bool>(
            AlertDialog(
              title: Text('Force Resync'),
              content: Text(
                  'This will mark all records as unsynced and force a complete resync. Continue?'),
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Get.back(result: true),
                  child: Text('Force Resync'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirm) return;

      Get.snackbar('Force Resync', 'Marking all records for resync...',
          backgroundColor: Colors.orange.shade100);

      await DatabaseHelper.instance.markAllRecordsForSync();

      final syncService = Get.find<FixedLocalFirstSyncService>();
      await syncService.syncWithFirebase();

      Get.snackbar(
        'Success',
        'Force resync completed!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await _loadSyncData();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Force resync failed: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _clearConflicts() async {
    try {
      await DatabaseHelper.instance.clearOldConflictLogs(daysToKeep: 0);
      Get.snackbar(
        'Success',
        'Conflict logs cleared',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      await _loadSyncData();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to clear conflicts: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _exportLogs() async {
    // For now, just show the logs in a dialog
    // In a real app, you might export to a file or send via email
    try {
      final status = await DatabaseHelper.instance.getDetailedSyncStatus();
      final conflicts = await DatabaseHelper.instance.getConflictHistory();

      Get.dialog(
        AlertDialog(
          title: Text('Sync Logs'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SYNC STATUS:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(status.toString()),
                  SizedBox(height: 20),
                  Text('CONFLICTS:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(conflicts.toString()),
                ],
              ),
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
    } catch (e) {
      Get.snackbar('Error', 'Failed to export logs: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    if (dateTime.year == 1970) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
