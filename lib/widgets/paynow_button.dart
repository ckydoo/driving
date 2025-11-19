// lib/widgets/paynow_button.dart
// SIMPLE PAYNOW BUTTON - Drop this anywhere you need a Paynow payment button

import 'package:flutter/material.dart';
import 'package:driving/widgets/paynow_payment_dialog.dart';

class PaynowButton extends StatelessWidget {
  /// The invoice ID to pay
  final int invoiceId;

  /// The invoice number for display
  final String invoiceNumber;

  /// The amount to pay
  final double amount;

  /// Callback when payment is successful
  final VoidCallback onPaymentSuccess;

  /// Button text (default: "Pay with Paynow")
  final String? buttonText;

  /// Button style
  final ButtonStyle? style;

  /// Show icon
  final bool showIcon;

  /// Full width button
  final bool fullWidth;

  /// Button size
  final Size? minimumSize;

  const PaynowButton({
    Key? key,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
    required this.onPaymentSuccess,
    this.buttonText,
    this.style,
    this.showIcon = true,
    this.fullWidth = false,
    this.minimumSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: () => _showPaymentDialog(context),
      style: style ?? _defaultStyle(),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(Icons.mobile_friendly, size: 20),
            SizedBox(width: 8),
          ],
          Text(
            buttonText ?? 'Pay with Paynow',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  ButtonStyle _defaultStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.green[700],
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      minimumSize: minimumSize,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 2,
    );
  }

  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaynowPaymentDialog(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        amount: amount,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================

/*

// EXAMPLE 1: Basic usage
PaynowButton(
  invoiceId: 123,
  invoiceNumber: 'INV-001',
  amount: 50.00,
  onPaymentSuccess: () {
    print('Payment successful!');
    // Reload your data here
  },
)

// EXAMPLE 2: Full width button
PaynowButton(
  invoiceId: 123,
  invoiceNumber: 'INV-001',
  amount: 50.00,
  fullWidth: true,
  onPaymentSuccess: () {
    // Handle success
  },
)

// EXAMPLE 3: Custom text and no icon
PaynowButton(
  invoiceId: 123,
  invoiceNumber: 'INV-001',
  amount: 50.00,
  buttonText: 'Pay \$50.00',
  showIcon: false,
  onPaymentSuccess: () {
    // Handle success
  },
)

// EXAMPLE 4: Custom style
PaynowButton(
  invoiceId: 123,
  invoiceNumber: 'INV-001',
  amount: 50.00,
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange[700],
    padding: EdgeInsets.all(16),
  ),
  onPaymentSuccess: () {
    // Handle success
  },
)

// EXAMPLE 5: In a Card with Stripe option
Card(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text('Pay Invoice INV-001'),
        Text('\$50.00', style: TextStyle(fontSize: 24)),
        SizedBox(height: 16),
        
        // Payment options
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => payWithStripe(),
                child: Text('Stripe'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: PaynowButton(
                invoiceId: 123,
                invoiceNumber: 'INV-001',
                amount: 50.00,
                fullWidth: true,
                buttonText: 'Paynow',
                onPaymentSuccess: () {
                  // Handle success
                },
              ),
            ),
          ],
        ),
      ],
    ),
  ),
)

// EXAMPLE 6: In a list of invoices
ListView.builder(
  itemCount: invoices.length,
  itemBuilder: (context, index) {
    final invoice = invoices[index];
    
    return ListTile(
      title: Text('Invoice ${invoice.number}'),
      subtitle: Text('\$${invoice.amount.toStringAsFixed(2)}'),
      trailing: invoice.isPaid
          ? Icon(Icons.check_circle, color: Colors.green)
          : PaynowButton(
              invoiceId: invoice.id,
              invoiceNumber: invoice.number,
              amount: invoice.amount,
              buttonText: 'Pay',
              onPaymentSuccess: () {
                setState(() {
                  invoice.isPaid = true;
                });
              },
            ),
    );
  },
)

// EXAMPLE 7: With GetX controller
class BillingScreen extends StatelessWidget {
  final SubscriptionController controller = Get.find();
  
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pendingInvoice = controller.pendingInvoice.value;
      
      if (pendingInvoice == null) {
        return Text('No pending invoices');
      }
      
      return PaynowButton(
        invoiceId: pendingInvoice.id,
        invoiceNumber: pendingInvoice.number,
        amount: pendingInvoice.amount,
        fullWidth: true,
        onPaymentSuccess: () {
          controller.loadSubscriptionData();
          Get.snackbar(
            'Success',
            'Payment processed!',
            backgroundColor: Colors.green[100],
          );
        },
      );
    });
  }
}

*/
