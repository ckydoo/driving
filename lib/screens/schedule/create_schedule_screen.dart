// lib/screens/schedule/single_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/schedule.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';

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

  // Form fields
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime =
      TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

  var _selectedStudent;
  var _selectedInstructor;
  var _selectedCourse;
  var _selectedVehicle;
  String _selectedClassType = 'Practical';
  String _selectedStatus = 'Scheduled';

  bool _isLoading = false;

  final List<String> _classTypes = ['Practical', 'Theory'];
  final List<String> _statusOptions = ['Scheduled', 'Confirmed', 'Pending'];

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingSchedule != null
            ? 'Edit Schedule'
            : 'Create Single Schedule'),
        backgroundColor: Colors.blue,
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
              _buildDateTimeSection(),
              SizedBox(height: 24),
              _buildParticipantsSection(),
              SizedBox(height: 24),
              _buildDetailsSection(),
              SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
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
            Text(
              'Date & Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Date Selection
            ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.blue),
              title: Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_selectedDate)),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: _selectDate,
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

            // Status
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
        onPressed: _isLoading ? null : _saveSchedule,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
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
                  Text('Saving...'),
                ],
              )
            : Text(
                widget.existingSchedule != null
                    ? 'Update Schedule'
                    : 'Create Schedule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
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

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate time selection
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

    if (endDateTime.isBefore(startDateTime) ||
        endDateTime.isAtSameMomentAs(startDateTime)) {
      Get.snackbar(
        'Invalid Time',
        'End time must be after start time',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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
        // Single schedule specific fields
        isRecurring: false,
        recurrencePattern: null,
        recurrenceEndDate: null,
      );

      await _scheduleController.addOrUpdateSchedule(schedule);

      Get.snackbar(
        'Success',
        widget.existingSchedule != null
            ? 'Schedule updated successfully'
            : 'Schedule created successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save schedule: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
