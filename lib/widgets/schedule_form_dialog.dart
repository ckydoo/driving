// lib/widgets/enhanced_schedule_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/user_controller.dart';
import '../controllers/fleet_controller.dart';
import '../controllers/course_controller.dart';
import '../controllers/billing_controller.dart';
import '../models/schedule.dart';
import '../models/user.dart';
import '../models/fleet.dart';
import '../models/course.dart';

class ScheduleFormDialog extends StatefulWidget {
  final Schedule? existingSchedule;
  final DateTime? preselectedDate;
  final User? preselectedStudent;
  final User? preselectedInstructor;

  const ScheduleFormDialog({
    Key? key,
    this.existingSchedule,
    this.preselectedDate,
    this.preselectedStudent,
    this.preselectedInstructor,
  }) : super(key: key);

  @override
  _ScheduleFormDialogState createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<ScheduleFormDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scheduleController = Get.find<ScheduleController>();
  final _userController = Get.find<UserController>();
  final _fleetController = Get.find<FleetController>();
  final _courseController = Get.find<CourseController>();
  final _billingController = Get.find<BillingController>();

  late TabController _tabController;

  // Form data
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  User? _selectedStudent;
  User? _selectedInstructor;
  Fleet? _selectedVehicle;
  Course? _selectedCourse;
  String _classType = 'Practical';
  bool _isRecurring = false;
  String? _recurrencePattern;
  DateTime? _recurrenceEndDate;
  String _notes = '';

  // UI state
  bool _isLoading = false;
  bool _showConflicts = false;
  List<Schedule> _conflicts = [];
  List<User> _availableInstructors = [];
  List<Fleet> _availableVehicles = [];
  Map<String, dynamic> _suggestions = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeFormData();
    _generateSuggestions();
  }

  void _initializeFormData() {
    if (widget.existingSchedule != null) {
      final schedule = widget.existingSchedule!;
      _selectedDate = DateTime(
          schedule.start.year, schedule.start.month, schedule.start.day);
      _startTime = TimeOfDay.fromDateTime(schedule.start);
      _endTime = TimeOfDay.fromDateTime(schedule.end);
      _selectedStudent = _userController.users
          .firstWhereOrNull((u) => u.id == schedule.studentId);
      _selectedInstructor = _userController.users
          .firstWhereOrNull((u) => u.id == schedule.instructorId);
      _selectedVehicle = _fleetController.fleet
          .firstWhereOrNull((v) => v.id == schedule.carId);
      _selectedCourse = _courseController.courses
          .firstWhereOrNull((c) => c.id == schedule.courseId);
      _classType = schedule.classType;
      _isRecurring = schedule.isRecurring;
      _recurrencePattern = schedule.recurrencePattern;
      _recurrenceEndDate = schedule.recurrenceEndDate;
    } else {
      _selectedDate = widget.preselectedDate ?? DateTime.now();
      _selectedStudent = widget.preselectedStudent;
      _selectedInstructor = widget.preselectedInstructor;
      _startTime = TimeOfDay(hour: 9, minute: 0);
      _endTime = TimeOfDay(hour: 10, minute: 30);
    }
  }

  void _generateSuggestions() {
    _suggestions = {
      'bestTimeSlots': _getBestTimeSlots(),
      'recommendedDuration': _getRecommendedDuration(),
      'availableInstructors': _getAvailableInstructors(),
      'studentProgress': _getStudentProgress(),
    };
    setState(() {});
  }

  List<String> _getBestTimeSlots() {
    // Analyze existing schedules to suggest optimal time slots
    final existingSchedules = _scheduleController.schedules;
    final hourCounts = <int, int>{};

    for (var schedule in existingSchedules) {
      hourCounts[schedule.start.hour] =
          (hourCounts[schedule.start.hour] ?? 0) + 1;
    }

    // Find less busy hours
    final sortedHours = hourCounts.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return sortedHours.take(3).map((e) => '${e.key}:00').toList();
  }

  String _getRecommendedDuration() {
    if (_selectedStudent != null && _selectedCourse != null) {
      final studentSchedules = _scheduleController.schedules
          .where((s) => s.studentId == _selectedStudent!.id)
          .toList();

      if (studentSchedules.isNotEmpty) {
        final avgDuration = studentSchedules
                .map((s) => s.end.difference(s.start).inMinutes)
                .reduce((a, b) => a + b) /
            studentSchedules.length;
        return '${(avgDuration / 60).toStringAsFixed(1)} hours (based on history)';
      }
    }
    return '1.5 hours (standard)';
  }

  List<User> _getAvailableInstructors() {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      return _userController.users
          .where((u) => u.role == 'instructor' && u.status == 'Active')
          .toList();
    }

    final startDateTime = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day, _startTime!.hour, _startTime!.minute);
    final endDateTime = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day, _endTime!.hour, _endTime!.minute);

    return _userController.users.where((instructor) {
      if (instructor.role != 'instructor' || instructor.status != 'Active')
        return false;

      return !_scheduleController.schedules.any((schedule) =>
          schedule.instructorId == instructor.id &&
          schedule.start.isBefore(endDateTime) &&
          schedule.end.isAfter(startDateTime) &&
          schedule.status != 'Cancelled');
    }).toList();
  }

  Map<String, dynamic> _getStudentProgress() {
    if (_selectedStudent == null) return {};

    final invoice = _billingController.invoices.firstWhereOrNull(
      (inv) => inv.studentId == _selectedStudent!.id,
    );

    if (invoice == null) return {};

    final completedLessons = _scheduleController.schedules
        .where((s) => s.studentId == _selectedStudent!.id && s.attended)
        .length;

    final progress = (completedLessons / invoice.lessons * 100).clamp(0, 100);

    return {
      'completedLessons': completedLessons,
      'totalLessons': invoice.lessons,
      'progress': progress,
      'remainingLessons': invoice.lessons - completedLessons,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInfoTab(),
                  _buildAdvancedTab(),
                  _buildSummaryTab(),
                ],
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.existingSchedule != null
                ? Icons.edit_calendar
                : Icons.add_circle_outline,
            color: Colors.white,
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingSchedule != null
                      ? 'Edit Schedule'
                      : 'Create New Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedStudent != null)
                  Text(
                    'for ${_selectedStudent!.fname} ${_selectedStudent!.lname}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[50],
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        tabs: [
          Tab(
            icon: Icon(Icons.info_outline),
            text: 'Basic Info',
          ),
          Tab(
            icon: Icon(Icons.settings),
            text: 'Advanced',
          ),
          Tab(
            icon: Icon(Icons.preview),
            text: 'Summary',
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_suggestions.isNotEmpty) _buildSuggestionsCard(),
            SizedBox(height: 16),
            _buildStudentSelection(),
            SizedBox(height: 16),
            _buildInstructorSelection(),
            SizedBox(height: 16),
            _buildDateTimeSelection(),
            SizedBox(height: 16),
            _buildCourseAndVehicleSelection(),
            if (_showConflicts && _conflicts.isNotEmpty) ...[
              SizedBox(height: 16),
              _buildConflictsCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  'Smart Suggestions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_suggestions['bestTimeSlots'] != null) ...[
              Text('Optimal time slots:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Text(
                (_suggestions['bestTimeSlots'] as List<String>).join(', '),
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
            ],
            if (_suggestions['recommendedDuration'] != null) ...[
              Text('Recommended duration:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Text(
                _suggestions['recommendedDuration'],
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildStudentAutocomplete(),
        ),
        if (_selectedStudent != null && _suggestions['studentProgress'] != null)
          _buildStudentProgressCard(),
      ],
    );
  }

  Widget _buildStudentAutocomplete() {
    final students = _userController.users
        .where((u) => u.role == 'student' && u.status == 'Active')
        .toList();

    return Autocomplete<User>(
      initialValue: _selectedStudent != null
          ? TextEditingValue(
              text: '${_selectedStudent!.fname} ${_selectedStudent!.lname}')
          : TextEditingValue.empty,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return students.take(5);
        }
        return students.where((student) => '${student.fname} ${student.lname}'
            .toLowerCase()
            .contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (user) => '${user.fname} ${user.lname}',
      onSelected: (user) {
        setState(() {
          _selectedStudent = user;
          _generateSuggestions();
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Search for student...',
            prefixIcon: Icon(Icons.person_search),
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16),
          ),
          validator: (value) {
            if (_selectedStudent == null) {
              return 'Please select a student';
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 300,
              constraints: BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final student = options.elementAt(index);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        '${student.fname[0]}${student.lname[0]}',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${student.fname} ${student.lname}'),
                    subtitle: Text(student.email),
                    onTap: () => onSelected(student),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentProgressCard() {
    final progress = _suggestions['studentProgress'] as Map<String, dynamic>;
    final progressPercent = progress['progress'] as double;

    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green[700], size: 16),
              SizedBox(width: 4),
              Text(
                'Student Progress',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressPercent >= 100 ? Colors.green : Colors.blue,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${progressPercent.toInt()}%',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '${progress['completedLessons']}/${progress['totalLessons']} lessons completed (${progress['remainingLessons']} remaining)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Instructor *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_availableInstructors.isNotEmpty) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_availableInstructors.length} available',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<User>(
              value: _selectedInstructor,
              isExpanded: true,
              hint: Text('Select instructor'),
              items: _availableInstructors.map((instructor) {
                final scheduleCount = _scheduleController.schedules
                    .where((s) =>
                        s.instructorId == instructor.id &&
                        s.start.isAfter(DateTime.now()) &&
                        s.start.isBefore(DateTime.now().add(Duration(days: 7))))
                    .length;

                return DropdownMenuItem<User>(
                  value: instructor,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          '${instructor.fname[0]}${instructor.lname[0]}',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${instructor.fname} ${instructor.lname}'),
                            Text(
                              '$scheduleCount lessons this week',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (instructor) {
                setState(() {
                  _selectedInstructor = instructor;
                  _checkForConflicts();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date & Time *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _selectDate,
                child: Container(
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
                        _selectedDate != null
                            ? DateFormat.yMMMd().format(_selectedDate!)
                            : 'Select date',
                        style: TextStyle(
                          color: _selectedDate != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _selectStartTime,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        _startTime != null
                            ? _startTime!.format(context)
                            : 'Start',
                        style: TextStyle(
                          color: _startTime != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _selectEndTime,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        _endTime != null ? _endTime!.format(context) : 'End',
                        style: TextStyle(
                          color: _endTime != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_startTime != null && _endTime != null) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Duration: ${_calculateDuration()}',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCourseAndVehicleSelection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Course *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Course>(
                        value: _selectedCourse,
                        isExpanded: true,
                        hint: Text('Select course'),
                        items: _courseController.courses
                            .where((c) => c.status == 'Active')
                            .map((course) => DropdownMenuItem<Course>(
                                  value: course,
                                  child:
                                      Text('${course.name} - \${course.price}'),
                                ))
                            .toList(),
                        onChanged: (course) {
                          setState(() => _selectedCourse = course);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Fleet>(
                        value: _selectedVehicle,
                        isExpanded: true,
                        hint: Text('Select vehicle'),
                        items: _availableVehicles
                            .map((vehicle) => DropdownMenuItem<Fleet>(
                                  value: vehicle,
                                  child: Text(
                                      '${vehicle.make} ${vehicle.model} (${vehicle.carPlate})'),
                                ))
                            .toList(),
                        onChanged: (vehicle) {
                          setState(() => _selectedVehicle = vehicle);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _buildClassTypeChip('Practical'),
                      SizedBox(width: 8),
                      _buildClassTypeChip('Theory'),
                      SizedBox(width: 8),
                      _buildClassTypeChip('Assessment'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClassTypeChip(String type) {
    final isSelected = _classType == type;
    return FilterChip(
      label: Text(type),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _classType = type);
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildConflictsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700]),
                SizedBox(width: 8),
                Text(
                  'Schedule Conflicts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._conflicts.map((conflict) {
              final student = _userController.users.firstWhereOrNull(
                (u) => u.id == conflict.studentId,
              );
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  '${student?.fname} ${student?.lname} - ${DateFormat.jm().format(conflict.start)} to ${DateFormat.jm().format(conflict.end)}',
                  style: TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecurrenceSection(),
          SizedBox(height: 20),
          _buildNotesSection(),
          SizedBox(height: 20),
          _buildRemindersSection(),
        ],
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              value: _isRecurring,
              onChanged: (value) => setState(() => _isRecurring = value),
            ),
            SizedBox(width: 8),
            Text(
              'Recurring Schedule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        if (_isRecurring) ...[
          SizedBox(height: 16),
          Text('Repeat Pattern:',
              style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildRecurrenceChip('daily'),
              _buildRecurrenceChip('weekly'),
              _buildRecurrenceChip('monthly'),
            ],
          ),
          SizedBox(height: 16),
          Text('End Date:', style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          GestureDetector(
            onTap: _selectRecurrenceEndDate,
            child: Container(
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
          ),
        ],
      ],
    );
  }

  Widget _buildRecurrenceChip(String pattern) {
    final isSelected = _recurrencePattern == pattern;
    return FilterChip(
      label: Text(pattern.capitalize!),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _recurrencePattern = pattern);
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        TextFormField(
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any additional notes or instructions...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) => _notes = value,
        ),
      ],
    );
  }

  Widget _buildRemindersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminders',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                CheckboxListTile(
                  title: Text('Send email reminder 24 hours before'),
                  value: true,
                  onChanged: (value) {},
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: Text('Send SMS reminder 2 hours before'),
                  value: false,
                  onChanged: (value) {},
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: Text('Notify instructor of assignment'),
                  value: true,
                  onChanged: (value) {},
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          _buildSummarySection(
              'Student',
              _selectedStudent != null
                  ? '${_selectedStudent!.fname} ${_selectedStudent!.lname}'
                  : 'Not selected'),
          _buildSummarySection(
              'Instructor',
              _selectedInstructor != null
                  ? '${_selectedInstructor!.fname} ${_selectedInstructor!.lname}'
                  : 'Not selected'),
          _buildSummarySection(
              'Date',
              _selectedDate != null
                  ? DateFormat.yMMMd().format(_selectedDate!)
                  : 'Not selected'),
          _buildSummarySection(
              'Time',
              _startTime != null && _endTime != null
                  ? '${_startTime!.format(context)} - ${_endTime!.format(context)}'
                  : 'Not selected'),
          _buildSummarySection('Duration', _calculateDuration()),
          _buildSummarySection(
              'Course', _selectedCourse?.name ?? 'Not selected'),
          _buildSummarySection(
              'Vehicle',
              _selectedVehicle != null
                  ? '${_selectedVehicle!.make} ${_selectedVehicle!.model}'
                  : 'Not assigned'),
          _buildSummarySection('Class Type', _classType),
          if (_isRecurring) ...[
            _buildSummarySection('Recurring', 'Yes - $_recurrencePattern'),
            if (_recurrenceEndDate != null)
              _buildSummarySection(
                  'Until', DateFormat.yMMMd().format(_recurrenceEndDate!)),
          ],
          if (_notes.isNotEmpty) _buildSummarySection('Notes', _notes),
        ],
      ),
    );
  }

  Widget _buildSummarySection(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveSchedule,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.existingSchedule != null
                      ? 'Update Schedule'
                      : 'Create Schedule'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _calculateDuration() {
    if (_startTime == null || _endTime == null) return 'Not set';

    final start =
        Duration(hours: _startTime!.hour, minutes: _startTime!.minute);
    final end = Duration(hours: _endTime!.hour, minutes: _endTime!.minute);
    final duration = end - start;

    if (duration.isNegative) return 'Invalid time range';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _generateSuggestions();
        _checkForConflicts();
      });
    }
  }

  void _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Auto-set end time to 1.5 hours later if not set
        if (_endTime == null) {
          final endDateTime = DateTime(2023, 1, 1, picked.hour, picked.minute)
              .add(Duration(hours: 1, minutes: 30));
          _endTime = TimeOfDay.fromDateTime(endDateTime);
        }
        _generateSuggestions();
        _checkForConflicts();
      });
    }
  }

  void _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay(hour: 10, minute: 30),
    );

    if (picked != null) {
      setState(() {
        _endTime = picked;
        _generateSuggestions();
        _checkForConflicts();
      });
    }
  }

  void _selectRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? DateTime.now().add(Duration(days: 30)),
      firstDate: _selectedDate ?? DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _recurrenceEndDate = picked);
    }
  }

  void _checkForConflicts() {
    if (_selectedInstructor == null ||
        _selectedDate == null ||
        _startTime == null ||
        _endTime == null) {
      return;
    }

    final startDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final endDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    _conflicts = _scheduleController.schedules.where((schedule) {
      if (widget.existingSchedule?.id == schedule.id)
        return false; // Exclude current schedule when editing

      return schedule.instructorId == _selectedInstructor!.id &&
          schedule.start.isBefore(endDateTime) &&
          schedule.end.isAfter(startDateTime) &&
          schedule.status != 'Cancelled';
    }).toList();

    setState(() {
      _showConflicts = _conflicts.isNotEmpty;
      _availableInstructors = _getAvailableInstructors();
      _availableVehicles = _getAvailableVehicles();
    });
  }

  List<Fleet> _getAvailableVehicles() {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      return _fleetController.fleet.toList();
    }

    final startDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final endDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    return _fleetController.fleet.where((vehicle) {
      return !_scheduleController.schedules.any((schedule) =>
          schedule.carId == vehicle.id &&
          schedule.start.isBefore(endDateTime) &&
          schedule.end.isAfter(startDateTime) &&
          schedule.status != 'Cancelled');
    }).toList();
  }

  void _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedStudent == null ||
        _selectedInstructor == null ||
        _selectedDate == null ||
        _startTime == null ||
        _endTime == null ||
        _selectedCourse == null) {
      Get.snackbar('Error', 'Please fill in all required fields');
      return;
    }

    if (_conflicts.isNotEmpty && widget.existingSchedule == null) {
      final confirmed = await _showConflictConfirmation();
      if (!confirmed) return;
    }

    setState(() => _isLoading = true);

    try {
      final startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      final endDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      final schedule = Schedule(
        id: widget.existingSchedule?.id,
        start: startDateTime,
        end: endDateTime,
        studentId: _selectedStudent!.id!,
        instructorId: _selectedInstructor!.id!,
        courseId: _selectedCourse!.id!,
        carId: _selectedVehicle?.id,
        classType: _classType,
        status: 'Scheduled',
        isRecurring: _isRecurring,
        recurrencePattern: _recurrencePattern,
        recurrenceEndDate: _recurrenceEndDate,
      );

      if (_isRecurring) {
        await _createRecurringSchedules(schedule);
      } else {
        await _scheduleController.addOrUpdateSchedule(schedule);
      }

      Navigator.of(context).pop();
      Get.snackbar(
        'Success',
        widget.existingSchedule != null
            ? 'Schedule updated successfully'
            : 'Schedule created successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save schedule: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConflictConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Schedule Conflicts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'The selected instructor has ${_conflicts.length} conflicting schedule(s):'),
                SizedBox(height: 8),
                ..._conflicts.take(3).map((conflict) {
                  final student = _userController.users.firstWhereOrNull(
                    (u) => u.id == conflict.studentId,
                  );
                  return Text(
                    '• ${student?.fname} ${student?.lname} - ${DateFormat.jm().format(conflict.start)} to ${DateFormat.jm().format(conflict.end)}',
                    style: TextStyle(fontSize: 14),
                  );
                }),
                if (_conflicts.length > 3)
                  Text('... and ${_conflicts.length - 3} more'),
                SizedBox(height: 12),
                Text(
                  'Do you want to proceed anyway?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Proceed'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _createRecurringSchedules(Schedule baseSchedule) async {
    if (_recurrencePattern == null || _recurrenceEndDate == null) {
      await _scheduleController.addOrUpdateSchedule(baseSchedule);
      return;
    }

    final schedules = <Schedule>[];
    var currentDate = baseSchedule.start;

    while (currentDate.isBefore(_recurrenceEndDate!) ||
        currentDate.isAtSameMomentAs(_recurrenceEndDate!)) {
      final schedule = baseSchedule.copyWith(
        id: null, // New schedule
        start: currentDate,
        end: DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          baseSchedule.end.hour,
          baseSchedule.end.minute,
        ),
      );

      schedules.add(schedule);

      // Calculate next occurrence
      switch (_recurrencePattern) {
        case 'daily':
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
            currentDate.hour,
            currentDate.minute,
          );
          break;
      }
    }

    // Save all schedules
    for (final schedule in schedules) {
      await _scheduleController.addOrUpdateSchedule(schedule);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
