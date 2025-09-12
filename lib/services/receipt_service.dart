// lib/services/receipt_service.dart - Local-Only Receipt Generation
import 'dart:io';
import 'dart:math';
import 'package:driving/models/course.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/payment.dart';
import '../models/invoice.dart';
import '../models/user.dart';
import '../controllers/settings_controller.dart';
import '../services/database_helper.dart';

class ReceiptService {
  static const String _receiptFolder = 'receipts';

  /// Generate a unique reference number for receipts
  static String generateReference() {
    final now = DateTime.now();
    final random = Random();
    return 'RCP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${random.nextInt(9999).toString().padLeft(4, '0')}';
  }

  /// Generate receipt and save to local storage (main method)
  static Future<String> generateAndUploadReceipt(
    Payment payment,
    Invoice invoice,
    User student,
  ) async {
    try {
      print('📄 Generating local receipt for payment ${payment.id}');

      // Get course data
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> results = await db.query(
        'courses',
        where: 'id = ?',
        whereArgs: [invoice.courseId],
      );

      if (results.isEmpty) {
        throw Exception('Course not found for invoice ${invoice.id}');
      }

      final course = Course.fromJson(results.first);

      // Create the receipt PDF
      final pdfBytes =
          await _generateReceiptPDF(payment, invoice, student, course);

      // Save to local storage
      final filePath = await _saveReceiptToLocal(pdfBytes, payment);

      print('✅ Receipt saved to: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Receipt generation failed: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> batchUploadReceipts(
    List<Payment> payments, {
    Function(int current, int total)? onProgress,
  }) async {
    int successCount = 0;
    int failureCount = 0;
    final total = payments.length;

    for (int i = 0; i < payments.length; i++) {
      try {
        final downloadUrl = await generateReceiptSmart(payments[i]);
        if (downloadUrl != null) {
          successCount++;
        } else {
          failureCount++;
        }
        onProgress?.call(i + 1, total);
      } catch (e) {
        failureCount++;
        print('Failed to upload receipt for payment ${payments[i].id}: $e');
      }
    }

    return {
      'success_count': successCount,
      'failure_count': failureCount,
      'total_processed': total,
    };
  }

  /// Generate receipt with smart fallback (alias for main method)
  static Future<String> generateReceiptSmart(Payment payment) async {
    // Get related invoice and student data
    final invoice = await _getInvoiceForPayment(payment);
    final student = await _getStudentForInvoice(invoice);

    return await generateAndUploadReceipt(payment, invoice, student);
  }

  /// Generate receipt PDF bytes
  static Future<Uint8List> _generateReceiptPDF(
    Payment payment,
    Invoice invoice,
    User student,
    Course course,
  ) async {
    final pdf = pw.Document();
    final settings = Get.find<SettingsController>();

    // Generate receipt data
    final receiptData =
        _buildReceiptData(payment, invoice, student, course, settings);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with business info
              _buildReceiptHeader(settings),

              pw.SizedBox(height: 30),

              // Receipt title and number
              _buildReceiptTitle(payment),

              pw.SizedBox(height: 20),

              // Student and payment info
              _buildStudentInfo(student),

              pw.SizedBox(height: 20),

              // Payment details table
              _buildPaymentDetails(receiptData),

              pw.SizedBox(height: 30),

              // Summary section
              _buildPaymentSummary(payment, invoice),

              pw.SizedBox(height: 30),

              // Footer
              _buildReceiptFooter(settings),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Save receipt PDF to local storage
  static Future<String> _saveReceiptToLocal(
      Uint8List pdfBytes, Payment payment) async {
    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final receiptDir = Directory('${directory.path}/$_receiptFolder');

      // Create receipts folder if it doesn't exist
      if (!await receiptDir.exists()) {
        await receiptDir.create(recursive: true);
      }

      // Generate filename
      final fileName = _generateReceiptFileName(payment);
      final filePath = '${receiptDir.path}/$fileName';

      // Save file
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      return filePath;
    } catch (e) {
      print('❌ Error saving receipt to local storage: $e');
      rethrow;
    }
  }

  /// Generate receipt filename
  static String _generateReceiptFileName(Payment payment) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(payment.paymentDate);
    final receiptNumber = payment.receiptNumber.replaceAll('-', '_');
    return 'receipt_${receiptNumber}_$timestamp.pdf';
  }

  /// Print receipt from local file
  static Future<void> printReceipt(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Receipt file not found: $filePath');
      }

      final pdfBytes = await file.readAsBytes();
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes);
    } catch (e) {
      print('❌ Error printing receipt: $e');
      rethrow;
    }
  }

  /// Print receipt from cloud URL (for compatibility)
  static Future<void> printReceiptFromCloud(String cloudUrl) async {
    // For local-only implementation, treat as file path
    await printReceipt(cloudUrl);
  }

  /// Share receipt from local file
  static Future<void> shareReceipt(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Receipt file not found: $filePath');
      }

      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        subject: 'Payment Receipt',
        text: 'Please find attached payment receipt.',
      );
    } catch (e) {
      print('❌ Error sharing receipt: $e');
      rethrow;
    }
  }

  /// Share receipt from cloud URL (for compatibility)
  static Future<void> shareReceiptFromCloud(String cloudUrl) async {
    // For local-only implementation, treat as file path
    await shareReceipt(cloudUrl);
  }

  /// View receipt (open in default PDF viewer)
  static Future<void> viewReceipt(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Receipt file not found: $filePath');
      }

      final pdfBytes = await file.readAsBytes();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'receipt.pdf',
      );
    } catch (e) {
      print('❌ Error viewing receipt: $e');
      rethrow;
    }
  }

  /// Delete receipt file
  static Future<bool> deleteReceipt(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting receipt: $e');
      return false;
    }
  }

  /// Get all local receipts
  static Future<List<String>> getLocalReceipts() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final receiptDir = Directory('${directory.path}/$_receiptFolder');

      if (!await receiptDir.exists()) {
        return [];
      }

      final files = receiptDir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.pdf'))
          .map((entity) => entity.path)
          .toList();

      return files;
    } catch (e) {
      print('❌ Error getting local receipts: $e');
      return [];
    }
  }

  /// Clean up old receipts (older than specified days)
  static Future<int> cleanupOldReceipts({int daysOld = 365}) async {
    try {
      final receipts = await getLocalReceipts();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      int deletedCount = 0;

      for (final receiptPath in receipts) {
        final file = File(receiptPath);
        final stats = await file.stat();

        if (stats.modified.isBefore(cutoffDate)) {
          await file.delete();
          deletedCount++;
        }
      }

      return deletedCount;
    } catch (e) {
      print('❌ Error cleaning up receipts: $e');
      return 0;
    }
  }

  // PDF Building Helper Methods

  static pw.Widget _buildReceiptHeader(SettingsController settings) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                settings.businessName.value.isNotEmpty
                    ? settings.businessName.value
                    : 'Driving School',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              if (settings.businessAddress.value.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  settings.businessAddress.value,
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey600),
                ),
              ],
              if (settings.businessPhone.value.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Phone: ${settings.businessPhone.value}',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey600),
                ),
              ],
              if (settings.businessEmail.value.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Email: ${settings.businessEmail.value}',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey600),
                ),
              ],
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PAYMENT RECEIPT',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptTitle(Payment payment) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Receipt Number',
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
              pw.Text(
                payment.receiptNumber,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Payment Date',
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
              pw.Text(
                DateFormat('MMM dd, yyyy').format(payment.paymentDate),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStudentInfo(User student) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Payment Received From',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${student.fname} ${student.lname}',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (student.email.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Email: ${student.email}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          ],
          if (student.phone != null && student.phone!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Phone: ${student.phone}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildPaymentDetails(Map<String, String> receiptData) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Description', isHeader: true),
            _buildTableCell('Details', isHeader: true),
          ],
        ),
        // Data rows
        ...receiptData.entries.map((entry) => pw.TableRow(
              children: [
                _buildTableCell(entry.key),
                _buildTableCell(entry.value),
              ],
            )),
      ],
    );
  }

  static pw.Widget _buildPaymentSummary(Payment payment, Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Amount Paid',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
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
          if (payment.reference != null && payment.reference!.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Reference',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey600),
                ),
                pw.Text(
                  payment.reference!,
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptFooter(SettingsController settings) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Thank you for your payment!',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'This receipt was generated electronically and is valid without signature.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
            textAlign: pw.TextAlign.center,
          ),
          if (settings.businessWebsite.value.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Visit us at: ${settings.businessWebsite.value}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey700 : PdfColors.black,
        ),
      ),
    );
  }

  // Helper Methods

  static Map<String, String> _buildReceiptData(
    Payment payment,
    Invoice invoice,
    User student,
    Course courses,
    SettingsController settings,
  ) {
    return {
      'Invoice Number': 'INV-${invoice.id.toString().padLeft(6, '0')}',
      'Course': courses.name,
      'Payment Method': payment.displayMethod,
      'Payment Date':
          DateFormat('MMM dd, yyyy - hh:mm a').format(payment.paymentDate),
      'Amount Paid': '\$${payment.amount.toStringAsFixed(2)}',
      if (payment.notes != null && payment.notes!.isNotEmpty)
        'Notes': payment.notes!,
    };
  }

  static Future<Invoice> _getInvoiceForPayment(Payment payment) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> results = await db.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [payment.invoiceId],
      );

      if (results.isEmpty) {
        throw Exception('Invoice not found for payment ${payment.id}');
      }

      return Invoice.fromJson(results.first);
    } catch (e) {
      print('❌ Error getting invoice for payment: $e');
      rethrow;
    }
  }

  static Future<User> _getStudentForInvoice(Invoice invoice) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [invoice.studentId],
      );

      if (results.isEmpty) {
        throw Exception('Student not found for invoice ${invoice.id}');
      }

      return User.fromJson(results.first);
    } catch (e) {
      print('❌ Error getting student for invoice: $e');
      rethrow;
    }
  }
}
