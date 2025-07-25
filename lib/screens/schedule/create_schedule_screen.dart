// lib/screens/schedule/create_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';
import '../../models/schedule.dart';
import '../../models/user.dart';
import '../../models/course.dart';
import '../../models/fleet.dart';

class CreateScheduleScreen extends StatefulWidget {
  final Schedule? existingSchedule; // For editing existing schedules

  const CreateScheduleScreen({Key? key, this.existingSchedule})
      : super(key: key);

  @override
  _CreateScheduleScreenState createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // Controllers
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final FleetController fleetController = Get.find<FleetController>();

  // Form state
  bool _isLoading = false;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  User? _selectedStudent;
  User? _selectedInstructor;
  Course? _selectedCourse;
  Fleet? _selectedVehicle;
  String _selectedClassType = 'Practical';
  String _selectedStatus = 'Scheduled';

  // Form controllers
  final TextEditingController _notesController = TextEditingController();

  // Class type options
  final List<String> _classTypes = [
    'Practical',
    'Theory',
    'Mock Test',
    'Road Test'
  ];
  final List<String> _statusOptions = ['Scheduled', 'Confirmed', 'Pending'];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.existingSchedule != null) {
      // Pre-populate form for editing
      final schedule = widget.existingSchedule!;
      _selectedDate = schedule.start;
      _startTime = TimeOfDay.fromDateTime(schedule.start);
      _endTime = TimeOfDay.fromDateTime(schedule.end);
      _selectedStudent = userController.users.firstWhereOrNull(
        (user) => user.id == schedule.studentId,
      );
      _selectedInstructor = userController.users.firstWhereOrNull(
        (user) => user.id == schedule.instructorId,
      );
      _selectedCourse = courseController.courses.firstWhereOrNull(
        (course) => course.id == schedule.courseId,
      );
      if (schedule.carId != null) {
        _selectedVehicle = fleetController.fleet.firstWhereOrNull(
          (vehicle) => vehicle.id == schedule.carId,
        );
      }
      _selectedClassType = schedule.classType;
      _selectedStatus = schedule.status;
    } else {
      // Set defaults for new schedule
      _selectedDate = DateTime.now().add(Duration(hours: 1));
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay(
        hour: (TimeOfDay.now().hour + 1) % 24,
        minute: TimeOfDay.now().minute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        title: Text(widget.existingSchedule != null
            ? 'Edit Schedule'
            : 'Create Schedule'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSchedule,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.existingSchedule != null ? 'Update' : 'Create',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
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
              _buildSectionHeader('Basic Information'),
              _buildBasicInfoSection(),
              SizedBox(height: 24),
              _buildSectionHeader('Date & Time'),
              _buildDateTimeSection(),
              SizedBox(height: 24),
              _buildSectionHeader('Participants'),
              _buildParticipantsSection(),
              SizedBox(height: 24),
              _buildSectionHeader('Additional Details'),
              _buildAdditionalDetailsSection(),
              SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Course Selection
            DropdownButtonFormField<Course>(
              decoration: InputDecoration(
                labelText: 'Course *',
                prefixIcon: Icon(Icons.school),
                border: OutlineInputBorder(),
              ),
              value: _selectedCourse,
              items: courseController.courses.map((course) {
                return DropdownMenuItem<Course>(
                  value: course,
                  child: Text(course.name),
                );
              }).toList(),
              onChanged: (course) {
                setState(() {
                  _selectedCourse = course;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a course';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Class Type Selection
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Class Type *',
                prefixIcon: Icon(Icons.class_),
                border: OutlineInputBorder(),
              ),
              value: _selectedClassType,
              items: _classTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (type) {
                setState(() {
                  _selectedClassType = type!;
                  // Auto-clear vehicle selection for theory classes
                  if (type == 'Theory') {
                    _selectedVehicle = null;
                  }
                });
              },
            ),

            SizedBox(height: 16),

            // Status Selection
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(),
              ),
              value: _selectedStatus,
              items: _statusOptions.map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (status) {
                setState(() {
                  _selectedStatus = status!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Date Selection
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date *',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedDate != null
                      ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!)
                      : 'Select Date',
                  style: TextStyle(
                    color: _selectedDate != null
                        ? Colors.black
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Time Selection Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Start Time *',
                        prefixIcon: Icon(Icons.access_time),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _startTime != null
                            ? _startTime!.format(context)
                            : 'Select Time',
                        style: TextStyle(
                          color: _startTime != null
                              ? Colors.black
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'End Time *',
                        prefixIcon: Icon(Icons.access_time_filled),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _endTime != null
                            ? _endTime!.format(context)
                            : 'Select Time',
                        style: TextStyle(
                          color: _endTime != null
                              ? Colors.black
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_getDurationText().isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: Colors.blue.shade700),
                    SizedBox(width: 8),
                    Text(
                      'Duration: ${_getDurationText()}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
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

  Widget _buildParticipantsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Student Selection
            DropdownButtonFormField<User>(
              decoration: InputDecoration(
                labelText: 'Student *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              value: _selectedStudent,
              items: userController.users
                  .where((user) => user.role.toLowerCase() == 'student')
                  .map((student) {
                return DropdownMenuItem<User>(
                  value: student,
                  child: Text('${student.fname} ${student.lname}'),
                );
              }).toList(),
              onChanged: (student) {
                setState(() {
                  _selectedStudent = student;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a student';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Instructor Selection
            DropdownButtonFormField<User>(
              decoration: InputDecoration(
                labelText: 'Instructor *',
                prefixIcon: Icon(Icons.school),
                border: OutlineInputBorder(),
              ),
              value: _selectedInstructor,
              items: userController.users
                  .where((user) => user.role.toLowerCase() == 'instructor')
                  .map((instructor) {
                return DropdownMenuItem<User>(
                  value: instructor,
                  child: Text('${instructor.fname} ${instructor.lname}'),
                );
              }).toList(),
              onChanged: (instructor) {
                setState(() {
                  _selectedInstructor = instructor;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select an instructor';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Vehicle Selection (only for practical classes)
            DropdownButtonFormField<Fleet>(
              decoration: InputDecoration(
                labelText: _selectedClassType == 'Theory'
                    ? 'Vehicle (Not Required)'
                    : 'Vehicle',
                prefixIcon: Icon(Icons.directions_car),
                border: OutlineInputBorder(),
                enabled: _selectedClassType != 'Theory',
              ),
              value: _selectedVehicle,
              items: fleetController.fleet.map((vehicle) {
                return DropdownMenuItem<Fleet>(
                  value: vehicle,
                  child: Text(
                      '${vehicle.make} ${vehicle.model} (${vehicle.carPlate})'),
                );
              }).toList(),
              onChanged: _selectedClassType == 'Theory'
                  ? null
                  : (vehicle) {
                      setState(() {
                        _selectedVehicle = vehicle;
                      });
                    },
              validator: (value) {
                if (_selectedClassType != 'Theory' && value == null) {
                  return 'Please select a vehicle for practical classes';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalDetailsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
                hintText: 'Add any additional notes or instructions...',
              ),
              maxLines: 3,
              maxLength: 500,
            ),

            SizedBox(height: 16),

            // Availability Check
            if (_selectedInstructor != null &&
                _selectedDate != null &&
                _startTime != null &&
                _endTime != null)
              _buildAvailabilityCheck(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityCheck() {
    return FutureBuilder<bool>(
      future: _checkAvailability(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Checking availability...'),
              ],
            ),
          );
        }

        final isAvailable = snapshot.data ?? false;
        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAvailable ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAvailable ? Icons.check_circle : Icons.error,
                color:
                    isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  isAvailable
                      ? 'Instructor is available at this time'
                      : 'Instructor is not available at this time',
                  style: TextStyle(
                    color: isAvailable
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
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
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Saving...'),
                    ],
                  )
                : Text(
                    widget.existingSchedule != null
                        ? 'Update Schedule'
                        : 'Create Schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Get.back(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Event handlers
  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ??
              TimeOfDay(hour: (TimeOfDay.now().hour + 1) % 24, minute: 0)),
    );

    if (time != null) {
      setState(() {
        if (isStartTime) {
          _startTime = time;
          // Auto-adjust end time to be 1 hour after start time
          if (_endTime == null || _endTime!.hour <= time.hour) {
            _endTime = TimeOfDay(
              hour: (time.hour + 1) % 24,
              minute: time.minute,
            );
          }
        } else {
          // Validate that end time is after start time
          if (_startTime != null) {
            final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
            final endMinutes = time.hour * 60 + time.minute;

            if (endMinutes <= startMinutes) {
              _scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text('End time must be after start time'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }
          _endTime = time;
        }
      });
    }
  }

  String _getDurationText() {
    if (_startTime == null || _endTime == null) return '';

    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    final durationMinutes = endMinutes - startMinutes;

    if (durationMinutes <= 0) return '';

    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  Future<bool> _checkAvailability() async {
    if (_selectedInstructor == null ||
        _selectedDate == null ||
        _startTime == null ||
        _endTime == null) {
      return false;
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

    return await scheduleController.checkAvailability(
      _selectedInstructor!.id!,
      startDateTime,
      endDateTime,
    );
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validations
    if (_selectedDate == null) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Please select a date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_startTime == null || _endTime == null) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Please select start and end times'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check availability
    final isAvailable = await _checkAvailability();
    if (!isAvailable) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Instructor is not available at the selected time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

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
        courseId: _selectedCourse!.id!,
        studentId: _selectedStudent!.id!,
        instructorId: _selectedInstructor!.id!,
        carId: _selectedVehicle?.id,
        classType: _selectedClassType,
        status: _selectedStatus,
        attended: widget.existingSchedule?.attended ?? false,
        lessonsCompleted: widget.existingSchedule?.lessonsCompleted ?? 0,
      );

      await scheduleController.addOrUpdateSchedule(schedule);

      Get.back(result: true);
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Failed to save schedule: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
