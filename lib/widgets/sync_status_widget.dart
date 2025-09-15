// lib/widgets/sync_status_widget.dart
import 'package:driving/controllers/sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool showFullStatus;
  final bool showSyncButton;

  const SyncStatusWidget({
    Key? key,
    this.showFullStatus = true,
    this.showSyncButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<SyncController>(
      builder: (syncController) {
        if (showFullStatus) {
          return _buildFullStatusCard(syncController);
        } else {
          return _buildCompactStatus(syncController);
        }
      },
    );
  }

  Widget _buildFullStatusCard(SyncController syncController) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  syncController.getSyncStatusIcon(),
                  color: syncController.getSyncStatusColor(),
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        syncController.syncStatus.value,
                        style: TextStyle(
                          color: syncController.getSyncStatusColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showSyncButton) _buildSyncButton(syncController),
              ],
            ),
            if (syncController.isSyncing.value) ...[
              SizedBox(height: 16),
              LinearProgressIndicator(
                value: syncController.syncProgress.value,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  syncController.getSyncStatusColor(),
                ),
              ),
              SizedBox(height: 8),
              if (syncController.syncProgressText.value.isNotEmpty)
                Text(
                  syncController.syncProgressText.value,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Connection',
                    syncController.isOnline.value ? 'Online' : 'Offline',
                    syncController.isOnline.value ? Colors.green : Colors.red,
                    syncController.isOnline.value ? Icons.wifi : Icons.wifi_off,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildInfoItem(
                    'Last Sync',
                    syncController.lastSyncTime.value,
                    Colors.grey[600]!,
                    Icons.access_time,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Auto Sync',
                    syncController.autoSyncEnabled.value
                        ? 'Enabled'
                        : 'Disabled',
                    syncController.autoSyncEnabled.value
                        ? Colors.green
                        : Colors.orange,
                    syncController.autoSyncEnabled.value
                        ? Icons.sync
                        : Icons.sync_disabled,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildInfoItem(
                    'Interval',
                    '${syncController.syncIntervalMinutes.value}min',
                    Colors.grey[600]!,
                    Icons.schedule,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatus(SyncController syncController) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: syncController.getSyncStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: syncController.getSyncStatusColor().withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            syncController.getSyncStatusIcon(),
            color: syncController.getSyncStatusColor(),
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            syncController.syncStatus.value,
            style: TextStyle(
              color: syncController.getSyncStatusColor(),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showSyncButton && !syncController.isSyncing.value) ...[
            SizedBox(width: 8),
            GestureDetector(
              onTap: () => syncController.performFullSync(),
              child: Icon(
                Icons.refresh,
                color: syncController.getSyncStatusColor(),
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncButton(SyncController syncController) {
    return PopupMenuButton<String>(
      enabled: !syncController.isSyncing.value,
      icon: Icon(
        Icons.more_vert,
        color: Colors.grey[600],
      ),
      onSelected: (value) {
        switch (value) {
          case 'full_sync':
            syncController.performFullSync();
            break;
          case 'upload_only':
            syncController.uploadPendingChanges();
            break;
          case 'toggle_auto':
            syncController
                .toggleAutoSync(!syncController.autoSyncEnabled.value);
            break;
          case 'settings':
            _showSyncSettings(syncController);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'full_sync',
          child: Row(
            children: [
              Icon(Icons.sync, size: 18),
              SizedBox(width: 8),
              Text('Full Sync'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'upload_only',
          child: Row(
            children: [
              Icon(Icons.cloud_upload, size: 18),
              SizedBox(width: 8),
              Text('Upload Changes'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'toggle_auto',
          child: Row(
            children: [
              Icon(
                syncController.autoSyncEnabled.value
                    ? Icons.sync_disabled
                    : Icons.sync,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(syncController.autoSyncEnabled.value
                  ? 'Disable Auto-Sync'
                  : 'Enable Auto-Sync'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 18),
              SizedBox(width: 8),
              Text('Sync Settings'),
            ],
          ),
        ),
      ],
    );
  }

  void _showSyncSettings(SyncController syncController) {
    Get.dialog(
      AlertDialog(
        title: Text('Sync Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Auto Sync'),
              subtitle: Text('Automatically sync data in the background'),
              value: syncController.autoSyncEnabled.value,
              onChanged: (value) {
                syncController.toggleAutoSync(value);
                Get.back();
              },
            ),
            if (syncController.autoSyncEnabled.value) ...[
              SizedBox(height: 16),
              Text('Sync Interval',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              DropdownButton<int>(
                value: syncController.syncIntervalMinutes.value,
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: 5, child: Text('5 minutes')),
                  DropdownMenuItem(value: 15, child: Text('15 minutes')),
                  DropdownMenuItem(value: 30, child: Text('30 minutes')),
                  DropdownMenuItem(value: 60, child: Text('1 hour')),
                  DropdownMenuItem(value: 120, child: Text('2 hours')),
                  DropdownMenuItem(value: 360, child: Text('6 hours')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    syncController.updateSyncInterval(value);
                    Get.back();
                  }
                },
              ),
            ],
          ],
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
                syncController.performFullSync();
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
