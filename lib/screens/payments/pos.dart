// lib/screens/payments/pos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
      print('📥 Loading users...');
      await userController.fetchUsers();
      print('✅ Loaded ${userController.users.length} users successfully');

      // Debug: Show user roles after loading
      if (userController.users.isNotEmpty) {
        print('👥 User roles available:');
        final roleGroups = <String, int>{};
        for (final user in userController.users) {
          final role = user.role?.toLowerCase()?.trim() ?? 'null';
          roleGroups[role] = (roleGroups[role] ?? 0) + 1;
        }
        roleGroups.forEach((role, count) => print('  - "$role": $count users'));
      }
    } catch (e) {
      print('❌ Error loading users: $e');
      _showError('Failed to load users. Please try again.');
    }
  }

  // FIXED: Search results display issue - force UI update and better positioning
  void _onStudentSearchChanged() {
    final query = _studentSearchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _studentSearchResults.clear();
        _showStudentResults = false;
      });
      return;
    }

    print('🔍 Searching for: "$query"');

    final allUsers = userController.users;
    if (allUsers.isEmpty) {
      _loadUsers();
      return;
    }

    // Filter for students
    final allStudents = allUsers.where((user) {
      final role = user.role?.toLowerCase()?.trim() ?? '';
      return role == 'student' || role.contains('student');
    }).toList();

    print('🎓 Found ${allStudents.length} students total');

    // Filter by search query
    final queryLower = query.toLowerCase();
    final matchingStudents = allStudents
        .where((user) {
          final firstName = user.fname?.toLowerCase()?.trim() ?? '';
          final lastName = user.lname?.toLowerCase()?.trim() ?? '';
          final fullName = '$firstName $lastName'.trim();
          final email = user.email?.toLowerCase()?.trim() ?? '';

          return firstName.contains(queryLower) ||
              lastName.contains(queryLower) ||
              fullName.contains(queryLower) ||
              email.contains(queryLower);
        })
        .take(5)
        .toList();

    print('🎯 Final matching students: ${matchingStudents.length}');

    // CRITICAL FIX: Force UI update even if no changes detected
    setState(() {
      _studentSearchResults = matchingStudents;
      _showStudentResults = matchingStudents.isNotEmpty;
    });

    // DEBUG: Log UI state
    print(
        '📱 UI State: _showStudentResults = $_showStudentResults, results count = ${_studentSearchResults.length}');

    // FORCE UI REBUILD: Add small delay to ensure setState completes
    Future.microtask(() {
      if (mounted && matchingStudents.isNotEmpty) {
        setState(() {
          // Force refresh
        });
      }
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

// 9. OPTIMIZED: Add to cart with better feedback
  void _addToCart(Course course, {int quantity = 1}) {
    if (quantity <= 0) return;

    setState(() {
      final existingIndex =
          _cartItems.indexWhere((item) => item.course.id == course.id);

      if (existingIndex >= 0) {
        // Update existing item
        _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
          quantity: _cartItems[existingIndex].quantity + quantity,
        );
      } else {
        // Add new item
        _cartItems.add(CartItem(
          course: course,
          quantity: quantity,
          pricePerUnit: course.price.toDouble(),
        ));
      }
    });

    // Add haptic feedback
    HapticFeedback.selectionClick();

    // Show optimized feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('${course.name} added to cart'),
            ),
          ],
        ),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
  }

// 2. FIXED: Safe quantity update with proper validation
  void _updateCartQuantity(int index, int newQuantity) {
    // Add comprehensive bounds checking
    if (index < 0 || index >= _cartItems.length) {
      print('Invalid index: $index, cart length: ${_cartItems.length}');
      return;
    }

    // Validate quantity
    if (newQuantity < 0) {
      print('Invalid quantity: $newQuantity');
      return; // Don't allow negative quantities
    }

    if (newQuantity == 0) {
      _removeFromCart(index);
      return;
    }

    // Update the cart item with new quantity
    setState(() {
      _cartItems[index] = _cartItems[index].copyWith(quantity: newQuantity);
    });

    // Optional: Show brief feedback for quantity changes
    if (newQuantity != _cartItems[index].quantity) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quantity updated to $newQuantity'),
          duration: Duration(milliseconds: 500),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: 100,
            left: 20,
            right: 20,
          ),
        ),
      );
    }
  }

// ENHANCED REMOVE FROM CART WITH FEEDBACK
  void _removeFromCart(int index) {
    // Add bounds checking to prevent RangeError
    if (index < 0 || index >= _cartItems.length) {
      print('Invalid index: $index, cart length: ${_cartItems.length}');
      return;
    }

    setState(() {
      final removedItem = _cartItems[index];
      _cartItems.removeAt(index);

      // Show immediate feedback
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.remove_shopping_cart, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('${removedItem.course.name} removed from cart'),
              ),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
    });
  }

  // FIXED: Enhanced payment processing with better error handling and validation
  Future<void> _processTransaction({bool payNow = true}) async {
    // STEP 1: Show immediate validation errors and return early
    if (_selectedStudent == null) {
      _showError('Please select a student before proceeding');
      return;
    }

    if (_cartItems.isEmpty) {
      _showError('Please add items to cart before proceeding');
      return;
    }

    // STEP 2: Additional safety checks
    if (_selectedStudent!.id == null) {
      _showError(
          'Selected student has invalid ID. Please select another student.');
      return;
    }

    // STEP 3: Validate cart items have valid course data
    for (int i = 0; i < _cartItems.length; i++) {
      final item = _cartItems[i];
      if (item.course.id == null) {
        _showError(
            'Cart item ${i + 1} has invalid course data. Please remove and re-add it.');
        return;
      }
      if (item.quantity <= 0) {
        _showError(
            'Cart item ${i + 1} has invalid quantity. Please fix the quantity.');
        return;
      }
    }

    // STEP 4: Start processing with loading state
    setState(() {
      _isProcessing = true;
    });

    try {
      if (payNow) {
        await _processPayment();
        _showSuccess('Payment processed successfully!');
      } else {
        await _createInvoiceOnly();
        _showSuccess('Invoice created successfully!');
      }

      // Clear everything after successful processing
      _clearAll();
    } catch (e, stackTrace) {
      // STEP 5: Comprehensive error handling
      print('❌ Payment processing error: $e');
      print('❌ Stack trace: $stackTrace');

      String errorMessage = 'Transaction failed. Please try again.';

      // Provide specific error messages for common issues
      if (e.toString().contains('student')) {
        errorMessage =
            'Student information error. Please reselect the student and try again.';
      } else if (e.toString().contains('course')) {
        errorMessage =
            'Course information error. Please clear cart and re-add items.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('database') ||
          e.toString().contains('SQL')) {
        errorMessage = 'Database error. Please try again or contact support.';
      }

      _showError(errorMessage);
    } finally {
      // STEP 6: Always reset processing state
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

// ENHANCED: Payment processing with better error handling
  Future<void> _processPayment() async {
    // Validate student before processing
    if (_selectedStudent?.id == null) {
      throw Exception('Invalid student selected');
    }

    for (final item in _cartItems) {
      try {
        // Validate course data
        if (item.course.id == null) {
          throw Exception('Invalid course data for ${item.course.name}');
        }

        // Create invoice data
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

        // Save invoice
        await billingController.createInvoice(invoice);

        // Refresh billing data to get the created invoice
        await billingController.fetchBillingData();

        // Find the created invoice
        final createdInvoice = billingController.invoices.firstWhereOrNull(
          (inv) => inv.invoiceNumber == invoiceNumber,
        );

        if (createdInvoice?.id == null) {
          throw Exception('Failed to create invoice: $invoiceNumber');
        }

        print('Found created invoice with database ID: ${createdInvoice!.id}');

        // Generate payment reference
        final reference =
            'POS-${DateTime.now().toUtc().millisecondsSinceEpoch}';

        // Create payment
        final payment = Payment(
          invoiceId: createdInvoice.id!,
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

        print('Creating payment with invoice ID: ${payment.invoiceId}');

        // Record payment
        await billingController.recordPayment(payment);

        print('Payment recorded successfully for invoice ${createdInvoice.id}');
      } catch (e) {
        print('❌ Error processing payment for ${item.course.name}: $e');
        throw Exception(
            'Failed to process payment for ${item.course.name}: $e');
      }
    }
  }

// ENHANCED: Invoice creation with better error handling
  Future<void> _createInvoiceOnly() async {
    // Validate student before processing
    if (_selectedStudent?.id == null) {
      throw Exception('Invalid student selected');
    }

    for (final item in _cartItems) {
      try {
        // Validate course data
        if (item.course.id == null) {
          throw Exception('Invalid course data for ${item.course.name}');
        }

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
      } catch (e) {
        print('❌ Error creating invoice for ${item.course.name}: $e');
        throw Exception('Failed to create invoice for ${item.course.name}: $e');
      }
    }
  }

// ENHANCED: Better error display with dialog option for serious errors
  void _showError(String message) {
    print('❌ POS Error: $message');

    // Hide any existing snackbars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Show error snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

// ENHANCED: Better success display
  void _showSuccess(String message) {
    print('✅ POS Success: $message');

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
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
        // Student Selection Card - Fixed height with internal scrolling
        Container(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * 0.4, // Max 40% of screen
          ),
          child: SingleChildScrollView(
            child: _buildStudentSelectionCard(),
          ),
        ),

        // Cart Summary (Compact) - Fixed size
        if (_cartItems.isNotEmpty) _buildMobileCartSummary(),

        // Course Catalog - Takes remaining space
        Expanded(
          child: _buildCourseCatalog(),
        ),

        // Bottom Action Panel - Fixed size
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

  // ENHANCED: Student selection card with height constraints
  Widget _buildStudentSelectionCard() {
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
        mainAxisSize:
            MainAxisSize.min, // IMPORTANT: Don't take more space than needed
        children: [
          Text(
            'Select Student',
            style: TextStyle(
              fontSize: _responsiveFontSize + 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),

          // Search field
          TextFormField(
            controller: _studentSearchController,
            focusNode: _studentSearchFocus,
            decoration: InputDecoration(
              hintText: _isMobile
                  ? 'Search students...'
                  : 'Search student by name, email, or phone...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _selectedStudent != null
                  ? IconButton(
                      onPressed: () => _clearStudentSelection(),
                      icon: Icon(Icons.clear),
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(
                horizontal: _isMobile ? 16 : 12,
                vertical: _isMobile ? 16 : 12,
              ),
            ),
            style: TextStyle(fontSize: _isMobile ? 16 : 14),
          ),

          // FIXED: Search results with height constraints
          if (_showStudentResults && _studentSearchResults.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              // CRITICAL FIX: Constrain maximum height to prevent overflow
              constraints: BoxConstraints(
                maxHeight: _isMobile ? 200 : 160, // Limit height
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue.shade50,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header - Fixed height
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Text(
                      '${_studentSearchResults.length} student${_studentSearchResults.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: _isMobile ? 14 : 12,
                      ),
                    ),
                  ),

                  // Results - Scrollable if needed
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _studentSearchResults.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.blue.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final student = _studentSearchResults[index];
                        return InkWell(
                          onTap: () => _selectStudent(student),
                          child: Container(
                            padding: EdgeInsets.all(_isMobile ? 12 : 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: _isMobile ? 18 : 16,
                                  backgroundColor: Colors.blue.shade200,
                                  child: Text(
                                    '${student.fname?.substring(0, 1)?.toUpperCase() ?? ''}${student.lname?.substring(0, 1)?.toUpperCase() ?? ''}',
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: _isMobile ? 12 : 10,
                                    ),
                                  ),
                                ),
                                SizedBox(width: _isMobile ? 12 : 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${student.fname ?? ''} ${student.lname ?? ''}'
                                            .trim(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: _isMobile ? 14 : 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (student.email?.isNotEmpty == true)
                                        Text(
                                          student.email!,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: _isMobile ? 12 : 10,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.blue.shade600,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Selected student display
          if (_selectedStudent != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(_isMobile ? 16 : 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: _isMobile ? 20 : 18,
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      '${_selectedStudent!.fname?.substring(0, 1)?.toUpperCase() ?? ''}${_selectedStudent!.lname?.substring(0, 1)?.toUpperCase() ?? ''}',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: _isMobile ? 14 : 12,
                      ),
                    ),
                  ),
                  SizedBox(width: _isMobile ? 12 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade600, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Selected',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${_selectedStudent!.fname ?? ''} ${_selectedStudent!.lname ?? ''}'
                              .trim(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: _isMobile ? 16 : 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_selectedStudent!.email?.isNotEmpty == true)
                          Text(
                            _selectedStudent!.email!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: _isMobile ? 12 : 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _clearStudentSelection(),
                    icon: Icon(Icons.close, size: _isMobile ? 20 : 18),
                    color: Colors.grey.shade600,
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
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

// 3. Add helper method to clear student selection
  void _clearStudentSelection() {
    setState(() {
      _selectedStudent = null;
      _studentSearchController.clear();
      _showStudentResults = false;
    });
  }

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

// 8. OPTIMIZED: Cart panel with better list performance
  Widget _buildCartPanel() {
    return Container(
      padding: _responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_cartItems.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: _isMobile ? 80 : 64,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: TextStyle(
                        fontSize: _isMobile ? 18 : 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                // Add performance optimizations
                cacheExtent: 1000, // Cache more items for smoother scrolling
                itemCount: _cartItems.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  // Add bounds checking here too
                  if (index >= _cartItems.length) {
                    return SizedBox.shrink();
                  }
                  return _buildCartItem(_cartItems[index], index);
                },
              ),
            ),
          if (_cartItems.isNotEmpty) ...[
            Divider(thickness: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: _isMobile ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${_cartTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: _isMobile ? 22 : 20,
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

  // 3. OPTIMIZED: Better cart item widget with debounced interactions
  Widget _buildCartItem(CartItem item, int index) {
    final TextEditingController quantityController =
        TextEditingController(text: item.quantity.toString());

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 8 : 4,
        vertical: _isMobile ? 12 : 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.course.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: _isMobile ? 16 : 14,
                  ),
                ),
                Text(
                  '\$${item.pricePerUnit.toStringAsFixed(2)} each',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: _isMobile ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: _isMobile ? 12 : 8),

          // OPTIMIZED: Quantity controls with better performance
          _buildQuantityControls(item, index),

          SizedBox(width: _isMobile ? 12 : 8),

          // Total price
          Container(
            width: _isMobile ? 80 : 60,
            child: Text(
              '\$${item.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: _isMobile ? 16 : 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // OPTIMIZED: Delete button with better performance
          _buildDeleteButton(index),
        ],
      ),
    );
  }

  // 4. OPTIMIZED: Separate quantity controls for better performance
  Widget _buildQuantityControls(CartItem item, int index) {
    return Row(
      children: [
        // Minus Button - WORKING VERSION
        _buildQuantityButton(
          icon: Icons.remove,
          onTap: () {
            // Ensure we have valid index and item
            if (index >= 0 &&
                index < _cartItems.length &&
                _cartItems[index].quantity > 0) {
              if (_cartItems[index].quantity > 1) {
                // Decrease quantity by 1
                _updateCartQuantity(index, _cartItems[index].quantity - 1);
              } else {
                // Remove item when quantity would be 0
                _removeFromCart(index);
              }
              // Add haptic feedback
              HapticFeedback.selectionClick();
            }
          },
          enabled: item.quantity > 0,
        ),

        // Quantity Display (read-only) - WORKING VERSION
        Container(
          width: _isMobile ? 60 : 50,
          height: _isMobile ? 44 : 32,
          margin: EdgeInsets.symmetric(horizontal: _isMobile ? 8 : 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: Center(
            child: Text(
              item.quantity.toString(),
              style: TextStyle(
                fontSize: _isMobile ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),

        // Plus Button - WORKING VERSION
        _buildQuantityButton(
          icon: Icons.add,
          onTap: () {
            // Ensure we have valid index and item
            if (index >= 0 && index < _cartItems.length) {
              // Increase quantity by 1
              _updateCartQuantity(index, _cartItems[index].quantity + 1);
              // Add haptic feedback
              HapticFeedback.selectionClick();
            }
          },
          enabled: true,
        ),
      ],
    );
  }

// 5. OPTIMIZED: Reusable quantity button
  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Container(
      width: _isMobile ? 44 : 32,
      height: _isMobile ? 44 : 32,
      decoration: BoxDecoration(
        border: Border.all(
          color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(8),
        color: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          // Add splash factory for better performance
          splashFactory: InkRipple.splashFactory,
          child: Icon(
            icon,
            size: _isMobile ? 20 : 16,
            color: enabled ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

// 6. OPTIMIZED: Delete button with better performance
  Widget _buildDeleteButton(int index) {
    return Container(
      width: _isMobile ? 44 : 32,
      height: _isMobile ? 44 : 32,
      margin: EdgeInsets.only(left: _isMobile ? 8 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            // Ensure we have valid index
            if (index >= 0 && index < _cartItems.length) {
              // Add haptic feedback
              HapticFeedback.lightImpact();
              // Remove item immediately
              _removeFromCart(index);
            }
          },
          splashFactory: InkRipple.splashFactory,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: _isMobile ? 24 : 20,
            ),
          ),
        ),
      ),
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

  // 4. Fix mobile cart bottom sheet with better touch targets
  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        // KEY FIX: Add StatefulBuilder
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header with better mobile touch target
              Container(
                padding: EdgeInsets.all(_isMobile ? 20 : 16),
                decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Shopping Cart (${_cartItems.length} items)', // Show item count
                      style: TextStyle(
                        fontSize: _isMobile ? 20 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    Container(
                      width: _isMobile ? 44 : 36,
                      height: _isMobile ? 44 : 36,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.close,
                            size: _isMobile ? 28 : 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cart content with reactive updates
              Expanded(
                child: _buildReactiveCartPanel(
                    setModalState), // Pass setModalState
              ),

              // Action buttons with mobile optimization
              Container(
                padding: EdgeInsets.all(_isMobile ? 20 : 16),
                child: Column(
                  children: [
                    // Total display
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: _isMobile ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${_cartTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: _isMobile ? 22 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: _isMobile ? 56 : 44,
                            child: OutlinedButton(
                              onPressed: _cartItems.isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _processTransaction(payNow: false);
                                    },
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'INVOICE ONLY',
                                style: TextStyle(fontSize: _isMobile ? 16 : 14),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: _isMobile ? 16 : 12),
                        Expanded(
                          child: Container(
                            height: _isMobile ? 56 : 44,
                            child: ElevatedButton(
                              onPressed: _cartItems.isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _processTransaction(payNow: true);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'PAY NOW',
                                style: TextStyle(fontSize: _isMobile ? 16 : 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactiveCartPanel(StateSetter setModalState) {
    return Container(
      padding: _responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_cartItems.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: _isMobile ? 80 : 64,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: TextStyle(
                        fontSize: _isMobile ? 18 : 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _cartItems.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= _cartItems.length) {
                    return SizedBox.shrink();
                  }
                  return _buildReactiveCartItem(
                      _cartItems[index], index, setModalState);
                },
              ),
            ),
        ],
      ),
    );
  }

// NEW: Reactive cart item for bottom sheet
  Widget _buildReactiveCartItem(
      CartItem item, int index, StateSetter setModalState) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 8 : 4,
        vertical: _isMobile ? 12 : 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.course.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: _isMobile ? 16 : 14,
                  ),
                ),
                Text(
                  '\$${item.pricePerUnit.toStringAsFixed(2)} each',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: _isMobile ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: _isMobile ? 12 : 8),

          // Reactive quantity controls
          _buildReactiveQuantityControls(item, index, setModalState),

          SizedBox(width: _isMobile ? 12 : 8),

          // Total price
          Container(
            width: _isMobile ? 80 : 60,
            child: Text(
              '\$${item.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: _isMobile ? 16 : 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Reactive delete button
          _buildReactiveDeleteButton(index, setModalState),
        ],
      ),
    );
  }

// NEW: Reactive quantity controls for bottom sheet
  Widget _buildReactiveQuantityControls(
      CartItem item, int index, StateSetter setModalState) {
    return Row(
      children: [
        // Minus Button
        _buildQuantityButton(
          icon: Icons.remove,
          onTap: () {
            if (index >= 0 &&
                index < _cartItems.length &&
                _cartItems[index].quantity > 0) {
              if (_cartItems[index].quantity > 1) {
                _updateCartQuantity(index, _cartItems[index].quantity - 1);
              } else {
                _removeFromCart(index);
              }
              HapticFeedback.selectionClick();
              setModalState(() {}); // Update modal state
            }
          },
          enabled: item.quantity > 0,
        ),

        // Quantity Display
        Container(
          width: _isMobile ? 60 : 50,
          height: _isMobile ? 44 : 32,
          margin: EdgeInsets.symmetric(horizontal: _isMobile ? 8 : 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: Center(
            child: Text(
              item.quantity.toString(),
              style: TextStyle(
                fontSize: _isMobile ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),

        // Plus Button
        _buildQuantityButton(
          icon: Icons.add,
          onTap: () {
            if (index >= 0 && index < _cartItems.length) {
              _updateCartQuantity(index, _cartItems[index].quantity + 1);
              HapticFeedback.selectionClick();
              setModalState(() {}); // Update modal state
            }
          },
          enabled: true,
        ),
      ],
    );
  }

// NEW: Reactive delete button for bottom sheet
  Widget _buildReactiveDeleteButton(int index, StateSetter setModalState) {
    return Container(
      width: _isMobile ? 44 : 32,
      height: _isMobile ? 44 : 32,
      margin: EdgeInsets.only(left: _isMobile ? 8 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (index >= 0 && index < _cartItems.length) {
              HapticFeedback.lightImpact();
              _removeFromCart(index);
              setModalState(() {}); // Update modal state
            }
          },
          splashFactory: InkRipple.splashFactory,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: _isMobile ? 24 : 20,
            ),
          ),
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
