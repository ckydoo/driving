import 'package:driving/controllers/sync_controller.dart';
import 'package:driving/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple Initial Sync Screen - Shows progress during first sync
class InitialSyncScreen extends StatefulWidget {
  const InitialSyncScreen({Key? key}) : super(key: key);

  @override
  State<InitialSyncScreen> createState() => _InitialSyncScreenState();
}

class _InitialSyncScreenState extends State<InitialSyncScreen> {
  final SyncController _syncController = Get.find<SyncController>();
  bool _syncStarted = false;

  @override
  void initState() {
    super.initState();
    // Start sync after a brief delay
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted && !_syncStarted) {
        _syncStarted = true;
        _startSync();
      }
    });
  }

  Future<void> _startSync() async {
    // Perform sync using your existing method
    await _syncController.performSmartSync();

    // Save that initial sync is complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('initial_sync_complete', true);
    await prefs.setString('last_full_sync', DateTime.now().toIso8601String());

    // Wait a moment then navigate to main
    if (mounted) {
      await Future.delayed(Duration(milliseconds: 500));
      AppRoutes.toMain();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back during sync
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Icon(
                  Icons.school,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),

                Text(
                  'DriveSync Pro',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 48),

                // Progress indicator
                Obx(() => SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                          if (_syncController.isSyncing.value)
                            Icon(
                              Icons.sync,
                              size: 40,
                              color: Theme.of(context).primaryColor,
                            ),
                        ],
                      ),
                    )),
                const SizedBox(height: 32),

                // Status text
                Obx(() => Text(
                      _syncController.syncStatus.value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    )),
                const SizedBox(height: 40),

                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Setting up your workspace. This usually takes 10-30 seconds.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
