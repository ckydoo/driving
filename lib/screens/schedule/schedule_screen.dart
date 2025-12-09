import 'dart:async';
import 'package:driving/controllers/utils/responsive_utils.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/schedule/create_schedule_screen.dart';
import 'package:driving/screens/schedule/recurring_schedule_screen.dart';
import 'package:driving/screens/simplified_schedule_booking_screen.dart';
import 'package:driving/widgets/responsive_extensions.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:driving/widgets/schedule_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';
import '../../models/course.dart';
import '../../controllers/auth_controller.dart';

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
  final AuthController authController = Get.find<AuthController>();

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

    // Listen for route changes to refresh data
    _setupRouteListener();
  }

  void _setupRouteListener() {
    // Listen for when we return to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.rootDelegate.addListener(() {
        if (Get.currentRoute == '/schedule' ||
            Get.currentRoute == '/' && mounted) {
          // Refresh data when returning to schedule screen
          _refreshData();
        }
      });
    });
  }

  Future<void> _loadAllData() async {
    try {
      await Future.wait([
        scheduleController.fetchSchedules(),
        userController.fetchUsers(),
        courseController.fetchCourses(),
        fleetController.fetchFleet(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Failed to load some data. Please refresh.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildResponsiveHeader(),
          _buildResponsiveFilters(),
          Expanded(
            child: _buildResponsiveCalendarView(),
          ),
        ],
      ),
      floatingActionButton: _buildResponsiveFABWithOptions(),
    );
  }

  Widget _buildResponsiveHeader() {
    return Container(
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(14),
        desktop: const EdgeInsets.all(16),
      ),
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
      child: Column(
        children: [
          _buildResponsiveUserContextInfo(),
          SizedBox(
              height: ResponsiveUtils.getValue(context,
                  mobile: 6.0, tablet: 7.0, desktop: 8.0)),
          context.isMobile
              ? _buildMobileHeaderControls()
              : _buildDesktopHeaderControls(),
        ],
      ),
    );
  }

  Widget _buildResponsiveUserContextInfo() {
    final currentUser = authController.currentUser.value;
    if (currentUser == null) return const SizedBox.shrink();

    String contextText = '';
    Color contextColor = Colors.blue;
    IconData contextIcon = Icons.schedule;

    switch (currentUser.role.toLowerCase()) {
      case 'student':
        contextText = context.isMobile
            ? 'My Lessons'
            : 'My Lessons - ${currentUser.fname} ${currentUser.lname}';
        contextColor = Colors.green;
        contextIcon = Icons.school;
        break;
      case 'instructor':
        contextText = context.isMobile
            ? 'My Teaching Schedule'
            : 'My Teaching Schedule - ${currentUser.fname} ${currentUser.lname}';
        contextColor = Colors.orange;
        contextIcon = Icons.person;
        break;
      default:
        contextText =
            context.isMobile ? 'All Schedules' : 'All Schedules - Admin View';
        contextColor = Colors.blue;
        contextIcon = Icons.admin_panel_settings;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getValue(context,
            mobile: 8.0, tablet: 10.0, desktop: 12.0),
        vertical: ResponsiveUtils.getValue(context,
            mobile: 4.0, tablet: 5.0, desktop: 6.0),
      ),
      decoration: BoxDecoration(
        color: contextColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: contextColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(contextIcon,
              size: ResponsiveUtils.getValue(context,
                  mobile: 14.0, tablet: 15.0, desktop: 16.0),
              color: contextColor),
          const SizedBox(width: 6),
          Flexible(
            child: ResponsiveText(
              style: TextStyle(),
              contextText,
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 11.0, tablet: 11.5, desktop: 12.0),
              color: contextColor,
              fontWeight: FontWeight.w500,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeaderControls() {
    return Column(
      children: [
        // Navigation and View Controls Row
        Row(
          children: [
            IconButton(
              onPressed: _previousPeriod,
              icon: const Icon(Icons.chevron_left),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            Expanded(
              child: Center(
                child: ResponsiveText(
                  style: TextStyle(),
                  _getHeaderText(),
                  fontSize: ResponsiveUtils.getValue(context,
                      mobile: 16.0, tablet: 17.0, desktop: 18.0),
                  fontWeight: FontWeight.bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              onPressed: _nextPeriod,
              icon: const Icon(Icons.chevron_right),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Action Buttons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMobileActionButton(Icons.today, 'Today', _showDatePicker),
            _buildMobileActionButton(
                _currentView == 'month' ? Icons.view_week : Icons.view_module,
                _currentView == 'month' ? 'Week' : 'Month',
                _toggleView),
            _buildMobileActionButton(Icons.refresh, 'Refresh', _refreshData),
            _buildMobileActionButton(Icons.search, 'Search', _showSearchDialog),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopHeaderControls() {
    return Row(
      children: [
        IconButton(
          onPressed: _previousPeriod,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: ResponsiveText(
              style: TextStyle(),
              _getHeaderText(),
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 16.0, tablet: 17.0, desktop: 18.0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: _nextPeriod,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          onPressed: _showDatePicker,
          icon: const Icon(Icons.today),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.view_module),
          onSelected: (value) {
            setState(() {
              _currentView = value;
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'month', child: Text('Month View')),
            const PopupMenuItem(value: 'week', child: Text('Week View')),
          ],
        ),
        IconButton(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: _showSearchDialog,
          icon: const Icon(Icons.search),
        ),
      ],
    );
  }

  Widget _buildMobileActionButton(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          tooltip,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildResponsiveFilters() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getValue(context,
            mobile: 12.0, tablet: 14.0, desktop: 16.0),
        vertical: ResponsiveUtils.getValue(context,
            mobile: 6.0, tablet: 7.0, desktop: 8.0),
      ),
      child: context.isMobile ? _buildMobileFilters() : _buildDesktopFilters(),
    );
  }

  Widget _buildMobileFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildResponsiveFilterDropdown(
                'Instructor',
                _selectedInstructorFilter,
                _getInstructorOptions(),
                (value) => setState(() => _selectedInstructorFilter = value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildResponsiveFilterDropdown(
                'Student',
                _selectedStudentFilter,
                _getStudentOptions(),
                (value) => setState(() => _selectedStudentFilter = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildResponsiveFilterDropdown(
                'Status',
                _selectedStatusFilter,
                ['Scheduled', 'Completed', 'Cancelled', 'In Progress'],
                (value) => setState(() => _selectedStatusFilter = value),
              ),
            ),
            if (_hasActiveFilters())
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton(
                  onPressed: _clearFilters,
                  child: Text(
                    'Clear\n(${_getFilteredCount()}/${_getTotalCount()})',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildResponsiveFilterDropdown(
            'Instructor',
            _selectedInstructorFilter,
            _getInstructorOptions(),
            (value) => setState(() => _selectedInstructorFilter = value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildResponsiveFilterDropdown(
            'Student',
            _selectedStudentFilter,
            _getStudentOptions(),
            (value) => setState(() => _selectedStudentFilter = value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildResponsiveFilterDropdown(
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
    );
  }

  Widget _buildResponsiveFilterDropdown(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getValue(context,
              mobile: 8.0, tablet: 10.0, desktop: 12.0),
          vertical: ResponsiveUtils.getValue(context,
              mobile: 6.0, tablet: 7.0, desktop: 8.0),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: TextStyle(
        fontSize: ResponsiveUtils.getValue(context,
            mobile: 12.0, tablet: 13.0, desktop: 14.0),
        color: Colors.black,
      ),
      value: value,
      isExpanded: true,
      menuMaxHeight: 300,
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        ...options.map((option) => DropdownMenuItem(
              value: option,
              child: Text(
                option,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            )),
      ],
      selectedItemBuilder: (BuildContext context) {
        // Custom builder for selected item to handle overflow
        return [
          const Text('All', overflow: TextOverflow.ellipsis, maxLines: 1),
          ...options.map((option) => Text(
                option,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              )),
        ];
      },
      onChanged: onChanged,
    );
  }

  Widget _buildResponsiveCalendarView() {
    return Obx(() {
      if (scheduleController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
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
            weekendTextStyle: TextStyle(
              color: Colors.red.shade400,
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 12.0, tablet: 13.0, desktop: 14.0),
            ),
            holidayTextStyle: TextStyle(color: Colors.red.shade400),
            markerDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            markersMaxCount: 3,
            markerMargin: const EdgeInsets.symmetric(horizontal: 1.5),
            // Responsive text sizing
            defaultTextStyle: TextStyle(
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 12.0, tablet: 13.0, desktop: 14.0),
            ),
            outsideTextStyle: TextStyle(
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 12.0, tablet: 13.0, desktop: 14.0),
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronVisible: false,
            rightChevronVisible: false,
            titleTextStyle: TextStyle(
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 14.0, tablet: 15.0, desktop: 16.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 11.0, tablet: 12.0, desktop: 13.0),
              fontWeight: FontWeight.w600,
            ),
            weekendStyle: TextStyle(
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 11.0, tablet: 12.0, desktop: 13.0),
              fontWeight: FontWeight.w600,
              color: Colors.red.shade400,
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
          // Add key to force rebuild when schedules change
          key: ValueKey(scheduleController.schedules.length),
        ),
      );
    });
  }

  Widget? _buildResponsiveFABWithOptions() {
    final currentUser = authController.currentUser.value;

    if (currentUser?.role.toLowerCase() == 'student') {
      return null;
    }

    return FloatingActionButton.extended(
      onPressed: _showCreateOptions,
      icon: const Icon(Icons.add),
      label: ResponsiveText(
        style: TextStyle(),
        context.isMobile ? 'New Schedule' : 'New Schedule',
        fontSize: ResponsiveUtils.getValue(context,
            mobile: 12.0, tablet: 13.0, desktop: 14.0),
      ),
    );
  }

  // Original logic methods (unchanged)
  void _toggleView() {
    setState(() {
      _currentView = _currentView == 'month' ? 'week' : 'month';
    });
  }

  void _refreshData() {
    scheduleController.refreshData();
    _loadAllData();
  }

  void _previousPeriod() {
    setState(() {
      if (_currentView == 'week') {
        _focusedDay.value = _focusedDay.value.subtract(const Duration(days: 7));
      } else {
        _focusedDay.value = DateTime(
          _focusedDay.value.year,
          _focusedDay.value.month - 1,
          _focusedDay.value.day,
        );
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_currentView == 'week') {
        _focusedDay.value = _focusedDay.value.add(const Duration(days: 7));
      } else {
        _focusedDay.value = DateTime(
          _focusedDay.value.year,
          _focusedDay.value.month + 1,
          _focusedDay.value.day,
        );
      }
    });
  }

  void _showDatePicker() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _focusedDay.value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (selectedDate != null) {
      setState(() {
        _focusedDay.value = selectedDate;
        _selectedDay.value = selectedDate;
      });
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay.value = selectedDay;
      _focusedDay.value = focusedDay;
    });

    // Always show dialog when a date is tapped
    final daySchedules = _getEventsForDay(selectedDay);
    _showDayLessons(selectedDay, daySchedules);
  }

// Update your _showDayLessons method to handle empty schedules better
  void _showDayLessons(DateTime day, List<Schedule> schedules) {
    Get.dialog(_ResponsiveDateLessonsDialog(
      selectedDate: day,
      schedules: schedules, // Can be empty list
      filterText: _getActiveFiltersText(),
      hasActiveFilters: _hasActiveFilters(),
    ));
  }

  List<Schedule> _getEventsForDay(DateTime day) {
    return scheduleController.filteredSchedules
        .where((schedule) => isSameDay(schedule.start, day))
        .toList();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return AlertDialog(
          title: const Text('Search Schedules'),
          content: TextField(
            decoration: const InputDecoration(
              hintText: 'Enter student or instructor name...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => searchQuery = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                if (searchQuery.isNotEmpty) {
                  _performSearch(searchQuery);
                }
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  void _performSearch(String query) {
    final searchText = query.toLowerCase();
    final matchingSchedules = scheduleController.schedules.where((schedule) {
      final student = _getStudentById(schedule.studentId);
      final instructor = _getInstructorById(schedule.instructorId);
      final course = _getCourseById(schedule.courseId);

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
          snackPosition: SnackPosition.BOTTOM,
          'Search Results',
          '${matchingSchedules.length} schedules found');
    } else {
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'No Results',
          'No schedules found matching "$query"');
    }
  }

  void _showCreateOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.blue),
              title: const Text('Schedule Single Lesson'),
              subtitle: const Text('Create a one-time lesson'),
              onTap: () {
                Get.back();
                _showCreateScheduleDialog(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat, color: Colors.green),
              title: const Text('Schedule Recurring Lessons'),
              subtitle: const Text('Create recurring lessons'),
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
      Get.to(() => SimplifiedScheduleBookingScreen());
    }
  }

  // Helper methods (unchanged)
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

  bool _hasActiveFilters() {
    return _selectedInstructorFilter != null ||
        _selectedStudentFilter != null ||
        _selectedStatusFilter != null;
  }

  void _clearFilters() {
    setState(() {
      _selectedInstructorFilter = null;
      _selectedStudentFilter = null;
      _selectedStatusFilter = null;
    });
  }

  int _getFilteredCount() {
    // Implement filtered count logic
    return scheduleController.filteredSchedules.length;
  }

  int _getTotalCount() {
    return scheduleController.schedules.length;
  }

  String _getActiveFiltersText() {
    List<String> filters = [];
    if (_selectedInstructorFilter != null) {
      filters.add('Instructor: $_selectedInstructorFilter');
    }
    if (_selectedStudentFilter != null) {
      filters.add('Student: $_selectedStudentFilter');
    }
    if (_selectedStatusFilter != null) {
      filters.add('Status: $_selectedStatusFilter');
    }
    return filters.isEmpty ? 'No filters active' : filters.join(', ');
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

// Responsive Daily Lessons Dialog
class _ResponsiveDateLessonsDialog extends StatelessWidget {
  final DateTime selectedDate;
  final List<Schedule> schedules;
  final String filterText;
  final bool hasActiveFilters;

  const _ResponsiveDateLessonsDialog({
    Key? key,
    required this.selectedDate,
    required this.schedules,
    required this.filterText,
    required this.hasActiveFilters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(selectedDate);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: ResponsiveUtils.getValue(
            context,
            mobile: MediaQuery.of(context).size.width * 0.95,
            tablet: MediaQuery.of(context).size.width * 0.8,
            desktop: MediaQuery.of(context).size.width * 0.6,
          ),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader(context, isToday),
            if (hasActiveFilters) _buildFilterInfo(context),
            Flexible(
              child: schedules.isEmpty
                  ? _buildEmptyState(context)
                  : _buildLessonsList(context),
            ),
            _buildDialogActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context, bool isToday) {
    final dayName = DateFormat('EEEE').format(selectedDate);
    final dateStr = DateFormat('MMM d, yyyy').format(selectedDate);

    return Container(
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(18),
        desktop: const EdgeInsets.all(20),
      ),
      decoration: BoxDecoration(
        color: isToday ? Colors.blue.shade600 : Colors.grey.shade700,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isToday ? Icons.today : Icons.calendar_today,
              color: Colors.white,
              size: ResponsiveUtils.getValue(context,
                  mobile: 20.0, tablet: 22.0, desktop: 24.0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveText(
                  style: TextStyle(),
                  dayName,
                  fontSize: ResponsiveUtils.getValue(context,
                      mobile: 18.0, tablet: 19.0, desktop: 20.0),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                ResponsiveText(
                  style: TextStyle(),
                  dateStr,
                  fontSize: ResponsiveUtils.getValue(context,
                      mobile: 12.0, tablet: 13.0, desktop: 14.0),
                  color: Colors.white.withOpacity(0.9),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ResponsiveText(
              style: TextStyle(),
              '${schedules.length} lesson${schedules.length != 1 ? 's' : ''}',
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 11.0, tablet: 12.0, desktop: 12.0),
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: ResponsiveText(
              style: TextStyle(),
              'Filtered view: $filterText',
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 11.0, tablet: 12.0, desktop: 12.0),
              color: Colors.blue.shade700,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: ResponsiveUtils.getValue(context,
                mobile: 48.0, tablet: 56.0, desktop: 64.0),
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          ResponsiveText(
            style: TextStyle(),
            'No lessons scheduled',
            fontSize: ResponsiveUtils.getValue(context,
                mobile: 16.0, tablet: 17.0, desktop: 18.0),
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 8),
          ResponsiveText(
            style: TextStyle(),
            hasActiveFilters
                ? 'No lessons match the current filters for this date'
                : 'No lessons are scheduled for this date',
            fontSize: ResponsiveUtils.getValue(context,
                mobile: 13.0, tablet: 14.0, desktop: 14.0),
            color: Colors.grey.shade500,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(16),
        desktop: const EdgeInsets.all(20),
      ),
      itemCount: schedules.length,
      itemBuilder: (context, index) =>
          _buildLessonCard(context, schedules[index]),
    );
  }

  Widget _buildLessonCard(BuildContext context, Schedule schedule) {
    final student = Get.find<UserController>().users.firstWhereOrNull(
          (user) => user.id == schedule.studentId,
        );
    final instructor = Get.find<UserController>().users.firstWhereOrNull(
          (user) => user.id == schedule.instructorId,
        );
    final course = Get.find<CourseController>().courses.firstWhereOrNull(
          (c) => c.id == schedule.courseId,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showScheduleDetailsDialog(schedule),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: ResponsiveUtils.getValue(
            context,
            mobile: const EdgeInsets.all(12),
            tablet: const EdgeInsets.all(14),
            desktop: const EdgeInsets.all(16),
          ),
          decoration: BoxDecoration(
            color: _getCardBackgroundColor(schedule),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getCardBorderColor(schedule),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Time and Status Row
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: ResponsiveUtils.getValue(context,
                              mobile: 14.0, tablet: 15.0, desktop: 16.0),
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: ResponsiveText(
                            style: TextStyle(),
                            '${DateFormat.jm().format(schedule.start)} - ${DateFormat.jm().format(schedule.end)}',
                            fontSize: ResponsiveUtils.getValue(context,
                                mobile: 14.0, tablet: 15.0, desktop: 16.0),
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ResponsiveText(
                          style: TextStyle(),
                          '(${schedule.duration})',
                          fontSize: ResponsiveUtils.getValue(context,
                              mobile: 10.0, tablet: 11.0, desktop: 12.0),
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(context, schedule),
                ],
              ),

              const SizedBox(height: 12),

              // Student and Course Info
              context.isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(context, Icons.person, Colors.blue,
                            '${student?.fname ?? 'Unknown'} ${student?.lname ?? ''}'),
                        const SizedBox(height: 4),
                        _buildInfoRow(context, Icons.school, Colors.green,
                            course?.name ?? 'Unknown Course'),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                            context,
                            Icons.person_outline,
                            Colors.purple,
                            'Instructor: ${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? ''}'),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(context, Icons.person, Colors.blue,
                                  '${student?.fname ?? 'Unknown'} ${student?.lname ?? ''}'),
                              const SizedBox(height: 4),
                              _buildInfoRow(context, Icons.school, Colors.green,
                                  course?.name ?? 'Unknown Course'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoRow(
                              context,
                              Icons.person_outline,
                              Colors.purple,
                              'Instructor: ${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? ''}'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScheduleDetailsDialog(Schedule schedule) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(ScheduleDetailsDialog(schedule: schedule));
    });
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon,
            size: ResponsiveUtils.getValue(context,
                mobile: 14.0, tablet: 15.0, desktop: 16.0),
            color: color),
        const SizedBox(width: 6),
        Expanded(
          child: ResponsiveText(
            style: TextStyle(),
            text,
            fontSize: ResponsiveUtils.getValue(context,
                mobile: 12.0, tablet: 13.0, desktop: 14.0),
            color: Colors.grey.shade700,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, Schedule schedule) {
    final status = schedule.statusDisplay ?? schedule.status;
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getValue(context,
            mobile: 6.0, tablet: 7.0, desktop: 8.0),
        vertical: ResponsiveUtils.getValue(context,
            mobile: 3.0, tablet: 4.0, desktop: 4.0),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: ResponsiveUtils.getValue(context,
                  mobile: 10.0, tablet: 11.0, desktop: 12.0),
              color: color),
          const SizedBox(width: 4),
          ResponsiveText(
            style: TextStyle(),
            status,
            fontSize: ResponsiveUtils.getValue(context,
                mobile: 9.0, tablet: 10.0, desktop: 11.0),
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }

  Widget _buildDialogActions(BuildContext context) {
    return Container(
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(14),
        desktop: const EdgeInsets.all(16),
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Get.back(),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.getValue(context,
                  mobile: 12.0, tablet: 14.0, desktop: 16.0),
            ),
          ),
          child: ResponsiveText(
            style: TextStyle(),
            'Close',
            fontSize: ResponsiveUtils.getValue(context,
                mobile: 14.0, tablet: 15.0, desktop: 16.0),
          ),
        ),
      ),
    );
  }

  // Helper methods
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Color _getCardBackgroundColor(Schedule schedule) {
    switch (schedule.status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade50;
      case 'cancelled':
        return Colors.red.shade50;
      case 'in progress':
        return Colors.orange.shade50;
      default:
        return Colors.blue.shade50;
    }
  }

  Color _getCardBorderColor(Schedule schedule) {
    switch (schedule.status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade200;
      case 'cancelled':
        return Colors.red.shade200;
      case 'in progress':
        return Colors.orange.shade200;
      default:
        return Colors.blue.shade200;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      case 'in progress':
        return Colors.orange.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'in progress':
        return Icons.play_circle;
      default:
        return Icons.schedule;
    }
  }
}

class ScheduleProgressMonitor {
  static Timer? _timer;
  static final ScheduleController _scheduleController =
      Get.find<ScheduleController>();

  static void startMonitoring() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _scheduleController.updateLessonProgress();
    });
  }

  static void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }
}
