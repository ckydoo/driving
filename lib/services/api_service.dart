// Enhanced API Service - Production Ready Multi-Device Sync Support

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static String? _token;
  static String baseUrl = 'https://driving.fonpos.co.zw/api';

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

  /// Register a new device with the server
  static Future<void> registerDevice({
    required String schoolId,
    required String deviceId,
  }) async {
    return _withRetry(() async {
      print('📱 Registering device: $deviceId for school: $schoolId');

      final response = await _makeRequest(
        'POST',
        '/sync/register-device',
        body: {
          'school_id': schoolId, // Added this - your server needs it
          'device_id': deviceId,
          'platform': Platform.operatingSystem,
          'app_version': '1.0.0', // Get from package_info if available
        },
        timeout: sendTimeout,
      );

      _handleResponse(response);
      print('✅ Device registered successfully');
    });
  }

  /// Download all data for a school (first-time setup)
  static Future<Map<String, dynamic>> downloadAllSchoolData({
    required String schoolId,
  }) async {
    return _withRetry(() async {
      print('⬇️ Downloading all data for school: $schoolId');

      final response = await _makeRequest(
        'GET',
        '/sync/download-all',
        queryParams: {'school_id': schoolId},
        timeout: receiveTimeout, // Longer timeout for large data
      );

      final data = _handleResponse(response);
      final result = data['data'] ?? {};

      print('✅ Downloaded school data:');
      _logDataCounts(result);

      return result;
    });
  }

  /// Download incremental changes since last sync
  static Future<Map<String, dynamic>> downloadIncrementalChanges({
    required String schoolId,
    DateTime? since,
  }) async {
    return _withRetry(() async {
      print('⚡ Downloading incremental changes for school: $schoolId');
      if (since != null) {
        print('📅 Since: ${since.toIso8601String()}');
      }

      final queryParams = {'school_id': schoolId};
      if (since != null) {
        queryParams['since'] = since.toIso8601String();
      }

      final response = await _makeRequest(
        'GET',
        '/sync/download-incremental',
        queryParams: queryParams,
        timeout: receiveTimeout,
      );

      final data = _handleResponse(response);
      final result = data['data'] ?? {};

      print('✅ Downloaded incremental changes:');
      _logDataCounts(result);

      return result;
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

  /// Upload changes to server
  static Future<Map<String, dynamic>> uploadChanges({
    required String schoolId,
    required Map<String, dynamic> changes,
  }) async {
    return _withRetry(() async {
      print('📤 Uploading changes for school: $schoolId');

      final response = await _makeRequest(
        'POST',
        '/sync/upload',
        body: {
          'school_id': schoolId,
          'changes': changes,
        },
        timeout: sendTimeout,
      );

      final data = _handleResponse(response);
      final result = data['data'] ?? {};

      print('✅ Upload result: ${result['uploaded'] ?? 0} items uploaded');
      if (result['errors'] != null && (result['errors'] as List).isNotEmpty) {
        print(
            '⚠️ Upload warnings: ${(result['errors'] as List).length} errors');
      }

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
        throw ApiException('Invalid changes format', 400, {'changes': changes});
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

  /// Handle HTTP response with proper error checking
  static Map<String, dynamic> _handleResponse(http.Response response) {
    print('🔍 Response Status: ${response.statusCode}');
    print('🔍 Response Body: ${response.body}');

    try {
      final data = json.decode(response.body) as Map<String, dynamic>;

      // ✅ FIX: Handle successful status codes (200-299)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Check if server explicitly marked as success
        final serverSuccess = data['success'] ?? false;
        final uploaded = data['data']?['uploaded'] ?? 0;
        final errors = data['data']?['errors'] ?? [];

        // ✅ FIXED: Consider upload successful if:
        // 1. Server says success=true, OR
        // 2. Server uploaded > 0 items, OR
        // 3. Server has no errors and reasonable response
        final actuallySuccessful = serverSuccess ||
            uploaded > 0 ||
            (errors.isEmpty && data.containsKey('data'));

        if (actuallySuccessful) {
          // Override success flag if server got it wrong
          data['success'] = true;
          print('✅ Response processed successfully');
          return data;
        } else {
          // Server returned 200 but with actual errors
          final errorMessage = data['message'] ?? 'Server processing failed';
          print('⚠️ Server returned 200 but failed processing: $errorMessage');
          throw ApiException(errorMessage, response.statusCode, data);
        }
      } else {
        // Handle error status codes (400+)
        final errorMessage = data['message'] ?? 'Server error occurred';
        print('❌ Server error ${response.statusCode}: $errorMessage');
        throw ApiException(errorMessage, response.statusCode, data);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      print('❌ Failed to parse response: $e');
      throw ApiException('Invalid server response format', response.statusCode,
          {'raw_body': response.body});
    }
  }

  /// Retry mechanism for failed requests
  static Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt < maxRetries) {
      try {
        attempt++;
        if (attempt > 1) {
          print('🔄 Retry attempt $attempt/$maxRetries');
        }

        return await operation();
      } on SocketException catch (e) {
        lastException = e;
        print('❌ Network error (attempt $attempt): ${e.message}');

        if (attempt < maxRetries) {
          print('⏳ Retrying in ${retryDelay.inSeconds}s...');
          await Future.delayed(retryDelay);
        }
      } on TimeoutException catch (e) {
        lastException = e;
        print('❌ Timeout error (attempt $attempt): ${e.message}');

        if (attempt < maxRetries) {
          print('⏳ Retrying in ${retryDelay.inSeconds}s...');
          await Future.delayed(retryDelay);
        }
      } on Exception catch (e) {
        // Don't retry for authentication/permission errors or client errors
        if (e.toString().contains('Authentication') ||
            e.toString().contains('Access forbidden') ||
            e.toString().contains('Invalid JSON')) {
          throw e;
        }

        lastException = e;
        print('❌ Request error (attempt $attempt): $e');

        if (attempt < maxRetries) {
          print('⏳ Retrying in ${retryDelay.inSeconds}s...');
          await Future.delayed(retryDelay);
        }
      }
    }

    print('💥 All $maxRetries attempts failed');
    throw lastException ??
        Exception('Request failed after $maxRetries attempts');
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
}

// ✅ Custom exception for better error handling
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic> data;

  ApiException(this.message, this.statusCode, this.data);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
