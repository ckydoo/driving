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
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0); // Fixed initialization
  TimeOfDay _endTime = TimeOfDay(hour: 10, minute: 0); // Fixed initialization

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

  final List<String> _statusOptions = ['Scheduled', 'Confirmed', 'Pending'];

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
      // Get student's invoices to determine available courses
      final studentInvoices = _billingController.invoices
          .where((invoice) => invoice.studentId == student.id)
          .toList();

      if (studentInvoices.isEmpty) {
        // No billing found - show error and prevent scheduling
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
        });
        return;
      }

      List<Course> validCourses = [];
      for (var invoice in studentInvoices) {
        final course = _courseController.courses.firstWhereOrNull(
          (c) => c.id == invoice.courseId,
        );
        if (course != null) {
          final usedLessons = _getUsedLessons(student.id!, invoice.courseId);
          final remaining = invoice.lessons - usedLessons;

          // Only include courses with remaining lessons
          if (remaining > 0) {
            validCourses.add(course);
          }
        }
      }

      if (validCourses.isEmpty) {
        // Student has invoices but no remaining lessons
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
        });
        return;
      }

      // Auto-select the first course with most remaining lessons
      validCourses.sort((a, b) {
        final aInvoice =
            studentInvoices.firstWhere((inv) => inv.courseId == a.id);
        final bInvoice =
            studentInvoices.firstWhere((inv) => inv.courseId == b.id);
        final aRemaining =
            aInvoice.lessons - _getUsedLessons(student.id!, a.id!);
        final bRemaining =
            bInvoice.lessons - _getUsedLessons(student.id!, b.id!);
        return bRemaining.compareTo(aRemaining); // Descending order
      });

      setState(() {
        _availableCourses = validCourses;
        _selectedCourse = validCourses.first;

        // Set remaining lessons for selected course
        final invoice = studentInvoices.firstWhere(
          (inv) => inv.courseId == _selectedCourse!.id,
        );
        _remainingLessons = invoice.lessons -
            _getUsedLessons(student.id!, _selectedCourse!.id!);
      });

      // Auto-assign instructor's vehicle if available
      if (_selectedInstructor != null) {
        _assignInstructorVehicle(_selectedInstructor!);
      }

      // Show success message with lesson count
      Get.snackbar(
        'Student Selected',
        'Found ${validCourses.length} course(s) with remaining lessons',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load student courses: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() {
        _availableCourses = [];
        _remainingLessons = 0;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _getUsedLessons(int studentId, int courseId) {
    return _scheduleController.schedules
        .where((s) =>
            s.studentId == studentId && s.courseId == courseId && s.attended)
        .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);
  }

  void _assignInstructorVehicle(User instructor) {
    // Find vehicle assigned to instructor
    final assignedVehicle = _fleetController.fleet.firstWhereOrNull(
      (vehicle) => vehicle.instructor == instructor.id,
    );

    if (assignedVehicle != null) {
      setState(() {
        _selectedVehicle = assignedVehicle;
      });
    }
  }

  Future<void> _checkInstructorAvailability() async {
    if (_selectedInstructor == null) return;

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

    final available = await _scheduleController.checkAvailability(
      _selectedInstructor!.id!,
      startDateTime,
      endDateTime,
    );

    setState(() {
      _instructorAvailable = available;
      _showAvailabilityStatus = true;
    });
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
                    _buildValidationMessages(), // ← ADD THIS LINE
                    SizedBox(height: 20),
                    _buildLessonDetailsSection(),
                    SizedBox(height: 30),
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
            DropdownButtonFormField<Course>(
              value: _selectedCourse,
              decoration: InputDecoration(
                labelText: 'Available Courses',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.library_books),
              ),
              validator: (value) =>
                  value == null ? 'Please select a course' : null,
              items: _availableCourses
                  .map((course) => DropdownMenuItem(
                        value: course,
                        child: Text(course.name),
                      ))
                  .toList(),
              onChanged: (Course? value) {
                setState(() {
                  _selectedCourse = value;
                });
                if (value != null && _selectedStudent != null) {
                  final invoice = _billingController.invoices.firstWhereOrNull(
                    (inv) =>
                        inv.studentId == _selectedStudent!.id &&
                        inv.courseId == value.id,
                  );
                  if (invoice != null) {
                    final used =
                        _getUsedLessons(_selectedStudent!.id!, value.id!);
                    setState(() {
                      _remainingLessons = invoice.lessons - used;
                    });
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
                  .map((user) => DropdownMenuItem(
                        value: user,
                        child: Text('${user.fname} ${user.lname}'),
                      ))
                  .toList(),
              onChanged: (User? value) {
                setState(() {
                  _selectedInstructor = value;
                  _showAvailabilityStatus = false;
                });
                if (value != null) {
                  _assignInstructorVehicle(value);
                  _checkInstructorAvailability();
                }
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<Fleet>(
              value: _selectedVehicle,
              decoration: InputDecoration(
                labelText: 'Vehicle',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              items: _fleetController.fleet
                  .map((vehicle) => DropdownMenuItem(
                        value: vehicle,
                        child: Text(
                            '${vehicle.make} ${vehicle.model} (${vehicle.carPlate})'),
                      ))
                  .toList(),
              onChanged: (Fleet? value) {
                setState(() {
                  _selectedVehicle = value;
                });
              },
            ),
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
                          : 'Instructor Not Available',
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
              subtitle:
                  Text(DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate)),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _selectDate(),
            ),
            Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.access_time, color: Colors.green),
              title: Text('Start Time'),
              subtitle: Text(_startTime.format(context)),
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

  Widget _buildLessonDetailsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Lesson Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
              items: _statusOptions
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (String? value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
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

  bool _canSchedule() {
    return _selectedStudent != null &&
        _selectedInstructor != null &&
        _selectedCourse != null &&
        _remainingLessons > 0 &&
        _instructorAvailable;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _checkInstructorAvailability();
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    try {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: isStartTime ? _startTime! : _endTime!,
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
      Get.back();
      Get.snackbar(
        'Success',
        'Lesson scheduled successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
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

// Helper method to get scheduled lessons count

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

// Also add this method to validate working hours before using them:

  bool _isValidTimeString(String timeString) {
    try {
      if (timeString.isEmpty || !timeString.contains(':')) return false;

      final parts = timeString.trim().split(':');
      if (parts.length != 2) return false;

      final hour = int.tryParse(parts[0].trim());
      final minute = int.tryParse(parts[1].trim());

      if (hour == null || minute == null) return false;
      if (hour < 0 || hour > 23) return false;
      if (minute < 0 || minute > 59) return false;

      return true;
    } catch (e) {
      return false;
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

// Enhanced form validation messages with working hours validation
  Widget _buildValidationMessages() {
    List<String> errors = [];
    List<String> warnings = [];

    if (_selectedDate != null && _startTime != null && _endTime != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDay =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

      if (selectedDay.isBefore(today)) {
        errors.add('Cannot schedule lessons for past dates');
      }

      final startDateTime = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _startTime.hour, _startTime.minute);
      final endDateTime = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _endTime.hour, _endTime.minute);
      final duration = endDateTime.difference(startDateTime);

      if (duration.inMinutes <= 0) {
        errors.add('End time must be after start time');
      } else if (duration.inMinutes < 30) {
        warnings.add('Lesson duration is less than 30 minutes');
      } else if (duration.inHours > 4) {
        warnings.add('Lesson duration exceeds 4 hours');
      }

      // NEW: Working hours validation
      final settingsController = Get.find<SettingsController>();
      if (settingsController.enforceWorkingHours.value &&
          _selectedInstructor != null) {
        final startTime =
            TimeOfDay(hour: _startTime.hour, minute: _startTime.minute);
        final endTime = TimeOfDay(hour: _endTime.hour, minute: _endTime.minute);

        final workingStart =
            _parseTimeString(settingsController.workingHoursStart.value);
        final workingEnd =
            _parseTimeString(settingsController.workingHoursEnd.value);

        if (_isTimeOutsideWorkingHours(
            startTime, endTime, workingStart, workingEnd)) {
          errors.add(
              'Schedule time is outside instructor working hours (${settingsController.workingHoursStart.value} - ${settingsController.workingHoursEnd.value})');
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
