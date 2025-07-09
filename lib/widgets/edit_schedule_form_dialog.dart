import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../models/schedule.dart';

class EditScheduleScreen extends StatefulWidget {
  final Schedule schedule;

  const EditScheduleScreen({Key? key, required this.schedule})
      : super(key: key);

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseController = Get.find<CourseController>();
  final _fleetController = Get.find<FleetController>();
  final _scheduleController = Get.find<ScheduleController>();

  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late int _selectedCourseId;
  late int _selectedFleetId;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(widget.schedule.start));
    _timeController = TextEditingController(
        text: DateFormat('HH:mm').format(widget.schedule.start));
    _selectedCourseId = widget.schedule.courseId;
    _selectedFleetId = widget.schedule.carId ?? 0;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Schedule'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: 'Date'),
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dateController.text =
                          DateFormat('yyyy-MM-dd').format(pickedDate);
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a date';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _timeController,
                decoration: const InputDecoration(labelText: 'Time'),
                onTap: () async {
                  final TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _timeController.text = pickedTime.format(context);
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a time';
                  }
                  return null;
                },
              ),
              Obx(() {
                final courses = _courseController.courses;
                if (courses.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Course'),
                  value: _selectedCourseId,
                  onChanged: (value) {
                    setState(() {
                      _selectedCourseId = value!;
                    });
                  },
                  items: courses.map((course) {
                    return DropdownMenuItem(
                      value: course.id,
                      child: Text(course.name),
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a course';
                    }
                    return null;
                  },
                );
              }),
              Obx(() {
                final fleets = _fleetController.fleet;
                if (fleets.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Fleet'),
                  value: _selectedFleetId,
                  onChanged: (value) {
                    setState(() {
                      _selectedFleetId = value!;
                    });
                  },
                  items: fleets.map((fleet) {
                    return DropdownMenuItem(
                      value: fleet.id,
                      child: Text(fleet.carPlate),
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a fleet';
                    }
                    return null;
                  },
                );
              }),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final updatedSchedule = Schedule(
                      id: widget.schedule.id,
                      start: DateTime.parse(
                          '${_dateController.text} ${_timeController.text}'),
                      courseId: _selectedCourseId,
                      carId: _selectedFleetId,
                      end: widget.schedule.end,
                      studentId: widget.schedule.studentId,
                      instructorId: widget.schedule.instructorId,
                      classType: widget.schedule.classType,
                      lessonsCompleted: widget.schedule.lessonsCompleted,
                    );
                    _scheduleController.addOrUpdateSchedule(updatedSchedule);
                    Get.back();
                  }
                },
                child: const Text('Update Schedule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
