// lib/screens/payments/pos_screen.dart
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

class _POSScreenState extends State<POSScreen> {
  final BillingController billingController = Get.find();
  final UserController userController = Get.find();
  final CourseController courseController = Get.find();

  // Screen responsiveness
  bool get _isMobile => MediaQuery.of(context).size.width < 768;
  bool get _isTablet =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1024;

  EdgeInsets get _responsivePadding => EdgeInsets.all(_isMobile ? 16 : 24);
  double get _responsiveFontSize => _isMobile ? 16 : 14;

  // Student Selection
  final TextEditingController _studentSearchController =
      TextEditingController();
  final FocusNode _studentSearchFocus = FocusNode();
  User? _selectedStudent;
  List<User> _studentSearchResults = [];
  bool _showStudentResults = false;

  // Shopping Cart
  final List<CartItem> _cartItems = [];
  double get _cartTotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  // Payment
  String _paymentMethod = 'Cash';
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _studentSearchController.addListener(_onStudentSearchChanged);
    // Load users when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _studentSearchFocus.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Load users if not already loaded
  void _loadUsers() async {
    try {
      if (userController.users.isEmpty) {
        await userController.fetchUsers(); // Assuming this method exists
        print('Loaded ${userController.users.length} users');
      } else {
        print('Users already loaded: ${userController.users.length}');
      }
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  void _onStudentSearchChanged() {
    final query = _studentSearchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _studentSearchResults.clear();
        _showStudentResults = false;
      });
      return;
    }

    print('Searching for: "$query"');
    print('Total users available: ${userController.users.length}');

    // Get all users first
    final allUsers = userController.users;

    if (allUsers.isEmpty) {
      print('No users loaded yet, attempting to load...');
      _loadUsers();
      return;
    }

    // Filter for students first
    final allStudents = allUsers.where((user) {
      final role = user.role?.toLowerCase() ?? '';
      return role == 'student';
    }).toList();

    print('Found ${allStudents.length} students total');

    // Then filter by search query
    final matchingStudents = allStudents
        .where((user) {
          final queryLower = query.toLowerCase();

          // Get user fields safely
          final firstName = user.fname?.toLowerCase() ?? '';
          final lastName = user.lname?.toLowerCase() ?? '';
          final fullName = '$firstName $lastName'.trim();
          final email = user.email?.toLowerCase() ?? '';
          final phone = user.phone ?? '';
          final idNumber = user.idnumber?.toLowerCase() ?? '';

          // Check all possible matches
          final matches = fullName.contains(queryLower) ||
              firstName.contains(queryLower) ||
              lastName.contains(queryLower) ||
              email.contains(queryLower) ||
              phone.contains(query) ||
              idNumber.contains(queryLower);

          return matches;
        })
        .take(5)
        .toList();

    print('Final matching students: ${matchingStudents.length}');

    setState(() {
      _studentSearchResults = matchingStudents;
      _showStudentResults = matchingStudents.isNotEmpty;
    });
  }

  void _selectStudent(User student) {
    setState(() {
      _selectedStudent = student;
      _studentSearchController.text =
          '${student.fname ?? ''} ${student.lname ?? ''}'.trim();
      _showStudentResults = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _addToCart(Course course, {int quantity = 1}) {
    setState(() {
      final existingIndex =
          _cartItems.indexWhere((item) => item.course.id == course.id);
      if (existingIndex >= 0) {
        _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
          quantity: _cartItems[existingIndex].quantity + quantity,
        );
      } else {
        _cartItems.add(CartItem(
          course: course,
          quantity: quantity,
          pricePerUnit: course.price.toDouble(),
        ));
      }
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${course.name} added to cart'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _updateCartQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(index);
      return;
    }
    setState(() {
      _cartItems[index] = _cartItems[index].copyWith(quantity: newQuantity);
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
    });
  }

  Future<void> _processTransaction({bool payNow = true}) async {
    if (_selectedStudent == null) {
      _showError('Please select a student');
      return;
    }
    if (_cartItems.isEmpty) {
      _showError('Please add items to cart');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (payNow) {
        // Process payment immediately
        await _processPayment();
      } else {
        // Create invoice only
        await _createInvoiceOnly();
      }

      _showSuccess(payNow
          ? 'Payment processed successfully!'
          : 'Invoice created successfully!');
      _clearAll();
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processPayment() async {
    for (final item in _cartItems) {
      // Create invoice data (without setting ID - let database auto-increment)
      final invoiceNumber =
          'INV-${DateTime.now().toUtc().millisecondsSinceEpoch}';

      final invoice = Invoice(
        studentId: _selectedStudent!.id!,
        courseId: item.course.id!,
        invoiceNumber: invoiceNumber,
        totalAmount: item.totalPrice,
        pricePerLesson: item.course.price.toDouble(),
        amountPaid: item.totalPrice,
        dueDate: DateTime.now(),
        status: 'paid',
        createdAt: DateTime.now(),
        lessons: item.quantity,
      );

      print(
          'Creating invoice: $invoiceNumber for ${item.course.name} x${item.quantity}');

      // Save invoice and capture the database-assigned ID
      await billingController.createInvoice(invoice);

      // Since createInvoice doesn't return the ID, we need to get the latest invoice
      // by finding the one we just created using the unique invoice number
      await billingController.fetchBillingData(); // Refresh to get latest data

      final createdInvoice = billingController.invoices.firstWhere(
          (inv) => inv.invoiceNumber == invoiceNumber,
          orElse: () => throw Exception(
              'Failed to find created invoice: $invoiceNumber'));

      print('Found created invoice with database ID: ${createdInvoice.id}');

      // Generate reference for payment
      final reference = 'POS-${DateTime.now().toUtc().millisecondsSinceEpoch}';

      // Create payment with the correct database-assigned invoice ID
      final payment = Payment(
        invoiceId: createdInvoice
            .id!, // Use the actual database ID, not the invoice number!
        amount: item.totalPrice,
        method: _convertPaymentMethod(_paymentMethod),
        paymentDate: DateTime.now(),
        notes: _notesController.text.trim().isEmpty
            ? 'POS Payment'
            : _notesController.text.trim(),
        reference: reference,
        receiptGenerated: false,
        userId: _selectedStudent!.id!,
      );

      print('Creating payment with correct database invoice ID:');
      print('- InvoiceId (DB ID): ${payment.invoiceId}');
      print('- Amount: ${payment.amount}');
      print('- Method: ${payment.method}');
      print('- Reference: ${payment.reference}');
      print('- Notes: ${payment.notes}');
      print('- UserId: ${payment.userId}');

      // Record the payment
      await billingController.recordPayment(payment);

      print('Payment recorded successfully for invoice ${createdInvoice.id}');
    }
  }

  Future<void> _createInvoiceOnly() async {
    for (final item in _cartItems) {
      final invoice = Invoice(
        studentId: _selectedStudent!.id!,
        courseId: item.course.id!,
        invoiceNumber: 'INV-${DateTime.now().toUtc().millisecondsSinceEpoch}',
        totalAmount: item.totalPrice,
        pricePerLesson: item.course.price.toDouble(),
        amountPaid: 0.0,
        dueDate: DateTime.now().add(Duration(days: 30)),
        status: 'pending',
        createdAt: DateTime.now(),
        lessons: item.quantity,
      );

      await billingController.createInvoice(invoice);

      print('Invoice created successfully: ${invoice.invoiceNumber}');
    }
  }

  // Helper method to convert payment method to backend format
  String _convertPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'cash';
      case 'card':
        return 'card';
      case 'bank transfer':
        return 'bank_transfer';
      case 'mobile money':
        return 'mobile_payment';
      default:
        return method.toLowerCase().replaceAll(' ', '_');
    }
  }

  void _clearAll() {
    setState(() {
      _selectedStudent = null;
      _studentSearchController.clear();
      _cartItems.clear();
      _notesController.clear();
      _paymentMethod = 'Cash';
      _showStudentResults = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('POS System'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_cartItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: _clearCart,
              tooltip: 'Clear Receipt',
            ),
        ],
      ),
      body: _isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Student Selection Card
        _buildStudentSelectionCard(),

        // Cart Summary (Compact)
        if (_cartItems.isNotEmpty) _buildMobileCartSummary(),

        // Course Catalog
        Expanded(
          child: _buildCourseCatalog(),
        ),

        // Bottom Action Panel
        _buildMobileActionPanel(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Panel - Student & Catalog
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildStudentSelectionCard(),
              Expanded(child: _buildCourseCatalog()),
            ],
          ),
        ),

        // Right Panel - Cart & Payment
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(left: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              Expanded(child: _buildCartPanel()),
              _buildPaymentPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentSelectionCard() {
    final studentCount = userController.users
        .where((u) => u.role?.toLowerCase() == 'student')
        .length;

    return Container(
      margin: _responsivePadding,
      padding: _responsivePadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Select Student',
                style: TextStyle(
                  fontSize: _responsiveFontSize + 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Main search field
          TextFormField(
            controller: _studentSearchController,
            focusNode: _studentSearchFocus,
            decoration: InputDecoration(
              hintText: 'Search student by name, email, or phone...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _selectedStudent != null
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedStudent = null;
                          _studentSearchController.clear();
                          _showStudentResults = false;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Search results dropdown (NOT positioned, but in normal flow)
          if (_showStudentResults)
            Container(
              margin: EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              constraints: BoxConstraints(maxHeight: 200),
              child: _studentSearchResults.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No students found',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _studentSearchResults.length,
                      separatorBuilder: (_, __) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final student = _studentSearchResults[index];
                        final initials =
                            '${student.fname?[0] ?? ''}${student.lname?[0] ?? ''}';
                        final fullName =
                            '${student.fname ?? ''} ${student.lname ?? ''}'
                                .trim();

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(initials.toUpperCase()),
                            backgroundColor: Colors.blue.shade100,
                          ),
                          title: Text(fullName.isNotEmpty
                              ? fullName
                              : 'Unknown Student'),
                          subtitle: Text(student.email ?? 'No email'),
                          onTap: () => _selectStudent(student),
                          dense: true,
                          hoverColor: Colors.blue.shade50,
                        );
                      },
                    ),
            ),

          // Selected student info
          if (_selectedStudent != null) _buildSelectedStudentInfo(),
        ],
      ),
    );
  }

  // Remove the old _buildStudentSearchResults method since we're now inlining it

  Widget _buildSelectedStudentInfo() {
    final initials =
        '${_selectedStudent!.fname?[0] ?? ''}${_selectedStudent!.lname?[0] ?? ''}';
    final fullName =
        '${_selectedStudent!.fname ?? ''} ${_selectedStudent!.lname ?? ''}'
            .trim();

    return Container(
      margin: EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(initials.toUpperCase()),
            backgroundColor: Colors.green.shade200,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isNotEmpty ? fullName : 'Selected Student',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _selectedStudent!.email ?? 'No email',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildCourseCatalog() {
    return Container(
      margin: _responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Courses Catalog',
            style: TextStyle(
              fontSize: _responsiveFontSize + 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _isMobile ? 1 : 2,
                childAspectRatio: _isMobile ? 4.5 : 3.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: courseController.courses.length,
              itemBuilder: (context, index) {
                final course = courseController.courses[index];
                return _buildCourseCard(course);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _addToCart(course),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.school, color: Colors.blue.shade700, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      course.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _responsiveFontSize,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '\$${course.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: _responsiveFontSize + 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: Colors.green.shade700, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCartSummary() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_cart, color: Colors.orange.shade700),
          SizedBox(width: 8),
          Text(
            '${_cartItems.length} items • \$${_cartTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
          Spacer(),
          TextButton(
            onPressed: () => _showCartBottomSheet(),
            child: Text('VIEW CART'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActionPanel() {
    if (_cartItems.isEmpty || _selectedStudent == null) {
      return Container(
        padding: _responsivePadding,
        child: Text(
          _selectedStudent == null
              ? 'Please select a student and add items to cart'
              : 'Add items to cart to continue',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Container(
      padding: _responsivePadding,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          // Payment Method Selection
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: InputDecoration(
              labelText: 'Payment Method',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: ['Cash', 'Card', 'Bank Transfer', 'Mobile Money']
                .map((method) =>
                    DropdownMenuItem(value: method, child: Text(method)))
                .toList(),
            onChanged: (value) => setState(() => _paymentMethod = value!),
          ),
          SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _processTransaction(payNow: false),
                  icon: Icon(Icons.receipt),
                  label: Text('INVOICE ONLY'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _processTransaction(payNow: true),
                  icon: _isProcessing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ))
                      : Icon(Icons.payment),
                  label: Text('PAY NOW'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel() {
    return Container(
      padding: _responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receipt',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          if (_cartItems.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Receipt is empty',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _cartItems.length,
                separatorBuilder: (_, __) => Divider(),
                itemBuilder: (context, index) {
                  final item = _cartItems[index];
                  return _buildCartItem(item, index);
                },
              ),
            ),
          if (_cartItems.isNotEmpty) ...[
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${_cartTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, int index) {
    final TextEditingController quantityController =
        TextEditingController(text: item.quantity.toString());

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.course.name,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '\$${item.pricePerUnit.toStringAsFixed(2)} each',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        Row(
          children: [
            // Minus Button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                onPressed: () => _updateCartQuantity(index, item.quantity - 1),
                icon: Icon(Icons.remove, size: 16),
                padding: EdgeInsets.zero,
              ),
            ),

            // Quantity Input Field
            Container(
              width: 60,
              height: 32,
              margin: EdgeInsets.symmetric(horizontal: 4),
              child: TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  isDense: true,
                ),
                onChanged: (value) {
                  final newQuantity = int.tryParse(value) ?? item.quantity;
                  if (newQuantity != item.quantity && newQuantity > 0) {
                    _updateCartQuantity(index, newQuantity);
                  }
                },
                onEditingComplete: () {
                  final newQuantity =
                      int.tryParse(quantityController.text) ?? item.quantity;
                  _updateCartQuantity(index, newQuantity);
                  FocusScope.of(context).unfocus();
                },
              ),
            ),

            // Plus Button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                onPressed: () => _updateCartQuantity(index, item.quantity + 1),
                icon: Icon(Icons.add, size: 16),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        SizedBox(width: 8),
        Text(
          '\$${item.totalPrice.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: () => _removeFromCart(index),
          icon: Icon(Icons.delete_outline, color: Colors.red),
          iconSize: 20,
        ),
      ],
    );
  }

  Widget _buildPaymentPanel() {
    if (_selectedStudent == null || _cartItems.isEmpty) {
      return Container(
        padding: _responsivePadding,
        child: Text(
          'Select student and add items to proceed',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Container(
      padding: _responsivePadding,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Options',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: InputDecoration(
              labelText: 'Payment Method',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: ['Cash', 'Card', 'Bank Transfer', 'Mobile Money']
                .map((method) =>
                    DropdownMenuItem(value: method, child: Text(method)))
                .toList(),
            onChanged: (value) => setState(() => _paymentMethod = value!),
          ),
          SizedBox(height: 12),

          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: 2,
          ),
          SizedBox(height: 20),

          // Action Buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _processTransaction(payNow: false),
                  icon: Icon(Icons.receipt),
                  label: Text('CREATE INVOICE ONLY'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _processTransaction(payNow: true),
                  icon: _isProcessing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ))
                      : Icon(Icons.payment),
                  label: Text('PROCESS PAYMENT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Text('Shopping Cart',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildCartPanel()),
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _processTransaction(payNow: false);
                      },
                      child: Text('INVOICE ONLY'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _processTransaction(payNow: true);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                      child: Text('PAY NOW'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Classes
class CartItem {
  final Course course;
  final int quantity;
  final double pricePerUnit;

  CartItem({
    required this.course,
    required this.quantity,
    required this.pricePerUnit,
  });

  double get totalPrice => quantity * pricePerUnit;

  CartItem copyWith({
    Course? course,
    int? quantity,
    double? pricePerUnit,
  }) {
    return CartItem(
      course: course ?? this.course,
      quantity: quantity ?? this.quantity,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
    );
  }
}
