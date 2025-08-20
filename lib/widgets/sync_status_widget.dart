// Enhanced Clickable Sync Status Widget
// Replace your existing SyncStatusWidget with this improved version

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../services/firebase_sync_service.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool showText;
  final bool showTooltip;

  const SyncStatusWidget({
    Key? key,
    this.showText = true,
    this.showTooltip = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<FirebaseSyncService>(
      builder: (syncService) {
        if (!syncService.firebaseAvailable.value) {
          return const SizedBox.shrink(); // Hide if Firebase unavailable
        }

        final widget = GestureDetector(
          onTap: () => _handleSyncTap(syncService),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: showText ? 12 : 8,
              vertical: showText ? 4 : 8,
            ),
            decoration: BoxDecoration(
              color: _getSyncStatusColor(syncService),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _getSyncStatusColor(syncService).withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated sync icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: syncService.isSyncing.value
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          _getSyncStatusIcon(syncService),
                          size: 14,
                          color: Colors.white,
                          key: ValueKey(_getSyncStatusIcon(syncService)),
                        ),
                ),
                if (showText) ...[
                  const SizedBox(width: 6),
                  Text(
                    _getSyncStatusText(syncService),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
            message: _getTooltipMessage(syncService),
            child: widget,
          );
        }

        return widget;
      },
    );
  }

  void _handleSyncTap(FirebaseSyncService syncService) async {
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

    // Check prerequisites
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

    if (!authController.isFirebaseAuthenticated) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to sync your data',
        icon: const Icon(Icons.account_circle, color: Colors.white),
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

  Color _getSyncStatusColor(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return Colors.blue;
    } else if (!syncService.isOnline.value) {
      return Colors.orange;
    } else if (!Get.find<AuthController>().isFirebaseAuthenticated) {
      return Colors.red;
    } else {
      return Colors.green;
    }
  }

  IconData _getSyncStatusIcon(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return Icons.sync;
    } else if (!syncService.isOnline.value) {
      return Icons.wifi_off;
    } else if (!Get.find<AuthController>().isFirebaseAuthenticated) {
      return Icons.account_circle;
    } else {
      return Icons.cloud_done;
    }
  }

  String _getSyncStatusText(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return 'Syncing...';
    } else if (!syncService.isOnline.value) {
      return 'Offline';
    } else if (!Get.find<AuthController>().isFirebaseAuthenticated) {
      return 'Sign in required';
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

  String _getTooltipMessage(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return 'Sync in progress... Please wait';
    } else if (!syncService.isOnline.value) {
      return 'No internet connection. Click to retry when online.';
    } else if (!Get.find<AuthController>().isFirebaseAuthenticated) {
      return 'Firebase authentication required for sync';
    } else {
      return 'Click to sync your data now';
    }
  }
}

// Alternative: Icon-only version for use in compact spaces
class SyncIconWidget extends StatelessWidget {
  const SyncIconWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SyncStatusWidget(
      showText: false,
      showTooltip: true,
    );
  }
}

// Alternative: Floating Action Button style sync widget
class SyncFABWidget extends StatelessWidget {
  const SyncFABWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<FirebaseSyncService>(
      builder: (syncService) {
        if (!syncService.firebaseAvailable.value) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.small(
          onPressed: () => _handleSyncTap(syncService),
          backgroundColor: _getSyncStatusColor(syncService),
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
                  _getSyncStatusIcon(syncService),
                  color: Colors.white,
                  size: 20,
                ),
        );
      },
    );
  }

  void _handleSyncTap(FirebaseSyncService syncService) async {
    // Same logic as main widget
    final authController = Get.find<AuthController>();

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

    if (!authController.isFirebaseAuthenticated) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to sync your data',
        icon: const Icon(Icons.account_circle, color: Colors.white),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    Get.snackbar(
      'Sync Started',
      'Synchronizing your data...',
      icon: const Icon(Icons.sync, color: Colors.white),
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );

    try {
      await syncService.triggerManualSync();

      Get.snackbar(
        'Sync Complete',
        'Your data has been synchronized successfully',
        icon: const Icon(Icons.check_circle, color: Colors.white),
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
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

  Color _getSyncStatusColor(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return Colors.blue;
    } else if (!syncService.isOnline.value) {
      return Colors.orange;
    } else if (!Get.find<AuthController>().isFirebaseAuthenticated) {
      return Colors.red;
    } else {
      return Colors.green;
    }
  }

  IconData _getSyncStatusIcon(FirebaseSyncService syncService) {
    if (syncService.isSyncing.value) {
      return Icons.sync;
    } else if (!syncService.isOnline.value) {
      return Icons.wifi_off;
    } else if (!Get.find<AuthController>().isFirebaseAuthenticated) {
      return Icons.account_circle;
    } else {
      return Icons.cloud_done;
    }
  }
}
