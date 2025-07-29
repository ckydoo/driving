import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/course_controller.dart';
import '../models/course.dart';

class CourseFormDialog extends StatefulWidget {
  final Course? course;

  const CourseFormDialog({super.key, this.course});

  @override
  State<CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends State<CourseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController priceController;
  String? status;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.course?.name);
    priceController =
        TextEditingController(text: widget.course?.price.toString() ?? '');
    status = widget.course?.status ?? 'active';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.course == null ? 'Add Course' : 'Edit Course',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Course Name',
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue.shade800),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: 'Price',
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue.shade800),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (int.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: status,
                items: ['active', 'inactive'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value.capitalize!,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => status = value),
                decoration: InputDecoration(
                  labelText: 'Status',
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue.shade800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            widget.course == null ? 'Add' : 'Update',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final course = Course(
        id: widget.course?.id,
        name: nameController.text,
        price: int.parse(priceController.text),
        status: status!,
        createdAt: widget.course?.createdAt ?? DateTime.now(),
      );

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              widget.course == null ? 'Confirm Add' : 'Confirm Update',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to ${widget.course == null ? "add" : "update"} this course?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(), // Close the dialog
                child: Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Get.find<CourseController>()
                      .handleCourse(course, isUpdate: widget.course != null);
                  Navigator.of(context).pop(); // Close the dialog
                  Get.back(result: true); // Close the form dialog
                },
                child: Text(
                  widget.course == null ? 'Add' : 'Update',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    }
  }
}
