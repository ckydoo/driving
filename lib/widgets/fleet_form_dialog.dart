import 'package:driving/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _FleetFormDialogState extends State<FleetFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _carPlateController;
  late TextEditingController _makeController;
  late TextEditingController _modelController;
  String _modelYear = '';
  int? _selectedInstructorId;
  List<User> _availableInstructors = [];
  final List<int> _years = List.generate(31, (index) => 2000 + index);
  bool _isLoading = false;
  bool _isLoadingInstructors = true;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadInstructors();

    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _carPlateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _initializeFields() {
    _carPlateController =
        TextEditingController(text: widget.vehicle?.carPlate ?? '');
    _makeController = TextEditingController(text: widget.vehicle?.make ?? '');
    _modelController = TextEditingController(text: widget.vehicle?.model ?? '');
    _modelYear = widget.vehicle?.modelYear ?? DateTime.now().year.toString();
    _selectedInstructorId = widget.vehicle?.instructor;
  }

  Future<void> _loadInstructors() async {
    try {
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
        _isLoadingInstructors = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingInstructors = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load instructors: ${e.toString()}',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: FadeTransition(
        opacity: _slideAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.of(context).size.height * 0.8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade50,
                  Colors.white,
                  Colors.green.shade50,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Flexible(child: _buildForm()),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.vehicle == null ? Icons.add_road : Icons.edit_road,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.vehicle == null ? 'Add New Vehicle' : 'Edit Vehicle',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.vehicle == null
                      ? 'Register a new vehicle to your fleet'
                      : 'Update vehicle information',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Get.back(),
            icon: Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildLicensePlateField(),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildMakeField()),
                  SizedBox(width: 16),
                  Expanded(child: _buildModelField()),
                ],
              ),
              SizedBox(height: 20),
              _buildYearField(),
              SizedBox(height: 20),
              _buildInstructorField(),
              if (_availableInstructors.isEmpty && !_isLoadingInstructors)
                _buildNoInstructorsWarning(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicensePlateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'License Plate',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _carPlateController,
          decoration: InputDecoration(
            hintText: 'ABC1234',
            prefixIcon: Container(
              margin: EdgeInsets.all(8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.confirmation_number,
                  color: Colors.green.shade700, size: 20),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade600, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            counterText: '${_carPlateController.text.length}/7',
          ),
          maxLength: 7,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
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
          onChanged: (value) => setState(() {}), // Update counter
        ),
        SizedBox(height: 4),
        Text(
          'Format: 3 letters followed by 4 numbers (e.g., ABC1234)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMakeField() {
    return _buildTextField(
      controller: _makeController,
      label: 'Make',
      hint: 'Toyota, Honda, etc.',
      icon: Icons.branding_watermark,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Make is required';
        }
        if (value.length < 2) {
          return 'Make must be at least 2 characters';
        }
        return null;
      },
    );
  }

  Widget _buildModelField() {
    return _buildTextField(
      controller: _modelController,
      label: 'Model',
      hint: 'Corolla, Civic, etc.',
      icon: Icons.directions_car,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Model is required';
        }
        if (value.length < 2) {
          return 'Model must be at least 2 characters';
        }
        return null;
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.green.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade600, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: validator,
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _buildYearField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model Year',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: int.tryParse(_modelYear),
          decoration: InputDecoration(
            prefixIcon:
                Icon(Icons.calendar_today, color: Colors.green.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade600, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: _years.reversed.map((year) {
            return DropdownMenuItem<int>(
              value: year,
              child: Text(year.toString()),
            );
          }).toList(),
          onChanged: (value) => setState(() => _modelYear = value.toString()),
          validator: (value) =>
              value == null ? 'Please select model year' : null,
        ),
      ],
    );
  }

  Widget _buildInstructorField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assigned Instructor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        if (_isLoadingInstructors)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                  ),
                ),
                SizedBox(width: 12),
                Text('Loading instructors...'),
              ],
            ),
          )
        else if (_availableInstructors.isEmpty)
          _buildEmptyInstructorField()
        else
          _buildSearchableInstructorDropdown(),
      ],
    );
  }

  Widget _buildEmptyInstructorField() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Icon(Icons.person_off, color: Colors.grey.shade400),
          SizedBox(width: 12),
          Text(
            'No available instructors',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchableInstructorDropdown() {
    final selectedInstructor = _selectedInstructorId != null
        ? _availableInstructors.firstWhere(
            (instructor) => instructor.id == _selectedInstructorId,
            orElse: () => _availableInstructors.first,
          )
        : null;

    return Autocomplete<User>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _availableInstructors;
        }
        return _availableInstructors.where((User instructor) {
          final fullName =
              '${instructor.fname} ${instructor.lname}'.toLowerCase();
          final searchTerm = textEditingValue.text.toLowerCase();
          return fullName.contains(searchTerm);
        });
      },
      displayStringForOption: (User instructor) =>
          '${instructor.fname} ${instructor.lname}',
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldTextEditingController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Set initial value if instructor is selected
        if (selectedInstructor != null &&
            fieldTextEditingController.text.isEmpty) {
          fieldTextEditingController.text =
              '${selectedInstructor.fname} ${selectedInstructor.lname}';
        }

        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            hintText: 'Search for an instructor...',
            prefixIcon: Icon(Icons.person_search, color: Colors.green.shade600),
            suffixIcon: fieldTextEditingController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade600),
                    onPressed: () {
                      fieldTextEditingController.clear();
                      setState(() {
                        _selectedInstructorId = null;
                      });
                    },
                  )
                : Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade600, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (_selectedInstructorId == null) {
              return 'Please select an instructor';
            }
            return null;
          },
          onTap: () {
            // Show all options when field is tapped
            if (fieldTextEditingController.text.isEmpty) {
              fieldTextEditingController.text = ' ';
              fieldTextEditingController.selection =
                  TextSelection.collapsed(offset: 0);
            }
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<User> onSelected,
        Iterable<User> options,
      ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              constraints: BoxConstraints(maxHeight: 200, maxWidth: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final User instructor = options.elementAt(index);
                  final bool isSelected =
                      _selectedInstructorId == instructor.id;

                  return InkWell(
                    onTap: () => onSelected(instructor),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green.shade50 : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected
                                ? Colors.green.shade200
                                : Colors.green.shade100,
                            child: Text(
                              instructor.fname[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${instructor.fname} ${instructor.lname}',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.green.shade800
                                        : Colors.black87,
                                  ),
                                ),
                                if (instructor.email.isNotEmpty)
                                  Text(
                                    instructor.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (User instructor) {
        setState(() {
          _selectedInstructorId = instructor.id;
        });
      },
    );
  }

  Widget _buildNoInstructorsWarning() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade600),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Available Instructors',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All instructors are already assigned to vehicles. Add new instructors or unassign existing ones.',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isLoading ? null : () => Get.back(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed:
                  _isLoading || _availableInstructors.isEmpty ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.vehicle == null ? 'Add Vehicle' : 'Update Vehicle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() || _selectedInstructorId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vehicle = Fleet(
        id: widget.vehicle?.id,
        carPlate: _carPlateController.text.trim(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        modelYear: _modelYear,
        instructor: _selectedInstructorId!,
      );

      await Get.find<FleetController>().handleFleet(
        vehicle,
        isUpdate: widget.vehicle != null,
      );

      // Close the dialog first
      Get.back(result: true);

      // Show success feedback after dialog is closed
      await Future.delayed(const Duration(milliseconds: 100));

      Get.snackbar(
        widget.vehicle == null ? 'Vehicle Added!' : 'Vehicle Updated!',
        widget.vehicle == null
            ? 'Vehicle ${vehicle.carPlate} has been added to your fleet'
            : 'Vehicle ${vehicle.carPlate} has been updated successfully',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to ${widget.vehicle == null ? "add" : "update"} vehicle: ${e.toString()}',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Enhanced formatters
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

class LicensePlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    String formattedText = '';
    for (int i = 0; i < text.length && i < 7; i++) {
      final char = text[i];

      if (i < 3) {
        // First 3 positions should be letters
        if (RegExp(r'[A-Za-z]').hasMatch(char)) {
          formattedText += char.toUpperCase();
        } else {
          break;
        }
      } else {
        // Last 4 positions should be numbers
        if (RegExp(r'[0-9]').hasMatch(char)) {
          formattedText += char;
        } else {
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
