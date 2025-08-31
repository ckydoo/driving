import 'package:driving/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SubscriptionScreen extends StatelessWidget {
  final SubscriptionService _subscriptionService =
      Get.find<SubscriptionService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscribe'),
        backgroundColor: const Color(0xFF4A6CF7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: Obx(() {
        if (_subscriptionService.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubscriptionHeader(),
              const SizedBox(height: 20),
              _buildSubscriptionOptions(),
              const SizedBox(height: 20),
              _buildPaymentMethods(),
              const SizedBox(height: 20),
              _buildSubscribeButton(),
              const SizedBox(height: 20),
              _buildSubscriptionStatus(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSubscriptionHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Subscription:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get unlimited access to all features with our simple monthly plan.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOptions() {
    return Column(
      children: [
        // Monthly plan option (only option available)
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A6CF7), Color(0xFF2ECC71)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '\$5 per month / Per Store',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '• 1-week free trial\n• Full access to all features\n• Cloud sync\n• Priority support',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.white, size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Pay \$5 USD',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2ECC71),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose Subscription then Select payment method below and paste Token.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Methods',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPaymentMethodIcon(
                    'assets/images/innbucks.png', 'InnBucks'),
                _buildPaymentMethodIcon('assets/images/ecocash.png', 'EcoCash'),
                _buildPaymentMethodIcon('assets/images/omari.png', 'O\'Mari'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Payment Reference/Token',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodIcon(String assetPath, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSubscribeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _subscriptionService.canUseApp ? null : _handleSubscribe,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2ECC71),
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _getSubscribeButtonText(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _getSubscribeButtonText() {
    if (_subscriptionService.isInFreeTrial.value) {
      return 'Free Trial Active (${_subscriptionService.daysRemainingInTrial.value} days left)';
    } else if (_subscriptionService.isSubscriptionActive.value) {
      return 'Subscription Active (${_subscriptionService.daysRemainingInSubscription.value} days left)';
    } else if (_subscriptionService.subscriptionStatus.value == 'expired') {
      return 'Renew Subscription';
    } else {
      return 'Start Free Trial';
    }
  }

  Widget _buildSubscriptionStatus() {
    final info = _subscriptionService.getSubscriptionInfo();

    return Card(
      color: _getStatusColor(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getStatusText(info),
              style: const TextStyle(color: Colors.white),
            ),
            if (_subscriptionService.voucherCode.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Voucher Code:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                _subscriptionService.voucherCode.value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
            if (info['status'] == 'expired') ...[
              const SizedBox(height: 12),
              Text(
                'Subscription Expired ${_getExpiredDate()}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_subscriptionService.subscriptionStatus.value) {
      case 'active':
        return Colors.green;
      case 'trial':
        return Colors.blue;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(Map<String, dynamic> info) {
    if (info['is_trial']) {
      return 'Free Trial - ${info['days_remaining_trial']} days remaining';
    } else if (info['is_active']) {
      return 'Active Subscription - ${info['days_remaining_subscription']} days remaining';
    } else if (info['status'] == 'expired') {
      return 'Subscription Expired - Please renew to continue';
    } else {
      return 'No active subscription';
    }
  }

  String _getExpiredDate() {
    final data = _subscriptionService.subscriptionData.value;
    if (data?['subscription_end_date'] != null) {
      final endDate = DateTime.parse(data!['subscription_end_date']);
      return '${endDate.day}/${endDate.month}/${endDate.year}';
    }
    return 'Recently';
  }

  void _handleSubscribe() async {
    if (_subscriptionService.subscriptionStatus.value == 'inactive') {
      // Start free trial
      final success = await _subscriptionService.startFreeTrial();
      if (success) {
        _showTrialStartedDialog();
      }
    } else if (_subscriptionService.subscriptionStatus.value == 'expired' ||
        _subscriptionService.daysRemainingInTrial.value <= 0) {
      // Show payment dialog
      _showPaymentDialog();
    }
  }

  void _showTrialStartedDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Free Trial Started! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Your 7-day free trial has started!\n\nVoucher Code: ${_subscriptionService.voucherCode.value}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog() {
    final paymentReferenceController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Complete Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send \$5 USD using any of the payment methods shown above, then enter your payment reference below:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentReferenceController,
              decoration: const InputDecoration(
                labelText: 'Payment Reference/Token',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (paymentReferenceController.text.isNotEmpty) {
                Get.back();

                // First subscribe
                final subscribed =
                    await _subscriptionService.subscribeToMonthlyPlan(
                  paymentMethod: 'mobile_money',
                  paymentReference: paymentReferenceController.text,
                );

                if (subscribed) {
                  _showPaymentVerificationDialog(
                      paymentReferenceController.text);
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showPaymentVerificationDialog(String paymentReference) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Subscription Expired'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Voucher Code: ${_subscriptionService.voucherCode.value}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Copy this Voucher Code and send it along with Proof of Payment (PoP) to our WhatsApp number through WhatsApp to receive your Token.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _copyVoucherCode(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4A6CF7),
                    ),
                    child: Text('Copy Voucher',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openWhatsApp(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF25D366),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('WhatsApp', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _copyVoucherCode() {
    // Copy voucher code to clipboard
    // Implement clipboard functionality
    Get.snackbar(
      'Copied',
      'Voucher code copied to clipboard',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  void _openWhatsApp() {
    // Open WhatsApp with pre-filled message
    // Implement WhatsApp opening functionality
    final message =
        'Hi, I want to activate my subscription.\nVoucher Code: ${_subscriptionService.voucherCode.value}\nPayment Reference: [Your payment reference here]';
    // Use url_launcher to open WhatsApp
  }

  void _showHelpDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('How Subscriptions Work'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Start with a FREE 7-day trial'),
            SizedBox(height: 8),
            Text('2. After trial, pay \$5/month to continue'),
            SizedBox(height: 8),
            Text('3. Send payment via mobile money'),
            SizedBox(height: 8),
            Text('4. Share voucher code + proof of payment'),
            SizedBox(height: 8),
            Text('5. Get activated within 24 hours'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            child: Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
