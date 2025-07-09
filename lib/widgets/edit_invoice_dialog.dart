import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/models/invoice.dart';

class EditInvoiceDialog extends StatefulWidget {
  final Invoice invoice;

  const EditInvoiceDialog({Key? key, required this.invoice}) : super(key: key);

  @override
  _EditInvoiceDialogState createState() => _EditInvoiceDialogState();
}

class _EditInvoiceDialogState extends State<EditInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _courseIdController;
  late TextEditingController _lessonsController;
  late TextEditingController _pricePerLessonController;
  late TextEditingController _dueDateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _courseIdController =
        TextEditingController(text: widget.invoice.courseId.toString());
    _lessonsController =
        TextEditingController(text: widget.invoice.lessons.toString());
    _pricePerLessonController =
        TextEditingController(text: widget.invoice.pricePerLesson.toString());
    _dueDateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(widget.invoice.dueDate));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Edit Invoice',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Course ID Field
              TextFormField(
                controller: _courseIdController,
                decoration: InputDecoration(
                  labelText: 'Course ID',
                  hintText: 'Enter course ID',
                  prefixIcon: const Icon(Icons.school, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Course ID is required';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Lessons Field
              TextFormField(
                controller: _lessonsController,
                decoration: InputDecoration(
                  labelText: 'Lessons',
                  hintText: 'Enter number of lessons',
                  prefixIcon: const Icon(Icons.list, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lessons are required';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price Per Lesson Field
              TextFormField(
                controller: _pricePerLessonController,
                decoration: InputDecoration(
                  labelText: 'Price/Lesson',
                  hintText: 'Enter price per lesson',
                  prefixIcon:
                      const Icon(Icons.attach_money, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Price is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Due Date Field
              TextFormField(
                controller: _dueDateController,
                decoration: InputDecoration(
                  labelText: 'Due Date',
                  hintText: 'Select due date',
                  prefixIcon:
                      const Icon(Icons.calendar_today, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: widget.invoice.dueDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    _dueDateController.text =
                        DateFormat('yyyy-MM-dd').format(pickedDate);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Due date is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _isSaving = true);
                    final billingController = Get.find<BillingController>();
                    final updatedInvoiceData = {
                      'id': widget.invoice.id,
                      'courseId': int.parse(_courseIdController.text),
                      'lessons': int.parse(_lessonsController.text),
                      'pricePerLesson':
                          double.parse(_pricePerLessonController.text),
                      'dueDate': _dueDateController.text,
                      // ... other fields
                    };
                    await billingController.updateInvoice(updatedInvoiceData);
                    setState(() => _isSaving = false);
                    Navigator.of(context).pop(); // Close the dialog
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
