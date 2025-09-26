// lib/controllers/subscription_controller.dart
import 'package:driving/models/subscription_package.dart';
import 'package:driving/screens/subscription/subscription_screen.dart';
import 'package:driving/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';

class SubscriptionController extends GetxController {
  final RxList<SubscriptionPackage> availablePackages =
      <SubscriptionPackage>[].obs;
  final Rxn<SubscriptionPackage> currentPackage = Rxn<SubscriptionPackage>();
  final RxString subscriptionStatus = 'trial'.obs;
  final RxInt remainingTrialDays = 30.obs;
  final RxString billingPeriod = 'monthly'.obs;
  final RxBool isLoading = false.obs;

  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void onInit() {
    super.onInit();
    loadSubscriptionData();
  }

  Future<void> loadSubscriptionData() async {
    try {
      isLoading(true);

      // Load packages and current status concurrently
      final results = await Future.wait([
        _subscriptionService.getSubscriptionPackages(),
        _subscriptionService.getSubscriptionStatus(),
      ]);

      availablePackages.value = results[0] as List<SubscriptionPackage>;
      final statusData = results[1] as Map<String, dynamic>;

      subscriptionStatus.value = statusData['subscription_status'];
      remainingTrialDays.value = statusData['remaining_trial_days'] ?? 0;

      if (statusData['current_package'] != null) {
        currentPackage.value = availablePackages.firstWhereOrNull(
            (pkg) => pkg.id == statusData['current_package']['id']);
      }

      // Check if trial expired
      if (subscriptionStatus.value == 'expired' ||
          (subscriptionStatus.value == 'trial' &&
              remainingTrialDays.value <= 0)) {
        _showTrialExpiredDialog();
      }
    } catch (e) {
      print('Error loading subscription data: $e');
      Get.snackbar('Error', 'Failed to load subscription data');
    } finally {
      isLoading(false);
    }
  }

  Future<void> upgradeToPackage(SubscriptionPackage package) async {
    try {
      isLoading(true);

      final clientSecret = await _subscriptionService.createPaymentIntent(
          package.id, billingPeriod.value);

      // Initialize Stripe payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'DriveSync Pro',
          style: ThemeMode.system,
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Reload subscription data after successful payment
      await loadSubscriptionData();

      Get.snackbar(
        'Success',
        'Subscription upgraded successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Payment error: $e');
      Get.snackbar(
        'Error',
        'Payment failed. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  void _showTrialExpiredDialog() {
    if (availablePackages.isEmpty) return;

    final professionalPackage =
        availablePackages.firstWhereOrNull((pkg) => pkg.slug == 'professional');

    if (professionalPackage == null) return;

    Get.dialog(
      AlertDialog(
        title: Text('Trial Expired'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Your ${remainingTrialDays.value <= 0 ? "trial has ended" : "trial is about to end"}. Upgrade to continue using all features.'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    professionalPackage.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '\$${professionalPackage.monthlyPrice}/month',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.to(() => SubscriptionScreen());
            },
            child: Text('View Plans'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
