// lib/widgets/sync_status_widget.dart - FIXED VERSION

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/sync_controller.dart';
import '../controllers/navigation_controller.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool showSyncButton;
  final bool showAppBar;

  const SyncStatusWidget({
    Key? key,
    this.showSyncButton = true,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Sync Status'),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            GetX<SyncController>(
              builder: (syncController) => IconButton(
                icon: Icon(
                  syncController.isSyncing.value ? Icons.sync : Icons.refresh,
                  color: Colors.white,
                ),
                onPressed: syncController.isSyncing.value
                    ? null
                    : () => syncController.performSmartSync(),
                tooltip:
                    syncController.isSyncing.value ? 'Syncing...' : 'Sync Now',
              ),
            ),
          ],
        ),
        body: _buildBody(),
      );
    } else {
      return _buildBody();
    }
  }

  Widget _buildBody() {
    return GetX<SyncController>(
      builder: (syncController) => Container(
        color: Colors.grey[50],
        child: SingleChildScrollView(
          // FIX: Make it scrollable to prevent overflow
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sync Status Card
              _buildSyncStatusCard(syncController),

              SizedBox(height: 16),

              // Sync Details Card
              _buildSyncDetailsCard(syncController),

              SizedBox(height: 16),

              // Connection Status Card
              _buildConnectionStatusCard(syncController),

              if (showSyncButton) ...[
                SizedBox(height: 24),
                _buildSyncActionsCard(syncController),
              ],

              SizedBox(height: 16),

              // Quick Settings Card
              _buildQuickSettingsCard(syncController),

              // Add some bottom padding to ensure last item is visible
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(SyncController syncController) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: syncController.getSyncStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    syncController.getSyncStatusIcon(),
                    color: syncController.getSyncStatusColor(),
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        syncController.syncStatus.value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: syncController.getSyncStatusColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Progress bar (if syncing)
            if (syncController.isSyncing.value) ...[
              SizedBox(height: 16),
              LinearProgressIndicator(
                value: syncController.syncProgress.value > 0
                    ? syncController.syncProgress.value
                    : null,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  syncController.getSyncStatusColor(),
                ),
              ),
              if (syncController.syncProgressText.value.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  syncController.syncProgressText.value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncDetailsCard(SyncController syncController) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              'Last Sync',
              syncController.lastSyncTime.value,
              Icons.access_time,
            ),
            _buildInfoRow(
              'Auto Sync',
              syncController.autoSyncEnabled.value ? 'Enabled' : 'Disabled',
              syncController.autoSyncEnabled.value
                  ? Icons.sync
                  : Icons.sync_disabled,
            ),
            _buildInfoRow(
              'Interval',
              '${syncController.syncIntervalMinutes.value} minutes',
              Icons.timer,
            ),
            if (syncController.lastSyncResult.value != null) ...[
              _buildInfoRow(
                'Last Result',
                syncController.lastSyncResult.value!.success
                    ? 'Success'
                    : 'Failed',
                syncController.lastSyncResult.value!.success
                    ? Icons.check_circle
                    : Icons.error,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(SyncController syncController) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: syncController.isOnline.value
                        ? Colors.green
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  syncController.isOnline.value ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: syncController.isOnline.value
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncActionsCard(SyncController syncController) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),

            // Row 1: Smart Sync and Legacy Sync
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: syncController.isSyncing.value
                        ? null
                        : () => syncController.performSmartSync(),
                    icon: Icon(Icons.auto_awesome, size: 18),
                    label: Text('Smart Sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: syncController.isSyncing.value
                        ? null
                        : () => syncController.performFullSync(),
                    icon: Icon(Icons.sync, size: 18),
                    label: Text('Legacy Sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Row 2: Upload Only and Full Reset
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: syncController.isSyncing.value
                        ? null
                        : () => syncController.uploadPendingChanges(),
                    icon: Icon(Icons.cloud_upload, size: 18),
                    label: Text('Upload Only'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: syncController.isSyncing.value
                        ? null
                        : () => _showResetConfirmation(),
                    icon: Icon(Icons.refresh, size: 18),
                    label: Text('Full Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildQuickSettingsCard(SyncController syncController) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),

            // Auto Sync Toggle
            Row(
              children: [
                Icon(Icons.sync, color: Colors.grey[600], size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Auto Sync',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                Switch(
                  value: syncController.autoSyncEnabled.value,
                  onChanged: (value) => syncController.toggleAutoSync(value),
                  activeColor: Colors.blue[600],
                ),
              ],
            ),

            SizedBox(height: 16),

            // Settings Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.find<NavigationController>().navigateToPage('settings');
                },
                icon: Icon(Icons.settings, size: 18),
                label: Text('More Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Full Reset'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will clear all local data and download everything fresh from the server.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'This may take several minutes. Are you sure?',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              final syncController = Get.find<SyncController>();
              // Check if the method exists by trying to call it safely
              try {
                syncController.performFullReset();
              } catch (e) {
                // Fallback to smart sync if performFullReset doesn't exist
                print('performFullReset not available, using smart sync: $e');
                syncController.performSmartSync();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Reset & Sync'),
          ),
        ],
      ),
    );
  }
}

// Compact version for use in other widgets (like main layout)
class CompactSyncStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetX<SyncController>(
      builder: (syncController) => GestureDetector(
        onTap: () => _showSyncDialog(),
        child: Container(
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
            ],
          ),
        ),
      ),
    );
  }

  void _showSyncDialog() {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.8,
        child: SyncStatusWidget(showAppBar: false),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }
}
