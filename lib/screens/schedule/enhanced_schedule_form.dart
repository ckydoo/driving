// lib/screens/schedule/enhanced_schedule_form.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/enhanced_schedule.dart';
import '../../controllers/enhanced_schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';

class EnhancedScheduleForm extends StatefulWidget {
  final EnhancedSchedule? existingSchedule;
  final bool isRecurring;

  const EnhancedScheduleForm({
    Key? key,
    this.existingSchedule,
    this.isRecurring = false,
  }) : super(key: key);

  @override
  _EnhancedScheduleFormState createState() => _EnhancedScheduleFormState();
}

class _EnhancedScheduleFormState extends State<EnhancedScheduleForm> {
  final _formKey = GlobalKey<FormState>();
  final _scheduleController = Get.find<EnhancedScheduleController>();
  final _userController = Get.find<UserController>();
  final _courseController = Get.find<CourseController>();
  final _fleetController = Get.find<FleetController>();

  // Form fields
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime =
      TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

  dynamic _selectedStudent;
  dynamic _selectedInstructor;
  dynamic _selectedCourse;
  dynamic _selectedVehicle;
  String _selectedClassType = 'Practical';
  String _selectedStatus = 'Scheduled';
  int _lessonsDeducted = 1;
  String _notes = '';

  // Recurring fields
  String _recurrencePattern = 'weekly';
  DateTime? _recurrenceEndDate;
  int? _maxOccurrences;
  bool _useEndDate = true;
  List<int> _selectedDaysOfWeek = [];
  int _customInterval = 1;

  final List<String> _classTypes = ['Practical', 'Theory'];
  final List<String> _statusOptions = ['Scheduled', 'Confirmed', 'Pending'];
  final List<String> _recurrencePatterns = [
    'daily',
    'weekly',
    'biweekly',
    'monthly',
    'custom'
  ];
  final List<String> _daysOfWeek = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.existingSchedule != null) {
      final schedule = widget.existingSchedule!;
      _selectedDate = schedule.start;
      _startTime = TimeOfDay.fromDateTime(schedule.start);
      _endTime = TimeOfDay.fromDateTime(schedule.end);
      _selectedClassType = schedule.classType;
      _selectedStatus = schedule.status;
      _lessonsDeducted = schedule.lessonsDeducted;
      _notes = schedule.notes ?? '';

      // Set selected entities
      _selectedStudent = _userController.users.firstWhereOrNull(
          (u) => u.id == schedule.studentId && u.role == 'student');
      _selectedInstructor = _userController.users.firstWhereOrNull(
          (u) => u.id == schedule.instructorId && u.role == 'instructor');
      _selectedCourse = _courseController.courses
          .firstWhereOrNull((c) => c.id == schedule.courseId);
      _selectedVehicle = schedule.carId != null
          ? _fleetController.fleet
              .firstWhereOrNull((v) => v.id == schedule.carId)
          : null;

      if (schedule.isRecurring) {
        _recurrencePattern = schedule.recurrencePattern ?? 'weekly';
        _recurrenceEndDate = schedule.recurrenceEndDate;
        _maxOccurrences = schedule.maxOccurrences;
        _selectedDaysOfWeek = schedule.selectedDaysOfWeek ?? [];
        _customInterval = schedule.customInterval ?? 1;
        _useEndDate = schedule.recurrenceEndDate != null;
      }
    } else {
      _recurrenceEndDate = DateTime.now().add(Duration(days: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingSchedule != null
            ? 'Edit Schedule'
            : widget.isRecurring
                ? 'Create Recurring Schedule'
                : 'Create Single Schedule'),
        backgroundColor: widget.isRecurring ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (widget.existingSchedule != null)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
        ],
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
              if (widget.isRecurring) ...[
                _buildRecurrenceSection(),
                SizedBox(height: 24),
              ],
              _buildNotesSection(),
              SizedBox(height: 32),
              _buildActionButtons(),
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
            Text('Basic Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),

            // Student Selection
            DropdownButtonFormField(
              value: _selectedStudent,
              decoration: InputDecoration(
                labelText: 'Student *',
                border: OutlineInputBorder(),
              ),
              items: _userController.users
                  .where((u) => u.role == 'student' && u.status == 'Active')
                  .map((student) => DropdownMenuItem(
                        value: student,
                        child: Text('${student.fname} ${student.lname}'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedStudent = value),
              validator: (value) =>
                  value == null ? 'Please select a student' : null,
            ),
            SizedBox(height: 16),

            // Course Selection
            DropdownButtonFormField(
              value: _selectedCourse,
              decoration: InputDecoration(
                labelText: 'Course *',
                border: OutlineInputBorder(),
              ),
              items: _courseController.courses
                  .where((c) => c.status == 'Active')
                  .map((course) => DropdownMenuItem(
                        value: course,
                        child: Text(course.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCourse = value),
              validator: (value) =>
                  value == null ? 'Please select a course' : null,
            ),
            SizedBox(height: 16),

            // Instructor Selection
            DropdownButtonFormField(
              value: _selectedInstructor,
              decoration: InputDecoration(
                labelText: 'Instructor *',
                border: OutlineInputBorder(),
              ),
              items: _userController.users
                  .where((u) => u.role == 'instructor' && u.status == 'Active')
                  .map((instructor) => DropdownMenuItem(
                        value: instructor,
                        child: Text('${instructor.fname} ${instructor.lname}'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedInstructor = value),
              validator: (value) =>
                  value == null ? 'Please select an instructor' : null,
            ),
            SizedBox(height: 16),

            // Vehicle Selection (Optional)
            DropdownButtonFormField(
              value: _selectedVehicle,
              decoration: InputDecoration(
                labelText: 'Vehicle (Optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                    value: null, child: Text('No vehicle assigned')),
                ..._fleetController.fleet
                    // .where((v) => v.status == 'Active')
                    .map((vehicle) => DropdownMenuItem(
                          value: vehicle,
                          child: Text(
                              '${vehicle.make} ${vehicle.model} (${vehicle.carPlate})'),
                        ))
                    .toList(),
              ],
              onChanged: (value) => setState(() => _selectedVehicle = value),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedClassType,
                    decoration: InputDecoration(
                      labelText: 'Class Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: _classTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedClassType = value!),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Status *',
                      border: OutlineInputBorder(),
                    ),
                    items: _statusOptions
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedStatus = value!),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Date and Time Selection
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.isRecurring ? 'Start Date *' : 'Date *',
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Start Time *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_startTime.format(context)),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'End Time *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_endTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            TextFormField(
              initialValue: _lessonsDeducted.toString(),
              decoration: InputDecoration(
                labelText: 'Lessons to Deduct *',
                border: OutlineInputBorder(),
                helperText: 'Number of lessons this session will consume',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter lessons to deduct';
                final lessons = int.tryParse(value);
                if (lessons == null || lessons < 1)
                  return 'Must be a positive number';
                return null;
              },
              onChanged: (value) {
                final lessons = int.tryParse(value);
                if (lessons != null) _lessonsDeducted = lessons;
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
            Text('Recurrence Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _recurrencePattern,
              decoration: InputDecoration(
                labelText: 'Recurrence Pattern *',
                border: OutlineInputBorder(),
              ),
              items: _recurrencePatterns
                  .map((pattern) => DropdownMenuItem(
                        value: pattern,
                        child: Text(pattern.capitalizeFirst!),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                _recurrencePattern = value!;
                if (value == 'weekly' || value == 'biweekly') {
                  _selectedDaysOfWeek = [_selectedDate.weekday];
                }
              }),
            ),
            SizedBox(height: 16),

            if (_recurrencePattern == 'weekly' ||
                _recurrencePattern == 'biweekly') ...[
              Text('Select Days of Week:'),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (index) {
                  final dayIndex = index + 1;
                  final isSelected = _selectedDaysOfWeek.contains(dayIndex);
                  return FilterChip(
                    label: Text(_daysOfWeek[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDaysOfWeek.add(dayIndex);
                        } else {
                          _selectedDaysOfWeek.remove(dayIndex);
                        }
                      });
                    },
                  );
                }),
              ),
              SizedBox(height: 16),
            ],

            if (_recurrencePattern == 'custom') ...[
              TextFormField(
                initialValue: _customInterval.toString(),
                decoration: InputDecoration(
                  labelText: 'Repeat Every (days) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter interval';
                  final interval = int.tryParse(value);
                  if (interval == null || interval < 1)
                    return 'Must be a positive number';
                  return null;
                },
                onChanged: (value) {
                  final interval = int.tryParse(value);
                  if (interval != null) _customInterval = interval;
                },
              ),
              SizedBox(height: 16),
            ],

            // End condition
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text('End by date'),
                    value: true,
                    groupValue: _useEndDate,
                    onChanged: (value) => setState(() => _useEndDate = value!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text('Max occurrences'),
                    value: false,
                    groupValue: _useEndDate,
                    onChanged: (value) => setState(() => _useEndDate = value!),
                  ),
                ),
              ],
            ),

            if (_useEndDate) ...[
              InkWell(
                onTap: _selectEndDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'End Date *',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_recurrenceEndDate != null
                      ? DateFormat('MMM dd, yyyy').format(_recurrenceEndDate!)
                      : 'Select end date'),
                ),
              ),
            ] else ...[
              TextFormField(
                initialValue: _maxOccurrences?.toString() ?? '',
                decoration: InputDecoration(
                  labelText: 'Maximum Occurrences *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (!_useEndDate) {
                    if (value == null || value.isEmpty)
                      return 'Please enter max occurrences';
                    final max = int.tryParse(value);
                    if (max == null || max < 1)
                      return 'Must be a positive number';
                  }
                  return null;
                },
                onChanged: (value) {
                  final max = int.tryParse(value);
                  _maxOccurrences = max;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Additional Notes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            TextFormField(
              initialValue: _notes,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Add any special instructions or notes...',
              ),
              maxLines: 3,
              onChanged: (value) => _notes = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Obx(() => ElevatedButton(
                onPressed:
                    _scheduleController.isLoading.value ? null : _saveSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.isRecurring ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _scheduleController.isLoading.value
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.existingSchedule != null ? 'Update' : 'Create'),
              )),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null) {
      setState(() {
        _startTime = time;
        // Automatically adjust end time to be 1 hour later
        _endTime = TimeOfDay(
          hour: (time.hour + 1) % 24,
          minute: time.minute,
        );
      });
    }
  }

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (time != null) {
      setState(() => _endTime = time);
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? DateTime.now().add(Duration(days: 30)),
      firstDate: _selectedDate,
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _recurrenceEndDate = date);
    }
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate recurring specific fields
    if (widget.isRecurring) {
      if ((_recurrencePattern == 'weekly' ||
              _recurrencePattern == 'biweekly') &&
          _selectedDaysOfWeek.isEmpty) {
        Get.snackbar('Error', 'Please select at least one day of the week');
        return;
      }
      if (_useEndDate && _recurrenceEndDate == null) {
        Get.snackbar('Error', 'Please select an end date');
        return;
      }
      if (!_useEndDate && _maxOccurrences == null) {
        Get.snackbar('Error', 'Please enter maximum occurrences');
        return;
      }
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

    if (endDateTime.isBefore(startDateTime)) {
      Get.snackbar('Error', 'End time must be after start time');
      return;
    }

    final schedule = EnhancedSchedule(
      id: widget.existingSchedule?.id,
      start: startDateTime,
      end: endDateTime,
      courseId: _selectedCourse!.id!,
      studentId: _selectedStudent!.id!,
      instructorId: _selectedInstructor!.id!,
      carId: _selectedVehicle?.id,
      classType: _selectedClassType,
      status: _selectedStatus,
      lessonsDeducted: _lessonsDeducted,
      isRecurring: widget.isRecurring,
      recurrencePattern: widget.isRecurring ? _recurrencePattern : null,
      recurrenceEndDate: widget.isRecurring ? _recurrenceEndDate : null,
      maxOccurrences:
          widget.isRecurring && !_useEndDate ? _maxOccurrences : null,
      selectedDaysOfWeek: widget.isRecurring ? _selectedDaysOfWeek : null,
      customInterval: widget.isRecurring && _recurrencePattern == 'custom'
          ? _customInterval
          : null,
      createdAt: widget.existingSchedule?.createdAt ?? DateTime.now(),
      notes: _notes.isNotEmpty ? _notes : null,
    );

    bool success;
    if (widget.existingSchedule != null) {
      // Update existing schedule
      success = await _scheduleController.rescheduleSession(
        widget.existingSchedule!.id!,
        startDateTime,
        endDateTime,
      );
    } else if (widget.isRecurring) {
      success = await _scheduleController.createRecurringSchedules(schedule);
    } else {
      success = await _scheduleController.createSingleSchedule(schedule);
    }

    if (success) {
      Get.back(result: true);
    }
  }

  void _showDeleteConfirmation() {
    if (widget.existingSchedule == null) return;

    Get.dialog(
      AlertDialog(
        title: Text('Delete Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete this schedule?'),
            if (widget.existingSchedule!.isRecurring) ...[
              SizedBox(height: 16),
              Text(
                  'This is part of a recurring series. What would you like to do?'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          if (widget.existingSchedule!.isRecurring) ...[
            TextButton(
              onPressed: () {
                Get.back();
                _deleteSchedule(false);
              },
              child: Text('Delete This Only'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                _deleteSchedule(true);
              },
              child: Text('Delete All Recurring',
                  style: TextStyle(color: Colors.red)),
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                Get.back();
                _deleteSchedule(false);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteSchedule(bool deleteAllRecurring) async {
    await _scheduleController.deleteSchedule(
      widget.existingSchedule!.id!,
      deleteAllRecurring: deleteAllRecurring,
    );
    Get.back(result: true);
  }
}
