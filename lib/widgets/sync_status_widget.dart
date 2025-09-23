// lib/widgets/sync_status_widget.dart
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool showSyncButton;
  final String preferredSyncType;

  const SyncStatusWidget({
    Key? key,
    this.showSyncButton = true,
    this.preferredSyncType = 'auto',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<SyncController>(
      builder: (syncController) => Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status row
              Row(
                children: [
                  Icon(
                    syncController.getSyncStatusIcon(),
                    color: syncController.getSyncStatusColor(),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      syncController.syncStatus.value,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: syncController.getSyncStatusColor(),
                      ),
                    ),
                  ),
                  if (showSyncButton && !syncController.isSyncing.value)
                    IconButton(
                      icon: Icon(Icons.more_vert),
                      onPressed: () => _showSyncOptions(context),
                    ),
                ],
              ),

              // Progress bar (if syncing)
              if (syncController.isSyncing.value) ...[
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: syncController.syncProgress.value > 0
                      ? syncController.syncProgress.value
                      : null,
                ),
                if (syncController.syncProgressText.value.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    syncController.syncProgressText.value,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],

              // Last sync time
              if (syncController.lastSyncTime.value != 'Never') ...[
                SizedBox(height: 8),
                Text(
                  'Last sync: ${syncController.lastSyncTime.value}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSyncOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SyncSettingsDialog(),
    );
  }
}

class SyncSettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final syncController = Get.find<SyncController>();

    return AlertDialog(
      title: Text('Sync Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.auto_awesome),
            title: Text('Smart Sync'),
            subtitle: Text('Automatically chooses best sync method'),
            onTap: () {
              Get.back();
              syncController.performSmartSync();
            },
          ),
          ListTile(
            leading: Icon(Icons.rocket_launch),
            title: Text('Production Sync'),
            subtitle: Text('Advanced multi-device sync'),
            onTap: () {
              Get.back();
              syncController.performProductionSync();
            },
          ),
          ListTile(
            leading: Icon(Icons.sync),
            title: Text('Legacy Sync'),
            subtitle: Text('Original sync method'),
            onTap: () {
              Get.back();
              syncController.performSmartSync();
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.refresh, color: Colors.orange),
            title: Text('Full Reset'),
            subtitle: Text('Clear all data and re-download'),
            onTap: () {
              Get.back();
              syncController.performFullReset();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('Cancel'),
        ),
      ],
    );
  }
}

// Compact sync indicator for app bar
class SyncIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetX<SyncController>(
      builder: (syncController) {
        return GestureDetector(
          onTap: () => _showSyncDialog(syncController),
          child: Container(
            padding: EdgeInsets.all(8),
            child: Stack(
              children: [
                Icon(
                  syncController.getSyncStatusIcon(),
                  color: syncController.getSyncStatusColor(),
                  size: 20,
                ),
                if (syncController.isSyncing.value)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSyncDialog(SyncController syncController) {
    Get.dialog(
      AlertDialog(
        title: Text('Sync Status'),
        content: SyncStatusWidget(showSyncButton: false),
        actions: [
          if (!syncController.isSyncing.value)
            TextButton(
              onPressed: () {
                syncController.performSmartSync();
                Get.back();
              },
              child: Text('Sync Now'),
            ),
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
// Add this to lib/widgets/sync_status_widget.dart
// Compact sync indicator specifically for mobile app bars

class MobileSyncIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetX<SyncController>(
      builder: (syncController) {
        return GestureDetector(
          onTap: () => _showMobileSyncDialog(syncController),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sync status icon
                Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: syncController.getSyncStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    syncController.getSyncStatusIcon(),
                    size: 16,
                    color: syncController.getSyncStatusColor(),
                  ),
                ),
                SizedBox(width: 4),
                // Last sync time (shortened for mobile)
                Text(
                  _getShortSyncTime(syncController.lastSyncTime.value),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getShortSyncTime(String fullTime) {
    if (fullTime == 'Never') return 'Never';
    if (fullTime.startsWith('Today')) return 'Today';
    if (fullTime.startsWith('Yesterday')) return 'Yesterday';

    // For other times, show just the day
    final parts = fullTime.split(' ');
    if (parts.isNotEmpty) {
      return parts[0]; // Return just the day part
    }
    return fullTime;
  }

  void _showMobileSyncDialog(SyncController syncController) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    syncController.getSyncStatusIcon(),
                    color: syncController.getSyncStatusColor(),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Sync Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),

              Divider(),
              SizedBox(height: 12),

              // Status Information
              _buildMobileInfoRow('Status', syncController.syncStatus.value,
                  syncController.getSyncStatusColor()),
              SizedBox(height: 8),
              _buildMobileInfoRow('Last Sync',
                  syncController.lastSyncTime.value, Colors.grey[700]!),
              SizedBox(height: 8),
              _buildMobileInfoRow(
                  'Auto-Sync',
                  syncController.autoSyncEnabled.value ? 'Enabled' : 'Disabled',
                  syncController.autoSyncEnabled.value
                      ? Colors.green
                      : Colors.orange),

              if (syncController.autoSyncEnabled.value) ...[
                SizedBox(height: 8),
                _buildMobileInfoRow(
                    'Interval',
                    '${syncController.syncIntervalMinutes.value} minutes',
                    Colors.blue),
              ],

              SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: syncController.isSyncing.value
                          ? null
                          : () {
                              Get.back();
                              syncController.performSmartSync();
                            },
                      icon: Icon(Icons.sync, size: 18),
                      label: Text('Sync Now'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        Get.find<NavigationController>()
                            .navigateToPage('settings');
                      },
                      icon: Icon(Icons.settings, size: 18),
                      label: Text('Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileInfoRow(String label, String value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
