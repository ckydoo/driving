// lib/screens/payments/enhanced_pos_screen.dart
import 'package:driving/services/receipt_service.dart';
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
  final List<double> _quickAmounts = [20.0];
  final GlobalKey<FormState> _paymentFormKey = GlobalKey<FormState>();
  String? _paymentAmountError;
  bool _isFormValid = false; // ADD THIS FOR BUTTON STATE

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
    _setupKeyboardShortcuts();
    _loadRecentStudents();
    _paymentAmountError = null;
  }

  // Helper method to get screen breakpoints
  bool get _isMobile => MediaQuery.of(context).size.width < 768;
  bool get _isTablet =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1024;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  // Responsive padding
  EdgeInsets get _responsivePadding {
    if (_isMobile) return EdgeInsets.all(8);
    if (_isTablet) return EdgeInsets.all(16);
    return EdgeInsets.all(20);
  }

  // Responsive text scaling
  double get _textScaleFactor {
    if (_isMobile) return 0.85;
    if (_isTablet) return 0.95;
    return 1.0;
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
    _slideAnimation =
        Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
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
    _notesController.dispose();
    _amountFocusNode.dispose();
    _lessonsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await userController.fetchUsers();
    await billingController.fetchBillingData();
    await courseController.fetchCourses();
  }

  void _loadRecentStudents() {
    // Load recently processed students
    _recentStudents = userController.users
        .where((user) => user.role.toLowerCase() == 'student')
        .take(5)
        .toList();
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

  // EXACT COPY from student_details_screen.dart _buildBillingTab method
  double _getStudentBalance(User student) {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();

    final totalBalance = studentInvoices.fold<double>(
        0.0, (sum, invoice) => sum + invoice.balance);

    return totalBalance;
  }

  // EXACT COPY from payment_dialog.dart logic
  List<Invoice> _getStudentInvoices(User student) {
    return billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();
  }

  // EXACT COPY from payment_dialog.dart - filter unpaid invoices
  List<Invoice> _getUnpaidInvoices(User student) {
    return billingController.invoices
        .where(
            (invoice) => invoice.studentId == student.id && invoice.balance > 0)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: _textScaleFactor,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildEnhancedAppBar(),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Mobile layout - single column with tabs
                  if (_isMobile) {
                    return _buildMobileLayout();
                  }
                  // Tablet and Desktop layout - side by side panels
                  else {
                    return _buildDesktopTabletLayout(constraints);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Operation Mode Tabs
        Container(
          color: Colors.grey[50],
          child: Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  'Payment',
                  'Process payments quickly',
                  Icons.payment,
                  'payment',
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildModeButton(
                  'Invoice',
                  'Create new invoices',
                  Icons.receipt,
                  'invoice',
                  Colors.blue,
                ),
              ),
            ],
          ),
        ),
        // Main Content
        Expanded(
          child: SingleChildScrollView(
            padding: _responsivePadding,
            child: Column(
              children: [
                _buildStudentPanel(),
                SizedBox(height: 16),
                _buildOperationForm(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTabletLayout(BoxConstraints constraints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel - Student Search & Selection
        Container(
          width: _isTablet
              ? constraints.maxWidth * 0.4
              : constraints.maxWidth * 0.35,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              // Operation Mode Selector
              Container(
                padding: _responsivePadding,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeButton(
                        'Payment',
                        'Process payments',
                        Icons.payment,
                        'payment',
                        Colors.green,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildModeButton(
                        'Invoice',
                        'Create invoices',
                        Icons.receipt,
                        'invoice',
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: _responsivePadding,
                  child: _buildStudentPanel(),
                ),
              ),
            ],
          ),
        ),
        // Right Panel - Operation Form
        Expanded(
          child: Container(
            padding: _responsivePadding,
            child: _buildOperationsPanel(),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildEnhancedAppBar() {
    return AppBar(
      title: _isMobile
          ? Text('Make Payments & Billing',
              style: TextStyle(fontWeight: FontWeight.bold))
          : Row(
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
        if (!_isMobile)
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

  Widget _buildModeButton(
      String title, String subtitle, IconData icon, String mode, Color color) {
    final isSelected = _operationMode == mode;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _operationMode = mode),
          child: Container(
            padding: EdgeInsets.all(_isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(_isMobile ? 8 : 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: _isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _isMobile ? 14 : 16,
                    color: isSelected ? color : Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!_isMobile) ...[
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
              ],
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
        SizedBox(height: 16),
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
            padding: _responsivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.search, color: Colors.blue.shade600),
                    SizedBox(width: 8),
                    Text(
                      'Find Student',
                      style: TextStyle(
                        fontSize: _isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Spacer(),
                    if (_selectedStudent != null)
                      IconButton(
                        icon: Icon(Icons.close, size: 20),
                        onPressed: () => setState(() {
                          _selectedStudent = null;
                          _searchController.clear();
                        }),
                        constraints:
                            BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or phone...',
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                    onChanged: _searchStudents,
                    textInputAction: TextInputAction.search,
                  ),
                ),
              ],
            ),
          ),
          if (_showSearchResults && _searchResults.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final student = _searchResults[index];
                  return _buildStudentListTile(student);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentListTile(User student) {
    final balance = _getStudentBalance(student);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectStudent(student),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _responsivePadding.horizontal,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: _isMobile ? 20 : 24,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  student.fname[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: _isMobile ? 14 : 16,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.fname} ${student.lname}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: _isMobile ? 14 : 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (student.email.isNotEmpty)
                      Text(
                        student.email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: _isMobile ? 12 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (balance > 0)
                      Text(
                        'Balance: \$${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: _isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: _isMobile ? 16 : 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    if (_selectedStudent == null) return SizedBox.shrink();

    final balance = _getStudentBalance(_selectedStudent!);
    final invoices = _getStudentInvoices(_selectedStudent!);
    final unpaidInvoices = _getUnpaidInvoices(_selectedStudent!);

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
      padding: _responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: _isMobile ? 25 : 30,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  _selectedStudent!.fname[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: _isMobile ? 18 : 22,
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
                        fontSize: _isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (_selectedStudent!.email.isNotEmpty)
                      Text(
                        _selectedStudent!.email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: _isMobile ? 12 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (_selectedStudent!.phone.isNotEmpty)
                      Text(
                        _selectedStudent!.phone,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: _isMobile ? 12 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Balance and Invoice Summary
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: balance > 0 ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding Balance',
                      style: TextStyle(
                        fontSize: _isMobile ? 12 : 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '\$${balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: _isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: balance > 0
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Unpaid Invoices',
                      style: TextStyle(
                        fontSize: _isMobile ? 12 : 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${unpaidInvoices.length}',
                      style: TextStyle(
                        fontSize: _isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStudentsCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: _responsivePadding,
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.grey.shade600),
                SizedBox(width: 8),
                Text(
                  'Recent Students',
                  style: TextStyle(
                    fontSize: _isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _recentStudents.take(3).length,
              itemBuilder: (context, index) {
                final student = _recentStudents[index];
                return _buildStudentListTile(student);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsPanel() {
    return Column(
      children: [
        Expanded(child: _buildOperationForm()),
      ],
    );
  }

  Widget _buildOperationForm() {
    if (_currentStep == 'processing') {
      return _buildProcessingScreen();
    } else if (_currentStep == 'success') {
      return _buildSuccessScreen();
    } else if (_operationMode == 'payment') {
      return SingleChildScrollView(child: _buildEnhancedPaymentForm());
    } else {
      return SingleChildScrollView(child: _buildEnhancedInvoiceForm());
    }
  }

  Widget _buildProcessingScreen() {
    return Container(
      padding: _responsivePadding.add(EdgeInsets.all(_isMobile ? 20 : 40)),
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
            width: _isMobile ? 60 : 80,
            height: _isMobile ? 60 : 80,
            child: CircularProgressIndicator(
              strokeWidth: _isMobile ? 4 : 6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          SizedBox(height: _isMobile ? 24 : 32),
          Text(
            'Processing ${_operationMode == 'payment' ? 'Payment' : 'Invoice'}...',
            style: TextStyle(
              fontSize: _isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: _isMobile ? 12 : 16),
          Text(
            'Please wait while we process your transaction',
            style: TextStyle(
              fontSize: _isMobile ? 14 : 16,
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
      padding: _responsivePadding.add(EdgeInsets.all(_isMobile ? 20 : 40)),
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
            width: _isMobile ? 60 : 80,
            height: _isMobile ? 60 : 80,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              color: Colors.green.shade600,
              size: _isMobile ? 30 : 40,
            ),
          ),
          SizedBox(height: _isMobile ? 24 : 32),
          Text(
            '${_operationMode == 'payment' ? 'Payment' : 'Invoice'} Completed!',
            style: TextStyle(
              fontSize: _isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: _isMobile ? 12 : 16),
          Text(
            _operationMode == 'payment'
                ? 'Payment has been processed successfully'
                : 'Invoice has been created successfully',
            style: TextStyle(
              fontSize: _isMobile ? 14 : 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: _isMobile ? 24 : 32),
          SizedBox(
            width: double.infinity,
            height: _isMobile ? 48 : 56,
            child: ElevatedButton(
              onPressed: () => _clearAll(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'New Transaction',
                style: TextStyle(
                  fontSize: _isMobile ? 16 : 18,
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

  Widget _buildQuickAmountChip(double amount, {bool isBalance = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _paymentAmountController.text = amount.toStringAsFixed(2),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 12 : 16,
            vertical: _isMobile ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: isBalance ? Colors.green.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isBalance ? Colors.green.shade200 : Colors.blue.shade200,
            ),
          ),
          child: Text(
            isBalance
                ? 'Full Balance (\$${amount.toStringAsFixed(2)})'
                : '\$${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: isBalance ? Colors.green.shade700 : Colors.blue.shade700,
              fontWeight: FontWeight.w600,
              fontSize: _isMobile ? 12 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedInvoiceForm() {
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
      padding: _responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt, color: Colors.blue.shade700),
              ),
              SizedBox(width: 12),
              Text(
                'Create Invoice',
                style: TextStyle(
                  fontSize: _isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: _isMobile ? 16 : 24),

          if (_selectedStudent == null)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange.shade600),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select a student to create invoice',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: _isMobile ? 14 : 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Course Selection
            Text(
              'Course',
              style: TextStyle(
                fontSize: _isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonFormField<Course>(
                value: _selectedCourse,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: 'Select a course...',
                ),
                items: courseController.courses
                    .map((course) => DropdownMenuItem(
                          value: course,
                          child: Text(
                            course.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCourse = value),
                isExpanded: true,
              ),
            ),
            SizedBox(height: _isMobile ? 16 : 20),

            // Lessons Count
            Text(
              'Number of Lessons',
              style: TextStyle(
                fontSize: _isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _lessonsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: '1',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                ),
                style: TextStyle(
                  fontSize: _isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: _isMobile ? 16 : 20),

            // Total Amount Preview
            if (_selectedCourse != null)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: _isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$${(_selectedCourse!.price * (int.tryParse(_lessonsController.text) ?? 1)).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: _isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),

            if (_selectedCourse != null) SizedBox(height: _isMobile ? 16 : 20),

            // Due Date
            Text(
              'Due Date',
              style: TextStyle(
                fontSize: _isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _selectDueDate,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue.shade600),
                      SizedBox(width: 12),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_invoiceDueDate),
                        style: TextStyle(
                          fontSize: _isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_drop_down, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: _isMobile ? 24 : 32),

            // Create Invoice Button
            SizedBox(
              width: double.infinity,
              height: _isMobile ? 48 : 56,
              child: ElevatedButton(
                onPressed: _isProcessing || _selectedCourse == null
                    ? null
                    : _createInvoice,
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
                              color: Colors.white, size: _isMobile ? 20 : 24),
                          SizedBox(width: 12),
                          Text(
                            'Create Invoice',
                            style: TextStyle(
                              fontSize: _isMobile ? 16 : 18,
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
    );
  }

  // Methods for handling user interactions
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
            (user.phone.contains(query)) ||
            (user.idnumber?.toLowerCase().contains(query.toLowerCase()) ??
                false))
        .take(10)
        .toList();

    setState(() {
      _searchResults = students;
      _showSearchResults = true;
    });
  }

  bool _canProcessPayment() {
    // Basic requirements
    if (_selectedStudent == null || _isProcessing) {
      return false;
    }

    // Check if amount is entered
    if (_paymentAmountController.text.isEmpty) {
      return false;
    }

    // Validate amount
    final amount = double.tryParse(_paymentAmountController.text);
    if (amount == null || amount <= 0) {
      return false;
    }

    // Check balance
    final balance = _getStudentBalance(_selectedStudent!);
    if (amount > balance) {
      return false;
    }

    // Check if student has any balance to pay
    if (balance <= 0) {
      return false;
    }

    // Form validation
    if (_paymentFormKey.currentState?.validate() != true) {
      return false;
    }

    return true;
  }

// 3. UPDATE YOUR PROCESS PAYMENT BUTTON WITH SMART STATE:
  Widget _buildProcessPaymentButton() {
    final canProcess = _canProcessPayment();
    final buttonColor =
        canProcess ? Colors.green.shade600 : Colors.grey.shade400;

    return SizedBox(
      width: double.infinity,
      height: _isMobile ? 48 : 56,
      child: ElevatedButton(
        onPressed: canProcess ? _processPayment : null, // SMART DISABLE
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canProcess ? 2 : 0,
          disabledBackgroundColor: Colors.grey.shade300, // DISABLED STYLE
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
                  Icon(
                    Icons.payment,
                    color: canProcess ? Colors.white : Colors.grey.shade600,
                    size: _isMobile ? 20 : 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    _getButtonText(),
                    style: TextStyle(
                      fontSize: _isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: canProcess ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

// 4. ADD METHOD TO GET DYNAMIC BUTTON TEXT:
  String _getButtonText() {
    if (_selectedStudent == null) {
      return 'Select Student First';
    }

    if (_paymentAmountController.text.isEmpty) {
      return 'Enter Payment Amount';
    }

    final amount = double.tryParse(_paymentAmountController.text);
    if (amount == null || amount <= 0) {
      return 'Enter Valid Amount';
    }

    final balance = _getStudentBalance(_selectedStudent!);
    if (balance <= 0) {
      return 'No Outstanding Balance';
    }

    if (amount > balance) {
      return 'Amount Exceeds Balance';
    }

    return 'Process Payment';
  }

// 5. UPDATE _buildPaymentAmountSection TO TRIGGER VALIDATION:
  Widget _buildPaymentAmountSection(double balance) {
    final currentAmount = double.tryParse(_paymentAmountController.text) ?? 0.0;
    final isExceeding = currentAmount > balance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with balance info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment Amount',
              style: TextStyle(
                fontSize: _isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: balance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      balance > 0 ? Colors.red.shade200 : Colors.green.shade200,
                ),
              ),
              child: Text(
                'Balance: \$${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),

        // Payment amount input with validation
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExceeding
                  ? Colors.red.shade400
                  : _paymentAmountError != null
                      ? Colors.red.shade400
                      : Colors.grey.shade300,
              width: isExceeding || _paymentAmountError != null ? 2 : 1,
            ),
          ),
          child: TextFormField(
            controller: _paymentAmountController,
            focusNode: _amountFocusNode,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '\$ ',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              prefixStyle: TextStyle(
                fontSize: _isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: isExceeding ? Colors.red.shade700 : Colors.grey[800],
              ),
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
            style: TextStyle(
              fontSize: _isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: isExceeding ? Colors.red.shade700 : Colors.grey[800],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter payment amount';
              }

              final amount = double.tryParse(value);
              if (amount == null) {
                return 'Please enter a valid number';
              }

              if (amount <= 0) {
                return 'Amount must be greater than zero';
              }

              if (_selectedStudent != null && amount > balance) {
                return 'Amount cannot exceed balance (\$${balance.toStringAsFixed(2)})';
              }

              return null;
            },
            onChanged: (value) {
              setState(() {
                _paymentAmountError = null;
                // TRIGGER BUTTON STATE UPDATE
                _isFormValid =
                    _paymentFormKey.currentState?.validate() ?? false;
              });
            },
          ),
        ),

        // Show error message if validation fails
        if (_paymentAmountError != null) ...[
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade600, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _paymentAmountError!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Show visual warning if exceeding balance
        if (_selectedStudent != null && isExceeding && currentAmount > 0) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red.shade600, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount Exceeds Balance',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Payment exceeds balance by \$${(currentAmount - balance).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Please reduce the amount to continue',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Show helpful info if balance is 0
        if (_selectedStudent != null && balance == 0) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This student has no outstanding balance',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

// 6. UPDATE _buildEnhancedPaymentForm TO USE NEW BUTTON:
  Widget _buildEnhancedPaymentForm() {
    final balance =
        _selectedStudent != null ? _getStudentBalance(_selectedStudent!) : 0.0;

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
      padding: _responsivePadding,
      child: Form(
        key: _paymentFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.payment, color: Colors.green.shade700),
                ),
                SizedBox(width: 12),
                Text(
                  'Process Payment',
                  style: TextStyle(
                    fontSize: _isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: _isMobile ? 16 : 24),

            if (_selectedStudent == null)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade600),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please select a student to process payment',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: _isMobile ? 14 : 16,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              _buildPaymentAmountSection(balance),
              SizedBox(height: _isMobile ? 12 : 16),

              // Quick Amount Buttons
              Text(
                'Quick Amounts',
                style: TextStyle(
                  fontSize: _isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._quickAmounts
                      .map((amount) => _buildQuickAmountChip(amount)),
                  if (balance > 0)
                    _buildQuickAmountChip(balance, isBalance: true),
                ],
              ),
              SizedBox(height: _isMobile ? 16 : 24),

              // Payment Method
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: _isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  items: ['Cash', 'Mobile Money']
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _paymentMethod = value!),
                ),
              ),
              SizedBox(height: _isMobile ? 16 : 24),

              // Receipt Option
              Row(
                children: [
                  Checkbox(
                    value: _generateReceipt,
                    onChanged: (value) =>
                        setState(() => _generateReceipt = value!),
                    activeColor: Colors.blue.shade600,
                  ),
                  Expanded(
                    child: Text(
                      'Generate receipt',
                      style: TextStyle(
                        fontSize: _isMobile ? 14 : 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _isMobile ? 24 : 32),

              // SMART PROCESS PAYMENT BUTTON
              _buildProcessPaymentButton(),
            ],
          ],
        ),
      ),
    );
  }

// 7. UPDATE _selectStudent TO TRIGGER BUTTON STATE UPDATE:
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

    // Use EXACT same balance calculation as student details screen
    final balance = _getStudentBalance(student);
    if (balance > 0) {
      _paymentAmountController.text = balance.toStringAsFixed(2);
    }

    // TRIGGER BUTTON STATE UPDATE
    setState(() {
      _isFormValid = _paymentFormKey.currentState?.validate() ?? false;
    });
  }

// 4. UPDATED _processPayment METHOD WITH VALIDATION:
  void _processPayment() async {
    if (_selectedStudent == null || _paymentAmountController.text.isEmpty) {
      _showEnhancedSnackbar('Please select a student and enter payment amount',
          SnackbarType.error);
      return;
    }

    // VALIDATE FORM FIRST
    if (!_paymentFormKey.currentState!.validate()) {
      _showEnhancedSnackbar('Please fix the errors above', SnackbarType.error);
      return;
    }

    final amount = double.tryParse(_paymentAmountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _paymentAmountError = 'Please enter a valid payment amount';
      });
      _showEnhancedSnackbar(
          'Please enter a valid payment amount', SnackbarType.error);
      return;
    }

    // DOUBLE CHECK AGAINST CURRENT BALANCE
    final currentBalance = _getStudentBalance(_selectedStudent!);
    if (amount > currentBalance) {
      setState(() {
        _paymentAmountError =
            'Amount cannot exceed balance (\$${currentBalance.toStringAsFixed(2)})';
      });
      _showEnhancedSnackbar(
          'Payment amount (\$${amount.toStringAsFixed(2)}) cannot exceed outstanding balance (\$${currentBalance.toStringAsFixed(2)})',
          SnackbarType.error);
      return;
    }

    // CHECK IF BALANCE IS ZERO
    if (currentBalance == 0) {
      _showEnhancedSnackbar(
          'This student has no outstanding balance to pay', SnackbarType.error);
      return;
    }

    setState(() {
      _isProcessing = true;
      _currentStep = 'processing';
      _paymentAmountError = null; // Clear any errors
    });

    try {
      // Use EXACT same logic as payment dialog - filter unpaid invoices
      final unpaidInvoices = _getUnpaidInvoices(_selectedStudent!);

      if (unpaidInvoices.isEmpty) {
        throw Exception('No outstanding invoices found for this student');
      }

      // EXACT same sorting logic as payment dialog
      unpaidInvoices.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final invoice = unpaidInvoices.first;

      // EXACT same reference generation as payment dialog
      final reference = ReceiptService.generateReference();

      // EXACT same Payment object creation as payment dialog
      final payment = Payment(
        invoiceId: invoice.id!,
        amount: amount,
        method: _paymentMethod,
        paymentDate: DateTime.now(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        reference: reference,
        receiptGenerated: false,
        userId: userController.currentUser.value?.id ?? 1,
      );

      print('POS Payment details:');
      print('- Invoice ID: ${payment.invoiceId}');
      print('- Invoice Balance: ${invoice.balance}');
      print('- Payment Amount: ${payment.amount}');
      print('- Method: ${payment.method}');
      print('- Reference: ${payment.reference}');
      print('- Generate Receipt: $_generateReceipt');

      // Use EXACT same logic as payment dialog _processSingleInvoicePayment
      if (_generateReceipt) {
        print('Using recordPaymentWithReceipt...');
        await billingController.recordPaymentWithReceipt(
            payment, invoice, _selectedStudent!);
      } else {
        print('Using recordPayment...');
        await billingController.recordPayment(payment);
      }

      print('Payment processing completed successfully');

      setState(() {
        _currentStep = 'success';
      });

      _showEnhancedSnackbar(
        'Payment of \$${amount.toStringAsFixed(2)} processed successfully!',
        SnackbarType.success,
      );

      // Auto-clear after success
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) _clearAll();
      });
    } catch (e) {
      print('Payment processing error: $e');
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

// 5. UPDATE _clearAll METHOD TO RESET VALIDATION:
  void _clearAll() {
    setState(() {
      _selectedStudent = null;
      _paymentAmountController.clear();
      _notesController.clear();
      _searchController.clear();
      _showSearchResults = false;
      _currentStep = 'search';
      _operationMode = 'payment';
      _paymentMethod = 'Cash';
      _generateReceipt = true;
      _isProcessing = false;
      _paymentAmountError = null; // CLEAR VALIDATION ERRORS
    });
    _paymentFormKey.currentState?.reset(); // RESET FORM VALIDATION
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != _invoiceDueDate) {
      setState(() {
        _invoiceDueDate = picked;
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
      _currentStep = 'processing';
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

      setState(() {
        _currentStep = 'success';
      });

      _showEnhancedSnackbar(
        'Invoice created successfully for ${lessons} lesson(s)!',
        SnackbarType.success,
      );

      // Auto-clear after success
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) _clearAll();
      });
    } catch (e) {
      _showEnhancedSnackbar(
          'Error creating invoice: ${e.toString()}', SnackbarType.error);
      setState(() {
        _currentStep = 'invoice';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}

enum SnackbarType { success, error, info }
