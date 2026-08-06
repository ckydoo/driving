// Enhanced PaymentDialog with invoice selection capability and "Pay All" option
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/services/receipt_service.dart';

class PaymentDialog extends StatefulWidget {
  final Invoice? invoice; // Make this optional
  final List<Invoice>? availableInvoices; // Add list of invoices to choose from
  final String studentName;
  final int studentId;

  const PaymentDialog({
    Key? key,
    this.invoice, // Optional specific invoice
    this.availableInvoices, // Optional list for selection
    required this.studentName,
    required this.studentId,
  }) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _referenceController = TextEditingController();

  String _paymentMethod = 'cash';
  bool _isRecording = false;
  bool _isPartialPayment = false;
  bool _generateReceipt = true;
  bool _autoGenerateReference = true;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  Invoice?
      _selectedInvoice; // Currently selected invoice (null when "pay all" is selected)
  List<Invoice> _selectableInvoices =
      []; // List of invoices user can choose from
  bool _payAllMode = false; // Whether "Pay All" is selected
  double _totalAmountDue = 0.0; // Total amount due across all invoices

  final List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'cash', 'label': 'Cash', 'icon': Icons.money},
    {
      'value': 'mobile_payment',
      'label': 'Mobile Payment',
      'icon': Icons.smartphone
    },
  ];

  @override
  void initState() {
    super.initState();

    // Initialize invoice selection
    _initializeInvoiceSelection();

    _referenceController.text = ReceiptService.generateReference();

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
  }

  void _initializeInvoiceSelection() {
    if (widget.invoice != null) {
      // Single invoice mode
      _selectedInvoice = widget.invoice;
      _selectableInvoices = [widget.invoice!];
      _payAllMode = false;
      _totalAmountDue = widget.invoice!.balance;
    } else if (widget.availableInvoices != null &&
        widget.availableInvoices!.isNotEmpty) {
      // Multiple invoices mode - filter unpaid invoices
      _selectableInvoices = widget.availableInvoices!
          .where((invoice) => invoice.balance > 0)
          .toList();

      if (_selectableInvoices.isNotEmpty) {
        // Sort by date (oldest first) and select the first one as default
        _selectableInvoices.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _selectedInvoice = _selectableInvoices.first;
        _payAllMode = false;

        // Calculate total amount due across all invoices
        _totalAmountDue = _selectableInvoices.fold(
            0.0, (sum, invoice) => sum + invoice.balance);
      }
    }

    // Set initial amount
    _updateAmountController();
  }

  void _updateAmountController() {
    if (_payAllMode) {
      _amountController.text = _totalAmountDue.toStringAsFixed(2);
    } else if (_selectedInvoice != null) {
      _amountController.text = _selectedInvoice!.balance.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onInvoiceSelected(Invoice? invoice) {
    if (invoice != null && invoice != _selectedInvoice) {
      setState(() {
        _selectedInvoice = invoice;
        _payAllMode = false;
        _updateAmountController();
        _onAmountChanged(_amountController.text);
      });
    }
  }

  void _onPayAllSelected() {
    setState(() {
      _selectedInvoice = null;
      _payAllMode = true;
      _updateAmountController();
      _onAmountChanged(_amountController.text);
    });
  }

  void _onAmountChanged(String value) {
    if (value.isNotEmpty) {
      final amount = double.tryParse(value) ?? 0;
      if (_payAllMode) {
        setState(() {
          _isPartialPayment = amount < _totalAmountDue;
        });
      } else if (_selectedInvoice != null) {
        setState(() {
          _isPartialPayment = amount < _selectedInvoice!.balance;
        });
      }
    }
  }

  void _setQuickAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(2);
    _onAmountChanged(amount.toString());
  }

  Widget _buildInvoiceSelector() {
    if (_selectableInvoices.length <= 1) {
      return const SizedBox.shrink(); // Don't show selector if only one invoice
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Select Payment Option',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.blue),

          // Pay All Option
          _buildPayAllOption(),

          // Individual invoice options
          ..._selectableInvoices.map((invoice) => _buildInvoiceOption(invoice)),
        ],
      ),
    );
  }

  Widget _buildPayAllOption() {
    return InkWell(
      onTap: _onPayAllSelected,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _payAllMode ? Colors.green.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: 'pay_all',
              groupValue: _payAllMode
                  ? 'pay_all'
                  : (_selectedInvoice?.id?.toString() ?? ''),
              onChanged: (_) => _onPayAllSelected(),
              activeColor: Colors.green.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.payment,
                        color: _payAllMode
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pay All',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _payAllMode
                              ? Colors.green.shade800
                              : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '\$${_totalAmountDue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.receipt_outlined,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectableInvoices.length} invoices',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.savings,
                          size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Clear all outstanding balance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildInvoiceOption(Invoice invoice) {
    final isSelected = !_payAllMode && invoice.id == _selectedInvoice?.id;

    return InkWell(
      onTap: () => _onInvoiceSelected(invoice),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: invoice.id.toString(),
              groupValue: _payAllMode
                  ? 'pay_all'
                  : (_selectedInvoice?.id?.toString() ?? ''),
              onChanged: (_) => _onInvoiceSelected(invoice),
              activeColor: Colors.blue.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Invoice #${invoice.invoiceNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.blue.shade800
                              : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: invoice.balance > 0
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '\$${invoice.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: invoice.balance > 0
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${invoice.dueDate.toString().split(' ')[0]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.school, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${invoice.lessons} lessons',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
    );
  }

  void _submitPayment() async {
    if (!_payAllMode && _selectedInvoice == null) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Please select an invoice to pay',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final confirmed = await _showConfirmationDialog();
      if (!confirmed) return;

      setState(() => _isRecording = true);

      try {
        final amount = double.parse(_amountController.text);
        final billingController = Get.find<BillingController>();
        final userController = Get.find<UserController>();

        final student = userController.users.firstWhere(
          (user) => user.id == widget.studentId,
          orElse: () => throw Exception('Student not found'),
        );

        if (_payAllMode) {
          // Pay all invoices
          await _processPayAllInvoices(amount, billingController, student);
        } else {
          // Pay single invoice
          await _processSingleInvoicePayment(
              amount, billingController, student);
        }

        await _showSuccessAnimation();
      } catch (e) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to record payment: ${e.toString()}',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
      } finally {
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _processPayAllInvoices(double totalAmount,
      BillingController billingController, dynamic student) async {
    double remainingAmount = totalAmount;

    // Sort invoices by date (oldest first) for payment allocation
    List<Invoice> invoicesToPay = List.from(_selectableInvoices);
    invoicesToPay.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (Invoice invoice in invoicesToPay) {
      if (remainingAmount <= 0) break;

      double paymentAmount = remainingAmount >= invoice.balance
          ? invoice.balance
          : remainingAmount;

      final reference = ReceiptService.generateReference();
      final payment = Payment(
        invoiceId: invoice.id!,
        amount: paymentAmount,
        method: _paymentMethod,
        paymentDate: DateTime.now(),
        notes: _notesController.text.trim().isEmpty
            ? 'Payment for multiple invoices'
            : _notesController.text.trim(),
        reference: reference,
        receiptGenerated: false,
      );

      if (_generateReceipt) {
        await billingController.recordPaymentWithReceipt(
            payment, invoice, student);
      } else {
        await billingController.recordPayment(payment);
      }

      remainingAmount -= paymentAmount;
    }
  }

  Future<void> _processSingleInvoicePayment(double amount,
      BillingController billingController, dynamic student) async {
    final reference = _autoGenerateReference
        ? ReceiptService.generateReference()
        : _referenceController.text.trim();

    final payment = Payment(
      invoiceId: _selectedInvoice!.id!,
      amount: amount,
      method: _paymentMethod,
      paymentDate: DateTime.now(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      reference: reference,
      receiptGenerated: false,
    );

    if (_generateReceipt) {
      await billingController.recordPaymentWithReceipt(
          payment, _selectedInvoice!, student);
    } else {
      await billingController.recordPayment(payment);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_payAllMode) ...[
                  Text('Pay All Outstanding Invoices'),
                  Text('Invoices: ${_selectableInvoices.length}'),
                ] else ...[
                  Text('Invoice: #${_selectedInvoice?.invoiceNumber}'),
                ],
                Text('Amount: \$${_amountController.text}'),
                Text(
                    'Method: ${_paymentMethod.replaceAll('_', ' ').toUpperCase()}'),
                if (_generateReceipt) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.receipt,
                          size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _payAllMode
                            ? 'Receipts will be generated for each invoice'
                            : 'Receipt will be generated',
                        style: TextStyle(
                            color: Colors.green.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                ),
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showSuccessAnimation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                _payAllMode
                    ? 'All Payments Recorded Successfully!'
                    : 'Payment Recorded Successfully!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _payAllMode
                    ? 'All outstanding invoices have been paid.'
                    : 'The payment has been successfully recorded.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Close the success dialog
                  Navigator.of(context).pop();
                  // Close the main payment dialog
                  Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isVerySmallScreen = screenSize.width < 400;

    if ((!_payAllMode && _selectedInvoice == null) ||
        _selectableInvoices.isEmpty) {
      return Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? screenSize.width * 0.9 : 400,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              const Text(
                'No Invoice Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('No outstanding invoices found for this student.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    final currentBalance =
        _payAllMode ? _totalAmountDue : (_selectedInvoice?.balance ?? 0.0);
    final displayTitle = _payAllMode
        ? 'Pay All Invoices (\$${_totalAmountDue.toStringAsFixed(2)})'
        : 'Invoice #${_selectedInvoice?.invoiceNumber ?? ''}';

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 40,
            vertical: isSmallScreen ? 24 : 40,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isSmallScreen ? double.infinity : 600,
              maxHeight: screenSize.height * (isSmallScreen ? 0.95 : 0.9),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header - Fixed
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _payAllMode
                          ? [Colors.green.shade600, Colors.green.shade800]
                          : [Colors.blue.shade600, Colors.blue.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isSmallScreen ? 16 : 20),
                      topRight: Radius.circular(isSmallScreen ? 16 : 20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _payAllMode ? Icons.payment : Icons.receipt_long,
                        color: Colors.white,
                        size: isSmallScreen ? 24 : 28,
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _payAllMode
                                  ? (isVerySmallScreen
                                      ? 'Pay All'
                                      : 'Pay All Outstanding')
                                  : 'Record Payment',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 18 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!isVerySmallScreen) ...[
                              Text(
                                'For ${widget.studentName}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Invoice Selector (if multiple invoices)
                          _buildResponsiveInvoiceSelector(
                              isSmallScreen, isVerySmallScreen),

                          // Payment Summary
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              color: _payAllMode
                                  ? Colors.green.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _payAllMode
                                    ? Colors.green.shade200
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _payAllMode
                                          ? Icons.payment
                                          : Icons.receipt_long,
                                      color: _payAllMode
                                          ? Colors.green.shade600
                                          : Colors.blue.shade600,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                    SizedBox(width: isSmallScreen ? 6 : 8),
                                    Expanded(
                                      child: Text(
                                        displayTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: isSmallScreen ? 14 : 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_payAllMode) ...[
                                  SizedBox(height: isSmallScreen ? 8 : 12),
                                  isVerySmallScreen
                                      ? Column(
                                          children: [
                                            _buildSummaryItem('Invoices',
                                                '${_selectableInvoices.length}',
                                                isSmall: true),
                                            const SizedBox(height: 8),
                                            _buildSummaryItem('Total Due',
                                                '\$${_totalAmountDue.toStringAsFixed(2)}',
                                                color: Colors.green.shade600,
                                                isSmall: true),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildSummaryItem('Invoices',
                                                '${_selectableInvoices.length}',
                                                isSmall: isSmallScreen),
                                            _buildSummaryItem('Total Due',
                                                '\$${_totalAmountDue.toStringAsFixed(2)}',
                                                color: Colors.green.shade600,
                                                isSmall: isSmallScreen),
                                          ],
                                        ),
                                ] else if (_selectedInvoice != null) ...[
                                  SizedBox(height: isSmallScreen ? 8 : 12),
                                  isVerySmallScreen
                                      ? Column(
                                          children: [
                                            _buildSummaryItem('Total',
                                                '\$${_selectedInvoice!.totalAmountCalculated.toStringAsFixed(2)}',
                                                isSmall: true),
                                            const SizedBox(height: 8),
                                            _buildSummaryItem('Paid',
                                                '\$${_selectedInvoice!.amountPaid.toStringAsFixed(2)}',
                                                isSmall: true),
                                            const SizedBox(height: 8),
                                            _buildSummaryItem(
                                              'Balance',
                                              '\$${_selectedInvoice!.balance.toStringAsFixed(2)}',
                                              color:
                                                  _selectedInvoice!.balance > 0
                                                      ? Colors.red.shade600
                                                      : Colors.green.shade600,
                                              isSmall: true,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildSummaryItem('Total',
                                                '\$${_selectedInvoice!.totalAmountCalculated.toStringAsFixed(2)}',
                                                isSmall: isSmallScreen),
                                            _buildSummaryItem('Paid',
                                                '\$${_selectedInvoice!.amountPaid.toStringAsFixed(2)}',
                                                isSmall: isSmallScreen),
                                            _buildSummaryItem(
                                              'Balance',
                                              '\$${_selectedInvoice!.balance.toStringAsFixed(2)}',
                                              color:
                                                  _selectedInvoice!.balance > 0
                                                      ? Colors.red.shade600
                                                      : Colors.green.shade600,
                                              isSmall: isSmallScreen,
                                            ),
                                          ],
                                        ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 16 : 20),

                          // Payment Amount
                          _buildPaymentAmountSection(
                              isSmallScreen, isVerySmallScreen, currentBalance),

                          SizedBox(height: isSmallScreen ? 16 : 20),

                          // Payment Method
                          _buildPaymentMethodSection(isSmallScreen),

                          // SizedBox(height: isSmallScreen ? 16 : 20),

                          // // Notes
                          // TextFormField(
                          //   controller: _notesController,
                          //   maxLines: isSmallScreen ? 2 : 3,
                          //   decoration: InputDecoration(
                          //     labelText: 'Notes (Optional)',
                          //     labelStyle:
                          //         TextStyle(fontSize: isSmallScreen ? 14 : 16),
                          //     hintText: _payAllMode
                          //         ? 'Payment for all outstanding invoices...'
                          //         : 'Add payment notes...',
                          //     hintStyle:
                          //         TextStyle(fontSize: isSmallScreen ? 12 : 14),
                          //     border: OutlineInputBorder(
                          //       borderRadius: BorderRadius.circular(10),
                          //     ),
                          //     focusedBorder: OutlineInputBorder(
                          //       borderRadius: BorderRadius.circular(10),
                          //       borderSide: BorderSide(
                          //         color: _payAllMode
                          //             ? Colors.green.shade600
                          //             : Colors.blue.shade600,
                          //         width: 2,
                          //       ),
                          //     ),
                          //     contentPadding:
                          //         EdgeInsets.all(isSmallScreen ? 12 : 16),
                          //   ),
                          // ),

                          SizedBox(height: isSmallScreen ? 16 : 20),

                          // // Receipt Options
                          // _buildReceiptOptionsSection(isSmallScreen),

                          // SizedBox(height: isSmallScreen ? 20 : 24),

                          // Action Buttons
                          isVerySmallScreen
                              ? Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: _isRecording
                                            ? null
                                            : () => Navigator.of(context).pop(),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isRecording
                                            ? null
                                            : _submitPayment,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _payAllMode
                                              ? Colors.green.shade600
                                              : Colors.blue.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: _isRecording
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(_payAllMode
                                                ? 'Pay All Invoices'
                                                : 'Record Payment'),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isRecording
                                            ? null
                                            : () => Navigator.of(context).pop(),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                              vertical:
                                                  isSmallScreen ? 14 : 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                              fontSize:
                                                  isSmallScreen ? 14 : 16),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 12 : 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isRecording
                                            ? null
                                            : _submitPayment,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _payAllMode
                                              ? Colors.green.shade600
                                              : Colors.blue.shade600,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                              vertical:
                                                  isSmallScreen ? 14 : 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: _isRecording
                                            ? SizedBox(
                                                width: isSmallScreen ? 18 : 20,
                                                height: isSmallScreen ? 18 : 20,
                                                child:
                                                    const CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(
                                                _payAllMode
                                                    ? (isSmallScreen
                                                        ? 'Pay All'
                                                        : 'Pay All Invoices')
                                                    : 'Record Payment',
                                                style: TextStyle(
                                                    fontSize: isSmallScreen
                                                        ? 14
                                                        : 16),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveInvoiceSelector(
      bool isSmallScreen, bool isVerySmallScreen) {
    if (_selectableInvoices.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Row(
              children: [
                Icon(Icons.receipt_long,
                    color: Colors.blue.shade600, size: isSmallScreen ? 18 : 20),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: Text(
                    isVerySmallScreen
                        ? 'Payment Option'
                        : 'Select Payment Option',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.blue),

          // Scrollable invoice list for small screens
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: isSmallScreen ? 200 : 300,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPayAllOption(),
                  ..._selectableInvoices
                      .map((invoice) => _buildInvoiceOption(invoice)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAmountSection(
      bool isSmallScreen, bool isVerySmallScreen, double currentBalance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Amount',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            prefixText: '\$',
            hintText: '0.00',
            hintStyle: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color:
                    _payAllMode ? Colors.green.shade600 : Colors.blue.shade600,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          ),
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter payment amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            if (amount > currentBalance) {
              return 'Amount cannot exceed balance (\$${currentBalance.toStringAsFixed(2)})';
            }
            return null;
          },
          onChanged: _onAmountChanged,
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),

        // Quick amount buttons
        isVerySmallScreen
            ? Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _setQuickAmount(currentBalance / 2),
                      child: Text(
                          'Half (\$${(currentBalance / 2).toStringAsFixed(2)})'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _setQuickAmount(currentBalance),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _payAllMode
                            ? Colors.green.shade600
                            : Colors.blue.shade600,
                      ),
                      child: Text(
                        'Full (\$${currentBalance.toStringAsFixed(2)})',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setQuickAmount(currentBalance / 2),
                      child: FittedBox(
                        child: Text(
                          'Half (\$${(currentBalance / 2).toStringAsFixed(2)})',
                          style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _setQuickAmount(currentBalance),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _payAllMode
                            ? Colors.green.shade600
                            : Colors.blue.shade600,
                      ),
                      child: FittedBox(
                        child: Text(
                          'Full (\$${currentBalance.toStringAsFixed(2)})',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildPaymentMethodSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: _paymentMethods.map((method) {
              return RadioListTile<String>(
                value: method['value'],
                groupValue: _paymentMethod,
                onChanged: (value) => setState(() => _paymentMethod = value!),
                title: Text(
                  method['label'],
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
                secondary: Icon(
                  method['icon'],
                  color: _payAllMode
                      ? Colors.green.shade600
                      : Colors.blue.shade600,
                  size: isSmallScreen ? 20 : 24,
                ),
                activeColor:
                    _payAllMode ? Colors.green.shade600 : Colors.blue.shade600,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 16,
                  vertical: isSmallScreen ? 4 : 8,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptOptionsSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: _generateReceipt,
            onChanged: (value) => setState(() => _generateReceipt = value!),
            title: Text(
              _payAllMode ? 'Generate Receipts' : 'Generate Receipt',
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
            subtitle: Text(
              _payAllMode
                  ? 'Create PDF receipts for each invoice payment'
                  : 'Create a PDF receipt for this payment',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
            activeColor: Colors.green.shade600,
            contentPadding: EdgeInsets.zero,
          ),
          if (_generateReceipt && !_payAllMode) ...[
            SizedBox(height: isSmallScreen ? 6 : 8),
            TextFormField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'Receipt Reference',
                labelStyle: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                hintText: 'REF-001',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    _referenceController.text =
                        ReceiptService.generateReference();
                  },
                  icon: Icon(Icons.refresh, size: isSmallScreen ? 20 : 24),
                ),
                contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              ),
            ),
          ],
          if (_generateReceipt && _payAllMode) ...[
            SizedBox(height: isSmallScreen ? 6 : 8),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: isSmallScreen ? 18 : 20,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      'Individual receipts will be generated with unique references for each invoice',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.blue.shade700,
                      ),
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

  Widget _buildSummaryItem(String label, String value,
      {Color? color, bool isSmall = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmall ? 14 : 16,
            color: color ?? Colors.black87,
          ),
        ),
        SizedBox(height: isSmall ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 10 : 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
