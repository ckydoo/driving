// lib/services/school_api_service.dart - ENHANCED WITH DETAILED ERROR LOGGING

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

class SchoolApiService {
  static const String baseUrl = 'https://driving.fonpos.co.zw/api';

  /// Register a new school online with enhanced error handling
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
      print('🌐 === SCHOOL REGISTRATION DEBUG ===');
      print('School Name: $schoolName');
      print('Admin Email: $adminEmail');
      print('Admin Password Length: ${adminPassword.length}');
      print('API URL: $baseUrl/schools/register');

      final requestData = {
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
        'admin_fname': adminFirstName,
        'admin_lname': adminLastName,
        'admin_email': adminEmail,
        'admin_password': adminPassword,
        'admin_password_confirmation': adminPassword,
        'admin_phone': adminPhone,
      };

      print('📤 Request Data: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse('$baseUrl/schools/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('📡 Registration response status: ${response.statusCode}');
      print('📡 Response headers: ${response.headers}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          print('✅ School registered successfully online');

          // Store the API token if provided
          if (data['data']['token'] != null) {
            final token = data['data']['token'];
            ApiService.setToken(token);
            print('🔑 API token stored');
          }

          return data['data'];
        } else {
          print('❌ Registration failed - Success flag false');
          print('❌ Error message: ${data['message']}');
          throw Exception(data['message'] ?? 'Registration failed');
        }
      } else {
        // Handle different HTTP error codes
        String errorMessage = 'Registration failed';

        try {
          final error = json.decode(response.body);
          errorMessage = error['message'] ?? errorMessage;

          // Log validation errors if present
          if (error['errors'] != null) {
            print('❌ Validation Errors:');
            final errors = error['errors'] as Map<String, dynamic>;
            errors.forEach((field, messages) {
              print('   $field: ${messages.join(', ')}');
            });
          }

          // Log exception details if present
          if (error['exception'] != null) {
            print('❌ Server Exception: ${error['exception']}');
          }

          // Log trace if present (for debugging)
          if (error['trace'] != null) {
            print('❌ Server Trace: ${error['trace']}');
          }
        } catch (e) {
          print('❌ Failed to parse error response: $e');
          errorMessage = 'Server returned status ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ School registration error: $e');
      throw Exception('Failed to register school: $e');
    }
  }

  /// Test API connection
  static Future<bool> testApiConnection() async {
    try {
      print('🔍 Testing API connection to $baseUrl');

      final response = await http.get(
        Uri.parse('$baseUrl/test'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📡 API test response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      print('❌ API connection test failed: $e');
      return false;
    }
  }

  /// Check if online with better error detection
  static Future<bool> isOnline() async {
    try {
      // First test basic connectivity
      final response = await http.get(
        Uri.parse('https://8.8.8.8'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));

      // Then test our API specifically
      if (response.statusCode == 200) {
        return await testApiConnection();
      }

      return false;
    } catch (e) {
      print('❌ Internet connectivity check failed: $e');
      return false;
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

      print('📡 School lookup response: ${response.statusCode}');

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
        try {
          final error = json.decode(response.body);
          throw Exception(error['message'] ?? 'Failed to find school');
        } catch (e) {
          throw Exception('Server returned status ${response.statusCode}');
        }
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
      print('🔐 === SCHOOL AUTH DEBUG ===');
      print('School: $schoolIdentifier');
      print('Email: $email');
      print('Password Length: ${password.length}');

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
      print('📡 Auth response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          print('✅ Authentication successful');

          // Store the API token
          if (data['data']['token'] != null) {
            final token = data['data']['token'];
            ApiService.setToken(token);
          }

          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Authentication failed');
        }
      } else {
        try {
          final error = json.decode(response.body);
          print('❌ Auth error details: ${error}');
          throw Exception(error['message'] ?? 'Authentication failed');
        } catch (e) {
          throw Exception(
              'Authentication failed - Server error ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ Authentication error: $e');
      rethrow;
    }
  }
}
