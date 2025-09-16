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

      // Get the ISO timestamp from storage and format it for display
      final lastSyncStored = settings['lastSync'];
      lastSyncTime.value = _formatLastSyncForDisplay(lastSyncStored);
    } catch (e) {
      print('❌ Failed to load sync settings: $e');
      lastSyncTime.value = 'Never';
    }
  }

  /// Format last sync timestamp for display (but don't save this format)
  String _formatLastSyncForDisplay(String? isoTimestamp) {
    if (isoTimestamp == null ||
        isoTimestamp == 'Never' ||
        isoTimestamp.isEmpty ||
        !isoTimestamp.contains('T')) {
      return 'Never';
    }

    try {
      final dateTime = DateTime.parse(isoTimestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        // Today - show as "Today HH:MM"
        return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        // Yesterday
        return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        // This week
        return '${_getDayName(dateTime.weekday)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        // Older dates
        return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print('⚠️ Failed to parse last sync timestamp: $e');
      return 'Never';
    }
  }

  String _getDayName(int weekday) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday];
  }

  /// Save sync settings - DO NOT save the display format
  Future<void> _saveSyncSettings() async {
    try {
      // DON'T save lastSyncTime.value (display format)
      // The ISO timestamp is saved directly by SyncService
      await SyncService.saveSyncSettings({
        'autoSync': autoSyncEnabled.value,
        'interval': syncIntervalMinutes.value,
        // Don't save 'lastSync' here - it's handled by SyncService
      });
    } catch (e) {
      print('❌ Failed to save sync settings: $e');
    }
  }

  /// Update last sync time display after successful sync
  void updateLastSyncDisplay() {
    // Reload from storage to get the latest ISO timestamp and format for display
    _loadSyncSettings();
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
        syncProgressText.value = 'Sync completed successfully';

        // Update the display format after successful sync
        updateLastSyncDisplay();

        // Show success message
        Get.snackbar(
          'Sync Complete',
          'Data synchronized successfully',
          icon: Icon(Icons.sync, color: Colors.white),
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
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
      }

      // Save settings (but not the display format)
      await _saveSyncSettings();
    } catch (e) {
      syncStatus.value = 'Sync failed';
      syncProgressText.value = e.toString();
      lastSyncResult.value = SyncResult(false, e.toString());

      Get.snackbar(
        'Sync Error',
        e.toString(),
        icon: Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );

      print('❌ Sync failed: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  /// Format sync time for display
  String _formatSyncTime(DateTime dateTime) {
    // Format as: "Today 16:13" or "15 Sep 16:13" etc.
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // Older dates
      return '${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }

  /// Update last sync time after successful sync
  void updateLastSyncTime(String isoTimestamp) {
    try {
      final syncDateTime = DateTime.parse(isoTimestamp);
      lastSyncTime.value = _formatSyncTime(syncDateTime);
    } catch (e) {
      print('⚠️ Failed to update last sync time display: $e');
      lastSyncTime.value = 'Just now';
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
// Updated uploadPendingChanges method in lib/controllers/sync_controller.dart
  Future<void> uploadPendingChanges() async {
    if (isSyncing.value) return;

    try {
      isSyncing.value = true;
      syncStatus.value = 'Uploading changes...';

      final result = await SyncService.uploadPendingChanges();
      lastSyncResult.value = result;

      if (result.success) {
        final uploaded = result.details?['uploaded'] ?? 0;
        final errors = result.details?['errors'] ?? [];
        final isPartial = result.details?['partial'] ?? false;

        syncStatus.value =
            isPartial ? 'Upload partially completed' : 'Upload completed';
        lastSyncTime.value = _formatDateTime(DateTime.now());

        // Show appropriate success message
        if (isPartial && errors.isNotEmpty) {
          Get.snackbar(
            'Upload Partially Complete',
            '$uploaded items uploaded, ${errors.length} failed',
            icon: Icon(Icons.warning, color: Colors.white),
            backgroundColor: Colors.amber,
            colorText: Colors.white,
            duration: Duration(seconds: 4),
          );
        } else {
          Get.snackbar(
            'Upload Complete',
            'Changes uploaded successfully',
            icon: Icon(Icons.cloud_upload, color: Colors.white),
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: Duration(seconds: 2),
          );
        }
      } else {
        syncStatus.value = 'Upload failed';

        Get.snackbar(
          'Upload Failed',
          result.message,
          icon: Icon(Icons.cloud_off, color: Colors.white),
          backgroundColor: Colors.red,
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
