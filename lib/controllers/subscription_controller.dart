// lib/controllers/subscription_controller.dart - COMPLETE PRODUCTION READY VERSION
import 'package:driving/models/subscription_package.dart';
import 'package:driving/screens/subscription/subscription_screen.dart';
import 'package:driving/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';

class SubscriptionController extends GetxController {
  // Observable variables
  final RxList<SubscriptionPackage> availablePackages =
      <SubscriptionPackage>[].obs;
  final Rxn<SubscriptionPackage> currentPackage = Rxn<SubscriptionPackage>();
  final RxString subscriptionStatus = 'trial'.obs;
  final RxInt remainingTrialDays = 30.obs;
  final RxString billingPeriod = 'monthly'.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void onInit() {
    super.onInit();
    loadSubscriptionData();
  }

  // ============================================
  // Load subscription data from backend
  // ============================================
  Future<void> loadSubscriptionData() async {
    try {
      isLoading(true);
      errorMessage.value = '';

      print('🔄 Loading subscription data...');

      // Load packages and current status concurrently
      final results = await Future.wait([
        _subscriptionService.getSubscriptionPackages(),
        _subscriptionService.getSubscriptionStatus(),
      ]);

      availablePackages.value = results[0] as List<SubscriptionPackage>;
      final statusData = results[1] as Map<String, dynamic>;

      subscriptionStatus.value = statusData['subscription_status'] ?? 'trial';
      remainingTrialDays.value = statusData['remaining_trial_days'] ?? 0;

      if (statusData['current_package'] != null) {
        currentPackage.value = availablePackages.firstWhereOrNull(
            (pkg) => pkg.id == statusData['current_package']['id']);
      }

      print(
          '✅ Subscription data loaded: ${subscriptionStatus.value}, ${remainingTrialDays.value} days remaining');

      // Check if trial expired
      if (subscriptionStatus.value == 'expired' ||
          (subscriptionStatus.value == 'trial' &&
              remainingTrialDays.value <= 0)) {
        _showTrialExpiredDialog();
      }
    } catch (e) {
      print('❌ Error loading subscription data: $e');
      errorMessage.value = 'Failed to load subscription data: $e';
      Get.snackbar(
        'Error',
        'Failed to load subscription data',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        icon: Icon(Icons.error_outline, color: Colors.red[900]),
      );
    } finally {
      isLoading(false);
    }
  }

  // ============================================
  // Upgrade to a subscription package
  // ============================================
  Future<void> upgradeToPackage(SubscriptionPackage package) async {
    try {
      isLoading(true);
      errorMessage.value = '';

      print('🔄 Starting upgrade to ${package.name}...');

      // Step 1: Create payment intent (returns String directly)
      final clientSecret = await _subscriptionService.createPaymentIntent(
          package.id, billingPeriod.value);

      print('✅ Payment intent created');

      // Step 2: Initialize Stripe payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'DriveSync Pro',
          style: ThemeMode.system,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Colors.blue,
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12,
            ),
          ),
        ),
      );

      print('✅ Payment sheet initialized');

      // Step 3: Present payment sheet to user
      await Stripe.instance.presentPaymentSheet();

      print('✅ Payment sheet completed');

      // Step 4: Retrieve payment intent to get its ID and status
      final paymentIntent =
          await Stripe.instance.retrievePaymentIntent(clientSecret);

      print('💳 Payment Intent Status: ${paymentIntent.status}');
      print('💳 Payment Intent ID: ${paymentIntent.id}');

      // Step 5: Confirm payment with backend
      if (paymentIntent.status == PaymentIntentsStatus.Succeeded) {
        print('🔄 Confirming payment with backend...');

        final confirmed = await _subscriptionService.confirmPayment(
          paymentIntent.id,
          package.id,
          billingPeriod.value,
        );

        if (confirmed) {
          print('✅ Payment confirmed on backend');

          // Step 6: Reload subscription data
          await loadSubscriptionData();

          // Step 7: Show success message
          Get.snackbar(
            'Success',
            'Subscription upgraded successfully to ${package.name}!',
            backgroundColor: Colors.green[100],
            colorText: Colors.green[900],
            icon: Icon(Icons.check_circle, color: Colors.green[900]),
            duration: Duration(seconds: 5),
          );

          // Optional: Navigate back or to a success screen
          Get.back();
        } else {
          throw Exception('Payment confirmation failed on server');
        }
      } else {
        throw Exception(
            'Payment not completed. Status: ${paymentIntent.status}');
      }
    } on StripeException catch (e) {
      print('❌ Stripe error: ${e.error.localizedMessage}');
      errorMessage.value = e.error.localizedMessage ?? 'Payment failed';

      // Only show error if user didn't cancel
      if (e.error.code != FailureCode.Canceled) {
        Get.snackbar(
          'Payment Error',
          e.error.localizedMessage ?? 'Payment failed',
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          icon: Icon(Icons.error_outline, color: Colors.red[900]),
          duration: Duration(seconds: 5),
        );
      }
    } catch (e) {
      print('❌ Error upgrading subscription: $e');
      errorMessage.value = e.toString();

      Get.snackbar(
        'Error',
        'Failed to upgrade subscription: $e',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        icon: Icon(Icons.error_outline, color: Colors.red[900]),
        duration: Duration(seconds: 5),
      );
    } finally {
      isLoading(false);
    }
  }

  // ============================================
  // Show trial expired dialog
  // ============================================
  void _showTrialExpiredDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Trial Expired'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your trial period has ended.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Please upgrade to a paid plan to continue using all features of DriveSync Pro.',
              style: TextStyle(fontSize: 14),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('View Plans'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // ============================================
  // Toggle billing period (monthly/yearly)
  // ============================================
  void toggleBillingPeriod() {
    billingPeriod.value =
        billingPeriod.value == 'monthly' ? 'yearly' : 'monthly';
  }

  // ============================================
  // Get package price based on billing period
  // ============================================
  double getPackagePrice(SubscriptionPackage package) {
    return package.getPrice(billingPeriod.value);
  }

  // ============================================
  // Get formatted price string
  // ============================================
  String getFormattedPrice(SubscriptionPackage package) {
    final price = getPackagePrice(package);
    return '\$${price.toStringAsFixed(2)}';
  }

  // ============================================
  // Get billing period text
  // ============================================
  String getBillingPeriodText() {
    return billingPeriod.value == 'monthly' ? 'per month' : 'per year';
  }

  // ============================================
  // Check if package is current
  // ============================================
  bool isCurrentPackage(SubscriptionPackage package) {
    return currentPackage.value?.id == package.id;
  }

  // ============================================
  // Check if user can upgrade
  // ============================================
  bool canUpgrade() {
    return subscriptionStatus.value == 'trial' ||
        subscriptionStatus.value == 'expired';
  }

  // ============================================
  // Cancel subscription
  // ============================================
  Future<void> cancelSubscription() async {
    try {
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: Text('Cancel Subscription?'),
          content: Text(
            'Are you sure you want to cancel your subscription? '
            'You will lose access to premium features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('Keep Subscription'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Cancel Subscription'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        isLoading(true);
        final success = await _subscriptionService.cancelSubscription();

        if (success) {
          await loadSubscriptionData();
          Get.snackbar(
            'Success',
            'Subscription cancelled successfully',
            backgroundColor: Colors.green[100],
            colorText: Colors.green[900],
          );
        } else {
          throw Exception('Failed to cancel subscription');
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to cancel subscription: $e',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    } finally {
      isLoading(false);
    }
  }

  // ============================================
  // Get trial days text
  // ============================================
  String getTrialDaysText() {
    if (remainingTrialDays.value <= 0) {
      return 'Trial expired';
    } else if (remainingTrialDays.value == 1) {
      return '1 day remaining';
    } else {
      return '${remainingTrialDays.value} days remaining';
    }
  }

  // ============================================
  // Check if trial is expiring soon
  // ============================================
  bool isTrialExpiring() {
    return subscriptionStatus.value == 'trial' &&
        remainingTrialDays.value <= 7 &&
        remainingTrialDays.value > 0;
  }

  // ============================================
  // Get subscription status color
  // ============================================
  Color getStatusColor() {
    switch (subscriptionStatus.value) {
      case 'active':
        return Colors.green;
      case 'trial':
        return isTrialExpiring() ? Colors.orange : Colors.blue;
      case 'expired':
      case 'cancelled':
        return Colors.red;
      case 'suspended':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ============================================
  // Get subscription status icon
  // ============================================
  IconData getStatusIcon() {
    switch (subscriptionStatus.value) {
      case 'active':
        return Icons.check_circle;
      case 'trial':
        return Icons.access_time;
      case 'expired':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      case 'suspended':
        return Icons.pause_circle;
      default:
        return Icons.help;
    }
  }

  // ============================================
  // Get formatted subscription status text
  // ============================================
  String getFormattedStatus() {
    switch (subscriptionStatus.value) {
      case 'active':
        return 'Active';
      case 'trial':
        return 'Free Trial';
      case 'expired':
        return 'Expired';
      case 'cancelled':
        return 'Cancelled';
      case 'suspended':
        return 'Suspended';
      default:
        return subscriptionStatus.value.toUpperCase();
    }
  }

  // ============================================
  // Calculate savings for yearly billing
  // ============================================
  double calculateYearlySavings(SubscriptionPackage package) {
    if (package.yearlyPrice == null) return 0;

    final monthlyTotal = package.monthlyPrice * 12;
    final yearlySavings = monthlyTotal - package.yearlyPrice!;

    return yearlySavings;
  }

  // ============================================
  // Get savings percentage
  // ============================================
  int getSavingsPercentage(SubscriptionPackage package) {
    if (package.yearlyPrice == null) return 0;

    final monthlyTotal = package.monthlyPrice * 12;
    final savings = calculateYearlySavings(package);
    final percentage = (savings / monthlyTotal * 100).round();

    return percentage;
  }
}
