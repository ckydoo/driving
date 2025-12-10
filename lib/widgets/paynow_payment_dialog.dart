import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../services/paynow_service.dart';

class PaynowPaymentDialog extends StatefulWidget {
  final int invoiceId;
  final String invoiceNumber;
  final double amount;
  final VoidCallback onPaymentSuccess;

  const PaynowPaymentDialog({
    Key? key,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
    required this.onPaymentSuccess,
  }) : super(key: key);

  @override
  State<PaynowPaymentDialog> createState() => _PaynowPaymentDialogState();
}

class _PaynowPaymentDialogState extends State<PaynowPaymentDialog> {
  final PaynowService _paynowService = PaynowService();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedMethod = 'web';
  bool _isProcessing = false;
  String? _errorMessage;
  String? _instructions;
  Timer? _statusCheckTimer;
  int _statusCheckAttempts = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
            maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Expanded(child: SingleChildScrollView(child: _buildContent())),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[700],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.payment, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pay with Paynow',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text('Invoice: ${widget.invoiceNumber}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 14)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAmountDisplay(),
          SizedBox(height: 24),
          if (_instructions == null) ...[
            Text('Select Payment Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _buildPaymentMethodOption(
                'web',
                'Web Payment',
                'Pay using Visa, Mastercard, EcoCash etc via Paynow web portal',
                Icons.language),
            _buildPaymentMethodOption('ecocash', 'EcoCash Direct',
                'Pay directly from your EcoCash wallet', Icons.phone_android),
            if (_selectedMethod != 'web') ...[
              SizedBox(height: 16),
              _buildPhoneInput(),
            ],
          ],
          if (_instructions != null) _buildInstructions(),
          if (_errorMessage != null) _buildErrorMessage(),
          SizedBox(height: 24),
          if (_instructions == null) _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Amount to Pay:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Text('\$${widget.amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700])),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption(
      String value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? Colors.green[700]! : Colors.grey[300]!,
              width: 2),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedMethod,
              onChanged: (val) => setState(() => _selectedMethod = val!),
              activeColor: Colors.green[700],
            ),
            Icon(icon,
                color: isSelected ? Colors.green[700] : Colors.grey[600]),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return TextField(
      controller: _phoneController,
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        hintText: '0771234567',
        prefixIcon: Icon(Icons.phone),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        helperText: 'Enter your Zimbabwe mobile number',
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 32),
          SizedBox(height: 12),
          Text(_instructions!, textAlign: TextAlign.center),
          SizedBox(height: 12),
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text('Waiting for payment confirmation...',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            SizedBox(width: 12),
            Expanded(
                child: Text(_errorMessage!,
                    style: TextStyle(color: Colors.red[900]))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Processing...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline),
                  SizedBox(width: 8),
                  Text('Proceed to Payment',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (_selectedMethod == 'web') {
        await _processWebPayment();
      } else {
        await _processMobilePayment();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<void> _processWebPayment() async {
    final result = await _paynowService.initiateWebPayment(widget.invoiceId);
    if (result['success'] == true) {
      final uri = Uri.parse(result['redirect_url'] as String);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _startStatusCheck();
        setState(() {
          _instructions =
              'Complete your payment in the browser.\n\nReturn here after payment is complete.';
          _isProcessing = false;
        });
      } else {
        throw Exception('Could not open payment page');
      }
    }
  }

  Future<void> _processMobilePayment() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) throw Exception('Please enter your mobile number');

    final result = await _paynowService.initiateMobilePayment(
      invoiceId: widget.invoiceId,
      phoneNumber: phoneNumber,
      method: _selectedMethod,
    );

    if (result['success'] == true) {
      setState(() {
        _instructions = result['instructions'] as String;
        _isProcessing = false;
      });
      _startStatusCheck();
    }
  }

  void _startStatusCheck() {
    _statusCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      _statusCheckAttempts++;
      if (_statusCheckAttempts > 60) {
        timer.cancel();
        setState(() {
          _errorMessage =
              'Payment status check timeout.\nPlease refresh to see if payment was successful.';
        });
        return;
      }

      try {
        final result =
            await _paynowService.checkPaymentStatus(widget.invoiceId);
        if (result['success'] == true && result['paid'] == true) {
          timer.cancel();
          Get.back();
          Get.snackbar(
            'Payment Successful! 🎉',
            'Your subscription has been updated.',
            backgroundColor: Colors.green[100],
            colorText: Colors.green[900],
            icon: Icon(Icons.check_circle, color: Colors.green[700]),
            duration: Duration(seconds: 4),
          );
          widget.onPaymentSuccess();
        }
      } catch (e) {
        print('Status check error: $e');
      }
    });
  }
}
