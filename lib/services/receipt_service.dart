// Enhanced Receipt Service with Business Settings Integration
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/payment.dart';
import '../models/invoice.dart';
import '../models/user.dart';
import '../controllers/settings_controller.dart';
import 'package:get/get.dart';

class ReceiptService {
  static String generateReference() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(7);
    return 'PAY-${DateFormat('yyyyMMdd').format(now)}-$timestamp';
  }

  static Future<String> generateReceipt(
    Payment payment,
    Invoice invoice,
    User student,
  ) async {
    // Get business settings from controller
    final settingsController = Get.find<SettingsController>();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Enhanced Header with Business Information
              _buildBusinessHeader(settingsController),

              pw.SizedBox(height: 30),

              // Receipt Title and Reference
              _buildReceiptTitle(payment),

              pw.SizedBox(height: 20),

              // Student and Invoice Information
              _buildStudentAndInvoiceInfo(student, invoice),

              pw.SizedBox(height: 30),

              // Payment Details Table
              _buildPaymentDetailsTable(payment, invoice),

              pw.SizedBox(height: 30),

              // Payment Summary
              _buildPaymentSummary(payment, invoice),

              pw.SizedBox(height: 30),

              // Notes Section
              if (payment.notes != null && payment.notes!.isNotEmpty)
                _buildNotesSection(payment),

              pw.Spacer(),

              // Enhanced Footer
              _buildFooter(settingsController),
            ],
          );
        },
      ),
    );

    // Save PDF file
    final directory = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${directory.path}/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final fileName =
        'receipt_${payment.reference}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${receiptsDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  static pw.Widget _buildBusinessHeader(SettingsController settings) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Business Info
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  settings.businessName.value.isNotEmpty
                      ? settings.businessName.value
                      : 'Driving School',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 8),

                // Address
                if (settings.businessAddress.value.isNotEmpty) ...[
                  pw.Row(
                    children: [
                      pw.Icon(pw.IconData(0xe0c8),
                          size: 12, color: PdfColors.grey600),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        '${settings.businessAddress.value}${settings.businessCity.value.isNotEmpty ? ', ${settings.businessCity.value}' : ''}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                ],

                // Phone
                if (settings.businessPhone.value.isNotEmpty) ...[
                  pw.Row(
                    children: [
                      pw.Icon(pw.IconData(0xe0cd),
                          size: 12, color: PdfColors.grey600),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        settings.businessPhone.value,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                ],

                // Email
                if (settings.businessEmail.value.isNotEmpty) ...[
                  pw.Row(
                    children: [
                      pw.Icon(pw.IconData(0xe0be),
                          size: 12, color: PdfColors.grey600),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        settings.businessEmail.value,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                ],

                // Website
                if (settings.businessWebsite.value.isNotEmpty)
                  pw.Row(
                    children: [
                      pw.Icon(pw.IconData(0xe157),
                          size: 12, color: PdfColors.grey600),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        settings.businessWebsite.value,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Receipt Badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.green600,
              borderRadius: pw.BorderRadius.circular(20),
            ),
            child: pw.Text(
              'RECEIPT',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptTitle(Payment payment) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Payment Receipt',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Thank you for your payment',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Receipt #${payment.reference}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                DateFormat('MMM dd, yyyy').format(payment.paymentDate),
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                DateFormat('HH:mm').format(payment.paymentDate),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildStudentAndInvoiceInfo(User student, Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Student Information
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'STUDENT INFORMATION',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '${student.fname} ${student.lname}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  student.email,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  student.phone,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                if (student.address.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    student.address,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        pw.SizedBox(width: 20),

        // Invoice Information
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INVOICE DETAILS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Invoice #${invoice.invoiceNumber}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Lessons: ${invoice.lessons}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Status: ${invoice.status.toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: invoice.status == 'paid'
                        ? PdfColors.green600
                        : PdfColors.orange600,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Created: ${DateFormat('MMM dd, yyyy').format(invoice.createdAt)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentDetailsTable(Payment payment, Invoice invoice) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          // Header
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.blue50),
            children: [
              _buildTableCell('Description', isHeader: true),
              _buildTableCell('Method', isHeader: true),
              _buildTableCell('Reference', isHeader: true),
              _buildTableCell('Amount', isHeader: true),
            ],
          ),
          // Payment Row
          pw.TableRow(
            children: [
              _buildTableCell('Payment for Invoice #${invoice.invoiceNumber}'),
              _buildTableCell(payment.method.toUpperCase()),
              _buildTableCell(payment.reference ?? 'N/A'),
              _buildTableCell('\$${payment.amount.toStringAsFixed(2)}',
                  isAmount: true),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPaymentSummary(Payment payment, Invoice invoice) {
    final remainingBalance = (invoice.balance - payment.amount).abs();

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PAYMENT SUMMARY',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                  'Invoice Total: \$${invoice.totalAmount.toStringAsFixed(2)}'),
              pw.Text(
                  'Previous Payments: \$${(invoice.totalAmount - invoice.balance).toStringAsFixed(2)}'),
              pw.Text('This Payment: \$${payment.amount.toStringAsFixed(2)}'),
              pw.Divider(color: PdfColors.green300),
              pw.Text(
                'Remaining Balance: \$${remainingBalance.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: remainingBalance > 0
                      ? PdfColors.orange700
                      : PdfColors.green700,
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.green600,
              borderRadius: pw.BorderRadius.circular(50),
            ),
            child: pw.Text(
              '\$${payment.amount.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNotesSection(Payment payment) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            payment.notes!,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(SettingsController settings) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Thank you for choosing ${settings.businessName.value.isNotEmpty ? settings.businessName.value : 'our driving school'}!',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.blue700,
                  ),
                ),
                if (settings.businessWebsite.value.isNotEmpty)
                  pw.Text(
                    'Visit us at: ${settings.businessWebsite.value}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated on',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'This is a computer-generated receipt and does not require a signature.',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey500,
            fontStyle: pw.FontStyle.italic,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text,
      {bool isHeader = false, bool isAmount = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blue800 : PdfColors.grey800,
        ),
        textAlign: isAmount ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  // Additional utility methods
  static Future<void> printReceipt(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
    }
  }

  static Future<void> shareReceipt(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
  }
}
