import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/user_controller.dart';
import '../../models/user.dart';

class UserFormDialog extends StatefulWidget {
  final User? user;
  final String role;

  const UserFormDialog({Key? key, this.user, required this.role})
      : super(key: key);

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController fnameController;
  late final TextEditingController lnameController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController dateOfBirthController;
  late final TextEditingController idNumberController;
  String? status;
  String? gender;

  @override
  void initState() {
    super.initState();
    fnameController = TextEditingController(text: widget.user?.fname);
    lnameController = TextEditingController(text: widget.user?.lname);
    emailController = TextEditingController(text: widget.user?.email);
    passwordController = TextEditingController(text: widget.user?.password);
    phoneController = TextEditingController(text: widget.user?.phone);
    addressController = TextEditingController(text: widget.user?.address);
    dateOfBirthController = TextEditingController(
        text: widget.user?.date_of_birth != null
            ? DateFormat('yyyy-MM-dd').format(widget.user!.date_of_birth)
            : '');
    idNumberController = TextEditingController(text: widget.user?.idnumber);
    status = widget.user?.status ?? 'Active';
    gender = widget.user?.gender ?? 'Male';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.user == null ? 'Add ${widget.role}' : 'Edit ${widget.role}',
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
              _buildTextField(fnameController, 'First Name'),
              _buildTextField(lnameController, 'Last Name'),
              _buildTextField(idNumberController, 'ID Number'),
              _buildTextField(emailController, 'Email', isEmail: true),
              _buildTextField(passwordController, 'Password', isPassword: true),
              _buildTextField(phoneController, 'Phone', isPhone: true),
              _buildTextField(addressController, 'Address'),
              _buildDatePickerField(),
              _buildDropdownField(
                value: gender,
                items: ['Male', 'Female'],
                label: 'Gender',
                onChanged: (value) => gender = value,
              ),
              _buildDropdownField(
                value: status,
                items: ['Active', 'Inactive'],
                label: 'Status',
                onChanged: (value) => status = value,
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
            widget.user == null ? 'Add' : 'Update',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isEmail = false, bool isPassword = false, bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
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
        obscureText: isPassword,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Required';
          }
          if (isEmail && !GetUtils.isEmail(value)) {
            return 'Invalid Email';
          }
          if (isPhone && !GetUtils.isPhoneNumber(value)) {
            return 'Invalid Phone Number';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePickerField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: dateOfBirthController,
        decoration: InputDecoration(
          labelText: 'Date of Birth',
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
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() {
              dateOfBirthController.text =
                  DateFormat('yyyy-MM-dd').format(picked);
            });
          }
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
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
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _showConfirmationDialog();
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            widget.user == null
                ? 'Add ${widget.role}'
                : 'Update ${widget.role}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          content: Text(
            widget.user == null
                ? 'Are you sure you want to add this user?'
                : 'Are you sure you want to update this user?',
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
                _saveUser();
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

  void _saveUser() async {
    final userController = Get.find<UserController>();

    // Check for existing user by phone or ID number
    final existingUser = userController.users.firstWhereOrNull(
      (user) =>
          user.phone == phoneController.text ||
          user.idnumber == idNumberController.text,
    );

    if (existingUser != null && existingUser.id != widget.user?.id) {
      // If a user with the same phone or ID exists and it's not the same user being edited
      Get.snackbar(
        'Error',
        'User with this Phone or ID Number already exists.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return; // Stop the submission
    }

    final user = User(
      id: widget.user?.id,
      fname: fnameController.text,
      lname: lnameController.text,
      email: emailController.text,
      password: passwordController.text,
      role: widget.role,
      status: status!,
      gender: gender!,
      phone: phoneController.text,
      address: addressController.text,
      date_of_birth: DateFormat('yyyy-MM-dd').parse(dateOfBirthController.text),
      created_at: widget.user?.created_at ?? DateTime.now(),
      idnumber: idNumberController.text,
    );

    await userController.handleUser(user, isUpdate: widget.user != null);
    Get.back(result: true); // Close the dialog and return true
  }
}
