// Add this widget to show sync status in your app

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../services/firebase_sync_service.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<FirebaseSyncService>(
      builder: (syncService) {
        if (!syncService.firebaseAvailable.value) {
          return const SizedBox.shrink(); // Hide if Firebase unavailable
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getSyncStatusColor(syncService),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getSyncStatusIcon(syncService),
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                _getSyncStatusText(syncService),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
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
      return Icons.check_circle;
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
      } else {
        return 'Synced ${minutesAgo}m ago';
      }
    }
  }
}

// Usage: Add this to your AppBar or anywhere in your UI
/*
AppBar(
  title: Text('My App'),
  actions: [
    const SyncStatusWidget(),
    const SizedBox(width: 16),
  ],
),
*/
