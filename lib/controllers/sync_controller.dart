// lib/controllers/sync_controller.dart - FIXED VERSION
import 'dart:async';
import 'package:driving/services/sync_service.dart';
import 'package:driving/models/sync_result.dart';
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
  final RxInt syncIntervalMinutes = 30.obs; // FIX: Changed from 1 to 30 minutes

  // Background sync timer
  Timer? _syncTimer;
  Timer? _connectionCheckTimer;

  // FIX: Add initialization state tracking
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  void onInit() {
    super.onInit();
    _initializeController();
  }

  @override
  void onClose() {
    _isDisposed = true;
    _stopAllTimers();
    super.onClose();
  }

  // FIX: Proper initialization sequence
  Future<void> _initializeController() async {
    try {
      print('🔄 Initializing SyncController...');

      // Load settings first
      await _loadSyncSettings();

      // Start connection monitoring
      _startConnectionMonitoring();

      // Mark as initialized
      _isInitialized = true;

      // Start periodic sync if enabled and user is logged in
      _startSyncIfReady();

      print('✅ SyncController initialized');
    } catch (e) {
      print('❌ SyncController initialization failed: $e');
    }
  }

  // FIX: Check conditions before starting sync
  void _startSyncIfReady() {
    if (!_isInitialized || _isDisposed) return;

    try {
      final authController = Get.find<AuthController>();
      if (autoSyncEnabled.value && authController.isLoggedIn.value) {
        startPeriodicSync();
      }
    } catch (e) {
      print('⚠️ AuthController not ready yet, will start sync on login');
    }
  }

  /// Start monitoring internet connection
  void _startConnectionMonitoring() {
    if (_isDisposed) return;

    // FIX: Adjust connection check interval based on sync interval
    final checkInterval =
        Duration(seconds: syncIntervalMinutes.value < 10 ? 30 : 60);

    _connectionCheckTimer = Timer.periodic(checkInterval, (timer) {
      if (!_isDisposed) {
        _checkConnection();
      }
    });

    // Check connection immediately
    _checkConnection();
  }

  /// Check internet connection status
  Future<void> _checkConnection() async {
    if (_isDisposed) return;

    try {
      final online = await SyncService.isOnline();

      if (!_isDisposed) {
        isOnline.value = online;

        if (online) {
          syncStatus.value = 'Connected';
        } else {
          syncStatus.value = 'Offline';
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        isOnline.value = false;
        syncStatus.value = 'Connection error';
      }
    }
  }

  /// Load sync settings from storage
  Future<void> _loadSyncSettings() async {
    try {
      final settings = await SyncService.getSyncSettings();

      if (_isDisposed) return;

      autoSyncEnabled.value = settings['autoSync'] ?? true;
      syncIntervalMinutes.value = settings['interval'] ?? 30;

      // Get the ISO timestamp from storage and format it for display
      final lastSyncStored = settings['lastSync'];
      lastSyncTime.value = _formatLastSyncForDisplay(lastSyncStored);

      print(
          '✅ Sync settings loaded: auto=${autoSyncEnabled.value}, interval=${syncIntervalMinutes.value}min');
    } catch (e) {
      print('❌ Failed to load sync settings: $e');
      lastSyncTime.value = 'Never';
    }
  }

  /// Format last sync timestamp for display
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
        return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${_getDayName(dateTime.weekday)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
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

  /// Save sync settings
  Future<void> _saveSyncSettings() async {
    try {
      await SyncService.saveSyncSettings({
        'autoSync': autoSyncEnabled.value,
        'interval': syncIntervalMinutes.value,
      });
    } catch (e) {
      print('❌ Failed to save sync settings: $e');
    }
  }

  /// Perform initial sync when user logs in
  Future<void> performInitialSync() async {
    if (_isDisposed) return;

    try {
      final authController = Get.find<AuthController>();
      if (!authController.isLoggedIn.value) {
        print('❌ Cannot sync: User not logged in');
        return;
      }

      print('🔄 Starting initial sync...');
      await performFullSync();

      // Start periodic sync after successful initial sync
      if (autoSyncEnabled.value) {
        startPeriodicSync();
      }
    } catch (e) {
      print('❌ Initial sync failed: $e');
    }
  }

  /// Start periodic sync - FIXED VERSION
  void startPeriodicSync() {
    if (_isDisposed || !_isInitialized) {
      print('⚠️ Cannot start periodic sync: controller not ready');
      return;
    }

    if (!autoSyncEnabled.value) {
      print('ℹ️ Auto-sync is disabled');
      return;
    }

    // FIX: Validate sync interval
    if (syncIntervalMinutes.value < 5) {
      print('⚠️ Sync interval too small, setting to minimum 5 minutes');
      syncIntervalMinutes.value = 5;
      _saveSyncSettings();
    }

    stopPeriodicSync(); // Stop existing timer

    final interval = Duration(minutes: syncIntervalMinutes.value);

    _syncTimer = Timer.periodic(interval, (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      try {
        final authController = Get.find<AuthController>();
        if (authController.isLoggedIn.value &&
            isOnline.value &&
            !isSyncing.value) {
          print('🔄 Starting periodic sync...');
          performFullSync();
        } else {
          print(
              '⏸️ Skipping periodic sync: logged_in=${authController.isLoggedIn.value}, online=${isOnline.value}, syncing=${isSyncing.value}');
        }
      } catch (e) {
        print('❌ Error in periodic sync: $e');
      }
    });

    print(
        '✅ Periodic sync started (interval: ${syncIntervalMinutes.value} minutes)');

    // FIX: Update connection check timer interval
    _restartConnectionMonitoring();
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
    if (!_isDisposed) {
      syncStatus.value = 'Stopped';
    }
    print('🛑 All sync activities stopped');
  }

  // FIX: Restart connection monitoring with appropriate interval
  void _restartConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _startConnectionMonitoring();
  }

  /// Perform full sync
  Future<void> performFullSync() async {
    if (_isDisposed || isSyncing.value) {
      print('⚠️ Sync already in progress or controller disposed');
      return;
    }

    try {
      isSyncing.value = true;
      syncStatus.value = 'Syncing...';

      final result = await SyncService.fullSync();

      if (_isDisposed) return;

      lastSyncResult.value = result;

      if (result.success) {
        syncStatus.value = 'Sync completed';
        updateLastSyncDisplay();

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

        Get.snackbar(
          'Sync Failed',
          result.message,
          icon: Icon(Icons.sync_problem, color: Colors.white),
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (!_isDisposed) {
        syncStatus.value = 'Sync error';
        print('❌ Full sync error: $e');

        Get.snackbar(
          'Sync Error',
          e.toString(),
          icon: Icon(Icons.error, color: Colors.white),
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } finally {
      if (!_isDisposed) {
        isSyncing.value = false;
      }
    }
  }

  /// Upload pending changes only
  Future<void> uploadPendingChanges() async {
    if (_isDisposed || isSyncing.value) return;

    try {
      isSyncing.value = true;
      syncStatus.value = 'Uploading changes...';

      final result = await SyncService.uploadPendingChanges();

      if (_isDisposed) return;

      lastSyncResult.value = result;

      if (result.success) {
        final uploaded = result.details?['uploaded'] ?? 0;
        final errors = result.details?['errors'] ?? [];
        final isPartial = result.details?['partial'] ?? false;

        syncStatus.value =
            isPartial ? 'Upload partially completed' : 'Upload completed';
        updateLastSyncDisplay();

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
      if (!_isDisposed) {
        syncStatus.value = 'Upload error';

        Get.snackbar(
          'Upload Error',
          e.toString(),
          icon: Icon(Icons.error, color: Colors.white),
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } finally {
      if (!_isDisposed) {
        isSyncing.value = false;
      }
    }
  }

  /// Toggle auto-sync - FIXED VERSION
  void toggleAutoSync(bool enabled) {
    if (_isDisposed) return;

    autoSyncEnabled.value = enabled;

    if (enabled && _isInitialized) {
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

  /// Update sync interval - FIXED VERSION
  void updateSyncInterval(int minutes) {
    if (_isDisposed) return;

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
    if (autoSyncEnabled.value && _isInitialized) {
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

  /// Update last sync time display
  void updateLastSyncDisplay() {
    if (_isDisposed) return;
    _loadSyncSettings();
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

  // FIX: Add method to handle auth state changes
  void onAuthStateChanged(bool isLoggedIn) {
    if (_isDisposed) return;

    if (isLoggedIn) {
      print('🔄 User logged in - starting sync...');
      Future.delayed(Duration(seconds: 1), () {
        if (!_isDisposed) {
          performInitialSync();
        }
      });
    } else {
      print('🔄 User logged out - stopping sync...');
      stopSync();
    }
  }
}
