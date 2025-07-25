// lib/screens/schedule/recurring_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/schedule.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';

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

  // Form fields
  DateTime _selectedStartDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime =
      TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

  var _selectedStudent;
  var _selectedInstructor;
  var _selectedCourse;
  var _selectedVehicle;
  String _selectedClassType = 'Practical';
  String _selectedStatus = 'Scheduled';

  // Recurring specific fields
  String _recurrencePattern = 'weekly';
  DateTime? _recurrenceEndDate;
  List<int> _selectedDaysOfWeek = []; // For weekly recurrence
  int _customInterval = 1; // For custom intervals (every X days/weeks/months)
  int _maxOccurrences = 0; // Alternative to end date
  bool _useEndDate = true; // Toggle between end date and max occurrences

  bool _isLoading = false;
  int _previewCount = 0;

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
    _recurrenceEndDate =
        DateTime.now().add(Duration(days: 30)); // Default 30 days
    _updatePreviewCount();
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              SizedBox(height: 24),
              _buildRecurrenceSection(),
              SizedBox(height: 24),
              _buildParticipantsSection(),
              SizedBox(height: 24),
              _buildDetailsSection(),
              SizedBox(height: 24),
              _buildPreviewSection(),
              SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Start Date
            ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.blue),
              title: Text('Start Date'),
              subtitle: Text(DateFormat.yMMMd().format(_selectedStartDate)),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: _selectStartDate,
            ),

            Divider(),

            // Start Time
            ListTile(
              leading: Icon(Icons.access_time, color: Colors.green),
              title: Text('Start Time'),
              subtitle: Text(_startTime.format(context)),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _selectTime(true),
            ),

            // End Time
            ListTile(
              leading: Icon(Icons.access_time_filled, color: Colors.orange),
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

  Widget _buildRecurrenceSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recurrence Pattern',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      label: Text(pattern.capitalize!),
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
            Text('days', style: TextStyle(fontSize: 16)),
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

        // Toggle between end date and max occurrences
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: Text('End Date'),
                value: true,
                groupValue: _useEndDate,
                onChanged: (value) {
                  setState(() {
                    _useEndDate = value!;
                    _updatePreviewCount();
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: Text('After X times'),
                value: false,
                groupValue: _useEndDate,
                onChanged: (value) {
                  setState(() {
                    _useEndDate = value!;
                    _updatePreviewCount();
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),

        SizedBox(height: 8),

        if (_useEndDate)
          GestureDetector(
            onTap: _selectRecurrenceEndDate,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    _recurrenceEndDate != null
                        ? DateFormat.yMMMd().format(_recurrenceEndDate!)
                        : 'Select end date',
                    style: TextStyle(
                      color: _recurrenceEndDate != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          TextFormField(
            initialValue: _maxOccurrences.toString(),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Number of occurrences',
              border: OutlineInputBorder(),
              suffixText: 'times',
            ),
            onChanged: (value) {
              setState(() {
                _maxOccurrences = int.tryParse(value) ?? 0;
                _updatePreviewCount();
              });
            },
          ),
      ],
    );
  }

  Widget _buildParticipantsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Course Selection
            _buildDropdown<dynamic>(
              label: 'Course',
              icon: Icons.book,
              value: _selectedCourse,
              items: _courseController.courses,
              onChanged: (value) => setState(() => _selectedCourse = value),
              displayText: (item) => item?.name ?? 'Select Course',
              validator: (value) =>
                  value == null ? 'Please select a course' : null,
            ),

            SizedBox(height: 16),

            // Student Selection
            _buildDropdown<dynamic>(
              label: 'Student',
              icon: Icons.person,
              value: _selectedStudent,
              items: _userController.users
                  .where((user) => user.role == 'student')
                  .toList(),
              onChanged: (value) => setState(() => _selectedStudent = value),
              displayText: (item) => item != null
                  ? '${item.fname} ${item.lname}'
                  : 'Select Student',
              validator: (value) =>
                  value == null ? 'Please select a student' : null,
            ),

            SizedBox(height: 16),

            // Instructor Selection
            _buildDropdown<dynamic>(
              label: 'Instructor',
              icon: Icons.person_pin,
              value: _selectedInstructor,
              items: _userController.users
                  .where((user) => user.role == 'instructor')
                  .toList(),
              onChanged: (value) => setState(() => _selectedInstructor = value),
              displayText: (item) => item != null
                  ? '${item.fname} ${item.lname}'
                  : 'Select Instructor',
              validator: (value) =>
                  value == null ? 'Please select an instructor' : null,
            ),

            SizedBox(height: 16),

            // Vehicle Selection (Optional)
            _buildDropdown<dynamic>(
              label: 'Vehicle (Optional)',
              icon: Icons.directions_car,
              value: _selectedVehicle,
              items: _fleetController.fleet,
              onChanged: (value) => setState(() => _selectedVehicle = value),
              displayText: (item) => item != null
                  ? '${item.make} ${item.model} - ${item.carPlate}'
                  : 'Select Vehicle',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildDropdown<String>(
              label: 'Status',
              icon: Icons.flag,
              value: _selectedStatus,
              items: _statusOptions,
              onChanged: (value) => setState(() => _selectedStatus = value!),
              displayText: (item) => item ?? 'Select Status',
              validator: (value) =>
                  value == null ? 'Please select a status' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Schedule Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'This will create $_previewCount recurring schedule(s)',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            if (_previewCount > 0)
              _buildPreviewDetails()
            else
              Text(
                'Please configure the recurrence pattern to see preview',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewDetails() {
    String patternDescription = '';
    switch (_recurrencePattern) {
      case 'daily':
        patternDescription = 'Every day';
        break;
      case 'weekly':
        if (_selectedDaysOfWeek.isNotEmpty) {
          final dayNames = _selectedDaysOfWeek
              .map((day) => _daysOfWeek[day - 1].substring(0, 3))
              .join(', ');
          patternDescription = 'Every week on $dayNames';
        } else {
          patternDescription = 'Weekly (no days selected)';
        }
        break;
      case 'monthly':
        patternDescription = 'Monthly on day ${_selectedStartDate.day}';
        break;
      case 'custom':
        patternDescription = 'Every $_customInterval days';
        break;
    }

    String endDescription = '';
    if (_useEndDate && _recurrenceEndDate != null) {
      endDescription =
          'Until ${DateFormat.yMMMd().format(_recurrenceEndDate!)}';
    } else if (!_useEndDate && _maxOccurrences > 0) {
      endDescription = 'For $_maxOccurrences occurrences';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• Pattern: $patternDescription'),
        Text('• Duration: $endDescription'),
        Text(
            '• Time: ${_startTime.format(context)} - ${_endTime.format(context)}'),
        if (_selectedStudent != null)
          Text(
              '• Student: ${_selectedStudent.fname} ${_selectedStudent.lname}'),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String Function(T?) displayText,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(),
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(displayText(item)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed:
            (_isLoading || _previewCount == 0) ? null : _saveRecurringSchedule,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Creating $_previewCount schedules...'),
                ],
              )
            : Text(
                'Create $_previewCount Recurring Schedules',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != _selectedStartDate) {
      setState(() {
        _selectedStartDate = picked;
        _updatePreviewCount();
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
          // Automatically set end time to 1 hour later
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

  Future<void> _selectRecurrenceEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? DateTime.now().add(Duration(days: 30)),
      firstDate: _selectedStartDate.add(Duration(days: 1)),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _recurrenceEndDate = picked;
        _updatePreviewCount();
      });
    }
  }

  void _updatePreviewCount() {
    setState(() {
      _previewCount = _calculateScheduleCount();
    });
  }

  int _calculateScheduleCount() {
    if (_useEndDate && _recurrenceEndDate == null) return 0;
    if (!_useEndDate && _maxOccurrences == 0) return 0;
    if (_recurrencePattern == 'weekly' && _selectedDaysOfWeek.isEmpty) return 0;

    int count = 0;
    DateTime currentDate = _selectedStartDate;
    DateTime endDate = _useEndDate
        ? _recurrenceEndDate!
        : DateTime.now().add(Duration(days: 365));

    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      if (!_useEndDate && count >= _maxOccurrences) break;

      switch (_recurrencePattern) {
        case 'daily':
          count++;
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case 'weekly':
          // Check if current day is in selected days
          if (_selectedDaysOfWeek.contains(currentDate.weekday)) {
            count++;
          }
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case 'monthly':
          count++;
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
          );
          break;
        case 'custom':
          count++;
          currentDate = currentDate.add(Duration(days: _customInterval));
          break;
      }

      // Safety check to prevent infinite loops
      if (count > 1000) break;
    }

    return count;
  }

  Future<void> _saveRecurringSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_recurrencePattern == 'weekly' && _selectedDaysOfWeek.isEmpty) {
      Get.snackbar(
        'Invalid Selection',
        'Please select at least one day for weekly recurrence',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _createRecurringSchedules();

      Get.snackbar(
        'Success',
        '$_previewCount recurring schedules created successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create recurring schedules: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createRecurringSchedules() async {
    final schedules = <Schedule>[];
    DateTime currentDate = _selectedStartDate;
    DateTime endDate = _useEndDate
        ? _recurrenceEndDate!
        : DateTime.now().add(Duration(days: 365));
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
          shouldCreateSchedule = count % _customInterval == 0;
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

        final schedule = Schedule(
          start: startDateTime,
          end: endDateTime,
          courseId: _selectedCourse!.id!,
          studentId: _selectedStudent!.id!,
          instructorId: _selectedInstructor!.id!,
          carId: _selectedVehicle?.id,
          classType: _selectedClassType,
          status: _selectedStatus,
          isRecurring: true,
          recurrencePattern: _recurrencePattern,
          recurrenceEndDate: _recurrenceEndDate,
        );

        schedules.add(schedule);
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
          currentDate = currentDate.add(Duration(days: _customInterval));
          break;
      }

      // Safety check
      if (schedules.length > 1000) break;
    }

    // Save all schedules
    for (final schedule in schedules) {
      await _scheduleController.addOrUpdateSchedule(schedule);
    }
  }
}
