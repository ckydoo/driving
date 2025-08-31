import 'package:driving/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SubscriptionStatusWidget extends StatelessWidget {
  final SubscriptionService _subscriptionService =
      Get.find<SubscriptionService>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final info = _subscriptionService.getSubscriptionInfo();

      return Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getStatusIcon(info['status']),
                    color: _getStatusColor(info['status']),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Subscription Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildStatusRow('Status', _getStatusText(info)),
              if (info['is_trial'] || info['is_active'])
                _buildStatusRow('Days Remaining',
                    '${info['is_trial'] ? info['days_remaining_trial'] : info['days_remaining_subscription']} days'),
              if (info['plan'] != 'trial')
                _buildStatusRow('Plan', '\$${info['price']}/month'),
              if (info['voucher_code'].isNotEmpty)
                _buildStatusRow('Voucher Code', info['voucher_code']),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.toNamed('/subscription'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getButtonColor(info['status']),
                  ),
                  child: Text(
                    _getButtonText(info),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'trial':
        return Icons.schedule;
      case 'expired':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
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

  Color _getButtonColor(String status) {
    switch (status) {
      case 'expired':
        return Colors.red;
      case 'trial':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  String _getStatusText(Map<String, dynamic> info) {
    if (info['is_trial']) {
      return 'Free Trial Active';
    } else if (info['is_active']) {
      return 'Subscription Active';
    } else if (info['status'] == 'expired') {
      return 'Subscription Expired';
    } else {
      return 'No Subscription';
    }
  }

  String _getButtonText(Map<String, dynamic> info) {
    if (info['status'] == 'expired') {
      return 'Renew Subscription';
    } else if (info['status'] == 'inactive') {
      return 'Start Free Trial';
    } else {
      return 'Manage Subscription';
    }
  }
}
