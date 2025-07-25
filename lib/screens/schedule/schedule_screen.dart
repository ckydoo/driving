// lib/screens/schedule/schedule_screen.dart
import 'package:driving/screens/schedule/create_schedule_screen.dart';
import 'package:driving/screens/schedule/recurring_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';
import '../../models/schedule.dart';
import '../../models/user.dart';
import '../../models/course.dart';
import '../../models/fleet.dart';

class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Controllers
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final FleetController fleetController = Get.find<FleetController>();

  // Calendar state
  final ValueNotifier<DateTime> _focusedDay = ValueNotifier(DateTime.now());
  final ValueNotifier<DateTime> _selectedDay = ValueNotifier(DateTime.now());
  String _currentView = 'month';

  // Filter state
  String? _selectedInstructorFilter;
  String? _selectedStudentFilter;
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    // Ensure data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  Future<void> _loadAllData() async {
    await scheduleController.fetchSchedules();
    await userController.fetchUsers();
    await courseController.fetchCourses();
    await fleetController.fetchFleet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _currentView == 'list'
                ? _buildListView()
                : _buildCalendarView(),
          ),
        ],
      ),
      floatingActionButton: _buildFABWithOptions(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _previousPeriod,
            icon: Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                _getHeaderText(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _nextPeriod,
            icon: Icon(Icons.chevron_right),
          ),
          IconButton(
            onPressed: _showDatePicker,
            icon: Icon(Icons.today),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.view_module),
            onSelected: (value) {
              setState(() {
                _currentView = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'month', child: Text('Month View')),
              PopupMenuItem(value: 'week', child: Text('Week View')),
              PopupMenuItem(value: 'day', child: Text('Day View')),
              PopupMenuItem(value: 'list', child: Text('List View')),
            ],
          ),
          IconButton(
            onPressed: _refreshData,
            icon: Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _showSearchDialog,
            icon: Icon(Icons.search),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown(
              'Instructor',
              _selectedInstructorFilter,
              _getInstructorOptions(),
              (value) => setState(() => _selectedInstructorFilter = value),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildFilterDropdown(
              'Student',
              _selectedStudentFilter,
              _getStudentOptions(),
              (value) => setState(() => _selectedStudentFilter = value),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildFilterDropdown(
              'Status',
              _selectedStatusFilter,
              ['Scheduled', 'Completed', 'Cancelled', 'In Progress'],
              (value) => setState(() => _selectedStatusFilter = value),
            ),
          ),
          if (_hasActiveFilters())
            TextButton(
              onPressed: _clearFilters,
              child: Text('Clear (${_getFilteredCount()}/${_getTotalCount()})'),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      value: value,
      items: [
        DropdownMenuItem<String>(value: null, child: Text('All')),
        ...options.map((option) => DropdownMenuItem(
              value: option,
              child: Text(option),
            )),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildCalendarView() {
    return Obx(() {
      if (scheduleController.isLoading.value) {
        return Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: TableCalendar<Schedule>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay.value,
              calendarFormat: _getCalendarFormat(),
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.red.shade400),
                holidayTextStyle: TextStyle(color: Colors.red.shade400),
                markerDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) {
                setState(() {
                  switch (format) {
                    case CalendarFormat.month:
                      _currentView = 'month';
                      break;
                    case CalendarFormat.twoWeeks:
                    case CalendarFormat.week:
                      _currentView = 'week';
                      break;
                  }
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay.value = focusedDay;
              },
            ),
          ),
          Expanded(
            child: _buildDayScheduleList(),
          ),
        ],
      );
    });
  }

  Widget _buildDayScheduleList() {
    return Obx(() {
      final dayEvents = _getEventsForDay(_selectedDay.value);

      if (dayEvents.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 60, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                'No lessons scheduled for ${DateFormat('MMM d, yyyy').format(_selectedDay.value)}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: dayEvents.length,
        itemBuilder: (context, index) {
          return _buildScheduleCard(dayEvents[index]);
        },
      );
    });
  }

  Widget _buildListView() {
    return Obx(() {
      if (scheduleController.isLoading.value) {
        return Center(child: CircularProgressIndicator());
      }

      final filteredSchedules = _getFilteredSchedules();

      if (filteredSchedules.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 60, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                'No schedules found matching your filters',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      }

      // Group schedules by date
      final groupedSchedules = <DateTime, List<Schedule>>{};
      for (final schedule in filteredSchedules) {
        final date = DateTime(
          schedule.start.year,
          schedule.start.month,
          schedule.start.day,
        );
        groupedSchedules.putIfAbsent(date, () => []).add(schedule);
      }

      final sortedDates = groupedSchedules.keys.toList()..sort();

      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final daySchedules = groupedSchedules[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(date),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${daySchedules.length} lesson${daySchedules.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              ...daySchedules
                  .map((schedule) => _buildScheduleCard(schedule))
                  .toList(),
              SizedBox(height: 16),
            ],
          );
        },
      );
    });
  }

  Widget _buildScheduleCard(Schedule schedule) {
    final student = _getStudentById(schedule.studentId);
    final instructor = _getInstructorById(schedule.instructorId);
    final course = _getCourseById(schedule.courseId);
    final vehicle =
        schedule.carId != null ? _getVehicleById(schedule.carId!) : null;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showScheduleDetails(schedule),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _getStatusColor(schedule.status),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course?.name ?? 'Unknown Course',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      _buildInfoChip(
                          Icons.person, student?.fname ?? 'Unknown Student'),
                      SizedBox(width: 8),
                      _buildInfoChip(Icons.school,
                          instructor?.fname ?? 'Unknown Instructor'),
                      if (vehicle != null) ...[
                        SizedBox(width: 8),
                        _buildInfoChip(Icons.directions_car, vehicle.carPlate),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _buildStatusBadge(schedule.status),
                if (schedule.attended)
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Attended',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          SizedBox(width: 4),
          Text(
            text.length > 10 ? '${text.substring(0, 10)}...' : text,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildFABWithOptions() {
    return FloatingActionButton.extended(
      onPressed: _showCreateOptions,
      icon: Icon(Icons.add),
      label: Text('New Lesson'),
    );
  }

  // Helper methods for getting data
  User? _getStudentById(int id) {
    return userController.users.firstWhereOrNull(
      (user) => user.id == id && user.role.toLowerCase() == 'student',
    );
  }

  User? _getInstructorById(int id) {
    return userController.users.firstWhereOrNull(
      (user) => user.id == id && user.role.toLowerCase() == 'instructor',
    );
  }

  Course? _getCourseById(int id) {
    return courseController.courses.firstWhereOrNull(
      (course) => course.id == id,
    );
  }

  Fleet? _getVehicleById(int id) {
    return fleetController.fleet.firstWhereOrNull(
      (vehicle) => vehicle.id == id,
    );
  }

  List<String> _getInstructorOptions() {
    return userController.users
        .where((user) => user.role.toLowerCase() == 'instructor')
        .map((user) => '${user.fname} ${user.lname}')
        .toList();
  }

  List<String> _getStudentOptions() {
    return userController.users
        .where((user) => user.role.toLowerCase() == 'student')
        .map((user) => '${user.fname} ${user.lname}')
        .toList();
  }

  List<Schedule> _getEventsForDay(DateTime day) {
    return _getFilteredSchedules().where((schedule) {
      return isSameDay(schedule.start, day);
    }).toList();
  }

  List<Schedule> _getFilteredSchedules() {
    return scheduleController.schedules.where((schedule) {
      // Filter by instructor
      if (_selectedInstructorFilter != null) {
        final instructor = _getInstructorById(schedule.instructorId);
        final instructorName =
            instructor != null ? '${instructor.fname} ${instructor.lname}' : '';
        if (instructorName != _selectedInstructorFilter) {
          return false;
        }
      }

      // Filter by student
      if (_selectedStudentFilter != null) {
        final student = _getStudentById(schedule.studentId);
        final studentName =
            student != null ? '${student.fname} ${student.lname}' : '';
        if (studentName != _selectedStudentFilter) {
          return false;
        }
      }

      // Filter by status
      if (_selectedStatusFilter != null) {
        if (schedule.status != _selectedStatusFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool _hasActiveFilters() {
    return _selectedInstructorFilter != null ||
        _selectedStudentFilter != null ||
        _selectedStatusFilter != null;
  }

  int _getFilteredCount() {
    return _getFilteredSchedules().length;
  }

  int _getTotalCount() {
    return scheduleController.schedules.length;
  }

  void _clearFilters() {
    setState(() {
      _selectedInstructorFilter = null;
      _selectedStudentFilter = null;
      _selectedStatusFilter = null;
    });
  }

  // Event handlers
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay.value = selectedDay;
      _focusedDay.value = focusedDay;
    });
  }

  void _previousPeriod() {
    switch (_currentView) {
      case 'week':
        _focusedDay.value = _focusedDay.value.subtract(Duration(days: 7));
        break;
      case 'day':
        _focusedDay.value = _focusedDay.value.subtract(Duration(days: 1));
        break;
      default:
        _focusedDay.value =
            DateTime(_focusedDay.value.year, _focusedDay.value.month - 1);
    }
  }

  void _nextPeriod() {
    switch (_currentView) {
      case 'week':
        _focusedDay.value = _focusedDay.value.add(Duration(days: 7));
        break;
      case 'day':
        _focusedDay.value = _focusedDay.value.add(Duration(days: 1));
        break;
      default:
        _focusedDay.value =
            DateTime(_focusedDay.value.year, _focusedDay.value.month + 1);
    }
  }

  void _refreshData() {
    _loadAllData();
    Get.snackbar('Info', 'Refreshing schedule data...');
  }

  void _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _focusedDay.value,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2030),
    );
    if (date != null) {
      _focusedDay.value = date;
      _selectedDay.value = date;
    }
  }

  void _showSearchDialog() {
    TextEditingController searchController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text('Search Schedule'),
        content: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search by student, instructor, or course...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement search functionality
              _performSearch(searchController.text);
              Get.back();
            },
            child: Text('Search'),
          ),
        ],
      ),
    );
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;

    // Find matching schedules and navigate to them
    final matchingSchedules = scheduleController.schedules.where((schedule) {
      final student = _getStudentById(schedule.studentId);
      final instructor = _getInstructorById(schedule.instructorId);
      final course = _getCourseById(schedule.courseId);

      final searchText = query.toLowerCase();
      return (student?.fname.toLowerCase().contains(searchText) ?? false) ||
          (student?.lname.toLowerCase().contains(searchText) ?? false) ||
          (instructor?.fname.toLowerCase().contains(searchText) ?? false) ||
          (instructor?.lname.toLowerCase().contains(searchText) ?? false) ||
          (course?.name.toLowerCase().contains(searchText) ?? false);
    }).toList();

    if (matchingSchedules.isNotEmpty) {
      // Navigate to the first match
      final firstMatch = matchingSchedules.first;
      _selectedDay.value = firstMatch.start;
      _focusedDay.value = firstMatch.start;
      setState(() {
        _currentView = 'day';
      });
      Get.snackbar(
          'Search Results', '${matchingSchedules.length} schedules found');
    } else {
      Get.snackbar('No Results', 'No schedules found matching "$query"');
    }
  }

  void _showCreateOptions() {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.add_circle, color: Colors.blue),
              title: Text('Schedule Single Lesson'),
              subtitle: Text('Create a one-time lesson'),
              onTap: () {
                Get.back();
                _showCreateScheduleDialog(false);
              },
            ),
            ListTile(
              leading: Icon(Icons.repeat, color: Colors.green),
              title: Text('Schedule Recurring Lessons'),
              subtitle: Text('Create recurring lessons'),
              onTap: () {
                Get.back();
                _showCreateScheduleDialog(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateScheduleDialog(bool isRecurring) {
    if (isRecurring) {
      Get.to(() => RecurringScheduleScreen());
    } else {
      Get.to(() => SingleScheduleScreen());
    }
  }

  void _showScheduleDetails(Schedule schedule) {
    final student = _getStudentById(schedule.studentId);
    final instructor = _getInstructorById(schedule.instructorId);
    final course = _getCourseById(schedule.courseId);
    final vehicle =
        schedule.carId != null ? _getVehicleById(schedule.carId!) : null;

    Get.dialog(
      AlertDialog(
        title: Text('Schedule Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Course', course?.name ?? 'Unknown'),
              _buildDetailRow(
                  'Student',
                  student != null
                      ? '${student.fname} ${student.lname}'
                      : 'Unknown'),
              _buildDetailRow(
                  'Instructor',
                  instructor != null
                      ? '${instructor.fname} ${instructor.lname}'
                      : 'Unknown'),
              _buildDetailRow('Date',
                  DateFormat('EEEE, MMMM d, yyyy').format(schedule.start)),
              _buildDetailRow('Time',
                  '${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)}'),
              _buildDetailRow('Duration', schedule.duration),
              _buildDetailRow('Type', schedule.classType),
              _buildDetailRow('Status', schedule.status),
              if (vehicle != null)
                _buildDetailRow('Vehicle',
                    '${vehicle.make} ${vehicle.model} (${vehicle.carPlate})'),
              if (schedule.attended) _buildDetailRow('Attendance', 'Attended'),
              _buildDetailRow(
                  'Lessons Completed', '${schedule.lessonsCompleted}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text('Close'),
          ),
          if (schedule.status != 'Cancelled')
            ElevatedButton(
              onPressed: () {
                Get.back();
                _showEditScheduleDialog(schedule);
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
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showEditScheduleDialog(Schedule schedule) {
    Get.snackbar('Info', 'Edit schedule dialog would open here');
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  CalendarFormat _getCalendarFormat() {
    switch (_currentView) {
      case 'week':
        return CalendarFormat.week;
      case 'day':
        return CalendarFormat.week; // TableCalendar doesn't have day format
      default:
        return CalendarFormat.month;
    }
  }

  String _getHeaderText() {
    switch (_currentView) {
      case 'week':
        return 'Week of ${DateFormat('MMM d').format(_focusedDay.value)}';
      case 'day':
        return DateFormat('EEEE, MMMM d').format(_focusedDay.value);
      case 'list':
        return 'All Schedules';
      default:
        return DateFormat('MMMM yyyy').format(_focusedDay.value);
    }
  }

  @override
  void dispose() {
    _focusedDay.dispose();
    _selectedDay.dispose();
    super.dispose();
  }
}
