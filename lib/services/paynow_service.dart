// lib/services/paynow_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import 'api_service.dart';

class PaynowService {
  final String _baseUrl = ApiService.baseUrl;

  /// Get authentication headers with Bearer token
  Future<Map<String, String>> _getAuthHeaders() async {
    String? token;

    // Try to get token from AuthController
    if (Get.isRegistered<AuthController>()) {
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;

      if (user?.email != null) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('api_token_${user!.email}');
      }
    }

    // Fallback: get any available token
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('api_token_'));
      if (keys.isNotEmpty) {
        token = prefs.getString(keys.first);
      }
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final headers = await _getAuthHeaders();
    final token = headers['Authorization'];
    return token != null && token.isNotEmpty && token != 'Bearer ';
  }

  /// Initiate web payment (opens Paynow website)
  Future<Map<String, dynamic>> initiateWebPayment(int invoiceId) async {
    try {
      print('🔄 Initiating Paynow web payment for invoice $invoiceId');

      final url = '$_baseUrl/school/paynow/initiate'; // ✅ API endpoint
      final body = json.encode({'invoice_id': invoiceId});

      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getAuthHeaders(),
            body: body,
          )
          .timeout(Duration(seconds: 30));

      print('📥 Web payment response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'redirect_url': data['redirect_url'],
            'poll_url': data['poll_url'],
          };
        } else {
          throw Exception(data['error'] ?? 'Failed to initiate payment');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Payment initiation failed');
      }
    } catch (e) {
      print('❌ Error initiating web payment: $e');
      rethrow;
    }
  }

  /// Initiate mobile payment (EcoCash or OneMoney)
  Future<Map<String, dynamic>> initiateMobilePayment({
    required int invoiceId,
    required String phoneNumber,
    required String method,
  }) async {
    try {
      print('🔄 Initiating Paynow mobile payment');

      if (!_isValidZimbabweNumber(phoneNumber)) {
        throw Exception(
            'Invalid phone number. Must be 10 digits starting with 07');
      }

      final url = '$_baseUrl/school/paynow/initiate-mobile'; // ✅ API endpoint
      final body = json.encode({
        'invoice_id': invoiceId,
        'phone_number': phoneNumber,
        'method': method,
      });

      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getAuthHeaders(),
            body: body,
          )
          .timeout(Duration(seconds: 30));

      print('📥 Mobile payment response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'instructions': data['instructions'],
            'poll_url': data['poll_url'],
          };
        } else {
          throw Exception(data['error'] ?? 'Failed to initiate mobile payment');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            errorData['error'] ?? 'Mobile payment initiation failed');
      }
    } catch (e) {
      print('❌ Error initiating mobile payment: $e');
      rethrow;
    }
  }

  /// Check payment status
  Future<Map<String, dynamic>> checkPaymentStatus(int invoiceId) async {
    try {
      print('🔄 Checking payment status for invoice $invoiceId');

      final url = '$_baseUrl/school/paynow/check-status'; // ✅ API endpoint
      final body = json.encode({'invoice_id': invoiceId});

      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getAuthHeaders(),
            body: body,
          )
          .timeout(Duration(seconds: 15));

      print('📥 Status check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to check payment status');
      }
    } catch (e) {
      print('❌ Error checking payment status: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Validate Zimbabwe phone number
  bool _isValidZimbabweNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return RegExp(r'^07[0-9]{8}$').hasMatch(cleanNumber);
  }
}
