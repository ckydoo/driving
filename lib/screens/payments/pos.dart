// lib/screens/billing/pos_screen.dart
import 'package:flutter/material.dart';
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

class _POSScreenState extends State<POSScreen> {
  final BillingController billingController = Get.find();
  final UserController userController = Get.find();
  final CourseController courseController = Get.find();

  // Search and Selection
  final TextEditingController _searchController = TextEditingController();
  User? _selectedStudent;
  List<User> _searchResults = [];

  // Invoice Creation
  Course? _selectedCourse;
  final TextEditingController _lessonsController =
      TextEditingController(text: '1');
  DateTime _invoiceDueDate = DateTime.now().add(Duration(days: 30));

  // Payment Processing
  final TextEditingController _paymentAmountController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'Cash';
  bool _generateReceipt = true;
  bool _isProcessing = false;

  // UI State
  String _operationMode = 'payment'; // 'payment' or 'invoice'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _lessonsController.dispose();
    _paymentAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await userController.fetchUsers();
    await billingController.fetchBillingData();
    await courseController.fetchCourses();
  }

  void _searchStudents(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
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
        .toList();

    setState(() {
      _searchResults = students;
    });
  }

  void _selectStudent(User student) {
    setState(() {
      _selectedStudent = student;
      _searchResults = [];
      _searchController.text = '${student.fname} ${student.lname}';
    });

    // Auto-set payment amount if student has balance
    final balance = _getStudentBalance(student);
    if (balance > 0) {
      _paymentAmountController.text = balance.toStringAsFixed(2);
    }
  }

  double _getStudentBalance(User student) {
    return billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .fold(0.0, (sum, invoice) => sum + invoice.balance);
  }

  List<Invoice> _getStudentInvoices(User student) {
    return billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();
  }

  int _getOverdueInvoicesCount(User student) {
    final now = DateTime.now();
    return billingController.invoices
        .where((invoice) =>
            invoice.studentId == student.id &&
            invoice.balance > 0 &&
            invoice.dueDate.isBefore(now))
        .length;
  }

  Future<void> _createInvoice() async {
    if (_selectedStudent == null || _selectedCourse == null) {
      _showErrorSnackbar('Please select a student and course');
      return;
    }

    final lessons = int.tryParse(_lessonsController.text);
    if (lessons == null || lessons <= 0) {
      _showErrorSnackbar('Please enter a valid number of lessons');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Use the generateInvoice method from BillingController
      await billingController.generateInvoice(
        studentId: _selectedStudent!.id!,
        courseId: _selectedCourse!.id!,
        lessons: lessons,
        pricePerLesson: _selectedCourse!.price.toDouble(),
      );

      _showSuccessSnackbar('Invoice created successfully');
      _clearInvoiceForm();
      setState(() {
        // Refresh student balance display
      });
    } catch (e) {
      _showErrorSnackbar('Failed to create invoice: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processPayment() async {
    if (_selectedStudent == null) {
      _showErrorSnackbar('Please select a student');
      return;
    }

    final amount = double.tryParse(_paymentAmountController.text);
    if (amount == null || amount <= 0) {
      _showErrorSnackbar('Please enter a valid payment amount');
      return;
    }

    final studentBalance = _getStudentBalance(_selectedStudent!);
    if (amount > studentBalance) {
      _showErrorSnackbar(
          'Payment amount cannot exceed student balance (\$${studentBalance.toStringAsFixed(2)})');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Get student's unpaid invoices sorted by date (oldest first)
      final unpaidInvoices = billingController.invoices
          .where((invoice) =>
              invoice.studentId == _selectedStudent!.id && invoice.balance > 0)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (unpaidInvoices.isEmpty) {
        _showErrorSnackbar('No outstanding invoices found for this student');
        return;
      }

      // Distribute payment across invoices (oldest first)
      double remainingAmount = amount;
      for (final invoice in unpaidInvoices) {
        if (remainingAmount <= 0) break;

        final paymentForInvoice = remainingAmount >= invoice.balance
            ? invoice.balance
            : remainingAmount;

        final payment = Payment(
          invoiceId: invoice.id!,
          amount: paymentForInvoice,
          method: _paymentMethod,
          paymentDate: DateTime.now(),
          notes: _notesController.text.trim().isEmpty
              ? 'POS Payment'
              : _notesController.text.trim(),
          reference: ReceiptService.generateReference(),
          receiptGenerated: false,
        );

        if (_generateReceipt) {
          await billingController.recordPaymentWithReceipt(
              payment, invoice, _selectedStudent!);
        } else {
          await billingController.recordPayment(payment);
        }

        remainingAmount -= paymentForInvoice;
      }

      await billingController.fetchBillingData(); // Refresh data

      _showSuccessSnackbar('Payment processed successfully');
      _clearPaymentForm();
      setState(() {
        // Refresh student balance display
      });
    } catch (e) {
      _showErrorSnackbar('Failed to process payment: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _clearInvoiceForm() {
    setState(() {
      _selectedCourse = null;
      _lessonsController.text = '1';
      _invoiceDueDate = DateTime.now().add(Duration(days: 30));
    });
  }

  void _clearPaymentForm() {
    setState(() {
      _paymentAmountController.clear();
      _notesController.clear();
      _paymentMethod = 'Cash';
      _generateReceipt = true;
    });
  }

  void _clearAll() {
    setState(() {
      _selectedStudent = null;
      _searchController.clear();
      _searchResults = [];
    });
    _clearInvoiceForm();
    _clearPaymentForm();
  }

  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      icon: Icon(Icons.check_circle, color: Colors.white),
    );
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade600,
      colorText: Colors.white,
      icon: Icon(Icons.error, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Point of Sale',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Panel - Student Selection and Info
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
    );
  }

  Widget _buildStudentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student Search
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Search',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or ID...',
                  prefixIcon: Icon(Icons.search, color: Colors.blue[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[600]!),
                  ),
                ),
                onChanged: _searchStudents,
              ),

              // Search Results
              if (_searchResults.isNotEmpty) ...[
                SizedBox(height: 10),
                Container(
                  constraints: BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final student = _searchResults[index];
                      final balance = _getStudentBalance(student);

                      return ListTile(
                        title: Text('${student.fname} ${student.lname}'),
                        subtitle: Text(student.email),
                        trailing: balance > 0
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '\$${balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : Icon(Icons.check_circle,
                                color: Colors.green, size: 20),
                        onTap: () => _selectStudent(student),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 20),

        // Selected Student Info
        if (_selectedStudent != null) _buildStudentInfo(),
      ],
    );
  }

  Widget _buildStudentInfo() {
    final student = _selectedStudent!;
    final balance = _getStudentBalance(student);
    final invoices = _getStudentInvoices(student);
    final overdueCount = _getOverdueInvoicesCount(student);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text(
                  '${student.fname[0]}${student.lname[0]}',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.fname} ${student.lname}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      student.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Balance Status
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: balance > 0 ? Colors.orange[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: balance > 0 ? Colors.orange[200]! : Colors.green[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  balance > 0
                      ? Icons.account_balance_wallet
                      : Icons.check_circle,
                  color: balance > 0 ? Colors.orange[700] : Colors.green[700],
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        balance > 0
                            ? 'Outstanding Balance'
                            : 'No Outstanding Balance',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: balance > 0
                              ? Colors.orange[800]
                              : Colors.green[800],
                        ),
                      ),
                      if (balance > 0) ...[
                        Text(
                          '\$${balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 15),

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Invoices',
                  invoices.length.toString(),
                  Icons.receipt,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Overdue',
                  overdueCount.toString(),
                  Icons.warning,
                  overdueCount > 0 ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsPanel() {
    return Column(
      children: [
        // Operation Mode Selector
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
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
              SizedBox(height: 15),
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
                  SizedBox(width: 15),
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
        ),

        SizedBox(height: 20),

        // Operation Form
        Expanded(
          child: _operationMode == 'payment'
              ? _buildPaymentForm()
              : _buildInvoiceForm(),
        ),
      ],
    );
  }

  Widget _buildModeButton(
      String title, String subtitle, IconData icon, String mode, Color color) {
    final isSelected = _operationMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _operationMode = mode),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 30,
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey[800],
              ),
            ),
            SizedBox(height: 5),
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
    );
  }

  Widget _buildPaymentForm() {
    final canProcessPayment =
        _selectedStudent != null && _getStudentBalance(_selectedStudent!) > 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Process Payment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 20),
          if (!canProcessPayment) ...[
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedStudent == null
                          ? 'Please select a student first'
                          : 'Student has no outstanding balance',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Payment Amount
            TextFormField(
              controller: _paymentAmountController,
              decoration: InputDecoration(
                labelText: 'Payment Amount (\$)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.attach_money, color: Colors.green[600]),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),

            SizedBox(height: 15),

            // Payment Method
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.payment, color: Colors.blue[600]),
              ),
              items: ['Cash', 'Card', 'Check', 'Bank Transfer']
                  .map((method) => DropdownMenuItem(
                        value: method,
                        child: Text(method),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _paymentMethod = value!),
            ),

            SizedBox(height: 15),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.note, color: Colors.grey[600]),
              ),
              maxLines: 2,
            ),

            SizedBox(height: 15),

            // Generate Receipt Checkbox
            CheckboxListTile(
              title: Text('Generate Receipt'),
              value: _generateReceipt,
              onChanged: (value) => setState(() => _generateReceipt = value!),
              controlAffinity: ListTileControlAffinity.leading,
            ),

            Spacer(),

            // Process Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
                    ? CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Process Payment',
                            style: TextStyle(
                              fontSize: 16,
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

  Widget _buildInvoiceForm() {
    final canCreateInvoice = _selectedStudent != null;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Invoice',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 20),
            if (!canCreateInvoice) ...[
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please select a student first',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 400), // Add spacing to push create button down
            ] else ...[
              // Course Selection
              Obx(() => DropdownButtonFormField<Course>(
                    value: _selectedCourse,
                    decoration: InputDecoration(
                      labelText: 'Select Course',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.book, color: Colors.blue[600]),
                    ),
                    items: courseController.courses
                        .map((course) => DropdownMenuItem(
                              value: course,
                              child: Text(
                                  '${course.name} - \$${course.price.toStringAsFixed(2)}'),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCourse = value),
                  )),

              SizedBox(height: 15),

              // Number of Lessons
              TextFormField(
                controller: _lessonsController,
                decoration: InputDecoration(
                  labelText: 'Number of Lessons',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.numbers, color: Colors.blue[600]),
                ),
                keyboardType: TextInputType.number,
              ),

              SizedBox(height: 15),

              // Due Date
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _invoiceDueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _invoiceDueDate = date);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon:
                        Icon(Icons.calendar_today, color: Colors.blue[600]),
                  ),
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(_invoiceDueDate),
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Invoice Preview
              if (_selectedCourse != null) ...[
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice Preview',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Course:'),
                          Text(_selectedCourse!.name),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Lessons:'),
                          Text(_lessonsController.text),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Price per lesson:'),
                          Text(
                              '\$${_selectedCourse!.price.toStringAsFixed(2)}'),
                        ],
                      ),
                      Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${(_selectedCourse!.price * (int.tryParse(_lessonsController.text) ?? 1)).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],

              SizedBox(height: 20),
            ],

            // Create Invoice Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (canCreateInvoice && !_isProcessing)
                    ? _createInvoice
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
                    ? CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Create Invoice',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
