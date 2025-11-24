import 'dart:math';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/user_controller.dart';
import '../../models/user.dart';
import '../../controllers/navigation_controller.dart';
import '../../widgets/responsive_text.dart';

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
    if (!mounted) return;

    // Use the safe lessons value method - this won't throw exceptions
    final lessons = safeLessonsValue;

    // Update any calculations that depend on lessons
    if (_selectedCourse != null) {
      final totalCost = lessons * _selectedCourse!.price;
      print(
          'Preview updated: $lessons lessons, total: \$${totalCost.toStringAsFixed(2)}');
    }

    // Update UI if needed
    setState(() {
      // Update any state variables for the preview display
    });
  }

  int get safeLessonsValue {
    try {
      if (_lessonsController.text.isEmpty) return 1;

      // Remove all non-digit characters and trim
      final cleanText =
          _lessonsController.text.replaceAll(RegExp(r'[^\d]'), '').trim();
      if (cleanText.isEmpty) return 1;

      final parsed = int.tryParse(cleanText);
      return parsed != null && parsed > 0 ? parsed : 1;
    } catch (e) {
      print('Error parsing lessons value: $e');
      return 1;
    }
  }

// Use this when creating invoices:
  Future<void> _createInvoiceForStudent(User user) async {
    try {
      if (_selectedCourse == null) return;

      // Use the safe lessons value
      final lessons = safeLessonsValue;

      final billingController = Get.find<BillingController>();
      await billingController.createInvoiceWithCourse(
        user.id!,
        _selectedCourse!,
        lessons, // Safe parsed value
        _invoiceDueDate ?? DateTime.now().add(Duration(days: 30)),
      );

      print('✅ Invoice created with $lessons lessons');
    } catch (e) {
      print('❌ Error creating invoice: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Failed to create invoice: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }
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

  // Check if we should show mobile layout
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  // Check if we should show tablet layout
  bool _isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1024;
  }

  @override
  Widget build(BuildContext context) {
    if (_isMobile(context)) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.user == null
              ? 'Add ${widget.role.capitalize}'
              : 'Edit ${widget.role.capitalize}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            final navController = Get.find<NavigationController>();
            navController.navigateToPage(
                widget.role == 'admin' ? 'users' : '${widget.role}s');
            Get.back();
          },
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(80),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Mobile step indicator
                Row(
                  children: List.generate(4, (index) {
                    final isActive = _currentStep == index;
                    final isCompleted = _currentStep > index;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? Colors.green
                                    : isActive
                                        ? Colors.blue
                                        : Colors.grey[400],
                              ),
                              child: Center(
                                child: isCompleted
                                    ? Icon(Icons.check,
                                        color: Colors.white, size: 16)
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _getStepTitle(index),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildMainContent(),
      bottomNavigationBar: _buildMobileBottomBar(),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Fixed Sidebar (same as main layout) - hide on tablet if needed
          if (!_isTablet(context) || MediaQuery.of(context).size.width > 900)
            Container(
              width: _isTablet(context) ? 200 : 250,
              color: Colors.blueGrey[900],
              child: _buildSidebar(),
            ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                if (_isTablet(context) &&
                    MediaQuery.of(context).size.width <= 900)
                  _buildTabletTopBar(),
                if (!_isTablet(context) ||
                    MediaQuery.of(context).size.width > 900)
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

  String _getStepTitle(int index) {
    switch (index) {
      case 0:
        return 'Basic';
      case 1:
        return 'Contact';
      case 2:
        return 'Additional';
      case 3:
        return 'Review';
      default:
        return '';
    }
  }

  Widget _buildMobileBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Previous'),
                ),
              ),
            if (_currentStep > 0) SizedBox(width: 16),
            Expanded(
              flex: _currentStep == 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_currentStep == 3 ? _submitForm : _nextStep),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_currentStep == 3
                        ? 'Save ${widget.role.capitalize}'
                        : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletTopBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
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
            IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                final navController = Get.find<NavigationController>();
                navController.navigateToPage(
                    widget.role == 'admin' ? 'users' : '${widget.role}s');
                Get.back();
              },
            ),
            SizedBox(width: 8),
            Text(
              widget.user == null
                  ? 'Add New ${widget.role.capitalize}'
                  : 'Edit ${widget.role.capitalize}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Spacer(),
            if (_isLoading)
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            else
              Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _previousStep,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
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
                        fontSize: _isTablet(context) ? 16 : 18,
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
                fontSize: _isTablet(context) ? 13 : 14,
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
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _previousStep,
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
    final isSmallScreen = _isMobile(context);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height -
                (isSmallScreen
                    ? 200
                    : 140), // Account for app bar and bottom bar
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  SingleChildScrollView(
                    child: _buildBasicInfoStep(),
                  ),
                  SingleChildScrollView(
                    child: _buildContactStep(),
                  ),
                  SingleChildScrollView(
                    child: _buildAdditionalStep(),
                  ),
                  SingleChildScrollView(
                    child: _buildReviewStep(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    final isSmallScreen = _isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: TextStyle(
            fontSize: isSmallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          'Enter the ${widget.role}\'s basic personal information',
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: isSmallScreen ? 24 : 32),

        // Responsive layout for name fields
        if (isSmallScreen)
          Column(
            children: [
              _buildTextField(
                controller: _fnameController,
                label: 'First Name',
                icon: Icons.person,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _lnameController,
                label: 'Last Name',
                icon: Icons.person,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ],
          )
        else
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

        // Responsive layout for gender and date
        if (isSmallScreen)
          Column(
            children: [
              _buildDropdownField(
                value: _gender,
                items: ['Male', 'Female'],
                label: 'Gender',
                icon: Icons.person_outline,
                onChanged: (value) => setState(() => _gender = value),
              ),
              SizedBox(height: 16),
              _buildDatePickerField(),
            ],
          )
        else
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
    final isSmallScreen = _isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: TextStyle(
            fontSize: isSmallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          'How can we reach this ${widget.role}?',
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: isSmallScreen ? 24 : 32),
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
    final isSmallScreen = _isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: TextStyle(
            fontSize: isSmallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          'Account settings and security',
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: isSmallScreen ? 24 : 32),

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
    );
  }
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
          TextButton(
            onPressed: () {
              final navController = Get.find<NavigationController>();
              navController.navigateToPage('billing');
              Get.back();
            },
            child: Text('Go to Billing →'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final isSmallScreen = _isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Information',
          style: TextStyle(
            fontSize: isSmallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          'Please review all information before saving',
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: isSmallScreen ? 24 : 32),
        _buildReviewSection(
          'Personal Information',
          [
            _buildReviewItem(
                'Name', '${_fnameController.text} ${_lnameController.text}'),
            _buildReviewItem('ID Number', _idNumberController.text),
            _buildReviewItem('Gender', _gender ?? ''),
            _buildReviewItem('Date of Birth', _dateOfBirthController.text),
          ],
        ),
        SizedBox(height: 20),
        _buildReviewSection(
          'Contact Information',
          [
            _buildReviewItem('Email', _emailController.text),
            _buildReviewItem('Phone', _phoneController.text),
            _buildReviewItem('Address', _addressController.text),
          ],
        ),
        SizedBox(height: 20),
        _buildReviewSection(
          'Account Information',
          [
            _buildReviewItem('Role', widget.role.capitalize!),
            _buildReviewItem('Status', _status ?? ''),
            _buildReviewItem('Password', '••••••••'),
          ],
        ),
        if (widget.role == 'student' &&
            widget.user == null &&
            _selectedCourse != null) ...[
          SizedBox(height: 20),
          _buildReviewSection(
            'Course & Billing',
            [
              _buildReviewItem('Course', _selectedCourse!.name),
              _buildReviewItem('Lessons', _lessonsController.text),
              _buildReviewItem('Total Amount',
                  '\$${(_selectedCourse!.price * int.parse(_lessonsController.text)).toStringAsFixed(2)}'),
              _buildReviewItem('Due Date',
                  DateFormat('dd/MM/yyyy').format(_invoiceDueDate!)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildReviewSection(String title, List<Widget> items) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
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
            width: _isMobile(context) ? 100 : 120,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 16 : 14,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return TextFormField(
      controller: _dateOfBirthController,
      readOnly: true,
      validator: (value) => value!.isEmpty ? 'Required' : null,
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ??
              DateTime.now().subtract(Duration(days: 6570)), // 18 years ago
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blue[600]!,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && picked != _selectedDate) {
          setState(() {
            _selectedDate = picked;
            _dateOfBirthController.text =
                DateFormat('yyyy-MM-dd').format(picked);
          });
        }
      },
      decoration: InputDecoration(
        labelText: 'Date of Birth',
        prefixIcon: Icon(Icons.calendar_today, color: Colors.grey[600]),
        suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildStudentSpecificFields() {
    final courseController = Get.find<CourseController>();

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
              Icon(Icons.school, color: Colors.green[600]),
              SizedBox(width: 8),
              Text(
                'Course Enrollment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Course dropdown
          Obx(() => DropdownButtonFormField<Course>(
                value: _selectedCourse,
                items: courseController.courses.map((Course course) {
                  return DropdownMenuItem<Course>(
                    value: course,
                    child: Text(
                        '${course.name} - \$${course.price.toStringAsFixed(2)}'),
                  );
                }).toList(),
                onChanged: (Course? course) {
                  setState(() {
                    _selectedCourse = course;
                  });
                  _updateBillingPreview();
                },
                decoration: InputDecoration(
                  labelText: 'Select Course',
                  prefixIcon: Icon(Icons.school, color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              )),

          SizedBox(height: 16),

          // Lessons field
          TextFormField(
            controller: _lessonsController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // Only allow digits
              LengthLimitingTextInputFormatter(3), // Limit to 3 digits max
            ],
            decoration: InputDecoration(
              labelText: 'Number of Lessons',
              hintText: '1',
              prefixIcon: Icon(Icons.numbers, color: Colors.green[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }

              // Use the safe parsing method
              final lessons = safeLessonsValue;

              if (lessons <= 0) {
                return 'Enter a valid number greater than 0';
              }

              if (lessons > 999) {
                return 'Maximum 999 lessons';
              }

              return null;
            },
            onChanged: (value) {
              // Add a small delay to avoid rapid updates during typing
              Future.delayed(Duration(milliseconds: 100), () {
                if (mounted) {
                  _updateBillingPreview();
                }
              });
            },
          ),
          SizedBox(height: 16),

          // Due date picker
          TextFormField(
            readOnly: true,
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate:
                    _invoiceDueDate ?? DateTime.now().add(Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _invoiceDueDate = picked;
                });
                _updateBillingPreview();
              }
            },
            decoration: InputDecoration(
              labelText: 'Invoice Due Date',
              prefixIcon: Icon(Icons.schedule, color: Colors.grey[600]),
              suffixIcon: Icon(Icons.calendar_today, color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            controller: TextEditingController(
              text: _invoiceDueDate != null
                  ? DateFormat('dd/MM/yyyy').format(_invoiceDueDate!)
                  : '',
            ),
          ),

          if (_selectedCourse != null) ...[
            SizedBox(height: 16),
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
                  Text(
                    'Billing Preview',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Course: ${_selectedCourse!.name}',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                  Text(
                    'Price per lesson: \$${_selectedCourse!.price.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                  Text(
                    'Lessons: ${_getSafeLessonsCount()}',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                  Divider(color: Colors.blue[300]),
                  Text(
                    'Total: ${(_selectedCourse!.price * _getSafeLessonsCount()).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _getSafeLessonsCount() {
    final lessonsText = _lessonsController.text.trim();
    if (lessonsText.isEmpty) return 0;

    try {
      final lessons = int.parse(lessonsText);
      return lessons > 0 ? lessons : 0;
    } catch (e) {
      return 0; // Return 0 if parsing fails
    }
  }

  Widget _buildInstructorSpecificFields() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_pin_circle, color: Colors.orange[600]),
              SizedBox(width: 8),
              ResponsiveText(
                'Instructor Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Vehicle assignments and schedule management can be handled in the Fleet and Schedule sections.',
            style: TextStyle(color: Colors.orange[700]),
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
            snackPosition: SnackPosition.BOTTOM,
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
            snackPosition: SnackPosition.BOTTOM,
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
            snackPosition: SnackPosition.BOTTOM,
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
            snackPosition: SnackPosition.BOTTOM,
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
        // Contact Info validation
        if (_emailController.text.isEmpty) {
          Get.snackbar(
            snackPosition: SnackPosition.BOTTOM,
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
            snackPosition: SnackPosition.BOTTOM,
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
            snackPosition: SnackPosition.BOTTOM,
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
            snackPosition: SnackPosition.BOTTOM,
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
        // Additional Info validation
        if (_passwordController.text.isEmpty) {
          Get.snackbar(
            snackPosition: SnackPosition.BOTTOM,
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
            snackPosition: SnackPosition.BOTTOM,
            'Validation Error',
            'Password must be exactly 8 digits',
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
    final navController = Get.find<NavigationController>();
    navController
        .navigateToPage(widget.role == 'admin' ? 'users' : '${widget.role}s');
    Get.back();
  }


  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userController = Get.find<UserController>();

      final user = User(
        id: widget.user?.id, // Keep existing ID for updates, null for new users
        fname: _fnameController.text.trim(),
        lname: _lnameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        idnumber: _idNumberController.text.trim(),
        role: widget.role,
        status: _status ?? 'Active',
        gender: _gender ?? 'Male',
        date_of_birth:
            _selectedDate ?? DateTime.now().subtract(Duration(days: 18 * 365)),
        created_at: widget.user?.created_at ?? DateTime.now(),
      );

      print(
          '📝 Submitting ${widget.user == null ? 'new' : 'updated'} user: ${user.email}');

      if (widget.user == null) {
        // Adding new user
        await userController.handleUser(user);
        print('✅ New user creation completed');

        // If student with course, create invoice
        if (widget.role == 'student' && _selectedCourse != null) {
          await _createStudentInvoice(user);
        }
      } else {
        // Updating existing user
        await userController.handleUser(user, isUpdate: true);
        print('✅ User update completed');
      }

      // If we get here, the operation was successful
      _showSuccessDialog();
    } catch (e) {
      print('❌ Form submission failed: $e');

      // The error snackbar is already shown by the controller,
      // so we just need to handle the UI state
      setState(() {
        _isLoading = false;
      });

      // Don't show additional error messages since controller already shows them
    }
  }

// Separate method for creating student invoice
  Future<void> _createStudentInvoice(User user) async {
    try {
      print('🧾 Creating invoice for new student...');

      // Parse lessons safely
      final lessonsText = _lessonsController.text.trim();
      int lessons = 1; // Default value

      if (lessonsText.isNotEmpty) {
        final cleanText = lessonsText.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanText.isNotEmpty) {
          lessons = int.parse(cleanText);
          if (lessons <= 0) lessons = 1;
        }
      }

      // Create invoice
      final pricePerLesson = _selectedCourse!.price.toDouble();
      final totalAmount = lessons * pricePerLesson;

      final invoice = Invoice(
        invoiceNumber: 'INV-${DateTime.now().toUtc().millisecondsSinceEpoch}',
        studentId: user.id ?? await _getLastInsertedUserId(),
        courseId: _selectedCourse!.id!,
        lessons: lessons,
        pricePerLesson: pricePerLesson,
        totalAmount: totalAmount,
        amountPaid: 0.0,
        dueDate: _invoiceDueDate ?? DateTime.now().add(Duration(days: 30)),
        status: 'unpaid',
        createdAt: DateTime.now(),
      );

      final billingController = Get.find<BillingController>();
      await billingController.createInvoice(invoice);
      print('✅ Invoice created successfully');
    } catch (e) {
      print('⚠️ Invoice creation failed: $e');
      // Show warning but don't prevent success dialog
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Warning',
        'Student created but invoice creation failed: ${e.toString()}',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    }
  }

  Future<int> _getLastInsertedUserId() async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      if (users.isNotEmpty) {
        // Get the most recently created user by email
        final recentUser = users.firstWhere(
          (u) =>
              u['email']?.toString().toLowerCase() ==
              _emailController.text.trim().toLowerCase(),
          orElse: () => {'id': 1}, // fallback
        );
        return recentUser['id'] ?? 1;
      }
      return 1; // fallback ID
    } catch (e) {
      print('Error getting last inserted user ID: $e');
      return 1; // fallback ID
    }
  }

  void _showSuccessDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(
          '${widget.role.capitalize} ${widget.user == null ? 'created' : 'updated'} successfully!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.back(); // Return to users list

              // Navigate to the users screen to show the updated list
              Get.offNamed('/users',
                  arguments: widget.role == 'student'
                      ? 'students'
                      : '${widget.role}s');
            },
            child: Text('Done'),
          ),
        ],
      ),
      barrierDismissible: false,
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
    _lessonsController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
