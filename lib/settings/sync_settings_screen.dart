// Fixed Auto-Sync Settings UI with proper error handling
// Replace your AutoSyncSettingsWidget with this version

import 'package:driving/controllers/firebase_sync_service.dart';
import 'package:driving/widgets/sync_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AutoSyncSettingsWidget extends StatelessWidget {
  const AutoSyncSettingsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if AutoSyncController is registered
    if (!Get.isRegistered<AutoSyncController>()) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              Text(
                'Auto-Sync Controller Not Available',
                style: Get.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please register AutoSyncController in your app bindings',
                style: Get.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _initializeAutoSync(),
                child: const Text('Initialize Auto-Sync'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
        actions: [
          const SyncStatusWidget(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        // Safe access with GetX
        child: GetBuilder<AutoSyncController>(
          init: AutoSyncController(), // Initialize if not already done
          builder: (controller) {
            // Additional null safety check
            if (controller == null) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            return Obx(() => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sync,
                              color: controller.autoSyncEnabled.value
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Automatic Sync',
                              style: Get.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.autoSyncStatus.value,
                          style: TextStyle(
                            color: _getStatusColor(
                                controller.autoSyncStatus.value),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Master auto-sync toggle
                        _buildSwitchTile(
                          title: 'Enable Auto-Sync',
                          subtitle: 'Automatically sync data in background',
                          value: controller.autoSyncEnabled.value,
                          onChanged: (value) =>
                              controller.enableAutoSync(value),
                          icon: Icons.sync,
                        ),

                        if (controller.autoSyncEnabled.value) ...[
                          const Divider(),

                          // Sync frequency
                          _buildFrequencySelector(controller),

                          const SizedBox(height: 12),

                          // Sync triggers
                          _buildSwitchTile(
                            title: 'Sync on Data Changes',
                            subtitle: 'Sync when you add/edit/delete data',
                            value: controller.syncOnDataChange.value,
                            onChanged: (value) =>
                                controller.enableSyncOnDataChange(value),
                            icon: Icons.edit,
                          ),

                          _buildSwitchTile(
                            title: 'Sync on Login',
                            subtitle: 'Sync when you sign in',
                            value: controller.syncOnLogin.value,
                            onChanged: (value) =>
                                controller.enableSyncOnLogin(value),
                            icon: Icons.login,
                          ),

                          _buildSwitchTile(
                            title: 'Sync on Network Restore',
                            subtitle:
                                'Sync when internet connection is restored',
                            value: controller.syncOnNetworkRestore.value,
                            onChanged: (value) =>
                                controller.enableSyncOnNetworkRestore(value),
                            icon: Icons.wifi,
                          ),

                          _buildSwitchTile(
                            title: 'Background Sync',
                            subtitle:
                                'Continue syncing when app is in background',
                            value: controller.backgroundSyncEnabled.value,
                            onChanged: (value) =>
                                controller.enableBackgroundSync(value),
                            icon: Icons.apps,
                          ),

                          _buildSwitchTile(
                            title: 'WiFi Only',
                            subtitle: 'Only sync when connected to WiFi',
                            value: controller.wifiOnlySync.value,
                            onChanged: (value) =>
                                controller.enableWifiOnlySync(value),
                            icon: Icons.wifi,
                          ),

                          const SizedBox(height: 16),

                          // Auto-sync statistics
                          _buildAutoSyncStats(controller),
                        ],
                      ],
                    ),
                  ),
                ));
          },
        ),
      ),
    );
  }

  void _initializeAutoSync() {
    try {
      // Try to register the controller
      Get.put(AutoSyncController(), permanent: true);

      Get.snackbar(
        'Auto-Sync Initialized',
        'Auto-sync controller has been registered successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Initialization Failed',
        'Failed to initialize auto-sync: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: value ? Colors.blue : Colors.grey,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildFrequencySelector(AutoSyncController controller) {
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: const Text('Sync Frequency'),
      subtitle: Text(
        'Automatically sync every ${controller.syncFrequencyMinutes.value} minute(s)',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: DropdownButton<int>(
        value: controller.syncFrequencyMinutes.value,
        items: const [
          DropdownMenuItem(value: 1, child: Text('1 minute')),
          DropdownMenuItem(value: 2, child: Text('2 minutes')),
          DropdownMenuItem(value: 5, child: Text('5 minutes')),
          DropdownMenuItem(value: 10, child: Text('10 minutes')),
          DropdownMenuItem(value: 15, child: Text('15 minutes')),
          DropdownMenuItem(value: 30, child: Text('30 minutes')),
          DropdownMenuItem(value: 60, child: Text('1 hour')),
        ],
        onChanged: (value) {
          if (value != null) {
            controller.setSyncFrequency(value);
          }
        },
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildAutoSyncStats(AutoSyncController controller) {
    final stats = controller.getAutoSyncStats();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Auto-Sync Statistics',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatRow('Status', stats['status']),
          _buildStatRow(
            'Last Auto-Sync',
            _formatSyncTime(stats['lastAutoSync'] as DateTime),
          ),
          _buildStatRow('Frequency', '${stats['frequency']} minutes'),
          _buildStatRow(
            'Triggers Enabled',
            _getTriggerCount(stats).toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('syncing') || status.contains('Ready')) {
      return Colors.green;
    } else if (status.contains('disabled') || status.contains('failed')) {
      return Colors.red;
    } else if (status.contains('No internet') ||
        status.contains('unavailable')) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  String _formatSyncTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  int _getTriggerCount(Map<String, dynamic> stats) {
    int count = 0;
    if (stats['syncOnDataChange'] == true) count++;
    if (stats['syncOnLogin'] == true) count++;
    if (stats['syncOnNetworkRestore'] == true) count++;
    if (stats['backgroundSyncEnabled'] == true) count++;
    return count;
  }
}

// Also fix the QuickAutoSyncWidget
class QuickAutoSyncWidget extends StatelessWidget {
  const QuickAutoSyncWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if controller is registered
    if (!Get.isRegistered<AutoSyncController>()) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_disabled, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'Auto: N/A',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return GetBuilder<AutoSyncController>(
      init: AutoSyncController(),
      builder: (controller) {
        if (controller == null) {
          return const SizedBox.shrink();
        }

        return Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: controller.autoSyncEnabled.value
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: controller.autoSyncEnabled.value
                      ? Colors.green.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    controller.autoSyncEnabled.value
                        ? Icons.sync
                        : Icons.sync_disabled,
                    size: 14,
                    color: controller.autoSyncEnabled.value
                        ? Colors.green
                        : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    controller.autoSyncEnabled.value
                        ? 'Auto: ${controller.syncFrequencyMinutes.value}m'
                        : 'Auto: OFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: controller.autoSyncEnabled.value
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ));
      },
    );
  }
}
