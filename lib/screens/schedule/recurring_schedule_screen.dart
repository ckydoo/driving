// lib/screens/schedule/recurring_schedule_screen.dart
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/widgets/recuring_progress.dart';
import 'package:driving/widgets/responsive_text.dart';
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
  bool _hasConflicts = false;
  List<String> _conflictDetails = [];
  bool _instructorAvailable = true;
  bool _vehicleAvailable = true;
  bool _showAvailabilityStatus = false;

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
    // Initialize availability status
    _instructorAvailable = true;
    _vehicleAvailable = true;
    _showAvailabilityStatus = false;
    _conflictDetails = [];
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

  Future<void> _loadStudentCourses(User student) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get student's invoices to determine available courses
      final studentInvoices = _billingController.invoices
          .where((invoice) => invoice.studentId == student.id)
          .toList();

      print(
          'DEBUG: Found ${studentInvoices.length} invoices for student ${student.id}');

      if (studentInvoices.isEmpty) {
        // No billing found - show error and prevent scheduling
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
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
          // Use the centralized method
          final remaining = _scheduleController.getRemainingLessons(
              student.id!, invoice.courseId);

          print(
              'DEBUG: Course ${course.name} (ID: ${course.id}) has $remaining remaining lessons');

          // FIXED: Only include courses with remaining lessons OR if billing validation is disabled
          final settingsController = Get.find<SettingsController>();
          if (remaining > 0 ||
              !settingsController.enforceBillingValidation.value) {
            validCourses.add(course);
            uniqueCourseIds.add(course.id!);
          }
        }
      }

      if (validCourses.isEmpty) {
        // Student has invoices but no remaining lessons
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
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

      // Auto-select the first course with most remaining lessons
      validCourses.sort((a, b) {
        final aRemaining =
            _scheduleController.getRemainingLessons(student.id!, a.id!);
        final bRemaining =
            _scheduleController.getRemainingLessons(student.id!, b.id!);
        return bRemaining.compareTo(aRemaining); // Descending order
      });

      setState(() {
        _availableCourses = validCourses;
        _selectedCourse = validCourses.first;

        // Set remaining lessons for selected course using centralized method
        _remainingLessons = _scheduleController.getRemainingLessons(
            student.id!, _selectedCourse!.id!);
      });

      // Show success message with lesson count
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Student Selected',
        'Found ${validCourses.length} course(s) with remaining lessons',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      print('ERROR in _loadStudentCourses: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
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

// DEBUGGING METHOD: Add this to help troubleshoot
  void debugBillingAndSchedules(int studentId, int courseId) {
    final billingController = Get.find<BillingController>();
    final settingsController = Get.find<SettingsController>();

    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) => inv.studentId == studentId && inv.courseId == courseId,
    );

    final studentSchedules = _scheduleController.schedules
        .where((s) => s.studentId == studentId && s.courseId == courseId)
        .toList();

    print('=== BILLING DEBUG ===');
    print('Student ID: $studentId, Course ID: $courseId');
    print('Invoice found: ${invoice != null}');
    if (invoice != null) {
      print('Invoice lessons: ${invoice.lessons}');
    }
    print(
        'Total schedules for this student/course: ${studentSchedules.length}');
    print(
        'countScheduledLessons setting: ${settingsController.countScheduledLessons.value}');

    for (var schedule in studentSchedules) {
      print(
          'Schedule ID: ${schedule.id}, Status: ${schedule.status}, Attended: ${schedule.attended}, LessonsDeducted: ${schedule.lessonsDeducted}');
    }

    final usedLessons = _getUsedLessons(studentId, courseId);
    final remainingLessons =
        _scheduleController.getRemainingLessons(studentId, courseId);

    print('Used lessons: $usedLessons');
    print('Remaining lessons: $remainingLessons');
    print('=== END DEBUG ===');
  }

  Widget _buildResultRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
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
          snackPosition: SnackPosition.BOTTOM,
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

  bool _isTimeOutsideWorkingHours(TimeOfDay startTime, TimeOfDay endTime,
      TimeOfDay workingStart, TimeOfDay workingEnd) {
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;
    int workingStartMinutes = workingStart.hour * 60 + workingStart.minute;
    int workingEndMinutes = workingEnd.hour * 60 + workingEnd.minute;

    return startMinutes < workingStartMinutes || endMinutes > workingEndMinutes;
  }

// Calculate maximum occurrences possible based on remaining lessons
  int _getMaxPossibleOccurrences() {
    final lessonsPerOccurrence = _getLessonsPerOccurrence();
    if (lessonsPerOccurrence <= 0 || _remainingLessons <= 0) return 0;
    return (_remainingLessons / lessonsPerOccurrence).floor();
  }

// Helper to build lesson info rows
  Widget _buildLessonInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.green.shade600,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.green.shade800,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

// SIMPLIFIED: Clear preview with plain English
  Widget _buildPreviewSection() {
    final lessonsPerSession = _getLessonsPerOccurrence();
    final totalLessonsToUse = _previewCount * lessonsPerSession;
    final remainingAfter = _remainingLessons - totalLessonsToUse;

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

            // SIMPLIFIED: Show in plain English
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Schedule:',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildPreviewRow(
                    icon: Icons.calendar_today,
                    label: 'Sessions to create:',
                    value: '$_previewCount',
                    color: Colors.blue,
                  ),
                  _buildPreviewRow(
                    icon: Icons.access_time,
                    label: 'Each session:',
                    value: _formatDuration(
                        Duration(minutes: lessonsPerSession * 30)),
                    color: Colors.green,
                  ),
                  _buildPreviewRow(
                    icon: Icons.school,
                    label: 'Total lessons to use:',
                    value: '$totalLessonsToUse of $_remainingLessons',
                    color: Colors.orange,
                  ),
                  _buildPreviewRow(
                    icon: Icons.bookmark,
                    label: 'Lessons remaining after:',
                    value: '$remainingAfter',
                    color: remainingAfter >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            // Validation messages
            ..._buildSimpleValidationMessages(),

            // Success message
            if (_previewCount > 0 &&
                totalLessonsToUse <= _remainingLessons &&
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
                        'Perfect! Ready to create your schedule.',
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

  Widget _buildPreviewRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

// SIMPLIFIED: Clear validation messages
  List<Widget> _buildSimpleValidationMessages() {
    List<Widget> messages = [];
    final errors = _getValidationErrors();
    final totalLessonsToUse = _previewCount * _getLessonsPerOccurrence();

    // Show lesson count error in simple terms
    if (totalLessonsToUse > _remainingLessons && _remainingLessons > 0) {
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
                'Not enough lessons! You need $totalLessonsToUse lessons but only have $_remainingLessons remaining.',
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

    // Show other errors in simple language
    for (String error in errors) {
      if (!error.contains('lessons')) {
        // Skip the complex lesson error, we handle it above
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
                  error,
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
    }

    return messages;
  }

// Helper method to format duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  // ADD THESE METHODS TO YOUR EXISTING RecurringScheduleScreen class

// REPLACE your existing _buildPreviewValidationMessages method with this:
  List<Widget> _buildPreviewValidationMessages() {
    List<Widget> messages = [];
    final errors = _getValidationErrors();
    final warnings = _getValidationWarnings();
    final totalLessonsToUse = _previewCount * _getLessonsPerOccurrence();

    // Show errors with clear styling
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

    // Show warnings with clear styling
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
            Icon(Icons.warning, color: Colors.orange, size: 20),
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

    // Show success message when everything is valid
    if (errors.isEmpty &&
        warnings.isEmpty &&
        _previewCount > 0 &&
        _selectedInstructor != null &&
        _selectedCourse != null &&
        totalLessonsToUse <= _remainingLessons) {
      messages.add(Container(
        margin: EdgeInsets.only(bottom: 8),
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
                'Perfect! Ready to create your $_previewCount recurring schedules.',
                style: TextStyle(
                  color: Colors.green.shade700,
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

// ADD this method for time overlap checking
  bool _hasTimeOverlap(
      TimeOfDay start1, TimeOfDay end1, TimeOfDay start2, TimeOfDay end2) {
    final start1Minutes = start1.hour * 60 + start1.minute;
    final end1Minutes = end1.hour * 60 + end1.minute;
    final start2Minutes = start2.hour * 60 + start2.minute;
    final end2Minutes = end2.hour * 60 + end2.minute;

    return !(end1Minutes <= start2Minutes || start1Minutes >= end2Minutes);
  }

// UPDATE your existing _getValidationWarnings method with enhanced break validation:
  List<String> _getValidationWarnings() {
    List<String> warnings = [];
    final settingsController = Get.find<SettingsController>();

    if (_selectedInstructor == null || _selectedCourse == null) {
      return warnings;
    }

    final startDateTime = DateTime(
      _selectedStartDate.year,
      _selectedStartDate.month,
      _selectedStartDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _selectedStartDate.year,
      _selectedStartDate.month,
      _selectedStartDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    final duration = endDateTime.difference(startDateTime);

    // Duration warnings
    if (duration.inMinutes > 0 && duration.inMinutes < 30) {
      warnings.add('Lesson duration is less than 30 minutes');
    } else if (duration.inHours > 4) {
      warnings.add('Lesson duration exceeds 4 hours');
    }

    // FIXED: Break between lessons validation
    if (settingsController.enforceWorkingHours.value &&
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

        // Check if there's a schedule that ends within break time of our start time
        final timeDifference = startDateTime.difference(schedule.end).inMinutes;
        return timeDifference > 0 && timeDifference < breakMinutes;
      }).toList();

      if (conflictingSchedules.isNotEmpty) {
        warnings.add(
            'Less than ${breakMinutes} minutes break from previous lesson');
      }
    }

    // Optimal end date suggestion
    if (_remainingLessons > 0 && _selectedInstructor != null && _useEndDate) {
      DateTime optimalEndDate = _findOptimalEndDate();
      if (optimalEndDate.isBefore(
          _recurrenceEndDate ?? DateTime.now().add(Duration(days: 365)))) {
        warnings.add(
            'Consider ending on ${DateFormat('MMM dd, yyyy').format(optimalEndDate)} to use all available lessons');
      }
    }

    return warnings;
  }

// REPLACE your existing _showRecurringResultsDialog method with this enhanced version:
  void _showRecurringResultsDialog(int savedCount, int failedCount,
      int totalGenerated, List<String> errors) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Icon(
                savedCount > 0 ? Icons.check_circle : Icons.error,
                size: 60,
                color: savedCount > 0 ? Colors.green : Colors.red,
              ),

              SizedBox(height: 16),

              // Title
              Text(
                savedCount > 0
                    ? 'Recurring Schedule Created!'
                    : 'Creation Failed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: savedCount > 0 ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12),

              // Summary
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Successfully created:' as String,
                        savedCount as int, Colors.green as Color),
                    if (failedCount > 0)
                      _buildSummaryRow('Failed to create:' as String,
                          failedCount as int, Colors.red as Color),
                    _buildSummaryRow('Total attempted:' as String,
                        totalGenerated as int, Colors.blue as Color),
                    SizedBox(height: 8),
                    Divider(),
                    SizedBox(height: 8),
                    _buildSummaryRow(
                        'Lessons used:' as String,
                        (savedCount * _getLessonsPerOccurrence()) as int,
                        Colors.orange as Color),
                    _buildSummaryRow(
                        'Lessons remaining:' as String,
                        (_remainingLessons -
                            (savedCount * _getLessonsPerOccurrence())) as int,
                        Colors.purple as Color),
                  ],
                ),
              ),

              // Show errors if any
              if (errors.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Errors:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      SizedBox(height: 8),
                      ...errors.take(3).map((error) => Text(
                            '• $error',
                            style: TextStyle(
                                fontSize: 12, color: Colors.red.shade700),
                          )),
                      if (errors.length > 3)
                        Text(
                          '... and ${errors.length - 3} more',
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade700),
                        ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 24),

              // FIXED: Action buttons with proper navigation
              Row(
                children: [
                  if (savedCount > 0) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Get.back(); // Close dialog
                          Get.back(); // Go back to previous screen
                          // Navigate to schedule screen to see created schedules
                          Get.offNamed('/schedule');
                        },
                        icon: Icon(Icons.calendar_view_day),
                        label: Text('View Schedules'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back(); // Close dialog
                        // FIXED: Always go back to schedule screen on success
                        if (savedCount > 0) {
                          Get.back(); // Close recurring schedule screen
                          // Refresh the schedule screen
                          Get.find<ScheduleController>().fetchSchedules();
                        }
                      },
                      icon: Icon(Icons.check),
                      label: Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            savedCount > 0 ? Colors.green : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Widget _buildSummaryRow(String label, int count, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14)),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
// REPLACE these methods in your RecurringScheduleScreen class

// FIXED: Calculate the perfect end date for user's remaining lessons
  DateTime _calculateOptimalEndDate() {
    if (_remainingLessons <= 0) {
      return DateTime.now().add(Duration(days: 30));
    }

    final lessonsPerOccurrence = _getLessonsPerOccurrence();
    final neededOccurrences =
        (_remainingLessons / lessonsPerOccurrence).floor();

    print('🔄 OPTIMAL DATE CALCULATION:');
    print('   Remaining lessons: $_remainingLessons');
    print('   Lessons per occurrence: $lessonsPerOccurrence');
    print('   Needed occurrences: $neededOccurrences');

    DateTime currentDate = _selectedStartDate;
    int occurrenceCount = 0;
    int safety = 0;

    while (occurrenceCount < neededOccurrences && safety < 1000) {
      safety++;

      bool shouldCount = false;
      switch (_recurrencePattern) {
        case 'daily':
          shouldCount = true;
          break;
        case 'weekly':
          shouldCount = _selectedDaysOfWeek.contains(currentDate.weekday);
          break;
        case 'monthly':
          shouldCount = currentDate.day == _selectedStartDate.day;
          break;
        case 'custom':
          final daysDiff = currentDate.difference(_selectedStartDate).inDays;
          shouldCount = daysDiff % _customInterval == 0;
          break;
      }

      if (shouldCount) {
        occurrenceCount++;
        print(
            '   Found occurrence $occurrenceCount on ${currentDate.toString().substring(0, 10)}');
      }

      if (occurrenceCount >= neededOccurrences) {
        print(
            '   Optimal end date: ${currentDate.toString().substring(0, 10)}');
        return currentDate;
      }

      currentDate = currentDate.add(Duration(days: 1));
    }

    print(
        '   Safety exit reached, returning: ${currentDate.toString().substring(0, 10)}');
    return currentDate;
  }

// FIXED: Find optimal end date (this was also incorrect)
  DateTime _findOptimalEndDate() {
    if (_remainingLessons <= 0 || _selectedInstructor == null) {
      return _selectedStartDate.add(Duration(days: 30));
    }

    final lessonsPerOccurrence = _getLessonsPerOccurrence();
    final neededOccurrences =
        (_remainingLessons / lessonsPerOccurrence).floor();

    print('🔄 FIND OPTIMAL DATE:');
    print('   Remaining lessons: $_remainingLessons');
    print('   Lessons per occurrence: $lessonsPerOccurrence');
    print('   Needed occurrences: $neededOccurrences');

    DateTime currentDate = _selectedStartDate;
    int occurrenceCount = 0;
    DateTime lastValidDate = _selectedStartDate;

    // Safety limit to prevent infinite loops
    int maxDays = 3650; // 10 years
    int dayCount = 0;

    while (occurrenceCount < neededOccurrences && dayCount < maxDays) {
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
        occurrenceCount++;
        lastValidDate = currentDate;
        print(
            '   Found occurrence $occurrenceCount on ${currentDate.toString().substring(0, 10)}');
      }

      if (occurrenceCount >= neededOccurrences) break;

      // Move to next day
      currentDate = currentDate.add(Duration(days: 1));
      dayCount++;
    }

    // If we couldn't find enough dates, return a reasonable default
    if (occurrenceCount == 0) {
      return _selectedStartDate.add(Duration(days: 30));
    }

    print(
        '   Final optimal date: ${lastValidDate.toString().substring(0, 10)} with $occurrenceCount occurrences');
    return lastValidDate;
  }

// FIXED: Update preview count with better logging
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

    print('🔄 UPDATE PREVIEW COUNT:');
    print('   Start date: ${_selectedStartDate.toString().substring(0, 10)}');
    print('   End date: ${endDate.toString().substring(0, 10)}');
    print('   Pattern: $_recurrencePattern');
    print('   Selected days: $_selectedDaysOfWeek');
    print('   Use end date: $_useEndDate');
    print('   Max occurrences: $_maxOccurrences');

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
        print(
            '   Found schedule ${count} on ${currentDate.toString().substring(0, 10)} (${_getDayName(currentDate.weekday)})');
      }

      // Move to next iteration based on pattern
      currentDate = currentDate.add(Duration(days: 1));

      // Safety check
      if (count > 1000) break;
    }

    print('   Final preview count: $count');
    setState(() {
      _previewCount = count;
    });
    _triggerConflictCheck();
  }

// FIXED: Smart end date selection with guidance
  Widget _buildEndConditionSection() {
    final lessonsPerSession = _getLessonsPerOccurrence();
    final maxSessions = _remainingLessons > 0
        ? (_remainingLessons / lessonsPerSession).floor()
        : 0;
    final optimalEndDate = _calculateOptimalEndDate();

    print('🔄 END CONDITION SECTION:');
    print('   Lessons per session: $lessonsPerSession');
    print('   Remaining lessons: $_remainingLessons');
    print('   Max sessions: $maxSessions');
    print('   Optimal end date: ${optimalEndDate.toString().substring(0, 10)}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How long to schedule?',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        SizedBox(height: 12),

        // RECOMMENDED option (make it prominent)
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: RadioListTile<bool>(
            value: true,
            groupValue: _useEndDate,
            onChanged: (value) {
              setState(() {
                _useEndDate = value!;
                _recurrenceEndDate = optimalEndDate; // Set to optimal
                _updatePreviewCount();
              });
            },
            title: Row(
              children: [
                Icon(Icons.recommend, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use all remaining lessons (Recommended)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Will schedule up to $maxSessions sessions until ${DateFormat('MMM dd, yyyy').format(optimalEndDate)}',
              style: TextStyle(color: Colors.blue.shade600),
            ),
          ),
        ),

        if (_useEndDate) ...[
          SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.only(left: 32),
            leading: Icon(Icons.event_available, color: Colors.blue),
            title: Text('End Date'),
            subtitle: Text(
                DateFormat('EEEE, MMMM dd, yyyy').format(_recurrenceEndDate!)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recurrenceEndDate = optimalEndDate;
                      _updatePreviewCount();
                    });
                  },
                  child: Text('Use Optimal'),
                ),
                IconButton(
                  onPressed: () => _selectEndDate(),
                  icon: Icon(Icons.edit),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: 8),

        // Custom option (less prominent)
        RadioListTile<bool>(
          value: false,
          groupValue: _useEndDate,
          onChanged: (value) {
            setState(() {
              _useEndDate = value!;
              _maxOccurrences =
                  maxSessions.clamp(1, maxSessions > 0 ? maxSessions : 1);
              _updatePreviewCount();
            });
          },
          title: Text('Custom number of sessions'),
          subtitle: Text('Manually choose how many sessions to schedule'),
        ),

        if (!_useEndDate) ...[
          Container(
            margin: EdgeInsets.only(left: 32, top: 8),
            width: 150,
            child: TextFormField(
              initialValue: _maxOccurrences.toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Sessions',
                border: OutlineInputBorder(),
                helperText: 'Max: $maxSessions',
                suffixText: 'of $maxSessions',
              ),
              validator: (value) {
                final val = int.tryParse(value ?? '');
                if (val == null || val <= 0) {
                  return 'Enter valid number';
                }
                if (val > maxSessions && maxSessions > 0) {
                  return 'Max $maxSessions sessions';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _maxOccurrences = int.tryParse(value) ?? 1;
                  if (_maxOccurrences > maxSessions && maxSessions > 0) {
                    _maxOccurrences = maxSessions;
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

// FIXED: Course selection to properly trigger updates
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
                  'Course & Lessons',
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
                  _updatePreviewCount(); // Add this to trigger validation
                }
              },
            ),
            if (_remainingLessons > 0) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Lesson Summary',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildLessonInfoRow(
                        'Available lessons:', '$_remainingLessons'),
                    if (_startTime != null && _endTime != null) ...[
                      SizedBox(height: 8),
                      _buildLessonInfoRow(
                          'Each session duration:',
                          _formatDuration(Duration(
                              minutes: _endTime.hour * 60 +
                                  _endTime.minute -
                                  (_startTime.hour * 60 + _startTime.minute)))),
                      SizedBox(height: 8),
                      _buildLessonInfoRow('Lessons per session:',
                          '${_getLessonsPerOccurrence()}'),
                      SizedBox(height: 8),
                      _buildLessonInfoRow('Max sessions possible:',
                          '${(_remainingLessons / _getLessonsPerOccurrence()).floor()}'),
                    ],
                  ],
                ),
              ),
            ],
            if (_selectedStudent != null && _availableCourses.isEmpty) ...[
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

// ALSO ADD this debug method to help troubleshoot
  void _debugCurrentState() {
    print('🔍 CURRENT STATE DEBUG:');
    print(
        '   _selectedStudent: ${_selectedStudent?.fname} ${_selectedStudent?.lname} (ID: ${_selectedStudent?.id})');
    print(
        '   _selectedCourse: ${_selectedCourse?.name} (ID: ${_selectedCourse?.id})');
    print(
        '   _selectedInstructor: ${_selectedInstructor?.fname} ${_selectedInstructor?.lname} (ID: ${_selectedInstructor?.id})');
    print(
        '   _selectedVehicle: ${_selectedVehicle?.make} ${_selectedVehicle?.model} (ID: ${_selectedVehicle?.id})');
    print('   _remainingLessons: $_remainingLessons');
    print('   _selectedStartDate: ${_selectedStartDate.toString()}');
    print('   _startTime: ${_startTime.toString()}');
    print('   _endTime: ${_endTime.toString()}');
    print('   _recurrencePattern: $_recurrencePattern');
    print('   _selectedDaysOfWeek: $_selectedDaysOfWeek');
    print('   _customInterval: $_customInterval');
    print('   _useEndDate: $_useEndDate');
    print('   _recurrenceEndDate: ${_recurrenceEndDate?.toString()}');
    print('   _maxOccurrences: $_maxOccurrences');
    print('   _previewCount: $_previewCount');
    print('   _getLessonsPerOccurrence(): ${_getLessonsPerOccurrence()}');
    print('   _getTotalLessonsToDeduct(): ${_getTotalLessonsToDeduct()}');

    final errors = _getValidationErrors();
    print('   Validation errors: $errors');

    final warnings = _getValidationWarnings();
    print('   Validation warnings: $warnings');
  }

// HELPER METHOD: Validate lesson duration and show helpful messages
  void _validateLessonDuration() {
    final startInMinutes = _startTime.hour * 60 + _startTime.minute;
    final endInMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationMinutes = endInMinutes - startInMinutes;

    if (durationMinutes <= 0) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Invalid Duration',
        'End time must be after start time',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } else if (durationMinutes < 30) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Short Duration',
        'Lesson is ${durationMinutes} minutes. Minimum recommended: 30 minutes',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } else if (durationMinutes % 30 != 0) {
      final lessons = (durationMinutes / 30.0).toStringAsFixed(1);
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Duration Info',
        'Lesson duration: ${durationMinutes} minutes (${lessons} lessons)',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    } else {
      final lessons = (durationMinutes / 30).round();
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Duration Set',
        'Lesson duration: ${durationMinutes} minutes (${lessons} lesson${lessons > 1 ? 's' : ''})',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

// FIX 2: Proper lesson duration calculation (30 minutes = 1 lesson)
  int _getLessonsPerOccurrence() {
    final startDateTime = DateTime(
      _selectedStartDate.year,
      _selectedStartDate.month,
      _selectedStartDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _selectedStartDate.year,
      _selectedStartDate.month,
      _selectedStartDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final duration = endDateTime.difference(startDateTime);
    final minutes = duration.inMinutes;

    // FIXED: Each lesson is exactly 30 minutes
    // Use proper division and rounding for accurate lesson count
    if (minutes <= 0) return 1; // Minimum 1 lesson

    final lessons = (minutes / 30.0).round(); // Round to nearest lesson
    return lessons.clamp(1, 8); // Min 1 lesson, max 8 lessons (4 hours)
  }

// FIX 3: Add missing helper method
  int _getTotalLessonsToDeduct() {
    return _previewCount * _getLessonsPerOccurrence();
  }

// FIX 4: Enhanced instructor availability checking for recurring schedules
  Future<void> _checkInstructorAvailabilityForRecurring() async {
    if (_selectedInstructor == null) {
      setState(() {
        _hasConflicts = false;
      });
      return;
    }

    final settingsController = Get.find<SettingsController>();
    List<String> conflicts = [];

    // Generate preview dates to check conflicts
    List<DateTime> previewDates = _generatePreviewDates();

    for (DateTime date in previewDates) {
      final startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Check for instructor conflicts on this date
      final conflictingSchedules =
          _scheduleController.schedules.where((schedule) {
        // Check if it's the same instructor
        if (schedule.instructorId != _selectedInstructor!.id) return false;

        // Check if cancelled schedules should be ignored
        if (schedule.status.toLowerCase() == 'cancelled') return false;

        // Check for time overlap
        return (startDateTime.isBefore(schedule.end) &&
            endDateTime.isAfter(schedule.start));
      }).toList();

      if (conflictingSchedules.isNotEmpty) {
        final dateStr = DateFormat('MMM dd').format(date);
        final timeStr =
            DateFormat('hh:mm a').format(conflictingSchedules.first.start);
        conflicts.add('$dateStr at $timeStr');
      }

      // Check break between lessons if enforced
      if (settingsController.enforceWorkingHours.value &&
          !settingsController.allowBackToBackLessons.value) {
        final breakMinutes = settingsController.breakBetweenLessons.value;

        final tooCloseSchedules =
            _scheduleController.schedules.where((schedule) {
          if (schedule.instructorId != _selectedInstructor!.id) return false;
          if (schedule.status.toLowerCase() == 'cancelled') return false;

          final scheduleDate = DateTime(
              schedule.start.year, schedule.start.month, schedule.start.day);
          final selectedDate = DateTime(date.year, date.month, date.day);

          if (!scheduleDate.isAtSameMomentAs(selectedDate)) return false;

          // Check if there's insufficient break time
          final timeDifference =
              startDateTime.difference(schedule.end).inMinutes.abs();
          return timeDifference > 0 && timeDifference < breakMinutes;
        }).toList();

        if (tooCloseSchedules.isNotEmpty) {
          final dateStr = DateFormat('MMM dd').format(date);
          conflicts.add('$dateStr - insufficient break time');
        }
      }
    }

    setState(() {
      _hasConflicts = conflicts.isNotEmpty;
      _conflictDetails = conflicts;
    });

    if (conflicts.isNotEmpty && conflicts.length <= 3) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Instructor Conflicts',
        'Conflicts on: ${conflicts.take(3).join(', ')}${conflicts.length > 3 ? '...' : ''}',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    }
  }

// FIX 6: Proper day calculation excluding closed days
  int _calculateLessonsForPeriod(DateTime startDate, DateTime endDate) {
    if (endDate.isBefore(startDate)) return 0;

    final settingsController = Get.find<SettingsController>();
    final closedDays = _getClosedDaysFromSettings(settingsController);

    int count = 0;
    DateTime currentDate =
        DateTime(startDate.year, startDate.month, startDate.day);
    final finalDate = DateTime(endDate.year, endDate.month, endDate.day);

    // Prevent infinite loops - limit to 1000 days maximum
    int dayCount = 0;
    const maxDays = 1000;

    while (!currentDate.isAfter(finalDate) && dayCount < maxDays) {
      bool shouldInclude = false;

      switch (_recurrencePattern) {
        case 'daily':
          // Skip closed days for daily recurring
          shouldInclude = !closedDays.contains(currentDate.weekday);
          break;
        case 'weekly':
          // Only include if it matches selected days and isn't a closed day
          shouldInclude = _selectedDaysOfWeek.contains(currentDate.weekday) &&
              !closedDays.contains(currentDate.weekday);
          break;
        case 'custom':
          // For custom patterns, check interval
          final daysDiff = currentDate.difference(startDate).inDays;
          shouldInclude = (daysDiff % _customInterval == 0) &&
              !closedDays.contains(currentDate.weekday);
          break;
        case 'monthly':
          // For monthly, check if it's the same day of month and not closed
          shouldInclude = (currentDate.day == startDate.day) &&
              !closedDays.contains(currentDate.weekday);
          break;
      }

      if (shouldInclude) {
        count++;
      }

      currentDate = currentDate.add(Duration(days: 1));
      dayCount++;
    }

    return count;
  }

// FIX 7: Generate proper preview dates for validation
  List<DateTime> _generatePreviewDates() {
    List<DateTime> dates = [];
    final settingsController = Get.find<SettingsController>();
    final closedDays = _getClosedDaysFromSettings(settingsController);

    DateTime currentDate = DateTime(_selectedStartDate.year,
        _selectedStartDate.month, _selectedStartDate.day);
    int count = 0;
    int dayCount = 0;
    const maxDays = 365; // Limit to 1 year for preview

    while (count < _previewCount && dayCount < maxDays) {
      bool shouldInclude = false;

      // Skip past dates
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      if (currentDate.isBefore(todayDate)) {
        currentDate = currentDate.add(Duration(days: 1));
        dayCount++;
        continue;
      }

      switch (_recurrencePattern) {
        case 'daily':
          shouldInclude = !closedDays.contains(currentDate.weekday);
          break;
        case 'weekly':
          shouldInclude = _selectedDaysOfWeek.contains(currentDate.weekday) &&
              !closedDays.contains(currentDate.weekday);
          break;
        case 'custom':
          final daysDiff = currentDate.difference(_selectedStartDate).inDays;
          shouldInclude = (daysDiff % _customInterval == 0) &&
              !closedDays.contains(currentDate.weekday);
          break;
        case 'monthly':
          shouldInclude = (currentDate.day == _selectedStartDate.day) &&
              !closedDays.contains(currentDate.weekday);
          break;
      }

      if (shouldInclude) {
        dates.add(currentDate);
        count++;
      }

      currentDate = currentDate.add(Duration(days: 1));
      dayCount++;
    }

    return dates;
  }

// FIX 8: Enhanced _canSchedule method that checks all conditions
  bool _canSchedule() {
    // Check basic requirements
    if (_selectedStudent == null ||
        _selectedInstructor == null ||
        _selectedCourse == null ||
        _remainingLessons <= 0) {
      return false;
    }

    // Check if vehicle is required and available for practical lessons
    if (_selectedClassType == 'Practical') {
      if (_selectedVehicle == null) return false;

      // Ensure the vehicle is actually assigned to the selected instructor
      if (_selectedVehicle!.instructor != _selectedInstructor!.id) {
        return false;
      }
    }

    // Check validation errors
    final errors = _getValidationErrors();
    if (errors.isNotEmpty) return false;

    // Check if we have enough lessons
    final totalLessonsNeeded = _getTotalLessonsToDeduct();
    if (totalLessonsNeeded > _remainingLessons) return false;

    // Check preview count
    if (_previewCount <= 0) return false;

    // Optional: Allow scheduling with conflicts but warn user
    // You can choose to return false here to prevent scheduling with conflicts
    // return !_hasConflicts;

    return true; // Allow scheduling even with conflicts (user will be warned)
  }

// FIX 9: Call availability check when instructor or time changes
  void _onInstructorChanged() {
    if (mounted) {
      // _updateVehicleAvailability();
      _checkInstructorAvailabilityForRecurring(); // Add this line
      _updatePreview();
    }
  }

  void _onTimeChanged() {
    if (mounted) {
      _updateLessonCounts();
      _checkInstructorAvailabilityForRecurring(); // Add this line
      _updatePreview();
    }
  }

// FIX 10: Add the missing parseTimeString method with error handling
  TimeOfDay _parseTimeString(String timeString) {
    try {
      if (timeString.isEmpty || !timeString.contains(':')) {
        return const TimeOfDay(hour: 9, minute: 0);
      }

      final parts = timeString.trim().split(':');
      if (parts.length != 2) {
        return const TimeOfDay(hour: 9, minute: 0);
      }

      final hour = int.tryParse(parts[0].trim()) ?? 9;
      final minute = int.tryParse(parts[1].trim()) ?? 0;

      // Validate ranges
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return const TimeOfDay(hour: 9, minute: 0);
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

// FIX 11: Add missing helper methods
  void _updatePreview() {
    _updatePreviewCount();
    // Force UI refresh
    if (mounted) {
      setState(() {});
    }
  }

// FIX 12: Simplified closed days method (since business days aren't fully implemented yet)
  List<int> _getClosedDaysFromSettings(SettingsController settingsController) {
    // For now, return empty list - no closed days
    // This can be expanded later when business operating days are fully implemented
    List<int> closedDays = [];

    // FUTURE: When business days are implemented, you can add:
    // if (settingsController.operatingDays.isNotEmpty) {
    //   for (int day = 1; day <= 7; day++) {
    //     final dayName = _getDayName(day);
    //     if (!settingsController.operatingDays.contains(dayName)) {
    //       closedDays.add(day);
    //     }
    //   }
    // }

    return closedDays;
  }

// FIX 13: Add helper method for day names
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

// FIX 14: Add helper method for business hours validation
  bool _isTimeOutsideBusinessHours(TimeOfDay startTime, TimeOfDay endTime,
      TimeOfDay businessStart, TimeOfDay businessEnd) {
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;
    int businessStartMinutes = businessStart.hour * 60 + businessStart.minute;
    int businessEndMinutes = businessEnd.hour * 60 + businessEnd.minute;

    return startMinutes < businessStartMinutes ||
        endMinutes > businessEndMinutes;
  }

// FIX 15: Update your time picker handlers to call availability check
  void _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
      _onTimeChanged(); // This will now check availability
    }
  }

  void _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
      _onTimeChanged(); // This will now check availability
    }
  }

// FIX 16: Update instructor selection to call availability check
  void _onStudentChanged(User? student) {
    setState(() {
      _selectedStudent = student;
    });
  }

  void _onInstructorSelectionChanged(User? instructor) {
    setState(() {
      _selectedInstructor = instructor;
    });
    _onInstructorChanged(); // This will call availability check
  }

// STEP 1: Replace your existing instructor dropdown in _buildInstructorSection()
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
              validator: (value) {
                if (value == null) return 'Please select an instructor';

                // Show availability status in validation
                if (_showAvailabilityStatus && !_instructorAvailable) {
                  return 'Instructor has scheduling conflicts';
                }

                return null;
              },
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
                });
                if (value != null) {
                  _assignInstructorVehicle(value);
                  _updatePreviewCount();
                  // NEW: Check for conflicts when instructor changes
                  _checkInstructorAndVehicleAvailability();
                }
              },
            ),

            // NEW: Add availability status display right after instructor selection
            _buildAvailabilityStatus(),

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
                  // NEW: Check for vehicle conflicts when vehicle changes
                  if (_selectedClassType == 'Practical') {
                    _checkInstructorAndVehicleAvailability();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

// STEP 2: Update your time selection methods to trigger conflict checking
  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
          // Auto-set end time to 1 hour later
          _endTime = TimeOfDay(
            hour: (picked.hour + 1) % 24,
            minute: picked.minute,
          );
        } else {
          _endTime = picked;
        }

        // AUTO-UPDATE optimal end date when time changes
        if (_remainingLessons > 0) {
          _recurrenceEndDate = _calculateOptimalEndDate();
        }
      });
      _updatePreviewCount();

      // NEW: Check for conflicts when time changes
      if (_selectedInstructor != null) {
        _checkInstructorAndVehicleAvailability();
      }
    }
  }

// STEP 3: Update your start date selection to trigger conflict checking
  Future<void> _selectStartDate() async {
    final scheduleController = Get.find<ScheduleController>();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: scheduleController.getMinimumScheduleDate(),
      lastDate: scheduleController.getMaximumScheduleDate(),
      helpText: 'Select Start Date',
      cancelText: 'Cancel',
      confirmText: 'Select',
      errorFormatText: 'Enter valid date',
      errorInvalidText: 'Enter date in valid range',
      fieldLabelText: 'Start Date',
      fieldHintText: 'mm/dd/yyyy',
      selectableDayPredicate: (DateTime date) {
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

      // NEW: Check for conflicts when date changes
      if (_selectedInstructor != null) {
        _checkInstructorAndVehicleAvailability();
      }
    }
  }

// STEP 4: Update your recurrence pattern selection to trigger conflict checking
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

        // NEW: Check for conflicts when pattern changes
        if (_selectedInstructor != null) {
          _checkInstructorAndVehicleAvailability();
        }
      },
      selectedColor: Colors.green.withOpacity(0.2),
      checkmarkColor: Colors.green,
    );
  }

// STEP 5: Update your weekly options to trigger conflict checking
  Widget _buildWeeklyOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Days:', style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(height: 8),

        // DEBUG: Show current selection
        if (_selectedDaysOfWeek.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Selected: ${_selectedDaysOfWeek.map((day) => _getDayName(day)).join(', ')}',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ),
          SizedBox(height: 8),
        ],

        Wrap(
          spacing: 8,
          children: List.generate(_daysOfWeek.length, (index) {
            final day = _daysOfWeek[index];
            final dayNumber = index + 1; // Monday = 1, Tuesday = 2, etc.
            final isSelected = _selectedDaysOfWeek.contains(dayNumber);

            return FilterChip(
              label: Text(day.substring(0, 3)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (!_selectedDaysOfWeek.contains(dayNumber)) {
                      _selectedDaysOfWeek.add(dayNumber);
                    }
                  } else {
                    _selectedDaysOfWeek.remove(dayNumber);
                  }
                  _selectedDaysOfWeek.sort();

                  print('🔄 Day selection updated: $_selectedDaysOfWeek');
                  print(
                      '   Selected days: ${_selectedDaysOfWeek.map((d) => _getDayName(d)).join(', ')}');

                  _updatePreviewCount();
                });

                // NEW: Check for conflicts when selected days change
                if (_selectedInstructor != null) {
                  _checkInstructorAndVehicleAvailability();
                }
              },
              selectedColor: Colors.blue.withOpacity(0.2),
              checkmarkColor: Colors.blue,
            );
          }),
        ),

        // WARNING: Show if no days are selected for weekly pattern
        if (_recurrencePattern == 'weekly' && _selectedDaysOfWeek.isEmpty) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text(
                  'Please select at least one day for weekly pattern',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

// STEP 6: Fix the _generateScheduleDates method to properly generate dates
  List<DateTime> _generateScheduleDates() {
    List<DateTime> dates = [];
    DateTime currentDate = _selectedStartDate;
    int count = 0;
    int maxCount = _useEndDate ? 100 : _maxOccurrences;
    int safetyCounter = 0;
    const maxDays = 1000; // Safety limit

    while (count < maxCount && count < 20 && safetyCounter < maxDays) {
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
        dates.add(currentDate);
        count++;
      }

      if (_useEndDate &&
          _recurrenceEndDate != null &&
          currentDate.isAfter(_recurrenceEndDate!)) {
        break;
      }

      currentDate = currentDate.add(Duration(days: 1));
      safetyCounter++;
    }

    return dates;
  }

// STEP 7: Fix the conflict detection method to work properly
  Future<void> _checkInstructorAndVehicleAvailability() async {
    if (_selectedInstructor == null) {
      setState(() {
        _instructorAvailable = true;
        _vehicleAvailable = true;
        _showAvailabilityStatus = false;
        _conflictDetails.clear();
      });
      return;
    }

    try {
      List<String> conflicts = [];
      bool instructorConflict = false;
      bool vehicleConflict = false;

      // Generate all the dates this recurring schedule would create
      List<DateTime> scheduleDates = _generateScheduleDates();

      print('🔄 Checking conflicts for ${scheduleDates.length} dates');

      for (DateTime scheduleDate in scheduleDates) {
        final checkStartTime = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day,
          _startTime.hour,
          _startTime.minute,
        );

        final checkEndTime = DateTime(
          scheduleDate.year,
          scheduleDate.month,
          scheduleDate.day,
          _endTime.hour,
          _endTime.minute,
        );

        // Check instructor conflicts
        final instructorConflicts =
            _scheduleController.schedules.where((schedule) {
          // Check if it's the same instructor
          if (schedule.instructorId != _selectedInstructor!.id) {
            return false;
          }

          // Skip cancelled schedules
          if (schedule.status.toLowerCase() == 'cancelled') {
            return false;
          }

          // Check for time overlap
          return (checkStartTime.isBefore(schedule.end) &&
              checkEndTime.isAfter(schedule.start));
        }).toList();

        if (instructorConflicts.isNotEmpty) {
          instructorConflict = true;
          final conflictTime = DateFormat('MMM d, hh:mm a')
              .format(instructorConflicts.first.start);
          final conflictEndTime =
              DateFormat('hh:mm a').format(instructorConflicts.first.end);
          conflicts.add(
              '${DateFormat('MMM d').format(scheduleDate)}: Instructor busy $conflictTime-$conflictEndTime');
        }

        // Check vehicle conflicts for practical lessons
        if (_selectedClassType == 'Practical' && _selectedVehicle != null) {
          final vehicleConflicts =
              _scheduleController.schedules.where((schedule) {
            // Check if it's the same vehicle
            if (schedule.carId != _selectedVehicle!.id) {
              return false;
            }

            // Skip cancelled schedules
            if (schedule.status.toLowerCase() == 'cancelled') {
              return false;
            }

            // Check for time overlap
            return (checkStartTime.isBefore(schedule.end) &&
                checkEndTime.isAfter(schedule.start));
          }).toList();

          if (vehicleConflicts.isNotEmpty) {
            vehicleConflict = true;
            final conflictTime = DateFormat('MMM d, hh:mm a')
                .format(vehicleConflicts.first.start);
            final conflictEndTime =
                DateFormat('hh:mm a').format(vehicleConflicts.first.end);
            conflicts.add(
                '${DateFormat('MMM d').format(scheduleDate)}: Vehicle busy $conflictTime-$conflictEndTime');
          }
        }

        // Limit conflicts shown to prevent overwhelming the user
        if (conflicts.length >= 5) {
          conflicts.add('... and more conflicts');
          break;
        }
      }

      setState(() {
        _instructorAvailable = !instructorConflict;
        _vehicleAvailable = !vehicleConflict;
        _showAvailabilityStatus = true;
        _conflictDetails = conflicts;
      });

      // Show snackbar if there are conflicts
      if (conflicts.isNotEmpty) {
        final conflictType = instructorConflict && vehicleConflict
            ? 'Instructor and Vehicle'
            : instructorConflict
                ? 'Instructor'
                : 'Vehicle';

        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          '$conflictType Conflicts Detected',
          '${conflicts.length > 5 ? '5+' : conflicts.length} scheduling conflicts found',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }

      print('🔄 Conflict check complete: ${conflicts.length} conflicts found');
    } catch (e) {
      print('Error checking availability: $e');
      setState(() {
        _instructorAvailable = false;
        _vehicleAvailable = false;
        _showAvailabilityStatus = true;
        _conflictDetails = ['Error checking availability'];
      });
    }
  }

// STEP 8: Enhance the create button to show warnings for conflicts
  Widget _buildActionButtons() {
    final errors = _getValidationErrors();
    final hasErrors = errors.isNotEmpty;
    final hasConflicts = _showAvailabilityStatus &&
        (!_instructorAvailable || !_vehicleAvailable);

    return Column(
      children: [
        // Show conflict warning if there are conflicts but no blocking errors
        if (hasConflicts && !hasErrors) ...[
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 16),
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
                    'Warning: ${_conflictDetails.length} scheduling conflicts detected. Some sessions may be skipped during creation.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: hasErrors ? null : _createRecurringSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasErrors
                  ? Colors.grey
                  : hasConflicts
                      ? Colors.orange
                      : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    hasConflicts && !hasErrors
                        ? 'Create Schedule (Skip Conflicts)'
                        : 'Create Recurring Schedule',
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

  // STEP 9: Enhanced _createRecurringSchedule method that handles conflicts properly
  Future<void> _createRecurringSchedule() async {
    print('🔄 RECURRING SCHEDULE CREATION STARTED');

    if (!_canCreateRecurringSchedule()) {
      final errors = _getValidationErrors();
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Validation Error',
        errors.isNotEmpty
            ? errors.first
            : 'Please complete all required fields',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      Get.dialog(
        Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text('Creating recurring schedules...'),
                SizedBox(height: 8),
                Text('Checking for conflicts and creating valid schedules',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final schedules = <Schedule>[];
      final skippedDates = <DateTime>[];
      DateTime currentDate = _selectedStartDate;
      int schedulesCreated = 0;
      int daysChecked = 0;
      final maxDays = 1000; // Safety limit

      // Determine the actual end condition
      final targetScheduleCount = _useEndDate ? _previewCount : _maxOccurrences;
      final endDate = _useEndDate
          ? _recurrenceEndDate!
          : _selectedStartDate.add(Duration(days: 365));

      print(
          '🔄 TARGET: Create $targetScheduleCount schedules until ${endDate.toString().substring(0, 10)}');

      while (schedulesCreated < targetScheduleCount &&
          (currentDate.isBefore(endDate) ||
              currentDate.isAtSameMomentAs(endDate)) &&
          daysChecked < maxDays) {
        daysChecked++;
        bool shouldCreateSchedule = false;

        // Check if this date matches our recurrence pattern
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

          // Check for conflicts before creating this schedule
          bool hasConflict =
              await _checkSingleDateConflict(startDateTime, endDateTime);

          if (!hasConflict) {
            // Create the schedule
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
            schedulesCreated++;

            print(
                '✅ Schedule $schedulesCreated created for ${startDateTime.toString().substring(0, 16)}');
          } else {
            // Skip this date due to conflict
            skippedDates.add(currentDate);
            print(
                '⚠️ Skipped ${currentDate.toString().substring(0, 10)} due to conflict');
          }
        }

        // Move to next day
        currentDate = currentDate.add(Duration(days: 1));

        if (daysChecked >= maxDays) {
          print(
              '⚠️ Reached maximum days limit ($maxDays), stopping generation');
          break;
        }
      }

      print('🔄 GENERATION COMPLETE:');
      print('   Days checked: $daysChecked');
      print('   Schedules generated: ${schedules.length}');
      print('   Schedules skipped: ${skippedDates.length}');
      print('   Target was: $targetScheduleCount');

      if (schedules.isEmpty) {
        throw Exception(
            'No schedules could be created. All dates had conflicts or no valid dates found.');
      }

      // Save all schedules WITH SILENT MODE to prevent multiple snackbars
      int savedCount = 0;
      int failedCount = 0;
      List<String> errors = [];

      for (int i = 0; i < schedules.length; i++) {
        try {
          // FIX 1: Use silent mode to prevent individual success snackbars
          await _scheduleController.addOrUpdateSchedule(schedules[i],
              silent: true);
          savedCount++;
          if (i < 5) {
            print(
                '✅ Saved schedule ${i + 1}: ${schedules[i].start.toString().substring(0, 16)}');
          }
        } catch (e) {
          failedCount++;
          errors.add('Schedule ${i + 1}: $e');
          print('❌ Failed to save schedule ${i + 1}: $e');
        }
      }

      print('🔄 SAVE RESULTS:');
      print('   Successfully saved: $savedCount');
      print('   Failed to save: $failedCount');
      print('   Conflicts skipped: ${skippedDates.length}');

      // Close loading dialog
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      // Refresh schedule controller
      await _scheduleController.fetchSchedules();

      // FIX 2: Show single consolidated success message
      if (savedCount > 0) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Success',
          'Created $savedCount recurring schedule${savedCount > 1 ? 's' : ''} successfully!${skippedDates.length > 0 ? ' (${skippedDates.length} skipped due to conflicts)' : ''}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }

      // Show enhanced results dialog with conflict information
      _showEnhancedResultsDialog(savedCount, failedCount, skippedDates.length,
          schedules.length, errors);
    } catch (e, stackTrace) {
      print('🚨 ERROR in recurring schedule creation: $e');
      print('🚨 Stack trace: $stackTrace');

      if (Get.isDialogOpen == true) {
        Get.back();
      }

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Failed to create recurring schedule: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 8),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

// FIX 3: Update the _showEnhancedResultsDialog method to fix navigation
  void _showEnhancedResultsDialog(int savedCount, int failedCount,
      int conflictsSkipped, int totalAttempted, List<String> errors) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(
              savedCount > 0 ? Icons.check_circle : Icons.error,
              color: savedCount > 0 ? Colors.green : Colors.red,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                savedCount > 0
                    ? 'Recurring Schedule Created!'
                    : 'Schedule Creation Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Success summary
              if (savedCount > 0) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✅ Successfully created: $savedCount schedule${savedCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      if (conflictsSkipped > 0)
                        Text(
                          '⚠️ Skipped due to conflicts: $conflictsSkipped',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                    ],
                  ),
                ),
              ],

              // Failure summary
              if (failedCount > 0) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '❌ Failed to create: $failedCount schedule${failedCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      if (errors.isNotEmpty) ...[
                        SizedBox(height: 8),
                        ...errors.take(3).map((error) => Text(
                              '• $error',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.red.shade600),
                            )),
                        if (errors.length > 3)
                          Text(
                            '... and ${errors.length - 3} more errors',
                            style: TextStyle(
                                fontSize: 12, color: Colors.red.shade600),
                          ),
                      ],
                    ],
                  ),
                ),
              ],

              SizedBox(height: 16),
              Text(
                'Total attempted: $totalAttempted schedules',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          if (savedCount > 0) ...[
            OutlinedButton.icon(
              onPressed: () {
                Get.back(); // Close dialog
                Get.back(); // Go back to previous screen

                // FIX 4: Use navigation controller for safer navigation
                try {
                  final navController = Get.find<NavigationController>();
                  navController.navigateToPage('schedules');
                } catch (e) {
                  // Fallback to direct navigation with correct route
                  Get.offNamed(
                      '/schedules'); // Fixed: added 's' to make it '/schedules'
                }
              },
              icon: Icon(Icons.calendar_view_day),
              label: Text('View Schedules'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: BorderSide(color: Colors.green),
              ),
            ),
            SizedBox(width: 8),
          ],
          ElevatedButton.icon(
            onPressed: () {
              Get.back(); // Close dialog
              if (savedCount > 0) {
                Get.back(); // Close recurring schedule screen
                // Refresh the schedule screen
                Get.find<ScheduleController>().fetchSchedules();
              }
            },
            icon: Icon(Icons.check),
            label: Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: savedCount > 0 ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

// STEP 10: Method to check for conflicts on a single date
  Future<bool> _checkSingleDateConflict(
      DateTime startDateTime, DateTime endDateTime) async {
    // Check instructor conflicts
    final instructorConflicts = _scheduleController.schedules.where((schedule) {
      // Check if it's the same instructor
      if (schedule.instructorId != _selectedInstructor!.id) return false;

      // Skip cancelled schedules
      if (schedule.status.toLowerCase() == 'cancelled') return false;

      // Check for time overlap
      return (startDateTime.isBefore(schedule.end) &&
          endDateTime.isAfter(schedule.start));
    }).toList();

    if (instructorConflicts.isNotEmpty) {
      return true; // Has conflict
    }

    // Check vehicle conflicts for practical lessons
    if (_selectedClassType == 'Practical' && _selectedVehicle != null) {
      final vehicleConflicts = _scheduleController.schedules.where((schedule) {
        // Check if it's the same vehicle
        if (schedule.carId != _selectedVehicle!.id) return false;

        // Skip cancelled schedules
        if (schedule.status.toLowerCase() == 'cancelled') return false;

        // Check for time overlap
        return (startDateTime.isBefore(schedule.end) &&
            endDateTime.isAfter(schedule.start));
      }).toList();

      if (vehicleConflicts.isNotEmpty) {
        return true; // Has conflict
      }
    }

    return false; // No conflicts
  }

// STEP 12: Helper method for result summary rows
  Widget _buildResultSummaryRow(String label, int count, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14)),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityStatus() {
    if (!_showAvailabilityStatus) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (_instructorAvailable && _vehicleAvailable)
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (_instructorAvailable && _vehicleAvailable)
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                (_instructorAvailable && _vehicleAvailable)
                    ? Icons.check_circle
                    : Icons.warning,
                color: (_instructorAvailable && _vehicleAvailable)
                    ? Colors.green
                    : Colors.orange,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  (_instructorAvailable && _vehicleAvailable)
                      ? 'No scheduling conflicts detected'
                      : 'Scheduling conflicts detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: (_instructorAvailable && _vehicleAvailable)
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (_conflictDetails.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Conflicts found:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade600,
              ),
            ),
            SizedBox(height: 4),
            ...(_conflictDetails.take(3).map((conflict) => Padding(
                  padding: EdgeInsets.only(left: 12, bottom: 2),
                  child: Text(
                    '• $conflict',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ))),
            if (_conflictDetails.length > 3)
              Padding(
                padding: EdgeInsets.only(left: 12),
                child: Text(
                  '• ... and ${_conflictDetails.length - 3} more conflicts',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            SizedBox(height: 4),
            Text(
              'Note: Conflicting sessions will be automatically skipped during creation.',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

// STEP 14: Updated validation method that properly handles conflicts
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

    // Note: We don't add conflicts as blocking errors anymore
    // They will be handled during creation by skipping conflicting dates

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

    // Lesson count validation
    final totalLessonsNeeded = _getTotalLessonsToDeduct();

    if (totalLessonsNeeded > _remainingLessons && _remainingLessons > 0) {
      final lessonsPerOccurrence = _getLessonsPerOccurrence();
      errors.add(
          'This schedule needs $totalLessonsNeeded lessons ($_previewCount occurrences × $lessonsPerOccurrence lessons each), but only $_remainingLessons lessons remain');
    }

    // Check if end date would generate too many lessons
    if (_useEndDate && _recurrenceEndDate != null && _remainingLessons > 0) {
      int estimatedOccurrences =
          _calculateLessonsForPeriod(_selectedStartDate, _recurrenceEndDate!);
      int estimatedTotalLessons =
          estimatedOccurrences * _getLessonsPerOccurrence();

      if (estimatedTotalLessons > _remainingLessons) {
        errors.add(
            'End date would generate $estimatedTotalLessons lessons ($estimatedOccurrences occurrences × ${_getLessonsPerOccurrence()} lessons each), but only $_remainingLessons lessons remain');
      }
    }

    return errors;
  }

// STEP 15: Updated _canCreateRecurringSchedule method
  bool _canCreateRecurringSchedule() {
    if (_selectedStudent == null ||
        _selectedInstructor == null ||
        _selectedCourse == null ||
        _previewCount <= 0 ||
        _remainingLessons <= 0) {
      print('DEBUG: Basic requirements not met');
      return false;
    }

    // Note: We no longer block creation due to conflicts
    // Conflicts will be handled by skipping those dates during creation

    // Check vehicle availability for practical lessons
    if (_selectedClassType == 'Practical') {
      if (_selectedVehicle == null) {
        print('DEBUG: _selectedVehicle is null for practical lesson');
        return false;
      }

      // Ensure the vehicle is actually assigned to the selected instructor
      if (_selectedVehicle!.instructor != _selectedInstructor!.id) {
        print('DEBUG: Vehicle not assigned to instructor');
        return false;
      }
    }

    // Check if start date and time is not in the past
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(_selectedStartDate.year, _selectedStartDate.month,
        _selectedStartDate.day);

    if (startDay.isBefore(today)) {
      print('DEBUG: Start date is in the past');
      return false;
    }

    // Check if time is in the past for today's date
    if (startDay.isAtSameMomentAs(today)) {
      final startDateTime = DateTime(
        _selectedStartDate.year,
        _selectedStartDate.month,
        _selectedStartDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      if (startDateTime.isBefore(now)) {
        print('DEBUG: Start time is in the past');
        return false;
      }
    }

    // Check validation errors (but not conflicts)
    final errors = _getValidationErrors();
    if (errors.isNotEmpty) {
      print('DEBUG: Validation errors: $errors');
      return false;
    }

    print('DEBUG: All validations passed');
    return true;
  }

// STEP 16: Add this method to trigger conflict checks when needed
  void _triggerConflictCheck() {
    if (_selectedInstructor != null && _selectedStartDate != null) {
      // Add a small delay to ensure state is updated
      Future.delayed(Duration(milliseconds: 100), () {
        _checkInstructorAndVehicleAvailability();
      });
    }
  }

  void _updateLessonCounts() {
    if (_selectedStudent != null && _selectedCourse != null) {
      setState(() {
        _remainingLessons = _scheduleController.getRemainingLessons(
            _selectedStudent!.id!, _selectedCourse!.id!);

        // AUTO-SET optimal end date when course is selected
        if (_remainingLessons > 0) {
          _recurrenceEndDate = _calculateOptimalEndDate();
        }
      });
      _updatePreviewCount();

      // Add this to trigger conflict check:
      _triggerConflictCheck();
    }
  }

// STEP 18: Quick test method (you can remove this after testing)
  void _testConflictDetection() {
    print('🔧 TESTING CONFLICT DETECTION');
    print(
        '   Instructor selected: ${_selectedInstructor?.fname} ${_selectedInstructor?.lname}');
    print('   Start date: ${_selectedStartDate.toString().substring(0, 10)}');
    print(
        '   Time: ${_startTime.format(context)} - ${_endTime.format(context)}');
    print('   Pattern: $_recurrencePattern');
    print('   Selected days: $_selectedDaysOfWeek');
    print('   Show availability status: $_showAvailabilityStatus');
    print('   Instructor available: $_instructorAvailable');
    print('   Conflict details: $_conflictDetails');

    _checkInstructorAndVehicleAvailability();
  }
}
