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
  final User? user;
  final bool embeddedInShell;
  final VoidCallback? onClose;

  const AddUserScreen({
    Key? key,
    required this.role,
    this.user,
    this.embeddedInShell = false,
    this.onClose,
  }) : super(key: key);

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

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
      TextEditingController(text: '1');
  DateTime? _invoiceDueDate = DateTime.now().add(Duration(days: 5));

  void _updateBillingPreview() {
    if (!mounted) return;

    final lessons = safeLessonsValue;

    if (_selectedCourse != null) {
      final totalCost = lessons * _selectedCourse!.price;
      debugPrint(
          'Preview updated: $lessons lessons, total: \$${totalCost.toStringAsFixed(2)}');
    }

    setState(() {});
  }

  int get safeLessonsValue {
    try {
      if (_lessonsController.text.isEmpty) return 1;

      final cleanText =
          _lessonsController.text.replaceAll(RegExp(r'[^\d]'), '').trim();
      if (cleanText.isEmpty) return 1;

      final parsed = int.tryParse(cleanText);
      return parsed != null && parsed > 0 ? parsed : 1;
    } catch (e) {
      return 1;
    }
  }

  Future<void> _createInvoiceForStudent(User user) async {
    try {
      if (_selectedCourse == null) return;

      final lessons = safeLessonsValue;

      final billingController = Get.find<BillingController>();
      await billingController.createInvoiceWithCourse(
        user.id!,
        _selectedCourse!,
        lessons,
        _invoiceDueDate ?? DateTime.now().add(Duration(days: 30)),
      );

      debugPrint('✅ Invoice created with $lessons lessons');
    } catch (e) {
      debugPrint('❌ Error creating invoice: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Unable to Create Invoice',
        'Could not create the invoice for this student. Please try adding it manually from the Billing section.',
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
      _status = widget.user!.status.capitalize;
      _gender = widget.user!.gender.capitalize;
    } else {
      _dateOfBirthController = TextEditingController();
      _status = 'Active';
      _gender = 'Male';
    }
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  bool _isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1024;
  }

  String _rolePageKey() {
    return widget.role == 'admin' ? 'users' : '${widget.role}s';
  }

  void _closeScreen() {
    final navController = Get.find<NavigationController>();
    if (widget.embeddedInShell) {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        navController.navigateToPage(_rolePageKey());
      }
      return;
    }

    navController.navigateToPage(_rolePageKey());
    if (Navigator.of(context).canPop()) {
      Get.back();
    }
  }

  void _closeAfterSuccess() {
    Get.back();
    _closeScreen();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedInShell && !_isMobile(context)) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildMainContent()),
          ],
        ),
      );
    }

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
        leading: widget.embeddedInShell
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: _closeScreen,
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
          preferredSize: Size.fromHeight(48),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Complete the form and save when ready.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildMainContent(),
      bottomNavigationBar: _buildMobileActionBar(),
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

  Widget _buildMobileActionBar() {
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
            Expanded(
              child: OutlinedButton(
                onPressed: _closeScreen,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Cancel'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
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
                    : Text('Save ${widget.role.capitalize}'),
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
            if (!widget.embeddedInShell)
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  final navController = Get.find<NavigationController>();
                  navController.navigateToPage(
                      widget.role == 'admin' ? 'users' : '${widget.role}s');
                  Get.back();
                },
              ),
            if (!widget.embeddedInShell) SizedBox(width: 8),
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
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
                child: Text('Save ${widget.role.capitalize}'),
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
                  if (!widget.embeddedInShell)
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        navController.navigateToPage(widget.role == 'admin'
                            ? 'users'
                            : '${widget.role}s');
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

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sections',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                _buildSidebarItem('Basic Info', Icons.person),
                _buildSidebarItem('Contact', Icons.contact_phone),
                _buildSidebarItem('Additional', Icons.info),
                _buildSidebarItem('Review & Save', Icons.check_circle),

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
                        '• Use a valid email address\n• Phone number should be 10-15 digits\n• ID number must be unique',
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

  Widget _buildSidebarItem(String title, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue[700],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
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
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
                child: Text('Save ${widget.role.capitalize}'),
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
                (isSmallScreen ? 200 : 140),
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoStep(),
                    SizedBox(height: 24),
                    _buildContactStep(),
                    SizedBox(height: 24),
                    _buildAdditionalStep(),
                    SizedBox(height: 24),
                    _buildReviewStep(),
                  ],
                ),
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
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter first name' : null,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _lnameController,
                  label: 'Last Name',
                  icon: Icons.person,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter last name' : null,
                ),
              ),
            ],
          ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _idNumberController,
          label: 'ID Number (Optional)',
          icon: Icons.badge,
        ),
        SizedBox(height: 16),
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
          label: 'Email Address (Optional)',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value!.isNotEmpty && !GetUtils.isEmail(value))
              return 'Please enter a valid email address';
            return null;
          },
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^[\+]?\d*$')),
          ],
          validator: (value) {
            if (value!.isEmpty) return 'Please enter a phone number';

            // Check if the format is valid: optional + followed by digits only
            if (!RegExp(r'^\+?\d+$').hasMatch(value)) {
              return 'Phone number can only contain numbers and optional + at the start';
            }

            String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
            if (digitsOnly.length > 15) {
              return 'Phone number is too long (maximum 15 digits)';
            }
            if (digitsOnly.length < 10) {
              return 'Phone number is too short (minimum 10 digits)';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: Icon(Icons.phone, color: Colors.grey[600]),
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
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: 'Address',
          icon: Icons.location_on,
          maxLines: 3,
          validator: (value) =>
              value!.isEmpty ? 'Please enter an address' : null,
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
          widget.role == 'admin'
              ? 'Account settings and security'
              : 'Account settings',
          style: TextStyle(color: Colors.grey[600]),
        ),
        SizedBox(height: isSmallScreen ? 24 : 32),
        if (widget.role == 'admin')
          Column(
            children: [
              _buildTextField(
                controller: _passwordController,
                label: 'Password (Optional)',
                icon: Icons.lock,
                obscureText: true,
                validator: (value) {
                  if (value!.isNotEmpty) {
                    if (value.length != 8)
                      return 'Password must be exactly 8 digits';
                    if (!RegExp(r'^\d{8}$').hasMatch(value)) {
                      return 'Password can only contain numbers (8 digits)';
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        _buildDropdownField(
          value: _status,
          items: ['Active', 'Inactive'],
          label: 'Status',
          icon: Icons.check_circle,
          onChanged: (value) => setState(() => _status = value),
        ),
        SizedBox(height: 24),
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
        labelText: 'Date of Birth (Optional)',
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

          TextFormField(
            controller: _lessonsController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
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
                return 'Please enter number of lessons';
              }

              final lessons = safeLessonsValue;

              if (lessons <= 0) {
                return 'Please enter a number greater than 0';
              }

              if (lessons > 999) {
                return 'Maximum number of lessons is 999';
              }

              return null;
            },
            onChanged: (value) {
              Future.delayed(Duration(milliseconds: 100), () {
                if (mounted) {
                  _updateBillingPreview();
                }
              });
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Invoice Due Date',
              prefixIcon: Icon(Icons.schedule, color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[100],
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
        id: widget.user?.id,
        schoolId: widget.user?.schoolId,
        firebaseUserId: widget.user?.firebaseUserId,
        fname: _fnameController.text.trim(),
        lname: _lnameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? _generateRandomPassword()
            : _passwordController.text.trim(),
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

      debugPrint(
          '📝 Submitting ${widget.user == null ? 'new' : 'updated'} user: ${user.email}');
      debugPrint('🏫 School ID: ${user.schoolId}');

      if (widget.user == null) {
        await userController.handleUser(user);
        debugPrint('✅ New user creation completed');

        if (widget.role == 'student' && _selectedCourse != null) {
          await _createStudentInvoice(user);
        }
      } else {
        await userController.handleUser(user, isUpdate: true);
        debugPrint('✅ User update completed');
      }

      _showSuccessDialog();
    } catch (e) {
      debugPrint('❌ Form submission failed: $e');

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createStudentInvoice(User user) async {
    try {
      debugPrint('🧾 Creating invoice for new student...');

      final lessonsText = _lessonsController.text.trim();
      int lessons = 1;

      if (lessonsText.isNotEmpty) {
        final cleanText = lessonsText.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanText.isNotEmpty) {
          lessons = int.parse(cleanText);
          if (lessons <= 0) lessons = 1;
        }
      }

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
      debugPrint('✅ Invoice created successfully');
    } catch (e) {
      debugPrint('⚠️ Invoice creation failed: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Invoice Not Created',
        'Student was created successfully, but the invoice could not be generated. You can add it manually from the Billing section.',
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
        final recentUser = users.firstWhere(
          (u) =>
              u['email']?.toString().toLowerCase() ==
              _emailController.text.trim().toLowerCase(),
          orElse: () => {'id': 1},
        );
        return recentUser['id'] ?? 1;
      }
      return 1;
    } catch (e) {
      debugPrint('Error getting last inserted user ID: $e');
      return 1;
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
              _closeAfterSuccess();
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
    super.dispose();
  }
}
