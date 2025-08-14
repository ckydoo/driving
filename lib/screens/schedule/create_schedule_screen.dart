import 'package:driving/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/schedule.dart';
import '../../models/user.dart';
import '../../models/course.dart';
import '../../models/fleet.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';
import '../../controllers/billing_controller.dart';

class SingleScheduleScreen extends StatefulWidget {
  final Schedule? existingSchedule;

  const SingleScheduleScreen({Key? key, this.existingSchedule})
      : super(key: key);

  @override
  _SingleScheduleScreenState createState() => _SingleScheduleScreenState();
}

class _SingleScheduleScreenState extends State<SingleScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scheduleController = Get.find<ScheduleController>();
  final _userController = Get.find<UserController>();
  final _courseController = Get.find<CourseController>();
  final _fleetController = Get.find<FleetController>();
  final _billingController = Get.find<BillingController>();

  // Form fields
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 10, minute: 0);

  User? _selectedStudent;
  User? _selectedInstructor;
  Course? _selectedCourse;
  Fleet? _selectedVehicle;
  String _selectedClassType = 'Practical';
  String _selectedStatus = 'Scheduled';

  bool _isLoading = false;
  List<Course> _availableCourses = [];
  int _remainingLessons = 0;
  bool _showAvailabilityStatus = false;
  bool _instructorAvailable = true;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadAvailableCourses();
  }

  void _initializeForm() {
    if (widget.existingSchedule != null) {
      final schedule = widget.existingSchedule!;
      _selectedDate = schedule.start;
      _startTime = TimeOfDay.fromDateTime(schedule.start);
      _endTime = TimeOfDay.fromDateTime(schedule.end);
      _selectedClassType = schedule.classType;
      _selectedStatus = schedule.status;

      // Find related entities
      _selectedStudent = _userController.users.firstWhereOrNull(
        (user) => user.id == schedule.studentId,
      );
      _selectedInstructor = _userController.users.firstWhereOrNull(
        (user) => user.id == schedule.instructorId,
      );
      _selectedCourse = _courseController.courses.firstWhereOrNull(
        (course) => course.id == schedule.courseId,
      );
      if (schedule.carId != null) {
        _selectedVehicle = _fleetController.fleet.firstWhereOrNull(
          (vehicle) => vehicle.id == schedule.carId,
        );
      }

      if (_selectedStudent != null) {
        _loadStudentCourses(_selectedStudent!);
      }
    }
  }

  void _loadAvailableCourses() {
    setState(() {
      _availableCourses = _courseController.courses.toList();
    });
  }

  Future<void> _loadStudentCourses(User student) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // IMPORTANT: Force refresh billing data before checking courses
      await _billingController.fetchBillingData();
      print('✓ Billing data refreshed before loading student courses');

      // Get student's invoices to determine available courses
      final studentInvoices = _billingController.invoices
          .where((invoice) => invoice.studentId == student.id)
          .toList();

      print(
          'DEBUG: Found ${studentInvoices.length} invoices for student ${student.id}');

      if (studentInvoices.isEmpty) {
        Get.snackbar(
          'No Billing Found',
          'This student has no invoices. Please create an invoice before scheduling.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
        );
        setState(() {
          _availableCourses = [];
          _remainingLessons = 0;
          _selectedCourse = null;
        });
        return;
      }

      // Use a Set to track unique course IDs to avoid duplicates
      Set<int> uniqueCourseIds = {};
      List<Course> validCourses = [];

      for (var invoice in studentInvoices) {
        final course = _courseController.courses.firstWhereOrNull(
          (c) => c.id == invoice.courseId,
        );
        if (course != null && !uniqueCourseIds.contains(course.id)) {
          // Force refresh and get remaining lessons
          final remaining = _scheduleController.getRemainingLessons(
              student.id!, invoice.courseId);

          print(
              'DEBUG: Course ${course.name} (ID: ${course.id}) has $remaining remaining lessons');

          // Check settings for billing validation
          final settingsController = Get.find<SettingsController>();
          if (remaining > 0 ||
              !settingsController.enforceBillingValidation.value) {
            validCourses.add(course);
            uniqueCourseIds.add(course.id!);
          }
        }
      }

      if (validCourses.isEmpty) {
        Get.snackbar(
          'No Lessons Remaining',
          'This student has used all their billed lessons. Please add more lessons to their invoice.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
        );
        setState(() {
          _availableCourses = [];
          _remainingLessons = 0;
          _selectedCourse = null;
        });
        return;
      }

      // Sort courses by remaining lessons (descending)
      validCourses.sort((a, b) {
        final aRemaining =
            _scheduleController.getRemainingLessons(student.id!, a.id!);
        final bRemaining =
            _scheduleController.getRemainingLessons(student.id!, b.id!);
        return bRemaining.compareTo(aRemaining);
      });

      setState(() {
        _availableCourses = validCourses;
        _selectedCourse = validCourses.first;
        _remainingLessons = _scheduleController.getRemainingLessons(
            student.id!, _selectedCourse!.id!);
      });

      // Auto-assign instructor's vehicle if available
      if (_selectedInstructor != null) {
        _assignInstructorVehicle(_selectedInstructor!);
      }

      Get.snackbar(
        'Student Selected',
        'Found ${validCourses.length} course(s) with remaining lessons',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      print('ERROR in _loadStudentCourses: $e');
      Get.snackbar(
        'Error',
        'Failed to load student courses: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() {
        _availableCourses = [];
        _remainingLessons = 0;
        _selectedCourse = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add a method to manually refresh student courses
  Future<void> _refreshStudentCourses() async {
    if (_selectedStudent != null) {
      await _loadStudentCourses(_selectedStudent!);
    }
  }

  // Add refresh button to your UI (optional)
  Widget _buildRefreshButton() {
    return IconButton(
      icon: Icon(Icons.refresh),
      onPressed: _refreshStudentCourses,
      tooltip: 'Refresh billing data',
    );
  }

  int _getUsedLessons(int studentId, int courseId) {
    return _scheduleController.getUsedLessons(studentId, courseId);
  }

  void _assignInstructorVehicle(User instructor) {
    // Find vehicle assigned to instructor
    final assignedVehicle = _fleetController.fleet.firstWhereOrNull(
      (vehicle) => vehicle.instructor == instructor.id,
    );

    setState(() {
      _selectedVehicle = assignedVehicle;
    });

    // Show message if instructor has no assigned vehicle for practical lessons
    if (assignedVehicle == null && _selectedClassType == 'Practical') {
      Get.snackbar(
        'No Vehicle Assigned',
        'This instructor has no vehicle assigned. Please assign a vehicle to this instructor first.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    }
  }

  Future<void> _checkInstructorAvailability() async {
    if (_selectedInstructor == null) {
      setState(() {
        _instructorAvailable = true;
        _showAvailabilityStatus = false;
      });
      return;
    }

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    try {
      // Check if instructor has any conflicting schedules
      final conflictingSchedules =
          _scheduleController.schedules.where((schedule) {
        // Skip checking against the current schedule being edited
        if (widget.existingSchedule != null &&
            schedule.id == widget.existingSchedule!.id) {
          return false;
        }

        // Check if it's the same instructor
        if (schedule.instructorId != _selectedInstructor!.id) {
          return false;
        }

        // Check for time overlap
        return (startDateTime.isBefore(schedule.end) &&
            endDateTime.isAfter(schedule.start));
      }).toList();

      setState(() {
        _instructorAvailable = conflictingSchedules.isEmpty;
        _showAvailabilityStatus = true;
      });

      // If there are conflicts, show details
      if (conflictingSchedules.isNotEmpty) {
        final conflictTime =
            DateFormat('hh:mm a').format(conflictingSchedules.first.start);
        final conflictEndTime =
            DateFormat('hh:mm a').format(conflictingSchedules.first.end);

        Get.snackbar(
          'Instructor Conflict',
          'Instructor has a lesson from $conflictTime to $conflictEndTime',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('Error checking instructor availability: $e');
      setState(() {
        _instructorAvailable = false;
        _showAvailabilityStatus = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingSchedule != null
            ? 'Edit Schedule'
            : 'Schedule Single Lesson'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.existingSchedule != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cancel') {
                  _cancelSchedule();
                } else if (value == 'reschedule') {
                  _rescheduleLesson();
                } else if (value == 'mark_attended') {
                  _markAttended(true);
                } else if (value == 'mark_not_attended') {
                  _markAttended(false);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'mark_attended',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Mark Attended'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mark_not_attended',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Mark Not Attended'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reschedule',
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Reschedule'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Cancel Lesson'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStudentSection(),
                    SizedBox(height: 20),
                    _buildCourseSection(),
                    SizedBox(height: 20),
                    _buildInstructorSection(),
                    SizedBox(height: 20),
                    _buildDateTimeSection(),
                    _buildValidationMessages(),
                    SizedBox(height: 20),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStudentSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Student',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<User>(
              value: _selectedStudent,
              decoration: InputDecoration(
                labelText: 'Select Student',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              validator: (value) =>
                  value == null ? 'Please select a student' : null,
              items: _userController.users
                  .where((user) => user.role.toLowerCase() == 'student')
                  .map((user) => DropdownMenuItem(
                        value: user,
                        child: Text('${user.fname} ${user.lname}'),
                      ))
                  .toList(),
              onChanged: (User? value) {
                setState(() {
                  _selectedStudent = value;
                  _selectedCourse = null;
                  _remainingLessons = 0;
                  _availableCourses = [];
                });
                if (value != null) {
                  _loadStudentCourses(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.book, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Course & Billing',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<int>(
              // Changed from Course to int
              value:
                  _selectedCourse?.id, // Use course ID instead of course object
              decoration: InputDecoration(
                labelText: 'Available Courses',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.library_books),
              ),
              validator: (value) =>
                  value == null ? 'Please select a course' : null,
              items: _availableCourses
                  .map((course) => DropdownMenuItem<int>(
                        // Changed to int
                        value: course.id, // Use course ID as value
                        child: Text(course.name),
                      ))
                  .toList(),
              onChanged: (int? courseId) {
                // Changed parameter type
                if (courseId != null) {
                  // Find the course object by ID
                  final selectedCourse = _availableCourses.firstWhereOrNull(
                    (course) => course.id == courseId,
                  );

                  setState(() {
                    _selectedCourse = selectedCourse;
                  });

                  if (selectedCourse != null && _selectedStudent != null) {
                    final invoice =
                        _billingController.invoices.firstWhereOrNull(
                      (inv) =>
                          inv.studentId == _selectedStudent!.id &&
                          inv.courseId == selectedCourse.id,
                    );
                    if (invoice != null) {
                      final used = _getUsedLessons(
                          _selectedStudent!.id!, selectedCourse.id!);
                      setState(() {
                        _remainingLessons = invoice.lessons - used;
                      });
                    }
                  }
                }
              },
            ),
            if (_remainingLessons > 0) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Remaining Lessons: $_remainingLessons',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedStudent != null &&
                _availableCourses.isEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No lessons remaining. Please create an invoice first.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
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

  Widget _buildInstructorSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_pin, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Instructor & Vehicle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<User>(
              value: _selectedInstructor,
              decoration: InputDecoration(
                labelText: 'Select Instructor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.supervisor_account),
              ),
              validator: (value) =>
                  value == null ? 'Please select an instructor' : null,
              items: _userController.users
                  .where((user) => user.role.toLowerCase() == 'instructor')
                  .where((instructor) {
                    // For practical lessons, only show instructors with assigned vehicles
                    if (_selectedClassType == 'Practical') {
                      return _fleetController.fleet.any(
                        (vehicle) => vehicle.instructor == instructor.id,
                      );
                    }
                    // For theory lessons, show all instructors
                    return true;
                  })
                  .map((user) => DropdownMenuItem(
                        value: user,
                        child: Text('${user.fname} ${user.lname}'),
                      ))
                  .toList(),
              onChanged: (User? value) {
                setState(() {
                  _selectedInstructor = value;
                  _showAvailabilityStatus = false;
                  _instructorAvailable = true;
                });
                if (value != null) {
                  _assignInstructorVehicle(value);
                  _checkInstructorAvailability();
                }
              },
            ),
            SizedBox(height: 16),
            // Vehicle field - make it read-only for practical lessons
            if (_selectedClassType == 'Practical') ...[
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Assigned Vehicle',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                  suffixIcon: Icon(Icons.lock, color: Colors.grey),
                ),
                controller: TextEditingController(
                  text: _selectedVehicle != null
                      ? '${_selectedVehicle!.make} ${_selectedVehicle!.model} (${_selectedVehicle!.carPlate})'
                      : 'No vehicle assigned to instructor',
                ),
                validator: (value) => _selectedVehicle == null
                    ? 'Instructor must have an assigned vehicle for practical lessons'
                    : null,
              ),
              SizedBox(height: 8),
              Text(
                'Vehicle is automatically assigned based on instructor selection',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              // For theory lessons, vehicle is optional and can be manually selected
              DropdownButtonFormField<Fleet>(
                value: _selectedVehicle,
                decoration: InputDecoration(
                  labelText: 'Vehicle (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: [
                  DropdownMenuItem<Fleet>(
                    value: null,
                    child: Text('No vehicle required'),
                  ),
                  ..._fleetController.fleet
                      .map((vehicle) => DropdownMenuItem(
                            value: vehicle,
                            child: Text(
                                '${vehicle.make} ${vehicle.model} (${vehicle.carPlate})'),
                          ))
                      .toList(),
                ],
                onChanged: (Fleet? value) {
                  setState(() {
                    _selectedVehicle = value;
                  });
                },
              ),
            ],
            if (_showAvailabilityStatus) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _instructorAvailable
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _instructorAvailable
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _instructorAvailable ? Icons.check_circle : Icons.error,
                      color: _instructorAvailable ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _instructorAvailable
                          ? 'Instructor Available'
                          : 'Instructor Not Available - Time Conflict',
                      style: TextStyle(
                        color: _instructorAvailable
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
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

  Widget _buildDateTimeSection() {
    final settingsController = Get.find<SettingsController>();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Date & Time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event, color: Colors.blue),
              title: Text('Date'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate)),
                  if (settingsController.operatingDays.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      'Operating days: ${settingsController.operatingDays.join(', ')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _selectDate(),
            ),
            Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.access_time, color: Colors.green),
              title: Text('Start Time'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_startTime.format(context)),
                  if (settingsController
                      .businessStartTime.value.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      'Business hours: ${settingsController.businessStartTime.value} - ${settingsController.businessEndTime.value}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _selectTime(true),
            ),
            Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.timer, color: Colors.orange),
              title: Text('End Time'),
              subtitle: Text(_endTime.format(context)),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _selectTime(false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _canSchedule() ? _saveSchedule : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              widget.existingSchedule != null
                  ? 'Update Lesson'
                  : 'Schedule Lesson',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Get.back(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(bool isStartTime) async {
    try {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: isStartTime ? _startTime : _endTime,
      );

      if (picked != null) {
        setState(() {
          if (isStartTime) {
            _startTime = picked;
            // Ensure end time is after start time using safe method
            final nextHour = (picked.hour + 1) % 24;
            _endTime = TimeOfDay(
              hour: nextHour,
              minute: picked.minute,
            );
          } else {
            _endTime = picked;
          }
        });

        // Re-check instructor availability when time changes
        if (_selectedInstructor != null) {
          _checkInstructorAvailability();
        }
      }
    } catch (e) {
      print('Error in time picker: $e');
      Get.snackbar(
        'Error',
        'Failed to select time. Please try again.',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final schedule = Schedule(
        id: widget.existingSchedule?.id,
        start: startDateTime,
        end: endDateTime,
        courseId: _selectedCourse!.id!,
        studentId: _selectedStudent!.id!,
        instructorId: _selectedInstructor!.id!,
        carId: _selectedVehicle?.id,
        classType: _selectedClassType,
        status: _selectedStatus,
      );

      await _scheduleController.addOrUpdateSchedule(schedule);

      // Show success dialog instead of just snackbar
      await _showSuccessDialog(schedule);

      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to schedule lesson: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showSuccessDialog(Schedule schedule) async {
    await Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text(
              'Lesson Scheduled Successfully',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.person, 'Student',
                        '${_selectedStudent?.fname} ${_selectedStudent?.lname}'),
                    SizedBox(height: 8),
                    _buildDetailRow(Icons.person_pin, 'Instructor',
                        '${_selectedInstructor?.fname} ${_selectedInstructor?.lname}'),
                    SizedBox(height: 8),
                    _buildDetailRow(
                        Icons.book, 'Course', '${_selectedCourse?.name}'),
                    SizedBox(height: 8),
                    _buildDetailRow(
                        Icons.calendar_today,
                        'Date',
                        DateFormat('EEEE, MMMM dd, yyyy')
                            .format(schedule.start)),
                    SizedBox(height: 8),
                    _buildDetailRow(Icons.access_time, 'Time',
                        '${DateFormat('hh:mm a').format(schedule.start)} - ${DateFormat('hh:mm a').format(schedule.end)}'),
                    if (_selectedVehicle != null) ...[
                      SizedBox(height: 8),
                      _buildDetailRow(Icons.directions_car, 'Vehicle',
                          '${_selectedVehicle!.make} ${_selectedVehicle!.model} (${_selectedVehicle!.carPlate})'),
                    ],
                    SizedBox(height: 8),
                    _buildDetailRow(Icons.flag, 'Status', _selectedStatus),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Remaining lessons for ${_selectedCourse?.name}: ${_remainingLessons - 1}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Get.back();
                    // Schedule another lesson for the same student
                    setState(() {
                      _selectedDate = DateTime.now();
                      _startTime = TimeOfDay(hour: 9, minute: 0);
                      _endTime = TimeOfDay(hour: 10, minute: 0);
                      _selectedStatus = 'Scheduled';
                      _showAvailabilityStatus = false;
                    });
                  },
                  icon: Icon(Icons.add),
                  label: Text('Schedule Another'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.check),
                  label: Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _cancelSchedule() async {
    if (widget.existingSchedule?.id == null) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Cancel Lesson'),
        content: Text('Are you sure you want to cancel this lesson?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('Yes'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _scheduleController.cancelSchedule(widget.existingSchedule!.id!);
      Get.back();
    }
  }

  Future<void> _rescheduleLesson() async {
    // Reset form to allow rescheduling
    setState(() {
      _selectedDate = DateTime.now();
      _startTime = TimeOfDay.now();
      _endTime = _getDefaultEndTime();
      _showAvailabilityStatus = false;
    });
  }

  TimeOfDay _getDefaultEndTime() {
    final now = TimeOfDay.now();
    final nextHour = (now.hour + 1) % 24; // Use modulo to wrap 23+1 to 0
    return TimeOfDay(hour: nextHour, minute: now.minute);
  }

  Future<void> _markAttended(bool attended) async {
    if (widget.existingSchedule?.id == null) return;

    await _scheduleController.toggleAttendance(
      widget.existingSchedule!.id!,
      attended,
    );
    Get.back();
  }

  TimeOfDay _parseTimeString(String timeString) {
    try {
      // Validate timeString format
      if (timeString.isEmpty || !timeString.contains(':')) {
        print('Invalid time string format: $timeString, using default 09:00');
        return const TimeOfDay(hour: 9, minute: 0);
      }

      final parts = timeString.trim().split(':');
      if (parts.length != 2) {
        print('Invalid time string parts: $timeString, using default 09:00');
        return const TimeOfDay(hour: 9, minute: 0);
      }

      final hour = int.tryParse(parts[0].trim()) ?? 9;
      final minute = int.tryParse(parts[1].trim()) ?? 0;

      // Validate hour range (0-23)
      if (hour < 0 || hour > 23) {
        print('Invalid hour value: $hour, using default 9');
        return TimeOfDay(hour: 9, minute: minute.clamp(0, 59));
      }

      // Validate minute range (0-59)
      if (minute < 0 || minute > 59) {
        print('Invalid minute value: $minute, using default 0');
        return TimeOfDay(hour: hour, minute: 0);
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      print('Error parsing time string "$timeString": $e, using default 09:00');
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

// Helper method to check if selected time is outside working hours
  bool _isTimeOutsideWorkingHours(TimeOfDay startTime, TimeOfDay endTime,
      TimeOfDay workingStart, TimeOfDay workingEnd) {
    // Convert TimeOfDay to minutes for easier comparison
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;
    int workingStartMinutes = workingStart.hour * 60 + workingStart.minute;
    int workingEndMinutes = workingEnd.hour * 60 + workingEnd.minute;

    // Check if lesson starts before working hours or ends after working hours
    return startMinutes < workingStartMinutes || endMinutes > workingEndMinutes;
  }

// Enhanced form validation messages with working hours and operating days validation
  Widget _buildValidationMessages() {
    List<String> errors = [];
    List<String> warnings = [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (selectedDay.isBefore(today)) {
      errors.add('Cannot schedule lessons for past dates');
    }

    // Check for past time on today's date
    final startDateTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _startTime.hour, _startTime.minute);
    final endDateTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _endTime.hour, _endTime.minute);

    // If it's today, check if the start time is in the past
    if (selectedDay.isAtSameMomentAs(today) && startDateTime.isBefore(now)) {
      errors.add('Cannot schedule lessons for past times');
    }

    // NEW: Check if the selected day is a business operating day
    final settingsController = Get.find<SettingsController>();
    final selectedDayName = _getDayName(_selectedDate.weekday);

    if (settingsController.operatingDays.isNotEmpty &&
        !settingsController.operatingDays.contains(selectedDayName)) {
      errors.add(
          'Business is closed on ${selectedDayName}s. Operating days: ${settingsController.operatingDays.join(', ')}');
    }

    final duration = endDateTime.difference(startDateTime);

    if (duration.inMinutes <= 0) {
      errors.add('End time must be after start time');
    } else if (duration.inMinutes < 30) {
      warnings.add('Lesson duration is less than 30 minutes');
    } else if (duration.inHours > 4) {
      warnings.add('Lesson duration exceeds 4 hours');
    }

    // Working hours validation
    if (settingsController.enforceWorkingHours.value &&
        _selectedInstructor != null) {
      final startTime =
          TimeOfDay(hour: _startTime.hour, minute: _startTime.minute);
      final endTime = TimeOfDay(hour: _endTime.hour, minute: _endTime.minute);

      final workingStart =
          _parseTimeString(settingsController.businessStartTime.value);
      final workingEnd =
          _parseTimeString(settingsController.businessEndTime.value);

      if (_isTimeOutsideWorkingHours(
          startTime, endTime, workingStart, workingEnd)) {
        errors.add(
            'Schedule time is outside business hours (${settingsController.businessStartTime.value} - ${settingsController.businessEndTime.value})');
      }

      // Check for break between lessons if enabled
      if (!settingsController.allowBackToBackLessons.value) {
        final breakMinutes = settingsController.breakBetweenLessons.value;
        final conflictingSchedules =
            _scheduleController.schedules.where((schedule) {
          if (schedule.instructorId != _selectedInstructor!.id) return false;

          final scheduleDate = DateTime(
              schedule.start.year, schedule.start.month, schedule.start.day);
          final selectedScheduleDate = DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day);

          if (!scheduleDate.isAtSameMomentAs(selectedScheduleDate))
            return false;

          // Check if there's a schedule that ends within break time of our start time
          final timeDifference =
              startDateTime.difference(schedule.end).inMinutes;
          return timeDifference > 0 && timeDifference < breakMinutes;
        }).toList();

        if (conflictingSchedules.isNotEmpty) {
          warnings.add(
              'Less than ${breakMinutes} minutes break from previous lesson');
        }
      }
    }

    if (errors.isEmpty && warnings.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ...errors.map(
              (error) => _buildMessageCard(error, Colors.red, Icons.error)),
          ...warnings.map((warning) =>
              _buildMessageCard(warning, Colors.orange, Icons.warning)),
        ],
      ),
    );
  }

// Helper method to get day name from weekday number
  String _getDayName(int weekday) {
    const days = [
      'Monday', // 1
      'Tuesday', // 2
      'Wednesday', // 3
      'Thursday', // 4
      'Friday', // 5
      'Saturday', // 6
      'Sunday', // 7
    ];
    return days[weekday - 1];
  }

// Update the _canSchedule method to include operating days validation
  bool _canSchedule() {
    // Check basic requirements
    if (_selectedStudent == null ||
        _selectedInstructor == null ||
        _selectedCourse == null ||
        _remainingLessons <= 0) {
      return false;
    }

    // Check if instructor is available
    if (!_instructorAvailable) {
      return false;
    }

    // Check if vehicle is required and available for practical lessons
    if (_selectedClassType == 'Practical') {
      if (_selectedVehicle == null) {
        return false;
      }
      // Ensure the vehicle is actually assigned to the selected instructor
      if (_selectedVehicle!.instructor != _selectedInstructor!.id) {
        return false;
      }
    }

    // Check for validation errors
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    // Check if date is in the past
    if (selectedDay.isBefore(today)) {
      return false;
    }

    // Check if time is in the past for today's date
    if (selectedDay.isAtSameMomentAs(today)) {
      final startDateTime = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _startTime.hour, _startTime.minute);
      if (startDateTime.isBefore(now)) {
        return false;
      }
    }

    // Check if the selected day is a business operating day
    final settingsController = Get.find<SettingsController>();
    final selectedDayName = _getDayName(_selectedDate.weekday);

    if (settingsController.operatingDays.isNotEmpty &&
        !settingsController.operatingDays.contains(selectedDayName)) {
      return false;
    }

    // Check if end time is after start time
    final endDateTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _endTime.hour, _endTime.minute);
    final startDateTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _startTime.hour, _startTime.minute);

    if (endDateTime.isBefore(startDateTime) ||
        endDateTime.isAtSameMomentAs(startDateTime)) {
      return false;
    }

    return true;
  }

// Update the date picker to only show operating days
  Future<void> _selectDate() async {
    final settingsController = Get.find<SettingsController>();

    // Find a valid initial date that satisfies the predicate
    DateTime initialDate = _selectedDate;

    // If operating days are configured, ensure initialDate is valid
    if (settingsController.operatingDays.isNotEmpty) {
      final currentDayName = _getDayName(initialDate.weekday);

      // If current date is not an operating day, find the next valid day
      if (!settingsController.operatingDays.contains(currentDayName)) {
        // Start from today and find the next operating day
        DateTime searchDate = DateTime.now();
        while (searchDate.isBefore(DateTime.now().add(Duration(days: 365)))) {
          final dayName = _getDayName(searchDate.weekday);
          if (settingsController.operatingDays.contains(dayName)) {
            initialDate = searchDate;
            break;
          }
          searchDate = searchDate.add(Duration(days: 1));
        }
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      selectableDayPredicate: (DateTime date) {
        // If no operating days are set, allow all days
        if (settingsController.operatingDays.isEmpty) {
          return true;
        }

        final dayName = _getDayName(date.weekday);
        return settingsController.operatingDays.contains(dayName);
      },
      helpText: settingsController.operatingDays.isNotEmpty
          ? 'Select date (Operating days: ${settingsController.operatingDays.join(', ')})'
          : 'Select date',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _checkInstructorAvailability();
    }
  }

  Widget _buildMessageCard(String message, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
