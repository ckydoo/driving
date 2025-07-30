// lib/screens/schedule/recurring_schedule_screen.dart
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/widgets/recuring_progress.dart';
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

class RecurringScheduleScreen extends StatefulWidget {
  const RecurringScheduleScreen({Key? key}) : super(key: key);

  @override
  _RecurringScheduleScreenState createState() =>
      _RecurringScheduleScreenState();
}

class _RecurringScheduleScreenState extends State<RecurringScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scheduleController = Get.find<ScheduleController>();
  final _userController = Get.find<UserController>();
  final _courseController = Get.find<CourseController>();
  final _fleetController = Get.find<FleetController>();
  final _billingController = Get.find<BillingController>();
  DateTime _selectedDate = DateTime.now();

  // Form fields
  DateTime _selectedStartDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0); // Fixed initialization
  TimeOfDay _endTime = TimeOfDay(hour: 10, minute: 0); // Fixed initialization

  User? _selectedStudent;
  User? _selectedInstructor;
  Course? _selectedCourse;
  Fleet? _selectedVehicle;
  String _selectedClassType = 'Practical';
  String _selectedStatus = 'Scheduled';

  // Recurring specific fields
  String _recurrencePattern = 'weekly';
  DateTime? _recurrenceEndDate;
  List<int> _selectedDaysOfWeek = [];
  int _customInterval = 1;
  int _maxOccurrences = 10;
  bool _useEndDate = true;

  bool _isLoading = false;
  int _previewCount = 0;
  List<Course> _availableCourses = [];
  int _remainingLessons = 0;
  int _maxPossibleLessons = 0;
  bool _showAvailabilityWarning = false;

  final List<String> _classTypes = ['Practical', 'Theory'];
  final List<String> _statusOptions = ['Scheduled', 'Confirmed', 'Pending'];
  final List<String> _recurrencePatterns = [
    'daily',
    'weekly',
    'monthly',
    'custom'
  ];

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _recurrenceEndDate = DateTime.now().add(Duration(days: 30));
    _selectedDaysOfWeek = [DateTime.now().weekday]; // Default to today
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Recurring Schedule'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
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
                    _buildRecurrenceSection(),
                    SizedBox(height: 20),
                    _buildLessonDetailsSection(),
                    SizedBox(height: 20),
                    _buildPreviewSection(),
                    SizedBox(height: 30),
                    _buildActionButtons(),
                    SizedBox(height: 20),
                    _buildValidationMessages(),
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
                  _updateLessonCounts();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                    if (_maxPossibleLessons > 0) ...[
                      SizedBox(height: 4),
                      Text(
                        'Max recurring lessons possible: $_maxPossibleLessons',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                });
                if (value != null) {
                  _assignInstructorVehicle(value);
                  _updatePreviewCount();
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
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.repeat, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Recurrence Pattern',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Pattern Selection
            Text('Repeat:', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _recurrencePatterns.map((pattern) {
                return _buildRecurrenceChip(pattern);
              }).toList(),
            ),

            SizedBox(height: 16),

            // Start Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event, color: Colors.blue),
              title: Text('Start Date'),
              subtitle: Text(
                  DateFormat('EEEE, MMMM dd, yyyy').format(_selectedStartDate)),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _selectStartDate(),
            ),

            Divider(),

            // Time Selection
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.access_time, color: Colors.green),
                    title: Text('Start Time'),
                    subtitle: Text(_startTime.format(context)),
                    onTap: () => _selectTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.timer, color: Colors.orange),
                    title: Text('End Time'),
                    subtitle: Text(_endTime.format(context)),
                    onTap: () => _selectTime(false),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Pattern-specific options
            if (_recurrencePattern == 'weekly') _buildWeeklyOptions(),
            if (_recurrencePattern == 'custom') _buildCustomOptions(),

            SizedBox(height: 16),

            // End condition
            _buildEndConditionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceChip(String pattern) {
    final isSelected = _recurrencePattern == pattern;
    return FilterChip(
      label: Text(pattern.capitalize ?? pattern),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _recurrencePattern = pattern;
          _updatePreviewCount();
        });
      },
      selectedColor: Colors.green.withOpacity(0.2),
      checkmarkColor: Colors.green,
    );
  }

  Widget _buildWeeklyOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Days:', style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(_daysOfWeek.length, (index) {
            final day = _daysOfWeek[index];
            final isSelected = _selectedDaysOfWeek.contains(index + 1);
            return FilterChip(
              label: Text(day.substring(0, 3)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDaysOfWeek.add(index + 1);
                  } else {
                    _selectedDaysOfWeek.remove(index + 1);
                  }
                  _selectedDaysOfWeek.sort();
                  _updatePreviewCount();
                });
              },
              selectedColor: Colors.blue.withOpacity(0.2),
              checkmarkColor: Colors.blue,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCustomOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Every:', style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 80,
              child: TextFormField(
                initialValue: _customInterval.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (value) {
                  setState(() {
                    _customInterval = int.tryParse(value) ?? 1;
                    _updatePreviewCount();
                  });
                },
              ),
            ),
            SizedBox(width: 8),
            Text('days'),
          ],
        ),
      ],
    );
  }

  Widget _buildEndConditionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('End Condition:', style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: _useEndDate,
              onChanged: (value) {
                setState(() {
                  _useEndDate = value!;
                  _updatePreviewCount();
                });
              },
            ),
            Text('End Date'),
          ],
        ),
        if (_useEndDate) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.event_available, color: Colors.red),
            title: Text('End Date'),
            subtitle: Text(
                DateFormat('EEEE, MMMM dd, yyyy').format(_recurrenceEndDate!)),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () => _selectEndDate(),
          ),
        ],
        Row(
          children: [
            Radio<bool>(
              value: false,
              groupValue: _useEndDate,
              onChanged: (value) {
                setState(() {
                  _useEndDate = value!;
                  _updatePreviewCount();
                });
              },
            ),
            Text('Number of Lessons'),
          ],
        ),
        if (!_useEndDate) ...[
          Container(
            width: 120,
            child: TextFormField(
              initialValue: _maxOccurrences.toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Lessons',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _maxOccurrences = int.tryParse(value) ?? 10;
                  _updatePreviewCount();
                });
              },
            ),
          ),
        ],
      ],
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
                Icon(Icons.settings, color: Colors.indigo),
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

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Schedule Preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Total lessons to schedule: $_previewCount',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (_previewCount > _remainingLessons &&
                      _remainingLessons > 0) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Warning: There are only have $_remainingLessons lessons remaining.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_previewCount > 0 &&
                      _previewCount <= _remainingLessons) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ready to schedule. Lessons will be deducted from billing.',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
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
            onPressed: _canSchedule() ? _createRecurringSchedule : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Create Recurring Schedule',
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

  // Helper methods
  Future<void> _loadStudentCourses(User student) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final studentInvoices = _billingController.invoices
          .where((invoice) => invoice.studentId == student.id)
          .toList();

      if (studentInvoices.isNotEmpty) {
        List<Course> courses = [];
        for (var invoice in studentInvoices) {
          final course = _courseController.courses.firstWhereOrNull(
            (c) => c.id == invoice.courseId,
          );
          if (course != null) {
            final usedLessons = _getUsedLessons(student.id!, invoice.courseId);
            final remaining = invoice.lessons - usedLessons;

            if (remaining > 0) {
              courses.add(course);
            }
          }
        }

        setState(() {
          _availableCourses = courses;
          if (courses.isNotEmpty) {
            _selectedCourse = courses.first;
            _updateLessonCounts();
          }
        });
      } else {
        Get.snackbar(
          'No Billing Found',
          'This student has no active billing. Please create an invoice first.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
        setState(() {
          _availableCourses = [];
          _remainingLessons = 0;
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateLessonCounts() {
    if (_selectedStudent != null && _selectedCourse != null) {
      final invoice = _billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == _selectedStudent!.id &&
            inv.courseId == _selectedCourse!.id,
      );
      if (invoice != null) {
        final used =
            _getUsedLessons(_selectedStudent!.id!, _selectedCourse!.id!);
        setState(() {
          _remainingLessons = invoice.lessons - used;
          _maxPossibleLessons = _remainingLessons;
        });
        _updatePreviewCount();
      }
    }
  }

  int _getUsedLessons(int studentId, int courseId) {
    return _scheduleController.schedules
        .where((s) =>
            s.studentId == studentId && s.courseId == courseId && s.attended)
        .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);
  }

  void _assignInstructorVehicle(User instructor) {
    final assignedVehicle = _fleetController.fleet.firstWhereOrNull(
      (vehicle) => vehicle.instructor == instructor.id,
    );

    if (assignedVehicle != null) {
      setState(() {
        _selectedVehicle = assignedVehicle;
      });
    }
  }

  void _updatePreviewCount() {
    if (_selectedInstructor == null) {
      setState(() {
        _previewCount = 0;
      });
      return;
    }

    final endDate = _useEndDate
        ? _recurrenceEndDate!
        : DateTime.now().add(Duration(days: 365));

    DateTime currentDate = _selectedStartDate;
    int count = 0;

    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      if (!_useEndDate && count >= _maxOccurrences) break;

      bool shouldCreateSchedule = false;

      switch (_recurrencePattern) {
        case 'daily':
          shouldCreateSchedule = true;
          break;
        case 'weekly':
          shouldCreateSchedule =
              _selectedDaysOfWeek.contains(currentDate.weekday);
          break;
        case 'monthly':
          shouldCreateSchedule = currentDate.day == _selectedStartDate.day;
          break;
        case 'custom':
          final daysDiff = currentDate.difference(_selectedStartDate).inDays;
          shouldCreateSchedule = daysDiff % _customInterval == 0;
          break;
      }

      if (shouldCreateSchedule) {
        count++;
      }

      // Move to next iteration
      switch (_recurrencePattern) {
        case 'daily':
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case 'weekly':
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case 'monthly':
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
          );
          break;
        case 'custom':
          currentDate = currentDate.add(Duration(days: 1));
          break;
      }

      // Safety check
      if (count > 1000) break;
    }

    setState(() {
      _previewCount = count;
    });
  }

  bool _canSchedule() {
    return _selectedStudent != null &&
        _selectedInstructor != null &&
        _selectedCourse != null &&
        _previewCount > 0 &&
        _previewCount <= _remainingLessons;
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
          _endTime = TimeOfDay(
            hour: (picked.hour + 1) % 24,
            minute: picked.minute,
          );
        } else {
          _endTime = picked;
        }
      });
    }
  }
// Fixed Recurring Schedule Creation - Issue 3: Single progress dialog instead of multiple success messages

  Future<void> _createRecurringSchedule() async {
    if (!_canCreateRecurringSchedule()) {
      Get.snackbar(
        'Validation Error',
        'Please complete all required fields',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Show progress dialog - Issue 3 fix
      Get.dialog(
        RecurringScheduleProgressDialog(
          totalSchedules: _previewCount,
          onComplete: (successCount, conflictCount) {
            _handleRecurringScheduleComplete(successCount, conflictCount);
          },
        ),
        barrierDismissible: false,
      );

      // Generate schedules
      final schedules = <Schedule>[];
      DateTime currentDate = _selectedStartDate;
      int count = 0;

      while (
          count < _previewCount && currentDate.isBefore(_recurrenceEndDate!)) {
        // Skip weekends for weekday patterns
        if (_recurrencePattern == 'weekdays' &&
            (currentDate.weekday == DateTime.saturday ||
                currentDate.weekday == DateTime.sunday)) {
          currentDate = currentDate.add(Duration(days: 1));
          continue;
        }

        final startDateTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          _startTime!.hour,
          _startTime!.minute,
        );

        final endDateTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          _endTime!.hour,
          _endTime!.minute,
        );

        // Check instructor availability
        final available = await _scheduleController.checkAvailability(
          _selectedInstructor!.id!,
          startDateTime,
          endDateTime,
        );

        if (available) {
          final schedule = Schedule(
            start: startDateTime,
            end: endDateTime,
            courseId: _selectedCourse!.id!,
            studentId: _selectedStudent!.id!,
            instructorId: _selectedInstructor!.id!,
            carId: _selectedVehicle?.id,
            status: _selectedStatus,
            isRecurring: true,
            recurrencePattern: _recurrencePattern,
            recurrenceEndDate: _recurrenceEndDate,
            classType: _selectedClassType,
          );

          schedules.add(schedule);
          count++;
        }

        // Move to next iteration
        switch (_recurrencePattern) {
          case 'daily':
          case 'weekdays':
            currentDate = currentDate.add(Duration(days: 1));
            break;
          case 'weekly':
            currentDate = currentDate.add(Duration(days: 7));
            break;
          case 'monthly':
            currentDate = DateTime(
              currentDate.year,
              currentDate.month + 1,
              currentDate.day,
            );
            break;
        }

        if (schedules.length > 1000) break; // Safety check
      }

      // Save schedules with progress updates
      await _saveSchedulesWithProgress(schedules);
    } catch (e) {
      Get.back(); // Close progress dialog
      Get.snackbar(
        'Error',
        'Failed to create recurring schedule: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSchedulesWithProgress(List<Schedule> schedules) async {
    int successCount = 0;
    int conflictCount = 0;

    for (int i = 0; i < schedules.length; i++) {
      try {
        await _scheduleController.addOrUpdateSchedule(schedules[i]);
        successCount++;

        // Update progress - Issue 3 fix
        if (Get.isDialogOpen == true) {
          Get.find<RecurringScheduleProgressController>().updateProgress(
              i + 1, schedules.length, successCount, conflictCount);
        }

        // Small delay to show progress
        await Future.delayed(Duration(milliseconds: 50));
      } catch (e) {
        conflictCount++;
        print('Failed to create schedule: $e');
      }
    }

    // Complete the process
    if (Get.isDialogOpen == true) {
      Get.find<RecurringScheduleProgressController>()
          .complete(successCount, conflictCount);
    }

    // FIXED: Force schedule controller to refresh
    _scheduleController.fetchSchedules();
  }

  void _handleRecurringScheduleComplete(int successCount, int conflictCount) {
    Get.back(); // Close progress dialog
    Get.back(); // Close recurring schedule screen

    // Single success message - Issue 3 fix
    if (successCount > 0) {
      String message =
          '$successCount recurring lessons scheduled successfully!';
      if (conflictCount > 0) {
        message += ' ($conflictCount conflicts skipped)';
      }

      Get.snackbar(
        'Success',
        message,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    } else {
      Get.snackbar(
        'Warning',
        'No lessons could be scheduled due to conflicts.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _selectStartDate() async {
    final scheduleController = Get.find<ScheduleController>();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate:
          scheduleController.getMinimumScheduleDate(), // Prevent past dates
      lastDate: scheduleController.getMaximumScheduleDate(),
      helpText: 'Select Start Date',
      cancelText: 'Cancel',
      confirmText: 'Select',
      errorFormatText: 'Enter valid date',
      errorInvalidText: 'Enter date in valid range',
      fieldLabelText: 'Start Date',
      fieldHintText: 'mm/dd/yyyy',
      selectableDayPredicate: (DateTime date) {
        // Only allow today and future dates
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final checkDate = DateTime(date.year, date.month, date.day);
        return checkDate.isAtSameMomentAs(today) || checkDate.isAfter(today);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[600]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[600],
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedStartDate) {
      setState(() {
        _selectedStartDate = picked;
        // Ensure end date is not before start date
        if (_recurrenceEndDate != null &&
            _recurrenceEndDate!.isBefore(picked)) {
          _recurrenceEndDate = picked.add(Duration(days: 30));
        }
      });
      _updatePreviewCount();
    }
  }

  Future<void> _selectEndDate() async {
    final scheduleController = Get.find<ScheduleController>();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _recurrenceEndDate ?? _selectedStartDate.add(Duration(days: 30)),
      firstDate: _selectedStartDate, // End date must be after start date
      lastDate: scheduleController.getMaximumScheduleDate(),
      helpText: 'Select End Date',
      cancelText: 'Cancel',
      confirmText: 'Select',
      errorFormatText: 'Enter valid date',
      errorInvalidText: 'Enter date in valid range',
      fieldLabelText: 'End Date',
      fieldHintText: 'mm/dd/yyyy',
      selectableDayPredicate: (DateTime date) {
        // End date must be same as or after start date
        final startDay = DateTime(_selectedStartDate.year,
            _selectedStartDate.month, _selectedStartDate.day);
        final checkDate = DateTime(date.year, date.month, date.day);
        return checkDate.isAtSameMomentAs(startDay) ||
            checkDate.isAfter(startDay);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[600]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.green[600],
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _recurrenceEndDate) {
      setState(() {
        _recurrenceEndDate = picked;
      });
      _updatePreviewCount();
    }
  }

// Enhanced date range picker widget
  Widget _buildDateRangeSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: Colors.blue[600], size: 20),
              SizedBox(width: 8),
              Text(
                'Schedule Period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              // Start date
              Expanded(
                child: InkWell(
                  onTap: _selectStartDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blue[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.play_arrow,
                                color: Colors.blue[600], size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Start Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          DateFormat('EEE, MMM dd, yyyy')
                              .format(_selectedStartDate),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // End date (if using end date)
              if (_useEndDate)
                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.green[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.stop,
                                  color: Colors.green[600], size: 16),
                              SizedBox(width: 4),
                              Text(
                                'End Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            _recurrenceEndDate != null
                                ? DateFormat('EEE, MMM dd, yyyy')
                                    .format(_recurrenceEndDate!)
                                : 'Select date',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _recurrenceEndDate != null
                                  ? Colors.black87
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Max occurrences (if not using end date)
              if (!_useEndDate)
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.orange[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.repeat,
                                color: Colors.orange[600], size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Max Lessons',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$_maxOccurrences lessons',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          _buildDateValidationInfo(),
        ],
      ),
    );
  }

// Date validation information widget
  Widget _buildDateValidationInfo() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(_selectedStartDate.year, _selectedStartDate.month,
        _selectedStartDate.day);

    List<Widget> infoItems = [];

    if (startDay.isAtSameMomentAs(today)) {
      infoItems.add(_buildInfoItem(
        icon: Icons.info,
        text: 'Starting today',
        color: Colors.blue,
      ));
    } else if (startDay.isAfter(today)) {
      final daysUntilStart = startDay.difference(today).inDays;
      infoItems.add(_buildInfoItem(
        icon: Icons.schedule,
        text:
            'Starting in $daysUntilStart day${daysUntilStart == 1 ? '' : 's'}',
        color: Colors.green,
      ));
    }

    if (_useEndDate && _recurrenceEndDate != null) {
      final totalDays =
          _recurrenceEndDate!.difference(_selectedStartDate).inDays;
      infoItems.add(_buildInfoItem(
        icon: Icons.timeline,
        text: 'Duration: $totalDays days',
        color: Colors.orange,
      ));
    }

    if (infoItems.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: infoItems
            .map((item) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: item,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildInfoItem(
      {required IconData icon, required String text, required Color color}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

// Enhanced validation for recurring schedule creation
  bool _canCreateRecurringSchedule() {
    if (_selectedStudent == null ||
        _selectedCourse == null ||
        _selectedInstructor == null ||
        _startTime == null ||
        _endTime == null) {
      return false;
    }

    // Check if start date is not in the past
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(_selectedStartDate.year, _selectedStartDate.month,
        _selectedStartDate.day);

    if (startDay.isBefore(today)) {
      return false;
    }

    // Check if we have preview count and remaining lessons
    if (_previewCount <= 0 || _remainingLessons <= 0) {
      return false;
    }

    // Check if preview count doesn't exceed remaining lessons
    if (_previewCount > _remainingLessons) {
      return false;
    }

    return true;
  }

  TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
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

      // NEW: Working hours validation
      final settingsController = Get.find<SettingsController>();
      if (settingsController.enforceWorkingHours.value &&
          _selectedInstructor != null) {
        final startTime =
            TimeOfDay(hour: _startTime!.hour, minute: _startTime!.minute);
        final endTime =
            TimeOfDay(hour: _endTime!.hour, minute: _endTime!.minute);

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
                _selectedDate!.year, _selectedDate!.month, _selectedDate!.day);

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
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          message,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
