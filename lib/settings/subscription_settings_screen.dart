// COMPLETE VERSION WITH PAYNOW INTEGRATION
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/subscription_cache.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/subscription_controller.dart';
import '../../models/subscription_package.dart';
import '../../widgets/paynow_button.dart';
import '../../widgets/paynow_payment_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends StatelessWidget {
  final SubscriptionController controller = Get.find<SubscriptionController>();
  final Rx<SubscriptionPackage?> _selectedPackage =
      Rx<SubscriptionPackage?>(null);
  final RxString _selectedBillingPeriod = 'monthly'.obs;
  final RxString _selectedPaymentMethod = 'paynow'.obs;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedPackage.value == null &&
          controller.availablePackages.isNotEmpty) {
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
          'Subscription',
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
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Obx(() {
        // ✅ FIX: Check for cached data FIRST to avoid infinite loading
        final isOffline = controller.availablePackages.isEmpty;
        final hasCurrentSubscription =
            controller.subscriptionStatus.value.isNotEmpty &&
                    controller.subscriptionStatus.value != 'trial' ||
                controller.remainingTrialDays.value > 0;

        // If offline but has subscription data (from cache), show offline view immediately
        if (isOffline && hasCurrentSubscription && !controller.isLoading.value) {
          return _buildOfflineView();
        }

        // Show loading spinner ONLY if actively loading and no cached data yet
        if (controller.isLoading.value && !hasCurrentSubscription) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF2563EB)),
                SizedBox(height: 16),
                Text(
                  'Loading subscription...',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }

        // If not loading, offline, and NO subscription data - show error screen
        if (isOffline && !hasCurrentSubscription) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'Unable to load subscription data',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check your internet connection',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => controller.loadSubscriptionData(),
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.currentPackage.value != null)
                _buildCurrentPlanCard(),
              _buildPendingInvoiceSection(),
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
              ...controller.availablePackages.expand((package) {
                return [
                  _buildPackageSelectionCard(package),
                  SizedBox(height: 12),
                ];
              }).toList(),
              SizedBox(height: 16),
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
                            method: 'paynow',
                            icon: Icons.mobile_friendly,
                            title: 'Paynow',
                            isAvailable: true,
                            width: responsiveCardWidth,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 32),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Developer Information',
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
                child: _buildDeveloperInfo(),
              ),
              SizedBox(height: 100),
            ],
          ),
        );
      }),
      bottomNavigationBar: Obx(() => _buildBottomButton()),
    );
  }

  Widget _buildPendingInvoiceSection() {
    return Obx(() {
      final pendingInvoice = controller.pendingSubscriptionInvoice.value;

      if (pendingInvoice == null) {
        return SizedBox.shrink();
      }

      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange[200]!, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[700],
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Payment',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                      Text(
                        'Invoice: ${pendingInvoice.invoiceNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),
            Divider(color: Colors.orange[200]),
            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Amount Due:',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Text(
                  '\$${pendingInvoice.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Due Date:', style: TextStyle(fontSize: 14)),
                Text(
                  DateFormat('MMM dd, yyyy').format(pendingInvoice.dueDate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: pendingInvoice.isOverdue
                        ? Colors.red[700]
                        : Colors.orange[700],
                  ),
                ),
              ],
            ),

            if (pendingInvoice.isOverdue)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ This invoice is overdue',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            SizedBox(height: 20),
            Text(
              'Choose Payment Method:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: PaynowButton(
                    invoiceId: pendingInvoice.id,
                    invoiceNumber: pendingInvoice.invoiceNumber,
                    amount: pendingInvoice.totalAmount,
                    fullWidth: true,
                    buttonText: 'Paynow',
                    showIcon: true,
                    onPaymentSuccess: () {
                      controller.loadSubscriptionData();

                      Get.snackbar(
                        'Payment Successful! 🎉',
                        'Your subscription has been updated.',
                        backgroundColor: Colors.green[100],
                        colorText: Colors.green[900],
                        icon:
                            Icon(Icons.check_circle, color: Colors.green[700]),
                        duration: Duration(seconds: 4),
                      );
                    },
                  ),
                ),
                SizedBox(width: 12),
              ],
            ),

            SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Paynow accepts EcoCash, OneMoney, and cards (Zimbabwe)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCurrentPlanCard() {
    return Obx(() {
      final package = controller.currentPackage.value;
      final status = controller.subscriptionStatus.value;
      final isActive = status == 'active';
      final isTrial = status == 'trial';

      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isActive
                ? [Colors.green[600]!, Colors.green[800]!]
                : isTrial
                    ? [Colors.blue[600]!, Colors.blue[800]!]
                    : [Colors.orange[600]!, Colors.orange[800]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isActive ? Colors.green : Colors.blue).withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium,
                        color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Current Subscription',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive
                        ? 'Active'
                        : isTrial
                            ? 'Trial'
                            : status.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              package?.name ?? 'No Package',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Obx(() => Text(
                  controller.displayPrice,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                )),
            if (controller.billingPeriod.value == 'yearly') ...[
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '💰 Yearly billing - Save 20%!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.3)),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    controller.subscriptionExpiresAt.value != null &&
                            controller.subscriptionExpiresAt.value!
                                    .difference(DateTime.now())
                                    .inDays <
                                7
                        ? Icons.warning_amber_rounded
                        : Icons.calendar_today,
                    color: controller.subscriptionExpiresAt.value != null &&
                            controller.subscriptionExpiresAt.value!
                                    .difference(DateTime.now())
                                    .inDays <
                                7
                        ? Colors.amber
                        : Colors.white.withOpacity(0.9),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() => Text(
                              controller.expiryDisplayText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            )),
                        if (controller.subscriptionExpiresAt.value != null) ...[
                          SizedBox(height: 2),
                          Text(
                            'Next renewal: ${DateFormat('MMM dd, yyyy').format(controller.subscriptionExpiresAt.value!)}',
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

  Widget _buildOfflineView() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: SubscriptionCache.getCachedSubscriptionData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final cachedData = snapshot.data!;
        final status = cachedData['subscription_status'] as String;
        final trialDays = cachedData['remaining_trial_days'] as int;
        final expiresAtStr = cachedData['subscription_expires_at'] as String?;
        final isActive = status == 'active';
        final isTrial = status == 'trial';

        DateTime? expiresAt;
        Duration? timeRemaining;
        if (expiresAtStr != null) {
          expiresAt = DateTime.parse(expiresAtStr);
          timeRemaining = expiresAt.difference(DateTime.now());
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.orange[700], size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline Mode',
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Showing cached subscription data from ${_formatCacheAge(cachedData['last_synced_at'])}',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Current Subscription',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [Color(0xFF2563EB), Color(0xFF1D4ED8)]
                        : [Color(0xFF059669), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isActive ? Colors.blue : Colors.green)
                          .withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isActive ? Icons.verified : Icons.access_time,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isActive ? 'Pro Subscription' : 'Free Trial',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (controller.currentPackage.value != null)
                                Text(
                                  controller.currentPackage.value!.name,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
                    SizedBox(height: 24),
                    if (timeRemaining != null &&
                        timeRemaining.inSeconds > 0) ...[
                      Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.white70, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Time Remaining',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${timeRemaining.inDays}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            timeRemaining.inDays == 1 ? 'day' : 'days',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTimeUnit(
                              timeRemaining.inHours % 24,
                              'hours',
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            _buildTimeUnit(
                              timeRemaining.inMinutes % 60,
                              'minutes',
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            _buildTimeUnit(
                              timeRemaining.inSeconds % 60,
                              'seconds',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event, color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Expires: ${_formatExpiryDate(expiresAt!)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isTrial) ...[
                      Text(
                        '$trialDays',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${trialDays == 1 ? 'day' : 'days'} remaining',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ],
                    if (isActive &&
                        controller.currentPackage.value != null) ...[
                      Row(
                        children: [
                          Icon(Icons.payment, color: Colors.white70, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Monthly Fee',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '\$${controller.currentPackage.value!.monthlyPrice?.toStringAsFixed(0) ?? '0'}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Connect to internet to upgrade or manage your subscription.',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => controller.loadSubscriptionData(),
                  icon: Icon(Icons.refresh),
                  label: Text('Connect and Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeUnit(int value, String unit) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          unit,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatCacheAge(String? lastSyncedStr) {
    if (lastSyncedStr == null) return 'unknown';

    final lastSynced = DateTime.parse(lastSyncedStr);
    final diff = DateTime.now().difference(lastSynced);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  String _formatExpiryDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(date.year, date.month, date.day);

    if (expiry == today) {
      return 'Today at ${DateFormat('HH:mm').format(date)}';
    } else if (expiry == today.add(Duration(days: 1))) {
      return 'Tomorrow at ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('MMM dd, yyyy \'at\' HH:mm').format(date);
    }
  }

  Widget _buildPackageSelectionCard(SubscriptionPackage package) {
    return Obx(() {
      final isSelected = _selectedPackage.value?.id == package.id;
      final isCurrentPackage =
          controller.currentPackage.value?.id == package.id;
      final isTrialPackage = package.slug == 'trial';

      String title = package.name;
      if (isCurrentPackage) {
        title = '${package.name} (Current)';
      }

      return GestureDetector(
        onTap: () {
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

    if (_selectedPaymentMethod.value == 'paynow') {
      _showPaynowDialog();
      return;
    }

    await controller.upgradeToPackage(_selectedPackage.value!);
  }

  void _showPaynowDialog() async {
    if (_selectedPackage.value == null) return;

    try {
      Get.dialog(
        Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating invoice...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );
      final invoice = await _createSubscriptionInvoice(
        _selectedPackage.value!,
        _selectedBillingPeriod.value,
      );

      Get.back();

      if (invoice == null) {
        Get.snackbar(
          'Error',
          'Failed to create invoice. Please try again.',
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          icon: Icon(Icons.error_outline, color: Colors.red[900]),
        );
        return;
      }
      Get.dialog(
        PaynowPaymentDialog(
          invoiceId: invoice['id'],
          invoiceNumber: invoice['invoice_number'],
          amount: double.tryParse(invoice['total_amount'].toString()) ?? 0.0,
          onPaymentSuccess: () {
            controller.loadSubscriptionData();

            Get.snackbar(
              'Success! 🎉',
              'Your subscription has been activated!',
              backgroundColor: Colors.green[100],
              colorText: Colors.green[900],
              icon: Icon(Icons.check_circle, color: Colors.green[700]),
              duration: Duration(seconds: 4),
            );
          },
        ),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to initiate payment: ${e.toString()}',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        icon: Icon(Icons.error_outline, color: Colors.red[900]),
        duration: Duration(seconds: 5),
      );
    }
  }

  Future<Map<String, dynamic>?> _createSubscriptionInvoice(
    SubscriptionPackage package,
    String billingPeriod,
  ) async {
    try {
      print('🔄 Creating subscription invoice...');
      print('Package: ${package.name}, Period: $billingPeriod');

      String? token;

      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        final user = authController.currentUser.value;

        if (user?.email != null) {
          final prefs = await SharedPreferences.getInstance();
          token = prefs.getString('api_token_${user!.email}');

          if (token != null) {
            print('✅ Token found for user: ${user.email}');
          } else {
            print('⚠️ No token found for user: ${user.email}');
          }
        } else {
          print('⚠️ No current user in AuthController');
        }
      } else {
        print('⚠️ AuthController not registered');
      }

      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        final keys =
            prefs.getKeys().where((key) => key.startsWith('api_token_'));

        if (keys.isNotEmpty) {
          token = prefs.getString(keys.first);
          print('✅ Fallback token found: ${keys.first}');
        }
      }

      if (token == null) {
        print('❌ No authentication token found');
        throw Exception('Authentication required. Please log in again.');
      }

      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/subscription/create-invoice'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'package_id': package.id,
              'billing_period': billingPeriod,
            }),
          )
          .timeout(Duration(seconds: 30));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['invoice'] != null) {
          return data['invoice'];
        } else if (data['invoice'] != null) {
          return data['invoice'];
        } else if (data['data'] != null && data['data']['invoice'] != null) {
          return data['data']['invoice'];
        }

        print('✅ Invoice created successfully');
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create invoice');
      }
    } catch (e) {
      print('❌ Error creating invoice: $e');
      rethrow;
    }
  }

  Widget _buildDeveloperInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, size: 20, color: Colors.blue[700]),
              SizedBox(width: 8),
              Text(
                'Developed by CodzLabZim',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),

          InkWell(
            onTap: () async {
              final Uri emailUri = Uri(
                scheme: 'mailto',
                path: 'support@drivesyncpro.co.zw',
              );
              if (await canLaunchUrl(emailUri)) {
                await launchUrl(emailUri);
              } else {
                Get.snackbar(
                  'Error',
                  'Could not open email app',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.email, color: Colors.blue[600], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'support@drivesyncpro.co.zw',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          // WhatsApp
          InkWell(
            onTap: () async {
              final Uri whatsappUri = Uri.parse('https://wa.me/2630784666891');
              if (await canLaunchUrl(whatsappUri)) {
                await launchUrl(whatsappUri,
                    mode: LaunchMode.externalApplication);
              } else {
                Get.snackbar(
                  'Error',
                  'Could not open WhatsApp',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat, color: Colors.green[700], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact on WhatsApp',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          '+263 78 466 6891',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
