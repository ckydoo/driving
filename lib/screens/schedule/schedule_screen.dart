// lib/screens/schedule/schedule_screen.dart
import 'dart:async';

import 'package:driving/screens/schedule/create_schedule_screen.dart';
import 'package:driving/screens/schedule/daily_lessons.dart';
import 'package:driving/screens/schedule/recurring_schedule_screen.dart';
import 'package:driving/widgets/schedule_details_dialog.dart';
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

// Updated Schedule Screen - Calendar Only with Filtered Dialog

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
            child: _buildCalendarView(), // Only calendar view now
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

      return Container(
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
            // Highlight days with filtered events
            markersMaxCount: 3,
            markerMargin: EdgeInsets.symmetric(horizontal: 1.5),
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
      );
    });
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

  String _getActiveFilterText() {
    List<String> activeFilters = [];

    if (_selectedInstructorFilter != null) {
      activeFilters.add('Instructor: $_selectedInstructorFilter');
    }
    if (_selectedStudentFilter != null) {
      activeFilters.add('Student: $_selectedStudentFilter');
    }
    if (_selectedStatusFilter != null) {
      activeFilters.add('Status: $_selectedStatusFilter');
    }

    return activeFilters.isEmpty ? 'All Schedules' : activeFilters.join(' • ');
  }

  // Event handlers
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // Get filtered schedules for the selected day
    final filteredSchedules = _getFilteredSchedules().where((schedule) {
      return isSameDay(schedule.start, selectedDay);
    }).toList();

    Get.dialog(
      FilteredDateLessonsDialog(
        selectedDate: selectedDay,
        schedules: filteredSchedules,
        filterText: _getActiveFilterText(),
        hasActiveFilters: _hasActiveFilters(),
      ),
      barrierDismissible: true,
    );
  }

  void _previousPeriod() {
    switch (_currentView) {
      case 'week':
        _focusedDay.value = _focusedDay.value.subtract(Duration(days: 7));
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
      final firstMatch = matchingSchedules.first;
      _selectedDay.value = firstMatch.start;
      _focusedDay.value = firstMatch.start;
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

  CalendarFormat _getCalendarFormat() {
    switch (_currentView) {
      case 'week':
        return CalendarFormat.week;
      default:
        return CalendarFormat.month;
    }
  }

  String _getHeaderText() {
    switch (_currentView) {
      case 'week':
        return 'Week of ${DateFormat('MMM d').format(_focusedDay.value)}';
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

class ScheduleProgressMonitor {
  static Timer? _timer;
  static final ScheduleController _scheduleController =
      Get.find<ScheduleController>();

  static void startMonitoring() {
    // Check every minute for lesson progress updates
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _scheduleController.updateLessonProgress();
    });
  }

  static void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }
}
