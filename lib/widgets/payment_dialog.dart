import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';

class PaymentDialog extends StatefulWidget {
  final Invoice invoice;

  const PaymentDialog({Key? key, required this.invoice}) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _paymentMethod = 'cash';
  final List<String> _paymentMethods = ['cash', 'credit card', 'bank transfer'];
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    // Initialize the amount field with the remaining balance
    _amountController.text = widget.invoice.balance.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submitPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isRecording = true);
      final amount = double.parse(_amountController.text);
      final payment = Payment(
        invoiceId: widget.invoice.id!,
        amount: amount,
        method: _paymentMethod,
        paymentDate: DateTime.now(),
      );

      await Get.find<BillingController>().recordPayment(payment);
      setState(() => _isRecording = false);
      Get.back();
      Get.snackbar(
        'Payment Recorded',
        'Payment of \$${amount.toStringAsFixed(2)} recorded successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Record Payment',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice Information Display
              const Text(
                'Invoice Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text('Invoice #: ${widget.invoice.id}'),
              const SizedBox(height: 8),
              Text(
                'Total Due: \$${widget.invoice.totalAmountCalculated.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              Text(
                'Current Balance: \$${widget.invoice.balance.toStringAsFixed(2)}',
              ),
              const Divider(height: 24),
              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter payment amount',
                  prefixIcon:
                      const Icon(Icons.attach_money, color: Colors.blue),
                  prefixText: '\$',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  suffixIcon: TextButton(
                    onPressed: () {
                      _amountController.text =
                          widget.invoice.balance.toStringAsFixed(2);
                    },
                    child: const Text(
                      'Max',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Amount is required';
                  final amount = double.tryParse(value);
                  if (amount == null) return 'Invalid amount';
                  if (amount <= 0) return 'Amount must be greater than zero';
                  if (amount > widget.invoice.balance) {
                    return 'Amount exceeds balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Payment Method Dropdown
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem<String>(
                    value: method,
                    child: Text(
                      method.toUpperCase(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _paymentMethod = value!),
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  prefixIcon: const Icon(Icons.payment, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _isRecording
              ? null
              : () {
                  if (_formKey.currentState!.validate()) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text(
                          'Confirm Payment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        content: Text(
                          'Record payment of \$${_amountController.text} via ${_paymentMethod.toUpperCase()}?',
                          style: const TextStyle(fontSize: 16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close confirmation
                              _submitPayment(); // Submit payment
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
              : const Text('Record'),
        ),
      ],
    );
  }
}
