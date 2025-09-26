// lib/screens/subscription/subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/subscription_controller.dart';
import '../../models/subscription_package.dart';

class SubscriptionScreen extends StatelessWidget {
  final SubscriptionController controller = Get.find<SubscriptionController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscription Plans'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Obx(() {
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

        return Column(
          children: [
            _buildHeader(),
            _buildBillingToggle(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.loadSubscriptionData(),
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (controller.subscriptionStatus.value == 'trial')
                        _buildTrialStatusCard(),
                      SizedBox(height: 16),
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
          colors: [Colors.blue[700]!, Colors.blue[800]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.workspace_premium,
            size: 48,
            color: Colors.white,
          ),
          SizedBox(height: 12),
          Text(
            'Choose Your Perfect Plan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Unlock the full potential of your driving school',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
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
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('Monthly', 'monthly'),
          _buildToggleButton('Yearly', 'yearly'),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, String period) {
    return Obx(() => GestureDetector(
          onTap: () => controller.billingPeriod.value = period,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: controller.billingPeriod.value == period
                  ? Colors.blue[700]
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: controller.billingPeriod.value == period
                        ? Colors.white
                        : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (period == 'yearly') ...[
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: controller.billingPeriod.value == period
                          ? Colors.white
                          : Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Save 20%',
                      style: TextStyle(
                        color: controller.billingPeriod.value == period
                            ? Colors.blue[700]
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ));
  }

  Widget _buildTrialStatusCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: controller.remainingTrialDays.value <= 3
              ? [Colors.orange[600]!, Colors.red[600]!]
              : [Colors.blue[600]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Free Trial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${controller.remainingTrialDays.value} days remaining',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (controller.remainingTrialDays.value <= 7)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.yellow[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'UPGRADE SOON',
                style: TextStyle(
                  color: Colors.orange[900],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(SubscriptionPackage package) {
    final isCurrentPackage = controller.currentPackage.value?.id == package.id;
    final billingPeriod = controller.billingPeriod.value;
    final price = package.getPrice(billingPeriod);
    final isTrialPackage = package.slug == 'trial';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: package.isPopular ? 6 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: package.isPopular
                ? Colors.blue
                : isCurrentPackage
                    ? Colors.green
                    : Colors.grey[300]!,
            width: package.isPopular ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Popular badge
            if (package.isPopular)
              Positioned(
                top: 0,
                right: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    'MOST POPULAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Current package badge
            if (isCurrentPackage)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'CURRENT PLAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isCurrentPackage ? 20 : 0),

                  // Package name and description
                  Text(
                    package.name,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (package.description != null) ...[
                    SizedBox(height: 6),
                    Text(
                      package.description!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 15,
                      ),
                    ),
                  ],

                  SizedBox(height: 20),

                  // Pricing
                  if (isTrialPackage) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'FREE',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'for ${package.trialDays} days',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        Text(
                          '/${billingPeriod == 'yearly' ? 'year' : 'month'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    // Yearly discount badge
                    if (billingPeriod == 'yearly' &&
                        package.yearlyDiscount > 0) ...[
                      SizedBox(height: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Save ${package.yearlyDiscount}% annually',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],

                  SizedBox(height: 24),

                  // Features list
                  ...package.features
                      .take(6)
                      .map((feature) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),

                  if (package.features.length > 6) ...[
                    SizedBox(height: 8),
                    Text(
                      '+ ${package.features.length - 6} more features',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  // Limits display
                  if (!isTrialPackage && package.limits.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What\'s included:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildLimitItem('Students',
                                    package.getLimit('max_students')),
                              ),
                              Expanded(
                                child: _buildLimitItem('Instructors',
                                    package.getLimit('max_instructors')),
                              ),
                              Expanded(
                                child: _buildLimitItem('Vehicles',
                                    package.getLimit('max_vehicles')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isCurrentPackage
                          ? null
                          : () => _handlePackageSelection(package),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCurrentPackage
                            ? Colors.grey[400]
                            : package.isPopular
                                ? Colors.blue[700]
                                : Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: package.isPopular ? 4 : 2,
                      ),
                      child: Text(
                        isCurrentPackage
                            ? 'Current Plan'
                            : isTrialPackage
                                ? 'Start Free Trial'
                                : 'Choose ${package.name}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitItem(String label, int limit) {
    return Column(
      children: [
        Text(
          limit == -1 ? '∞' : limit.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why Choose DriveSync Pro?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            _buildComparisonFeature(
              'Complete Student Management',
              'Track progress, manage documents, and monitor performance all in one place.',
              Icons.people,
            ),
            _buildComparisonFeature(
              'Smart Scheduling System',
              'Intelligent scheduling that prevents conflicts and optimizes instructor time.',
              Icons.calendar_today,
            ),
            _buildComparisonFeature(
              'Automated Billing',
              'Generate invoices, track payments, and manage finances effortlessly.',
              Icons.receipt_long,
            ),
            _buildComparisonFeature(
              'Real-time Sync',
              'All your data synced across devices with automatic cloud backup.',
              Icons.cloud_sync,
            ),
            _buildComparisonFeature(
              'Advanced Reporting',
              'Detailed insights and analytics to help grow your business.',
              Icons.analytics,
            ),
            _buildComparisonFeature(
              '24/7 Support',
              'Priority customer support to help you succeed.',
              Icons.support_agent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonFeature(
      String title, String description, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.blue[600],
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    height: 1.4,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            _buildFAQItem(
              'Can I cancel anytime?',
              'Yes, you can cancel your subscription at any time. You\'ll continue to have access until the end of your billing period.',
            ),
            _buildFAQItem(
              'What happens to my data if I cancel?',
              'Your data remains safe for 90 days after cancellation. You can export it anytime or reactivate your subscription.',
            ),
            _buildFAQItem(
              'Do you offer refunds?',
              'We offer a 30-day money-back guarantee for new subscriptions. If you\'re not satisfied, we\'ll refund your payment.',
            ),
            _buildFAQItem(
              'Is my data secure?',
              'Absolutely! We use enterprise-grade security with 256-bit SSL encryption and regular security audits.',
            ),
            _buildFAQItem(
              'Can I upgrade or downgrade my plan?',
              'Yes, you can change your plan at any time. Changes take effect immediately and billing is prorated.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 6),
          Text(
            answer,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _handlePackageSelection(SubscriptionPackage package) {
    if (package.slug == 'trial') {
      Get.snackbar(
        'Free Trial',
        'You are already on a trial or this package is not available for direct signup.',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
      return;
    }

    // Show upgrade confirmation dialog
    Get.dialog(
      AlertDialog(
        title: Text('Upgrade to ${package.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You\'re about to upgrade to:'),
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
              'Your ${controller.subscriptionStatus.value == 'trial' ? 'trial' : 'current subscription'} will be upgraded immediately.',
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
            child: Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
}
