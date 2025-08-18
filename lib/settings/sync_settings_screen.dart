import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_sync_service.dart';
import '../../widgets/sync_status_widget.dart';

class SyncSettingsScreen extends StatelessWidget {
  const SyncSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
        actions: [
          SyncIndicator(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SyncStatusWidget(
              showFullStatus: true,
              showLastSyncTime: true,
            ),
            const SizedBox(height: 24),
            _buildSyncStatistics(),
            const SizedBox(height: 24),
            _buildSyncSettings(),
            const SizedBox(height: 24),
            _buildAdvancedOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatistics() {
    return GetBuilder<FirebaseSyncService>(
      builder: (syncService) {
        return Obx(() {
          final stats = syncService.getSyncStats();

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sync Statistics',
                    style: Get.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Connection Status',
                      stats['isOnline'] ? 'Online' : 'Offline'),
                  _buildStatRow('Sync Status', stats['syncStatus']),
                  _buildStatRow(
                      'Tables Synced', '${stats['syncTables'].length}'),
                  if (stats['lastSyncTime'].millisecondsSinceEpoch > 0)
                    _buildStatRow(
                      'Last Sync',
                      DateFormat('MMM dd, yyyy HH:mm')
                          .format(stats['lastSyncTime']),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Settings',
              style: Get.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Auto Sync'),
              subtitle: const Text('Automatically sync when online'),
              trailing: Switch(
                value: true, // You can make this configurable
                onChanged: (value) {
                  // Implement auto sync toggle
                },
              ),
            ),
            ListTile(
              title: const Text('Sync Frequency'),
              subtitle: const Text('How often to sync when online'),
              trailing: DropdownButton<String>(
                value: '5 minutes',
                items: const [
                  DropdownMenuItem(value: '1 minute', child: Text('1 minute')),
                  DropdownMenuItem(
                      value: '5 minutes', child: Text('5 minutes')),
                  DropdownMenuItem(
                      value: '15 minutes', child: Text('15 minutes')),
                  DropdownMenuItem(
                      value: '30 minutes', child: Text('30 minutes')),
                ],
                onChanged: (value) {
                  // Implement frequency change
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Options',
              style: Get.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download All Data'),
              subtitle: const Text('Force download all data from server'),
              onTap: () => _confirmAction(
                'Download All Data',
                'This will download all data from the server. Continue?',
                () => FirebaseSyncService.instance.forceFullSync(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reset Local Data'),
              subtitle: const Text('Clear local data and re-download'),
              onTap: () => _confirmAction(
                'Reset Local Data',
                'This will clear all local data and re-download from server. Continue?',
                () => FirebaseSyncService.instance.resetAndResync(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync),
              title: const Text('Manual Sync'),
              subtitle: const Text('Trigger sync now'),
              onTap: () => FirebaseSyncService.instance.triggerManualSync(),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAction(String title, String message, VoidCallback action) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              action();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
