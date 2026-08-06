import 'dart:convert';

import 'package:driving/services/api_service.dart';
import 'package:http/http.dart' as http;

class EngagementService {
  static Map<String, String> _headers() {
    final token = ApiService.currentToken;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiService.baseUrl;
    final parsed = Uri.parse('$base$path');
    return query == null ? parsed : parsed.replace(queryParameters: query);
  }

  static Future<List<Map<String, dynamic>>> getReminderTemplates({
    String? locale,
    bool? active,
  }) async {
    final qp = <String, String>{};
    if (locale != null && locale.isNotEmpty) qp['locale'] = locale;
    if (active != null) qp['active'] = active.toString();

    final response = await http.get(
      _uri('/engagement/reminder-templates', qp.isEmpty ? null : qp),
      headers: _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>?> createReminderTemplate(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      _uri('/engagement/reminder-templates'),
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  static Future<Map<String, dynamic>?> updateReminderTemplate(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      _uri('/engagement/reminder-templates/$id'),
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  static Future<Map<String, dynamic>?> createRescheduleLink(
    int scheduleId, {
    int expiresInMinutes = 1440,
  }) async {
    final response = await http.post(
      _uri('/engagement/schedules/$scheduleId/reschedule-link'),
      headers: _headers(),
      body: jsonEncode({'expires_in_minutes': expiresInMinutes}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  static Future<Map<String, dynamic>?> consumeRescheduleLink(
      String token) async {
    final response = await http.get(
      _uri('/engagement/reschedule-link/$token'),
      headers: _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  static Future<List<Map<String, dynamic>>> getOverdueBoard() async {
    final response = await http.get(
      _uri('/engagement/overdue-board'),
      headers: _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  static Future<bool> updateOverdueFollowup(
    int invoiceId, {
    required String status,
    String? note,
    int? assignedTo,
    DateTime? nextFollowupAt,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      if (note != null) 'note': note,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (nextFollowupAt != null)
        'next_followup_at': nextFollowupAt.toIso8601String(),
    };

    final response = await http.put(
      _uri('/engagement/overdue-board/$invoiceId/follow-up'),
      headers: _headers(),
      body: jsonEncode(payload),
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<Map<String, dynamic>?> getInstructorDailyBriefing({
    DateTime? date,
    int? instructorId,
  }) async {
    final qp = <String, String>{};
    if (date != null) qp['date'] = date.toIso8601String();
    if (instructorId != null) qp['instructor_id'] = instructorId.toString();

    final response = await http.get(
      _uri('/engagement/instructor-briefing', qp.isEmpty ? null : qp),
      headers: _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }
}
