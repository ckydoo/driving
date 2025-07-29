import 'package:driving/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:get/get.dart';
import '../../controllers/fleet_controller.dart';
import '../../models/fleet.dart';
import '../../models/user.dart';

class FleetFormDialog extends StatefulWidget {
  final Fleet? vehicle;
  const FleetFormDialog({super.key, this.vehicle});

  @override
  State<FleetFormDialog> createState() => _FleetFormDialogState();
}

class _FleetFormDialogState extends State<FleetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _carPlate;
  late String _make;
  late String _model;
  late String _modelYear;
  int? _selectedInstructorId;
  List<User> _availableInstructors = [];
  final List<int> _years = List.generate(31, (index) => 2000 + index);

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadInstructors();
  }

  void _initializeFields() {
    _carPlate = widget.vehicle?.carPlate ?? '';
    _make = widget.vehicle?.make ?? '';
    _model = widget.vehicle?.model ?? '';
    _modelYear = widget.vehicle?.modelYear ?? DateTime.now().year.toString();
    _selectedInstructorId = widget.vehicle?.instructor;
  }

  Future<void> _loadInstructors() async {
    final fleetController = Get.find<FleetController>();
    final userController = Get.find<UserController>();

    final allInstructors = userController.users
        .where((user) => user.role.toLowerCase() == 'instructor')
        .toList();

    final assignedIds = fleetController.fleet
        .where((v) => v.id != widget.vehicle?.id)
        .map((v) => v.instructor)
        .toSet();

    setState(() {
      _availableInstructors = allInstructors.where((i) {
        return !assignedIds.contains(i.id);
      }).toList();
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _selectedInstructorId != null) {
      _formKey.currentState!.save();
      _showConfirmationDialog();
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            widget.vehicle == null ? 'Add Vehicle' : 'Update Vehicle',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          content: Text(
            widget.vehicle == null
                ? 'Are you sure you want to add this vehicle?'
                : 'Are you sure you want to update this vehicle?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _saveVehicle();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _saveVehicle() {
    final vehicle = Fleet(
      id: widget.vehicle?.id,
      carPlate: _carPlate,
      make: _make,
      model: _model,
      modelYear: _modelYear,
      instructor: _selectedInstructorId!,
    );
    Get.find<FleetController>().handleFleet(
      vehicle,
      isUpdate: widget.vehicle != null,
    );
    Get.back(result: true); // Close the dialog and return true
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle',
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
                initialValue: _carPlate,
                decoration: InputDecoration(
                  labelText: 'License Plate (ABC1234)',
                  hintText: 'ABC1234',
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
                maxLength: 7,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  UpperCaseTextFormatter(),
                  LicensePlateFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'License plate is required';
                  }
                  if (value.length != 7) {
                    return 'License plate must be 7 characters';
                  }
                  if (!RegExp(r'^[A-Z]{3}[0-9]{4}$').hasMatch(value)) {
                    return 'Format: ABC1234 (3 letters, 4 numbers)';
                  }
                  return null;
                },
                onSaved: (value) => _carPlate = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _make,
                decoration: InputDecoration(
                  labelText: 'Make',
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
                onSaved: (value) => _make = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _model,
                decoration: InputDecoration(
                  labelText: 'Model',
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
                onSaved: (value) => _model = value!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: int.tryParse(_modelYear),
                decoration: InputDecoration(
                  labelText: 'Model Year',
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
                items: _years.map((year) {
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
                onChanged: (value) => _modelYear = value.toString(),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedInstructorId,
                decoration: InputDecoration(
                  labelText: 'Instructor',
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
                items: _availableInstructors.isEmpty
                    ? [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No available instructors'),
                        )
                      ]
                    : _availableInstructors.map((instructor) {
                        return DropdownMenuItem<int>(
                          value: instructor.id,
                          child:
                              Text('${instructor.fname} ${instructor.lname}'),
                        );
                      }).toList(),
                onChanged: _availableInstructors.isEmpty
                    ? null
                    : (value) => setState(() => _selectedInstructorId = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              if (_availableInstructors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'All instructors are already assigned to vehicles',
                    style: TextStyle(color: Colors.red.shade700),
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
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            widget.vehicle == null ? 'Add' : 'Update',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// Custom formatter to enforce uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// Custom formatter to enforce license plate format
class LicensePlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty or partial input during typing
    if (text.isEmpty) {
      return newValue;
    }

    // Ensure the format is correct as user types
    String formattedText = '';
    // ignore: unused_local_variable
    int letterCount = 0;
    // ignore: unused_local_variable
    int numberCount = 0;

    for (int i = 0; i < text.length && i < 7; i++) {
      final char = text[i];

      if (i < 3) {
        // First 3 positions should be letters
        if (RegExp(r'[A-Za-z]').hasMatch(char)) {
          formattedText += char.toUpperCase();
          letterCount++;
        } else {
          // If user tries to input number in letter position, reject it
          break;
        }
      } else {
        // Last 4 positions should be numbers
        if (RegExp(r'[0-9]').hasMatch(char)) {
          formattedText += char;
          numberCount++;
        } else {
          // If user tries to input letter in number position, reject it
          break;
        }
      }
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
