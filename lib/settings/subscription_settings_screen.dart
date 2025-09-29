// lib/screens/subscription/subscription_screen.dart - FIXED VERSION WITH DEBUGGING
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/subscription_controller.dart';
import '../../models/subscription_package.dart';

class SubscriptionSettingsScreen extends StatelessWidget {
  final SubscriptionController controller = Get.find<SubscriptionController>();

  @override
  Widget build(BuildContext context) {
    // Reload data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadSubscriptionData();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Subscription Plans'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              print('🔄 Manual refresh triggered');
              controller.loadSubscriptionData();
            },
          ),
        ],
      ),
      body: Obx(() {
        // Debug: Print current state
        print('🔍 DEBUG - Building subscription screen');
        print('🔍 isLoading: ${controller.isLoading.value}');
        print(
            '🔍 availablePackages count: ${controller.availablePackages.length}');
        print('🔍 errorMessage: ${controller.errorMessage.value}');

        // Show loading state
        if (controller.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading subscription plans...'),
              ],
            ),
          );
        }

        // Show error state
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Failed to load subscriptions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => controller.loadSubscriptionData(),
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        // Show empty state
        if (controller.availablePackages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No subscription plans available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check your internet connection',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => controller.loadSubscriptionData(),
                  icon: Icon(Icons.refresh),
                  label: Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        // Show main content with data
        return Column(
          children: [
            _buildHeader(),
            _buildBillingToggle(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  print('🔄 Pull to refresh triggered');
                  await controller.loadSubscriptionData();
                },
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Trial status card
                      if (controller.subscriptionStatus.value == 'trial')
                        _buildTrialStatusCard(),
                      SizedBox(height: 16),

                      // Package cards
                      ...controller.availablePackages
                          .map((package) => _buildPackageCard(package))
                          .toList(),

                      SizedBox(height: 20),
                      _buildFeaturesComparison(),
                      SizedBox(height: 20),
                      _buildFAQSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.workspace_premium, size: 48, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'Choose Your Perfect Plan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Upgrade anytime to unlock more features',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => controller.billingPeriod.value = 'monthly',
              child: Obx(() => Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: controller.billingPeriod.value == 'monthly'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: controller.billingPeriod.value == 'monthly'
                          ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
                          : [],
                    ),
                    child: Text(
                      'Monthly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: controller.billingPeriod.value == 'monthly'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  )),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => controller.billingPeriod.value = 'yearly',
              child: Obx(() => Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: controller.billingPeriod.value == 'yearly'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: controller.billingPeriod.value == 'yearly'
                          ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Yearly',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight:
                                controller.billingPeriod.value == 'yearly'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        if (controller.billingPeriod.value == 'yearly')
                          Text(
                            'Save up to 17%',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialStatusCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.orange[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.white, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free Trial Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Obx(() => Text(
                      '${controller.remainingTrialDays.value} days remaining',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(SubscriptionPackage package) {
    final isCurrentPackage = controller.currentPackage.value?.id == package.id;
    final isTrial = package.slug == 'trial';
    final currentStatus = controller.subscriptionStatus.value;

    // Determine if trial can be selected
    bool canSelectTrial = false;
    String? trialBlockReason;

    if (isTrial) {
      // Trial can only be selected if:
      // 1. User has NEVER had a trial before (new account)
      // 2. Admin manually resets trial

      if (currentStatus == 'trial') {
        // Already on trial
        canSelectTrial = false;
        trialBlockReason = 'You are currently on a free trial';
      } else if (currentStatus == 'expired' ||
          currentStatus == 'suspended' ||
          currentStatus == 'cancelled' ||
          currentStatus == 'active') {
        // Has used trial before - can't use again
        canSelectTrial = false;
        trialBlockReason = 'Trial period has already been used';
      } else {
        // Should not happen, but allow for safety
        canSelectTrial = false;
        trialBlockReason = 'Trial not available';
      }
    }

    return Card(
      elevation: isCurrentPackage ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrentPackage
            ? BorderSide(color: Colors.blue[700]!, width: 3)
            : BorderSide.none,
      ),
      margin: EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isCurrentPackage
              ? LinearGradient(
                  colors: [Colors.blue[50]!, Colors.blue[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Package name and current badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      package.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isCurrentPackage
                            ? Colors.blue[900]
                            : Colors.grey[800],
                      ),
                    ),
                  ),
                  if (isCurrentPackage)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'CURRENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (package.isPopular && !isCurrentPackage)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[600],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'POPULAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 8),

              // Description
              Text(
                package.description!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),

              SizedBox(height: 16),

              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${package.getPrice(controller.billingPeriod.value).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(width: 8),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '/${controller.billingPeriod.value == 'yearly' ? 'year' : 'month'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),

              if (controller.billingPeriod.value == 'yearly')
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Save \$${((package.monthlyPrice * 12) - package.yearlyPrice!).toStringAsFixed(0)} per year',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),

              SizedBox(height: 20),

              // Features
              ...package.features.map((feature) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

              SizedBox(height: 20),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isTrial && !canSelectTrial
                      ? null // Disable if trial and can't be selected
                      : isCurrentPackage
                          ? null // Disable if already current package
                          : () => _handlePackageSelection(package),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentPackage
                        ? Colors.grey[400]
                        : isTrial && !canSelectTrial
                            ? Colors.grey[300]
                            : Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: isCurrentPackage || (isTrial && !canSelectTrial)
                        ? 0
                        : 2,
                  ),
                  child: Text(
                    isCurrentPackage
                        ? 'Current Plan'
                        : isTrial && !canSelectTrial
                            ? 'Not Available'
                            : isTrial
                                ? 'Start Free Trial'
                                : 'Select Plan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Show reason why trial is blocked
              if (isTrial && !canSelectTrial && trialBlockReason != null)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.orange[700], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trialBlockReason,
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePackageSelection(SubscriptionPackage package) {
    final isTrial = package.slug == 'trial';
    final currentStatus = controller.subscriptionStatus.value;

    // Block trial if already used
    if (isTrial) {
      if (currentStatus == 'trial') {
        Get.snackbar(
          'Already on Trial',
          'You are currently using your free trial period.',
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[900],
          icon: Icon(Icons.info_outline, color: Colors.orange[900]),
        );
        return;
      } else {
        // Trial has been used before
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red[700]),
                SizedBox(width: 12),
                Text('Trial Not Available'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your free trial period has already been used.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Choose one of our paid plans to continue using the service.',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                ),
                child: Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // For paid packages - check if it's the current package
    if (controller.currentPackage.value?.id == package.id) {
      Get.snackbar(
        'Current Package',
        'You are already subscribed to this package.',
        backgroundColor: Colors.blue[100],
        colorText: Colors.blue[900],
      );
      return;
    }

    // Show upgrade confirmation dialog
    Get.dialog(
      AlertDialog(
        title: Text('Subscribe to ${package.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You\'re about to subscribe to:'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '\$${package.getPrice(controller.billingPeriod.value).toStringAsFixed(2)}/${controller.billingPeriod.value == 'yearly' ? 'year' : 'month'}',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Billing: ${controller.billingPeriod.value}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              currentStatus == 'trial'
                  ? 'Your trial will be upgraded immediately.'
                  : 'Your current subscription will be upgraded immediately.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.upgradeToPackage(package);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitItem(String label, int limit) {
    final displayValue = limit == -1 ? '∞' : limit.toString();
    return Column(
      children: [
        Text(
          displayValue,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesComparison() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why Choose Premium?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildComparisonItem(
                'Priority Support', 'Get help when you need it most'),
            _buildComparisonItem(
                'Advanced Analytics', 'Deep insights into your school'),
            _buildComparisonItem(
                'Custom Branding', 'Make it yours with custom logos'),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonItem(String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.amber, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildFAQItem('Can I change plans anytime?',
                'Yes! Upgrade or downgrade at any time.'),
            _buildFAQItem('What payment methods do you accept?',
                'We accept all major credit cards via Stripe.'),
            _buildFAQItem(
                'Is there a refund policy?', '30-day money-back guarantee.'),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
