// lib/services/subscription_service.dart - FIXED RETURN TYPES
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/auth_controller.dart';
import '../models/subscription_package.dart';

class SubscriptionService {
  // Environment-based API URL
  static String get _baseUrl {
    const environment =
        String.fromEnvironment('ENV', defaultValue: 'development');

    switch (environment) {
      case 'development':
        return 'http://192.168.9.108:8000/api';
      case 'production':
        return 'https://your-production-domain.com/api'; // REPLACE WITH YOUR DOMAIN
      default:
        return 'http://192.168.9.108:8000/api';
    }
  }

  // Get subscription packages - Returns List<SubscriptionPackage>
  Future<List<SubscriptionPackage>> getSubscriptionPackages() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/subscription/packages'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both direct array and wrapped response
        final List<dynamic> packagesJson =
            data is List ? data : data['data'] ?? data['packages'] ?? [];

        return packagesJson
            .map((json) => SubscriptionPackage.fromJson(json))
            .toList();
      } else {
        print('❌ Failed to load packages: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception(
            'Failed to load subscription packages: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching packages: $e');
      throw Exception('Error fetching packages: $e');
    }
  }

  // Get subscription status - Returns Map<String, dynamic>
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/subscription/status'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? data;
      } else {
        print('❌ Failed to get subscription status: ${response.statusCode}');
        throw Exception(
            'Failed to get subscription status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting subscription status: $e');
      throw Exception('Error getting subscription status: $e');
    }
  }

  // Create payment intent - Returns String (client_secret)
  Future<String> createPaymentIntent(
      int packageId, String billingPeriod) async {
    try {
      print(
          '🔄 Creating payment intent for package $packageId ($billingPeriod)');

      final response = await http.post(
        Uri.parse('$_baseUrl/subscription/create-payment-intent'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'package_id': packageId,
          'billing_period': billingPeriod,
        }),
      );

      print('📥 Payment intent response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract client_secret from response
        String? clientSecret;

        if (data is Map<String, dynamic>) {
          // Try multiple possible locations for client_secret
          clientSecret = data['client_secret'] as String? ??
              data['data']?['client_secret'] as String?;
        }

        if (clientSecret == null || clientSecret.isEmpty) {
          print('❌ Response data: $data');
          throw Exception('No client secret in response');
        }

        print('✅ Payment intent created successfully');
        print('🔑 Client secret: ${clientSecret.substring(0, 20)}...');
        return clientSecret;
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Failed to create payment intent';
        print('❌ Payment intent error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error creating payment intent: $e');
      rethrow;
    }
  }

  // Confirm payment - Returns bool
  Future<bool> confirmPayment(
      String paymentIntentId, int packageId, String billingPeriod) async {
    try {
      print('🔄 Confirming payment: $paymentIntentId');

      final response = await http.post(
        Uri.parse('$_baseUrl/subscription/confirm-payment'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'payment_intent_id': paymentIntentId,
          'package_id': packageId,
          'billing_period': billingPeriod,
        }),
      );

      print('📥 Confirmation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Payment confirmed successfully');
        return true;
      } else {
        print('❌ Payment confirmation failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error confirming payment: $e');
      return false;
    }
  }

  // Cancel subscription - Returns bool
  Future<bool> cancelSubscription() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/subscription/cancel'),
        headers: await _getAuthHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error canceling subscription: $e');
      return false;
    }
  }

  // Get billing history - Returns List<Map<String, dynamic>>
  Future<List<Map<String, dynamic>>> getBillingHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/subscription/billing-history'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception(
            'Failed to get billing history: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting billing history: $e');
      return [];
    }
  }

  // ============================================
  // Private Helper Methods
  // ============================================

  /// Get authentication headers with token from AuthController
  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final token = await _getStoredAuthToken();

      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (e) {
      print('⚠️ Error getting auth headers: $e');
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
    }
  }

  /// Get stored auth token using the same method as AuthController
  Future<String?> _getStoredAuthToken() async {
    try {
      // First try to get from AuthController if available
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        final user = authController.currentUser.value;

        if (user?.email != null) {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('api_token_${user!.email}');
          return token;
        }
      }

      // Fallback: try to get from any stored token
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('api_token_'));

      if (keys.isNotEmpty) {
        return prefs.getString(keys.first);
      }

      return null;
    } catch (e) {
      print('⚠️ Error getting stored auth token: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _getStoredAuthToken();
    return token != null && token.isNotEmpty;
  }
}
