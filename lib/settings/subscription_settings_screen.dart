// lib/screens/settings/subscription_settings_screen.dart
import 'package:driving/screens/subscription/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/subscription_controller.dart';
import '../../controllers/auth_controller.dart';

class SubscriptionSettingsScreen extends StatelessWidget {
  final SubscriptionController subscriptionController =
      Get.find<SubscriptionController>();
  final AuthController authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscription Settings'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (subscriptionController.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => subscriptionController.loadSubscriptionData(),
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSubscriptionStatusCard(),
                SizedBox(height: 20),
                _buildSubscriptionDetailsCard(),
                SizedBox(height: 20),
                _buildUsageLimitsCard(),
                SizedBox(height: 20),
                _buildBillingHistoryCard(),
                SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSubscriptionStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _getStatusGradient(),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Subscription Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              if (subscriptionController.subscriptionStatus.value == 'trial')
                _buildTrialCountdown()
              else if (subscriptionController.subscriptionStatus.value ==
                  'active')
                _buildActiveSubscriptionInfo(),
              SizedBox(height: 16),
              _buildStatusDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrialCountdown() {
    final daysLeft = subscriptionController.remainingTrialDays.value;
    final isExpiringSoon = daysLeft <= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trial ends in',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isExpiringSoon
                    ? Colors.red[600]
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$daysLeft ${daysLeft == 1 ? 'day' : 'days'}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isExpiringSoon) ...[
              SizedBox(width: 8),
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.yellow[300],
                size: 20,
              ),
            ],
          ],
        ),
        if (daysLeft <= 7) ...[
          SizedBox(height: 8),
          Text(
            isExpiringSoon
                ? 'Upgrade now to avoid service interruption!'
                : 'Consider upgrading to continue enjoying all features.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveSubscriptionInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next billing date',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          _getNextBillingDate(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDetails() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white70, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _getStatusDescription(),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow('Current Plan', _getCurrentPlanName()),
            _buildDetailRow('Price', _getCurrentPrice()),
            _buildDetailRow('Billing Cycle', _getBillingCycle()),
            _buildDetailRow(
                'Account Type',
                authController.currentUser.value?.role?.toUpperCase() ??
                    'Unknown'),
            _buildDetailRow('School Name',
                authController.currentUser.value?.schoolId ?? 'Not Available'),
            if (subscriptionController.subscriptionStatus.value == 'trial')
              _buildDetailRow('Trial Started', _getTrialStartDate()),
            if (subscriptionController.subscriptionStatus.value == 'active')
              _buildDetailRow(
                  'Subscription Started', _getSubscriptionStartDate()),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageLimitsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Usage & Limits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            _buildUsageRow('Students', 45,
                _getStudentLimit()), // Replace with actual count
            _buildUsageRow('Instructors', 8,
                _getInstructorLimit()), // Replace with actual count
            _buildUsageRow('Vehicles', 12,
                _getVehicleLimit()), // Replace with actual count
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upgrade your plan to increase limits and access additional features.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
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

  Widget _buildUsageRow(String label, int current, int limit) {
    final percentage = limit == -1 ? 0.0 : (current / limit).clamp(0.0, 1.0);
    final isNearLimit = percentage > 0.8;
    final isUnlimited = limit == -1;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                isUnlimited ? '$current (Unlimited)' : '$current / $limit',
                style: TextStyle(
                  fontSize: 14,
                  color: isNearLimit ? Colors.orange[700] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (!isUnlimited) ...[
            SizedBox(height: 4),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isNearLimit ? Colors.orange : Colors.blue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Billing History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to full billing history
                    Get.snackbar(
                      'Coming Soon',
                      'Detailed billing history will be available soon.',
                      backgroundColor: Colors.blue,
                      colorText: Colors.white,
                    );
                  },
                  child: Text('View All'),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (subscriptionController.subscriptionStatus.value == 'trial') ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.green[600], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You\'re currently on a free trial. No billing history yet.',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildBillingHistoryItem(
                'Monthly Subscription',
                'Dec 15, 2024',
                '\$20.00',
                'Paid',
              ),
              _buildBillingHistoryItem(
                'Monthly Subscription',
                'Nov 15, 2024',
                '\$20.00',
                'Paid',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillingHistoryItem(
      String description, String date, String amount, String status) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'Paid' ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color:
                    status == 'Paid' ? Colors.green[700] : Colors.orange[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (subscriptionController.subscriptionStatus.value == 'trial') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Get.to(() => SubscriptionScreen()),
              icon: Icon(Icons.upgrade),
              label: Text('Upgrade Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Get.to(() => SubscriptionScreen()),
            icon: Icon(Icons.compare),
            label: Text('Compare Plans'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (subscriptionController.subscriptionStatus.value == 'active') ...[
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCancelSubscriptionDialog(),
              icon: Icon(Icons.cancel, color: Colors.red),
              label: Text(
                'Cancel Subscription',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Helper methods
  LinearGradient _getStatusGradient() {
    switch (subscriptionController.subscriptionStatus.value) {
      case 'active':
        return LinearGradient(
          colors: [Colors.green[600]!, Colors.green[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'trial':
        final daysLeft = subscriptionController.remainingTrialDays.value;
        if (daysLeft <= 3) {
          return LinearGradient(
            colors: [Colors.orange[600]!, Colors.red[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        }
        return LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'expired':
        return LinearGradient(
          colors: [Colors.red[600]!, Colors.red[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [Colors.grey[600]!, Colors.grey[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  IconData _getStatusIcon() {
    switch (subscriptionController.subscriptionStatus.value) {
      case 'active':
        return Icons.verified;
      case 'trial':
        return Icons.access_time;
      case 'expired':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  String _getStatusText() {
    switch (subscriptionController.subscriptionStatus.value) {
      case 'active':
        return 'Active Subscription';
      case 'trial':
        return 'Free Trial';
      case 'expired':
        return 'Subscription Expired';
      case 'suspended':
        return 'Subscription Suspended';
      default:
        return 'Unknown Status';
    }
  }

  String _getStatusDescription() {
    switch (subscriptionController.subscriptionStatus.value) {
      case 'active':
        return 'Your subscription is active and all features are available.';
      case 'trial':
        final daysLeft = subscriptionController.remainingTrialDays.value;
        if (daysLeft <= 0) {
          return 'Your trial has expired. Upgrade to continue using all features.';
        } else if (daysLeft <= 3) {
          return 'Your trial is ending soon. Upgrade to avoid service interruption.';
        }
        return 'You have full access to all features during your trial period.';
      case 'expired':
        return 'Your subscription has expired. Please upgrade to continue using the service.';
      case 'suspended':
        return 'Your subscription is temporarily suspended. Contact support for assistance.';
      default:
        return 'Unable to determine subscription status.';
    }
  }

  String _getCurrentPlanName() {
    return subscriptionController.currentPackage.value?.name ??
        (subscriptionController.subscriptionStatus.value == 'trial'
            ? 'Free Trial'
            : 'Unknown');
  }

  String _getCurrentPrice() {
    if (subscriptionController.subscriptionStatus.value == 'trial') {
      return 'Free';
    }
    return subscriptionController.currentPackage.value?.monthlyPrice != null
        ? '\$${subscriptionController.currentPackage.value!.monthlyPrice.toStringAsFixed(2)}/month'
        : 'Unknown';
  }

  String _getBillingCycle() {
    if (subscriptionController.subscriptionStatus.value == 'trial') {
      return 'N/A (Trial)';
    }
    return 'Monthly'; // You can make this dynamic based on user's actual billing cycle
  }

  String _getTrialStartDate() {
    // Calculate based on trial length and remaining days
    final totalTrialDays = 30; // Assuming 30-day trial
    final daysUsed =
        totalTrialDays - subscriptionController.remainingTrialDays.value;
    final startDate = DateTime.now().subtract(Duration(days: daysUsed));
    return DateFormat('MMM dd, yyyy').format(startDate);
  }

  String _getSubscriptionStartDate() {
    // This should come from your backend data
    return 'Nov 15, 2024'; // Placeholder
  }

  String _getNextBillingDate() {
    // This should come from your backend data
    final nextBilling = DateTime.now().add(Duration(days: 15)); // Placeholder
    return DateFormat('MMM dd, yyyy').format(nextBilling);
  }

  int _getStudentLimit() {
    return subscriptionController.currentPackage.value
            ?.getLimit('max_students') ??
        50;
  }

  int _getInstructorLimit() {
    return subscriptionController.currentPackage.value
            ?.getLimit('max_instructors') ??
        5;
  }

  int _getVehicleLimit() {
    return subscriptionController.currentPackage.value
            ?.getLimit('max_vehicles') ??
        10;
  }

  void _showCancelSubscriptionDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Cancel Subscription'),
        content: Text(
            'Are you sure you want to cancel your subscription? You will continue to have access until the end of your current billing period.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _handleCancelSubscription();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  void _handleCancelSubscription() {
    Get.snackbar(
      'Coming Soon',
      'Subscription cancellation will be available soon. Please contact support for now.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
  }
}
