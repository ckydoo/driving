// lib/screens/payments/enhanced_pos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/billing_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../models/user.dart';
import '../../models/course.dart';
import '../../models/invoice.dart';
import '../../models/payment.dart';
import '../../services/receipt_service.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({Key? key}) : super(key: key);

  @override
  _POSScreenState createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with TickerProviderStateMixin {
  final BillingController billingController = Get.find();
  final UserController userController = Get.find();
  final CourseController courseController = Get.find();

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Search and Selection
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  User? _selectedStudent;
  List<User> _searchResults = [];
  List<User> _recentStudents = [];
  bool _showSearchResults = false;

  // Payment Processing
  final TextEditingController _paymentAmountController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  String _paymentMethod = 'Cash';
  bool _generateReceipt = true;
  bool _isProcessing = false;

  // Invoice Creation
  Course? _selectedCourse;
  final TextEditingController _lessonsController =
      TextEditingController(text: '1');
  DateTime _invoiceDueDate = DateTime.now().add(Duration(days: 30));

  // UI State
  String _operationMode = 'payment';
  String _currentStep = 'search'; // search, details, payment, confirmation

  // Quick Actions
  final List<double> _quickAmounts = [50.0, 100.0, 200.0, 500.0];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
    _setupKeyboardShortcuts();
    _loadRecentStudents();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  void _setupKeyboardShortcuts() {
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() {
          _showSearchResults = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _paymentAmountController.dispose();
    _amountFocusNode.dispose();
    _notesController.dispose();
    _lessonsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await userController.fetchUsers();
    await billingController.fetchBillingData();
    await courseController.fetchCourses();
  }

  void _loadRecentStudents() {
    // Load recently processed students (you might want to store this in SharedPreferences)
    _recentStudents = userController.users
        .where((user) => user.role.toLowerCase() == 'student')
        .take(5)
        .toList();
  }

  void _searchStudents(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final students = userController.users
        .where((user) => user.role.toLowerCase() == 'student')
        .where((user) =>
            '${user.fname} ${user.lname}'
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            user.email.toLowerCase().contains(query.toLowerCase()) ||
            (user.idnumber?.toLowerCase().contains(query.toLowerCase()) ??
                false))
        .take(10)
        .toList();

    setState(() {
      _searchResults = students;
      _showSearchResults = true;
    });
  }

  void _selectStudent(User student) {
    setState(() {
      _selectedStudent = student;
      _searchController.text = '${student.fname} ${student.lname}';
      _showSearchResults = false;
      _currentStep = 'details';
    });

    // Add to recent students
    if (!_recentStudents.any((s) => s.id == student.id)) {
      _recentStudents.insert(0, student);
      if (_recentStudents.length > 5) {
        _recentStudents.removeLast();
      }
    }

    _scaleController.reset();
    _scaleController.forward();

    // Auto-populate payment amount with outstanding balance
    final balance = _getStudentBalance(student);
    if (balance > 0) {
      _paymentAmountController.text = balance.toStringAsFixed(2);
    }
  }

  double _getStudentBalance(User student) {
    return billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .fold(0.0,
            (sum, invoice) => sum + (invoice.totalAmount - invoice.amountPaid));
  }

  List<Invoice> _getStudentInvoices(User student) {
    return billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();
  }

  void _processPayment() async {
    if (_selectedStudent == null || _paymentAmountController.text.isEmpty) {
      _showEnhancedSnackbar('Please select a student and enter payment amount',
          SnackbarType.error);
      return;
    }

    final amount = double.tryParse(_paymentAmountController.text);
    if (amount == null || amount <= 0) {
      _showEnhancedSnackbar(
          'Please enter a valid payment amount', SnackbarType.error);
      return;
    }

    setState(() {
      _isProcessing = true;
      _currentStep = 'processing';
    });

    try {
      // Find the oldest unpaid invoice
      final studentInvoices = _getStudentInvoices(_selectedStudent!)
          .where((invoice) => invoice.totalAmount > invoice.amountPaid)
          .toList();

      if (studentInvoices.isEmpty) {
        throw Exception('No outstanding invoices found for this student');
      }

      studentInvoices.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final invoice = studentInvoices.first;

      final payment = Payment(
        invoiceId: invoice.id!,
        amount: amount,
        method: _paymentMethod,
        paymentDate: DateTime.now(),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        userId: userController.currentUser.value?.id ?? 1,
        reference: 'POS-${DateTime.now().millisecondsSinceEpoch}',
      );

      await billingController.recordPayment(payment);

      if (_generateReceipt) {
        await ReceiptService.generateReceipt(
          payment,
          invoice,
          _selectedStudent!,
          'Your Driving School',
        );
      }

      setState(() {
        _currentStep = 'success';
      });

      _showEnhancedSnackbar(
        'Payment of \$${amount.toStringAsFixed(2)} processed successfully!',
        SnackbarType.success,
      );

      // Auto-clear after success
      Future.delayed(Duration(seconds: 2), () {
        _clearAll();
      });
    } catch (e) {
      _showEnhancedSnackbar(
          'Error processing payment: ${e.toString()}', SnackbarType.error);
      setState(() {
        _currentStep = 'payment';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _createInvoice() async {
    if (_selectedStudent == null || _selectedCourse == null) {
      _showEnhancedSnackbar(
          'Please select a student and course', SnackbarType.error);
      return;
    }

    final lessons = int.tryParse(_lessonsController.text) ?? 1;
    if (lessons <= 0) {
      _showEnhancedSnackbar(
          'Please enter a valid number of lessons', SnackbarType.error);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final invoice = Invoice(
        studentId: _selectedStudent!.id!,
        courseId: _selectedCourse!.id!,
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        totalAmount: _selectedCourse!.price * lessons.toDouble(),
        pricePerLesson: _selectedCourse!.price.toDouble(),
        amountPaid: 0.0,
        dueDate: _invoiceDueDate,
        status: 'pending',
        createdAt: DateTime.now(),
        lessons: lessons,
      );

      await billingController.createInvoice(invoice);

      _showEnhancedSnackbar(
        'Invoice created successfully for ${lessons} lesson(s)!',
        SnackbarType.success,
      );

      _clearAll();
    } catch (e) {
      _showEnhancedSnackbar(
          'Error creating invoice: ${e.toString()}', SnackbarType.error);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _clearAll() {
    setState(() {
      _selectedStudent = null;
      _searchController.clear();
      _paymentAmountController.clear();
      _notesController.clear();
      _selectedCourse = null;
      _lessonsController.text = '1';
      _invoiceDueDate = DateTime.now().add(Duration(days: 30));
      _paymentMethod = 'Cash';
      _generateReceipt = true;
      _showSearchResults = false;
      _currentStep = 'search';
    });
    _searchFocusNode.requestFocus();
  }

  void _showEnhancedSnackbar(String message, SnackbarType type) {
    final color = type == SnackbarType.success
        ? Colors.green
        : type == SnackbarType.error
            ? Colors.red
            : Colors.blue;

    final icon = type == SnackbarType.success
        ? Icons.check_circle
        : type == SnackbarType.error
            ? Icons.error
            : Icons.info;

    Get.snackbar(
      '',
      '',
      titleText: Container(),
      messageText: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color.shade600,
      snackPosition: SnackPosition.TOP,
      margin: EdgeInsets.all(16),
      borderRadius: 12,
      duration: Duration(seconds: 3),
      animationDuration: Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildEnhancedAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel - Student Search and Info
                Expanded(
                  flex: 2,
                  child: _buildStudentPanel(),
                ),
                SizedBox(width: 20),
                // Right Panel - Operations
                Expanded(
                  flex: 3,
                  child: _buildOperationsPanel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildEnhancedAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.point_of_sale, color: Colors.white),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Point of Sale',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              Text(
                'Process payments & create invoices',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.blue[700],
      elevation: 0,
      actions: [
        _buildQuickAction(Icons.refresh, 'Refresh', _loadData),
        _buildQuickAction(Icons.clear_all, 'Clear All', _clearAll),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildQuickAction(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchSection(),
        SizedBox(height: 20),
        if (_selectedStudent != null) _buildStudentInfoCard(),
        if (_recentStudents.isNotEmpty && _selectedStudent == null)
          _buildRecentStudentsCard(),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.search, color: Colors.blue.shade600),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Student Search',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _searchStudents,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or ID number...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade400),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade400),
                              onPressed: () {
                                _searchController.clear();
                                _searchStudents('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showSearchResults && _searchResults.isNotEmpty)
            _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final student = _searchResults[index];
          final balance = _getStudentBalance(student);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectStudent(student),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    // Student Avatar
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        '${student.fname.substring(0, 1)}${student.lname.substring(0, 1)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Student Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${student.fname} ${student.lname}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            student.email,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          if (student.idnumber != null)
                            Text(
                              'ID: ${student.idnumber}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Balance Indicator
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: balance > 0
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: balance > 0
                              ? Colors.red.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: balance > 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    final balance = _getStudentBalance(_selectedStudent!);
    final invoices = _getStudentInvoices(_selectedStudent!);
    final paidInvoices = invoices.where((i) => i.status == 'paid').length;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    '${_selectedStudent!.fname.substring(0, 1)}${_selectedStudent!.lname.substring(0, 1)}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedStudent!.fname} ${_selectedStudent!.lname}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _selectedStudent!.email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade400),
                  onPressed: () {
                    setState(() {
                      _selectedStudent = null;
                      _searchController.clear();
                      _currentStep = 'search';
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            // Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Outstanding Balance',
                    '\$${balance.toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    balance > 0 ? Colors.red : Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Invoices',
                    '${invoices.length}',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Paid Invoices',
                    '$paidInvoices',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStudentsCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.grey.shade600),
              SizedBox(width: 8),
              Text(
                'Recent Students',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ..._recentStudents
              .map((student) => Container(
                    margin: EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _selectStudent(student),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey.shade200,
                                child: Text(
                                  '${student.fname.substring(0, 1)}${student.lname.substring(0, 1)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${student.fname} ${student.lname}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios,
                                  color: Colors.grey.shade400, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildOperationsPanel() {
    return Column(
      children: [
        _buildModeSelector(),
        SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            // Add scrollable wrapper
            child: _buildOperationForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Operation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  'Process Payment',
                  'Accept payment for outstanding balance',
                  Icons.payment,
                  'payment',
                  Colors.green,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildModeButton(
                  'Create Invoice',
                  'Generate new invoice for student',
                  Icons.receipt_long,
                  'invoice',
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
      String title, String subtitle, IconData icon, String mode, Color color) {
    final isSelected = _operationMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _operationMode = mode),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? color : Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationForm() {
    if (_currentStep == 'processing') {
      return _buildProcessingScreen();
    } else if (_currentStep == 'success') {
      return _buildSuccessScreen();
    } else if (_operationMode == 'payment') {
      return _buildEnhancedPaymentForm();
    } else {
      return _buildEnhancedInvoiceForm();
    }
  }

  Widget _buildProcessingScreen() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Processing Payment...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Please wait while we process your transaction',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 50,
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Payment Successful!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Transaction completed successfully',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: _clearAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'New Transaction',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ...existing code...
  Widget _buildEnhancedPaymentForm() {
    final canProcessPayment =
        _selectedStudent != null && _getStudentBalance(_selectedStudent!) > 0;
    final balance =
        _selectedStudent != null ? _getStudentBalance(_selectedStudent!) : 0.0;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SingleChildScrollView(
        // Add this wrapper
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.payment,
                      color: Colors.green.shade700, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  // Add Expanded to prevent overflow
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Process Payment',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'Accept payment for outstanding balance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            if (!canProcessPayment) ...[
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 24),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedStudent == null
                                ? 'No Student Selected'
                                : 'No Outstanding Balance',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _selectedStudent == null
                                ? 'Please search and select a student to continue'
                                : 'This student has no outstanding balance to pay',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Payment Amount Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'Outstanding: \$${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextFormField(
                      controller: _paymentAmountController,
                      focusNode: _amountFocusNode,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: Container(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '\$',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Quick Amount Buttons
                  Row(
                    children: [
                      Text(
                        'Quick amounts:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(width: 12),
                      ..._quickAmounts
                          .where((amount) => amount <= balance)
                          .map(
                            (amount) => Container(
                              margin: EdgeInsets.only(right: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    _paymentAmountController.text =
                                        amount.toStringAsFixed(2);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.blue.shade200),
                                    ),
                                    child: Text(
                                      '\$${amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      // Full Balance Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            _paymentAmountController.text =
                                balance.toStringAsFixed(2);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'Full Balance',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Payment Method Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPaymentMethodButton(
                          'Cash', Icons.money, Colors.green),
                      SizedBox(width: 12),
                      _buildPaymentMethodButton(
                          'Ecocash', Icons.credit_card, Colors.blue),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Generate Receipt Option
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  title: Text(
                    'Generate Receipt',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Automatically generate and print receipt',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  value: _generateReceipt,
                  onChanged: (value) =>
                      setState(() => _generateReceipt = value ?? true),
                  activeColor: Colors.green.shade600,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              SizedBox(height: 32),

              // Process Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Process Payment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodButton(String method, IconData icon, Color color) {
    final isSelected = _paymentMethod == method;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _paymentMethod = method),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.grey.shade500,
                  size: 24,
                ),
                SizedBox(height: 8),
                Text(
                  method,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedInvoiceForm() {
    final canCreateInvoice = _selectedStudent != null;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long,
                      color: Colors.blue.shade700, size: 24),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Invoice',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Generate new invoice for student',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24),

            if (!canCreateInvoice) ...[
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 24),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Student Selected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Please search and select a student to create an invoice',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Course Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Course',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<Course>(
                      value: _selectedCourse,
                      onChanged: (Course? course) {
                        setState(() {
                          _selectedCourse = course;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Choose a course...',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      items: courseController.courses.map((Course course) {
                        return DropdownMenuItem<Course>(
                          value: course,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.school,
                                    color: Colors.blue.shade700),
                              ),
                              SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      course.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '\$${course.price.toStringAsFixed(2)} per lesson',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Number of Lessons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Number of Lessons',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 12),
                        // ...existing code...
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextFormField(
                            controller: _lessonsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            onChanged: (value) {
                              // Add this onChanged callback to trigger UI update
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.attach_money,
                                  color: Colors.green.shade700),
                              SizedBox(width: 8),
                              Text(
                                _selectedCourse != null
                                    ? '\$${(_selectedCourse!.price * (int.tryParse(_lessonsController.text) ?? 1)).toStringAsFixed(2)}'
                                    : '\$${0.00}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Due Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due Date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: _invoiceDueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme:
                                    Theme.of(context).colorScheme.copyWith(
                                          primary: Colors.blue.shade600,
                                        ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (selectedDate != null) {
                          setState(() {
                            _invoiceDueDate = selectedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: Colors.blue.shade600),
                            SizedBox(width: 12),
                            Text(
                              DateFormat('MMM dd, yyyy')
                                  .format(_invoiceDueDate),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Spacer(),
                            Icon(Icons.arrow_drop_down,
                                color: Colors.grey.shade500),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32),

              // Create Invoice Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _createInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long,
                                color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Create Invoice',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum SnackbarType { success, error, info }
