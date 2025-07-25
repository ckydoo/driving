// lib/screens/schedule/enhanced_schedule_dashboard.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/enhanced_schedule.dart';
import '../../controllers/enhanced_schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import 'enhanced_schedule_form.dart';
import 'attendance_management_screen.dart';

class EnhancedScheduleDashboard extends StatefulWidget {
  @override
  _EnhancedScheduleDashboardState createState() =>
      _EnhancedScheduleDashboardState();
}

class _EnhancedScheduleDashboardState extends State<EnhancedScheduleDashboard> {
  final _scheduleController = Get.find<EnhancedScheduleController>();
  final _userController = Get.find<UserController>();
  final _courseController = Get.find<CourseController>();

  late final ValueNotifier<List<EnhancedSchedule>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));

    // Listen to schedule changes and update events
    ever(_scheduleController.filteredSchedules,
        (List<EnhancedSchedule> schedules) {
      if (mounted) {
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      }
    });
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<EnhancedSchedule> _getEventsForDay(DateTime day) {
    return _scheduleController.getSchedulesForDay(day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: Icon(Icons.assignment_turned_in),
            onPressed: () => Get.to(() => AttendanceManagementScreen()),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              PopupMenuItem(value: 'today', child: Text('Go to Today')),
              PopupMenuItem(value: 'filters', child: Text('Filters')),
              PopupMenuItem(value: 'stats', child: Text('Statistics')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildQuickStats(),
            _buildCalendar(),
            _buildEventsList(),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "recurring",
            onPressed: () => _createSchedule(true),
            backgroundColor: Colors.green,
            child: Icon(Icons.repeat, color: Colors.white),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "single",
            onPressed: () => _createSchedule(false),
            backgroundColor: Colors.blue,
            child: Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Obx(() {
      final stats = _scheduleController.getTodayStats();

      return Card(
        margin: EdgeInsets.all(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Today\'s Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                      'Total', stats['total'].toString(), Colors.blue),
                  _buildStatItem(
                      'Attended', stats['attended'].toString(), Colors.green),
                  _buildStatItem(
                      'Pending', stats['pending'].toString(), Colors.amber),
                  _buildStatItem(
                      'Absent', stats['absent'].toString(), Colors.red),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCalendar() {
    return Obx(() {
      // Access the observable to trigger rebuilds
      _scheduleController
          .filteredSchedules.length; // This ensures Obx tracks the observable

      return TableCalendar<EnhancedSchedule>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        eventLoader: _getEventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          markerDecoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          markerSize: 6,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(16),
          ),
          formatButtonTextStyle: TextStyle(color: Colors.white),
        ),
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() => _calendarFormat = format);
          }
        },
        onPageChanged: (focusedDay) => _focusedDay = focusedDay,
      );
    });
  }

  Widget _buildEventsList() {
    return ValueListenableBuilder<List<EnhancedSchedule>>(
      valueListenable: _selectedEvents,
      builder: (context, events, _) {
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                    'No schedules for ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _createSchedule(false),
                  icon: Icon(Icons.add),
                  label: Text('Create Schedule'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(8),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final schedule = events[index];
            return _buildScheduleCard(schedule);
          },
        );
      },
    );
  }

  Widget _buildScheduleCard(EnhancedSchedule schedule) {
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
          child: Text(
            DateFormat('HH:mm').format(schedule.start),
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
        title: Text(
            '${student?.fname ?? 'Unknown'} ${student?.lname ?? 'Student'}',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('${course?.name ?? 'Unknown Course'} • ${schedule.classType}'),
            Text(
                '${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? 'Instructor'}'),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                    '${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)}'),
                SizedBox(width: 16),
                if (schedule.isRecurring) ...[
                  Icon(Icons.repeat, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Recurring',
                      style: TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleScheduleAction(value, schedule),
          itemBuilder: (context) => [
            if (schedule.canEditAttendance) ...[
              PopupMenuItem(value: 'attend', child: Text('Mark Attended')),
              PopupMenuItem(value: 'absent', child: Text('Mark Absent')),
            ],
            if (schedule.canReschedule)
              PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
            PopupMenuItem(value: 'details', child: Text('View Details')),
            PopupMenuItem(
                value: 'cancel',
                child: Text('Cancel', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => _showScheduleDetails(schedule),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.attended:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.pending:
        return Colors.blue;
      case AttendanceStatus.cancelled:
        return Colors.grey;
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'refresh':
        _scheduleController.refresh();
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
        break;
      case 'today':
        setState(() {
          _selectedDay = DateTime.now();
          _focusedDay = DateTime.now();
        });
        _selectedEvents.value = _getEventsForDay(DateTime.now());
        break;
      case 'filters':
        _showFiltersDialog();
        break;
      case 'stats':
        _showStatsDialog();
        break;
    }
  }

  void _handleScheduleAction(String action, EnhancedSchedule schedule) {
    switch (action) {
      case 'attend':
        _scheduleController.updateAttendance(
            schedule.id!, AttendanceStatus.attended);
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
        break;
      case 'absent':
        _scheduleController.updateAttendance(
            schedule.id!, AttendanceStatus.absent);
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
        break;
      case 'reschedule':
        Get.to(() => EnhancedScheduleForm(existingSchedule: schedule))
            ?.then((result) {
          if (result == true) {
            _selectedEvents.value = _getEventsForDay(_selectedDay!);
          }
        });
        break;
      case 'details':
        _showScheduleDetails(schedule);
        break;
      case 'cancel':
        _showCancelConfirmation(schedule);
        break;
    }
  }

  void _createSchedule(bool isRecurring) {
    Get.to(() => EnhancedScheduleForm(isRecurring: isRecurring))
        ?.then((result) {
      if (result == true) {
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      }
    });
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
                Get.to(() => EnhancedScheduleForm(existingSchedule: schedule));
              },
              child: Text('Edit'),
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

  void _showCancelConfirmation(EnhancedSchedule schedule) {
    Get.dialog(
      AlertDialog(
        title: Text('Cancel Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to cancel this schedule?'),
            if (schedule.isRecurring) ...[
              SizedBox(height: 16),
              Text(
                  'This is part of a recurring series. What would you like to do?'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Keep'),
          ),
          if (schedule.isRecurring) ...[
            TextButton(
              onPressed: () {
                Get.back();
                _scheduleController.cancelSchedule(schedule.id!,
                    cancelAllRecurring: false);
                _selectedEvents.value = _getEventsForDay(_selectedDay!);
              },
              child: Text('Cancel This Only'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                _scheduleController.cancelSchedule(schedule.id!,
                    cancelAllRecurring: true);
                _selectedEvents.value = _getEventsForDay(_selectedDay!);
              },
              child: Text('Cancel All Recurring',
                  style: TextStyle(color: Colors.red)),
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                Get.back();
                _scheduleController.cancelSchedule(schedule.id!);
                _selectedEvents.value = _getEventsForDay(_selectedDay!);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  void _showSearchDialog() {
    String searchQuery = '';
    Get.dialog(
      AlertDialog(
        title: Text('Search Schedules'),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Enter student or instructor name...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => searchQuery = value,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _scheduleController.searchSchedules(searchQuery);
            },
            child: Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showFiltersDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Filter Schedules'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() => DropdownButtonFormField<String>(
                    value: _scheduleController
                            .selectedInstructorFilter.value.isEmpty
                        ? 'all'
                        : _scheduleController.selectedInstructorFilter.value,
                    decoration: InputDecoration(
                      labelText: 'Instructor',
                      border: OutlineInputBorder(),
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
                    onChanged: (value) {
                      _scheduleController.selectedInstructorFilter.value =
                          value == 'all' ? '' : value!;
                    },
                  )),
              SizedBox(height: 16),
              Obx(() => DropdownButtonFormField<String>(
                    value:
                        _scheduleController.selectedStudentFilter.value.isEmpty
                            ? 'all'
                            : _scheduleController.selectedStudentFilter.value,
                    decoration: InputDecoration(
                      labelText: 'Student',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Students')),
                      ..._userController.users
                          .where((u) => u.role == 'student')
                          .map((student) => DropdownMenuItem(
                                value: student.id.toString(),
                                child:
                                    Text('${student.fname} ${student.lname}'),
                              )),
                    ],
                    onChanged: (value) {
                      _scheduleController.selectedStudentFilter.value =
                          value == 'all' ? '' : value!;
                    },
                  )),
              SizedBox(height: 16),
              Obx(() => DropdownButtonFormField<String>(
                    value:
                        _scheduleController.selectedStatusFilter.value.isEmpty
                            ? 'all'
                            : _scheduleController.selectedStatusFilter.value,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(
                          value: 'Scheduled', child: Text('Scheduled')),
                      DropdownMenuItem(
                          value: 'Confirmed', child: Text('Confirmed')),
                      DropdownMenuItem(
                          value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'Cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (value) {
                      _scheduleController.selectedStatusFilter.value =
                          value == 'all' ? '' : value!;
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _scheduleController.clearFilters();
              Get.back();
            },
            child: Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog() {
    final stats = _scheduleController.getTodayStats();
    final upcomingSchedules = _scheduleController.getUpcomingSchedules();

    Get.dialog(
      AlertDialog(
        title: Text('Schedule Statistics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Today\'s Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Text('Total Lessons: ${stats['total']}'),
              Text('Attended: ${stats['attended']}',
                  style: TextStyle(color: Colors.green)),
              Text('Pending: ${stats['pending']}',
                  style: TextStyle(color: Colors.amber)),
              Text('Absent: ${stats['absent']}',
                  style: TextStyle(color: Colors.red)),
              SizedBox(height: 16),
              Text('Upcoming Lessons',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              if (upcomingSchedules.isEmpty)
                Text('No upcoming lessons scheduled',
                    style: TextStyle(color: Colors.grey))
              else
                ...upcomingSchedules.take(3).map((schedule) {
                  final student = _userController.users
                      .firstWhereOrNull((u) => u.id == schedule.studentId);
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${DateFormat('MMM dd, HH:mm').format(schedule.start)} - ${student?.fname ?? 'Unknown'} ${student?.lname ?? ''}',
                      style: TextStyle(fontSize: 12),
                    ),
                  );
                }),
            ],
          ),
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
