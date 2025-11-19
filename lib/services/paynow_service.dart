// lib/services/paynow_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class PaynowService {
  final String _baseUrl = ApiService.baseUrl;

  // Get authentication headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  /// Initiate web payment (opens Paynow website)
  Future<Map<String, dynamic>> initiateWebPayment(int invoiceId) async {
    try {
      print('🔄 Initiating Paynow web payment for invoice $invoiceId');

      final url = '$_baseUrl/school/paynow/initiate';
      final body = json.encode({'invoice_id': invoiceId});

      final response = await http
          .post(Uri.parse(url), headers: await _getAuthHeaders(), body: body)
          .timeout(Duration(seconds: 30));

      print('📥 Web payment response: ${response.statusCode}');

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
        throw Exception('Payment initiation failed');
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
        throw Exception('Invalid phone number. Use format: 0771234567');
      }

      final url = '$_baseUrl/school/paynow/initiate-mobile';
      final body = json.encode({
        'invoice_id': invoiceId,
        'phone_number': phoneNumber,
        'method': method,
      });

      final response = await http
          .post(Uri.parse(url), headers: await _getAuthHeaders(), body: body)
          .timeout(Duration(seconds: 30));

      print('📥 Mobile payment response: ${response.statusCode}');

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
        throw Exception('Mobile payment initiation failed');
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

      final url = '$_baseUrl/school/paynow/check-status';
      final body = json.encode({'invoice_id': invoiceId});

      final response = await http
          .post(Uri.parse(url), headers: await _getAuthHeaders(), body: body)
          .timeout(Duration(seconds: 15));

      print('📥 Status check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'paid': data['paid'] ?? false,
            'status': data['status'] ?? 'unknown',
            'amount': data['amount'],
            'reference': data['reference'],
          };
        } else {
          throw Exception(data['message'] ?? 'Status check failed');
        }
      } else {
        throw Exception('Status check failed');
      }
    } catch (e) {
      print('❌ Error checking payment status: $e');
      rethrow;
    }
  }

  /// Validate Zimbabwe phone number format
  bool _isValidZimbabweNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final regex = RegExp(r'^07[0-9]{8}$');
    return regex.hasMatch(cleaned);
  }

  /// Format phone number for display
  String formatPhoneNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
    }
    return phoneNumber;
  }

  /// Get payment method name for display
  String getPaymentMethodName(String method) {
    switch (method.toLowerCase()) {
      case 'ecocash':
        return 'EcoCash';
      case 'onemoney':
        return 'OneMoney';
      case 'web':
        return 'Paynow Web';
      default:
        return method;
    }
  }
}
