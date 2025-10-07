// lib/settings/subscription_settings_screen.dart
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
    // Auto-select first non-trial package on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedPackage.value == null &&
          controller.availablePackages.isNotEmpty) {
        // Find first non-trial package or use first package
        final firstPaidPackage = controller.availablePackages.firstWhere(
          (pkg) => pkg.slug != 'trial',
          orElse: () => controller.availablePackages.first,
        );
        _selectedPackage.value = firstPaidPackage;
        if (_selectedPackage.value!.hasYearlyPricing) {
          _selectedBillingPeriod.value = 'yearly';
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF2563EB),
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
              // Current Plan Info (if user has one)
              if (controller.currentPackage.value != null)
                _buildCurrentPlanCard(),

              // Choose Subscription Header
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Choose Subscription:',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Subscription Options from Server
              ...controller.availablePackages.expand((package) {
                return [
                  _buildPackageSelectionCard(package),
                  SizedBox(height: 12),
                ];
              }).toList(),

              SizedBox(height: 16),

              // Billing Period Selection
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Billing Period:',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 12),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Obx(() => Row(
                      children: [
                        Expanded(
                          child: _buildBillingPeriodCard(
                            'Monthly',
                            'monthly',
                            _selectedBillingPeriod.value == 'monthly',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildBillingPeriodCard(
                            'Yearly (Save 20%)',
                            'yearly',
                            _selectedBillingPeriod.value == 'yearly',
                          ),
                        ),
                      ],
                    )),
              ),

              SizedBox(height: 24),

              // Payment Methods Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Payment Methods',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Payment Method Selection - Responsive
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final cardWidth = (screenWidth - 36) / 4;
                    final minCardWidth = 85.0;
                    final maxCardWidth = 120.0;
                    final responsiveCardWidth =
                        cardWidth.clamp(minCardWidth, maxCardWidth);

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPaymentMethodCard(
                            method: 'stripe',
                            icon: Icons.credit_card,
                            title: 'Stripe',
                            isAvailable: true,
                            width: responsiveCardWidth,
                          ),
                          SizedBox(width: 12),
                          _buildPaymentMethodCard(
                            method: 'paypal',
                            icon: Icons.paypal,
                            title: 'PayPal',
                            isAvailable: false,
                            width: responsiveCardWidth,
                          ),
                          SizedBox(width: 12),
                          _buildPaymentMethodCard(
                            method: 'mpesa',
                            icon: Icons.phone_android,
                            title: 'M-Pesa',
                            isAvailable: false,
                            width: responsiveCardWidth,
                          ),
                          SizedBox(width: 12),
                          _buildPaymentMethodCard(
                            method: 'bank',
                            icon: Icons.account_balance,
                            title: 'Bank',
                            isAvailable: false,
                            width: responsiveCardWidth,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: 100), // Space for bottom button
            ],
          ),
        );
      }),
      bottomNavigationBar: Obx(() => _buildBottomButton()),
    );
  }

  Widget _buildCurrentPlanCard() {
    return Obx(() {
      final currentPlan = controller.currentPackage.value;
      if (currentPlan == null) return SizedBox.shrink();

      final status = controller.subscriptionStatus.value;
      final expiryDate = controller.remainingTrialDays.value;

      // Calculate days left
      int? daysLeft = expiryDate;
      String expiryText = 'Not available';
      if (daysLeft != null) {
        final now = DateTime.now();
        final expiry = now.add(Duration(days: daysLeft));
        daysLeft = expiry.difference(now).inDays;

        if (daysLeft < 0) {
          expiryText = 'Expired';
        } else if (daysLeft == 0) {
          expiryText = 'Expires today';
        } else if (daysLeft == 1) {
          expiryText = '1 day left';
        } else {
          expiryText = '$daysLeft days left';
        }
      }

      // Determine status color and icon
      Color statusColor;
      IconData statusIcon;
      String statusText = status ?? 'Unknown';

      switch (status?.toLowerCase()) {
        case 'active':
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusText = 'Active';
          break;
        case 'trial':
          statusColor = Colors.blue;
          statusIcon = Icons.schedule;
          statusText = 'Trial';
          break;
        case 'expired':
        case 'cancelled':
          statusColor = Colors.red;
          statusIcon = Icons.cancel;
          statusText = status == 'expired' ? 'Expired' : 'Cancelled';
          break;
        case 'pending':
          statusColor = Colors.orange;
          statusIcon = Icons.pending;
          statusText = 'Pending';
          break;
        default:
          statusColor = Colors.grey;
          statusIcon = Icons.info;
      }

      return Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF2563EB).withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Current Subscription',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // Status badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Plan name and price
            Text(
              currentPlan.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '\$${currentPlan.monthlyPrice.toStringAsFixed(2)}/month',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            SizedBox(height: 16),

            // Expiry information
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    daysLeft != null && daysLeft < 7
                        ? Icons.warning_amber_rounded
                        : Icons.calendar_today,
                    color: daysLeft != null && daysLeft < 7
                        ? Colors.amber
                        : Colors.white.withOpacity(0.9),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expiryText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (expiryDate != null) ...[
                          SizedBox(height: 2),
                          Text(
                            'Expires: ${DateFormat('MMM dd, yyyy').format(DateTime.now().add(Duration(days: expiryDate)))}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildPackageSelectionCard(SubscriptionPackage package) {
    return Obx(() {
      final isSelected = _selectedPackage.value?.id == package.id;
      final isCurrentPackage =
          controller.currentPackage.value?.id == package.id;
      final isTrialPackage = package.slug == 'trial';

      // Calculate the display title
      String title = package.name;
      if (isCurrentPackage) {
        title = '${package.name} (Current)';
      }

      return GestureDetector(
        onTap: () {
          // Don't allow selecting trial package
          if (!isTrialPackage) {
            _selectedPackage.value = package;
          }
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: Color(0xFFD97706), width: 2)
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
                              color: Color(0xFFD97706),
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

  Widget _buildBillingPeriodCard(String label, String period, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectedBillingPeriod.value = period,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF2563EB) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFF2563EB) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required String method,
    required IconData icon,
    required String title,
    required bool isAvailable,
    required double width,
  }) {
    return Obx(() {
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
              color: isSelected ? Color(0xFF2563EB) : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Color(0xFF2563EB).withOpacity(0.3),
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
                padding: EdgeInsets.all(width * 0.12),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? Color(0xFF2563EB).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isAvailable ? Color(0xFF2563EB) : Colors.grey,
                  size: width * 0.28,
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
                  fontSize: width * 0.13,
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
                      fontSize: width * 0.09,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (isSelected) ...[
                SizedBox(height: 3),
                Icon(
                  Icons.check_circle,
                  color: Color(0xFF2563EB),
                  size: width * 0.18,
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomButton() {
    final selectedPrice = _getSelectedPrice();
    final isTrialUser = controller.subscriptionStatus.value == 'trial';
    final isCurrentPackage =
        _selectedPackage.value?.id == controller.currentPackage.value?.id;

    // Determine button text
    String buttonText;
    if (isCurrentPackage) {
      buttonText = 'Pay \$${selectedPrice.toStringAsFixed(2)}';
    } else if (isTrialUser) {
      buttonText = 'Upgrade Now - \$${selectedPrice.toStringAsFixed(2)}';
    } else {
      buttonText = 'Pay \$${selectedPrice.toStringAsFixed(2)}';
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _selectedPackage.value != null ? _handleSubscribe : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 20),
              SizedBox(width: 8),
              Text(
                buttonText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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

    // Process payment/upgrade
    await controller.upgradeToPackage(_selectedPackage.value!);
  }

  Future<bool> _showPaymentConfirmation() async {
    final selectedPrice = _getSelectedPrice();
    final period = _selectedBillingPeriod.value == 'yearly' ? 'year' : 'month';
    final isTrialUser = controller.subscriptionStatus.value == 'trial';
    final isCurrentPackage =
        _selectedPackage.value?.id == controller.currentPackage.value?.id;

    String dialogTitle;
    String dialogMessage;

    if (isTrialUser && !isCurrentPackage) {
      dialogTitle = 'Confirm Upgrade';
      dialogMessage =
          'You\'re upgrading from trial to ${_selectedPackage.value!.name}.';
    } else if (isCurrentPackage) {
      dialogTitle = 'Confirm Payment';
      dialogMessage =
          'Process payment for your ${_selectedPackage.value!.name} plan.';
    } else {
      dialogTitle = 'Confirm Payment';
      dialogMessage = 'Process payment for ${_selectedPackage.value!.name}.';
    }

    return await Get.dialog<bool>(
          AlertDialog(
            title: Text(dialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dialogMessage),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Plan:', style: TextStyle(fontSize: 14)),
                          Text(
                            _selectedPackage.value!.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount:', style: TextStyle(fontSize: 14)),
                          Text(
                            '\$${selectedPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
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
                        size: 16, color: Color(0xFF2563EB)),
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
                  backgroundColor: Color(0xFF2563EB),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(isTrialUser && !isCurrentPackage
                    ? 'Upgrade Now'
                    : 'Proceed to Payment'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
