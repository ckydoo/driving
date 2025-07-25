// lib/models/enhanced_schedule.dart
enum ScheduleType { single, recurring }

enum RecurrencePattern { daily, weekly, biweekly, monthly, custom }

enum AttendanceStatus { pending, attended, absent, cancelled }

class EnhancedSchedule {
  final int? id;
  final DateTime start;
  final DateTime end;
  final int courseId;
  final int studentId;
  final int instructorId;
  final int? carId;
  final String classType;
  final String status;
  final AttendanceStatus attendanceStatus;
  final int lessonsDeducted;
  final bool isRecurring;
  final String? recurrencePattern;
  final DateTime? recurrenceEndDate;
  final int? maxOccurrences;
  final List<int>? selectedDaysOfWeek; // For weekly patterns
  final int? customInterval; // For custom patterns
  final String? parentScheduleId; // Links recurring instances
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final String? notes;

  const EnhancedSchedule({
    this.id,
    required this.start,
    required this.end,
    required this.courseId,
    required this.studentId,
    required this.instructorId,
    this.carId,
    required this.classType,
    this.status = 'Scheduled',
    this.attendanceStatus = AttendanceStatus.pending,
    this.lessonsDeducted = 1,
    this.isRecurring = false,
    this.recurrencePattern,
    this.recurrenceEndDate,
    this.maxOccurrences,
    this.selectedDaysOfWeek,
    this.customInterval,
    this.parentScheduleId,
    required this.createdAt,
    this.modifiedAt,
    this.notes,
  });

  factory EnhancedSchedule.fromJson(Map<String, dynamic> json) {
    return EnhancedSchedule(
      id: json['id'],
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
      courseId: json['course'],
      studentId: json['student'],
      instructorId: json['instructor'],
      carId: json['car'],
      classType: json['class_type'],
      status: json['status'] ?? 'Scheduled',
      attendanceStatus: AttendanceStatus.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (json['attendance_status'] ?? 'pending'),
        orElse: () => AttendanceStatus.pending,
      ),
      lessonsDeducted: json['lessons_deducted'] ?? 1,
      isRecurring: json['is_recurring'] == 1,
      recurrencePattern: json['recurrence_pattern'],
      recurrenceEndDate: json['recurrence_end_date'] != null
          ? DateTime.parse(json['recurrence_end_date'])
          : null,
      maxOccurrences: json['max_occurrences'],
      selectedDaysOfWeek: json['selected_days'] != null
          ? List<int>.from(json['selected_days']
              .split(',')
              .map((e) => int.parse(e.trim()))
              .where((e) => e > 0))
          : null,
      customInterval: json['custom_interval'],
      parentScheduleId: json['parent_schedule_id'],
      createdAt: DateTime.parse(json['created_at']),
      modifiedAt: json['modified_at'] != null
          ? DateTime.parse(json['modified_at'])
          : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'course': courseId,
      'student': studentId,
      'instructor': instructorId,
      'car': carId,
      'class_type': classType,
      'status': status,
      'attendance_status': attendanceStatus.toString().split('.').last,
      'lessons_deducted': lessonsDeducted,
      'is_recurring': isRecurring ? 1 : 0,
      'recurrence_pattern': recurrencePattern,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      'max_occurrences': maxOccurrences,
      'selected_days': selectedDaysOfWeek?.join(','),
      'custom_interval': customInterval,
      'parent_schedule_id': parentScheduleId,
      'created_at': createdAt.toIso8601String(),
      'modified_at': modifiedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  EnhancedSchedule copyWith({
    int? id,
    DateTime? start,
    DateTime? end,
    int? courseId,
    int? studentId,
    int? instructorId,
    int? carId,
    String? classType,
    String? status,
    AttendanceStatus? attendanceStatus,
    int? lessonsDeducted,
    bool? isRecurring,
    String? recurrencePattern,
    DateTime? recurrenceEndDate,
    int? maxOccurrences,
    List<int>? selectedDaysOfWeek,
    int? customInterval,
    String? parentScheduleId,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? notes,
  }) {
    return EnhancedSchedule(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      courseId: courseId ?? this.courseId,
      studentId: studentId ?? this.studentId,
      instructorId: instructorId ?? this.instructorId,
      carId: carId ?? this.carId,
      classType: classType ?? this.classType,
      status: status ?? this.status,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      lessonsDeducted: lessonsDeducted ?? this.lessonsDeducted,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
      selectedDaysOfWeek: selectedDaysOfWeek ?? this.selectedDaysOfWeek,
      customInterval: customInterval ?? this.customInterval,
      parentScheduleId: parentScheduleId ?? this.parentScheduleId,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      notes: notes ?? this.notes,
    );
  }

  String get duration {
    final difference = end.difference(start);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  bool get canEditAttendance {
    return status != 'Cancelled' && start.isBefore(DateTime.now());
  }

  bool get canReschedule {
    return status != 'Cancelled' && start.isAfter(DateTime.now());
  }

  @override
  String toString() {
    return 'EnhancedSchedule(id: $id, start: $start, student: $studentId, instructor: $instructorId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedSchedule && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
