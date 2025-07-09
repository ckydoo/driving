import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/fleet.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/schedule/daily_schedule_screen.dart';
import 'package:driving/widgets/edit_schedule_form_dialog.dart';
import 'package:driving/widgets/schedule_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:driving/services/helper.dart'; // Import UIHelper

class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  final Rx<DateTime> _focusedDay = DateTime.now().obs;
  final DateTime _firstDay = DateTime.utc(2020);
  final DateTime _lastDay = DateTime.utc(2030);

  User? _selectedInstructorFilter;
  User? _selectedStudentFilter;
  String? _selectedStatusFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  final List<String> _statusOptions = [
    'All',
    'Scheduled',
    'Canceled',
    // Add other status options as needed
  ];
  final scheduleController = Get.find<ScheduleController>();

  @override
  void initState() {
    super.initState();
    Get.put(UserController(), permanent: true);
    Get.put(FleetController(), permanent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Schedule Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800, // Consistent app bar color
        elevation: 0,
        iconTheme:
            const IconThemeData(color: Colors.white), // Style back button color
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              await Get.find<UserController>().fetchUsers();
              await Get.find<FleetController>().fetchFleet();
              await scheduleController.fetchSchedules();
            },
          ),
        ],
      ),
      body: Obx(
        () {
          if (scheduleController.isLoading.value) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Colors.blue)); // Use app's accent color
          } else {
            return Column(
              children: [
                _buildCalendar(),
              ],
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue.shade800, // Use app's primary color
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Get.dialog(const ScheduleFormDialog()),
      ),
    );
  }

  Widget _buildCalendar() {
    return Obx(() => Card(
          // Added Card for elevation
          elevation: 4,
          margin: const EdgeInsets.all(16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Navigation
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween, // Use spaceBetween
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () {
                        _focusedDay.value = DateTime(
                          _focusedDay.value.year,
                          _focusedDay.value.month - 1,
                          _focusedDay.value.day,
                        );
                      },
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(
                          _focusedDay.value), // Added year, formatted date
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey, // Use a more subtle color
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () {
                        _focusedDay.value = DateTime(
                          _focusedDay.value.year,
                          _focusedDay.value.month + 1,
                          _focusedDay.value.day,
                        );
                      },
                    ),
                  ],
                ),
                // Calendar
                TableCalendar(
                  firstDay: _firstDay,
                  lastDay: _lastDay,
                  focusedDay: _focusedDay.value,
                  calendarFormat: _calendarFormat,
                  eventLoader: (day) => _getFilteredSchedules(day),
                  calendarStyle: CalendarStyle(
                    // Style the calendar
                    todayDecoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: (event) {
                        if (event.isNotEmpty) {
                          return getStatusColor(event.first);
                        }
                        return Colors.blue;
                      }(scheduleController
                          .getDailySchedules(_focusedDay.value)),
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    _focusedDay.value = focusedDay;
                    final dailySchedules = _getFilteredSchedules(selectedDay);
                    if (dailySchedules.isNotEmpty) {
                      _showEventDialog(context, dailySchedules);
                    } else {
                      Get.to(
                          () => DailyScheduleScreen(selectedDate: selectedDay));
                    }
                  },
                ),
                // Filtering and Search
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Wrap(
                    // Use Wrap for better layout
                    spacing: 8.0,
                    runSpacing: 4.0,
                    alignment: WrapAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<User>(
                          decoration: const InputDecoration(
                            labelText: 'Instructor',
                            border: OutlineInputBorder(), // Added border
                            prefixIcon: Icon(Icons.person), // Added icon
                          ),
                          value: _selectedInstructorFilter,
                          items: Get.find<UserController>()
                              .instructors
                              .map((instructor) => DropdownMenuItem(
                                    value: instructor,
                                    child: Text(
                                      '${instructor.fname} ${instructor.lname}',
                                    ),
                                  ))
                              .toList(),
                          onChanged: (user) {
                            setState(() {
                              _selectedInstructorFilter = user;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<User>(
                          decoration: const InputDecoration(
                            labelText: 'Student',
                            border: OutlineInputBorder(), // Added border
                            prefixIcon: Icon(Icons.school), // Added icon
                          ),
                          value: _selectedStudentFilter,
                          items: Get.find<UserController>()
                              .students
                              .map((student) => DropdownMenuItem(
                                    value: student,
                                    child: Text(
                                      '${student.fname} ${student.lname}',
                                    ),
                                  ))
                              .toList(),
                          onChanged: (user) {
                            setState(() {
                              _selectedStudentFilter = user;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(), // Added border
                            prefixIcon: Icon(Icons.filter_list), // Added icon
                          ),
                          value: _selectedStatusFilter,
                          items: _statusOptions
                              .map((status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status),
                                  ))
                              .toList(),
                          onChanged: (status) {
                            setState(() {
                              _selectedStatusFilter = status;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 200, // Adjust width as needed
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search Student...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(), // Added border
                          ),
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchText = value;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Color getStatusColor(Schedule schedule) {
    switch (schedule.status) {
      case 'Scheduled':
        return Colors.green;
      case 'Canceled':
        return Colors.red;
      //Add more cases as needed
      default:
        return Colors.blue;
    }
  }

  List<Schedule> _getFilteredSchedules(DateTime day) {
    List<Schedule> schedules = scheduleController.getDailySchedules(day);

    // Filtering Logic
    if (_selectedInstructorFilter != null) {
      schedules = schedules
          .where((s) => s.instructorId == _selectedInstructorFilter!.id)
          .toList();
    }
    if (_selectedStudentFilter != null) {
      schedules = schedules
          .where((s) => s.studentId == _selectedStudentFilter!.id)
          .toList();
    }
    if (_selectedStatusFilter != null && _selectedStatusFilter != 'All') {
      schedules =
          schedules.where((s) => s.status == _selectedStatusFilter).toList();
    }

    // Search Logic
    if (_searchText.isNotEmpty) {
      schedules = schedules
          .where((s) =>
              Get.find<UserController>()
                  .users
                  .firstWhere((user) => user.id == s.studentId)
                  .fname
                  .toLowerCase()
                  .contains(_searchText.toLowerCase()) ||
              Get.find<UserController>()
                  .users
                  .firstWhere((user) => user.id == s.studentId)
                  .lname
                  .toLowerCase()
                  .contains(_searchText.toLowerCase()))
          .toList();
    }

    return schedules;
  }

  void _applyFilters() {
    _focusedDay.refresh(); // Trigger calendar refresh
  }

  void _showEventDialog(BuildContext context, List<Schedule> schedules) {
    // Get the current date and time
    final now = DateTime.now();

    // Filter schedules to get only those that are upcoming
    final upcomingSchedules = schedules.where((schedule) {
      return schedule.start.isAfter(now);
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upcoming Schedules'),
        content: SizedBox(
          width: double.maxFinite,
          child: upcomingSchedules.isEmpty
              ? const Padding(
                  // Display this if there are no upcoming schedules
                  padding: EdgeInsets.all(16.0),
                  child: Text('No upcoming schedules found.'),
                )
              : Column(
                  // Display this if there are upcoming schedules
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Row
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Time',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                              semanticsLabel: 'Time',
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Student',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                              semanticsLabel: 'Student',
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Instructor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                              semanticsLabel: 'Instructor',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Schedule List
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: upcomingSchedules
                            .length, // Use upcomingSchedules count
                        itemBuilder: (context, index) {
                          final schedule =
                              upcomingSchedules[index]; // Use upcomingSchedules
                          if (schedule.status != 'Scheduled') {
                            return const SizedBox.shrink();
                          }
                          final student = Get.find<UserController>()
                              .users
                              .firstWhere(
                                  (user) => user.id == schedule.studentId);
                          final instructor = Get.find<UserController>()
                              .users
                              .firstWhere(
                                  (user) => user.id == schedule.instructorId);
                          return Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                          '${DateFormat.yMd().format(schedule.start)} \n ${DateFormat.jm().format(schedule.start)} - ${DateFormat.jm().format(schedule.end)}', // Added Date
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '${student.fname} ${student.lname}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '${instructor.fname} ${instructor.lname}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        DailyScheduleScreen(selectedDate: DateTime.now())),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('View Full Details'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildScheduleItem(Schedule schedule) {
    final billingController = Get.find<BillingController>();
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) => inv.studentId == schedule.studentId,
    );
    final totalLessons = invoice?.lessons ?? 0;
    final overallProgress =
        scheduleController.calculateCourseProgress(schedule.studentId);

    final remainingLessons =
        totalLessons - overallProgress * totalLessons ~/ 100;

    final now = DateTime.now();
    final lessonEndTime = schedule.end;
    final isLessonPast = now.isAfter(lessonEndTime);

    final isCanceled = schedule.status == 'Canceled';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCanceled
                      ? 'Canceled: Lesson #${schedule.lessonsCompleted + 1}'
                      : 'Lesson #${schedule.lessonsCompleted + 1}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: isCanceled ? TextDecoration.lineThrough : null,
                    color: isCanceled ? Colors.grey : Colors.blueGrey,
                  ),
                ),
                _buildLessonStatus(schedule, isCanceled: isCanceled),
              ],
            ),
            const SizedBox(height: 8),
            _buildUserInfo(schedule.studentId, 'Student'),
            _buildUserInfo(schedule.instructorId, 'Instructor'),
            if (schedule.carId != null) _buildVehicleInfo(schedule.carId!),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)} (${schedule.duration})',
                  style: TextStyle(
                    color: isCanceled ? Colors.grey : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildProgressIndicator(overallProgress, remainingLessons),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isLessonPast && !isCanceled)
                  IconButton(
                    icon: Icon(
                      schedule.attended
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: Colors.green,
                    ),
                    onPressed: () {
                      scheduleController.toggleAttendance(
                          schedule.id!, !schedule.attended);
                    },
                    tooltip:
                        schedule.attended ? 'Mark Absent' : 'Mark Attended',
                  ),
                if (!isLessonPast && !isCanceled)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Get.dialog(EditScheduleScreen(
                        schedule: schedule,
                      ));
                    },
                    tooltip: 'Edit Schedule',
                  ),
                if (!isLessonPast && !isCanceled)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    tooltip: 'Cancel Schedule',
                    onPressed: () {
                      _showCancelDialog(schedule, context);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonStatus(Schedule schedule, {bool isCanceled = false}) {
    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (isCanceled) {
      statusText = 'Canceled';
      statusIcon = Icons.cancel;
      statusColor = Colors.grey;
    } else if (schedule.attended) {
      statusText = 'Attended';
      statusIcon = Icons.check;
      statusColor = Colors.green;
    } else if (DateTime.now().isBefore(schedule.start)) {
      // Check if the lesson is in the future
      statusText = 'Pending';
      statusIcon = Icons.pending;
      statusColor = Colors.orange;
    } else {
      statusText = 'Missed';
      statusIcon = Icons.close;
      statusColor = Colors.red;
    }

    return Row(
      children: [
        Icon(
          statusIcon,
          color: statusColor,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            //  fontStyle: isCanceled ? FontStyle.italic : null, // Italic style for canceled
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(double progress, int remainingLessons) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              UIHelper.getProgressColor(progress),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Course Progress: ${progress.toStringAsFixed(1)}% (${remainingLessons.abs()} ${remainingLessons >= 0 ? 'to go' : 'over'})',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(int userId, String role) {
    final userController = Get.find<UserController>();
    return Obx(() {
      final user = userController.users.firstWhere(
        (u) => u.id == userId,
        orElse: () => User(
          id: -1,
          fname: 'Loading...',
          lname: '',
          email: '',
          password: '',
          gender: '',
          phone: '',
          address: '',
          date_of_birth: DateTime.now(),
          role: '',
          status: '',
          idnumber: '',
          created_at: DateTime.now(),
        ),
      );
      return Text(
        '$role: ${user.fname} ${user.lname}',
        style: TextStyle(
          color: user.id == -1 ? Colors.grey : null,
          fontStyle: user.id == -1 ? FontStyle.italic : null,
        ),
      );
    });
  }

  Widget _buildVehicleInfo(int vehicleId) {
    final fleetController = Get.find<FleetController>();
    return Obx(() {
      final vehicle = fleetController.fleet.firstWhere(
        (v) => v.id == vehicleId,
        orElse: () => Fleet(
          id: -1,
          make: 'Loading...',
          model: '',
          carPlate: '',
          modelYear: '',
          instructor: 0,
        ),
      );
      return Text(
        'Vehicle: ${vehicle.make} ${vehicle.model} (${vehicle.carPlate})',
        style: TextStyle(
          color: vehicle.id == -1 ? Colors.grey : null,
          fontStyle: vehicle.id == -1 ? FontStyle.italic : null,
        ),
      );
    });
  }

  void _showCancelDialog(Schedule schedule, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Schedule'),
          content: const Text('Are you sure you want to cancel this schedule?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                scheduleController.cancelSchedule(schedule.id!);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
