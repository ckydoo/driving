import 'package:driving/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/schedule.dart';
import '../../models/user.dart';
import '../../models/course.dart';
import '../../models/fleet.dart';
import '../../models/invoice.dart';
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
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime =
      TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

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

  final List<String> _classTypes = ['Practical', 'Theory'];
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
              value: _selectedClassType,
              decoration: InputDecoration(
                labelText: 'Class Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.class_),
              ),
              items: _classTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (String? value) {
                setState(() {
                  _selectedClassType = value!;
                });
              },
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
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
          // Auto-adjust end time to be 1 hour later
          _endTime = TimeOfDay(
            hour: (picked.hour + 1) % 24,
            minute: picked.minute,
          );
        } else {
          _endTime = picked;
        }
      });
      _checkInstructorAvailability();
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
      _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
      _showAvailabilityStatus = false;
    });
  }

  Future<void> _markAttended(bool attended) async {
    if (widget.existingSchedule?.id == null) return;

    await _scheduleController.toggleAttendance(
      widget.existingSchedule!.id!,
      attended,
    );
    Get.back();
  }

  // Enhanced Billing Status Widget for consistent UI
// Add this to your schedule form to show billing information consistently

  Widget _buildBillingStatusCard() {
    if (_selectedStudent == null || _selectedCourse == null) {
      return SizedBox.shrink();
    }

    final billingController = Get.find<BillingController>();
    final settingsController = Get.find<SettingsController>();

    // Get invoice for this student and course
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) =>
          inv.studentId == _selectedStudent!.id &&
          inv.courseId == _selectedCourse!.id,
    );

    if (invoice == null) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red[600], size: 20),
                SizedBox(width: 8),
                Text(
                  'No Billing Found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'This student does not have an active invoice for the selected course. Please create an invoice before scheduling lessons.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to create invoice screen
                Get.toNamed('/billing/create', arguments: {
                  'studentId': _selectedStudent!.id,
                  'courseId': _selectedCourse!.id,
                });
              },
              icon: Icon(Icons.add),
              label: Text('Create Invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate lesson usage
    final totalLessons = invoice.lessons;
    final usedLessons =
        _getUsedLessons(_selectedStudent!.id!, _selectedCourse!.id!);
    final scheduledLessons = settingsController.countScheduledLessons.value
        ? _getScheduledLessons(_selectedStudent!.id!, _selectedCourse!.id!)
        : 0;
    final remainingLessons = totalLessons - usedLessons - scheduledLessons;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (remainingLessons <= 0) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'No lessons remaining';
    } else if (remainingLessons <=
        settingsController.lowLessonThreshold.value) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Low lesson balance';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Sufficient lessons available';
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Billing Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLessonCounter(
                  'Total',
                  totalLessons.toString(),
                  Colors.blue,
                  Icons.book,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildLessonCounter(
                  'Used',
                  usedLessons.toString(),
                  Colors.grey,
                  Icons.check,
                ),
              ),
              if (settingsController.countScheduledLessons.value) ...[
                SizedBox(width: 12),
                Expanded(
                  child: _buildLessonCounter(
                    'Scheduled',
                    scheduledLessons.toString(),
                    Colors.orange,
                    Icons.schedule,
                  ),
                ),
              ],
              SizedBox(width: 12),
              Expanded(
                child: _buildLessonCounter(
                  'Remaining',
                  remainingLessons.toString(),
                  statusColor,
                  Icons.inventory,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: totalLessons > 0
                ? (totalLessons - remainingLessons) / totalLessons
                : 0,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              Text(
                'Invoice #${invoice.id}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (remainingLessons <= 0 &&
              settingsController.enforceBillingValidation.value) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red[700], size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cannot schedule lesson - billing validation enabled',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildLessonCounter(
      String label, String count, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

// Helper method to get scheduled lessons count
  int _getScheduledLessons(int studentId, int courseId) {
    final scheduleController = Get.find<ScheduleController>();
    return scheduleController.schedules
        .where((s) =>
            s.studentId == studentId &&
            s.courseId == courseId &&
            !s.attended &&
            s.status != 'Cancelled' &&
            s.start.isAfter(DateTime.now()))
        .fold<int>(0, (sum, s) => sum + (s.lessonsCompleted ?? 1));
  }

// Helper method to get used lessons count

// Enhanced Submit Button with validation
  Widget _buildSubmitButton() {
    final canSubmit = _selectedStudent != null &&
        _selectedInstructor != null &&
        _selectedCourse != null &&
        _selectedDate != null &&
        _startTime != null &&
        _endTime != null &&
        _isValidForSubmission();

    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: canSubmit ? _saveSchedule : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canSubmit ? Colors.blue[600] : Colors.grey[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canSubmit ? 2 : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
            ],
            Icon(
              widget.existingSchedule != null ? Icons.update : Icons.add,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              _isLoading
                  ? 'Processing...'
                  : widget.existingSchedule != null
                      ? 'Update Schedule'
                      : 'Create Schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Validation method for submission
  bool _isValidForSubmission() {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      return false;
    }

    // Check if date is not in the past
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay =
        DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);

    if (selectedDay.isBefore(today)) {
      return false;
    }

    // Check duration
    final startDateTime = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day, _startTime!.hour, _startTime!.minute);
    final endDateTime = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day, _endTime!.hour, _endTime!.minute);
    final duration = endDateTime.difference(startDateTime);

    if (duration.inMinutes < 30 || duration.inHours > 4) {
      return false;
    }

    // Check billing if validation is enabled
    final settingsController = Get.find<SettingsController>();
    if (settingsController.enforceBillingValidation.value &&
        _selectedStudent != null &&
        _selectedCourse != null) {
      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == _selectedStudent!.id &&
            inv.courseId == _selectedCourse!.id,
      );

      if (invoice == null) return false;

      final usedLessons =
          _getUsedLessons(_selectedStudent!.id!, _selectedCourse!.id!);
      final scheduledLessons = settingsController.countScheduledLessons.value
          ? _getScheduledLessons(_selectedStudent!.id!, _selectedCourse!.id!)
          : 0;
      final remainingLessons = invoice.lessons - usedLessons - scheduledLessons;

      if (remainingLessons <= 0) return false;
    }

    return true;
  }

// Enhanced form validation messages
  Widget _buildValidationMessages() {
    List<String> errors = [];
    List<String> warnings = [];

    if (_selectedDate != null && _startTime != null && _endTime != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDay = DateTime(
          _selectedDate!.year, _selectedDate!.month, _selectedDate!.day);

      if (selectedDay.isBefore(today)) {
        errors.add('Cannot schedule lessons for past dates');
      }

      final startDateTime = DateTime(_selectedDate!.year, _selectedDate!.month,
          _selectedDate!.day, _startTime!.hour, _startTime!.minute);
      final endDateTime = DateTime(_selectedDate!.year, _selectedDate!.month,
          _selectedDate!.day, _endTime!.hour, _endTime!.minute);
      final duration = endDateTime.difference(startDateTime);

      if (duration.inMinutes <= 0) {
        errors.add('End time must be after start time');
      } else if (duration.inMinutes < 30) {
        warnings.add('Lesson duration is less than 30 minutes');
      } else if (duration.inHours > 4) {
        warnings.add('Lesson duration exceeds 4 hours');
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
