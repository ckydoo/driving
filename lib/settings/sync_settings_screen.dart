// ADD THIS WIDGET TO YOUR ADMIN OR SETTINGS SCREEN

import 'package:driving/controllers/user_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/settings/debug_sync_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyncManagementSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Data Sync Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: BackButton(),
      ),
      body: Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data Sync Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _buildSyncStatus(),
              SizedBox(height: 16),
              _buildSyncButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatus() {
    try {
      final syncService = Get.find<FixedLocalFirstSyncService>();

      return Obx(() => Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  syncService.isSyncing.value
                      ? Icons.sync
                      : Icons.sync_disabled,
                  color: syncService.isSyncing.value
                      ? Colors.blue
                      : syncService.firebaseAvailable.value
                          ? Colors.green
                          : Colors.red,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sync Status: ${syncService.syncStatus.value}'),
                      Text(
                        'Last Sync: ${_formatSyncTime(syncService.lastSyncTime.value)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ));
    } catch (e) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Sync service unavailable: $e'),
      );
    }
  }

  final userController = Get.find<FixedLocalFirstSyncService>();

  Widget _buildSyncButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => _triggerManualSync(),
          icon: Icon(Icons.sync),
          label: Text('Manual Sync'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Get.to(() => DebugSyncScreen()),
          icon: Icon(Icons.analytics),
          label: Text('Sync Dashboard'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showSyncStatus(),
          icon: Icon(Icons.info),
          label: Text('Sync Status'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _createBackup(),
          icon: Icon(Icons.backup),
          label: Text('Backup Data'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            userController.fixMismatchedUserDocuments();
          },
          icon: Icon(Icons.backup),
          label: Text('Force Sync Users'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _triggerManualSync() async {
    try {
      final syncService = Get.find<FixedLocalFirstSyncService>();

      if (syncService.isSyncing.value) {
        Get.snackbar('Info', 'Sync already in progress');
        return;
      }

      Get.snackbar('Sync Started', 'Manual sync initiated...');

      await syncService.syncWithFirebase();

      Get.snackbar(
        'Success',
        'Manual sync completed successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Manual sync failed: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _showSyncStatus() async {
    try {
      final status = await DatabaseHelper.instance.getDetailedSyncStatus();

      Get.dialog(
        AlertDialog(
          title: Text('Sync Status Summary'),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: status.entries.map((entry) {
                  final data = entry.value as Map<String, dynamic>;
                  return ListTile(
                    title: Text(entry.key),
                    subtitle: Text(
                      'Total: ${data['total']}, Synced: ${data['synced']}, Unsynced: ${data['unsynced']}',
                    ),
                    trailing: Text('${data['sync_percentage']}%'),
                  );
                }).toList(),
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
      Get.snackbar('Error', 'Failed to get sync status: $e');
    }
  }

  Future<void> _createBackup() async {
    try {
      Get.snackbar('Backup', 'Creating backup...');

      final backup = await DatabaseHelper.instance.backupDatabase();

      Get.snackbar(
        'Success',
        'Backup created successfully!\nKey: ${backup['backup_key']}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Backup failed: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _formatSyncTime(DateTime syncTime) {
    if (syncTime.year == 1970) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(syncTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

// ADD THIS TO YOUR ADMIN/SETTINGS SCREEN:
// SyncManagementSection()
