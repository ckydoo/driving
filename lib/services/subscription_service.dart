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
        return 'https://driving.fonpos.co.zw/api';
      case 'production':
        return 'https://your-production-domain.com/api'; // REPLACE WITH YOUR DOMAIN
      default:
        return 'http://192.168.9.108:8000/api';
    }
  }

  /// Create Stripe Checkout Session (for desktop platforms)
  Future<String> createCheckoutSession(
      int packageId, String billingPeriod) async {
    try {
      print('🔄 Creating Stripe Checkout session for package $packageId');

      final url = '$_baseUrl/subscription/create-checkout-session';
      print('📡 POST to: $url');

      final body = json.encode({
        'package_id': packageId,
        'billing_period': billingPeriod,
      });

      final response = await http
          .post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
        body: body,
      )
          .timeout(
        Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Checkout session creation timeout');
        },
      );

      print('📥 Checkout session response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        String? checkoutUrl;
        if (data['success'] == true && data['data'] != null) {
          checkoutUrl = data['data']['checkout_url'] as String?;
        }

        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          throw Exception('No checkout URL received');
        }

        print('✅ Checkout session created');
        print('🔗 Checkout URL: $checkoutUrl');
        return checkoutUrl;
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Failed to create checkout session';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error creating checkout session: $e');
      rethrow;
    }
  }

  // Get auth headers with token - FIXED TO MATCH AuthController METHOD
  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      // Get token using the SAME method as AuthController
      final token = await _getStoredAuthToken();

      print('🔑 Auth token exists: ${token != null}');
      if (token != null) {
        print(
            '🔑 Token prefix: ${token.substring(0, min(20, token.length))}...');
      }

      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (e) {
      print('❌ Error getting auth headers: $e');
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
    }
  }

  // Get stored auth token using the SAME method as AuthController
  Future<String?> _getStoredAuthToken() async {
    try {
      // First try to get from AuthController if available
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        final user = authController.currentUser.value;

        if (user?.email != null) {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('api_token_${user!.email}');

          if (token != null) {
            print('✅ Token found for user: ${user.email}');
            return token;
          } else {
            print('⚠️ No token found for user: ${user.email}');
          }
        } else {
          print('⚠️ No current user in AuthController');
        }
      } else {
        print('⚠️ AuthController not registered');
      }

      // Fallback: try to get from any stored token
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('api_token_'));

      if (keys.isNotEmpty) {
        final token = prefs.getString(keys.first);
        print('✅ Fallback token found: ${keys.first}');
        return token;
      }

      print('❌ No authentication token found anywhere');
      return null;
    } catch (e) {
      print('❌ Error getting stored auth token: $e');
      return null;
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _getStoredAuthToken();
    return token != null && token.isNotEmpty;
  }

  // Get subscription packages - Returns List<SubscriptionPackage>
  Future<List<SubscriptionPackage>> getSubscriptionPackages() async {
    try {
      final url = '$_baseUrl/subscription/packages';
      print('📡 Fetching packages from: $url');

      final headers = await _getAuthHeaders();
      print('📡 Request headers: ${headers.keys.toList()}');

      final response = await http
          .get(
        Uri.parse(url),
        headers: headers,
      )
          .timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Request timeout - please check your internet connection');
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Successfully decoded response');
        print('🔍 Response type: ${data.runtimeType}');

        // Handle both direct array and wrapped response
        final List<dynamic> packagesJson;

        if (data is List) {
          print('✅ Response is direct array');
          packagesJson = data;
        } else if (data is Map<String, dynamic>) {
          print('✅ Response is wrapped object');
          packagesJson = data['data'] ?? data['packages'] ?? [];
          print('🔍 Found ${packagesJson.length} packages in data');
        } else {
          print('❌ Unexpected response format');
          packagesJson = [];
        }

        if (packagesJson.isEmpty) {
          print('⚠️ No packages found in response');
          print('⚠️ Full response: $data');
        }

        final packages = packagesJson
            .map((json) {
              try {
                print('🔄 Parsing package: ${json['name']}');
                return SubscriptionPackage.fromJson(json);
              } catch (e) {
                print('❌ Error parsing package: $e');
                print('❌ Package data: $json');
                return null;
              }
            })
            .whereType<SubscriptionPackage>()
            .toList();

        print('✅ Successfully parsed ${packages.length} packages');
        for (var pkg in packages) {
          print('  - ${pkg.name}: \$${pkg.monthlyPrice}/mo');
        }

        return packages;
      } else if (response.statusCode == 401) {
        print('❌ Authentication failed - token may be expired');
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 404) {
        print('❌ API endpoint not found');
        throw Exception('Subscription API not found. Please contact support.');
      } else {
        print('❌ Failed to load packages: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        throw Exception(
            'Failed to load subscription packages (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Exception fetching packages: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Get subscription status - Returns Map<String, dynamic>
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final url = '$_baseUrl/subscription/status';
      print('📡 Fetching subscription status from: $url');

      final response = await http
          .get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      )
          .timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Request timeout - please check your internet connection');
        },
      );

      print('📥 Status response code: ${response.statusCode}');
      print('📥 Status response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle wrapped response
        if (data is Map<String, dynamic>) {
          final statusData = data['data'] ?? data;
          print('✅ Subscription status retrieved');
          print('🔍 Status: ${statusData['subscription_status']}');
          print('🔍 Trial days: ${statusData['remaining_trial_days']}');

          return statusData;
        }

        return data;
      } else if (response.statusCode == 401) {
        print('❌ Authentication failed getting status');
        throw Exception('Authentication failed. Please login again.');
      } else {
        print('❌ Failed to get subscription status: ${response.statusCode}');
        throw Exception(
            'Failed to get subscription status (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error getting subscription status: $e');
      rethrow;
    }
  }

  // Create payment intent - Returns String (client_secret)
  Future<String> createPaymentIntent(
      int packageId, String billingPeriod) async {
    try {
      print(
          '🔄 Creating payment intent for package $packageId ($billingPeriod)');

      final url = '$_baseUrl/subscription/create-payment-intent';
      print('📡 POST to: $url');

      final body = json.encode({
        'package_id': packageId,
        'billing_period': billingPeriod,
      });
      print('📤 Request body: $body');

      // INCREASED TIMEOUT TO 60 SECONDS
      final response = await http
          .post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
        body: body,
      )
          .timeout(
        Duration(seconds: 60), // CHANGED FROM 30 TO 60 SECONDS
        onTimeout: () {
          print('⏰ Request timeout after 60 seconds');
          throw Exception(
              'Payment request is taking longer than usual. Please check your connection and try again.');
        },
      );

      print('📥 Payment intent response: ${response.statusCode}');
      print('📥 Payment response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract client_secret from response
        String? clientSecret;

        if (data is Map<String, dynamic>) {
          // Handle both response formats
          if (data['success'] == true && data['data'] != null) {
            // New format: { success: true, data: { client_secret: "..." } }
            clientSecret = data['data']['client_secret'] as String?;
          } else {
            // Legacy format
            clientSecret = data['client_secret'] as String? ??
                data['data']?['client_secret'] as String? ??
                data['clientSecret'] as String?;
          }
        }

        if (clientSecret == null || clientSecret.isEmpty) {
          print('❌ No client secret in response');
          print('❌ Response data: $data');
          throw Exception('No payment client secret received from server');
        }

        print('✅ Payment intent created successfully');
        print('🔑 Client secret received (length: ${clientSecret.length})');
        return clientSecret;
      } else if (response.statusCode == 401) {
        print('❌ Authentication failed');
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 404) {
        print('❌ Package not found');
        throw Exception(
            'Selected package not found. Please refresh and try again.');
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Validation error';
        print('❌ Validation error: $errorMessage');
        throw Exception(errorMessage);
      } else if (response.statusCode == 429) {
        print('❌ Too many requests');
        throw Exception(
            'Too many payment attempts. Please wait a moment and try again.');
      } else if (response.statusCode >= 500) {
        print('❌ Server error: ${response.statusCode}');
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Server error';
        throw Exception(
            'Payment service temporarily unavailable: $errorMessage');
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Failed to create payment intent';
        print('❌ Payment intent error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      print('❌ Network error: $e');
      throw Exception('Network error. Please check your internet connection.');
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

      final url = '$_baseUrl/subscription/confirm-payment';
      print('📡 POST to: $url');

      final body = json.encode({
        'payment_intent_id': paymentIntentId,
        'package_id': packageId,
        'billing_period': billingPeriod,
      });

      final response = await http
          .post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
        body: body,
      )
          .timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Payment confirmation timeout');
        },
      );

      print('📥 Confirmation response: ${response.statusCode}');
      print('📥 Confirmation body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Payment confirmed successfully');
        return true;
      } else {
        print('❌ Payment confirmation failed: ${response.body}');
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Payment confirmation failed');
      }
    } catch (e) {
      print('❌ Error confirming payment: $e');
      rethrow;
    }
  }

  // Cancel subscription - Returns bool
  Future<bool> cancelSubscription() async {
    try {
      print('🔄 Canceling subscription');

      final url = '$_baseUrl/subscription/cancel';
      final response = await http
          .post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      )
          .timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Cancel request timeout');
        },
      );

      print('📥 Cancel response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Subscription canceled successfully');
        return true;
      } else {
        print('❌ Cancel failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error canceling subscription: $e');
      return false;
    }
  }

  // Get billing history - Returns List<Map<String, dynamic>>
  Future<List<Map<String, dynamic>>> getBillingHistory() async {
    try {
      print('🔄 Fetching billing history');

      final url = '$_baseUrl/subscription/billing-history';
      final response = await http
          .get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      )
          .timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Billing history request timeout');
        },
      );

      print('📥 Billing history response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> history = data['data'] ?? data['history'] ?? [];

        print('✅ Retrieved ${history.length} billing records');

        return List<Map<String, dynamic>>.from(history);
      } else {
        print('❌ Failed to get billing history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching billing history: $e');
      return [];
    }
  }

  // Helper method to check network connectivity
  Future<bool> checkConnectivity() async {
    try {
      print('🔍 Checking network connectivity...');

      final response = await http
          .get(
        Uri.parse('$_baseUrl/health'),
      )
          .timeout(
        Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Network timeout');
        },
      );

      final isConnected = response.statusCode == 200;
      print(isConnected ? '✅ Network connected' : '❌ Network unavailable');

      return isConnected;
    } catch (e) {
      print('❌ Network connectivity check failed: $e');
      return false;
    }
  }

  /// Check trial eligibility
  Future<Map<String, dynamic>> checkTrialEligibility() async {
    try {
      final url = '$_baseUrl/subscription/check-trial-eligibility';
      print('📡 Checking trial eligibility from: $url');

      final response = await http
          .get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      )
          .timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
              'Request timeout - please check your internet connection');
        },
      );

      print('📥 Trial eligibility response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Trial eligibility retrieved');

        return data['data'] ?? data;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception(
            'Failed to check trial eligibility (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Exception checking trial eligibility: $e');
      rethrow;
    }
  }

  // Helper to get min value
  int min(int a, int b) => a < b ? a : b;
}
