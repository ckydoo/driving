// lib/widgets/schedule_details_dialog.dart
import 'package:driving/screens/schedule/create_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/schedule.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/user_controller.dart';
import '../controllers/course_controller.dart';
import '../controllers/fleet_controller.dart';
import '../controllers/billing_controller.dart';

class ScheduleDetailsDialog extends StatefulWidget {
  final Schedule schedule;

  const ScheduleDetailsDialog({Key? key, required this.schedule})
      : super(key: key);

  @override
  State<ScheduleDetailsDialog> createState() => _ScheduleDetailsDialogState();
}

class _ScheduleDetailsDialogState extends State<ScheduleDetailsDialog> {
  late Schedule currentSchedule;
  Timer? _lessonTimer;

  @override
  void initState() {
    super.initState();
    currentSchedule = widget.schedule;
    _startLessonTimer();
  }

  @override
  void dispose() {
    _lessonTimer?.cancel();
    super.dispose();
  }

  // Auto-complete lesson when time ends
  void _startLessonTimer() {
    if (currentSchedule.status.toLowerCase() == 'in progress') {
      final now = DateTime.now();
      final timeUntilEnd = currentSchedule.end.difference(now);

      if (timeUntilEnd.isNegative) {
        // Lesson should already be completed
        _autoCompleteLessonIfNeeded();
      } else {
        // Set timer to auto-complete when lesson ends
        _lessonTimer = Timer(timeUntilEnd, () {
          _autoCompleteLessonIfNeeded();
        });
      }
    }
  }

  Future<void> _autoCompleteLessonIfNeeded() async {
    if (currentSchedule.status.toLowerCase() == 'in progress' && mounted) {
      try {
        final scheduleController = Get.find<ScheduleController>();
        final completedSchedule = currentSchedule.copyWith(status: 'Completed');

        await scheduleController.addOrUpdateSchedule(completedSchedule);

        if (mounted) {
          setState(() {
            currentSchedule = completedSchedule;
          });

          Get.snackbar(
            'Lesson Auto-Completed',
            'The lesson has been automatically marked as completed',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );
        }
      } catch (e) {
        if (mounted) {
          Get.snackbar(
            'Auto-Complete Error',
            'Failed to auto-complete lesson: ${e.toString()}',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final courseController = Get.find<CourseController>();
    final fleetController = Get.find<FleetController>();
    final scheduleController = Get.find<ScheduleController>();
    final billingController = Get.find<BillingController>();

    // FIX 1: Use safe null checks for finding related entities
    final student = userController.users.firstWhereOrNull(
      (user) =>
          user.id == currentSchedule.studentId &&
          user.role.toLowerCase() == 'student',
    );

    final instructor = userController.users.firstWhereOrNull(
      (user) =>
          user.id == currentSchedule.instructorId &&
          user.role.toLowerCase() == 'instructor',
    );

    final course = courseController.courses.firstWhereOrNull(
      (c) => c.id == currentSchedule.courseId,
    );

    final vehicle = currentSchedule.carId != null
        ? fleetController.fleet
            .firstWhereOrNull((v) => v.id == currentSchedule.carId)
        : null;

    // FIX 2: Get billing information with proper null safety
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) =>
          inv.studentId == currentSchedule.studentId &&
          inv.courseId == currentSchedule.courseId,
    );

    // FIX 3: Use centralized lesson calculation method (if available)
    // Otherwise fallback to local calculation
    final usedLessons = scheduleController.schedules
        .where((s) =>
            s.studentId == currentSchedule.studentId &&
            s.courseId == currentSchedule.courseId &&
            s.attended &&
            s.status.toLowerCase() != 'cancelled') // Exclude cancelled lessons
        .fold<int>(0, (sum, s) => sum + (s.lessonsDeducted ?? 1));

    final remainingLessons = invoice != null
        ? (invoice.lessons - usedLessons).clamp(0, invoice.lessons)
        : 0;

    return Dialog(
      insetPadding: EdgeInsets.all(16),
      child: Container(
        width: double.maxFinite,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getStatusColor(currentSchedule.status),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(currentSchedule.status),
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lesson Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          currentSchedule.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and Time Section
                    _buildInfoSection(
                      'Schedule Information',
                      Icons.schedule,
                      Colors.blue,
                      [
                        _buildInfoRow(
                            'Date',
                            DateFormat('EEEE, MMMM dd, yyyy')
                                .format(currentSchedule.start)),
                        _buildInfoRow('Start Time',
                            DateFormat('HH:mm').format(currentSchedule.start)),
                        _buildInfoRow('End Time',
                            DateFormat('HH:mm').format(currentSchedule.end)),
                        _buildInfoRow('Duration', _calculateDuration()),
                        _buildInfoRow('Class Type', currentSchedule.classType),
                      ],
                    ),

                    SizedBox(height: 20),

                    // People Section
                    _buildInfoSection(
                      'Participants',
                      Icons.people,
                      Colors.green,
                      [
                        _buildInfoRow(
                          'Student',
                          student != null
                              ? '${student.fname} ${student.lname}'
                              : 'Unknown Student',
                        ),
                        _buildInfoRow(
                          'Instructor',
                          instructor != null
                              ? '${instructor.fname} ${instructor.lname}'
                              : 'Unknown Instructor',
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Course and Vehicle Section
                    _buildInfoSection(
                      'Course & Vehicle',
                      Icons.directions_car,
                      Colors.orange,
                      [
                        _buildInfoRow(
                            'Course', course?.name ?? 'Unknown Course'),
                        _buildInfoRow(
                          'Vehicle',
                          vehicle != null
                              ? '${vehicle.make} ${vehicle.model} (${vehicle.carPlate})'
                              : 'No vehicle assigned',
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Billing Section
                    if (invoice != null) ...[
                      _buildInfoSection(
                        'Billing Information',
                        Icons.account_balance_wallet,
                        Colors.purple,
                        [
                          _buildInfoRow('Total Lessons', '${invoice.lessons}'),
                          _buildInfoRow('Used Lessons', '$usedLessons'),
                          _buildInfoRow(
                              'Remaining Lessons', '$remainingLessons'),
                          _buildInfoRow(
                              'Lesson Status',
                              currentSchedule.attended
                                  ? 'Attended'
                                  : 'Not Attended'),
                          _buildInfoRow('Lessons Deducted',
                              '${currentSchedule.lessonsDeducted ?? 1}'),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],

                    // Progress Section
                    if (currentSchedule.attended ||
                        currentSchedule.status.toLowerCase() ==
                            'completed') ...[
                      _buildInfoSection(
                        'Progress',
                        Icons.trending_up,
                        Colors.teal,
                        [
                          _buildInfoRow('Lessons Completed',
                              '${currentSchedule.lessonsCompleted ?? 0}'),
                          // FIX 4: Calculate progress safely
                          _buildInfoRow(
                              'Progress',
                              invoice != null
                                  ? '${((usedLessons / invoice.lessons) * 100).toStringAsFixed(1)}%'
                                  : '0%'),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],

                    // Recurrence Section - FIX 5: Check for recurrence properly
                    if (currentSchedule.isRecurring == true) ...[
                      _buildInfoSection(
                        'Recurrence',
                        Icons.repeat,
                        Colors.indigo,
                        [
                          _buildInfoRow(
                              'Pattern',
                              currentSchedule
                                      .recurrencePattern?.capitalizeFirst ??
                                  'N/A'),
                          if (currentSchedule.recurrenceEndDate != null)
                            _buildInfoRow(
                              'End Date',
                              DateFormat('MMM dd, yyyy')
                                  .format(currentSchedule.recurrenceEndDate!),
                            ),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Column(
                children: [
                  // Show attendance status if already marked
                  if (currentSchedule.attended) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getAttendanceStatusColor(currentSchedule.status)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _getAttendanceStatusColor(
                                    currentSchedule.status)
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          // Animated icon for "In Progress"
                          if (currentSchedule.status.toLowerCase() ==
                              'in progress')
                            TweenAnimationBuilder<double>(
                              duration: Duration(seconds: 2),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.rotate(
                                  angle: value * 2 * 3.14159,
                                  child: Icon(
                                    Icons.access_time,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                );
                              },
                            )
                          else
                            Icon(
                                _getAttendanceStatusIcon(
                                    currentSchedule.status),
                                color: _getAttendanceStatusColor(
                                    currentSchedule.status),
                                size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _getAttendanceStatusText(
                                          currentSchedule.status),
                                      style: TextStyle(
                                        color: _getAttendanceStatusColor(
                                            currentSchedule.status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (currentSchedule.status.toLowerCase() ==
                                        'in progress') ...[
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'AUTO',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (currentSchedule.status.toLowerCase() ==
                                    'in progress') ...[
                                  SizedBox(height: 4),
                                  StreamBuilder<DateTime>(
                                    stream: Stream.periodic(
                                        Duration(seconds: 1),
                                        (_) => DateTime.now()),
                                    builder: (context, snapshot) {
                                      final now =
                                          snapshot.data ?? DateTime.now();
                                      final timeRemaining =
                                          currentSchedule.end.difference(now);

                                      if (timeRemaining.isNegative) {
                                        return Text(
                                          'Auto-completing lesson...',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        );
                                      }

                                      final minutes = timeRemaining.inMinutes;
                                      final seconds =
                                          timeRemaining.inSeconds % 60;

                                      return Text(
                                        'Auto-completes in ${minutes}m ${seconds}s',
                                        style: TextStyle(
                                          color: Colors.orange.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                  ],

                  // Attendance Actions (for instructors)
                  if (currentSchedule.status.toLowerCase() != 'cancelled' &&
                      !currentSchedule.attended &&
                      _canMarkAttendance()) ...[
                    _buildAttendanceSection(scheduleController),
                    SizedBox(height: 12),
                  ],

                  // Show time remaining message if attendance not available yet
                  if (currentSchedule.status.toLowerCase() != 'cancelled' &&
                      !currentSchedule.attended &&
                      !_canMarkAttendance()) ...[
                    _buildAttendanceTimeMessage(),
                    SizedBox(height: 12),
                  ],

                  // Management Actions (only if not attended)
                  if (currentSchedule.status.toLowerCase() != 'cancelled' &&
                      !currentSchedule.attended) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _editSchedule(),
                            icon: Icon(Icons.edit, size: 18),
                            label: Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.blue),
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _rescheduleLesson(),
                            icon: Icon(Icons.schedule, size: 18),
                            label: Text('Reschedule'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.purple),
                              foregroundColor: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                  ],

                  // Cancel Action (only if not attended)
                  if (currentSchedule.status.toLowerCase() != 'cancelled' &&
                      !currentSchedule.attended) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelLesson(scheduleController),
                        icon: Icon(Icons.delete, size: 18),
                        label: Text('Cancel Lesson'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSection(ScheduleController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mark Attendance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _markAttendance(true, controller),
                icon: Icon(Icons.check, size: 18),
                label: Text('Present'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _markAttendance(false, controller),
                icon: Icon(Icons.close, size: 18),
                label: Text('Absent'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Check if attendance can be marked (5 minutes before lesson starts)
  bool _canMarkAttendance() {
    final now = DateTime.now();
    final fiveMinutesBeforeStart =
        currentSchedule.start.subtract(Duration(minutes: 5));

    // Allow marking attendance from 5 minutes before start until lesson end
    return now.isAfter(fiveMinutesBeforeStart) &&
        now.isBefore(currentSchedule.end);
  }

  // Build message showing when attendance will be available
  Widget _buildAttendanceTimeMessage() {
    final now = DateTime.now();
    final fiveMinutesBeforeStart =
        currentSchedule.start.subtract(Duration(minutes: 5));

    String message;
    Color messageColor;
    IconData messageIcon;

    if (now.isBefore(fiveMinutesBeforeStart)) {
      final timeUntilAvailable = fiveMinutesBeforeStart.difference(now);
      final hours = timeUntilAvailable.inHours;
      final minutes = timeUntilAvailable.inMinutes % 60;

      String timeString;
      if (hours > 0) {
        timeString = '${hours}h ${minutes}m';
      } else {
        timeString = '${minutes}m';
      }

      message = 'Attendance will be available in $timeString';
      messageColor = Colors.orange;
      messageIcon = Icons.access_time;
    } else if (now.isAfter(currentSchedule.end)) {
      message = 'Lesson time has ended - attendance no longer available';
      messageColor = Colors.red;
      messageIcon = Icons.event_busy;
    } else {
      // This case shouldn't happen if _canMarkAttendance() is working correctly
      message = 'Attendance is now available';
      messageColor = Colors.green;
      messageIcon = Icons.check_circle_outline;
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: messageColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: messageColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(messageIcon, color: messageColor, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: messageColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FIX 7: Calculate duration properly
  String _calculateDuration() {
    final duration = currentSchedule.end.difference(currentSchedule.start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'confirmed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'scheduled':
        return Colors.blue.shade600;
      case 'in progress':
        return Colors.orange.shade600;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'confirmed':
        return Icons.verified;
      case 'pending':
        return Icons.pending;
      case 'scheduled':
        return Icons.schedule;
      case 'in progress':
        return Icons.play_circle_filled;
      default:
        return Icons.schedule;
    }
  }

  Future<void> _markAttendance(
      bool attended, ScheduleController controller) async {
    try {
      String newStatus;

      if (attended) {
        // Check if lesson is currently happening (between start and end time)
        final now = DateTime.now();
        if (now.isBefore(currentSchedule.end)) {
          // If current time is before lesson end, it's still in progress
          newStatus = 'In Progress';
        } else {
          // Only mark as completed if lesson time has actually ended
          newStatus = 'Completed';
        }
      } else {
        newStatus = 'Absent';
      }

      // Update the schedule with attendance information
      final updatedSchedule = currentSchedule.copyWith(
        attended: attended,
        status: newStatus,
      );

      // Call the controller method
      await controller.addOrUpdateSchedule(updatedSchedule);

      // Update local state to reflect changes immediately
      setState(() {
        currentSchedule = updatedSchedule;
      });

      // Start auto-completion timer if lesson is in progress
      if (newStatus == 'In Progress') {
        _startLessonTimer();
      }

      String message;
      if (attended) {
        message = newStatus == 'In Progress'
            ? 'Student marked present - lesson started. Will auto-complete at ${DateFormat('HH:mm').format(currentSchedule.end)}'
            : 'Lesson marked as completed';
      } else {
        message = 'Lesson marked as absent';
      }

      Get.snackbar(
        'Success',
        message,
        backgroundColor: attended
            ? (newStatus == 'In Progress' ? Colors.orange : Colors.green)
            : Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update attendance: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _editSchedule() {
    Get.back(); // Close dialog
    Get.to(() => SingleScheduleScreen(existingSchedule: currentSchedule));
  }

  void _rescheduleLesson() {
    Get.back(); // Close dialog
    // Create a copy of the schedule for rescheduling
    final rescheduleSchedule = currentSchedule.copyWith(
      id: null, // New schedule
      status: 'Scheduled',
      attended: false,
    );
    Get.to(() => SingleScheduleScreen(existingSchedule: rescheduleSchedule));
  }

  Future<void> _cancelLesson(ScheduleController controller) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Cancel Lesson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel this lesson?'),
            SizedBox(height: 8),
            Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('• Mark the lesson as cancelled'),
            if (currentSchedule.attended &&
                (currentSchedule.lessonsDeducted ?? 1) > 0)
              Text(
                  '• Return ${currentSchedule.lessonsDeducted ?? 1} lesson(s) to the student'),
            SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final billingController = Get.find<BillingController>();

        // If the lesson was attended and lessons were deducted, refund them
        if (currentSchedule.attended &&
            (currentSchedule.lessonsDeducted ?? 1) > 0) {
          // Find the invoice for this student and course
          final invoice = billingController.invoices.firstWhereOrNull(
            (inv) =>
                inv.studentId == currentSchedule.studentId &&
                inv.courseId == currentSchedule.courseId,
          );

          if (invoice != null) {
            // Create a new invoice with lessons refunded
            final lessonsToRefund = currentSchedule.lessonsDeducted ?? 1;
            final updatedInvoice = invoice.copyWith(
              lessons: invoice.lessons + lessonsToRefund,
            );

            // Update the invoice
            await billingController.updateInvoice(updatedInvoice.toMap());

            // Optional: Add a note to track the refund
            Get.snackbar(
              'Lessons Refunded',
              '$lessonsToRefund lesson(s) have been returned to the student\'s account',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: Duration(seconds: 3),
            );
          }
        }

        // Update the schedule status to cancelled and reset attendance
        final cancelledSchedule = currentSchedule.copyWith(
          status: 'Cancelled',
          attended: false,
        );

        await controller.addOrUpdateSchedule(cancelledSchedule);

        Get.back(); // Close dialog
        Get.snackbar(
          'Lesson Cancelled',
          'The lesson has been cancelled successfully',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to cancel lesson: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  // Helper methods for attendance status display
  Color _getAttendanceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getAttendanceStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Icons.access_time;
      case 'completed':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getAttendanceStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return 'Lesson In Progress';
      case 'completed':
        return 'Lesson Completed';
      case 'absent':
        return 'Student Absent';
      default:
        return 'Attendance Marked';
    }
  }
}
