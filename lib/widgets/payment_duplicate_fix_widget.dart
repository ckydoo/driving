// lib/widgets/payment_duplicate_fix_widget.dart
// Add this widget to your settings screen or create a debug/admin panel

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/payment_sync_integration.dart';
import '../controllers/billing_controller.dart';

class PaymentDuplicateFixWidget extends StatefulWidget {
  @override
  _PaymentDuplicateFixWidgetState createState() =>
      _PaymentDuplicateFixWidgetState();
}

class _PaymentDuplicateFixWidgetState extends State<PaymentDuplicateFixWidget> {
  bool _isFixing = false;
  Map<String, dynamic>? _duplicateReport;
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadDuplicateReport();
  }

  Future<void> _loadDuplicateReport() async {
    try {
      final report = await PaymentSyncIntegration.instance.getDuplicateReport();
      setState(() {
        _duplicateReport = report;
      });
    } catch (e) {
      print('Error loading duplicate report: $e');
    }
  }

  Future<void> _fixDuplicatesNow() async {
    setState(() {
      _isFixing = true;
    });

    try {
      // Show progress dialog
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false, // Prevent dismissal
          child: AlertDialog(
            title: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 16),
                Text('Fixing Payment Duplicates'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Please wait while we fix the payment duplicates...'),
                SizedBox(height: 12),
                Text('• Removing duplicate payments',
                    style: TextStyle(fontSize: 12)),
                Text('• Recalculating invoice balances',
                    style: TextStyle(fontSize: 12)),
                Text('• Preparing for re-sync', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Fix the duplicates
      await PaymentSyncIntegration.instance.fixDuplicatePaymentsNow();

      // Refresh data
      final billingController = Get.find<BillingController>();
      await billingController.fetchBillingData();

      // Reload reports
      await _loadDuplicateReport();

      // Close loading dialog
      Get.back();

      // Show success
      Get.snackbar(
        'Success',
        'Payment duplicates fixed successfully! Invoice balances have been recalculated.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      Get.back(); // Close loading

      Get.snackbar(
        'Error',
        'Failed to fix duplicates: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
        icon: Icon(Icons.error, color: Colors.white),
      );
    } finally {
      setState(() {
        _isFixing = false;
      });
    }
  }

  Future<void> _runEnhancedSync() async {
    setState(() {
      _isFixing = true;
    });

    try {
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 16),
                Text('Enhanced Sync'),
              ],
            ),
            content: Text('Running enhanced sync with duplicate prevention...'),
          ),
        ),
        barrierDismissible: false,
      );

      await PaymentSyncIntegration.instance.triggerEnhancedSync();

      // Refresh data
      final billingController = Get.find<BillingController>();
      await billingController.fetchBillingData();

      await _loadDuplicateReport();

      Get.back(); // Close loading

      Get.snackbar(
        'Success',
        'Enhanced sync completed successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: Icon(Icons.sync, color: Colors.white),
      );
    } catch (e) {
      Get.back();

      Get.snackbar(
        'Error',
        'Enhanced sync failed: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error, color: Colors.white),
      );
    } finally {
      setState(() {
        _isFixing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payments Sync and fix'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: BackButton(),
      ),
      body: Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.healing, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Payment Duplicate Fix',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Duplicate Report
              if (_duplicateReport != null) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.payments,
                              size: 16, color: Colors.blue.shade600),
                          SizedBox(width: 4),
                          Text(
                              'Total Payments: ${_duplicateReport!['total_payments']}'),
                        ],
                      ),
                      if ((_duplicateReport!['reference_duplicates'] ?? 0) >
                          0) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.warning, size: 16, color: Colors.orange),
                            SizedBox(width: 4),
                            Text(
                              'Reference Duplicates: ${_duplicateReport!['reference_duplicates']}',
                              style: TextStyle(color: Colors.orange.shade800),
                            ),
                          ],
                        ),
                      ],
                      if ((_duplicateReport!['detail_duplicates'] ?? 0) >
                          0) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.warning, size: 16, color: Colors.orange),
                            SizedBox(width: 4),
                            Text(
                              'Detail Duplicates: ${_duplicateReport!['detail_duplicates']}',
                              style: TextStyle(color: Colors.orange.shade800),
                            ),
                          ],
                        ),
                      ],
                      if ((_duplicateReport!['reference_duplicates'] ?? 0) ==
                              0 &&
                          (_duplicateReport!['detail_duplicates'] ?? 0) ==
                              0) ...[
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 16, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              'No duplicates detected',
                              style: TextStyle(color: Colors.green.shade800),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isFixing ? null : _fixDuplicatesNow,
                      icon: Icon(Icons.healing),
                      label: Text('Fix Duplicates Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isFixing ? null : _runEnhancedSync,
                      icon: Icon(Icons.sync),
                      label: Text('Enhanced Sync'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Refresh Report Button
              Center(
                child: TextButton.icon(
                  onPressed: _isFixing ? null : _loadDuplicateReport,
                  icon: Icon(Icons.refresh, size: 16),
                  label: Text('Refresh Report'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Warning Text
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info,
                            size: 16, color: Colors.amber.shade800),
                        SizedBox(width: 8),
                        Text(
                          'What this does:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Removes duplicate payments based on reference numbers\n'
                      '• Removes duplicates with same invoice+amount+date\n'
                      '• Recalculates invoice balances to fix negatives\n'
                      '• Prevents future duplicates during sync',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade800,
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
}

// HOW TO USE THIS WIDGET:
// 1. Add it to your settings screen or create a debug panel
// 2. Import and use like this:
/*
// In your settings screen or debug panel:
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... your other settings widgets ...
            
            PaymentDuplicateFixWidget(), // Add this line
            
            // ... more settings widgets ...
          ],
        ),
      ),
    );
  }
}
*/
