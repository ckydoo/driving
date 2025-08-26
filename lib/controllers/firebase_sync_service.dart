// Enhanced Automatic Sync System with User Controls
// Add this to your firebase_sync_service.dart or create a new controller

import 'dart:async';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AutoSyncController extends GetxController {
  // Observable settings
  final RxBool autoSyncEnabled = true.obs;
  final RxInt syncFrequencyMinutes = 5.obs;
  final RxBool syncOnDataChange = true.obs;
  final RxBool syncOnLogin = true.obs;
  final RxBool syncOnNetworkRestore = true.obs;
  final RxBool backgroundSyncEnabled = true.obs;
  final RxBool wifiOnlySync = false.obs;

  // Internal state
  Timer? _periodicSyncTimer;
  Timer? _dataSyncDebounceTimer;
  final RxString autoSyncStatus = 'Waiting for conditions...'.obs;
  final Rx<DateTime> lastAutoSync = DateTime.fromMillisecondsSinceEpoch(0).obs;

  // Dependencies
  late MultiTenantFirebaseSyncService _syncService;
  late AuthController _authController;

  @override
  void onInit() {
    super.onInit();
    _syncService = Get.find<MultiTenantFirebaseSyncService>();
    _authController = Get.find<AuthController>();

    // Load saved settings
    _loadSettings();

    // Set up automatic sync system
    _setupAutomaticSyncSystem();
  }

  @override
  void onClose() {
    _periodicSyncTimer?.cancel();
    _dataSyncDebounceTimer?.cancel();
    super.onClose();
  }

  /// Load auto-sync settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      autoSyncEnabled.value = prefs.getBool('auto_sync_enabled') ?? true;
      syncFrequencyMinutes.value = prefs.getInt('sync_frequency_minutes') ?? 5;
      syncOnDataChange.value = prefs.getBool('sync_on_data_change') ?? true;
      syncOnLogin.value = prefs.getBool('sync_on_login') ?? true;
      syncOnNetworkRestore.value =
          prefs.getBool('sync_on_network_restore') ?? true;
      backgroundSyncEnabled.value =
          prefs.getBool('background_sync_enabled') ?? true;
      wifiOnlySync.value = prefs.getBool('wifi_only_sync') ?? false;

      final lastAutoSyncMs = prefs.getInt('last_auto_sync') ?? 0;
      lastAutoSync.value = DateTime.fromMillisecondsSinceEpoch(lastAutoSyncMs);

      print('✅ Auto-sync settings loaded');
    } catch (e) {
      print('⚠️ Error loading auto-sync settings: $e');
    }
  }

  /// Save auto-sync settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('auto_sync_enabled', autoSyncEnabled.value);
      await prefs.setInt('sync_frequency_minutes', syncFrequencyMinutes.value);
      await prefs.setBool('sync_on_data_change', syncOnDataChange.value);
      await prefs.setBool('sync_on_login', syncOnLogin.value);
      await prefs.setBool(
          'sync_on_network_restore', syncOnNetworkRestore.value);
      await prefs.setBool(
          'background_sync_enabled', backgroundSyncEnabled.value);
      await prefs.setBool('wifi_only_sync', wifiOnlySync.value);
      await prefs.setInt(
          'last_auto_sync', lastAutoSync.value.millisecondsSinceEpoch);

      print('✅ Auto-sync settings saved');
    } catch (e) {
      print('⚠️ Error saving auto-sync settings: $e');
    }
  }

  /// Set up the complete automatic sync system
  void _setupAutomaticSyncSystem() {
    print('🤖 Setting up enhanced automatic sync system...');

    // 1. Set up periodic sync
    _setupPeriodicSync();

    // 2. Set up data change triggers
    _setupDataChangeTriggers();

    // 3. Set up authentication triggers
    _setupAuthTriggers();

    // 4. Set up network change triggers
    _setupNetworkTriggers();

    // 5. Watch for setting changes
    _setupSettingsWatchers();

    autoSyncStatus.value = 'Auto-sync system ready';
    print('✅ Enhanced automatic sync system initialized');
  }

  /// Set up periodic sync based on user frequency setting
  void _setupPeriodicSync() {
    _periodicSyncTimer?.cancel();

    // Watch for frequency changes
    ever(syncFrequencyMinutes, (int frequency) {
      _restartPeriodicSync();
    });

    // Watch for auto-sync enabled/disabled
    ever(autoSyncEnabled, (bool enabled) {
      if (enabled) {
        _restartPeriodicSync();
      } else {
        _periodicSyncTimer?.cancel();
        autoSyncStatus.value = 'Auto-sync disabled';
      }
    });

    _restartPeriodicSync();
  }

  void _restartPeriodicSync() {
    _periodicSyncTimer?.cancel();

    if (!autoSyncEnabled.value) return;

    final frequency = Duration(minutes: syncFrequencyMinutes.value);

    _periodicSyncTimer = Timer.periodic(frequency, (timer) {
      if (_shouldPerformAutoSync()) {
        _performAutoSync(
            'Periodic sync (${syncFrequencyMinutes.value}m interval)');
      }
    });

    autoSyncStatus.value = 'Periodic sync every ${syncFrequencyMinutes.value}m';
    print(
        '🕐 Periodic sync set up for every ${syncFrequencyMinutes.value} minutes');
  }

  /// Set up data change triggers
  void _setupDataChangeTriggers() {
    // This integrates with your existing database helpers
    // The database helpers should call triggerDataChangeSync()
  }

  /// Trigger sync when data changes (called by database helpers)
  void triggerDataChangeSync() {
    if (!autoSyncEnabled.value || !syncOnDataChange.value) return;

    // Use debouncing to prevent too frequent syncs
    _dataSyncDebounceTimer?.cancel();
    _dataSyncDebounceTimer = Timer(const Duration(seconds: 10), () {
      if (_shouldPerformAutoSync()) {
        _performAutoSync('Data change detected');
      }
    });
  }

  /// Set up authentication state triggers
  void _setupAuthTriggers() {
    // Trigger sync when user logs in
    ever(_authController.isLoggedIn, (bool isLoggedIn) {
      if (isLoggedIn &&
          syncOnLogin.value &&
          _authController.isFirebaseAuthenticated) {
        Future.delayed(const Duration(seconds: 3), () {
          if (_shouldPerformAutoSync()) {
            _performAutoSync('User login detected');
          }
        });
      }
    });

    // Trigger sync when Firebase authentication completes
    ever(_authController.firebaseUser, (firebaseUser) {
      if (firebaseUser != null &&
          syncOnLogin.value &&
          _authController.isLoggedIn.value) {
        Future.delayed(const Duration(seconds: 5), () {
          if (_shouldPerformAutoSync()) {
            _performAutoSync('Firebase authentication completed');
          }
        });
      }
    });
  }

  /// Set up network change triggers
  void _setupNetworkTriggers() {
    ever(_syncService.isOnline, (bool isOnline) {
      if (isOnline && syncOnNetworkRestore.value) {
        // Wait a moment for connection to stabilize
        Future.delayed(const Duration(seconds: 8), () {
          if (_shouldPerformAutoSync()) {
            _performAutoSync('Network connection restored');
          }
        });
      }
    });
  }

  /// Set up watchers for settings changes
  void _setupSettingsWatchers() {
    // Save settings when they change
    ever(autoSyncEnabled, (_) => _saveSettings());
    ever(syncFrequencyMinutes, (_) => _saveSettings());
    ever(syncOnDataChange, (_) => _saveSettings());
    ever(syncOnLogin, (_) => _saveSettings());
    ever(syncOnNetworkRestore, (_) => _saveSettings());
    ever(backgroundSyncEnabled, (_) => _saveSettings());
    ever(wifiOnlySync, (_) => _saveSettings());
  }

  /// Check if auto-sync should be performed
  bool _shouldPerformAutoSync() {
    // Basic checks
    if (!autoSyncEnabled.value) {
      autoSyncStatus.value = 'Auto-sync disabled';
      return false;
    }

    if (_syncService.isSyncing.value) {
      autoSyncStatus.value = 'Sync already in progress';
      return false;
    }

    if (!_syncService.isOnline.value) {
      autoSyncStatus.value = 'No internet connection';
      return false;
    }

    if (!_syncService.firebaseAvailable.value) {
      autoSyncStatus.value = 'Firebase unavailable';
      return false;
    }

    if (!_authController.isFirebaseAuthenticated) {
      autoSyncStatus.value = 'Authentication required';
      return false;
    }

    // WiFi-only check
    if (wifiOnlySync.value) {
      // You can implement WiFi detection here if needed
      // For now, we'll assume it's OK
    }

    // Check minimum time between syncs (prevent too frequent syncs)
    final timeSinceLastSync = DateTime.now().difference(lastAutoSync.value);
    if (timeSinceLastSync.inMinutes < 1) {
      autoSyncStatus.value = 'Too soon since last sync';
      return false;
    }

    autoSyncStatus.value = 'Ready to sync';
    return true;
  }

  /// Perform automatic sync
  Future<void> _performAutoSync(String reason) async {
    try {
      autoSyncStatus.value = 'Auto-syncing: $reason';
      print('🤖 Auto-sync triggered: $reason');

      await _syncService.triggerManualSync();

      lastAutoSync.value = DateTime.now();
      await _saveSettings();

      autoSyncStatus.value =
          'Last auto-sync: ${_formatSyncTime(lastAutoSync.value)}';
      print('✅ Auto-sync completed: $reason');
    } catch (e) {
      autoSyncStatus.value = 'Auto-sync failed: ${e.toString()}';
      print('❌ Auto-sync failed: $e');
    }
  }

  /// Format sync time for display
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

  /// Public methods for settings
  void enableAutoSync(bool enabled) {
    autoSyncEnabled.value = enabled;
  }

  void setSyncFrequency(int minutes) {
    if (minutes >= 1 && minutes <= 60) {
      syncFrequencyMinutes.value = minutes;
    }
  }

  void enableSyncOnDataChange(bool enabled) {
    syncOnDataChange.value = enabled;
  }

  void enableSyncOnLogin(bool enabled) {
    syncOnLogin.value = enabled;
  }

  void enableSyncOnNetworkRestore(bool enabled) {
    syncOnNetworkRestore.value = enabled;
  }

  void enableBackgroundSync(bool enabled) {
    backgroundSyncEnabled.value = enabled;
  }

  void enableWifiOnlySync(bool enabled) {
    wifiOnlySync.value = enabled;
  }

  /// Get auto-sync statistics
  Map<String, dynamic> getAutoSyncStats() {
    return {
      'enabled': autoSyncEnabled.value,
      'frequency': syncFrequencyMinutes.value,
      'status': autoSyncStatus.value,
      'lastAutoSync': lastAutoSync.value,
      'syncOnDataChange': syncOnDataChange.value,
      'syncOnLogin': syncOnLogin.value,
      'syncOnNetworkRestore': syncOnNetworkRestore.value,
      'backgroundSyncEnabled': backgroundSyncEnabled.value,
      'wifiOnlySync': wifiOnlySync.value,
    };
  }
}

// Update your DatabaseHelperSyncExtension to trigger auto-sync
class DatabaseHelperSyncExtension {
  static Future<int> insertWithSync(
      Database db, String table, Map<String, dynamic> values) async {
    values['last_modified'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    values['firebase_synced'] = 0;

    // Add firebase_user_id if not present
    if (values['firebase_user_id'] == null) {
      try {
        final authController = Get.find<AuthController>();
        if (authController.isFirebaseAuthenticated) {
          values['firebase_user_id'] = authController.currentFirebaseUserId;
        }
      } catch (e) {
        print('⚠️ Could not get Firebase user ID: $e');
      }
    }

    final result = await db.insert(table, values);

    // Trigger auto-sync data change detection
    _triggerAutoSyncDataChange();

    return result;
  }

  static Future<int> updateWithSync(
      Database db,
      String table,
      Map<String, dynamic> values,
      String where,
      List<dynamic> whereArgs) async {
    values['last_modified'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    values['firebase_synced'] = 0;

    final result =
        await db.update(table, values, where: where, whereArgs: whereArgs);

    // Trigger auto-sync data change detection
    _triggerAutoSyncDataChange();

    return result;
  }

  static Future<int> deleteWithSync(
      Database db, String table, String where, List<dynamic> whereArgs) async {
    try {
      final result = await db.update(
          table,
          {
            'deleted': 1,
            'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
            'firebase_synced': 0,
          },
          where: where,
          whereArgs: whereArgs);

      // Trigger auto-sync data change detection
      _triggerAutoSyncDataChange();

      return result;
    } catch (e) {
      final result = await db.delete(table, where: where, whereArgs: whereArgs);
      _triggerAutoSyncDataChange();
      return result;
    }
  }

  static void _triggerAutoSyncDataChange() {
    try {
      final autoSyncController = Get.find<AutoSyncController>();
      autoSyncController.triggerDataChangeSync();
    } catch (e) {
      print('⚠️ Auto-sync controller not available: $e');
      // Fallback to manual sync service
      try {
        final syncService = Get.find<MultiTenantFirebaseSyncService>();
        syncService.triggerDebouncedSync(delay: const Duration(seconds: 10));
      } catch (e2) {
        print('⚠️ Could not trigger any sync: $e2');
      }
    }
  }
}
