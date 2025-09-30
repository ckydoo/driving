// lib/screens/subscription/subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/subscription_controller.dart';
import '../../models/subscription_package.dart';

class SubscriptionScreen extends StatelessWidget {
  final SubscriptionController controller = Get.find<SubscriptionController>();
  final Rx<SubscriptionPackage?> _selectedPackage =
      Rx<SubscriptionPackage?>(null);
  final RxString _selectedBillingPeriod = 'monthly'.obs;
  final RxString _selectedPaymentMethod = 'stripe'.obs;

  @override
  Widget build(BuildContext context) {
    // Auto-select first package on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedPackage.value == null &&
          controller.availablePackages.isNotEmpty) {
        _selectedPackage.value = controller.availablePackages.first;
        if (_selectedPackage.value!.hasYearlyPricing) {
          _selectedBillingPeriod.value = 'yearly';
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white, // White background
      appBar: AppBar(
        backgroundColor: Color(0xFF2563EB), // Changed from 0xFF1E1E96
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Subscribe',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () => controller.loadSubscriptionData(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Loading subscription plans...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        if (controller.availablePackages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.white54),
                SizedBox(height: 16),
                Text(
                  'No subscription packages available',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => controller.loadSubscriptionData(),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Choose Subscription Header
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Choose Subscription:',
                  style: TextStyle(
                    color: Color(0xFF0F172A), // Dark text for white background
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Subscription Options from Server
              ...controller.availablePackages.expand((package) {
                return _buildPackageOptions(package);
              }).toList(),

              // Price Display
              SizedBox(height: 24),
              Center(
                child: Obx(() {
                  final price = _getSelectedPrice();

                  return Column(
                    children: [
                      Text(
                        'Pay \$${price.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          color: Color(0xFF059669), // Changed to success green
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedPackage.value != null &&
                          _selectedBillingPeriod.value == 'yearly') ...[
                        SizedBox(height: 8),
                        Text(
                          'Save ${_selectedPackage.value!.yearlyDiscount}% with yearly billing',
                          style: TextStyle(
                            color:
                                Color(0xFFD97706), // Changed to warning orange
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ),

              // Instruction Text
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Select your subscription plan and payment method below',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(
                        0xFF64748B), // Secondary gray for white background
                    fontSize: 13,
                  ),
                ),
              ),

              // Payment Methods Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Payment Methods',
                  style: TextStyle(
                    color: Color(0xFF0F172A), // Dark text for white background
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Payment Method Selection - Responsive Horizontal Layout
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate card width based on screen size
                    final screenWidth = constraints.maxWidth;
                    final cardWidth =
                        (screenWidth - 36) / 4; // 4 cards with spacing
                    final minCardWidth = 85.0;
                    final maxCardWidth = 120.0;
                    final responsiveCardWidth =
                        cardWidth.clamp(minCardWidth, maxCardWidth);

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Stripe - Fully functional
                          _buildPaymentMethodCard(
                            method: 'stripe',
                            icon: Icons.credit_card,
                            title: 'Stripe',
                            isAvailable: true,
                            width: responsiveCardWidth,
                          ),
                          SizedBox(width: 12),

                          // Innbucks - Coming Soon
                          _buildPaymentMethodCard(
                            method: 'innbucks',
                            icon: Icons.account_balance_wallet,
                            title: 'Innbucks',
                            isAvailable: false,
                            width: responsiveCardWidth,
                          ),
                          SizedBox(width: 12),

                          // EcoCash - Coming Soon
                          _buildPaymentMethodCard(
                            method: 'ecocash',
                            icon: Icons.mobile_friendly,
                            title: 'EcoCash',
                            isAvailable: false,
                            width: responsiveCardWidth,
                          ),
                          SizedBox(width: 12),

                          // O'mari - Coming Soon
                          _buildPaymentMethodCard(
                            method: 'omari',
                            icon: Icons.phone_android,
                            title: "O'mari",
                            isAvailable: false,
                            width: responsiveCardWidth,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 24),

              // Subscribe Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Obx(() => ElevatedButton(
                        onPressed: _selectedPackage.value != null &&
                                _selectedPaymentMethod.value == 'stripe'
                            ? _handleSubscribe
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Color(0xFF059669), // Changed to success green
                          disabledBackgroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedPaymentMethod.value == 'stripe'
                                  ? Icons.lock_outline
                                  : Icons.info_outline,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _selectedPaymentMethod.value == 'stripe'
                                  ? 'Pay with Stripe'
                                  : 'Select Stripe to Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )),
                ),
              ),

              SizedBox(height: 16),

              // Secure Payment Badge
              if (_selectedPaymentMethod.value == 'stripe')
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user,
                          color: Color(0xFF059669),
                          size: 16), // Changed to success green
                      SizedBox(width: 8),
                      Text(
                        'Secure Payment by Stripe',
                        style: TextStyle(
                          color: Color(
                              0xFF64748B), // Secondary gray for white background
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Current Subscription Info
              Obx(() {
                if (controller.currentPackage.value != null) {
                  return Container(
                    margin: EdgeInsets.all(20),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF2563EB)
                          .withOpacity(0.3), // Changed to primary blue
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Color(0xFF2563EB).withOpacity(0.5), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue[200], size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Current Plan',
                              style: TextStyle(
                                color: Colors.blue[200],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          controller.currentPackage.value!.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Status: ${controller.subscriptionStatus.value.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Trial Info
                if (controller.subscriptionStatus.value == 'trial' &&
                    controller.remainingTrialDays.value > 0) {
                  final expiryDate = DateTime.now()
                      .add(Duration(days: controller.remainingTrialDays.value));
                  final formattedDate =
                      DateFormat('EEE, MMM d, y').format(expiryDate);

                  return Container(
                    margin: EdgeInsets.all(20),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule,
                            color:
                                Color(0xFFD97706)), // Changed to warning orange
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trial Period Active',
                                style: TextStyle(
                                  color: Color(0xFF0F172A), // Changed to dark
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${controller.remainingTrialDays.value} days remaining (Expires $formattedDate)',
                                style: TextStyle(
                                  color: Color(
                                      0xFFD97706), // Changed to warning orange
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox.shrink();
              }),

              SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  // Generate subscription options for each package
  List<Widget> _buildPackageOptions(SubscriptionPackage package) {
    List<Widget> options = [];

    // Monthly option
    options.add(_buildSubscriptionOption(
      package: package,
      billingPeriod: 'monthly',
      title:
          '\$${package.monthlyPrice.toStringAsFixed(0)} per month / ${package.name}',
    ));

    // Yearly option (if available)
    if (package.hasYearlyPricing) {
      final discount = package.yearlyDiscount > 0
          ? ' (Save ${package.yearlyDiscount}%)'
          : '';

      options.add(_buildSubscriptionOption(
        package: package,
        billingPeriod: 'yearly',
        title:
            '\$${package.yearlyPrice!.toStringAsFixed(0)} Per year / ${package.name}$discount',
      ));
    }

    return options;
  }

  Widget _buildSubscriptionOption({
    required SubscriptionPackage package,
    required String billingPeriod,
    required String title,
  }) {
    return Obx(() {
      final isSelected = _selectedPackage.value?.id == package.id &&
          _selectedBillingPeriod.value == billingPeriod;

      return GestureDetector(
        onTap: () {
          _selectedPackage.value = package;
          _selectedBillingPeriod.value = billingPeriod;
          controller.billingPeriod.value = billingPeriod;
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      Color(0xFF1D4ED8),
                      Color(0xFF2563EB)
                    ], // Changed to primary dark and primary
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : LinearGradient(
                    colors: [
                      Color(0xFF64748B),
                      Color(0xFF2563EB)
                    ], // Changed to secondary and primary
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(12),
            border: package.isPopular && !isSelected
                ? Border.all(
                    color: Color(0xFFD97706),
                    width: 2) // Changed to warning orange
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (package.isPopular && !isSelected)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(
                                  0xFFD97706), // Changed to warning orange
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'POPULAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (package.description != null) ...[
                      SizedBox(height: 4),
                      Text(
                        package.description!,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12),
              if (isSelected)
                Icon(Icons.check_circle, color: Colors.white, size: 24),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPaymentMethodCard({
    required String method,
    required IconData icon,
    required String title,
    required bool isAvailable,
    required double width,
  }) {
    final isSelected = _selectedPaymentMethod.value == method;

    return GestureDetector(
      onTap: isAvailable ? () => _selectedPaymentMethod.value = method : null,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isAvailable
              ? (isSelected ? Colors.white : Colors.white.withOpacity(0.9))
              : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Color(0xFF2563EB)
                : Colors.transparent, // Changed to primary blue
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(0xFF2563EB)
                        .withOpacity(0.3), // Changed to primary blue
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(width * 0.12), // Responsive padding
              decoration: BoxDecoration(
                color: isAvailable
                    ? Color(0xFF2563EB)
                        .withOpacity(0.1) // Changed to primary blue
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isAvailable
                    ? Color(0xFF2563EB)
                    : Colors.grey, // Changed to primary blue
                size: width * 0.28, // Responsive icon size
              ),
            ),
            SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isAvailable ? Colors.black87 : Colors.grey,
                fontSize: width * 0.13, // Responsive font size
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (!isAvailable) ...[
              SizedBox(height: 3),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: width * 0.09, // Responsive badge font
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (isSelected) ...[
              SizedBox(height: 3),
              Icon(
                Icons.check_circle,
                color: Color(0xFF2563EB), // Changed to primary blue
                size: width * 0.18, // Responsive checkmark
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _getSelectedPrice() {
    if (_selectedPackage.value == null) return 0.0;

    return _selectedBillingPeriod.value == 'yearly'
        ? (_selectedPackage.value!.yearlyPrice ??
            _selectedPackage.value!.monthlyPrice)
        : _selectedPackage.value!.monthlyPrice;
  }

  void _handleSubscribe() async {
    if (_selectedPackage.value == null) {
      Get.snackbar(
        'Error',
        'Please select a subscription package',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        icon: Icon(Icons.error_outline, color: Colors.red[900]),
      );
      return;
    }

    if (_selectedPaymentMethod.value != 'stripe') {
      Get.snackbar(
        'Coming Soon',
        'This payment method will be available soon. Please use Stripe.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange[100],
        colorText: Colors.orange[900],
        icon: Icon(Icons.info_outline, color: Colors.orange[700]),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showPaymentConfirmation();
    if (!confirmed) return;

    // Process Stripe payment using existing controller method
    await controller.upgradeToPackage(_selectedPackage.value!);
  }

  Future<bool> _showPaymentConfirmation() async {
    final package = _selectedPackage.value!;
    final price = _getSelectedPrice();
    final period = _selectedBillingPeriod.value == 'yearly' ? 'year' : 'month';

    return await Get.dialog<bool>(
          AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.payment,
                    color: Color(0xFF2563EB)), // Changed to primary blue
                SizedBox(width: 12),
                Text('Confirm Subscription'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are about to subscribe to:',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC), // Changed to light
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB), // Changed to primary blue
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount:', style: TextStyle(fontSize: 14)),
                          Text(
                            '\$${price.toStringAsFixed(2)} USD',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  Color(0xFF059669), // Changed to success green
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Billing:', style: TextStyle(fontSize: 14)),
                          Text(
                            'Every $period',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16,
                        color: Color(0xFF2563EB)), // Changed to primary blue
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You will be redirected to Stripe secure payment.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2563EB), // Changed to primary blue
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Proceed to Payment'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
