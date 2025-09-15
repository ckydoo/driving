// lib/services/api_service.dart - CORRECTED VERSION

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
  static const String baseUrl = 'http://your-domain.com/api';
  static String? _token;

  // Headers
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // Authentication
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      _token = data['data']['token'];
      return data;
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  static Future<void> logout() async {
    if (_token != null) {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
      );
      _token = null;
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
      if (invoiceId != null) 'invoice_id': invoiceId.toString(),
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

  // Sync Methods
  static Future<Map<String, dynamic>> syncDownload({String? lastSync}) async {
    final headers = Map<String, String>.from(_headers);
    if (lastSync != null) {
      headers['Last-Sync'] = lastSync;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/sync/download'),
      headers: headers,
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Sync download failed');
    }
  }

  static Future<Map<String, dynamic>> syncUpload(
      Map<String, dynamic> localData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sync/upload'),
      headers: _headers,
      body: json.encode(localData),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Sync upload failed');
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

  // Set token for authentication
  static void setToken(String token) {
    _token = token;
  }

  // Clear token
  static void clearToken() {
    _token = null;
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
      'description': apiData['description'],
      'price': apiData['price'],
      'lessons': apiData['lessons'],
      'type': apiData['type'],
      'status': apiData['status'],
      'duration_minutes': apiData['duration_minutes'],
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
      'transmission': 'manual', // Default transmission
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
      'invoiceId': apiData['invoice_id'],
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
      'invoice_id': localData['invoiceId'],
      'amount': localData['amount'],
      'payment_method': localData['method'],
      'payment_date': localData['paymentDate'],
      'notes': localData['notes'],
      'reference_number': localData['reference'],
    };
  }
}
