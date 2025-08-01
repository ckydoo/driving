// lib/constants/schedule_status.dart
class ScheduleStatus {
  // Core status values
  static const String scheduled = 'Scheduled';
  static const String inProgress = 'In Progress';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const String missed = 'Missed';
  static const String rescheduled = 'Rescheduled';

  // All valid statuses
  static const List<String> allStatuses = [
    scheduled,
    inProgress,
    completed,
    cancelled,
    missed,
    rescheduled,
  ];

  // Status colors for UI
  static const Map<String, int> statusColors = {
    scheduled: 0xFF2196F3, // Blue
    inProgress: 0xFFFF9800, // Orange
    completed: 0xFF4CAF50, // Green
    cancelled: 0xFFF44336, // Red
    missed: 0xFF9E9E9E, // Grey
    rescheduled: 0xFF673AB7, // Purple
  };

  // Status icons
  static const Map<String, int> statusIcons = {
    scheduled: 0xe8b5, // Icons.schedule
    inProgress: 0xe037, // Icons.play_circle
    completed: 0xe876, // Icons.check_circle
    cancelled: 0xe5c9, // Icons.cancel
    missed: 0xe002, // Icons.access_time
    rescheduled: 0xe8b5, // Icons.schedule
  };

  // Helper methods
  static bool isValidStatus(String status) {
    return allStatuses.contains(status);
  }

  static String getDisplayStatus(
      String status, bool attended, DateTime start, DateTime end) {
    final now = DateTime.now();

    // If explicitly cancelled, return cancelled
    if (status == cancelled) return cancelled;

    // If attended, always completed regardless of other status
    if (attended) return completed;

    // If currently in progress
    if (now.isAfter(start) && now.isBefore(end) && status != cancelled) {
      return inProgress;
    }

    // If past and not attended (and not cancelled)
    if (now.isAfter(end) && !attended && status != cancelled) {
      return missed;
    }

    // Default to the actual status or scheduled
    return isValidStatus(status) ? status : scheduled;
  }
}
