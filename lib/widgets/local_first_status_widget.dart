// lib/widgets/local_first_status_widget.dart - Status widget for local-first approach

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../services/multi_tenant_firebase_sync_service.dart';

class LocalFirstStatusWidget extends StatefulWidget {
  const LocalFirstStatusWidget({Key? key}) : super(key: key);

  @override
  _LocalFirstStatusWidgetState createState() => _LocalFirstStatusWidgetState();
}

class _LocalFirstStatusWidgetState extends State<LocalFirstStatusWidget> {
  Map<String, dynamic>? _syncStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    setState(() => _isLoading = true);
    try {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      final status = await syncService.getSyncStatusSummary();
      setState(() => _syncStatus = status);
    } catch (e) {
      print('Error loading sync status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.storage,
                color: Colors.blue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Local First Storage',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue.shade800,
                ),
              ),
              Spacer(),
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),

          SizedBox(height: 12),

          // Local Storage Status
          _buildStatusCard(
            'Local Database',
            'Always Available',
            Icons.check_circle,
            Colors.green,
            'Data saved locally first for reliability',
          ),

          SizedBox(height: 8),

          // Firebase Sync Status
          Obx(() => _buildStatusCard(
                'Cloud Sync',
                authController.firebaseAvailable.value
                    ? 'Available'
                    : 'Offline',
                authController.firebaseAvailable.value
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                authController.firebaseAvailable.value
                    ? Colors.green
                    : Colors.orange,
                authController.firebaseAvailable.value
                    ? 'Syncing to cloud in background'
                    : 'Will sync when connection restored',
              )),

          SizedBox(height: 12),

          // Sync Statistics
          if (_syncStatus != null) ...[
            Text(
              'Sync Statistics',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            _buildSyncStats(),
          ],

          SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _refreshStatus,
                  icon: Icon(Icons.refresh, size: 16),
                  label: Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade700,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      authController.firebaseAvailable.value ? _syncNow : null,
                  icon: Icon(Icons.sync, size: 16),
                  label: Text('Sync Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.green.shade700,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String status, IconData icon,
      Color color, String description) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStats() {
    final stats = _syncStatus!;
    final totalUsers = stats['total_users'] as int? ?? 0;
    final syncedUsers = stats['synced_users'] as int? ?? 0;
    final unsyncedUsers = stats['unsynced_users'] as int? ?? 0;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem('Total Users', totalUsers.toString(), Icons.people,
                  Colors.blue),
              _buildStatItem('Synced', syncedUsers.toString(), Icons.cloud_done,
                  Colors.green),
              _buildStatItem('Local Only', unsyncedUsers.toString(),
                  Icons.storage, Colors.orange),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalUsers > 0 ? syncedUsers / totalUsers : 0,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 4,
          ),
          SizedBox(height: 4),
          Text(
            totalUsers > 0
                ? 'Sync Progress: ${(syncedUsers / totalUsers * 100).toInt()}%'
                : 'No data to sync',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _refreshStatus() async {
    await _loadSyncStatus();
    Get.snackbar(
      'Status Refreshed',
      'Sync status updated',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _syncNow() async {
    try {
      Get.snackbar(
        'Sync Started',
        'Syncing local data to cloud...',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
      );

      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      await syncService.triggerManualSync();

      await _loadSyncStatus();

      Get.snackbar(
        'Sync Complete',
        'All local data synced to cloud',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Sync Failed',
        'Failed to sync: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

// Usage example: Add to your users screen for monitoring
/*
// In your users screen, add this at the top for development/admin view:

class EnhancedUsersScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Add status widget for admins or debug mode
          if (Get.find<AuthController>().isAdmin || kDebugMode) 
            LocalFirstStatusWidget(),
          
          // Your existing users screen content
          Expanded(
            child: YourExistingUsersContent(),
          ),
        ],
      ),
    );
  }
}
*/
