// lib/models/schedule.dart
import 'billing.dart';
import 'payment.dart';
import 'package:driving/constant/schedule_status.dart';

class Schedule {
  final int? id;
  double progress;
  final DateTime start;
  final DateTime end;
  final int courseId;
  final int studentId;
  final int instructorId;
  final int? carId;
  final String classType;
  final String status;
  final bool attended;
  int lessonsCompleted;
  final Billing? billing;
  final List<Payment> payments;
  final bool hasPaidOverHalf;

  // New fields for recurring schedules
  final bool isRecurring;
  final String? recurrencePattern;
  final DateTime? recurrenceEndDate;

  Schedule({
    this.id,
    required this.start,
    required this.end,
    required this.courseId,
    required this.studentId,
    required this.instructorId,
    this.carId,
    this.progress = 0.0,
    required this.classType,
    this.status = ScheduleStatus.scheduled,
    this.attended = false,
    this.billing,
    this.payments = const [],
    this.hasPaidOverHalf = false,
    this.lessonsCompleted = 0,
    this.isRecurring = false,
    this.recurrencePattern,
    this.recurrenceEndDate,
  });

  // Calculate lessons deducted based on duration
  int get lessonsDeducted {
    final duration = end.difference(start);
    final minutes = duration.inMinutes;
    // Each lesson is 30 minutes, so divide by 30 and round up
    return (minutes / 30).ceil();
  }

  factory Schedule.fromJson(Map<String, dynamic> json) {
    try {
      print('📅 Parsing schedule from JSON: $json');

      return Schedule(
        id: _parseInt(json['id']),
        // ✅ FIX: Use safe date parsing for start and end times
        start: _parseDateTime(json['start']) ?? DateTime.now(),
        end: _parseDateTime(json['end']) ??
            DateTime.now().add(Duration(hours: 1)),
        courseId: _parseInt(json['course']) ?? 0,
        studentId: _parseInt(json['student']) ?? 0,
        instructorId: _parseInt(json['instructor']) ?? 0,
        carId: _parseInt(json['car']),
        classType: json['class_type']?.toString() ?? '',
        status: json['status']?.toString() ?? ScheduleStatus.scheduled,
        attended: _parseBool(json['attended']),
        lessonsCompleted: _parseInt(json['lessonsCompleted']) ?? 0,
        isRecurring: _parseBool(json['is_recurring']),
        recurrencePattern: json['recurrence_pattern']?.toString(),
        recurrenceEndDate: _parseDateTime(json['recurrence_end_date']),
      );
    } catch (e) {
      print('❌ Error parsing Schedule from JSON: $e');
      print('🔍 JSON data: $json');
      rethrow;
    }
  }

// ✅ NEW: Safe parsing methods for Schedule
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    try {
      if (value is DateTime) return value;

      if (value is int) {
        // Handle milliseconds timestamp
        return DateTime.fromMillisecondsSinceEpoch(value);
      }

      if (value is String) {
        if (value.trim().isEmpty) return null;

        // Handle ISO format: "2025-08-29T17:19:53.000"
        if (value.contains('T')) {
          return DateTime.parse(value);
        }

        // Handle other date formats
        if (value.contains('-')) {
          // Try parsing date strings like "2025-08-29 15:22:08"
          if (value.contains(' ')) {
            return DateTime.parse(value.replaceFirst(' ', 'T'));
          }
          return DateTime.parse(value);
        }

        // Handle numeric string (milliseconds)
        final intValue = int.tryParse(value);
        if (intValue != null) {
          return DateTime.fromMillisecondsSinceEpoch(intValue);
        }
      }

      // Handle Firestore Timestamp format
      if (value is Map && value.containsKey('seconds')) {
        final seconds = value['seconds'] as int;
        final nanoseconds = value['nanoseconds'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000));
      }
    } catch (e) {
      print('⚠️ Error parsing DateTime from $value (${value.runtimeType}): $e');
    }

    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'course': courseId,
        'student': studentId,
        'instructor': instructorId,
        'car': carId,
        'class_type': classType,
        'status': status,
        'attended': attended ? 1 : 0,
        'lessonsCompleted': lessonsCompleted,
        'lessonsDeducted': lessonsDeducted,
        'is_recurring': isRecurring ? 1 : 0,
        'recurrence_pattern': recurrencePattern,
        'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      };

  String get duration {
    final difference = end.difference(start);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  Schedule copyWith({
    int? id,
    double? progress,
    DateTime? start,
    DateTime? end,
    int? courseId,
    int? studentId,
    int? instructorId,
    int? carId,
    String? classType,
    String? status,
    bool? attended,
    int? lessonsCompleted,
    Billing? billing,
    List<Payment>? payments,
    bool? hasPaidOverHalf,
    bool? isRecurring,
    String? recurrencePattern,
    DateTime? recurrenceEndDate,
  }) {
    return Schedule(
      id: id ?? this.id,
      progress: progress ?? this.progress,
      start: start ?? this.start,
      end: end ?? this.end,
      courseId: courseId ?? this.courseId,
      studentId: studentId ?? this.studentId,
      instructorId: instructorId ?? this.instructorId,
      carId: carId ?? this.carId,
      classType: classType ?? this.classType,
      status: status ?? this.status,
      attended: attended ?? this.attended,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      billing: billing ?? this.billing,
      payments: payments ?? this.payments,
      hasPaidOverHalf: hasPaidOverHalf ?? this.hasPaidOverHalf,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
    );
  }

  // Helper methods
  bool get isUpcoming {
    return start.isAfter(DateTime.now()) && status != ScheduleStatus.cancelled;
  }

  bool get isPast {
    return end.isBefore(DateTime.now());
  }

  bool get isToday {
    final now = DateTime.now();
    return start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
  }

  bool get isInProgress {
    final now = DateTime.now();
    return now.isAfter(start) &&
        now.isBefore(end) &&
        status != ScheduleStatus.cancelled &&
        !attended;
  }

  /// Get the display status using consistent logic
  String get statusDisplay {
    return ScheduleStatus.getDisplayStatus(status, attended, start, end);
  }

  /// Validate that the schedule has consistent status and attendance
  bool get isStatusConsistent {
    final displayStatus = statusDisplay;

    // Check if attended matches completed status
    if (attended && displayStatus != ScheduleStatus.completed) return false;
    if (!attended && displayStatus == ScheduleStatus.completed) return false;

    // Check if cancelled schedules are not marked attended
    if (status == ScheduleStatus.cancelled && attended) return false;

    return true;
  }

  /// Get corrected schedule with consistent status
  Schedule get withConsistentStatus {
    if (isStatusConsistent) return this;

    final correctStatus = statusDisplay;
    final correctAttended = correctStatus == ScheduleStatus.completed;

    return copyWith(
      status: correctStatus,
      attended: correctAttended,
    );
  }
}
