// lib/services/subscription_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/auth_controller.dart';
import '../models/subscription_package.dart';

class SubscriptionService {
  static const String _baseUrl =
      'http://192.168.9.108:8000/api'; // Replace with your actual API URL

  Future<List<SubscriptionPackage>> getSubscriptionPackages() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/subscription/packages'),
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
        throw Exception(
            'Failed to load subscription packages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching packages: $e');
    }
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/subscription/status'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? data;
      } else {
        throw Exception(
            'Failed to get subscription status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting subscription status: $e');
    }
  }

  Future<String> createPaymentIntent(
      int packageId, String billingPeriod) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/subscription/create-payment-intent'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'package_id': packageId,
          'billing_period': billingPeriod,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['client_secret'] ?? data['client_secret'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            errorData['message'] ?? 'Failed to create payment intent');
      }
    } catch (e) {
      throw Exception('Error creating payment intent: $e');
    }
  }

  Future<bool> confirmPayment(
      String paymentIntentId, int packageId, String billingPeriod) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/subscription/confirm-payment'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'payment_intent_id': paymentIntentId,
          'package_id': packageId,
          'billing_period': billingPeriod,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error confirming payment: $e');
      return false;
    }
  }

  Future<bool> cancelSubscription() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/subscription/cancel'),
        headers: await _getAuthHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error canceling subscription: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBillingHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/subscription/billing-history'),
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
      print('Error getting billing history: $e');
      return [];
    }
  }

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
      print('Error getting auth headers: $e');
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
      print('Error getting stored auth token: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _getStoredAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current user email for token storage
  String? _getCurrentUserEmail() {
    try {
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        return authController.currentUser.value?.email;
      }
      return null;
    } catch (e) {
      print('Error getting current user email: $e');
      return null;
    }
  }

  /// Store new auth token (called after successful authentication)
  Future<void> storeAuthToken(String token) async {
    try {
      final email = _getCurrentUserEmail();
      if (email != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('api_token_$email', token);
      }
    } catch (e) {
      print('Error storing auth token: $e');
    }
  }

  /// Clear stored auth token
  Future<void> clearAuthToken() async {
    try {
      final email = _getCurrentUserEmail();
      if (email != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('api_token_$email');
      }
    } catch (e) {
      print('Error clearing auth token: $e');
    }
  }

  /// Test API connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user'),
        headers: await _getAuthHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  /// Handle API errors and token refresh if needed
  Future<void> _handleApiError(http.Response response) async {
    if (response.statusCode == 401) {
      // Token might be expired, clear it
      await clearAuthToken();

      // Notify AuthController to handle re-authentication
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        // You might want to trigger a re-login flow here
        print('API token expired, user needs to re-authenticate');
      }
    }
  }
}
