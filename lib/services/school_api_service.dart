import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

class SchoolApiService {
  static const String baseUrl = 'https://drivesyncpro.co.zw/api';

  /// Convert technical error messages to user-friendly messages
  static String _getUserFriendlyError(String errorMessage) {
    // Duplicate entry errors
    if (errorMessage.contains('Duplicate entry') &&
        errorMessage.contains('email')) {
      return 'This email address is already registered. Please use a different email or try logging in.';
    }
    if (errorMessage.contains('Duplicate entry') &&
        errorMessage.contains('phone')) {
      return 'This phone number is already registered. Please use a different phone number or leave it blank.';
    }
    if (errorMessage.contains('users_phone_unique')) {
      return 'This phone number is already in use. Please use a different phone number or leave it blank.';
    }
    if (errorMessage.contains('Duplicate entry') &&
        errorMessage.contains('name')) {
      return 'A school with this name already exists. Please use a different name.';
    }

    // Validation errors
    if (errorMessage.contains('validation') ||
        errorMessage.contains('Validation')) {
      return 'Please check your information and try again. Make sure all required fields are filled correctly.';
    }

    // Password errors
    if (errorMessage.contains('password')) {
      return 'Invalid password. Password must be at least 8 characters long.';
    }

    // Authentication errors
    if (errorMessage.contains('Unauthorized') || errorMessage.contains('401')) {
      return 'Invalid email or password. Please try again.';
    }

    // Network errors
    if (errorMessage.contains('SocketException') ||
        errorMessage.contains('Failed host lookup')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (errorMessage.contains('TimeoutException') ||
        errorMessage.contains('timeout')) {
      return 'Connection timeout. Please check your internet connection and try again.';
    }

    // Server errors
    if (errorMessage.contains('500') ||
        errorMessage.contains('Internal Server Error')) {
      return 'Server error. Please try again later or contact support.';
    }
    if (errorMessage.contains('503') ||
        errorMessage.contains('Service Unavailable')) {
      return 'Service temporarily unavailable. Please try again later.';
    }

    // Default fallback
    return 'Registration failed. Please try again or contact support if the problem persists.';
  }

  /// Register a new school online with enhanced error handling
  static Future<Map<String, dynamic>> registerSchool({
    required String schoolName,
    required String schoolEmail,
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
        'password': adminPassword, // Use admin password as school password
        'password_confirmation': adminPassword,
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
        'admin_phone':
            (adminPhone.isEmpty || adminPhone == 'N/A') ? null : adminPhone,
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

          // ✅ Extract and format validation errors for user display
          if (error['errors'] != null) {
            print('❌ Validation Errors:');
            final errors = error['errors'] as Map<String, dynamic>;

            // Build simple error message from validation errors
            List<String> errorMessages = [];
            errors.forEach((field, messages) {
              if (messages is List && messages.isNotEmpty) {
                // Get the first error message for this field
                String message = messages[0].toString();
                errorMessages.add(message);
                print('   $field: ${messages.join(', ')}');
              }
            });

            // If we have validation errors, use them instead of generic message
            if (errorMessages.isNotEmpty) {
              // Join multiple errors with line breaks
              errorMessage = errorMessages.join('\n');
            }
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

        // Throw error with specific validation messages
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ School registration error: $e');

      // If it's already an Exception with validation errors, just rethrow it
      if (e is Exception &&
          (e.toString().contains('already been taken') ||
           e.toString().contains('required') ||
           e.toString().contains('invalid'))) {
        rethrow;
      }

      // Otherwise, return user-friendly error message
      final errorMessage = e.toString();
      throw Exception(_getUserFriendlyError(errorMessage));
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

  /// Fetch business settings from server
  static Future<Map<String, dynamic>> getBusinessSettings(
      String schoolId) async {
    try {
      print('🏢 Fetching business settings for school: $schoolId');

      // Get the API token
      final token = ApiService.currentToken;
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated. Please login first.');
      }

      // FIXED: Use correct endpoint with school ID in path
      final response = await http.get(
        Uri.parse('$baseUrl/schools/$schoolId/settings'), // Fixed URL
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Business settings response status: ${response.statusCode}');
      print('📡 Business settings response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          print('✅ Business settings fetched successfully');
          return data['data'];
        } else {
          throw Exception(
              data['message'] ?? 'Failed to fetch business settings');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (response.statusCode == 403) {
        // FIXED: Handle unauthorized access specifically
        final data = json.decode(response.body);
        throw Exception(data['message'] ??
            'You don\'t have permission to access these settings.');
      } else if (response.statusCode == 404) {
        throw Exception('School not found on server.');
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(
              error['message'] ?? 'Failed to fetch business settings');
        } catch (e) {
          throw Exception(
              'Server returned status ${response.statusCode}. Please try again later.');
        }
      }
    } catch (e) {
      print('❌ Business settings fetch error: $e');
      rethrow;
    }
  }
}
