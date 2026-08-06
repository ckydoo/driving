import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../controllers/auth_controller.dart';
import '../models/subscription_package.dart';

class SubscriptionService {
  static String get _baseUrl => ApiService.baseUrl;

  // Get auth headers with token - FIXED TO MATCH AuthController METHOD
  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      // Get token using the SAME method as AuthController
      final token = await _getStoredAuthToken();

      debugPrint('🔑 Auth token exists: ${token != null}');
      if (token != null) {
        debugPrint(
            '🔑 Token prefix: ${token.substring(0, min(20, token.length))}...');
      }

      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (e) {
      debugPrint('❌ Error getting auth headers: $e');
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
            debugPrint('✅ Token found for user: ${user.email}');
            return token;
          } else {
            debugPrint('⚠️ No token found for user: ${user.email}');
          }
        } else {
          debugPrint('⚠️ No current user in AuthController');
        }
      } else {
        debugPrint('⚠️ AuthController not registered');
      }

      debugPrint('❌ No authentication token found for current user');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting stored auth token: $e');
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
      debugPrint('📡 Fetching packages from: $url');

      final headers = await _getAuthHeaders();
      debugPrint('📡 Request headers: ${headers.keys.toList()}');

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

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Successfully decoded response');
        debugPrint('🔍 Response type: ${data.runtimeType}');

        // Handle both direct array and wrapped response
        final List<dynamic> packagesJson;

        if (data is List) {
          debugPrint('✅ Response is direct array');
          packagesJson = data;
        } else if (data is Map<String, dynamic>) {
          debugPrint('✅ Response is wrapped object');
          packagesJson = data['data'] ?? data['packages'] ?? [];
          debugPrint('🔍 Found ${packagesJson.length} packages in data');
        } else {
          debugPrint('❌ Unexpected response format');
          packagesJson = [];
        }

        if (packagesJson.isEmpty) {
          debugPrint('⚠️ No packages found in response');
          debugPrint('⚠️ Full response: $data');
        }

        final packages = packagesJson
            .map((json) {
              try {
                debugPrint('🔄 Parsing package: ${json['name']}');
                return SubscriptionPackage.fromJson(json);
              } catch (e) {
                debugPrint('❌ Error parsing package: $e');
                debugPrint('❌ Package data: $json');
                return null;
              }
            })
            .whereType<SubscriptionPackage>()
            .toList();

        debugPrint('✅ Successfully parsed ${packages.length} packages');
        for (var pkg in packages) {
          debugPrint('  - ${pkg.name}: \$${pkg.monthlyPrice}/mo');
        }

        return packages;
      } else if (response.statusCode == 401) {
        debugPrint('❌ Authentication failed - token may be expired');
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 404) {
        debugPrint('❌ API endpoint not found');
        throw Exception('Subscription API not found. Please contact support.');
      } else {
        debugPrint('❌ Failed to load packages: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.body}');
        throw Exception(
            'Failed to load subscription packages (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Exception fetching packages: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Get subscription status - Returns Map<String, dynamic>
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final url = '$_baseUrl/subscription/status';
      debugPrint('📡 Fetching subscription status from: $url');

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

      debugPrint('📥 Status response code: ${response.statusCode}');
      debugPrint('📥 Status response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle wrapped response
        if (data is Map<String, dynamic>) {
          final statusData = data['data'] ?? data;
          debugPrint('✅ Subscription status retrieved');
          debugPrint('🔍 Status: ${statusData['subscription_status']}');
          debugPrint('🔍 Trial days: ${statusData['remaining_trial_days']}');

          return statusData;
        }

        return data;
      } else if (response.statusCode == 401) {
        debugPrint('❌ Authentication failed getting status');
        throw Exception('Authentication failed. Please login again.');
      } else {
        debugPrint(
            '❌ Failed to get subscription status: ${response.statusCode}');
        throw Exception(
            'Failed to get subscription status (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Error getting subscription status: $e');
      rethrow;
    }
  }

  // Cancel subscription - Returns bool
  Future<bool> cancelSubscription() async {
    try {
      debugPrint('🔄 Canceling subscription');

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

      debugPrint('📥 Cancel response: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ Subscription canceled successfully');
        return true;
      } else {
        debugPrint('❌ Cancel failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error canceling subscription: $e');
      return false;
    }
  }

  // Get billing history - Returns List<Map<String, dynamic>>
  Future<List<Map<String, dynamic>>> getBillingHistory() async {
    try {
      debugPrint('🔄 Fetching billing history');

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

      debugPrint('📥 Billing history response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> history = data['data'] ?? data['history'] ?? [];

        debugPrint('✅ Retrieved ${history.length} billing records');

        return List<Map<String, dynamic>>.from(history);
      } else {
        debugPrint('❌ Failed to get billing history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching billing history: $e');
      return [];
    }
  }

  // Helper method to check network connectivity
  Future<bool> checkConnectivity() async {
    try {
      debugPrint('🔍 Checking network connectivity...');

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
      debugPrint(isConnected ? '✅ Network connected' : '❌ Network unavailable');

      return isConnected;
    } catch (e) {
      debugPrint('❌ Network connectivity check failed: $e');
      return false;
    }
  }

  /// Check trial eligibility
  Future<Map<String, dynamic>> checkTrialEligibility() async {
    try {
      final url = '$_baseUrl/subscription/check-trial-eligibility';
      debugPrint('📡 Checking trial eligibility from: $url');

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

      debugPrint('📥 Trial eligibility response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Trial eligibility retrieved');

        return data['data'] ?? data;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception(
            'Failed to check trial eligibility (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Exception checking trial eligibility: $e');
      rethrow;
    }
  }

  // Helper to get min value
  int min(int a, int b) => a < b ? a : b;
}
