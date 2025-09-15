// lib/controllers/sync_controller.dart
import 'dart:async';
import 'package:driving/services/sync_service.dart';
import 'package:driving/models/sync_result.dart'; // Import shared SyncResult
import 'package:driving/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyncController extends GetxController {
  // Sync state
  final RxBool isOnline = false.obs;
  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Not connected'.obs;
  final RxString lastSyncTime = 'Never'.obs;
  final Rx<SyncResult?> lastSyncResult = Rx<SyncResult?>(null);

  // Sync progress
  final RxDouble syncProgress = 0.0.obs;
  final RxString syncProgressText = ''.obs;

  // Sync settings
  final RxBool autoSyncEnabled = true.obs;
  final RxInt syncIntervalMinutes = 30.obs;

  // Background sync timer
  Timer? _syncTimer;
  Timer? _connectionCheckTimer;

  @override
  void onInit() {
    super.onInit();
    _startConnectionMonitoring();
    _loadSyncSettings();
  }

  @override
  void onClose() {
    _stopAllTimers();
    super.onClose();
  }

  /// Start monitoring internet connection
  void _startConnectionMonitoring() {
    _connectionCheckTimer = Timer.periodic(
      Duration(seconds: 30),
      (timer) => _checkConnection(),
    );

    // Check connection immediately
    _checkConnection();
  }

  /// Check internet connection status
  Future<void> _checkConnection() async {
    try {
      final online = await SyncService.isOnline();
      isOnline.value = online;

      if (online) {
        syncStatus.value = 'Connected';
      } else {
        syncStatus.value = 'Offline';
      }
    } catch (e) {
      isOnline.value = false;
      syncStatus.value = 'Connection error';
    }
  }

  /// Load sync settings from storage
  Future<void> _loadSyncSettings() async {
    try {
      final settings = await SyncService.getSyncSettings();
      autoSyncEnabled.value = settings['autoSync'] ?? true;
      syncIntervalMinutes.value = settings['interval'] ?? 30;
      lastSyncTime.value = settings['lastSync'] ?? 'Never';
    } catch (e) {
      print('❌ Failed to load sync settings: $e');
    }
  }

  /// Save sync settings
  Future<void> _saveSyncSettings() async {
    try {
      await SyncService.saveSyncSettings({
        'autoSync': autoSyncEnabled.value,
        'interval': syncIntervalMinutes.value,
        'lastSync': lastSyncTime.value,
      });
    } catch (e) {
      print('❌ Failed to save sync settings: $e');
    }
  }

  /// Perform initial sync when user logs in
  Future<void> performInitialSync() async {
    if (!Get.find<AuthController>().isLoggedIn.value) {
      print('❌ Cannot sync: User not logged in');
      return;
    }

    print('🔄 Starting initial sync...');
    await performFullSync();
  }

  /// Perform full sync
  Future<void> performFullSync() async {
    if (isSyncing.value) {
      print('⚠️ Sync already in progress');
      return;
    }

    try {
      isSyncing.value = true;
      syncStatus.value = 'Syncing...';
      syncProgress.value = 0.0;
      syncProgressText.value = 'Checking connection...';

      // Check connection
      if (!await SyncService.isOnline()) {
        throw Exception('No internet connection');
      }

      syncProgress.value = 0.2;
      syncProgressText.value = 'Downloading data...';

      // Perform full sync
      final result = await SyncService.fullSync();
      lastSyncResult.value = result;

      syncProgress.value = 1.0;

      if (result.success) {
        syncStatus.value = 'Sync completed';
        syncProgressText.value = 'Sync successful';
        lastSyncTime.value = _formatDateTime(DateTime.now());

        // Show success message
        Get.snackbar(
          'Sync Complete',
          'Data synchronized successfully',
          icon: Icon(Icons.sync, color: Colors.white),
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );

        print('✅ Full sync completed successfully');
      } else {
        syncStatus.value = 'Sync failed';
        syncProgressText.value = result.message;

        // Show error message
        Get.snackbar(
          'Sync Failed',
          result.message,
          icon: Icon(Icons.sync_problem, color: Colors.white),
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );

        print('❌ Full sync failed: ${result.message}');
      }

      await _saveSyncSettings();
    } catch (e) {
      syncStatus.value = 'Sync error';
      syncProgressText.value = 'Sync failed: ${e.toString()}';

      // Show error message
      Get.snackbar(
        'Sync Error',
        e.toString(),
        icon: Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );

      print('❌ Sync error: $e');
    } finally {
      isSyncing.value = false;

      // Reset progress after delay
      Timer(Duration(seconds: 2), () {
        syncProgress.value = 0.0;
        syncProgressText.value = '';
      });
    }
  }

  /// Start periodic sync
  void startPeriodicSync() {
    if (!autoSyncEnabled.value) {
      print('ℹ️ Auto-sync is disabled');
      return;
    }

    stopPeriodicSync(); // Stop existing timer

    final interval = Duration(minutes: syncIntervalMinutes.value);
    _syncTimer = Timer.periodic(interval, (timer) {
      if (Get.find<AuthController>().isLoggedIn.value && isOnline.value) {
        print('🔄 Starting periodic sync...');
        performFullSync();
      }
    });

    print(
        '✅ Periodic sync started (interval: ${syncIntervalMinutes.value} minutes)');
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('🛑 Periodic sync stopped');
  }

  /// Stop all sync activities
  void stopSync() {
    stopPeriodicSync();
    syncStatus.value = 'Stopped';
    print('🛑 All sync activities stopped');
  }

  /// Upload pending changes only
  Future<void> uploadPendingChanges() async {
    if (isSyncing.value) return;

    try {
      isSyncing.value = true;
      syncStatus.value = 'Uploading changes...';

      final result = await SyncService.uploadPendingChanges();
      lastSyncResult.value = result;

      if (result.success) {
        syncStatus.value = 'Upload completed';
        lastSyncTime.value = _formatDateTime(DateTime.now());

        Get.snackbar(
          'Upload Complete',
          'Changes uploaded successfully',
          icon: Icon(Icons.cloud_upload, color: Colors.white),
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      } else {
        syncStatus.value = 'Upload failed';

        Get.snackbar(
          'Upload Failed',
          result.message,
          icon: Icon(Icons.cloud_off, color: Colors.white),
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      syncStatus.value = 'Upload error';

      Get.snackbar(
        'Upload Error',
        e.toString(),
        icon: Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// Get sync status information
  Future<Map<String, dynamic>> getSyncInfo() async {
    try {
      return await SyncService.getSyncStatus();
    } catch (e) {
      print('❌ Failed to get sync info: $e');
      return {
        'connected': false,
        'last_sync': 'Unknown',
        'pending_changes': 0,
        'error': e.toString(),
      };
    }
  }

  /// Toggle auto-sync
  void toggleAutoSync(bool enabled) {
    autoSyncEnabled.value = enabled;

    if (enabled) {
      startPeriodicSync();
    } else {
      stopPeriodicSync();
    }

    _saveSyncSettings();

    Get.snackbar(
      'Auto-Sync ${enabled ? 'Enabled' : 'Disabled'}',
      enabled
          ? 'Data will sync automatically every ${syncIntervalMinutes.value} minutes'
          : 'Manual sync only',
      icon:
          Icon(enabled ? Icons.sync : Icons.sync_disabled, color: Colors.white),
      backgroundColor: enabled ? Colors.green : Colors.orange,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );
  }

  /// Update sync interval
  void updateSyncInterval(int minutes) {
    if (minutes < 5 || minutes > 1440) {
      Get.snackbar(
        'Invalid Interval',
        'Sync interval must be between 5 minutes and 24 hours',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    syncIntervalMinutes.value = minutes;
    _saveSyncSettings();

    // Restart periodic sync with new interval
    if (autoSyncEnabled.value) {
      startPeriodicSync();
    }

    Get.snackbar(
      'Sync Interval Updated',
      'Data will sync every $minutes minutes',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );
  }

  /// Stop all timers when disposing
  void _stopAllTimers() {
    _syncTimer?.cancel();
    _connectionCheckTimer?.cancel();
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Get sync status color
  Color getSyncStatusColor() {
    if (isSyncing.value) return Colors.blue;
    if (!isOnline.value) return Colors.grey;
    if (lastSyncResult.value?.success == true) return Colors.green;
    if (lastSyncResult.value?.success == false) return Colors.red;
    return Colors.grey;
  }

  /// Get sync status icon
  IconData getSyncStatusIcon() {
    if (isSyncing.value) return Icons.sync;
    if (!isOnline.value) return Icons.wifi_off;
    if (lastSyncResult.value?.success == true) return Icons.sync;
    if (lastSyncResult.value?.success == false) return Icons.sync_problem;
    return Icons.sync_disabled;
  }
}
