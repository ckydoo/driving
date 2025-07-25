import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/models/billing_record.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/user.dart';
import 'package:driving/widgets/payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart'; // Import intl for date formatting

class StudentInvoiceScreen extends StatelessWidget {
  final User student;

  const StudentInvoiceScreen({Key? key, required this.student})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final BillingController billingController = Get.find();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Invoices for ${student.fname} ${student.lname}',
          style: const TextStyle(
            color: Colors.white, // Consistent app bar title color
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800, // Use app's primary color
        elevation: 0,
        iconTheme:
            const IconThemeData(color: Colors.white), // Style back button color
      ),
      body: Obx(() {
        if (billingController.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
                color: Colors.blue), // Use app's accent color
          );
        }

        final studentInvoices = billingController.invoices
            .where((invoice) => invoice.studentId == student.id)
            .toList();

        if (studentInvoices.isEmpty) {
          return const Center(
            child: Text(
              'No invoices found for this student',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: studentInvoices.length,
          itemBuilder: (context, index) {
            final invoice = studentInvoices[index];
            return InvoiceCard(
              invoice: invoice,
              student: student,
            );
          },
        );
      }),
    );
  }
}

class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final User student;

  const InvoiceCard({
    Key? key,
    required this.invoice,
    required this.student,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final BillingController billingController = Get.find();

    final bool isOverdue =
        invoice.dueDate.isBefore(DateTime.now()) && invoice.balance > 0;

    return FutureBuilder<String>(
      future: billingController.getCourseName(invoice.courseId),
      builder: (context, snapshot) {
        final courseName = snapshot.data ?? 'Loading...';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          color: isOverdue ? Colors.red.shade50 : null,
          child: ExpansionTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice #${invoice.id}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isOverdue ? Colors.red : Colors.blueGrey,
                  ),
                ),
                _buildStatusChip(invoice.status),
              ],
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(
                      color: Colors.grey,
                      height: 20,
                    ),
                    _buildDetailText('Course', courseName,
                        fontWeight: FontWeight.w500),
                    _buildDetailText('Lessons', '${invoice.lessons}'),
                    _buildDetailText('Price/Lesson',
                        '\$${invoice.pricePerLesson.toStringAsFixed(2)}'),
                    _buildDetailText('Total', invoice.formattedTotal,
                        fontSize: 16, fontWeight: FontWeight.bold),
                    _buildDetailText(
                        'Paid', '\$${invoice.amountPaid.toStringAsFixed(2)}',
                        color: Colors.green.shade700),
                    _buildDetailText('Balance', invoice.formattedBalance,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red),
                    _buildDetailText('Due Date',
                        DateFormat('MMM dd, yyyy').format(invoice.dueDate),
                        color: isOverdue ? Colors.red : null),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (invoice.balance > 0)
                          ElevatedButton(
                            onPressed: () => Get.dialog(PaymentDialog(
                              invoice: invoice,
                              studentName: '${student.fname} ${student.lname}',
                            )),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w500),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Record Payment'),
                          ),
                        ElevatedButton(
                          onPressed: () => _generateAndDownloadPdf(invoice),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w500),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Download PDF'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            if (invoice.id != null) {
                              _deleteInvoice(invoice.id!);
                            } else {
                              Get.snackbar(
                                'Error',
                                'Invoice ID is null.',
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // In InvoiceCard widget:
              ExpansionTile(
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text('Invoice Number: ${invoice.id} '),
                children: [
                  // Display Payment Log
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      'Total Paid \$ ${invoice.totalAmount} - Amount Paid \$ ${invoice.amountPaid} = Balance: \$ ${invoice.balance.toDouble()}', // Display total amount
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  if (invoice.payments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No payments recorded for this invoice.'),
                    )
                  else
                    ...invoice.payments
                        .map((payment) => ListTile(
                              leading: const Icon(Icons.attach_money),
                              title:
                                  Text('Payment: ${payment.formattedAmount}'),
                              subtitle: Text('Date: ${payment.formattedDate}'),
                              trailing: Text(
                                  'Method: ${payment.method}'), // Show payment method
                            ))
                        .toList(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Invoice Status: ${invoice.status}',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Delete Invoice
void _deleteInvoice(int invoiceId) {
  Get.dialog(
    AlertDialog(
      title: const Text('Delete Invoice'),
      content: const Text('Are you sure you want to delete this invoice?'),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final BillingController billingController = Get.find();
            await billingController.deleteInvoice(invoiceId);
            Get.back();
            Get.snackbar(
              'Invoice Deleted',
              'Invoice #$invoiceId has been deleted.',
              duration: const Duration(seconds: 3),
            );
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

Widget _buildDetailText(
  String label,
  String value, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize ?? 14,
          color: color ?? Colors.black87,
          fontWeight: fontWeight,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

Widget _buildStatusChip(String status) {
  Color chipColor;
  switch (status.toLowerCase()) {
    case 'paid':
      chipColor = Colors.green.shade100;
      break;
    case 'pending':
      chipColor = Colors.orange.shade100;
      break;
    case 'overdue':
      chipColor = Colors.red.shade100;
      break;
    default:
      chipColor = Colors.grey.shade300;
  }
  return Chip(
    label: Text(
      status.toUpperCase(),
      style: TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    ),
    backgroundColor: chipColor,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'paid':
      return Colors.green;
    case 'pending':
      return Colors.orange;
    case 'overdue':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

Future<void> _generateAndDownloadPdf(Invoice invoice) async {
  try {
    final doc = await _generateInvoiceDocument(invoice);
    final pdfFile = await doc.save();
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/invoice_${invoice.id}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfFile);

    Get.snackbar(
      'Invoice Saved',
      'Invoice ${invoice.id} has been saved to: $filePath',
      duration: const Duration(seconds: 5),
    );
  } catch (e) {
    Get.snackbar(
      'Error Saving Invoice',
      'An error occurred while saving the invoice: ${e.toString()}',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}

Future<dynamic> _generateInvoiceDocument(Invoice invoice) async {
  final doc = pw.Document();
  final BillingController billingController = Get.find();
  final courseName = await billingController.getCourseName(invoice.courseId);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Invoice #${invoice.id}',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(invoice.formattedDueDate),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Course:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(courseName),
                ],
              ),
              // Rest of the PDF content...
            ],
          ),
        );
      },
    ),
  );
  return doc;
}
