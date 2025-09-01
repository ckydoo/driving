import 'package:driving/services/database_helper.dart';

class ScheduleDataValidator {
  /// Validates schedule data before inserting to prevent NOT NULL constraint errors
  static Map<String, dynamic> validateScheduleData(
      Map<String, dynamic> scheduleData) {
    final validatedData = Map<String, dynamic>.from(scheduleData);

    // ✅ FIX 1: Ensure start and end are not null or empty
    if (validatedData['start'] == null || validatedData['start'] == '') {
      throw Exception('Schedule start time is required and cannot be null');
    }

    if (validatedData['end'] == null || validatedData['end'] == '') {
      throw Exception('Schedule end time is required and cannot be null');
    }

    // Validate other required fields
    if (validatedData['course'] == null) {
      throw Exception('Course ID is required');
    }

    if (validatedData['student'] == null) {
      throw Exception('Student ID is required');
    }

    if (validatedData['instructor'] == null) {
      throw Exception('Instructor ID is required');
    }

    if (validatedData['class_type'] == null ||
        validatedData['class_type'] == '') {
      validatedData['class_type'] = 'Practical'; // Default value
    }

    if (validatedData['status'] == null || validatedData['status'] == '') {
      validatedData['status'] = 'Scheduled'; // Default value
    }

    // Ensure numeric defaults
    validatedData['attended'] ??= 0;
    validatedData['lessonsCompleted'] ??= 0;
    validatedData['lessonsDeducted'] ??= 1;
    validatedData['is_recurring'] ??= 0;
    validatedData['deleted'] ??= 0;
    validatedData['firebase_synced'] ??= 0;

    return validatedData;
  }
}
