// lib/services/api_service.dart - CORRECTED VERSION

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:driving/models/user.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/models/fleet.dart';

class ApiService {
  static String? _token;
  static String baseUrl = 'http://192.168.9.103:8000/api'; // CHANGE THIS

  static void configure({required String baseUrl}) {
    ApiService.baseUrl = baseUrl;
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

  // Sync-specific methods

  static Future<Map<String, dynamic>> syncDownload({String? lastSync}) async {
    print('🔍 Making sync download request...');
    print('🔍 URL: $baseUrl/sync/download');

    // Build headers - only include Last-Sync if we have a valid timestamp
    final headers = Map<String, String>.from(_headers);

    // Only add Last-Sync header if lastSync is not null and not "Never"
    if (lastSync != null && lastSync.isNotEmpty && lastSync != 'Never') {
      headers['Last-Sync'] = lastSync;
      print('🔍 Last-Sync: $lastSync');
    } else {
      print('🔍 No Last-Sync header (first sync)');
    }

    print('🔍 Headers: $headers');

    final response = await http.get(
      Uri.parse('$baseUrl/sync/download'),
      headers: headers,
    );

    print('🔍 Response Status: ${response.statusCode}');
    print('🔍 Response Body: ${response.body}');

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      print('✅ Sync download successful');
      return data['data'];
    } else {
      print('❌ Sync download failed');
      print('❌ Error details: ${data['message']}');
      if (data.containsKey('data') && data['data'] != null) {
        print('❌ Additional error info: ${data['data']}');
      }
      throw Exception(data['message'] ?? 'Sync download failed');
    }
  }

  // Updated syncUpload method in lib/services/api_service.dart
  static Future<Map<String, dynamic>> syncUpload(
      Map<String, dynamic> changes) async {
    print('🔍 Making sync upload request...');
    print('🔍 URL: $baseUrl/sync/upload');
    print('🔍 Changes to upload: ${json.encode(changes)}');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/upload'),
        headers: _headers,
        body: json.encode(changes),
      );

      print('🔍 Upload Response Status: ${response.statusCode}');
      print('🔍 Upload Response Body: ${response.body}');

      final data = json.decode(response.body);

      // Handle different response scenarios more strictly
      if (response.statusCode == 200 && data['success']) {
        // Complete success - verify no errors exist
        final errors = data['data']['errors'] ?? [];
        final uploaded = data['data']['uploaded'] ?? 0;

        if (errors.isEmpty) {
          print('✅ Upload completed successfully with no errors');
          return {
            'success': true,
            'uploaded': uploaded,
            'errors': [],
            'message': 'Upload completed successfully'
          };
        } else {
          // Server returned success but with errors - treat as partial success
          print(
              '⚠️ Server returned success but with errors - treating as partial success');
          return {
            'success': true,
            'uploaded': uploaded,
            'errors': errors,
            'message': 'Upload completed with some errors'
          };
        }
      } else if (response.statusCode == 422 && !data['success']) {
        // Partial success - some items uploaded, some failed
        final uploaded = data['data']['uploaded'] ?? 0;
        final errors = data['data']['errors'] ?? [];

        print(
            '⚠️ Upload partially successful: $uploaded uploaded, ${errors.length} errors');

        // ✅ BE MORE STRICT ABOUT WHAT COUNTS AS SUCCESS
        if (uploaded > 0) {
          return {
            'success': true, // Consider it success if something was uploaded
            'uploaded': uploaded,
            'errors': errors,
            'message':
                'Upload partially completed: $uploaded items uploaded, ${errors.length} failed'
          };
        } else {
          return {
            'success': false, // No items uploaded - complete failure
            'uploaded': 0,
            'errors': errors,
            'message': 'Upload failed: no items were processed successfully'
          };
        }
      } else if (response.statusCode == 401) {
        print('❌ Authentication failed');
        throw Exception('Authentication failed - please login again');
      } else if (response.statusCode == 403) {
        print('❌ Access forbidden');
        throw Exception('Access forbidden - insufficient permissions');
      } else if (response.statusCode >= 500) {
        print('❌ Server error: ${response.statusCode}');
        throw Exception(
            'Server error: ${data['message'] ?? 'Internal server error'}');
      } else {
        // Other errors
        print('❌ Upload failed with status: ${response.statusCode}');
        final errorMessage = data['message'] ??
            'Upload failed with status ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('❌ Network error - no internet connection');
      throw Exception('No internet connection');
    } on TimeoutException {
      print('❌ Request timeout');
      throw Exception('Request timeout - please try again');
    } on FormatException {
      print('❌ Invalid response format');
      throw Exception('Invalid server response');
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }

  // Authentication
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      // Store the token
      setToken(data['data']['token']);
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
      );
    } catch (e) {
      print('Logout API call failed: $e');
    } finally {
      clearToken();
    }
  }

  // Users
  static Future<List<User>> getUsers({String? role, String? status}) async {
    final uri = Uri.parse('$baseUrl/users').replace(queryParameters: {
      if (role != null) 'role': role,
      if (status != null) 'status': status,
    });

    final response = await http.get(uri, headers: _headers);
    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return (data['data'] as List)
          .map((json) => User.fromJson(_convertUserApiToLocal(json)))
          .toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch users');
    }
  }

  static Future<User> createUser(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: _headers,
      body: json.encode(_convertUserLocalToApi(userData)),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return User.fromJson(_convertUserApiToLocal(data['data']));
    } else {
      throw Exception(data['message'] ?? 'Failed to create user');
    }
  }

  static Future<User> updateUser(int id, Map<String, dynamic> userData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$id'),
      headers: _headers,
      body: json.encode(_convertUserLocalToApi(userData)),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return User.fromJson(_convertUserApiToLocal(data['data']));
    } else {
      throw Exception(data['message'] ?? 'Failed to update user');
    }
  }

  static Future<void> deleteUser(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$id'),
      headers: _headers,
    );

    final data = json.decode(response.body);

    if (response.statusCode != 200 || !data['success']) {
      throw Exception(data['message'] ?? 'Failed to delete user');
    }
  }

  // Schedules
  static Future<List<Schedule>> getSchedules({
    int? studentId,
    int? instructorId,
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    final uri = Uri.parse('$baseUrl/schedules').replace(queryParameters: {
      if (studentId != null) 'student_id': studentId.toString(),
      if (instructorId != null) 'instructor_id': instructorId.toString(),
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (status != null) 'status': status,
    });

    final response = await http.get(uri, headers: _headers);
    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return (data['data'] as List)
          .map((json) => Schedule.fromJson(_convertScheduleApiToLocal(json)))
          .toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch schedules');
    }
  }

  static Future<Schedule> createSchedule(
      Map<String, dynamic> scheduleData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/schedules'),
      headers: _headers,
      body: json.encode(_convertScheduleLocalToApi(scheduleData)),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return Schedule.fromJson(_convertScheduleApiToLocal(data['data']));
    } else {
      throw Exception(data['message'] ?? 'Failed to create schedule');
    }
  }

  static Future<Schedule> updateSchedule(
      int id, Map<String, dynamic> scheduleData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/schedules/$id'),
      headers: _headers,
      body: json.encode(_convertScheduleLocalToApi(scheduleData)),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return Schedule.fromJson(_convertScheduleApiToLocal(data['data']));
    } else {
      throw Exception(data['message'] ?? 'Failed to update schedule');
    }
  }

  // Courses
  static Future<List<Course>> getCourses() async {
    final response = await http.get(
      Uri.parse('$baseUrl/courses'),
      headers: _headers,
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return (data['data'] as List)
          .map((json) => Course.fromJson(_convertCourseApiToLocal(json)))
          .toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch courses');
    }
  }

  static Future<Course> createCourse(Map<String, dynamic> courseData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/courses'),
      headers: _headers,
      body: json.encode(courseData),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return Course.fromJson(_convertCourseApiToLocal(data['data']));
    } else {
      throw Exception(data['message'] ?? 'Failed to create course');
    }
  }

  // Fleet
  static Future<List<Fleet>> getFleet() async {
    final response = await http.get(
      Uri.parse('$baseUrl/fleet'),
      headers: _headers,
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return (data['data'] as List)
          .map((json) => Fleet.fromJson(_convertFleetApiToLocal(json)))
          .toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch fleet');
    }
  }

  static Future<Fleet> createFleet(Map<String, dynamic> fleetData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/fleet'),
      headers: _headers,
      body: json.encode(_convertFleetLocalToApi(fleetData)),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return Fleet.fromJson(_convertFleetApiToLocal(data['data']));
    } else {
      throw Exception(data['message'] ?? 'Failed to create fleet');
    }
  }

  // Invoices
  static Future<List<Invoice>> getInvoices({int? studentId}) async {
    final uri = Uri.parse('$baseUrl/invoices').replace(queryParameters: {
      if (studentId != null) 'student_id': studentId.toString(),
    });

    final response = await http.get(uri, headers: _headers);
    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return (data['data'] as List)
          .map((json) => Invoice.fromMap(_convertInvoiceApiToLocal(json)))
          .toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch invoices');
    }
  }

  static Future<Invoice> createInvoice(Map<String, dynamic> invoiceData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/invoices'),
      headers: _headers,
      body: json.encode(_convertInvoiceLocalToApi(invoiceData)),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return Invoice.fromMap(_convertInvoiceApiToLocal(data['data']));
    } else {
      throw Exception(data['message'] ?? 'Failed to create invoice');
    }
  }

  // Payments
  static Future<List<Payment>> getPayments(
      {int? studentId, int? invoiceId}) async {
    final uri = Uri.parse('$baseUrl/payments').replace(queryParameters: {
      if (studentId != null) 'student_id': studentId.toString(),
      if (invoiceId != null) 'invoiceId': invoiceId.toString(),
    });

    final response = await http.get(uri, headers: _headers);
    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return (data['data'] as List)
          .map((json) => Payment.fromJson(_convertPaymentApiToLocal(json)))
          .toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch payments');
    }
  }

  static Future<Payment> createPayment(Map<String, dynamic> paymentData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments'),
      headers: _headers,
      body: json.encode(_convertPaymentLocalToApi(paymentData)),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return Payment.fromJson(_convertPaymentApiToLocal(data['data']));
    } else {
      throw Exception(data['message'] ?? 'Failed to create payment');
    }
  }

  static Future<Map<String, dynamic>> getSyncStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/sync/status'),
      headers: _headers,
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get sync status');
    }
  }

  // Network connectivity check
  static Future<bool> checkConnectivity() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: _headers,
          )
          .timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ========================================
  // DATA CONVERSION METHODS
  // ========================================
  // These methods convert between API format and your local Flutter model format

  // User conversions
  static Map<String, dynamic> _convertUserApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'fname': apiData['fname'],
      'lname': apiData['lname'],
      'email': apiData['email'],
      'date_of_birth': apiData['date_of_birth'],
      'password': '', // Don't store password locally
      'role': apiData['role'],
      'status': apiData['status'],
      'created_at': apiData['created_at'],
      'gender': apiData['gender'],
      'phone': apiData['phone'],
      'address': apiData['address'],
      'idnumber': apiData['idnumber'],
    };
  }

  static Map<String, dynamic> _convertUserLocalToApi(
      Map<String, dynamic> localData) {
    return {
      'fname': localData['fname'],
      'lname': localData['lname'],
      'email': localData['email'],
      'date_of_birth': localData['date_of_birth'],
      'password': localData['password'],
      'role': localData['role'],
      'status': localData['status'],
      'gender': localData['gender'],
      'phone': localData['phone'],
      'address': localData['address'],
      'idnumber': localData['idnumber'],
    };
  }

  // Schedule conversions
  static Map<String, dynamic> _convertScheduleApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'start': apiData['start'],
      'end': apiData['end'],
      'course': apiData['course_id'],
      'student': apiData['student_id'],
      'instructor': apiData['instructor_id'],
      'car': apiData['car_id'],
      'class_type': apiData['class_type'],
      'status': apiData['status'],
      'attended': apiData['attended'],
      'lessonsDeducted': apiData['lessons_deducted'],
      'is_recurring': apiData['is_recurring'],
      'recurrence_pattern': apiData['recurring_pattern'],
      'recurrence_end_date': apiData['recurring_end_date'],
    };
  }

  static Map<String, dynamic> _convertScheduleLocalToApi(
      Map<String, dynamic> localData) {
    return {
      'student_id': localData['student'],
      'instructor_id': localData['instructor'],
      'course_id': localData['course'],
      'car_id': localData['car'],
      'start': localData['start'],
      'end': localData['end'],
      'class_type': localData['class_type'],
      'status': localData['status'],
      'attended': localData['attended'],
      'lessons_deducted': localData['lessonsDeducted'],
      'lessons_completed': localData['lessonsCompleted'],
      'is_recurring': localData['is_recurring'],
      'recurring_pattern': localData['recurrence_pattern'],
      'recurring_end_date': localData['recurrence_end_date'],
    };
  }

  // Course conversions
  static Map<String, dynamic> _convertCourseApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'name': apiData['name'],
      'price': apiData['price'],
      'status': apiData['status'],
    };
  }

  // Fleet conversions
  static Map<String, dynamic> _convertFleetApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'carplate': apiData['registration'],
      'make': apiData['make'],
      'model': apiData['model'],
      'modelyear': apiData['year'].toString(),
      'instructor': apiData['assigned_instructor_id'] ?? 0,
    };
  }

  static Map<String, dynamic> _convertFleetLocalToApi(
      Map<String, dynamic> localData) {
    return {
      'make': localData['make'],
      'model': localData['model'],
      'registration': localData['carplate'],
      'year': int.tryParse(localData['modelyear'].toString()) ??
          DateTime.now().year,
      'assigned_instructor_id': localData['instructor'],
    };
  }

  // Invoice conversions
  static Map<String, dynamic> _convertInvoiceApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'invoice_number': apiData['invoice_number'],
      'student': apiData['student_id'],
      'course': apiData['course_id'],
      'lessons': apiData['lessons'],
      'price_per_lesson': apiData['price_per_lesson'],
      'amountpaid': apiData['amount_paid'],
      'created_at': apiData['created_at'],
      'due_date': apiData['due_date'],
      'status': apiData['status'],
      'total_amount': apiData['total_amount'],
    };
  }

  static Map<String, dynamic> _convertInvoiceLocalToApi(
      Map<String, dynamic> localData) {
    return {
      'student_id': localData['student'],
      'course_id': localData['course'],
      'lessons': localData['lessons'],
      'price_per_lesson': localData['price_per_lesson'],
      'due_date': localData['due_date'],
    };
  }

  // Payment conversions
  static Map<String, dynamic> _convertPaymentApiToLocal(
      Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'],
      'invoiceId': apiData['invoiceId'],
      'amount': apiData['amount'],
      'method': apiData['payment_method'],
      'paymentDate': apiData['payment_date'],
      'notes': apiData['notes'],
      'reference': apiData['reference_number'],
      'receipt_path': apiData['receipt_path'],
    };
  }

  static Map<String, dynamic> _convertPaymentLocalToApi(
      Map<String, dynamic> localData) {
    return {
      'invoiceId': localData['invoiceId'],
      'amount': localData['amount'],
      'payment_method': localData['method'],
      'payment_date': localData['paymentDate'],
      'notes': localData['notes'],
      'reference_number': localData['reference'],
    };
  }
}
