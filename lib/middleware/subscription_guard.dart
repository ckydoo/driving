// lib/middleware/subscription_guard.dart - FIXED WITH REAL-TIME CHECK

import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/subscription_controller.dart';
import 'package:driving/screens/subscription/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SubscriptionGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    try {
      // Skip check for subscription-related routes
      if (route?.contains('/subscription') == true ||
          route == '/login' ||
          route == '/school-selection') {
        return null;
      }

      final authController = Get.find<AuthController>();
      final subscriptionController = Get.find<SubscriptionController>();

      // Only check if user is logged in
      if (!authController.isLoggedIn.value) {
        return null; // Auth middleware will handle this
      }

      print('🔐 Subscription Guard Check:');
      print('   Route: ${route}');

      // CRITICAL: Refresh status from server before allowing access
      try {
        print('🔄 Checking current subscription status from server...');
        subscriptionController.loadSubscriptionData();
      } catch (e) {
        print('⚠️ Failed to check subscription status: $e');
        // If we can't check, allow access (fail open) but log the error
        return null;
      }

      final status = subscriptionController.subscriptionStatus.value;
      final trialDays = subscriptionController.remainingTrialDays.value;

      print('   Status from server: $status');
      print('   Trial Days: $trialDays');

      // Block if suspended
      if (status == 'suspended') {
        print('🚫 BLOCKED: Subscription suspended');
        _showSubscriptionDialog(
          'Subscription Suspended',
          'Your subscription has been suspended. Please contact support or update your payment method.',
          canUpgrade: false,
          status: 'suspended',
        );
        return RouteSettings(name: '/subscription');
      }

      // Block if expired
      if (status == 'expired') {
        print('🚫 BLOCKED: Subscription expired');
        _showSubscriptionDialog(
          'Subscription Expired',
          'Your subscription has expired. Please renew to continue using the service.',
          canUpgrade: true,
          status: 'expired',
        );
        return RouteSettings(name: '/subscription');
      }

      // Block if trial expired
      if (status == 'trial' && trialDays <= 0) {
        print('🚫 BLOCKED: Trial expired');
        _showSubscriptionDialog(
          'Trial Expired',
          'Your free trial has ended. Please subscribe to continue using the service.',
          canUpgrade: true,
          status: 'trial_expired',
        );
        return RouteSettings(name: '/subscription');
      }

      print('✅ ALLOWED: Subscription is $status with $trialDays days');
      return null; // Allow access
    } catch (e) {
      print('❌ Subscription Guard Error: $e');
      print('Stack trace: ${StackTrace.current}');
      return null; // Allow access if error (fail open)
    }
  }

  void _showSubscriptionDialog(
    String title,
    String message, {
    bool canUpgrade = true,
    required String status,
  }) {
    // Use Future.delayed to avoid dialog during build
    Future.delayed(Duration(milliseconds: 500), () {
      if (Get.context != null && !Get.isDialogOpen!) {
        IconData icon;
        Color iconColor;

        switch (status) {
          case 'suspended':
            icon = Icons.block;
            iconColor = Colors.red[700]!;
            break;
          case 'expired':
            icon = Icons.warning_amber_rounded;
            iconColor = Colors.orange[700]!;
            break;
          case 'trial_expired':
            icon = Icons.access_time_filled;
            iconColor = Colors.blue[700]!;
            break;
          default:
            icon = Icons.info_outline;
            iconColor = Colors.grey[700]!;
        }

        Get.dialog(
          WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(fontSize: 16),
                  ),
                  if (!canUpgrade) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.support_agent, color: Colors.blue[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please contact support for assistance.',
                              style: TextStyle(color: Colors.blue[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (canUpgrade && status == 'trial_expired') ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[600]!, Colors.blue[800]!],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Upgrade now to unlock all premium features!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (canUpgrade) ...[
                  TextButton(
                    onPressed: () {
                      Get.back();
                      // Go back to previous screen
                      Get.back();
                    },
                    child: Text('Go Back'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      // Stay on subscription screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                    child: Text('View Plans'),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      Get.back(); // Go back to previous screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                    child: Text('OK'),
                  ),
                ],
              ],
            ),
          ),
          barrierDismissible: false,
        );
      }
    });
  }
}

/// Helper to check subscription status from anywhere in the app
class SubscriptionHelper {
  /// Check if subscription is currently active (checks server)
  static Future<bool> checkIsActive() async {
    try {
      if (!Get.isRegistered<SubscriptionController>()) {
        return true; // Fail open if controller not registered
      }

      final controller = Get.find<SubscriptionController>();

      // Refresh from server
      try {
        await controller.loadSubscriptionData();
      } catch (e) {
        print('⚠️ Could not refresh subscription status: $e');
        // Use cached value if refresh fails
      }

      final status = controller.subscriptionStatus.value;
      final trialDays = controller.remainingTrialDays.value;

      return status == 'active' || (status == 'trial' && trialDays > 0);
    } catch (e) {
      print('Error checking subscription: $e');
      return true; // Fail open
    }
  }

  static bool get isSubscriptionActive {
    try {
      if (!Get.isRegistered<SubscriptionController>()) {
        return true; // Fail open if controller not registered
      }

      final controller = Get.find<SubscriptionController>();
      final status = controller.subscriptionStatus.value;

      return status == 'active' ||
          (status == 'trial' && controller.remainingTrialDays.value > 0);
    } catch (e) {
      print('Error checking subscription: $e');
      return true; // Fail open
    }
  }

  static bool get isTrialExpired {
    try {
      if (!Get.isRegistered<SubscriptionController>()) {
        return false;
      }

      final controller = Get.find<SubscriptionController>();
      return controller.subscriptionStatus.value == 'trial' &&
          controller.remainingTrialDays.value <= 0;
    } catch (e) {
      return false;
    }
  }

  static bool get isSuspended {
    try {
      if (!Get.isRegistered<SubscriptionController>()) {
        return false;
      }

      final controller = Get.find<SubscriptionController>();
      return controller.subscriptionStatus.value == 'suspended';
    } catch (e) {
      return false;
    }
  }

  static bool get isExpired {
    try {
      if (!Get.isRegistered<SubscriptionController>()) {
        return false;
      }

      final controller = Get.find<SubscriptionController>();
      return controller.subscriptionStatus.value == 'expired';
    } catch (e) {
      return false;
    }
  }

  static void showUpgradeDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Upgrade Required'),
        content: Text(
            'This feature requires an active subscription. Would you like to view available plans?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: Text('View Plans'),
          ),
        ],
      ),
    );
  }

  /// Show blocking dialog when subscription check fails
  static void showBlockedDialog(String reason) {
    Future.delayed(Duration(milliseconds: 300), () {
      if (!Get.isDialogOpen!) {
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red[700]),
                SizedBox(width: 12),
                Text('Access Blocked'),
              ],
            ),
            content: Text(reason),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.offAllNamed('/subscription');
                },
                child: Text('View Subscription'),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      }
    });
  }
}
