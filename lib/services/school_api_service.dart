// lib/services/school_api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

class SchoolApiService {
  static const String baseUrl =
      'http://192.168.9.103:8000/api'; // Update with your Laravel URL

  /// Register a new school online
  static Future<Map<String, dynamic>> registerSchool({
    required String schoolName,
    required String schoolEmail,
    required String schoolPhone,
    required String schoolAddress,
    required String schoolCity,
    required String schoolCountry,
    String? schoolWebsite,
    required String startTime,
    required String endTime,
    required List<String> operatingDays,
    required String adminFirstName,
    required String adminLastName,
    required String adminEmail,
    required String adminPassword,
    required String adminPhone,
  }) async {
    try {
      print('🌐 Registering school online: $schoolName');

      final response = await http.post(
        Uri.parse('$baseUrl/schools/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'name': schoolName,
          'email': schoolEmail,
          'phone': schoolPhone,
          'address': schoolAddress,
          'city': schoolCity,
          'country': schoolCountry,
          'website': schoolWebsite,
          'start_time': startTime,
          'end_time': endTime,
          'operating_days': operatingDays,
          'admin_first_name': adminFirstName,
          'admin_last_name': adminLastName,
          'admin_email': adminEmail,
          'admin_password': adminPassword,
          'admin_password_confirmation': adminPassword,
          'admin_phone': adminPhone,
        }),
      );

      print('📡 Registration response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          print('✅ School registered successfully online');

          // Store the API token using your existing ApiService method
          final token = data['data']['token'];
          ApiService.setToken(token);

          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Registration failed');
        }
      } else {
        final error = json.decode(response.body);
        print('❌ Registration failed: ${error['message']}');
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      print('❌ School registration error: $e');
      throw Exception('Failed to register school: $e');
    }
  }

  /// Find school by name or invitation code
  static Future<Map<String, dynamic>> findSchool(String identifier) async {
    try {
      print('🔍 Looking up school: $identifier');

      final response = await http.post(
        Uri.parse('$baseUrl/schools/find'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'identifier': identifier,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          print('✅ School found: ${data['data']['name']}');
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'School not found');
        }
      } else if (response.statusCode == 404) {
        throw Exception('No school found with that name or code');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to find school');
      }
    } catch (e) {
      print('❌ School lookup error: $e');
      rethrow;
    }
  }

  /// Authenticate user for a specific school
  static Future<Map<String, dynamic>> authenticateSchoolUser({
    required String schoolIdentifier,
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Authenticating user for school: $schoolIdentifier');
      print('📧 User email: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/schools/authenticate'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'school_identifier': schoolIdentifier,
          'email': email,
          'password': password,
        }),
      );

      print('📡 Auth response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          print('✅ Authentication successful');

          // Store the API token using your existing ApiService method
          final token = data['data']['token'];
          ApiService.setToken(token);

          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Authentication failed');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Invalid email or password for this school');
      } else if (response.statusCode == 404) {
        throw Exception('School not found or inactive');
      } else if (response.statusCode == 403) {
        throw Exception('School subscription has expired');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Authentication failed');
      }
    } catch (e) {
      print('❌ School authentication error: $e');
      rethrow;
    }
  }

  /// Get school dashboard data
  static Future<Map<String, dynamic>> getSchoolDashboard() async {
    try {
      // Use the existing ApiService headers which include the token
      final response = await http.get(
        Uri.parse('$baseUrl/schools/dashboard'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to load dashboard');
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to load dashboard');
      }
    } catch (e) {
      print('❌ Dashboard error: $e');
      rethrow;
    }
  }

  /// Update school settings
  static Future<Map<String, dynamic>> updateSchoolSettings(
      Map<String, dynamic> settings) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/schools/settings'),
        headers: _getHeaders(),
        body: json.encode(settings),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to update settings');
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update settings');
      }
    } catch (e) {
      print('❌ Settings update error: $e');
      rethrow;
    }
  }

  /// Check if online (test connectivity)
  static Future<bool> isOnline() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('🔌 Offline - API not reachable: $e');
      return false;
    }
  }

  /// Get API status and version
  static Future<Map<String, dynamic>> getApiStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('API not responding');
      }
    } catch (e) {
      throw Exception('Failed to check API status: $e');
    }
  }

  /// Private helper to get headers with token (mimics ApiService._headers)
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Note: The token is automatically included by using ApiService.setToken()
      // which your existing ApiService handles in its _headers getter
    };
  }
}
