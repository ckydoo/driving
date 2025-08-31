import 'package:driving/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppAccessController extends GetxController {
  final SubscriptionService _subscriptionService =
      Get.find<SubscriptionService>();

  @override
  void onInit() {
    super.onInit();
    _setupAccessMonitoring();
  }

  void _setupAccessMonitoring() {
    // Monitor subscription status changes
    ever(_subscriptionService.subscriptionStatus, (String status) {
      if (status == 'expired' && Get.currentRoute != '/subscription') {
        _handleSubscriptionExpired();
      }
    });

    // Monitor trial expiration
    ever(_subscriptionService.daysRemainingInTrial, (int days) {
      if (days <= 0 && _subscriptionService.isInFreeTrial.value) {
        _handleTrialExpired();
      }
    });
  }

  void _handleSubscriptionExpired() {
    Get.offAllNamed('/subscription');
    Get.snackbar(
      'Subscription Expired',
      'Your subscription has expired. Please renew to continue using the app.',
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 5),
    );
  }

  void _handleTrialExpired() {
    Get.offAllNamed('/subscription');
    Get.snackbar(
      'Free Trial Ended',
      'Your free trial has ended. Subscribe now to continue using the app.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: Duration(seconds: 5),
    );
  }

  /// Check if user can access a specific feature
  bool canAccessFeature(String featureName) {
    if (!_subscriptionService.canUseApp) {
      _showFeatureBlockedDialog(featureName);
      return false;
    }
    return true;
  }

  void _showFeatureBlockedDialog(String featureName) {
    Get.dialog(
      AlertDialog(
        title: Text('Feature Locked'),
        content: Text('$featureName requires an active subscription.'),
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
            child: Text('Subscribe'),
          ),
        ],
      ),
    );
  }
}
