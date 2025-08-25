// lib/widgets/sync_status_widget.dart - Fixed for GetxService compatibility
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool showText;
  final bool showTooltip;
  final bool isCompact;

  const SyncStatusWidget({
    Key? key,
    this.showText = true,
    this.showTooltip = true,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use Obx to listen to observable properties directly
    return Obx(() {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      final authController = Get.find<AuthController>();

      final widget = GestureDetector(
        onTap: () => _handleSyncTap(syncService),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 12,
            vertical: isCompact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: _getSyncStatusColor(syncService, authController),
            borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
            boxShadow: [
              BoxShadow(
                color: _getSyncStatusColor(syncService, authController)
                    .withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status Icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: syncService.isSyncing.value
                    ? SizedBox(
                        width: isCompact ? 12 : 14,
                        height: isCompact ? 12 : 14,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _getSyncStatusIcon(syncService, authController),
                        size: isCompact ? 12 : 14,
                        color: Colors.white,
                        key: ValueKey(
                            _getSyncStatusIcon(syncService, authController)),
                      ),
              ),
              if (showText) ...[
                SizedBox(width: isCompact ? 4 : 6),
                Text(
                  _getSyncStatusText(syncService, authController),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      // Wrap with tooltip if enabled
      if (showTooltip) {
        return Tooltip(
          message: _getTooltipMessage(syncService, authController),
          child: widget,
        );
      }

      return widget;
    });
  }

  void _handleSyncTap(MultiTenantFirebaseSyncService syncService) async {
    final authController = Get.find<AuthController>();

    // Don't allow sync if already syncing
    if (syncService.isSyncing.value) {
      Get.snackbar(
        'Sync in Progress',
        'Please wait for the current sync to complete',
        icon: const Icon(Icons.info, color: Colors.white),
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Check internet connection
    if (!syncService.isOnline.value) {
      Get.snackbar(
        'No Internet Connection',
        'Please check your internet connection and try again',
        icon: const Icon(Icons.wifi_off, color: Colors.white),
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // NEW: Firebase-first authentication check
    if (!authController.isFirebaseAuthenticated) {
      // If user is locally authenticated but not Firebase authenticated
      if (authController.isLoggedIn.value) {
        Get.snackbar(
          'Cloud Sync Unavailable',
          'Sign in with your cloud account to enable sync',
          icon: const Icon(Icons.cloud_off, color: Colors.white),
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          mainButton: TextButton(
            onPressed: () => _promptForCloudSignIn(),
            child: const Text('SIGN IN', style: TextStyle(color: Colors.white)),
          ),
        );
      } else {
        Get.snackbar(
          'Authentication Required',
          'Please sign in to sync your data',
          icon: const Icon(Icons.account_circle, color: Colors.white),
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }

    // Firebase is not available
    if (!authController.firebaseAvailable.value) {
      Get.snackbar(
        'Firebase Unavailable',
        'Cloud services are currently unavailable',
        icon: const Icon(Icons.cloud_off, color: Colors.white),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Show sync starting message
    Get.snackbar(
      'Sync Started',
      'Synchronizing your data...',
      icon: const Icon(Icons.sync, color: Colors.white),
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );

    try {
      // Trigger manual sync
      await syncService.triggerManualSync();

      // Show success message
      Get.snackbar(
        'Sync Complete',
        'Your data has been synchronized successfully',
        icon: const Icon(Icons.check_circle, color: Colors.white),
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      // Show error message
      Get.snackbar(
        'Sync Failed',
        'Failed to sync data: ${e.toString()}',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _promptForCloudSignIn() {
    Get.dialog(
      AlertDialog(
        title: const Text('Cloud Sync'),
        content: const Text(
          'To enable automatic cloud sync, please sign in with your cloud account. '
          'This will ensure your data is backed up and synchronized across devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed('/login');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Color _getSyncStatusColor(MultiTenantFirebaseSyncService syncService,
      AuthController authController) {
    if (syncService.isSyncing.value) {
      return Colors.blue;
    } else if (!syncService.isOnline.value) {
      return Colors.orange;
    } else if (!authController.firebaseAvailable.value) {
      return Colors.red;
    } else if (!authController.isFirebaseAuthenticated) {
      // Only show red if user is not authenticated at all
      // Show orange if locally authenticated but not Firebase authenticated
      return authController.isLoggedIn.value ? Colors.orange : Colors.red;
    } else {
      return Colors.green;
    }
  }

  IconData _getSyncStatusIcon(MultiTenantFirebaseSyncService syncService,
      AuthController authController) {
    if (syncService.isSyncing.value) {
      return Icons.sync;
    } else if (!syncService.isOnline.value) {
      return Icons.wifi_off;
    } else if (!authController.firebaseAvailable.value) {
      return Icons.cloud_off;
    } else if (!authController.isFirebaseAuthenticated) {
      return authController.isLoggedIn.value
          ? Icons.cloud_off
          : Icons.account_circle;
    } else {
      return Icons.cloud_done;
    }
  }

  String _getSyncStatusText(MultiTenantFirebaseSyncService syncService,
      AuthController authController) {
    if (syncService.isSyncing.value) {
      return 'Syncing...';
    } else if (!syncService.isOnline.value) {
      return 'Offline';
    } else if (!authController.firebaseAvailable.value) {
      return 'Cloud unavailable';
    } else if (!authController.isFirebaseAuthenticated) {
      if (authController.isLoggedIn.value) {
        return 'Local only';
      } else {
        return 'Sign in required';
      }
    } else {
      final lastSync = syncService.lastSyncTime.value;
      final minutesAgo = DateTime.now().difference(lastSync).inMinutes;
      if (minutesAgo < 1) {
        return 'Just synced';
      } else if (minutesAgo < 60) {
        return 'Synced ${minutesAgo}m ago';
      } else {
        final hoursAgo = (minutesAgo / 60).floor();
        return 'Synced ${hoursAgo}h ago';
      }
    }
  }

  String _getTooltipMessage(MultiTenantFirebaseSyncService syncService,
      AuthController authController) {
    if (syncService.isSyncing.value) {
      return 'Sync in progress... Please wait';
    } else if (!syncService.isOnline.value) {
      return 'No internet connection. Click to retry when online.';
    } else if (!authController.firebaseAvailable.value) {
      return 'Firebase cloud services are unavailable';
    } else if (!authController.isFirebaseAuthenticated) {
      if (authController.isLoggedIn.value) {
        return 'Click to sign in for cloud sync';
      } else {
        return 'Authentication required for sync';
      }
    } else {
      return 'Click to sync your data now';
    }
  }
}

// Compact version for use in tight spaces
class SyncIconWidget extends StatelessWidget {
  const SyncIconWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SyncStatusWidget(
      showText: false,
      showTooltip: true,
      isCompact: true,
    );
  }
}

// Floating Action Button version
class SyncFABWidget extends StatelessWidget {
  const SyncFABWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      final authController = Get.find<AuthController>();

      return FloatingActionButton(
        onPressed: () => SyncStatusWidget()._handleSyncTap(syncService),
        backgroundColor:
            SyncStatusWidget()._getSyncStatusColor(syncService, authController),
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
                SyncStatusWidget()
                    ._getSyncStatusIcon(syncService, authController),
                color: Colors.white,
              ),
      );
    });
  }
}

// Status bar version
class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();
      final authController = Get.find<AuthController>();
      final statusColor =
          SyncStatusWidget()._getSyncStatusColor(syncService, authController);

      // Only show status bar if there are issues
      if (statusColor == Colors.green) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: statusColor,
        child: Row(
          children: [
            Icon(
              SyncStatusWidget()
                  ._getSyncStatusIcon(syncService, authController),
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                SyncStatusWidget()
                    ._getTooltipMessage(syncService, authController),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!authController.isFirebaseAuthenticated &&
                authController.isLoggedIn.value)
              TextButton(
                onPressed: () => Get.offAllNamed('/login'),
                child: const Text(
                  'SIGN IN',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      );
    });
  }
}
