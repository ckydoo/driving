// lib/screens/users/add_user_screen.dart
import 'dart:math';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/invoice.dart';
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
  Course? _selectedCourse;
  final TextEditingController _lessonsController =
      TextEditingController(text: '1'); // Default 10 lessons
  DateTime? _invoiceDueDate =
      DateTime.now().add(Duration(days: 5)); // Default 30 days

  void _updateBillingPreview() {
    setState(() {
      // Trigger rebuild to update preview
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  // Add this method to generate random 8-digit password
  String _generateRandomPassword() {
    final random = Random();
    String password = '';
    for (int i = 0; i < 8; i++) {
      password += random.nextInt(10).toString();
    }
    return password;
  }

  void _initializeControllers() {
    _fnameController = TextEditingController(text: widget.user?.fname ?? '');
    _lnameController = TextEditingController(text: widget.user?.lname ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');

    // Auto-generate password for new users, keep existing for edits
    _passwordController = TextEditingController(
        text: widget.user?.password ?? _generateRandomPassword());

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
                        '• Use a valid email address\n• Phone number should be 10 Numbers\n• ID number must be unique',
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
                    child: Text('Previous'),
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
                items: ['Male', 'Female'],
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
          validator: (value) {
            if (value!.isEmpty) return 'Required';
            // Remove any non-digit characters for validation
            String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
            if (digitsOnly.length > 15) {
              return 'Phone number cannot exceed 15 digits';
            }
            if (digitsOnly.length < 10) {
              return 'Phone number must be at least 10 digits';
            }
            return null;
          },
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
    return SingleChildScrollView(
      child: Column(
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
              if (value.length != 8) return 'Password must be exactly 8 digits';
              if (!RegExp(r'^\d{8}$').hasMatch(value)) {
                return 'Password must contain only 8 digits';
              }
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

          // Role-specific fields - only show billing for NEW students
          if (widget.role == 'student' && widget.user == null)
            _buildStudentSpecificFields(),
          if (widget.role == 'student' && widget.user != null)
            _buildEditingStudentNote(),
          if (widget.role == 'instructor') _buildInstructorSpecificFields(),

          SizedBox(height: 20),
        ],
      ),
    );
  }

// Add this new method to show a note when editing students
  Widget _buildEditingStudentNote() {
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
              Icon(Icons.info_outline, color: Colors.blue[600]),
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
            'Course enrollment and billing information can be managed separately in the Billing section.',
            style: TextStyle(color: Colors.blue[700]),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blue[600], size: 16),
              SizedBox(width: 6),
              Text(
                'View invoices and billing history in the Billing module',
                style: TextStyle(
                  color: Colors.blue[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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

                // Add invoice preview ONLY for NEW students with course selection
                if (widget.role == 'student' &&
                    widget.user == null && // Only for new students
                    _selectedCourse != null &&
                    _lessonsController.text.isNotEmpty)
                  _buildInvoicePreviewSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicePreviewSection() {
    final lessons = int.tryParse(_lessonsController.text) ?? 0;
    final pricePerLesson = _selectedCourse?.price ?? 0.0;
    final totalAmount = lessons * pricePerLesson;

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.green[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Invoice to be Created',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Text(
                  'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Invoice details
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildInvoiceReviewItem('Course', _selectedCourse?.name ?? ''),
                _buildInvoiceReviewItem('Price per Lesson',
                    '\$${pricePerLesson.toStringAsFixed(2)}'),
                _buildInvoiceReviewItem('Number of Lessons', '$lessons'),
                _buildInvoiceReviewItem(
                    'Due Date',
                    _invoiceDueDate != null
                        ? DateFormat('MMM dd, yyyy').format(_invoiceDueDate!)
                        : ''),
                Divider(color: Colors.grey[300], thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Text(
                        '\$${totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          // Additional info
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This invoice will be automatically created when the student is saved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceReviewItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
        // Add suffix icon for password regeneration
        suffixIcon: label == 'Password' && widget.user == null
            ? IconButton(
                icon: Icon(Icons.refresh, color: Colors.blue[600]),
                onPressed: () {
                  setState(() {
                    controller.text = _generateRandomPassword();
                  });
                },
                tooltip: 'Generate new password',
              )
            : null,
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
        // Add helper text for auto-generated password
        helperText: label == 'Password' && widget.user == null
            ? 'Auto-generated 8-digit password'
            : null,
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
        helperText:
            widget.role == 'student' ? 'Must be 16 years or older' : null,
      ),
      readOnly: true,
      validator: (value) {
        if (value!.isEmpty) return 'Required';

        // Additional age validation for students
        if (widget.role == 'student' && _selectedDate != null) {
          final age = DateTime.now().difference(_selectedDate!).inDays / 365.25;
          if (age < 16) {
            return 'Student must be at least 16 years old';
          }
        }
        return null;
      },
      onTap: () async {
        // Calculate maximum date (16 years ago from today)
        final DateTime maxDate = widget.role == 'student'
            ? DateTime.now().subtract(Duration(days: 16 * 365))
            : DateTime.now()
                .subtract(Duration(days: 365)); // 1 year ago for non-students

        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? maxDate,
          firstDate: DateTime(1900),
          lastDate: maxDate,
          helpText: widget.role == 'student'
              ? 'Select birth date (must be 16+ years old)'
              : 'Select birth date',
        );

        if (picked != null) {
          // Double-check age requirement for students
          if (widget.role == 'student') {
            final age = DateTime.now().difference(picked).inDays / 365.25;
            if (age < 16) {
              Get.snackbar(
                'Age Requirement',
                'Students must be at least 16 years old to enroll',
                backgroundColor: Colors.orange[100],
                colorText: Colors.orange[800],
                icon: Icon(Icons.warning, color: Colors.orange),
              );
              return;
            }
          }

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

        // Age validation for students
        if (widget.role == 'student' && _selectedDate != null) {
          final age = DateTime.now().difference(_selectedDate!).inDays / 365.25;
          if (age < 16) {
            Get.snackbar(
              'Age Requirement',
              'Students must be at least 16 years old',
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
              icon: Icon(Icons.error, color: Colors.red),
            );
            return false;
          }
        }
        return true;

      case 1:
        // Contact validation (same as before)
        // ... existing contact validation code ...
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
        if (_passwordController.text.length != 8) {
          Get.snackbar(
            'Validation Error',
            'Password must be exactly 8 digits',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }
        // Validate that password contains only numbers
        if (!RegExp(r'^\d{8}$').hasMatch(_passwordController.text)) {
          Get.snackbar(
            'Validation Error',
            'Password must contain only 8 digits',
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
            icon: Icon(Icons.error, color: Colors.red),
          );
          return false;
        }

        // Additional validation for NEW students only (not when editing)
        if (widget.role == 'student' && widget.user == null) {
          if (_selectedCourse == null) {
            Get.snackbar(
              'Validation Error',
              'Please select a course',
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
              icon: Icon(Icons.error, color: Colors.red),
            );
            return false;
          }

          if (_lessonsController.text.isEmpty) {
            Get.snackbar(
              'Validation Error',
              'Please enter number of lessons',
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
              icon: Icon(Icons.error, color: Colors.red),
            );
            return false;
          }

          final lessons = int.tryParse(_lessonsController.text);
          if (lessons == null || lessons < 1) {
            Get.snackbar(
              'Validation Error',
              'Please enter a valid number of lessons (minimum 1)',
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
              icon: Icon(Icons.error, color: Colors.red),
            );
            return false;
          }

          if (lessons > 50) {
            Get.snackbar(
              'Validation Error',
              'Maximum 50 lessons per invoice',
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
              icon: Icon(Icons.error, color: Colors.red),
            );
            return false;
          }

          if (_invoiceDueDate == null) {
            Get.snackbar(
              'Validation Error',
              'Please select an invoice due date',
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
              icon: Icon(Icons.error, color: Colors.red),
            );
            return false;
          }
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

  void _goBackToUserList() {
    final navController = Get.find<NavigationController>();
    final userController = Get.find<UserController>();

    // Reload the user list to show the newly added user
    userController.fetchUsers();

    // Navigate back to the appropriate list
    navController
        .navigateToPage(widget.role == 'admin' ? 'users' : '${widget.role}s');

    // Close the current screen
    Get.back();
  }

  Future<void> _submitForm() async {
    // If it's a new student with course selection, use the enhanced save method
    if (widget.user == null &&
        widget.role == 'student' &&
        _selectedCourse != null) {
      await _saveUserWithInvoice();
      return;
    }

    // Otherwise, use the existing save logic
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

  Widget _buildStudentSpecificFields() {
    final CourseController courseController = Get.find<CourseController>();
    Get.find<BillingController>();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.blue[600]),
              SizedBox(width: 8),
              Text(
                'Course Enrollment & Billing',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Course Selection Dropdown
          DropdownButtonFormField<Course>(
            value: _selectedCourse,
            decoration: InputDecoration(
              labelText: 'Select Course *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.book, color: Colors.blue),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            validator: (value) =>
                value == null ? 'Please select a course' : null,
            items: courseController.courses
                .where((course) => course.status.toLowerCase() == 'active')
                .map((course) => DropdownMenuItem(
                      value: course,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              course.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '\$${course.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (Course? value) {
              setState(() {
                _selectedCourse = value;
                _updateBillingPreview();
              });
            },
          ),

          SizedBox(height: 12),

          // Number of Lessons Input
          TextFormField(
            controller: _lessonsController,
            decoration: InputDecoration(
              labelText: 'Number of Lessons *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers, color: Colors.blue),
              filled: true,
              fillColor: Colors.white,
              helperText: 'How many lessons to bill initially (1-50)',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter number of lessons';
              }
              final lessons = int.tryParse(value);
              if (lessons == null || lessons < 1) {
                return 'Please enter a valid number (minimum 1)';
              }
              if (lessons > 50) {
                return 'Maximum 50 lessons per invoice';
              }
              return null;
            },
            onChanged: (value) {
              _updateBillingPreview();
            },
          ),

          SizedBox(height: 12),

          // Invoice Due Date
          InkWell(
            onTap: () => _selectDueDate(),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Invoice Due Date *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today, color: Colors.blue),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                errorText:
                    _invoiceDueDate == null ? 'Please select due date' : null,
              ),
              child: Text(
                _invoiceDueDate != null
                    ? DateFormat('MMM dd, yyyy').format(_invoiceDueDate!)
                    : 'Select due date',
                style: TextStyle(
                  color:
                      _invoiceDueDate != null ? Colors.black : Colors.grey[600],
                ),
              ),
            ),
          ),

          SizedBox(height: 12),

          // Required fields note
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[600], size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '* All fields are required for student enrollment',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          // Billing Preview
          if (_selectedCourse != null && _lessonsController.text.isNotEmpty)
            _buildBillingPreview(),
        ],
      ),
    );
  }

  Widget _buildBillingPreview() {
    final lessons = int.tryParse(_lessonsController.text) ?? 0;
    final pricePerLesson = _selectedCourse?.price ?? 0.0;
    final totalAmount = lessons * pricePerLesson;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: Colors.green[600], size: 20),
              SizedBox(width: 8),
              Text(
                'Invoice Preview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Course:', style: TextStyle(color: Colors.grey[700])),
              Text(_selectedCourse?.name ?? '',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lessons:', style: TextStyle(color: Colors.grey[700])),
              Text('$lessons lessons',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Price per lesson:',
                  style: TextStyle(color: Colors.grey[700])),
              Text('\$${pricePerLesson.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          Divider(color: Colors.green[300]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('\$${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[700],
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDueDate ?? DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != _invoiceDueDate) {
      setState(() {
        _invoiceDueDate = picked;
      });
    }
  }

  Future<void> _saveUserWithInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userController = Get.find<UserController>();
      final billingController = Get.find<BillingController>();

      // Check for existing user by phone or ID number
      final existingUser = userController.users.firstWhereOrNull(
        (user) => (user.phone == _phoneController.text ||
            user.idnumber == _idNumberController.text),
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

      // 1. Create the student user first
      final user = User(
        fname: _fnameController.text.trim(),
        lname: _lnameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        password: _passwordController.text.trim(),
        role: widget.role,
        status: _status!,
        gender: _gender!,
        date_of_birth: _selectedDate!,
        idnumber: _idNumberController.text.trim(),
        created_at: DateTime.now(),
      );

      // Save the user to database and get the created user with ID
      await userController.handleUser(user, isUpdate: false);

      // Get the saved user from the controller (it should now have an ID)
      final savedUser = userController.users.firstWhereOrNull(
        (u) => u.email == user.email && u.phone == user.phone,
      );

      if (savedUser == null || savedUser.id == null) {
        throw Exception('Failed to save user to database');
      }

      // 2. Auto-create invoice if student and course selected
      String successMessage = '';
      if (widget.role == 'student' && _selectedCourse != null) {
        final lessons = int.parse(_lessonsController.text);
        final pricePerLesson = _selectedCourse!.price.toDouble();
        final totalAmount = lessons * pricePerLesson;

        final invoice = Invoice(
          invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
          studentId: savedUser.id!, // Use the saved user's ID
          courseId: _selectedCourse!.id!,
          lessons: lessons,
          pricePerLesson: pricePerLesson,
          totalAmount: totalAmount,
          amountPaid: 0.0,
          createdAt: DateTime.now(),
          dueDate: _invoiceDueDate!,
          status: 'unpaid',
        );

        // Create the invoice
        await billingController.createInvoice(invoice);

        successMessage =
            'Student enrolled successfully and billed for $lessons lessons (\$${totalAmount.toStringAsFixed(2)})';
      } else {
        successMessage = '${widget.role.capitalize} created successfully';
      }

      // Show success dialog (rest of the method remains the same)...
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
                successMessage,
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
                        '${_fnameController.text} ${_lnameController.text} has been added as a ${widget.role}.',
                        style: TextStyle(color: Colors.green[800]),
                      ),
                    ),
                  ],
                ),
              ),
              // Add invoice details for students
              if (widget.role == 'student' && _selectedCourse != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
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
                          Icon(Icons.receipt_long,
                              color: Colors.blue[700], size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Invoice Created',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Course: ${_selectedCourse!.name}',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                      Text(
                        'Lessons: ${_lessonsController.text}',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                      Text(
                        'Due Date: ${DateFormat('MMM dd, yyyy').format(_invoiceDueDate!)}',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ),
              ],
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
      print('Error creating student with invoice: $e'); // Add debugging
      Get.snackbar(
        'Error',
        'Failed to create ${widget.role}: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
