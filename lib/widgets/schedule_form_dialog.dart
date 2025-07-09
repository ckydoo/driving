import 'package:driving/controllers/billing_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/course_controller.dart';
import '../controllers/fleet_controller.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/user_controller.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../models/user.dart';

class ScheduleFormDialog extends StatefulWidget {
  const ScheduleFormDialog({Key? key}) : super(key: key);

  @override
  _ScheduleFormDialogState createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<ScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _startTime;
  late DateTime _endTime;
  User? _selectedStudent;
  User? _selectedInstructor;
  Course? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _endTime = _startTime.add(const Duration(hours: 1));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Schedule'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionTitle('Student'),
              _buildStudentAutocomplete(),
              const SizedBox(height: 16),
              _buildSectionTitle('Instructor'),
              _buildInstructorAutocomplete(),
              const SizedBox(height: 16),
              _buildSectionTitle('Vehicle'),
              _buildVehicleDisplay(),
              const SizedBox(height: 16),
              _buildSectionTitle('Course'),
              _buildCourseDropdown(),
              const SizedBox(height: 16),
              _buildSectionTitle('Time'),
              _buildTimePickers(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildStudentAutocomplete() {
    return Obx(() {
      final students = Get.find<UserController>()
          .users
          .where((user) =>
              user.role == 'student' &&
              user.status == 'Active') // ADDED STATUS CHECK
          .toList();

      return Autocomplete<User>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<User>.empty();
          }
          return students.where((user) => "${user.fname} ${user.lname}"
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase()));
        },
        displayStringForOption: (user) => "${user.fname} ${user.lname}",
        onSelected: (user) => setState(() => _selectedStudent = user),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Select Student',
              hintText: 'Enter student name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: _selectedStudent == null ? 'Required' : null,
            ),
            validator: (_) =>
                _selectedStudent == null ? 'Select student' : null,
          );
        },
      );
    });
  }

  Widget _buildInstructorAutocomplete() {
    return Obx(() {
      final instructors = Get.find<UserController>()
          .users
          .where((user) =>
              user.role == 'instructor' &&
              user.status == 'Active') // ADDED STATUS CHECK
          .toList();

      return Autocomplete<User>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<User>.empty();
          }
          return instructors.where((user) => "${user.fname} ${user.lname}"
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase()));
        },
        displayStringForOption: (user) => "${user.fname} ${user.lname}",
        onSelected: (user) => setState(() => _selectedInstructor = user),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Select Instructor',
              hintText: 'Enter instructor name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: _selectedInstructor == null ? 'Required' : null,
            ),
            validator: (_) =>
                _selectedInstructor == null ? 'Select instructor' : null,
          );
        },
      );
    });
  }

  Widget _buildVehicleDisplay() {
    return Obx(() {
      final vehicle = Get.find<FleetController>().fleet.firstWhereOrNull(
            (v) => v.instructor == _selectedInstructor?.id,
          );

      return _selectedInstructor != null
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Assigned Vehicle'),
                subtitle: vehicle != null
                    ? Text('${vehicle.make} ${vehicle.model}')
                    : const Text(
                        'No vehicle assigned',
                        style: TextStyle(color: Colors.red),
                      ),
              ),
            )
          : const SizedBox.shrink();
    });
  }

  Widget _buildCourseDropdown() {
    return _selectedStudent != null
        ? Obx(() {
            final courses = Get.find<CourseController>().courses;
            final billingController = Get.find<BillingController>();

            final courseItems = courses
                .where((course) {
                  final invoice = billingController.invoices.firstWhereOrNull(
                    (inv) =>
                        inv.studentId == _selectedStudent?.id &&
                        inv.courseId == course.id,
                  );
                  return invoice != null;
                })
                .map((course) => DropdownMenuItem<Course>(
                      value: course,
                      child: Text(course.name),
                    ))
                .toList();

            return DropdownButtonFormField<Course>(
              decoration: InputDecoration(
                labelText: 'Select Course',
                hintText: 'Choose a course',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: _selectedCourse == null ? 'Required' : null,
              ),
              value: _selectedCourse,
              items: courseItems.isNotEmpty
                  ? courseItems
                  : [
                      const DropdownMenuItem<Course>(
                        child: Text("No courses available for this student."),
                      )
                    ],
              onChanged: courseItems.isNotEmpty
                  ? (course) => setState(() => _selectedCourse = course)
                  : null,
              validator: (value) => value == null ? 'Select course' : null,
              //   disabledHint: Text("No courses available for this student."),
            );
          })
        : const SizedBox.shrink();
  }

  Widget _buildTimePickers() {
    return Column(
      children: [
        _buildTimePicker('Start Time', _startTime, (time) {
          setState(() => _startTime = time);
        }),
        const SizedBox(height: 12),
        _buildTimePicker('End Time', _endTime, (time) {
          setState(() => _endTime = time);
        }),
      ],
    );
  }

  Widget _buildTimePicker(
      String label, DateTime time, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () => _showDateTimePicker(time, onChanged),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              DateFormat.yMd().add_jm().format(time),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateTimePicker(
      DateTime initialTime, Function(DateTime) onChanged) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialTime),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        DateTime newDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          // Snap to 30-minute interval
          pickedTime.minute < 15
              ? 0
              : pickedTime.minute < 45
                  ? 30
                  : 0,
        );

        // Adjust hour if minutes are 45 or more
        if (pickedTime.minute >= 45) {
          newDateTime = newDateTime.add(Duration(hours: 1));
          if (newDateTime.hour == 0) {
            newDateTime = newDateTime.add(Duration(days: 1));
          }
        }
        onChanged(newDateTime);
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final fleetController = Get.find<FleetController>();
    final scheduleController = Get.find<ScheduleController>();

    final vehicle = fleetController.fleet.firstWhereOrNull(
      (v) => v.instructor == _selectedInstructor?.id,
    );

    if (vehicle == null) {
      Get.snackbar(
        'No Vehicle Assigned',
        'The selected instructor has no assigned vehicle.',
        backgroundColor: Colors.orange[100],
        colorText: Colors.black87,
      );
      return;
    }

    final available = await scheduleController.checkAvailability(
      _selectedInstructor!.id!,
      _startTime,
      _endTime,
    );

    if (!available) {
      Get.snackbar(
        'Time Conflict',
        'The instructor is unavailable at the selected time.',
        backgroundColor: Colors.orange[100],
        colorText: Colors.black87,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Schedule'),
            content: RichText(
              // Display student and instructor names in bold
              text: TextSpan(
                style: TextStyle(color: Colors.black87),
                children: [
                  TextSpan(text: 'Confirm session for '),
                  TextSpan(
                    text:
                        '${_selectedStudent!.fname} ${_selectedStudent!.lname}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' with '),
                  TextSpan(
                    text:
                        '${_selectedInstructor!.fname} ${_selectedInstructor!.lname}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' on '),
                  TextSpan(
                    text: DateFormat.yMd().add_jm().format(_startTime),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '?'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      scheduleController.addOrUpdateSchedule(Schedule(
        studentId: _selectedStudent!.id!,
        instructorId: _selectedInstructor!.id!,
        start: _startTime,
        end: _endTime,
        carId: vehicle.id,
        courseId: _selectedCourse!.id!,
        classType: _selectedCourse!.name,
        lessonsCompleted: 0,
      ));
      Get.back();
    }
  }
}
