// lib/screens/users/add_user_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/user_controller.dart';
import '../../models/user.dart';
import '../../controllers/navigation_controller.dart';

class AddUserScreen extends StatefulWidget {
  final String role;
  final User? user; // For editing existing user

  const AddUserScreen({
    Key? key,
    required this.role,
    this.user,
  }) : super(key: key);

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form controllers
  late final TextEditingController _fnameController;
  late final TextEditingController _lnameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _idNumberController;

  String? _status;
  String? _gender;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _fnameController = TextEditingController(text: widget.user?.fname ?? '');
    _lnameController = TextEditingController(text: widget.user?.lname ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController =
        TextEditingController(text: widget.user?.password ?? '');
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _addressController =
        TextEditingController(text: widget.user?.address ?? '');
    _idNumberController =
        TextEditingController(text: widget.user?.idnumber ?? '');

    if (widget.user != null) {
      _dateOfBirthController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(widget.user!.date_of_birth),
      );
      _selectedDate = widget.user!.date_of_birth;
      _status = widget.user!.status;
      _gender = widget.user!.gender;
    } else {
      _dateOfBirthController = TextEditingController();
      _status = 'Active';
      _gender = 'Male';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Fixed Sidebar (same as main layout)
          Container(
            width: 250,
            color: Colors.blueGrey[900],
            child: _buildSidebar(),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final navController = Get.find<NavigationController>();
    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      navController.navigateToPage(
                          widget.role == 'admin' ? 'users' : '${widget.role}s');
                      Get.back();
                    },
                  ),
                  Expanded(
                    child: Text(
                      widget.user == null
                          ? 'Add ${widget.role.capitalize}'
                          : 'Edit ${widget.role.capitalize}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(color: Colors.white54),

        // Steps indicator
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                _buildStepIndicator(0, 'Basic Info', Icons.person),
                _buildStepIndicator(1, 'Contact', Icons.contact_phone),
                _buildStepIndicator(2, 'Additional', Icons.info),
                _buildStepIndicator(3, 'Review', Icons.check_circle),

                Spacer(),

                // Tips section
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb,
                              color: Colors.yellow[300], size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Tips',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Use a valid email address\n• Phone number should include country code\n• ID number must be unique',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String title, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green
                  : isActive
                      ? Colors.blue
                      : Colors.grey[600],
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isActive || isCompleted ? Colors.white : Colors.white60,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Text(
              widget.user == null
                  ? 'Add New ${widget.role.capitalize}'
                  : 'Edit ${widget.role.capitalize}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            Spacer(),
            if (_isLoading)
              CircularProgressIndicator()
            else
              Row(
                children: [
                  TextButton(
                    onPressed: _goBack,
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _currentStep == 3 ? _submitForm : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_currentStep == 3
                        ? 'Save ${widget.role.capitalize}'
                        : 'Next'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoStep(),
                _buildContactStep(),
                _buildAdditionalStep(),
                _buildReviewStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          'Enter the ${widget.role}\'s basic personal information',
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _fnameController,
                label: 'First Name',
                icon: Icons.person,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _lnameController,
                label: 'Last Name',
                icon: Icons.person,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _idNumberController,
          label: 'ID Number',
          icon: Icons.badge,
          validator: (value) => value!.isEmpty ? 'Required' : null,
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                value: _gender,
                items: ['Male', 'Female', 'Other'],
                label: 'Gender',
                icon: Icons.person_outline,
                onChanged: (value) => setState(() => _gender = value),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildDatePickerField(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          'How can we reach this ${widget.role}?',
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: 32),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value!.isEmpty) return 'Required';
            if (!GetUtils.isEmail(value)) return 'Invalid Email';
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) => value!.isEmpty ? 'Required' : null,
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: 'Address',
          icon: Icons.location_on,
          maxLines: 3,
          validator: (value) => value!.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildAdditionalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          'Account settings and security',
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: 32),

        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock,
          obscureText: true,
          validator: (value) {
            if (value!.isEmpty) return 'Required';
            if (value.length < 6)
              return 'Password must be at least 6 characters';
            return null;
          },
        ),
        SizedBox(height: 16),

        _buildDropdownField(
          value: _status,
          items: ['Active', 'Inactive'],
          label: 'Status',
          icon: Icons.check_circle,
          onChanged: (value) => setState(() => _status = value),
        ),
        SizedBox(height: 24),

        // Role-specific fields
        if (widget.role == 'student') _buildStudentSpecificFields(),
        if (widget.role == 'instructor') _buildInstructorSpecificFields(),
      ],
    );
  }

  Widget _buildStudentSpecificFields() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.blue[600]),
              SizedBox(width: 8),
              Text(
                'Student Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Additional fields for student enrollment and course tracking will be available after saving.',
            style: TextStyle(color: Colors.blue[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorSpecificFields() {
    return Container(
      padding: EdgeInsets.all(16),
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
              Icon(Icons.drive_eta, color: Colors.green[600]),
              SizedBox(width: 8),
              Text(
                'Instructor Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Vehicle assignment and schedule management will be available after saving.',
            style: TextStyle(color: Colors.green[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Information',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          'Please review all information before saving',
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: 32),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildReviewSection('Basic Information', [
                  _buildReviewItem('Name',
                      '${_fnameController.text} ${_lnameController.text}'),
                  _buildReviewItem('ID Number', _idNumberController.text),
                  _buildReviewItem('Gender', _gender ?? ''),
                  _buildReviewItem(
                      'Date of Birth', _dateOfBirthController.text),
                ]),
                _buildReviewSection('Contact Information', [
                  _buildReviewItem('Email', _emailController.text),
                  _buildReviewItem('Phone', _phoneController.text),
                  _buildReviewItem('Address', _addressController.text),
                ]),
                _buildReviewSection('Account Settings', [
                  _buildReviewItem('Role', widget.role.capitalize!),
                  _buildReviewItem('Status', _status ?? ''),
                  _buildReviewItem(
                      'Password', '*' * (_passwordController.text.length)),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePickerField() {
    return TextFormField(
      controller: _dateOfBirthController,
      decoration: InputDecoration(
        labelText: 'Date of Birth',
        prefixIcon: Icon(Icons.calendar_today, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      readOnly: true,
      validator: (value) => value!.isEmpty ? 'Required' : null,
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ??
              DateTime.now().subtract(Duration(days: 6570)), // 18 years ago
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
            _dateOfBirthController.text =
                DateFormat('yyyy-MM-dd').format(picked);
          });
        }
      },
    );
  }

  Widget _buildReviewSection(String title, List<Widget> items) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        // Basic Info validation
        if (_fnameController.text.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'First name is required',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        if (_lnameController.text.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'Last name is required',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        if (_idNumberController.text.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'ID number is required',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        if (_selectedDate == null) {
          Get.snackbar(
            'Validation Error',
            'Date of birth is required',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        return true;

      case 1:
        // Contact validation
        if (_emailController.text.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'Email is required',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        if (!GetUtils.isEmail(_emailController.text)) {
          Get.snackbar(
            'Validation Error',
            'Please enter a valid email address',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        if (_phoneController.text.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'Phone number is required',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        if (_addressController.text.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'Address is required',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        return true;

      case 2:
        // Additional info validation
        if (_passwordController.text.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'Password is required',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        if (_passwordController.text.length < 6) {
          Get.snackbar(
            'Validation Error',
            'Password must be at least 6 characters long',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      _previousStep();
    } else {
      final navController = Get.find<NavigationController>();
      navController
          .navigateToPage(widget.role == 'admin' ? 'users' : '${widget.role}s');
      Get.back();
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userController = Get.find<UserController>();

      // Check for existing user by phone or ID number (if not editing the same user)
      final existingUser = userController.users.firstWhereOrNull(
        (user) =>
            (user.phone == _phoneController.text ||
                user.idnumber == _idNumberController.text) &&
            user.id != widget.user?.id,
      );

      if (existingUser != null) {
        Get.snackbar(
          'Error',
          'User with this Phone or ID Number already exists.',
          backgroundColor: Colors.red[100],
          colorText: Colors.red[800],
          icon: Icon(Icons.error, color: Colors.red),
          duration: Duration(seconds: 4),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final user = User(
        id: widget.user?.id,
        fname: _fnameController.text,
        lname: _lnameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: widget.role,
        status: _status!,
        gender: _gender!,
        phone: _phoneController.text,
        address: _addressController.text,
        date_of_birth: _selectedDate!,
        created_at: widget.user?.created_at ?? DateTime.now(),
        idnumber: _idNumberController.text,
      );

      await userController.handleUser(user, isUpdate: widget.user != null);

      // Show success dialog
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Success!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.role.capitalize} ${widget.user == null ? 'added' : 'updated'} successfully!',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.green[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_fnameController.text} ${_lnameController.text} has been ${widget.user == null ? 'added' : 'updated'} as a ${widget.role}.',
                        style: TextStyle(color: Colors.green[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back(); // Close dialog
                _goBackToUserList();
              },
              child: Text('View ${widget.role.capitalize} List'),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back(); // Close dialog
                _resetFormForNewUser();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Add Another ${widget.role.capitalize}'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save ${widget.role}: ${e.toString()}',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        icon: Icon(Icons.error, color: Colors.red),
        duration: Duration(seconds: 5),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goBackToUserList() {
    final navController = Get.find<NavigationController>();
    navController
        .navigateToPage(widget.role == 'admin' ? 'users' : '${widget.role}s');
    Get.back();
  }

  void _resetFormForNewUser() {
    // Clear all form fields for new user
    _fnameController.clear();
    _lnameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _phoneController.clear();
    _addressController.clear();
    _dateOfBirthController.clear();
    _idNumberController.clear();

    setState(() {
      _currentStep = 0;
      _selectedDate = null;
      _status = 'Active';
      _gender = 'Male';
    });

    _pageController.animateToPage(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fnameController.dispose();
    _lnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dateOfBirthController.dispose();
    _idNumberController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
