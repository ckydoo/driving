// Enhanced PaymentDialog with receipt functionality
// Replace your existing PaymentDialog with this version

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/services/receipt_service.dart';

class PaymentDialog extends StatefulWidget {
  final Invoice invoice;
  final String studentName;
  final int studentId;

  const PaymentDialog({
    Key? key,
    required this.invoice,
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
  // ignore: unused_field
  bool _isPartialPayment = false;
  bool _generateReceipt = true; // NEW: Option to generate receipt
  bool _autoGenerateReference = true; // NEW: Auto-generate reference
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

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
    _amountController.text = widget.invoice.balance.toStringAsFixed(2);
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

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    if (value.isNotEmpty) {
      final amount = double.tryParse(value) ?? 0;
      setState(() {
        _isPartialPayment = amount < widget.invoice.balance;
      });
    }
  }

  void _setQuickAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(2);
    _onAmountChanged(amount.toString());
  }

  void _submitPayment() async {
    if (_formKey.currentState!.validate()) {
      final confirmed = await _showConfirmationDialog();
      if (!confirmed) return;

      setState(() => _isRecording = true);

      try {
        final amount = double.parse(_amountController.text);
        final reference = _autoGenerateReference
            ? ReceiptService.generateReference()
            : _referenceController.text.trim();

        final payment = Payment(
          invoiceId: widget.invoice.id!,
          amount: amount,
          method: _paymentMethod,
          paymentDate: DateTime.now(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          reference: reference,
          receiptGenerated: false, // Will be updated after receipt generation
        );

        final billingController = Get.find<BillingController>();
        final userController = Get.find<UserController>();

        if (_generateReceipt) {
          // Get student data
          final student = userController.users.firstWhere(
            (user) => user.id == widget.studentId,
            orElse: () => throw Exception('Student not found'),
          );

          // Record payment with receipt
          await billingController.recordPaymentWithReceipt(
              payment, widget.invoice, student);
        } else {
          // Record payment without receipt
          await billingController.recordPayment(payment);
        }

        await _showSuccessAnimation();

        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to record payment: ${e.toString()}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
      } finally {
        setState(() => _isRecording = false);
      }
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
                      const Text('Receipt will be generated',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
                if (!_autoGenerateReference &&
                    _referenceController.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Reference: ${_referenceController.text}',
                      style: const TextStyle(fontSize: 12)),
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
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showSuccessAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.green.shade600,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Recorded!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_generateReceipt) ...[
                const SizedBox(height: 8),
                Text(
                  'Receipt generated successfully',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.invoice.totalAmountCalculated;
    final paidAmount = widget.invoice.amountPaid;
    final remainingBalance = widget.invoice.balance;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight:
                  MediaQuery.of(context).size.height * 0.9, // Add max height
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade700],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Payment for ${widget.studentName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Paid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${paidAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Balance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${remainingBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: remainingBalance > 0
                                        ? Colors.yellow
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Make the content area scrollable
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quick Amount Buttons
                            const Text(
                              'Quick Amounts',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildQuickAmountButton(
                                    'Half', remainingBalance / 2),
                                _buildQuickAmountButton(
                                    'Full', remainingBalance),
                                _buildQuickAmountButton('\$50', 50),
                                _buildQuickAmountButton('\$100', 100),
                                _buildQuickAmountButton('\$200', 200),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Amount Input
                            TextFormField(
                              controller: _amountController,
                              decoration: InputDecoration(
                                labelText: 'Payment Amount',
                                prefixText: '',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.blue.shade600, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              onChanged: _onAmountChanged,
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Please enter an amount';
                                final amount = double.tryParse(value);
                                if (amount == null || amount <= 0)
                                  return 'Please enter a valid amount';
                                if (amount > remainingBalance)
                                  return 'Amount cannot exceed balance';
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Payment Method
                            const Text(
                              'Payment Method',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: _paymentMethods.map((method) {
                                  return RadioListTile<String>(
                                    value: method['value'],
                                    groupValue: _paymentMethod,
                                    onChanged: (value) =>
                                        setState(() => _paymentMethod = value!),
                                    title: Row(
                                      children: [
                                        Icon(method['icon'],
                                            size: 20,
                                            color: Colors.blue.shade600),
                                        const SizedBox(width: 8),
                                        Text(method['label']),
                                      ],
                                    ),
                                    dense: true,
                                  );
                                }).toList(),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Receipt Options
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.receipt_long,
                                          color: Colors.blue.shade600,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Receipt Options',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Generate Receipt Toggle
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _generateReceipt,
                                        onChanged: (value) => setState(
                                            () => _generateReceipt = value!),
                                        activeColor: Colors.blue.shade600,
                                      ),
                                      const Expanded(
                                        child: Text(
                                          'Generate PDF receipt',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Auto-generate Reference Toggle
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _autoGenerateReference,
                                        onChanged: (value) => setState(() {
                                          _autoGenerateReference = value!;
                                          if (value) {
                                            _referenceController.text =
                                                ReceiptService
                                                    .generateReference();
                                          }
                                        }),
                                        activeColor: Colors.blue.shade600,
                                      ),
                                      const Expanded(
                                        child: Text(
                                          'Auto-generate reference number',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Manual Reference Input
                                  if (!_autoGenerateReference) ...[
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _referenceController,
                                      decoration: InputDecoration(
                                        labelText: 'Reference Number',
                                        hintText: 'Enter payment reference',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                      ),
                                      validator: (value) {
                                        if (!_autoGenerateReference &&
                                            (value == null || value.isEmpty)) {
                                          return 'Please enter a reference number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Notes
                            TextFormField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: 'Notes (Optional)',
                                hintText: 'Add any payment notes...',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.blue.shade600, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              maxLines: 3,
                              maxLength: 200,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isRecording ? null : _submitPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isRecording
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.payment, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _generateReceipt
                                          ? 'Pay & Generate Receipt'
                                          : 'Record Payment',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String label, double amount) {
    return ElevatedButton(
      onPressed: () => _setQuickAmount(amount),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade700,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.blue.shade200),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
