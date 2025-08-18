// lib/widgets/sync_status_widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/firebase_sync_service.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool showFullStatus;
  final bool showLastSyncTime;

  const SyncStatusWidget({
    Key? key,
    this.showFullStatus = false,
    this.showLastSyncTime = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<FirebaseSyncService>(
      builder: (syncService) {
        if (showFullStatus) {
          return _buildFullStatusWidget(syncService);
        } else {
          return _buildCompactStatusWidget(syncService);
        }
      },
    );
  }

  Widget _buildCompactStatusWidget(FirebaseSyncService syncService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(syncService).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(syncService).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(syncService),
          const SizedBox(width: 4),
          Text(
            _getStatusText(syncService),
            style: TextStyle(
              color: _getStatusColor(syncService),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullStatusWidget(FirebaseSyncService syncService) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(syncService),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sync Status',
                    style: Theme.of(Get.context!).textTheme.titleMedium,
                  ),
                ),
                if (!syncService.isSyncing.value && syncService.isOnline.value)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => syncService.triggerManualSync(),
                    tooltip: 'Manual Sync',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  syncService.isOnline.value ? Icons.wifi : Icons.wifi_off,
                  color: syncService.isOnline.value ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  syncService.isOnline.value ? 'Online' : 'Offline',
                  style: TextStyle(
                    color:
                        syncService.isOnline.value ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _getStatusIconData(syncService),
                  color: _getStatusColor(syncService),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  syncService.syncStatus.value,
                  style: TextStyle(
                    color: _getStatusColor(syncService),
                  ),
                ),
              ],
            ),
            if (showLastSyncTime &&
                syncService.lastSyncTime.value.millisecondsSinceEpoch > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Last sync: ${_formatLastSyncTime(syncService.lastSyncTime.value)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: syncService.isOnline.value &&
                            !syncService.isSyncing.value
                        ? () => syncService.forceFullSync()
                        : null,
                    icon: const Icon(Icons.cloud_sync, size: 16),
                    label: const Text('Full Sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: syncService.isOnline.value &&
                            !syncService.isSyncing.value
                        ? () => _showResetDialog()
                        : null,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
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

  Widget _buildStatusIcon(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor:
              AlwaysStoppedAnimation<Color>(_getStatusColor(syncService)),
        ),
      );
    }

    return Icon(
      _getStatusIconData(syncService),
      size: 16,
      color: _getStatusColor(syncService),
    );
  }

  IconData _getStatusIconData(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return Icons.sync;
    }

    if (!syncService.isOnline.value) {
      return Icons.cloud_off;
    }

    switch (syncService.syncStatus.value.toLowerCase()) {
      case 'synced':
        return Icons.cloud_done;
      case 'sync failed':
        return Icons.cloud_off;
      case 'syncing...':
        return Icons.sync;
      default:
        return Icons.cloud_queue;
    }
  }

  Color _getStatusColor(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return Colors.blue;
    }

    if (!syncService.isOnline.value) {
      return Colors.red;
    }

    switch (syncService.syncStatus.value.toLowerCase()) {
      case 'synced':
        return Colors.green;
      case 'sync failed':
        return Colors.red;
      case 'syncing...':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return 'Syncing...';
    }

    if (!syncService.isOnline.value) {
      return 'Offline';
    }

    return syncService.syncStatus.value;
  }

  String _formatLastSyncTime(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM dd, HH:mm').format(lastSync);
    }
  }

  void _showResetDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Reset and Resync'),
        content: const Text(
            'This will clear all local data and re-download everything from the server. '
            'Are you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              FirebaseSyncService.instance.resetAndResync();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

// Compact sync indicator for app bars
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<FirebaseSyncService>(
      builder: (syncService) {
        return GestureDetector(
          onTap: () => _showSyncDetails(),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: syncService.isSyncing.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    syncService.isOnline.value
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    color:
                        syncService.isOnline.value ? Colors.white : Colors.red,
                    size: 20,
                  ),
          ),
        );
      },
    );
  }

  void _showSyncDetails() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: const SyncStatusWidget(showFullStatus: true),
      ),
      isScrollControlled: true,
    );
  }
}

// Additional helper widget for sync progress in lists
class SyncProgressItem extends StatelessWidget {
  final String tableName;
  final int totalRecords;
  final int syncedRecords;

  const SyncProgressItem({
    Key? key,
    required this.tableName,
    required this.totalRecords,
    required this.syncedRecords,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = totalRecords > 0 ? syncedRecords / totalRecords : 0.0;

    return ListTile(
      leading: CircularProgressIndicator(
        value: progress,
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(
          progress == 1.0 ? Colors.green : Colors.blue,
        ),
      ),
      title: Text(tableName.toUpperCase()),
      subtitle: Text('$syncedRecords of $totalRecords synced'),
      trailing: progress == 1.0
          ? const Icon(Icons.check, color: Colors.green)
          : Text('${(progress * 100).toInt()}%'),
    );
  }
}

// Sync status banner for important notifications
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<FirebaseSyncService>(
      builder: (syncService) {
        // Only show banner for important states
        if (syncService.syncStatus.value.toLowerCase() == 'sync failed' ||
            (!syncService.isOnline.value &&
                syncService.syncStatus.value != 'Offline')) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red[100],
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    syncService.isOnline.value
                        ? 'Sync failed - Some data may not be backed up'
                        : 'Working offline - Changes will sync when online',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (syncService.isOnline.value)
                  TextButton(
                    onPressed: () => syncService.triggerManualSync(),
                    child:
                        Text('Retry', style: TextStyle(color: Colors.red[700])),
                  ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
