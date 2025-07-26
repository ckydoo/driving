// lib/widgets/schedule_details_dialog.dart
import 'package:driving/screens/schedule/create_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../models/fleet.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/user_controller.dart';
import '../controllers/course_controller.dart';
import '../controllers/fleet_controller.dart';
import '../controllers/billing_controller.dart';

class ScheduleDetailsDialog extends StatelessWidget {
  final Schedule schedule;

  const ScheduleDetailsDialog({Key? key, required this.schedule})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final courseController = Get.find<CourseController>();
    final fleetController = Get.find<FleetController>();
    final scheduleController = Get.find<ScheduleController>();
    final billingController = Get.find<BillingController>();

    final student = userController.users.firstWhereOrNull(
      (user) =>
          user.id == schedule.studentId && user.role.toLowerCase() == 'student',
    );
    final instructor = userController.users.firstWhereOrNull(
      (user) =>
          user.id == schedule.instructorId &&
          user.role.toLowerCase() == 'instructor',
    );
    final course = courseController.courses.firstWhereOrNull(
      (c) => c.id == schedule.courseId,
    );
    final vehicle = schedule.carId != null
        ? fleetController.fleet.firstWhereOrNull((v) => v.id == schedule.carId)
        : null;

    // Get billing information
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) =>
          inv.studentId == schedule.studentId &&
          inv.courseId == schedule.courseId,
    );

    final usedLessons = scheduleController.schedules
        .where((s) =>
            s.studentId == schedule.studentId &&
            s.courseId == schedule.courseId &&
            s.attended)
        .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

    final remainingLessons =
        invoice != null ? invoice.lessons - usedLessons : 0;

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
                color: _getStatusColor(schedule.status),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(schedule.status),
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
                          schedule.status.toUpperCase(),
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
                                .format(schedule.start)),
                        _buildInfoRow('Start Time',
                            DateFormat('HH:mm').format(schedule.start)),
                        _buildInfoRow('End Time',
                            DateFormat('HH:mm').format(schedule.end)),
                        _buildInfoRow('Duration', schedule.duration),
                        _buildInfoRow('Class Type', schedule.classType),
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
                          _buildInfoRow('Lesson Status',
                              schedule.attended ? 'Attended' : 'Not Attended'),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],

                    // Progress Section
                    if (schedule.attended ||
                        schedule.status == 'Completed') ...[
                      _buildInfoSection(
                        'Progress',
                        Icons.trending_up,
                        Colors.teal,
                        [
                          _buildInfoRow('Lessons Completed',
                              '${schedule.lessonsCompleted}'),
                          _buildInfoRow('Progress',
                              '${(schedule.progress * 100).toStringAsFixed(1)}%'),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],

                    // Notes Section (if needed)
                    if (schedule.isRecurring) ...[
                      _buildInfoSection(
                        'Recurrence',
                        Icons.repeat,
                        Colors.indigo,
                        [
                          _buildInfoRow('Pattern',
                              schedule.recurrencePattern?.capitalize ?? 'N/A'),
                          if (schedule.recurrenceEndDate != null)
                            _buildInfoRow(
                              'End Date',
                              DateFormat('MMM dd, yyyy')
                                  .format(schedule.recurrenceEndDate!),
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
                  // Attendance Actions (for instructors)
                  if (schedule.status != 'Cancelled' && !schedule.attended) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _markAttendance(true, scheduleController),
                            icon: Icon(Icons.check_circle, size: 18),
                            label: Text('Mark Attended'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _markAttendance(false, scheduleController),
                            icon: Icon(Icons.cancel, size: 18),
                            label: Text('Mark Absent'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                  ],

                  // Management Actions
                  if (schedule.status != 'Cancelled') ...[
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

                  // Cancel Action
                  if (schedule.status != 'Cancelled') ...[
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
      default:
        return Icons.schedule;
    }
  }

  Future<void> _markAttendance(
      bool attended, ScheduleController controller) async {
    try {
      await controller.toggleAttendance(schedule.id!, attended);
      Get.back(); // Close dialog
      Get.snackbar(
        'Success',
        attended ? 'Lesson marked as attended' : 'Lesson marked as absent',
        backgroundColor: attended ? Colors.green : Colors.orange,
        colorText: Colors.white,
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
    Get.to(() => SingleScheduleScreen(existingSchedule: schedule));
  }

  void _rescheduleLesson() {
    Get.back(); // Close dialog
    // Create a copy of the schedule for rescheduling
    final rescheduleSchedule = schedule.copyWith(
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
        content: Text(
            'Are you sure you want to cancel this lesson? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('Yes, Cancel'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await controller.cancelSchedule(schedule.id!);
        Get.back(); // Close dialog
        Get.snackbar(
          'Success',
          'Lesson cancelled successfully',
          backgroundColor: Colors.green,
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
}
