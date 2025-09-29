// lib/services/api_interceptor.dart
// Add this to your existing ApiService or create a new interceptor

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:driving/controllers/subscription_controller.dart';

class ApiInterceptor {
  /// Handle API response and check for subscription errors
  static Future<http.Response> handleResponse(http.Response response) async {
    // Check for subscription-related 403 errors
    if (response.statusCode == 403) {
      try {
        final data = json.decode(response.body);
        final errorCode = data['error_code'];

        print('⚠️ API 403 Error: $errorCode');

        // Handle subscription-specific errors
        if (errorCode == 'SUBSCRIPTION_SUSPENDED') {
          _handleSubscriptionSuspended(data);
          throw SubscriptionSuspendedException(data['message']);
        } else if (errorCode == 'SUBSCRIPTION_EXPIRED') {
          _handleSubscriptionExpired(data);
          throw SubscriptionExpiredException(data['message']);
        } else if (errorCode == 'TRIAL_EXPIRED') {
          _handleTrialExpired(data);
          throw TrialExpiredException(data['message']);
        }
      } catch (e) {
        if (e is SubscriptionException) {
          rethrow;
        }
        // If not a subscription error, continue normal error handling
      }
    }

    return response;
  }

  static void _handleSubscriptionSuspended(Map<String, dynamic> data) {
    print('🚫 Subscription suspended');

    // Update subscription controller
    if (Get.isRegistered<SubscriptionController>()) {
      final controller = Get.find<SubscriptionController>();
      controller.subscriptionStatus.value = 'suspended';
    }

    // Show dialog
    Future.delayed(Duration(milliseconds: 300), () {
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red[700], size: 28),
              SizedBox(width: 12),
              Text('Subscription Suspended'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['message'] ?? 'Your subscription has been suspended.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What to do:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Contact support for assistance\n'
                      '• Update your payment method\n'
                      '• Check for outstanding invoices',
                      style: TextStyle(color: Colors.blue[900]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('OK'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    });
  }

  static void _handleSubscriptionExpired(Map<String, dynamic> data) {
    print('🚫 Subscription expired');

    // Update subscription controller
    if (Get.isRegistered<SubscriptionController>()) {
      final controller = Get.find<SubscriptionController>();
      controller.subscriptionStatus.value = 'expired';
    }

    // Show dialog
    Future.delayed(Duration(milliseconds: 300), () {
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange[700], size: 28),
              SizedBox(width: 12),
              Text('Subscription Expired'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['message'] ?? 'Your subscription has expired.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Renew your subscription to continue using all features.',
                  style: TextStyle(color: Colors.green[900]),
                ),
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
                Get.toNamed('/subscription');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: Text('Renew Now'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    });
  }

  static void _handleTrialExpired(Map<String, dynamic> data) {
    print('🚫 Trial expired');

    // Update subscription controller
    if (Get.isRegistered<SubscriptionController>()) {
      final controller = Get.find<SubscriptionController>();
      controller.subscriptionStatus.value = 'expired';
      controller.remainingTrialDays.value = 0;
    }

    // Show dialog
    Future.delayed(Duration(milliseconds: 300), () {
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.access_time_filled, color: Colors.blue[700], size: 28),
              SizedBox(width: 12),
              Text('Trial Ended'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your free trial has ended.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                data['message'] ??
                    'Subscribe now to continue using all features.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[800]!],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Upgrade now to unlock all premium features!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                Get.toNamed('/subscription');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('View Plans'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    });
  }
}

// Custom exceptions
class SubscriptionException implements Exception {
  final String message;
  SubscriptionException(this.message);

  @override
  String toString() => message;
}

class SubscriptionSuspendedException extends SubscriptionException {
  SubscriptionSuspendedException(String message) : super(message);
}

class SubscriptionExpiredException extends SubscriptionException {
  SubscriptionExpiredException(String message) : super(message);
}

class TrialExpiredException extends SubscriptionException {
  TrialExpiredException(String message) : super(message);
}
