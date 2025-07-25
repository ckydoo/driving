// lib/screens/schedule/attendance_management_screen.dart
import 'package:driving/screens/schedule/enhanced_schedule_form.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/enhanced_schedule.dart';
import '../../controllers/enhanced_schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';

class AttendanceManagementScreen extends StatefulWidget {
  @override
  _AttendanceManagementScreenState createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  final _scheduleController = Get.find<EnhancedScheduleController>();
  final _userController = Get.find<UserController>();
  final _courseController = Get.find<CourseController>();

  DateTime _selectedDate = DateTime.now();
  String _filterStatus = 'all';
  String _filterInstructor = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Management'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _scheduleController.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: Obx(() => _scheduleController.isLoading.value
                ? Center(child: CircularProgressIndicator())
                : _buildAttendanceList()),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.purple),
                SizedBox(width: 8),
                Text(DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Spacer(),
                TextButton(
                  onPressed: _selectDate,
                  child: Text('Change Date'),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterStatus,
                    decoration: InputDecoration(
                      labelText: 'Filter by Status',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'attended', child: Text('Attended')),
                      DropdownMenuItem(value: 'absent', child: Text('Absent')),
                    ],
                    onChanged: (value) =>
                        setState(() => _filterStatus = value!),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterInstructor,
                    decoration: InputDecoration(
                      labelText: 'Filter by Instructor',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Instructors')),
                      ..._userController.users
                          .where((u) => u.role == 'instructor')
                          .map((instructor) => DropdownMenuItem(
                                value: instructor.id.toString(),
                                child: Text(
                                    '${instructor.fname} ${instructor.lname}'),
                              )),
                    ],
                    onChanged: (value) =>
                        setState(() => _filterInstructor = value!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    final filteredSchedules = _getFilteredSchedules();

    if (filteredSchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No schedules found for selected date',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _selectedDate = DateTime.now()),
              child: Text('Go to Today'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: filteredSchedules.length,
      itemBuilder: (context, index) {
        final schedule = filteredSchedules[index];
        return _buildAttendanceCard(schedule);
      },
    );
  }

  Widget _buildAttendanceCard(EnhancedSchedule schedule) {
    final student = _userController.users
        .firstWhereOrNull((u) => u.id == schedule.studentId);
    final instructor = _userController.users
        .firstWhereOrNull((u) => u.id == schedule.instructorId);
    final course = _courseController.courses
        .firstWhereOrNull((c) => c.id == schedule.courseId);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(schedule.attendanceStatus),
          child: Icon(
            _getStatusIcon(schedule.attendanceStatus),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
            '${student?.fname ?? 'Unknown'} ${student?.lname ?? 'Student'}',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.book, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                    '${course?.name ?? 'Unknown Course'} • ${schedule.classType}'),
              ],
            ),
            SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                    '${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? 'Instructor'}'),
              ],
            ),
            SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                    '${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)}'),
                SizedBox(width: 16),
                Icon(Icons.school, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                    '${schedule.lessonsDeducted} lesson${schedule.lessonsDeducted > 1 ? 's' : ''}'),
              ],
            ),
          ],
        ),
        trailing: schedule.canEditAttendance
            ? PopupMenuButton<AttendanceStatus>(
                icon: Icon(Icons.more_vert),
                onSelected: (status) => _updateAttendance(schedule, status),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: AttendanceStatus.attended,
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Mark Attended'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: AttendanceStatus.absent,
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Mark Absent'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: AttendanceStatus.pending,
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text('Mark Pending'),
                      ],
                    ),
                  ),
                ],
              )
            : Chip(
                label: Text(
                  schedule.attendanceStatus
                      .toString()
                      .split('.')
                      .last
                      .capitalizeFirst!,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: _getStatusColor(schedule.attendanceStatus),
              ),
        onTap: () => _showScheduleDetails(schedule),
      ),
    );
  }

  List<EnhancedSchedule> _getFilteredSchedules() {
    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    return _scheduleController.filteredSchedules.where((schedule) {
      // Date filter
      if (schedule.start.isBefore(startOfDay) ||
          schedule.start.isAfter(endOfDay)) {
        return false;
      }

      // Status filter
      if (_filterStatus != 'all' &&
          schedule.attendanceStatus.toString().split('.').last !=
              _filterStatus) {
        return false;
      }

      // Instructor filter
      if (_filterInstructor != 'all' &&
          schedule.instructorId.toString() != _filterInstructor) {
        return false;
      }

      return schedule.status != 'Cancelled';
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.attended:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.pending:
        return Colors.amber;
      case AttendanceStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.attended:
        return Icons.check_circle;
      case AttendanceStatus.absent:
        return Icons.cancel;
      case AttendanceStatus.pending:
        return Icons.access_time;
      case AttendanceStatus.cancelled:
        return Icons.block;
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  void _updateAttendance(
      EnhancedSchedule schedule, AttendanceStatus newStatus) {
    // Show confirmation dialog for important actions
    if (newStatus == AttendanceStatus.attended) {
      Get.dialog(
        AlertDialog(
          title: Text('Confirm Attendance'),
          content: Text(
              'Mark this lesson as attended? This will deduct ${schedule.lessonsDeducted} lesson(s) from the student\'s balance.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                _scheduleController.updateAttendance(schedule.id!, newStatus);
              },
              child: Text('Confirm'),
            ),
          ],
        ),
      );
    } else {
      _scheduleController.updateAttendance(schedule.id!, newStatus);
    }
  }

  void _showScheduleDetails(EnhancedSchedule schedule) {
    final student = _userController.users
        .firstWhereOrNull((u) => u.id == schedule.studentId);
    final instructor = _userController.users
        .firstWhereOrNull((u) => u.id == schedule.instructorId);
    final course = _courseController.courses
        .firstWhereOrNull((c) => c.id == schedule.courseId);

    Get.dialog(
      AlertDialog(
        title: Text('Schedule Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Student',
                  '${student?.fname ?? 'Unknown'} ${student?.lname ?? ''}'),
              _buildDetailRow('Course', course?.name ?? 'Unknown Course'),
              _buildDetailRow('Instructor',
                  '${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? ''}'),
              _buildDetailRow(
                  'Date', DateFormat('MMM dd, yyyy').format(schedule.start)),
              _buildDetailRow('Time',
                  '${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)}'),
              _buildDetailRow('Duration', schedule.duration),
              _buildDetailRow('Type', schedule.classType),
              _buildDetailRow('Status', schedule.status),
              _buildDetailRow(
                  'Attendance',
                  schedule.attendanceStatus
                      .toString()
                      .split('.')
                      .last
                      .capitalizeFirst!),
              _buildDetailRow(
                  'Lessons Deducted', schedule.lessonsDeducted.toString()),
              if (schedule.notes != null && schedule.notes!.isNotEmpty)
                _buildDetailRow('Notes', schedule.notes!),
              if (schedule.isRecurring)
                _buildDetailRow(
                    'Recurring', 'Yes (${schedule.recurrencePattern})'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
          if (schedule.canReschedule)
            TextButton(
              onPressed: () {
                Get.back();
                _rescheduleSession(schedule);
              },
              child: Text('Reschedule'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label + ':',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _rescheduleSession(EnhancedSchedule schedule) {
    // Navigate to reschedule form
    Get.to(() => EnhancedScheduleForm(existingSchedule: schedule))
        ?.then((result) {
      if (result == true) {
        setState(() {}); // Refresh the list
      }
    });
  }
}
