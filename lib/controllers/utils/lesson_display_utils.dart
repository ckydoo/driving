// lib/utils/lesson_display_utils.dart
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/services/lesson_counting_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Utility class for consistent lesson display across all UI components
/// This ensures all screens show the same information using the centralized logic
class LessonDisplayUtils {
  static final LessonCountingService _lessonService =
      LessonCountingService.instance;
  static final SettingsController _settings = Get.find<SettingsController>();

  /// Get formatted text for remaining lessons
  static String getRemainingLessonsText(int studentId, int courseId) {
    final remaining = _lessonService.getRemainingLessons(studentId, courseId);

    if (remaining <= 0) {
      return 'No lessons remaining';
    } else if (remaining == 1) {
      return '1 lesson remaining';
    } else {
      return '$remaining lessons remaining';
    }
  }

  /// Get color based on remaining lesson count
  static Color getRemainingLessonsColor(int studentId, int courseId) {
    final remaining = _lessonService.getRemainingLessons(studentId, courseId);

    if (remaining <= 0) {
      return Colors.red;
    } else if (remaining <= _settings.lowLessonThreshold.value) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  /// Get icon for lesson status
  static IconData getRemainingLessonsIcon(int studentId, int courseId) {
    final remaining = _lessonService.getRemainingLessons(studentId, courseId);

    if (remaining <= 0) {
      return Icons.warning;
    } else if (remaining <= _settings.lowLessonThreshold.value) {
      return Icons.warning_amber;
    } else {
      return Icons.check_circle;
    }
  }

  /// Get detailed lesson usage statistics for display
  static Map<String, dynamic> getLessonUsageDisplay(
      int studentId, int courseId) {
    final stats = _lessonService.getLessonUsageStats(studentId, courseId);

    return {
      'total': stats['total'],
      'used': stats['used'],
      'remaining': stats['remaining'],
      'attended': stats['attended'],
      'scheduled': stats['scheduled'],
      'usageText': '${stats['used']} / ${stats['total']} lessons used',
      'progressPercent': stats['total']! > 0
          ? (stats['used']! / stats['total']! * 100).round()
          : 0,
      'remainingText': getRemainingLessonsText(studentId, courseId),
      'statusColor': getRemainingLessonsColor(studentId, courseId),
      'statusIcon': getRemainingLessonsIcon(studentId, courseId),
    };
  }

  /// Get warning message if applicable
  static String? getLessonWarningMessage(int studentId, int courseId) {
    return _lessonService.getLessonWarningMessage(studentId, courseId);
  }

  /// Check if should show warning
  static bool shouldShowLessonWarning(int studentId, int courseId) {
    if (!_settings.showLowLessonWarning.value) return false;
    return getLessonWarningMessage(studentId, courseId) != null;
  }

  /// Build lesson status chip widget
  static Widget buildLessonStatusChip(int studentId, int courseId) {
    final display = getLessonUsageDisplay(studentId, courseId);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: display['statusColor'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: display['statusColor'], width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            display['statusIcon'],
            size: 16,
            color: display['statusColor'],
          ),
          SizedBox(width: 4),
          Text(
            display['remainingText'],
            style: TextStyle(
              color: display['statusColor'],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Build lesson progress bar widget
  static Widget buildLessonProgressBar(int studentId, int courseId) {
    final display = getLessonUsageDisplay(studentId, courseId);
    final progress = display['progressPercent'] / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lesson Usage',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Text(
              display['usageText'],
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 1.0
                ? Colors.red
                : progress >= 0.8
                    ? Colors.orange
                    : Colors.blue,
          ),
        ),
        SizedBox(height: 2),
        Text(
          display['remainingText'],
          style: TextStyle(
            color: display['statusColor'],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Build detailed lesson statistics card
  static Widget buildDetailedLessonStats(int studentId, int courseId) {
    final display = getLessonUsageDisplay(studentId, courseId);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lesson Statistics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildStatRow('Total Lessons:', '${display['total']}'),
            _buildStatRow('Lessons Used:', '${display['used']}'),
            _buildStatRow('Lessons Remaining:', '${display['remaining']}'),
            _buildStatRow('Attended Lessons:', '${display['attended']}'),
            _buildStatRow('Scheduled Lessons:', '${display['scheduled']}'),
            SizedBox(height: 8),
            buildLessonProgressBar(studentId, courseId),
            if (shouldShowLessonWarning(studentId, courseId)) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        getLessonWarningMessage(studentId, courseId)!,
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Helper method to build stat rows
  static Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Format lesson count with proper pluralization
  static String formatLessonCount(int count) {
    if (count == 0) return 'No lessons';
    if (count == 1) return '1 lesson';
    return '$count lessons';
  }

  /// Get lesson count color based on value and threshold
  static Color getLessonCountColor(int count, {int? threshold}) {
    threshold ??= _settings.lowLessonThreshold.value;

    if (count <= 0) return Colors.red;
    if (count <= threshold) return Colors.orange;
    return Colors.green;
  }

  /// Build a simple lesson counter widget
  static Widget buildSimpleLessonCounter(int studentId, int courseId,
      {double fontSize = 14}) {
    final remaining = _lessonService.getRemainingLessons(studentId, courseId);
    final color = getLessonCountColor(remaining);

    return Text(
      formatLessonCount(remaining),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
      ),
    );
  }

  /// Check if scheduling is allowed based on lesson availability
  static bool canScheduleLesson(
      int studentId, int courseId, int lessonsNeeded) {
    return _lessonService.canScheduleLessons(
        studentId, courseId, lessonsNeeded);
  }

  /// Get text explanation of counting method
  static String getCountingMethodText() {
    return _settings.countScheduledLessons.value
        ? 'Counting scheduled and attended lessons'
        : 'Counting only attended lessons';
  }

  /// Show lesson availability dialog
  static void showLessonAvailabilityDialog(int studentId, int courseId) {
    final display = getLessonUsageDisplay(studentId, courseId);

    Get.dialog(
      AlertDialog(
        title: Text('Lesson Availability'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDetailedLessonStats(studentId, courseId),
            SizedBox(height: 8),
            Text(
              getCountingMethodText(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
