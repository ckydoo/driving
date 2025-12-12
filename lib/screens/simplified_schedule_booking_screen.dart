import 'package:driving/screens/payments/pos.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/schedule.dart';
import '../../models/user.dart';
import '../../models/course.dart';
import '../../models/fleet.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';
import '../../controllers/billing_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../services/print_service.dart';

class SimplifiedScheduleBookingScreen extends StatefulWidget {
  final User? student;

  const SimplifiedScheduleBookingScreen({
    Key? key,
    this.student,
  }) : super(key: key);

  @override
  _SimplifiedScheduleBookingScreenState createState() =>
      _SimplifiedScheduleBookingScreenState();
}

class _SimplifiedScheduleBookingScreenState
    extends State<SimplifiedScheduleBookingScreen> {
  final _scheduleController = Get.find<ScheduleController>();
  final _userController = Get.find<UserController>();
  final _courseController = Get.find<CourseController>();
  final _fleetController = Get.find<FleetController>();
  final _billingController = Get.find<BillingController>();
  final _settingsController = Get.find<SettingsController>();

  // Booking state
  int _currentStep = 0;
  User? _selectedStudent;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTimeSlot;
  Course? _selectedCourse;
  User? _selectedInstructor;
  Fleet? _selectedVehicle;
  int _remainingLessons = 0;
  bool _isLoading = false;

  // Available courses based on student's billing
  List<Course> _availableCourses = [];

  // Search controller for student selection
  final TextEditingController _searchController = TextEditingController();
  List<User> _filteredStudents = [];

  @override
  void initState() {
    super.initState();

    // If student was provided, use it and skip to step 1
    if (widget.student != null) {
      _selectedStudent = widget.student;
      _currentStep = 1;
      _loadStudentData();
    } else {
      // Start at student selection (step 0)
      _currentStep = 0;
      _loadAllStudents();
    }
  }

  void _loadAllStudents() {
    setState(() {
      _filteredStudents = _userController.users
          .where((user) => user.role.toLowerCase() == 'student')
          .toList();
    });
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _userController.users
            .where((user) => user.role.toLowerCase() == 'student')
            .toList();
      } else {
        _filteredStudents = _userController.users
            .where((user) => user.role.toLowerCase() == 'student')
            .where((user) {
          final fullName = '${user.fname} ${user.lname}'.toLowerCase();
          final email = user.email.toLowerCase();
          final searchLower = query.toLowerCase();
          return fullName.contains(searchLower) || email.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _loadStudentData() async {
    if (_selectedStudent == null) return;

    setState(() => _isLoading = true);

    try {
      // Refresh billing data
      await _billingController.fetchBillingData();

      // Get student's invoices to determine available courses
      final studentInvoices = _billingController.invoices
          .where((invoice) => invoice.studentId == _selectedStudent!.id)
          .toList();

      if (studentInvoices.isEmpty) {
        _showNoBillingDialog();
        return;
      }

      // Find courses with remaining lessons
      Set<int> uniqueCourseIds = {};
      List<Course> validCourses = [];

      for (var invoice in studentInvoices) {
        final course = _courseController.courses.firstWhereOrNull(
          (c) => c.id == invoice.courseId,
        );

        if (course != null && !uniqueCourseIds.contains(course.id)) {
          final remaining = _scheduleController.getRemainingLessons(
            _selectedStudent!.id!,
            invoice.courseId,
          );

          if (remaining > 0) {
            validCourses.add(course);
            uniqueCourseIds.add(course.id!);
          }
        }
      }

      if (validCourses.isEmpty) {
        _showNoLessonsDialog();
        return;
      }

      setState(() {
        _availableCourses = validCourses;
        // Auto-select first course if only one available
        if (validCourses.length == 1) {
          _selectedCourse = validCourses.first;
          _updateRemainingLessons();
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateRemainingLessons() {
    if (_selectedCourse != null && _selectedStudent != null) {
      setState(() {
        _remainingLessons = _scheduleController.getRemainingLessons(
          _selectedStudent!.id!,
          _selectedCourse!.id!,
        );
      });
    }
  }

  // Get count of schedules for a specific date
  int _getScheduleCountForDate(DateTime date) {
    return _scheduleController.schedules
        .where((schedule) =>
            schedule.status != 'Cancelled' &&
            schedule.start.year == date.year &&
            schedule.start.month == date.month &&
            schedule.start.day == date.day)
        .length;
  }

  // Check if a date has schedules
  bool _hasSchedules(DateTime date) {
    return _getScheduleCountForDate(date) > 0;
  }

  // Check if a time slot is in the future (for today's date)
  bool _isTimeSlotInFuture(TimeOfDay timeSlot, DateTime now) {
    // Add 30 minutes buffer to prevent booking too close to current time
    final currentTimeWithBuffer = now.add(Duration(minutes: 30));
    final slotDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      timeSlot.hour,
      timeSlot.minute,
    );
    return slotDateTime.isAfter(currentTimeWithBuffer);
  }

  // Calculate lesson credits required based on duration
  int _calculateLessonCredits() {
    final durationInHours = _settingsController.defaultLessonDuration.value;
    // Each 30 minutes = 1 lesson credit
    return (durationInHours * 2).round();
  }

  // Get formatted duration string
  String _getFormattedDuration() {
    return _settingsController.getLessonDurationLabel(
      _settingsController.defaultLessonDuration.value,
    );
  }

  void _showNoBillingDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('No Billing Found'),
          ],
        ),
        content: Text(
          '${_selectedStudent!.fname} has no invoices. Please create an invoice/package before scheduling lessons.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              setState(() {
                _selectedStudent = null;
                _currentStep = 0; // Go back to student selection
              });
            },
            child: Text('Select Different Student'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back(); // Close dialog
              // Replace current screen with POS screen
              Get.off(() => POSScreen());
            },
            icon: Icon(Icons.point_of_sale),
            label: Text('Go to POS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showNoLessonsDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('No Lessons Remaining'),
          ],
        ),
        content: Text(
          '${_selectedStudent!.fname} has used all their billed lessons. Please add more lessons to their package.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              setState(() {
                _selectedStudent = null;
                _currentStep = 0; // Go back to student selection
              });
            },
            child: Text('Select Different Student'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back(); // Close dialog
              // Replace current screen with POS screen
              Get.off(() => POSScreen());
            },
            icon: Icon(Icons.point_of_sale),
            label: Text('Go to POS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book a Lesson'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Lesson Credits Banner (only show after student selected)
                if (_selectedStudent != null && _selectedCourse != null)
                  _buildLessonCreditsBanner(),

                // Step Indicator (adjusted for student selection step)
                _buildStepIndicator(),

                // Content based on current step
                Expanded(
                  child: _buildStepContent(),
                ),

                // Navigation Buttons
                _buildNavigationButtons(),
              ],
            ),
    );
  }

  Widget _buildLessonCreditsBanner() {
    if (_selectedCourse == null || _selectedStudent == null) {
      return SizedBox.shrink();
    }

    final hasLowCredits = _remainingLessons <= 3;
    final hasNoCredits = _remainingLessons <= 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasNoCredits
              ? [Colors.red.shade400, Colors.red.shade600]
              : hasLowCredits
                  ? [Colors.orange.shade400, Colors.orange.shade600]
                  : [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              '${_selectedStudent!.fname.isNotEmpty ? _selectedStudent!.fname[0] : ""}${_selectedStudent!.lname.isNotEmpty ? _selectedStudent!.lname[0] : ""}',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedStudent!.fname} ${_selectedStudent!.lname}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_remainingLessons lessons left • ${_selectedCourse!.name}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (hasLowCredits && !hasNoCredits)
            Icon(Icons.warning, color: Colors.white, size: 24),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.student == null) ...[
            _buildStepDot(0, 'Student'),
            _buildStepLine(0),
          ],
          _buildStepDot(widget.student != null ? 0 : 1, 'Date'),
          _buildStepLine(widget.student != null ? 0 : 1),
          _buildStepDot(widget.student != null ? 1 : 2, 'Time'),
          _buildStepLine(widget.student != null ? 1 : 2),
          _buildStepDot(widget.student != null ? 2 : 3, 'Instructor'),
          _buildStepLine(widget.student != null ? 2 : 3),
          _buildStepDot(widget.student != null ? 3 : 4, 'Confirm'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Column(
      children: [
        Container(
          width: isActive ? 32 : 24,
          height: isActive ? 32 : 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted || isActive ? Colors.blue : Colors.grey.shade300,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? Colors.blue : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isCompleted = step < _currentStep;
    return Container(
      width: 30,
      height: 2,
      color: isCompleted ? Colors.blue : Colors.grey.shade300,
      margin: EdgeInsets.only(bottom: 20),
    );
  }

  Widget _buildStepContent() {
    // Adjust step index based on whether student was pre-selected
    if (widget.student != null) {
      // Student was provided, skip step 0
      switch (_currentStep) {
        case 1:
          return _buildDateSelectionStep();
        case 2:
          return _buildTimeSelectionStep();
        case 3:
          return _buildInstructorSelectionStep(); // NEW STEP
        case 4:
          return _buildConfirmationStep();
        default:
          return _buildDateSelectionStep();
      }
    } else {
      // Student selection is step 0
      switch (_currentStep) {
        case 0:
          return _buildStudentSelectionStep();
        case 1:
          return _buildDateSelectionStep();
        case 2:
          return _buildTimeSelectionStep();
        case 3:
          return _buildInstructorSelectionStep(); // NEW STEP
        case 4:
          return _buildConfirmationStep();
        default:
          return _buildStudentSelectionStep();
      }
    }
  }

  // NEW STEP 0: STUDENT SELECTION (only shown when student not provided)
  Widget _buildStudentSelectionStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Student',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Choose which student to book a lesson for',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 24),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: _filterStudents,
          ),

          SizedBox(height: 16),

          // Student list
          if (_filteredStudents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.person_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No students found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._filteredStudents.map((student) {
              final isSelected = _selectedStudent?.id == student.id;

              // Get total remaining lessons for this student
              int totalLessons = 0;
              final studentInvoices = _billingController.invoices
                  .where((inv) => inv.studentId == student.id)
                  .toList();

              for (var invoice in studentInvoices) {
                final remaining = _scheduleController.getRemainingLessons(
                  student.id!,
                  invoice.courseId,
                );
                totalLessons += remaining;
              }

              return Card(
                margin: EdgeInsets.only(bottom: 12),
                color: isSelected ? Colors.blue.shade50 : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isSelected ? Colors.blue : Colors.blue.shade400,
                    child: Text(
                      '${student.fname.isNotEmpty ? student.fname[0] : ""}${student.lname.isNotEmpty ? student.lname[0] : ""}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '${student.fname} ${student.lname}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.email),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            totalLessons > 0
                                ? Icons.check_circle
                                : Icons.warning,
                            size: 14,
                            color:
                                totalLessons > 0 ? Colors.green : Colors.orange,
                          ),
                          SizedBox(width: 4),
                          Text(
                            totalLessons > 0
                                ? '$totalLessons lessons available'
                                : 'No lessons remaining',
                            style: TextStyle(
                              fontSize: 12,
                              color: totalLessons > 0
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.blue)
                      : Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    setState(() {
                      _selectedStudent = student;
                    });
                  },
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

// NEW STEP 3: INSTRUCTOR SELECTION
  Widget _buildInstructorSelectionStep() {
    if (_selectedTimeSlot == null) {
      return Center(child: Text('Please select a time slot first'));
    }

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTimeSlot!.hour,
      _selectedTimeSlot!.minute,
    );
    final durationInHours = _settingsController.defaultLessonDuration.value;
    final endDateTime = startDateTime.add(
      Duration(minutes: (durationInHours * 60).round()),
    );

    // Get all instructors who have a vehicle assigned
    final allInstructors = _userController.users
        .where((user) => user.role.toLowerCase() == 'instructor')
        .where((instructor) {
          // Only include instructors who have a vehicle assigned
          return _fleetController.fleet.any((v) => v.instructor == instructor.id);
        })
        .toList();

    // Separate available and busy instructors
    List<User> availableInstructors = [];
    List<User> busyInstructors = [];

    for (var instructor in allInstructors) {
      final instructorSchedules = _scheduleController.schedules
          .where((s) => s.instructorId == instructor.id)
          .where((s) => s.status != 'Cancelled')
          .where((s) {
        return s.start.year == _selectedDate.year &&
            s.start.month == _selectedDate.month &&
            s.start.day == _selectedDate.day;
      }).toList();

      final hasConflict = instructorSchedules.any((schedule) {
        return schedule.start.isBefore(endDateTime) &&
            schedule.end.isAfter(startDateTime);
      });

      if (hasConflict) {
        busyInstructors.add(instructor);
      } else {
        availableInstructors.add(instructor);
      }
    }

    // Format time range
    final startTime = TimeOfDay.fromDateTime(startDateTime);
    final endTime = TimeOfDay.fromDateTime(endDateTime);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Instructor',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${DateFormat('EEE, MMM d').format(_selectedDate)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
              SizedBox(width: 4),
              Text(
                '${startTime.format(context)} to ${endTime.format(context)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          if (availableInstructors.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'No instructors available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please select a different time slot',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Available Instructors (${availableInstructors.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 12),
            ...availableInstructors.map((instructor) {
              final isSelected = _selectedInstructor?.id == instructor.id;

              // Get instructor's vehicle
              final vehicle = _fleetController.fleet.firstWhereOrNull(
                (v) => v.instructor == instructor.id,
              );

              return Card(
                margin: EdgeInsets.only(bottom: 12),
                color: isSelected ? Colors.blue.shade50 : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isSelected ? Colors.blue : Colors.green.shade400,
                    child: Text(
                      '${instructor.fname.isNotEmpty ? instructor.fname[0] : ""}${instructor.lname.isNotEmpty ? instructor.lname[0] : ""}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '${instructor.fname} ${instructor.lname}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (vehicle != null) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.directions_car,
                                size: 14, color: Colors.grey.shade600),
                            SizedBox(width: 4),
                            Text(
                              '${vehicle.make} ${vehicle.model}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.blue)
                      : Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    setState(() {
                      _selectedInstructor = instructor;
                      _selectedVehicle = vehicle;
                    });
                  },
                ),
              );
            }).toList(),
          ],
          if (busyInstructors.isNotEmpty) ...[
            SizedBox(height: 24),
            Text(
              'Unavailable (${busyInstructors.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 12),
            ...busyInstructors.map((instructor) {
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                color: Colors.grey.shade100,
                child: ListTile(
                  enabled: false,
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade400,
                    child: Text(
                      '${instructor.fname.isNotEmpty ? instructor.fname[0] : ""}${instructor.lname.isNotEmpty ? instructor.lname[0] : ""}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '${instructor.fname} ${instructor.lname}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  subtitle: Text(
                    'Busy at this time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  trailing: Icon(Icons.block, color: Colors.grey.shade400),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  // STEP 1: DATE SELECTION
  Widget _buildDateSelectionStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course selection (if multiple courses available)
          if (_availableCourses.length > 1) ...[
            Text(
              'Select Course',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            ..._availableCourses.map((course) {
              final remaining = _scheduleController.getRemainingLessons(
                _selectedStudent!.id!,
                course.id!,
              );
              final isSelected = _selectedCourse?.id == course.id;

              return Card(
                margin: EdgeInsets.only(bottom: 12),
                color: isSelected ? Colors.blue.shade50 : null,
                child: ListTile(
                  leading: Icon(
                    Icons.book,
                    color: isSelected ? Colors.blue : null,
                  ),
                  title: Text(course.name),
                  subtitle: Text('$remaining lessons remaining'),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCourse = course;
                      _updateRemainingLessons();
                    });
                  },
                ),
              );
            }).toList(),
            SizedBox(height: 24),
          ],

          if (_selectedCourse != null) ...[
            Text(
              'Choose Your Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),

            // Calendar with schedule markers
            Card(
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(Duration(days: 90)),
                focusedDay: _selectedDate,
                selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  // Prevent selecting past dates
                  if (selectedDay
                      .isBefore(DateTime.now().subtract(Duration(days: 1)))) {
                    Get.snackbar(
                      'Invalid Date',
                      'Cannot schedule lessons in the past',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                      duration: Duration(seconds: 2),
                    );
                    return;
                  }
                  setState(() {
                    _selectedDate = selectedDay;
                  });
                },
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                enabledDayPredicate: (day) {
                  // Only enable today and future dates
                  return day
                      .isAfter(DateTime.now().subtract(Duration(days: 1)));
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.blue.shade200,
                    shape: BoxShape.circle,
                  ),
                  disabledDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  disabledTextStyle: TextStyle(
                    color: Colors.grey.shade400,
                  ),
                  markersMaxCount: 1,
                  markerDecoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                // Event loader - returns list of events for each day
                eventLoader: (day) {
                  final count = _getScheduleCountForDate(day);
                  // Return a list with 'count' items to show markers
                  return List.generate(count > 0 ? 1 : 0, (index) => count);
                },
                // Custom builders for the calendar
                calendarBuilders: CalendarBuilders(
                  // Custom marker builder to show schedule count
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;

                    final count = _getScheduleCountForDate(day);
                    if (count == 0) return null;

                    return Positioned(
                      bottom: 1,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            SizedBox(height: 16),

            // Helpful info
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can book lessons up to 90 days in advance',
                      style:
                          TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // STEP 2: TIME SELECTION WITH FIXED CONFLICT CHECKING
  Widget _buildTimeSelectionStep() {
    final workingHours = _settingsController.businessStartTime.value;

    // Parse working hours with fallback to default (9 AM - 5 PM)
    int startHour = 8;
    int endHour = 17;

    try {
      if (workingHours.isNotEmpty && workingHours.contains('-')) {
        final parts = workingHours.split('-');
        if (parts.length == 2) {
          startHour = int.parse(parts[0].split(':')[0].trim());
          endHour = int.parse(parts[1].split(':')[0].trim());
        }
      }
    } catch (e) {
      // Use default hours if parsing fails (9 AM - 5 PM)
      startHour = 8;
      endHour = 17;
    }

    // Generate time slots (every 15 minutes)
    List<TimeOfDay> timeSlots = [];
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    for (int hour = startHour; hour < endHour; hour++) {
      // Add hour:00 slot
      final slot00 = TimeOfDay(hour: hour, minute: 0);
      if (!isToday || _isTimeSlotInFuture(slot00, now)) {
        timeSlots.add(slot00);
      }

      // Add hour:30 slot
      final slot30 = TimeOfDay(hour: hour, minute: 30);
      if (!isToday || _isTimeSlotInFuture(slot30, now)) {
        timeSlots.add(slot30);
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d, y').format(_selectedDate),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Select a time slot',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),

          // Show info if booking for today
          if (isToday) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time,
                      color: Colors.orange.shade700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking for today - only showing time slots at least 30 minutes from now',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 24),

          // Show message if no time slots available
          if (timeSlots.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No available time slots',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      isToday
                          ? 'All time slots for today have passed. Please select a future date.'
                          : 'No time slots available for this date.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Time slots grouped by time of day
            _buildTimeSection(
                'Morning', timeSlots.where((t) => t.hour < 12).toList()),
            SizedBox(height: 16),
            _buildTimeSection('Afternoon',
                timeSlots.where((t) => t.hour >= 12 && t.hour < 17).toList()),
            SizedBox(height: 16),
            _buildTimeSection(
                'Evening', timeSlots.where((t) => t.hour >= 17).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSection(String title, List<TimeOfDay> slots) {
    if (slots.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) => _buildTimeSlot(slot)).toList(),
        ),
      ],
    );
  }

  // ENHANCED: Show instructor availability count in time slots
  Widget _buildTimeSlot(TimeOfDay slot) {
    final isSelected = _selectedTimeSlot?.hour == slot.hour &&
        _selectedTimeSlot?.minute == slot.minute;

    // Calculate time range for this slot
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      slot.hour,
      slot.minute,
    );
    final durationInHours = _settingsController.defaultLessonDuration.value;
    final endDateTime = startDateTime.add(
      Duration(minutes: (durationInHours * 60).round()),
    );

    // Get all instructors who have a vehicle assigned
    final allInstructors = _userController.users
        .where((user) => user.role.toLowerCase() == 'instructor')
        .where((instructor) {
          // Only include instructors who have a vehicle assigned
          return _fleetController.fleet.any((v) => v.instructor == instructor.id);
        })
        .toList();

    // Count available instructors
    int availableInstructorCount = 0;
    List<String> availableInstructorNames = [];

    for (var instructor in allInstructors) {
      // Get all schedules for this instructor on this date
      final instructorSchedules = _scheduleController.schedules
          .where((s) => s.instructorId == instructor.id)
          .where((s) => s.status != 'Cancelled')
          .where((s) {
        // Only check schedules on the same date
        return s.start.year == _selectedDate.year &&
            s.start.month == _selectedDate.month &&
            s.start.day == _selectedDate.day;
      }).toList();

      // Check if this instructor has any conflicting schedules
      final hasConflict = instructorSchedules.any((schedule) {
        // Check for time overlap
        return schedule.start.isBefore(endDateTime) &&
            schedule.end.isAfter(startDateTime);
      });

      if (!hasConflict) {
        availableInstructorCount++;
        availableInstructorNames.add('${instructor.fname} ${instructor.lname}');
      }
    }

    final isAvailable = availableInstructorCount > 0;
    final totalInstructors = allInstructors.length;

    return InkWell(
      onTap: isAvailable
          ? () {
              setState(() {
                _selectedTimeSlot = slot;
                // Don't auto-assign - user will select in next step
                _selectedInstructor = null;
                _selectedVehicle = null;
              });
            }
          : null,
      child: Container(
        width: 100,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : isAvailable
                  ? Colors.white
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : isAvailable
                    ? (availableInstructorCount == totalInstructors
                        ? Colors.green // All instructors free
                        : Colors.orange) // Some instructors free
                    : Colors.grey.shade300, // No instructors free
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              slot.format(context),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isSelected
                    ? Colors.white
                    : isAvailable
                        ? Colors.black
                        : Colors.grey,
              ),
            ),
            SizedBox(height: 4),
            if (isAvailable)
              Text(
                '$availableInstructorCount/$totalInstructors free',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Colors.white70
                      : (availableInstructorCount == totalInstructors
                          ? Colors.green
                          : Colors.orange),
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text(
                'Fully Booked',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // STEP 3: CONFIRMATION
  Widget _buildConfirmationStep() {
    if (_selectedCourse == null ||
        _selectedInstructor == null ||
        _selectedTimeSlot == null ||
        _selectedStudent == null) {
      return Center(child: Text('Missing booking information'));
    }

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTimeSlot!.hour,
      _selectedTimeSlot!.minute,
    );

    // Calculate end time based on duration
    final durationInHours = _settingsController.defaultLessonDuration.value;
    final endDateTime = startDateTime.add(
      Duration(minutes: (durationInHours * 60).round()),
    );

    // Format start and end times
    final startTime = TimeOfDay.fromDateTime(startDateTime);
    final endTime = TimeOfDay.fromDateTime(endDateTime);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm Booking',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),

          // Summary Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.person,
                  'Student',
                  '${_selectedStudent!.fname} ${_selectedStudent!.lname}',
                ),
                Divider(color: Colors.white30, height: 24),
                _buildSummaryRow(
                  Icons.calendar_today,
                  'Date & Time',
                  '${DateFormat('EEE, MMM d').format(_selectedDate)}\n${startTime.format(context)} to ${endTime.format(context)}',
                ),
                Divider(color: Colors.white30, height: 24),
                _buildSummaryRow(
                  Icons.person,
                  'Instructor',
                  '${_selectedInstructor!.fname} ${_selectedInstructor!.lname}',
                ),
                Divider(color: Colors.white30, height: 24),
                if (_selectedVehicle != null) ...[
                  _buildSummaryRow(
                    Icons.directions_car,
                    'Vehicle',
                    '${_selectedVehicle!.make} ${_selectedVehicle!.model}',
                  ),
                  Divider(color: Colors.white30, height: 24),
                ],
                _buildSummaryRow(
                  Icons.access_time,
                  'Duration',
                  '${_getFormattedDuration()} (${_calculateLessonCredits()} lessons)',
                ),
                Divider(color: Colors.white30, height: 24),
                _buildSummaryRow(
                  Icons.account_balance_wallet,
                  'Cost',
                  '${_calculateLessonCredits()} lesson credits',
                  showBold: true,
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Remaining Credits Info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green.shade700),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'After this booking:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_remainingLessons - _calculateLessonCredits()} lessons remaining',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Reminder Info
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications,
                    color: Colors.blue.shade700, size: 20),
                SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value,
      {bool showBold = false}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: showBold ? 18 : 14,
              fontWeight: showBold ? FontWeight.bold : FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > (widget.student != null ? 1 : 0))
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.blue, width: 2),
                ),
                child: Text('Back'),
              ),
            ),
          if (_currentStep > (widget.student != null ? 1 : 0))
            SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _canProceed() ? _handleNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep == (widget.student != null ? 3 : 3)
                          ? 'Confirm Booking'
                          : 'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    if (widget.student != null) {
      // Student pre-selected
      switch (_currentStep) {
        case 1:
          return _selectedCourse != null;
        case 2:
          return _selectedTimeSlot != null;
        case 3:
          return _selectedInstructor != null; // NEW: Check instructor selected
        case 4:
          return true;
        default:
          return false;
      }
    } else {
      // Student selection required
      switch (_currentStep) {
        case 0:
          return _selectedStudent != null;
        case 1:
          return _selectedCourse != null;
        case 2:
          return _selectedTimeSlot != null;
        case 3:
          return _selectedInstructor != null; // NEW: Check instructor selected
        case 4:
          return true;
        default:
          return false;
      }
    }
  }

  void _handleNext() async {
    final maxStep = widget.student != null ? 4 : 4;

    if (_currentStep < maxStep) {
      // Special handling for step 0 (student selection)
      if (_currentStep == 0 && widget.student == null) {
        // Load student data before proceeding
        await _loadStudentData();
        if (_availableCourses.isNotEmpty) {
          setState(() {
            _currentStep++;
          });
        }
        // If no courses, dialog was shown, don't proceed
      } else if (_currentStep == 2 ||
          (_currentStep == 1 && widget.student != null)) {
        // Validate lesson credits before moving from time selection to instructor selection
        final requiredCredits = _calculateLessonCredits();
        if (_remainingLessons < requiredCredits) {
          Get.dialog(
            AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Insufficient Lessons'),
                ],
              ),
              content: Text(
                'You need at least $requiredCredits lesson credits to book a ${_getFormattedDuration()} session.\n\nCurrent balance: $_remainingLessons lesson(s)\nRequired: $requiredCredits lesson(s)\nShortfall: ${requiredCredits - _remainingLessons} lesson(s)\n\nPlease purchase more lessons or select a shorter duration in settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text('OK'),
                ),
              ],
            ),
          );
          return; // Don't proceed to next step
        }
        // If validation passes, proceed
        setState(() {
          _currentStep++;
        });
      } else {
        setState(() {
          _currentStep++;
        });
      }
    } else {
      // Final step - create the booking
      await _confirmBooking();
    }
  }

  Future<void> _confirmBooking() async {
    final requiredCredits = _calculateLessonCredits();

    // Check if student has enough lessons remaining
    if (_remainingLessons < requiredCredits) {
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 12),
              Text('Insufficient Lessons'),
            ],
          ),
          content: Text(
            'Need at least $requiredCredits lessons to book this ${_getFormattedDuration()} session. Currently $_remainingLessons lesson(s) remaining.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Validate that the selected time is not in the past
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTimeSlot!.hour,
      _selectedTimeSlot!.minute,
    );

    if (startDateTime.isBefore(DateTime.now())) {
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 12),
              Text('Invalid Time'),
            ],
          ),
          content: Text(
            'Cannot schedule a lesson in the past. Please select a different date or time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final durationInHours = _settingsController.defaultLessonDuration.value;
      final endDateTime = startDateTime.add(
        Duration(minutes: (durationInHours * 60).round()),
      );

      // Create the schedule
      final schedule = Schedule(
        studentId: _selectedStudent!.id!,
        instructorId: _selectedInstructor!.id!,
        courseId: _selectedCourse!.id!,
        carId: _selectedVehicle?.id,
        start: startDateTime,
        end: endDateTime,
        classType: 'Practical',
        status: 'Scheduled',
        attended: false,
      );

      await _scheduleController.createSchedule(schedule);

      // Calculate remaining lessons after booking
      final remainingAfterBooking =
          _remainingLessons - _calculateLessonCredits();

      // Show success dialog
      Get.dialog(
        AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Lesson successfully booked for ${_selectedStudent!.fname}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Date & Time:',
                            style: TextStyle(color: Colors.grey.shade600)),
                        Text(
                          '${DateFormat('MMM d').format(_selectedDate)} at ${_selectedTimeSlot!.format(context)}',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Instructor:',
                            style: TextStyle(color: Colors.grey.shade600)),
                        Text(
                          '${_selectedInstructor!.fname} ${_selectedInstructor!.lname}',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lessons Remaining:',
                            style: TextStyle(color: Colors.grey.shade600)),
                        Text(
                          '$remainingAfterBooking',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  // Print booking confirmation
                  await PrintService.printBookingConfirmation(
                    student: _selectedStudent!,
                    instructor: _selectedInstructor!,
                    course: _selectedCourse!,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime,
                    vehicle: _selectedVehicle,
                    remainingLessons: remainingAfterBooking,
                  );
                } catch (e) {
                  // Error already shown by PrintService
                  print('Print error: $e');
                }
              },
              icon: Icon(Icons.print),
              label: Text('Print'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back(); // Close dialog
                Get.back(); // Go back to previous screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: Text('Done'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create booking: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
