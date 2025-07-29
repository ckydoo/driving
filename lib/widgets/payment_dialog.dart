import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';

class PaymentDialog extends StatefulWidget {
  final Invoice invoice;
  final String studentName;

  const PaymentDialog(
      {Key? key, required this.invoice, required this.studentName})
      : super(key: key);

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
  bool _printReceipt = true;

  late AnimationController _animationController;
  late AnimationController _shakeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'value': 'cash',
      'label': 'Cash',
      'icon': Icons.money,
      'color': Colors.green
    },
    {
      'value': 'credit_card',
      'label': 'Credit Card',
      'icon': Icons.credit_card,
      'color': Colors.blue
    },
    {
      'value': 'debit_card',
      'label': 'Debit Card',
      'icon': Icons.payment,
      'color': Colors.purple
    },
    {
      'value': 'bank_transfer',
      'label': 'Bank Transfer',
      'icon': Icons.account_balance,
      'color': Colors.orange
    },
    {
      'value': 'check',
      'label': 'Check',
      'icon': Icons.receipt_long,
      'color': Colors.brown
    },
    {
      'value': 'mobile_payment',
      'label': 'Mobile Pay',
      'icon': Icons.smartphone,
      'color': Colors.indigo
    },
  ];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.invoice.balance.toStringAsFixed(2);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
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
    _shakeController.dispose();
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

  void _setQuickAmount(double percentage) {
    final amount = widget.invoice.balance * percentage;
    _amountController.text = amount.toStringAsFixed(2);
    _onAmountChanged(amount.toString());
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2); // Last 2 digits of year
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final invoiceId = widget.invoice.id.toString().padLeft(4, '0');
    return 'INV-$year$month$day-$invoiceId';
  }

  String _generateReceiptNumber(int paymentId) {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final receiptId = paymentId.toString().padLeft(4, '0');
    return 'RCP-$year$month$day-$receiptId';
  }

  Future<void> _generateReceipt(Payment payment) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildReceiptContent(payment);
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final receiptNumber = _generateReceiptNumber(payment.id!);
      final fileName = 'receipt_$receiptNumber.pdf';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Show success message with option to view receipt
      _showReceiptGeneratedDialog(filePath, receiptNumber);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to generate receipt: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
      );
    }
  }

  pw.Widget _buildReceiptContent(Payment payment) {
    final receiptNumber = _generateReceiptNumber(payment.id!);
    final invoiceNumber = _generateInvoiceNumber();

    return pw.Padding(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PAYMENT RECEIPT',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  receiptNumber,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // Payment Details
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildReceiptRow('Student:', widget.studentName),
                    _buildReceiptRow('Invoice #:', invoiceNumber),
                    _buildReceiptRow(
                        'Payment Date:',
                        DateFormat('MMM dd, yyyy - hh:mm a')
                            .format(payment.paymentDate)),
                    _buildReceiptRow(
                        'Payment Method:', _getPaymentMethodLabel()),
                    if (_referenceController.text.isNotEmpty)
                      _buildReceiptRow('Reference:', _referenceController.text),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('AMOUNT PAID',
                        style: pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey600)),
                    pw.Text(
                      '\$${payment.amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Invoice Summary
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                _buildSummaryRow('Total Invoice Amount:',
                    '\$${widget.invoice.totalAmountCalculated.toStringAsFixed(2)}'),
                _buildSummaryRow('Amount Paid (Before):',
                    '\$${widget.invoice.amountPaid.toStringAsFixed(2)}'),
                _buildSummaryRow(
                    'This Payment:', '\$${payment.amount.toStringAsFixed(2)}',
                    bold: true),
                pw.Divider(),
                _buildSummaryRow('Remaining Balance:',
                    '\$${(widget.invoice.balance - payment.amount).toStringAsFixed(2)}',
                    bold: true),
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // Notes
          if (_notesController.text.isNotEmpty) ...[
            pw.Text('Notes:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(_notesController.text),
            ),
            pw.SizedBox(height: 20),
          ],

          pw.Spacer(),

          // Footer
          pw.Center(
            child: pw.Text(
              'Thank you for your payment!',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'Generated on ${DateFormat('MMM dd, yyyy at hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReceiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  String _getPaymentMethodLabel() {
    return _paymentMethods
        .firstWhere((method) => method['value'] == _paymentMethod)['label'];
  }

  void _showReceiptGeneratedDialog(String filePath, String receiptNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Text('Receipt Generated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Receipt $receiptNumber has been generated successfully!'),
            const SizedBox(height: 8),
            Text('Saved to: ${filePath.split('/').last}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _submitPayment() async {
    if (_formKey.currentState!.validate()) {
      final confirmed = await _showEnhancedConfirmationDialog();
      if (!confirmed) return;

      setState(() => _isRecording = true);

      try {
        final amount = double.parse(_amountController.text);
        final payment = Payment(
          invoiceId: widget.invoice.id!,
          amount: amount,
          method: _paymentMethod,
          paymentDate: DateTime.now(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        // Record payment
        final paymentId =
            await Get.find<BillingController>().insertPayment(payment.toJson());
        final recordedPayment = payment.copyWith(id: paymentId);

        // Update invoice
        await Get.find<BillingController>().fetchBillingData();

        // Generate receipt if requested
        if (_printReceipt) {
          await _generateReceipt(recordedPayment);
        }

        // Success animation
        await _showSuccessAnimation();

        // Close dialog
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        }

        // Success message
        Get.snackbar(
          'Payment Recorded',
          'Payment of \$${amount.toStringAsFixed(2)} recorded successfully for ${widget.studentName}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to record payment: ${e.toString()}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          icon: const Icon(Icons.error, color: Colors.white),
        );
      } finally {
        if (mounted) {
          setState(() => _isRecording = false);
        }
      }
    }
  }

  Future<bool> _showEnhancedConfirmationDialog() async {
    final amount = double.parse(_amountController.text);
    final methodData = _paymentMethods
        .firstWhere((method) => method['value'] == _paymentMethod);

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Confirm Payment',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfirmationCard(),
                  const SizedBox(height: 16),
                  if (_isPartialPayment) _buildPartialPaymentWarning(),
                  if (_printReceipt) _buildReceiptInfo(),
                ],
              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Confirm Payment'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildConfirmationCard() {
    final amount = double.parse(_amountController.text);
    final methodData = _paymentMethods
        .firstWhere((method) => method['value'] == _paymentMethod);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfirmationRow('Student:', widget.studentName),
          _buildConfirmationRow('Invoice #:', _generateInvoiceNumber()),
          _buildConfirmationRow('Amount:', '\$${amount.toStringAsFixed(2)}'),
          Row(
            children: [
              const Text('Method: ',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: methodData['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(methodData['icon'],
                        size: 16, color: methodData['color']),
                    const SizedBox(width: 4),
                    Text(methodData['label'],
                        style: TextStyle(color: methodData['color'])),
                  ],
                ),
              ),
            ],
          ),
          if (_referenceController.text.trim().isNotEmpty)
            _buildConfirmationRow(
                'Reference:', _referenceController.text.trim()),
          if (_notesController.text.trim().isNotEmpty)
            _buildConfirmationRow('Notes:', _notesController.text.trim()),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildPartialPaymentWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This is a partial payment. Remaining balance: \$${(widget.invoice.balance - double.parse(_amountController.text)).toStringAsFixed(2)}',
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A receipt will be generated after payment',
              style: TextStyle(color: Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessAnimation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.green.shade600,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Payment Recorded!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingBalance = widget.invoice.balance;
    final totalAmount = widget.invoice.totalAmountCalculated;
    final paidAmount = totalAmount - remainingBalance;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.payment,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Record Payment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.studentName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Invoice Summary Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.shade50,
                                Colors.grey.shade100
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSummaryItem(
                                    'Total Amount',
                                    '\$${totalAmount.toStringAsFixed(2)}',
                                    Icons.receipt_long,
                                    Colors.blue.shade600,
                                  ),
                                  _buildSummaryItem(
                                    'Already Paid',
                                    '\$${paidAmount.toStringAsFixed(2)}',
                                    Icons.check_circle,
                                    Colors.green.shade600,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.account_balance_wallet,
                                        color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Outstanding Balance: \$${remainingBalance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Amount Input with Quick Options
                        const Text(
                          'Payment Amount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.attach_money),
                            hintText: 'Enter amount',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount';
                            }
                            if (amount > widget.invoice.balance) {
                              return 'Amount cannot exceed balance';
                            }
                            return null;
                          },
                          onChanged: _onAmountChanged,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Quick Amount Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickAmountButton('25%', 0.25),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickAmountButton('50%', 0.50),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickAmountButton('75%', 0.75),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickAmountButton('Full', 1.0),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Payment Method
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),

                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _paymentMethods.length,
                          itemBuilder: (context, index) {
                            final method = _paymentMethods[index];
                            final isSelected =
                                _paymentMethod == method['value'];
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _paymentMethod = method['value']),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? method['color'].withOpacity(0.1)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? method['color']
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      method['icon'],
                                      color: isSelected
                                          ? method['color']
                                          : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      method['label'],
                                      style: TextStyle(
                                        color: isSelected
                                            ? method['color']
                                            : Colors.grey.shade700,
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Reference Number (for non-cash payments)
                        if (_paymentMethod != 'cash') ...[
                          const Text(
                            'Reference Number (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _referenceController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.numbers),
                              hintText:
                                  'Transaction reference, check number, etc.',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Notes
                        const Text(
                          'Notes (Optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 40),
                              child: Icon(Icons.note_add),
                            ),
                            hintText: 'Add any additional notes...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Receipt Option
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Generate Receipt',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Create a PDF receipt for this payment',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _printReceipt,
                                onChanged: (value) =>
                                    setState(() => _printReceipt = value),
                                activeColor: Colors.blue.shade600,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Partial Payment Warning
                        if (_isPartialPayment)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Partial Payment',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                      Text(
                                        'Remaining balance: \${(widget.invoice.balance - (double.tryParse(_amountController.text) ?? 0)).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade600,
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
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isRecording ? null : _submitPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isRecording
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Record Payment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
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
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
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
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAmountButton(String label, double percentage) {
    final amount = widget.invoice.balance * percentage;
    final isSelected = _amountController.text == amount.toStringAsFixed(2);

    return GestureDetector(
      onTap: () => _setQuickAmount(percentage),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// Extension for Payment model to add copyWith method
extension PaymentExtension on Payment {
  Payment copyWith({
    int? id,
    int? invoiceId,
    double? amount,
    String? method,
    DateTime? paymentDate,
    String? notes,
  }) {
    return Payment(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes,
    );
  }
}
