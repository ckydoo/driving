import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/models/course.dart';
import 'package:driving/services/receipt_service.dart';

class POSCashierScreen extends StatefulWidget {
  @override
  _POSCashierScreenState createState() => _POSCashierScreenState();
}

class _POSCashierScreenState extends State<POSCashierScreen>
    with TickerProviderStateMixin {
  final BillingController billingController = Get.find<BillingController>();
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();

  // Form controllers - derived from payment_dialog.dart
  final _formKey = GlobalKey<FormState>();
  final _studentSearchController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _referenceController = TextEditingController();
  final _cashReceivedController = TextEditingController();

  // Selected data - derived from create_invoice_dialog.dart and payment_dialog.dart
  User? _selectedStudent;
  Course? _selectedCourse;
  int _numberOfLessons = 1;
  double _pricePerLesson = 0.0;
  String _paymentMethod = 'cash';
  bool _isProcessing = false;
  bool _generateReceipt = true;
  bool _autoGenerateReference = true;

  // Animation controller - from payment_dialog.dart
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Payment methods from payment_dialog.dart
  final List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'cash', 'label': 'Cash', 'icon': Icons.money},
    {
      'value': 'mobile_payment',
      'label': 'Mobile Payment',
      'icon': Icons.smartphone
    },
  ];

  // Calculated totals
  double get _totalAmount =>
      _selectedCourse != null ? _numberOfLessons * _pricePerLesson : 0.0;
  double get _cashReceived =>
      double.tryParse(_cashReceivedController.text) ?? 0.0;
  double get _change => _cashReceived - _totalAmount;

  @override
  void initState() {
    super.initState();

    // Initialize reference from receipt service
    _referenceController.text = ReceiptService.generateReference();

    // Animation setup from payment_dialog.dart
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();

    // Cash received controller listener
    _cashReceivedController.addListener(() {
      setState(() {}); // Update change calculation
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('POS - Cashier Terminal'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearTransaction,
            icon: Icon(Icons.refresh),
            tooltip: 'New Transaction',
          ),
        ],
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: Row(
          children: [
            // Left Panel - Student & Course Selection
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    _buildStudentSection(),
                    _buildCourseSection(),
                    // _buildInvoicePreview(),
                  ],
                ),
              ),
            ),

            // Right Panel - Payment Processing
            Container(
              width: 400,
              color: Colors.grey[100],
              child: _buildPaymentPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Student Selection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),

          // Student autocomplete - derived from create_invoice_dialog.dart
          _buildStudentAutocomplete(),

          if (_selectedStudent != null) ...[
            SizedBox(height: 12),
            _buildSelectedStudentCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentAutocomplete() {
    final students = userController.students
        .where((student) => student.status.toLowerCase() == 'active')
        .toList();

    return Autocomplete<User>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return students.take(5);
        }
        return students.where((student) {
          final searchText = textEditingValue.text.toLowerCase();
          return student.fname.toLowerCase().contains(searchText) ||
              student.lname.toLowerCase().contains(searchText) ||
              student.email.toLowerCase().contains(searchText) ||
              (student.phone?.toLowerCase().contains(searchText) ?? false);
        }).take(5);
      },
      displayStringForOption: (User student) =>
          '${student.fname} ${student.lname}',
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        if (_selectedStudent != null) {
          textEditingController.text =
              '${_selectedStudent!.fname} ${_selectedStudent!.lname}';
        }
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Search student by name, email, or phone...',
            prefixIcon: Icon(Icons.search),
            suffixIcon: _selectedStudent != null
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedStudent = null;
                        textEditingController.clear();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 350,
              constraints: BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final student = options.elementAt(index);
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(student.fname[0].toUpperCase()),
                      backgroundColor: Colors.green[100],
                    ),
                    title: Text('${student.fname} ${student.lname}'),
                    subtitle: Text(student.email),
                    trailing: student.phone?.isNotEmpty == true
                        ? Text(student.phone!, style: TextStyle(fontSize: 12))
                        : null,
                    onTap: () => onSelected(student),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (User student) {
        setState(() {
          _selectedStudent = student;
        });
      },
    );
  }

  Widget _buildSelectedStudentCard() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(_selectedStudent!.fname[0].toUpperCase()),
            backgroundColor: Colors.green[200],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_selectedStudent!.fname} ${_selectedStudent!.lname}',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(_selectedStudent!.email),
                if (_selectedStudent!.phone?.isNotEmpty == true)
                  Text(_selectedStudent!.phone!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseSection() {
    if (_selectedStudent == null) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Text('Select a student first',
            style: TextStyle(color: Colors.grey[600])),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Course Selection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          _buildCourseAutocomplete(),
          if (_selectedCourse != null) ...[
            SizedBox(height: 12),
            _buildLessonsSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseAutocomplete() {
    final courses = courseController.courses
        .where((course) => course.status.toLowerCase() == 'active')
        .toList();

    return Autocomplete<Course>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return courses;
        }
        return courses.where((course) => course.name
            .toLowerCase()
            .contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (Course course) => course.name,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        if (_selectedCourse != null) {
          textEditingController.text = _selectedCourse!.name;
        }
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Select course...',
            prefixIcon: Icon(Icons.school),
            suffixIcon: _selectedCourse != null
                ? Icon(Icons.check_circle, color: Colors.green[600])
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        );
      },
      onSelected: (Course course) {
        setState(() {
          _selectedCourse = course;
          _pricePerLesson =
              course.price.toDouble(); // Price IS per lesson in your model
          _numberOfLessons = 1; // Start with 1 lesson
        });
      },
    );
  }

  Widget _buildLessonsSelector() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600]),
              SizedBox(width: 8),
              Text('Course: ${_selectedCourse!.name}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 8),
          Text(
              'Price per lesson: \$${_selectedCourse!.price.toStringAsFixed(2)}'),
          SizedBox(height: 12),

          Text('Number of lessons:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),

          // Lessons counter
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: IconButton(
                  onPressed: _numberOfLessons > 1
                      ? () {
                          setState(() {
                            _numberOfLessons--;
                          });
                        }
                      : null,
                  icon: Icon(Icons.remove),
                ),
              ),
              Container(
                width: 80,
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: TextFormField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  controller:
                      TextEditingController(text: _numberOfLessons.toString()),
                  onChanged: (value) {
                    final newValue = int.tryParse(value);
                    if (newValue != null && newValue > 0) {
                      setState(() {
                        _numberOfLessons = newValue;
                      });
                    }
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _numberOfLessons++;
                    });
                  },
                  icon: Icon(Icons.add),
                ),
              ),
              SizedBox(width: 16),
              Text('lessons'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentPanel() {
    return Form(
      key: _formKey,
      child: Container(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Payment Processing',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),

              // Amount display
              _buildAmountSection(),

              SizedBox(height: 16),

              // Payment method selection - from payment_dialog.dart
              _buildPaymentMethodSection(),

              SizedBox(height: 16),

              // Cash payment specific fields
              if (_paymentMethod == 'cash') _buildCashPaymentSection(),

              SizedBox(height: 16),

              // Reference field
              _buildReferenceSection(),

              SizedBox(height: 24),

              // Process payment button
              _buildProcessPaymentButton(),

              SizedBox(height: 16), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Amount to Pay:', style: TextStyle(fontSize: 16)),
              Text('\$${_totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600])),
            ],
          ),
          if (_paymentMethod == 'cash' && _cashReceived > 0) ...[
            SizedBox(height: 8),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cash Received:'),
                Text('\$${_cashReceived.toStringAsFixed(2)}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Change:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('\$${_change.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _change >= 0 ? Colors.green[600] : Colors.red[600],
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paymentMethods.map((method) {
            return FilterChip(
              avatar: Icon(method['icon'], size: 18),
              label: Text(method['label']),
              selected: _paymentMethod == method['value'],
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _paymentMethod = method['value'];
                  });
                }
              },
              selectedColor: Colors.green[100],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCashPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cash Received',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        TextFormField(
          controller: _cashReceivedController,
          decoration: InputDecoration(
            hintText: 'Enter cash amount received',
            prefixText: '\$',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          validator: (value) {
            if (_paymentMethod == 'cash') {
              final amount = double.tryParse(value ?? '');
              if (amount == null || amount < _totalAmount) {
                return 'Cash received must be at least \$${_totalAmount.toStringAsFixed(2)}';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildReferenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Payment Reference',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Spacer(),
            Row(
              children: [
                Text('Auto-generate', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _autoGenerateReference,
                  onChanged: (value) {
                    setState(() {
                      _autoGenerateReference = value;
                      if (value) {
                        _referenceController.text =
                            ReceiptService.generateReference();
                      }
                    });
                  },
                  activeColor: Colors.green[600],
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _referenceController,
          enabled: !_autoGenerateReference,
          decoration: InputDecoration(
            hintText: 'Payment reference',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: _autoGenerateReference ? Colors.grey[100] : Colors.white,
          ),
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'Payment reference is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildProcessPaymentButton() {
    final canProcess = _selectedStudent != null &&
        _selectedCourse != null &&
        _totalAmount > 0 &&
        !_isProcessing;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canProcess ? _processPayment : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Processing...'),
                ],
              )
            : Text('Process Payment - \$${_totalAmount.toStringAsFixed(2)}'),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog - derived from payment_dialog.dart
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Generate invoice number
      final invoiceNumber = 'POS-${DateTime.now().millisecondsSinceEpoch}';

      // Create invoice - derived from create_invoice_dialog.dart logic
      final invoice = Invoice(
        studentId: _selectedStudent!.id!,
        courseId: _selectedCourse!.id!,
        lessons: _numberOfLessons,
        pricePerLesson: _pricePerLesson,
        totalAmount: _totalAmount,
        status:
            'paid', // Mark as paid immediately since we're processing payment
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(Duration(days: 30)),
        amountPaid: _totalAmount, // Full payment
        // notes:
        //     'POS Payment - ${_selectedCourse!.name} (${_numberOfLessons} lessons)',
        invoiceNumber: invoiceNumber,
      );

      // Save invoice and get ID - using billingController method
      final invoiceId = await billingController.createInvoice(invoice);

      // Create payment - derived from payment_dialog.dart
      final payment = Payment(
        invoiceId: invoiceId,
        amount: _totalAmount,
        method: _paymentMethod,
        paymentDate: DateTime.now(),
        notes: _notesController.text.trim().isEmpty
            ? 'POS Payment - ${_paymentMethod.replaceAll('_', ' ').toUpperCase()}'
            : _notesController.text.trim(),
        reference: _referenceController.text.trim(),
        receiptGenerated: false,
      );

      // Process payment with receipt
      await billingController.recordPaymentWithReceipt(
          payment, invoice.copyWith(id: invoiceId), _selectedStudent!);

      // Show success animation
      await _showSuccessAnimation();

      // Show success message
      Get.snackbar(
        'Payment Successful!',
        'Invoice created and payment processed. Receipt generated.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        icon: Icon(Icons.check_circle, color: Colors.white),
      );

      // Clear transaction for next customer
      _clearTransaction();
    } catch (e) {
      Get.snackbar(
        'Payment Failed',
        'Failed to process payment: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        icon: Icon(Icons.error, color: Colors.white),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.payment, color: Colors.green[600]),
                  SizedBox(width: 8),
                  Text('Confirm Payment'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Please confirm the payment details:'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildConfirmationRow('Student',
                            '${_selectedStudent!.fname} ${_selectedStudent!.lname}'),
                        _buildConfirmationRow('Course', _selectedCourse!.name),
                        _buildConfirmationRow('Lessons', '$_numberOfLessons'),
                        _buildConfirmationRow(
                            'Amount', '\$${_totalAmount.toStringAsFixed(2)}'),
                        _buildConfirmationRow('Payment Method',
                            _paymentMethod.replaceAll('_', ' ').toUpperCase()),
                        if (_paymentMethod == 'cash' && _cashReceived > 0) ...[
                          _buildConfirmationRow('Cash Received',
                              '\$${_cashReceived.toStringAsFixed(2)}'),
                          _buildConfirmationRow(
                              'Change', '\$${_change.toStringAsFixed(2)}'),
                        ],
                        _buildConfirmationRow(
                            'Reference', _referenceController.text),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Confirm Payment'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _showSuccessAnimation() async {
    // Show the dialog and get a reference to close it
    final dialogContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder(
                  duration: Duration(milliseconds: 500),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 64,
                      ),
                    );
                  },
                ),
                SizedBox(height: 16),
                Text(
                  'Payment\nSuccessful!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Auto close after 1.5 seconds
    await Future.delayed(Duration(milliseconds: 1500));

    // Check if the widget is still mounted and close the dialog
    if (mounted && Navigator.of(dialogContext).canPop()) {
      Navigator.of(dialogContext).pop();
    }
  }

  void _clearTransaction() {
    setState(() {
      _selectedStudent = null;
      _selectedCourse = null;
      _numberOfLessons = 1;
      _pricePerLesson = 0.0;
      _paymentMethod = 'cash';
      _studentSearchController.clear();
      _amountController.clear();
      _notesController.clear();
      _cashReceivedController.clear();
      _referenceController.text = ReceiptService.generateReference();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _studentSearchController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }
}
