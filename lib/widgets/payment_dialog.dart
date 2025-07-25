import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
  String _paymentMethod = 'cash';
  bool _isRecording = false;
  bool _isPartialPayment = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'cash', 'label': 'Cash', 'icon': Icons.money},
    {'value': 'credit_card', 'label': 'Credit Card', 'icon': Icons.credit_card},
    {'value': 'debit_card', 'label': 'Debit Card', 'icon': Icons.payment},
    {
      'value': 'bank_transfer',
      'label': 'Bank Transfer',
      'icon': Icons.account_balance
    },
    {'value': 'check', 'label': 'Check', 'icon': Icons.receipt_long},
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
      // Show confirmation dialog
      final confirmed = await _showConfirmationDialog();
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

        await Get.find<BillingController>().recordPayment(payment);

        // Success animation and feedback
        await _showSuccessAnimation();

        // Close the payment dialog
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        }

        // Show success snackbar
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

  Future<bool> _showConfirmationDialog() async {
    final amount = double.parse(_amountController.text);
    final methodLabel = _paymentMethods
        .firstWhere((method) => method['value'] == _paymentMethod)['label'];

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.confirmation_number, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text('Confirm Payment'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConfirmationRow('Student:', widget.studentName),
                _buildConfirmationRow('Invoice #:', '${widget.invoice.id}'),
                _buildConfirmationRow(
                    'Amount:', '\$${amount.toStringAsFixed(2)}'),
                _buildConfirmationRow('Method:', methodLabel),
                if (_notesController.text.trim().isNotEmpty)
                  _buildConfirmationRow('Notes:', _notesController.text.trim()),
                if (_isPartialPayment)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info,
                            color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is a partial payment. Remaining balance: \$${(widget.invoice.balance - amount).toStringAsFixed(2)}',
                            style: TextStyle(
                                color: Colors.orange.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  Future<void> _showSuccessAnimation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
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
              ],
            ),
          ),
        ),
      ),
    );

    // Auto-dismiss after animation completes
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop(); // Close success dialog
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payment,
                        color: Colors.white,
                        size: 24,
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
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Invoice Summary Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.receipt,
                                      color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Invoice #${widget.invoice.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSummaryItem('Total Amount',
                                      '\$${totalAmount.toStringAsFixed(2)}'),
                                  _buildSummaryItem('Paid',
                                      '\$${paidAmount.toStringAsFixed(2)}'),
                                  _buildSummaryItem('Balance',
                                      '\$${remainingBalance.toStringAsFixed(2)}',
                                      isHighlighted: true),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

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
                                'Full Balance', remainingBalance),
                            _buildQuickAmountButton(
                                'Half', remainingBalance / 2),
                            if (remainingBalance >= 100)
                              _buildQuickAmountButton('\$100', 100),
                            if (remainingBalance >= 50)
                              _buildQuickAmountButton('\$50', 50),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Payment Amount
                        const Text(
                          'Payment Amount',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.blue.shade600, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          onChanged: _onAmountChanged,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount';
                            }
                            if (amount > remainingBalance) {
                              return 'Amount cannot exceed balance of \$${remainingBalance.toStringAsFixed(2)}';
                            }
                            return null;
                          },
                        ),

                        if (_isPartialPayment) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Partial payment - Remaining balance will be \$${(remainingBalance - (double.tryParse(_amountController.text) ?? 0)).toStringAsFixed(2)}',
                                    style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Payment Method
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.5,
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
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue.shade600
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
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      method['label'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.blue.shade600
                                            : Colors.grey.shade700,
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

                        // Notes
                        const Text(
                          'Notes (Optional)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            hintText: 'Add any notes about this payment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16),
                        ),
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
                            : const Text(
                                'Record Payment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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

  Widget _buildSummaryItem(String label, String value,
      {bool isHighlighted = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isHighlighted ? Colors.red.shade700 : Colors.grey.shade800,
          ),
        ),
      ],
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
