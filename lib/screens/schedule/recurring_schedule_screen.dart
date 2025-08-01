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
                helperText: 'Max: $_remainingLessons',
              ),
              validator: (value) {
                final val = int.tryParse(value ?? '');
                if (val == null || val <= 0) {
                  return 'Enter valid number';
                }
                if (val > _remainingLessons && _remainingLessons > 0) {
                  return 'Exceeds remaining lessons';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _maxOccurrences = int.tryParse(value) ?? 10;
                  if (_maxOccurrences > _remainingLessons &&
                      _remainingLessons > 0) {
                    _maxOccurrences = _remainingLessons;
                  }
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

            // Lesson count preview
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
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
            ),

            SizedBox(height: 12),

            // Validation messages integrated here
            ..._buildPreviewValidationMessages(),

            // Success message when ready
            if (_previewCount > 0 &&
                _previewCount <= _remainingLessons &&
                _getValidationErrors().isEmpty) ...[
              SizedBox(height: 8),
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _getValidationErrors() {
    List<String> errors = [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedStartDate.year,
        _selectedStartDate.month, _selectedStartDate.day);

    if (selectedDay.isBefore(today)) {
      errors.add('Cannot schedule lessons for past dates');
    }

    // Check for past time on today's date
    if (selectedDay.isAtSameMomentAs(today)) {
      final startDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      if (startDateTime.isBefore(now)) {
        errors.add('Cannot schedule lessons for past times');
      }
    }

    final startDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _startTime.hour,
        _startTime.minute);
    final endDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _endTime.hour,
        _endTime.minute);
    final duration = endDateTime.difference(startDateTime);

    if (duration.inMinutes <= 0) {
      errors.add('End time must be after start time');
    }

    // Business settings validation
    final settingsController = Get.find<SettingsController>();

    // Check if scheduling on closed days
    if (_selectedInstructor != null) {
      final closedDays = _getClosedDaysFromSettings(settingsController);

      // Check if start date falls on a closed day
      if (closedDays.contains(_selectedStartDate.weekday)) {
        final dayName = _getDayName(_selectedStartDate.weekday);
        errors.add('Cannot schedule on $dayName - Business is closed');
      }

      // For recurring schedules, check if any selected days are closed
      if (_recurrencePattern == 'weekly' && _selectedDaysOfWeek.isNotEmpty) {
        final conflictingDays = _selectedDaysOfWeek
            .where((day) => closedDays.contains(day))
            .toList();
        if (conflictingDays.isNotEmpty) {
          final dayNames =
              conflictingDays.map((day) => _getDayName(day)).join(', ');
          errors.add(
              'Cannot schedule on $dayNames - Business is closed on these days');
        }
      }
    }

    // Business hours validation
    if (settingsController.enforceWorkingHours.value &&
        _selectedInstructor != null) {
      final startTime =
          TimeOfDay(hour: _startTime.hour, minute: _startTime.minute);
      final endTime = TimeOfDay(hour: _endTime.hour, minute: _endTime.minute);

      final workingStart =
          _parseTimeString(settingsController.workingHoursStart.value);
      final workingEnd =
          _parseTimeString(settingsController.workingHoursEnd.value);

      if (_isTimeOutsideBusinessHours(
          startTime, endTime, workingStart, workingEnd)) {
        errors.add(
            'Schedule time is outside business hours (${settingsController.workingHoursStart.value} - ${settingsController.workingHoursEnd.value})');
      }
    }

    // Check if end date would generate too many lessons
    if (_useEndDate && _recurrenceEndDate != null && _remainingLessons > 0) {
      int estimatedLessons =
          _calculateLessonsForPeriod(_selectedStartDate, _recurrenceEndDate!);

      if (estimatedLessons > _remainingLessons) {
        errors.add(
            'End date would generate $estimatedLessons lessons, but only $_remainingLessons lessons remain');
      }
    }

    // Check if number of lessons exceeds remaining when not using end date
    if (!_useEndDate &&
        _maxOccurrences > _remainingLessons &&
        _remainingLessons > 0) {
      errors.add(
          'Number of lessons ($_maxOccurrences) exceeds remaining lessons ($_remainingLessons)');
    }

    return errors;
  }

  List<String> _getValidationWarnings() {
    List<String> warnings = [];

    final startDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _startTime.hour,
        _startTime.minute);
    final endDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _endTime.hour,
        _endTime.minute);
    final duration = endDateTime.difference(startDateTime);

    if (duration.inMinutes > 0 && duration.inMinutes < 30) {
      warnings.add('Lesson duration is less than 30 minutes');
    } else if (duration.inHours > 4) {
      warnings.add('Lesson duration exceeds 4 hours');
    }

    // Working hours break validation
    final settingsController = Get.find<SettingsController>();
    if (settingsController.enforceWorkingHours.value &&
        _selectedInstructor != null &&
        !settingsController.allowBackToBackLessons.value) {
      final breakMinutes = settingsController.breakBetweenLessons.value;
      final conflictingSchedules =
          _scheduleController.schedules.where((schedule) {
        if (schedule.instructorId != _selectedInstructor!.id) return false;

        final scheduleDate = DateTime(
            schedule.start.year, schedule.start.month, schedule.start.day);
        final selectedScheduleDate = DateTime(_selectedStartDate.year,
            _selectedStartDate.month, _selectedStartDate.day);

        if (!scheduleDate.isAtSameMomentAs(selectedScheduleDate)) return false;

        final timeDifference = startDateTime.difference(schedule.end).inMinutes;
        return timeDifference > 0 && timeDifference < breakMinutes;
      }).toList();

      if (conflictingSchedules.isNotEmpty) {
        warnings.add(
            'Less than ${breakMinutes} minutes break from previous lesson');
      }
    }

    // Suggest optimal end date
    if (_remainingLessons > 0 && _selectedInstructor != null && _useEndDate) {
      DateTime optimalEndDate = _findOptimalEndDate();
      if (optimalEndDate.isBefore(
          _recurrenceEndDate ?? DateTime.now().add(Duration(days: 365)))) {
        warnings.add(
            'Recommended end date: ${DateFormat('MMM dd, yyyy').format(optimalEndDate)} (uses all $_remainingLessons lessons)');
      }
    }

    return warnings;
  }

// Helper method to get closed days from settings
  List<int> _getClosedDaysFromSettings(SettingsController settingsController) {
    List<int> closedDays = [];

    // For now, assume all days are open since the specific day properties don't exist
    // This method can be updated when the SettingsController has the required properties

    return closedDays;
  }

// Helper method to get day name from weekday number
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

// Updated method name for clarity
  bool _isTimeOutsideBusinessHours(TimeOfDay startTime, TimeOfDay endTime,
      TimeOfDay businessStart, TimeOfDay businessEnd) {
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;
    int businessStartMinutes = businessStart.hour * 60 + businessStart.minute;
    int businessEndMinutes = businessEnd.hour * 60 + businessEnd.minute;

    return startMinutes < businessStartMinutes ||
        endMinutes > businessEndMinutes;
  }

// Updated method to respect closed days when calculating lessons
  int _calculateLessonsForPeriod(DateTime startDate, DateTime endDate) {
    if (_selectedInstructor == null) return 0;

    final settingsController = Get.find<SettingsController>();
    final closedDays = _getClosedDaysFromSettings(settingsController);

    DateTime currentDate = startDate;
    int count = 0;

    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      // Skip if it's a closed day
      if (closedDays.contains(currentDate.weekday)) {
        currentDate = _getNextDate(currentDate);
        continue;
      }

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
          shouldCreateSchedule = currentDate.day == startDate.day;
          break;
        case 'custom':
          final daysDiff = currentDate.difference(startDate).inDays;
          shouldCreateSchedule = daysDiff % _customInterval == 0;
          break;
      }

      if (shouldCreateSchedule) {
        count++;
      }

      currentDate = _getNextDate(currentDate);

      if (count > 1000) break;
    }

    return count;
  }

// Helper method to get next date based on recurrence pattern
  DateTime _getNextDate(DateTime currentDate) {
    switch (_recurrencePattern) {
      case 'daily':
        return currentDate.add(Duration(days: 1));
      case 'weekly':
        return currentDate.add(Duration(days: 1));
      case 'monthly':
        return DateTime(
          currentDate.year,
          currentDate.month + 1,
          currentDate.day,
        );
      case 'custom':
        return currentDate.add(Duration(days: 1));
      default:
        return currentDate.add(Duration(days: 1));
    }
  }

// Updated _updatePreviewCount to respect closed days
  void _updatePreviewCount() {
    if (_selectedInstructor == null) {
      setState(() {
        _previewCount = 0;
      });
      return;
    }

    final settingsController = Get.find<SettingsController>();
    final closedDays = _getClosedDaysFromSettings(settingsController);

    final endDate = _useEndDate
        ? _recurrenceEndDate!
        : DateTime.now().add(Duration(days: 365));

    DateTime currentDate = _selectedStartDate;
    int count = 0;

    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      if (!_useEndDate && count >= _maxOccurrences) break;

      // Skip if it's a closed day
      if (closedDays.contains(currentDate.weekday)) {
        currentDate = currentDate.add(Duration(days: 1));
        continue;
      }

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

  List<Widget> _buildPreviewValidationMessages() {
    List<Widget> messages = [];
    final errors = _getValidationErrors();
    final warnings = _getValidationWarnings();

    // Show errors
    for (String error in errors) {
      messages.add(Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ));
    }

    // Show lesson count warning if exceeds remaining
    if (_previewCount > _remainingLessons && _remainingLessons > 0) {
      messages.add(Container(
        margin: EdgeInsets.only(bottom: 8),
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
                'Warning: You only have $_remainingLessons lessons remaining.',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ));
    }

    // Show warnings
    for (String warning in warnings) {
      messages.add(Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                warning,
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ));
    }

    return messages;
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _canCreateRecurringSchedule()
                ? _createRecurringSchedule
                : null, // Changed from _canSchedule()
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
              // Check if course is already in the list to avoid duplicates
              if (!courses.any((c) => c.id == course.id)) {
                courses.add(course);
              }
            }
          }
        }

        setState(() {
          _availableCourses = courses;
          // Only set selected course if it exists in the new list
          if (courses.isNotEmpty) {
            if (_selectedCourse == null ||
                !courses.any((c) => c.id == _selectedCourse!.id)) {
              _selectedCourse = courses.first;
            }
            _updateLessonCounts();
          } else {
            _selectedCourse = null;
            _remainingLessons = 0;
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
          _selectedCourse = null;
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
      setState(() {
        _remainingLessons = _scheduleController.getRemainingLessons(
            _selectedStudent!.id!, _selectedCourse!.id!);
      });
      _updatePreviewCount();
    }
  }

  int _getUsedLessons(int studentId, int courseId) {
    return _scheduleController.getUsedLessons(studentId, courseId);
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
          _startTime.hour,
          _startTime.minute,
        );

        final endDateTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          _endTime.hour,
          _endTime.minute,
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

    // Calculate a safe initial date that satisfies the predicate
    DateTime safeInitialDate =
        _recurrenceEndDate ?? _selectedStartDate.add(Duration(days: 30));

    // If the current end date would generate too many lessons, find a safe date
    if (_remainingLessons > 0 && _selectedInstructor != null) {
      int estimatedLessons =
          _calculateLessonsForPeriod(_selectedStartDate, safeInitialDate);

      if (estimatedLessons > _remainingLessons) {
        // Use the optimal end date as initial date
        safeInitialDate = _findOptimalEndDate();
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
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

        if (checkDate.isBefore(startDay)) {
          return false;
        }

        // Check if this date would generate too many lessons
        if (_remainingLessons > 0 && _selectedInstructor != null) {
          int estimatedLessons =
              _calculateLessonsForPeriod(_selectedStartDate, date);
          return estimatedLessons <= _remainingLessons;
        }

        return true;
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
      // Double check the lesson count after selection
      int estimatedLessons =
          _calculateLessonsForPeriod(_selectedStartDate, picked);

      if (estimatedLessons > _remainingLessons && _remainingLessons > 0) {
        Get.snackbar(
          'Too Many Lessons',
          'This end date would generate $estimatedLessons lessons, but only $_remainingLessons lessons remain. Please choose an earlier end date.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
        return;
      }

      setState(() {
        _recurrenceEndDate = picked;
      });
      _updatePreviewCount();
    }
  }

  bool _canCreateRecurringSchedule() {
    if (_selectedStudent == null ||
        _selectedCourse == null ||
        _selectedInstructor == null) {
      return false;
    }

    // Check if start date and time is not in the past
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(_selectedStartDate.year, _selectedStartDate.month,
        _selectedStartDate.day);

    if (startDay.isBefore(today)) {
      return false;
    }

    // NEW: Check if time is in the past for today's date
    if (startDay.isAtSameMomentAs(today)) {
      final startDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      if (startDateTime.isBefore(now)) {
        return false;
      }
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

  bool _isTimeOutsideWorkingHours(TimeOfDay startTime, TimeOfDay endTime,
      TimeOfDay workingStart, TimeOfDay workingEnd) {
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;
    int workingStartMinutes = workingStart.hour * 60 + workingStart.minute;
    int workingEndMinutes = workingEnd.hour * 60 + workingEnd.minute;

    return startMinutes < workingStartMinutes || endMinutes > workingEndMinutes;
  }

  DateTime _findOptimalEndDate() {
    if (_remainingLessons <= 0 || _selectedInstructor == null) {
      return _selectedStartDate.add(Duration(days: 30));
    }

    DateTime currentDate = _selectedStartDate;
    int count = 0;
    DateTime lastValidDate = _selectedStartDate;

    // Safety limit to prevent infinite loops
    int maxDays = 3650; // 10 years
    int dayCount = 0;

    while (count < _remainingLessons && dayCount < maxDays) {
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
        lastValidDate = currentDate;
      }

      if (count >= _remainingLessons) break;

      // Move to next day
      currentDate = currentDate.add(Duration(days: 1));
      dayCount++;
    }

    // If we couldn't find enough dates, return a reasonable default
    if (count == 0) {
      return _selectedStartDate.add(Duration(days: 30));
    }

    return lastValidDate;
  }
}
