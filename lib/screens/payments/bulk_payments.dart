import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class BulkPaymentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> studentsData;
  final double totalAmount;
  final VoidCallback onPaymentComplete;

  const BulkPaymentDialog({
    Key? key,
    required this.studentsData,
    required this.totalAmount,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  _BulkPaymentDialogState createState() => _BulkPaymentDialogState();
}

class _BulkPaymentDialogState extends State<BulkPaymentDialog> {
  final BillingController billingController = Get.find();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedPaymentMethod = 'cash';
  bool _isProcessing = false;
  bool _payFullAmount = true;
  double _customAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalAmount.toStringAsFixed(2);
    _customAmount = widget.totalAmount;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStudentsList(),
                        const SizedBox(height: 24),
                        _buildPaymentDetails(),
                        const SizedBox(height: 24),
                        _buildPaymentMethod(),
                        const SizedBox(height: 24),
                        _buildNotesField(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payment, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bulk Payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.studentsData.length} students selected',
                  style: const TextStyle(
                    color: Colors.white70,
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
    );
  }

  Widget _buildStudentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Students & Outstanding Amounts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildStudentsHeader(),
              ...widget.studentsData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return _buildStudentRow(data, index);
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Row(
        children: [
          Expanded(
              flex: 3,
              child: Text('Student',
                  style: TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
              flex: 2,
              child: Text('Invoices',
                  style: TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
              flex: 2,
              child: Text('Balance',
                  style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> data, int index) {
    final User student = data['student'];
    final List<Invoice> invoices = data['invoices'];
    final double balance = data['balance'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    '${student.fname[0]}${student.lname[0]}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student.fname} ${student.lname}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        student.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${invoices.length}'),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Pay Full Amount'),
                value: true,
                groupValue: _payFullAmount,
                onChanged: (bool? value) {
                  setState(() {
                    _payFullAmount = value!;
                    if (_payFullAmount) {
                      _amountController.text =
                          widget.totalAmount.toStringAsFixed(2);
                      _customAmount = widget.totalAmount;
                    }
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _amountController,
                enabled: !_payFullAmount,
                decoration: InputDecoration(
                  labelText: 'Payment Amount',
                  prefixText: '\$',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter payment amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount > widget.totalAmount) {
                    return 'Amount cannot exceed total balance';
                  }
                  return null;
                },
                onChanged: (value) {
                  _customAmount = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '\$${widget.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          children: [
            _buildPaymentMethodOption('cash', 'Cash', Icons.money),
            _buildPaymentMethodOption('card', 'Card', Icons.credit_card),
            _buildPaymentMethodOption(
                'bank_transfer', 'Bank Transfer', Icons.account_balance),
            _buildPaymentMethodOption('check', 'Check', Icons.receipt),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption(String value, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes (Optional)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add payment notes or reference...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _isProcessing ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processBulkPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Process Payment'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processBulkPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final paymentAmount = double.parse(_amountController.text);

      // Process bulk payment through billing controller
      await billingController.processBulkPayment(
        studentsData: widget.studentsData,
        paymentAmount: paymentAmount,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim(),
      );

      // Show success message
      Get.snackbar(
        'Success',
        'Bulk payment of \$${paymentAmount.toStringAsFixed(2)} processed successfully',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Close dialog and refresh data
      Navigator.of(context).pop();
      widget.onPaymentComplete();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to process bulk payment: ${e.toString()}',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}
