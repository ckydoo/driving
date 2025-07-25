// lib/models/schedule.dart
import 'billing.dart';
import 'payment.dart';

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
  final int lessonsDeducted; // Added missing property
  final Billing? billing;
  final List<Payment> payments;
  final bool hasPaidOverHalf;

  // New fields for recurring schedules
  final bool isRecurring;
  final String? recurrencePattern; // e.g., 'daily', 'weekly', 'monthly'
  final DateTime? recurrenceEndDate; // When the recurrence ends

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
    this.status = 'Scheduled',
    this.attended = false,
    this.lessonsDeducted = 1, // Default to 1 lesson per schedule
    this.billing,
    this.payments = const [],
    this.hasPaidOverHalf = false,
    this.lessonsCompleted = 0,
    // Initialize new fields
    this.isRecurring = false,
    this.recurrencePattern,
    this.recurrenceEndDate,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
        id: json['id'],
        start: DateTime.parse(json['start'] ?? ''),
        end: DateTime.parse(json['end'] ?? ''),
        courseId: json['course'] ?? 0,
        studentId: json['student'] ?? 0,
        instructorId: json['instructor'] ?? 0,
        carId: json['car'] ?? 0,
        classType: json['class_type'] ?? '',
        status: json['status'] ?? 'Scheduled',
        attended: json['attended'] == 1,
        lessonsCompleted: json['lessonsCompleted'] ?? 0,
        lessonsDeducted: json['lessonsDeducted'] ?? 1,
        // Parse new fields
        isRecurring: json['is_recurring'] == 1,
        recurrencePattern: json['recurrence_pattern'],
        recurrenceEndDate: json['recurrence_end_date'] != null
            ? DateTime.parse(json['recurrence_end_date'])
            : null,
      );

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
        // Add new fields to toJson
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
    int? lessonsDeducted,
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
      lessonsDeducted: lessonsDeducted ?? this.lessonsDeducted,
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
    return start.isAfter(DateTime.now()) && status != 'Cancelled';
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
    return now.isAfter(start) && now.isBefore(end) && status != 'Cancelled';
  }

  String get statusDisplay {
    if (isInProgress) return 'In Progress';
    if (isPast && attended) return 'Completed';
    if (isPast && !attended && status != 'Cancelled') return 'Missed';
    return status;
  }
}
