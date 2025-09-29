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
    final isTrialPackage = package.name.toLowerCase().contains('trial');

    print('🔍 Building package card: ${package.name}');
    print('🔍 Features count: ${package.features.length}');
    print('🔍 Monthly price: ${package.monthlyPrice}');

    return Obx(() {
      final selectedPeriod = controller.billingPeriod.value;
      final price = selectedPeriod == 'yearly'
          ? (package.yearlyPrice ?? package.monthlyPrice)
          : package.monthlyPrice;

      return Card(
        margin: EdgeInsets.only(bottom: 16),
        elevation: isCurrentPackage ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isCurrentPackage
              ? BorderSide(color: Colors.blue[700]!, width: 2)
              : BorderSide.none,
        ),
        child: Stack(
          children: [
            // Popular badge
            if (package.isPopular && !isCurrentPackage)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange[400]!, Colors.orange[600]!],
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Current package badge
            if (isCurrentPackage)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    'CURRENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Package name
                  Text(
                    package.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),

                  // Description
                  if (package.description != null &&
                      package.description!.isNotEmpty)
                    Text(
                      package.description!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  SizedBox(height: 16),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      SizedBox(width: 8),
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          selectedPeriod == 'yearly' ? '/year' : '/month',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Yearly savings
                  if (selectedPeriod == 'yearly' &&
                      package.yearlyDiscount > 0) ...[
                    SizedBox(height: 8),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Save ${package.yearlyDiscount}% annually',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 16),

                  // Features
                  Text(
                    'Features:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),

                  // Show features (max 6)
                  ...package.features
                      .take(6)
                      .map((feature) => Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: Colors.green[600],
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style: TextStyle(
                                      color: Colors.grey[700],
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
                          : () {
                              print(
                                  '💰 Upgrade button pressed for: ${package.name}');
                              controller.upgradeToPackage(package);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isCurrentPackage ? Colors.grey : Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: isCurrentPackage ? 0 : 2,
                      ),
                      child: Text(
                        isCurrentPackage ? 'Current Plan' : 'Upgrade Now',
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
      );
    });
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
