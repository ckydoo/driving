// Enhanced API Service - Production Ready Multi-Device Sync Support

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

class ApiService {
  static String? _token;
  static String baseUrl = 'https://drivesyncpro.co.zw/api';

  /// Check if we have a valid token
  static bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Get current token (for debugging)
  static String? get currentToken => _token;

  // Enhanced timeout settings for production
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout =
      Duration(seconds: 120); // Longer for large data
  static const Duration sendTimeout = Duration(seconds: 60);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  static void configure({required String baseUrl}) {
    ApiService.baseUrl = baseUrl;
    print('🔧 API Service configured: $baseUrl');
  }

  static void setToken(String token) {
    _token = token;
  }

  static void clearToken() {
    _token = null;
  }

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  // ===================================================================
  // PRODUCTION SYNC ENDPOINTS
  // ===================================================================

  /// Get comprehensive sync state for a school and device
  static Future<Map<String, dynamic>> getSchoolSyncState({
    required String schoolId,
    required String deviceId,
  }) async {
    return _withRetry(() async {
      print('🏫 Getting sync state for school: $schoolId, device: $deviceId');

      final response = await _makeRequest(
        'GET',
        '/sync/school-state',
        queryParams: {
          'school_id': schoolId,
          'device_id': deviceId,
        },
        timeout: connectTimeout,
      );

      final data = _handleResponse(response);
      return data['data'] ?? {};
    });
  }

  /// Download specific table data
  static Future<List<dynamic>> downloadTableData({
    required String schoolId,
    required String table,
  }) async {
    return _withRetry(() async {
      print('📊 Downloading table data: $table for school: $schoolId');

      final response = await _makeRequest(
        'GET',
        '/sync/download-table',
        queryParams: {
          'school_id': schoolId,
          'table': table,
        },
        timeout: receiveTimeout,
      );

      final data = _handleResponse(response);
      final result = data['data'] ?? [];

      print('✅ Downloaded $table: ${result.length} records');
      return result;
    });
  }

  /// Get sync status/statistics
  static Future<Map<String, dynamic>> getSyncStatus({
    required String schoolId,
  }) async {
    return _withRetry(() async {
      print('📊 Getting sync status for school: $schoolId');

      final response = await _makeRequest(
        'GET',
        '/sync/status',
        queryParams: {'school_id': schoolId},
        timeout: connectTimeout,
      );

      final data = _handleResponse(response);
      return data['data'] ?? {};
    });
  }

  // ===================================================================
  // LEGACY SYNC METHODS (for backward compatibility)
  // ===================================================================

  /// Legacy sync download method
  static Future<Map<String, dynamic>> syncDownload({String? lastSync}) async {
    return _withRetry(() async {
      print('🔍 Making legacy sync download request...');

      final headers = Map<String, String>.from(_headers);
      if (lastSync != null && lastSync.isNotEmpty && lastSync != 'Never') {
        headers['Last-Sync'] = lastSync;
        print('🔍 Last-Sync: $lastSync');
      }

      final response = await _makeRequest(
        'GET',
        '/sync/download',
        headers: headers,
        timeout: receiveTimeout,
      );

      final data = _handleResponse(response);
      return data['data'] ?? {};
    });
  }

  /// Fixed legacy sync upload method
  static Future<Map<String, dynamic>> syncUpload(dynamic changes) async {
    return _withRetry(() async {
      print('📤 Making legacy sync upload request...');
      print('🔍 Changes type: ${changes.runtimeType}');
      print(
          '🔍 Changes content: ${changes.toString().length > 200 ? changes.toString().substring(0, 200) + "..." : changes}');

      // ✅ FIX: Handle both Map and List format changes
      dynamic formattedChanges;

      if (changes is Map<String, dynamic>) {
        // Convert Map format to List format for server compatibility
        formattedChanges = _convertMapFormatToListFormat(changes);
        print(
            '🔄 Converted Map format to List format: ${formattedChanges.length} items');
      } else if (changes is List) {
        formattedChanges = changes;
        print('📋 Using List format: ${changes.length} items');
      } else {
        throw ApiException(400, 'Invalid changes format');
      }

      final response = await _makeRequest(
        'POST',
        '/sync/upload',
        body: {'changes': formattedChanges},
        timeout: sendTimeout,
      );

      final data = _handleResponse(response);

      // ✅ FIX: Return consistent format
      return {
        'success': data['success'] ?? false,
        'uploaded': data['data']?['uploaded'] ?? 0,
        'errors': data['data']?['errors'] ?? [],
        'message': data['message'] ?? 'Upload completed',
        'partial': data['data']?['partial'] ?? false,
        'timestamp': data['data']?['timestamp'],
      };
    });
  }

  /// Helper method to convert Map format to List format
  static List<Map<String, dynamic>> _convertMapFormatToListFormat(
      Map<String, dynamic> mapFormat) {
    final List<Map<String, dynamic>> listFormat = [];

    for (final entry in mapFormat.entries) {
      final table = entry.key;
      final items = entry.value as List<dynamic>;

      for (final item in items) {
        listFormat.add({
          'table': table,
          'operation': item['operation'] ?? 'upsert',
          'data': item['data'] ?? item,
          'id': item['data']?['id'] ?? item['id'],
        });
      }
    }

    return listFormat;
  }

  // ===================================================================
  // HTTP CLIENT HELPER METHODS
  // ===================================================================

  /// Make HTTP request with proper error handling
  static Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final finalUri =
        queryParams != null ? uri.replace(queryParameters: queryParams) : uri;

    final finalHeaders = {
      ..._headers,
      if (headers != null) ...headers,
    };

    final client = http.Client();

    try {
      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await client.get(finalUri, headers: finalHeaders).timeout(
            timeout ?? receiveTimeout,
            onTimeout: () {
              throw TimeoutException(
                'GET request timed out after ${(timeout ?? receiveTimeout).inSeconds}s',
                timeout ?? receiveTimeout,
              );
            },
          );
          break;
        case 'POST':
          response = await client
              .post(
            finalUri,
            headers: finalHeaders,
            body: body != null ? json.encode(body) : null,
          )
              .timeout(
            timeout ?? sendTimeout,
            onTimeout: () {
              throw TimeoutException(
                'POST request timed out after ${(timeout ?? sendTimeout).inSeconds}s',
                timeout ?? sendTimeout,
              );
            },
          );
          break;
        case 'PUT':
          response = await client
              .put(
            finalUri,
            headers: finalHeaders,
            body: body != null ? json.encode(body) : null,
          )
              .timeout(
            timeout ?? sendTimeout,
            onTimeout: () {
              throw TimeoutException(
                'PUT request timed out after ${(timeout ?? sendTimeout).inSeconds}s',
                timeout ?? sendTimeout,
              );
            },
          );
          break;
        case 'DELETE':
          response =
              await client.delete(finalUri, headers: finalHeaders).timeout(
            timeout ?? connectTimeout,
            onTimeout: () {
              throw TimeoutException(
                'DELETE request timed out after ${(timeout ?? connectTimeout).inSeconds}s',
                timeout ?? connectTimeout,
              );
            },
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      return response;
    } finally {
      client.close();
    }
  }

  /// Log data counts for debugging
  static void _logDataCounts(Map<String, dynamic> data) {
    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet'
    ];
    for (final table in tables) {
      if (data[table] != null && data[table] is List) {
        final count = (data[table] as List).length;
        print('   $table: $count records');
      }
    }
  }

  // ===================================================================
  // CONNECTIVITY AND HEALTH CHECKS
  // ===================================================================

  /// Test server connectivity
  static Future<bool> testServerConnection() async {
    try {
      print('🏥 Testing server connectivity...');

      final response = await _makeRequest(
        'GET',
        '/health',
        timeout: Duration(seconds: 10),
      );

      print('✅ Server is reachable and healthy');
      return true;
    } catch (e) {
      print('❌ Server connectivity test failed: $e');
      return false;
    }
  }

  /// Check internet connectivity
  static Future<bool> isOnline() async {
    try {
      print('🔍 Checking internet connectivity...');

      // Test 1: DNS lookup
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(Duration(seconds: 5));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          print('✅ Internet connection confirmed (DNS)');
          return true;
        }
      } catch (e) {
        print('⚠️ DNS lookup failed: $e');
      }

      // Test 2: HTTP request
      try {
        final client = http.Client();
        final response = await client
            .get(Uri.parse('https://www.google.com'))
            .timeout(Duration(seconds: 8));
        client.close();

        if (response.statusCode == 200) {
          print('✅ Internet connection confirmed (HTTP)');
          return true;
        }
      } catch (e) {
        print('⚠️ HTTP connectivity test failed: $e');
      }

      print('❌ No internet connection detected');
      return false;
    } catch (e) {
      print('❌ Connectivity check error: $e');
      return false;
    }
  }

  // ===================================================================
  // AUTHENTICATION METHODS
  // ===================================================================

  /// User authentication
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    return _withRetry(() async {
      final response = await _makeRequest(
        'POST',
        '/auth/login',
        body: {
          'email': email,
          'password': password,
        },
        timeout: connectTimeout,
      );

      final data = _handleResponse(response);

      // Store the token
      if (data['data']?['token'] != null) {
        setToken(data['data']['token']);
      }

      return data['data'] ?? {};
    });
  }

  /// Enhanced error handling for responses
  static Map<String, dynamic> _handleResponse(http.Response response) {
    developer.log('Response received: ${response.statusCode}', name: 'ApiService');

    if (response.statusCode == 401) {
      // Token is invalid/expired
      developer.log('Authentication failed', name: 'ApiService', level: 1000);
      clearToken(); // Clear the invalid token
      throw ApiException(401, 'Your session has expired. Please sign in again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return json.decode(response.body);
      } catch (e) {
        developer.log('JSON decode error', error: e, name: 'ApiService', level: 1000);
        throw ApiException(response.statusCode, 'Received invalid data from server');
      }
    }

    // Handle other HTTP errors
    String errorMessage = _getDefaultErrorMessage(response.statusCode);

    try {
      final errorData = json.decode(response.body);
      errorMessage = errorData['message'] ?? errorMessage;
    } catch (e) {
      developer.log('Could not parse error response', error: e, name: 'ApiService');
    }

    developer.log('Server error: $errorMessage', name: 'ApiService', level: 1000);
    throw ApiException(response.statusCode, errorMessage);
  }

  /// Get user-friendly error message based on status code
  static String _getDefaultErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 422:
        return 'Validation failed. Please check your input.';
      case 500:
        return 'A server error occurred. Please try again later.';
      case 503:
        return 'Service temporarily unavailable. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  /// Enhanced retry mechanism with better error handling
  static Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      attempts++;

      try {
        developer.log('Request attempt $attempts/$maxRetries', name: 'ApiService');
        return await operation();
      } catch (e) {
        developer.log('Request failed (attempt $attempts)', error: e, name: 'ApiService');

        // Don't retry on authentication errors
        if (e is ApiException && e.statusCode == 401) {
          developer.log('Not retrying authentication error', name: 'ApiService');
          rethrow;
        }

        // Don't retry client errors (4xx except 401)
        if (e is ApiException && e.statusCode >= 400 && e.statusCode < 500) {
          developer.log('Not retrying client error', name: 'ApiService');
          rethrow;
        }

        // Don't retry on the last attempt
        if (attempts >= maxRetries) {
          developer.log('All retry attempts exhausted', name: 'ApiService', level: 1000);
          rethrow;
        }

        // Wait before retrying
        developer.log('Retrying in ${retryDelay.inSeconds}s...', name: 'ApiService');
        await Future.delayed(retryDelay);
      }
    }

    throw Exception('All retry attempts failed');
  }

  /// User logout
  static Future<void> logout() async {
    try {
      await _makeRequest('POST', '/auth/logout', timeout: connectTimeout);
    } catch (e) {
      print('⚠️ Logout request failed (continuing anyway): $e');
    } finally {
      clearToken();
    }
  }

// 1. Download All (Points to ProductionSyncController@downloadAllSchoolData)
  static Future<Map<String, dynamic>> downloadAllSchoolData(
      {required String schoolId}) async {
    // FIXED: Remove 'production' from URL
    final response = await http.get(
      Uri.parse('$baseUrl/sync/download-all?school_id=$schoolId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('❌ Download failed: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to download school data: ${response.statusCode}');
    }
  }

// 2. Incremental (Points to ProductionSyncController@downloadIncrementalChanges)
  static Future<Map<String, dynamic>> downloadIncrementalChanges(
      {required String schoolId, DateTime? since}) async {
    // FIXED: Remove 'production' from URL
    String url = '$baseUrl/sync/download-incremental?school_id=$schoolId';
    if (since != null) {
      url += '&since=${since.toIso8601String()}';
    }

    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('❌ Incremental download failed: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to download changes');
    }
  }

// 3. Upload Changes (Points to ProductionSyncController@uploadChanges)
  static Future<Map<String, dynamic>> uploadChanges(
      List<Map<String, dynamic>> groupedChanges) async {
    // FIXED: Remove 'production' from URL
    final response = await http.post(
      Uri.parse('$baseUrl/sync/upload-changes'),
      headers: _headers,
      body: json.encode({'changes': groupedChanges}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('❌ Upload failed: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Upload failed: ${response.body}');
    }
  }

// 4. Register Device
  static Future<void> registerDevice(
      {required String schoolId, required String deviceId}) async {
    // FIXED: Remove 'production' from URL
    await http.post(
      Uri.parse('$baseUrl/sync/register-device'),
      headers: _headers,
      body: json.encode({
        'school_id': schoolId,
        'device_id': deviceId,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      }),
    );
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
