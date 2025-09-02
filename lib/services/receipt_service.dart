// Cloud-Based Receipt Service with Firebase Storage
import 'dart:io';
import 'dart:typed_data';
import 'package:driving/services/school_config_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../models/payment.dart';
import '../models/invoice.dart';
import '../models/user.dart';
import '../controllers/settings_controller.dart';
import '../services/database_helper.dart';
import '../controllers/billing_controller.dart';
import '../controllers/user_controller.dart';
import 'package:get/get.dart';

class ReceiptService {
  static FirebaseStorage? _storage;

  /// Initialize Firebase Storage
  static void initialize() {
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        print('❌ Firebase not initialized');
        return;
      }

      _storage = FirebaseStorage.instance;
      print('✅ Firebase Storage initialized');

      // Test storage availability
      _testStorageConnection();
    } catch (e) {
      print('❌ Failed to initialize Firebase Storage: $e');
    }
  }

// Add this test method
  static Future<void> _testStorageConnection() async {
    try {
      final ref = _storage!.ref().child('test/connection.txt');
      await ref.putString('test connection');
      await ref.delete();
      print('✅ Firebase Storage connection test successful');
    } catch (e) {
      print('⚠️ Firebase Storage connection test failed: $e');
    }
  }

  /// Check if Firebase Storage is available
  static bool get isStorageAvailable => _storage != null;

  static String generateReference() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(7);
    return 'PAY-${DateFormat('yyyyMMdd').format(now)}-$timestamp';
  }

  /// Generate cloud storage path for receipt
  static String generateCloudReceiptPath(Payment payment, String schoolId) {
    final date = DateFormat('yyyy/MM').format(payment.paymentDate);
    final filename =
        'receipt_${payment.id}_${payment.reference ?? payment.id}.pdf';
    return 'schools/$schoolId/receipts/$date/$filename';
  }

  /// Generate receipt PDF and upload to cloud storage
  static Future<String> generateAndUploadReceipt(
    Payment payment,
    Invoice invoice,
    User student,
  ) async {
    if (!isStorageAvailable) {
      throw Exception('Firebase Storage not available');
    }

    try {
      print('🧾 Generating cloud receipt for payment ${payment.id}');

      // Get school ID
      final schoolConfig = Get.find<SchoolConfigService>();
      final schoolId = schoolConfig.schoolId.value;
      if (schoolId.isEmpty) {
        throw Exception('School ID not available');
      }

      // Generate PDF in memory
      final pdfBytes = await _generateReceiptPDF(payment, invoice, student);

      // Generate cloud path
      final cloudPath = generateCloudReceiptPath(payment, schoolId);

      // Upload to Firebase Storage
      final downloadUrl = await _uploadReceiptToStorage(pdfBytes, cloudPath);

      print('✅ Receipt uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Failed to generate and upload receipt: $e');
      rethrow;
    }
  }

  /// Generate receipt PDF bytes
  static Future<Uint8List> _generateReceiptPDF(
    Payment payment,
    Invoice invoice,
    User student,
  ) async {
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
              _buildBusinessHeader(settingsController),
              pw.SizedBox(height: 30),
              _buildReceiptTitle(payment),
              pw.SizedBox(height: 20),
              _buildStudentAndInvoiceInfo(student, invoice),
              pw.SizedBox(height: 30),
              _buildPaymentDetailsTable(payment, invoice),
              pw.SizedBox(height: 30),
              _buildPaymentSummary(payment, invoice),
              pw.SizedBox(height: 30),
              if (payment.notes != null && payment.notes!.isNotEmpty)
                _buildNotesSection(payment),
              pw.Spacer(),
              _buildFooter(settingsController),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Upload receipt PDF to Firebase Storage
  static Future<String> _uploadReceiptToStorage(
    Uint8List pdfBytes,
    String cloudPath,
  ) async {
    try {
      final ref = _storage!.ref().child(cloudPath);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'generated_at': DateTime.now().toIso8601String(),
          'generated_by': 'receipt_service',
        },
      );

      // Upload file
      final uploadTask = ref.putData(pdfBytes, metadata);
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ File uploaded to: $cloudPath');
      print('📎 Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Upload failed: $e');
      rethrow;
    }
  }

  /// Smart receipt generation with data fetching
  static Future<String> generateReceiptSmart(Payment payment) async {
    try {
      print('🧾 Smart cloud receipt generation for payment ${payment.id}');

      // Get required data
      final billingController = Get.find<BillingController>();
      final userController = Get.find<UserController>();

      // Find invoice
      Invoice? invoice = billingController.invoices
          .firstWhereOrNull((inv) => inv.id == payment.invoiceId);

      if (invoice == null) {
        print('📊 Invoice not found in controller, fetching from database...');
        final db = await DatabaseHelper.instance.database;
        final invoiceResults = await db.query(
          'invoices',
          where: 'id = ?',
          whereArgs: [payment.invoiceId],
          limit: 1,
        );

        if (invoiceResults.isNotEmpty) {
          invoice = Invoice.fromJson(invoiceResults.first);
        } else {
          throw Exception('Invoice ${payment.invoiceId} not found');
        }
      }

      // Find student
      User? student = userController.users
          .firstWhereOrNull((user) => user.id == invoice!.studentId);

      if (student == null) {
        print('👤 Student not found in controller, fetching from database...');
        final db = await DatabaseHelper.instance.database;
        final studentResults = await db.query(
          'users',
          where: 'id = ? AND role = ?',
          whereArgs: [invoice.studentId, 'student'],
          limit: 1,
        );

        if (studentResults.isNotEmpty) {
          student = User.fromJson(studentResults.first);
        } else {
          throw Exception('Student ${invoice.studentId} not found');
        }
      }

      // Generate and upload receipt
      return await generateAndUploadReceipt(payment, invoice, student);
    } catch (e) {
      print('❌ Smart cloud receipt generation failed: $e');
      rethrow;
    }
  }

  /// Download receipt from cloud storage
  static Future<Uint8List> downloadReceiptFromCloud(String downloadUrl) async {
    try {
      print('📥 Downloading receipt from cloud: $downloadUrl');

      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        print('✅ Receipt downloaded successfully');
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download receipt: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Receipt download failed: $e');
      rethrow;
    }
  }

  /// Print receipt from cloud URL
  static Future<void> printReceiptFromCloud(String downloadUrl) async {
    try {
      final pdfBytes = await downloadReceiptFromCloud(downloadUrl);
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      print('❌ Print from cloud failed: $e');
      rethrow;
    }
  }

  /// Share receipt from cloud URL
  static Future<void> shareReceiptFromCloud(String downloadUrl) async {
    try {
      final pdfBytes = await downloadReceiptFromCloud(downloadUrl);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      print('❌ Share from cloud failed: $e');
      rethrow;
    }
  }

  /// Save receipt to local device for offline access (optional)
  static Future<String> saveReceiptLocally(
      String downloadUrl, Payment payment) async {
    try {
      print('💾 Saving receipt locally for offline access...');

      final pdfBytes = await downloadReceiptFromCloud(downloadUrl);

      // Create local receipts directory
      final directory = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${directory.path}/receipts_cache');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      // Generate local filename
      final filename = 'receipt_${payment.id}_cached.pdf';
      final file = File('${receiptsDir.path}/$filename');

      // Save file
      await file.writeAsBytes(pdfBytes);

      print('✅ Receipt cached locally: ${file.path}');
      return file.path;
    } catch (e) {
      print('❌ Failed to save receipt locally: $e');
      rethrow;
    }
  }

  /// Delete receipt from cloud storage
  static Future<void> deleteReceiptFromCloud(String cloudPath) async {
    if (!isStorageAvailable) {
      throw Exception('Firebase Storage not available');
    }

    try {
      final ref = _storage!.ref().child(cloudPath);
      await ref.delete();
      print('🗑️ Receipt deleted from cloud: $cloudPath');
    } catch (e) {
      print('❌ Failed to delete receipt from cloud: $e');
      rethrow;
    }
  }

  /// Check if receipt exists in cloud storage
  static Future<bool> receiptExistsInCloud(String cloudPath) async {
    if (!isStorageAvailable) return false;

    try {
      final ref = _storage!.ref().child(cloudPath);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get receipt metadata from cloud storage
  static Future<Map<String, dynamic>?> getReceiptMetadata(
      String cloudPath) async {
    if (!isStorageAvailable) return null;

    try {
      final ref = _storage!.ref().child(cloudPath);
      final metadata = await ref.getMetadata();

      return {
        'size': metadata.size,
        'created': metadata.timeCreated?.toIso8601String(),
        'updated': metadata.updated?.toIso8601String(),
        'content_type': metadata.contentType,
        'custom_metadata': metadata.customMetadata,
      };
    } catch (e) {
      print('❌ Failed to get receipt metadata: $e');
      return null;
    }
  }

  /// Clean up old cached receipts (for local cache management)
  static Future<void> cleanupLocalCache({int maxAgeDays = 30}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${directory.path}/receipts_cache');

      if (!await receiptsDir.exists()) return;

      final files = receiptsDir.listSync();
      final now = DateTime.now();
      int deletedCount = 0;

      for (final file in files) {
        if (file is File && file.path.endsWith('.pdf')) {
          final lastModified = await file.lastModified();
          final age = now.difference(lastModified).inDays;

          if (age > maxAgeDays) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      print('🧹 Cleaned up $deletedCount old cached receipt files');
    } catch (e) {
      print('❌ Cache cleanup failed: $e');
    }
  }

  /// Batch upload receipts (for migration or bulk operations)
  static Future<Map<String, dynamic>> batchUploadReceipts(
      List<Payment> payments,
      {Function(int, int)? onProgress}) async {
    if (!isStorageAvailable) {
      throw Exception('Firebase Storage not available');
    }

    print(
        '📤 Starting batch receipt upload for ${payments.length} payments...');

    int successCount = 0;
    int failureCount = 0;
    final errors = <String, String>{};

    final deviceId = await DatabaseHelper.getDeviceId();

    for (int i = 0; i < payments.length; i++) {
      try {
        final payment = payments[i];
        onProgress?.call(i + 1, payments.length);

        // Skip if already has cloud URL
        if (payment.receiptPath != null &&
            payment.receiptPath!.startsWith('https://')) {
          continue;
        }

        // Generate and upload receipt
        final downloadUrl = await generateReceiptSmart(payment);

        // Update payment record
        await _updatePaymentReceiptUrl(payment.id!, downloadUrl);

        successCount++;
        print('✅ Uploaded receipt for payment ${payment.id}');
      } catch (e) {
        failureCount++;
        errors[payments[i].id.toString()] =
            e.toString(); // Use payments[i].id instead of payment.id
        print('❌ Failed to upload receipt for payment ${payments[i].id}: $e');
      }
    }

    final result = {
      'total_processed': payments.length,
      'success_count': successCount,
      'failure_count': failureCount,
      'errors': errors,
      'success_rate': payments.isNotEmpty
          ? (successCount / payments.length * 100).round()
          : 100,
    };

    print('📤 Batch upload completed:');
    print('   Total: ${result['total_processed']}');
    print('   Success: ${result['success_count']}');
    print('   Failed: ${result['failure_count']}');
    print('   Success Rate: ${result['success_rate']}%');

    return result;
  }

  /// Update payment record with cloud receipt URL
  static Future<void> _updatePaymentReceiptUrl(
      int paymentId, String downloadUrl) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'payments',
        {
          'receipt_path':
              downloadUrl, // Now stores cloud URL instead of local path
          'receipt_generated': 1,
          'receipt_generated_at': DateTime.now().toIso8601String(),
          'receipt_type':
              'cloud', // Add new field to distinguish cloud vs local
          'last_modified': DateTime.now().millisecondsSinceEpoch,
          'firebase_synced': 0, // Mark for sync
        },
        where: 'id = ?',
        whereArgs: [paymentId],
      );

      print('✅ Payment receipt URL updated: $paymentId');
    } catch (e) {
      print('❌ Failed to update payment receipt URL: $e');
      rethrow;
    }
  }

  // PDF Building Methods (same as before, keeping for completeness)
  static pw.Widget _buildBusinessHeader(SettingsController settings) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.blue600, PdfColors.blue800],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(10),
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
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 5),
              if (settings.businessAddress.value.isNotEmpty)
                pw.Text(
                  settings.businessAddress.value,
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey100),
                ),
              if (settings.businessPhone.value.isNotEmpty)
                pw.Text(
                  'Phone: ${settings.businessPhone.value}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey100),
                ),
              if (settings.businessEmail.value.isNotEmpty)
                pw.Text(
                  'Email: ${settings.businessEmail.value}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey100),
                ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(50),
            ),
            child: pw.Text('🧾', style: pw.TextStyle(fontSize: 24)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptTitle(Payment payment) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PAYMENT RECEIPT',
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Container(width: 100, height: 3, color: PdfColors.orange400),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Receipt #: ${payment.reference ?? payment.id}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(payment.paymentDate)}',
              style: pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildStudentAndInvoiceInfo(User student, Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'STUDENT INFORMATION',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Name: ${student.fname} ${student.lname}',
                  style: pw.TextStyle(fontSize: 11),
                ),
                if (student.email?.isNotEmpty == true)
                  pw.Text(
                    'Email: ${student.email}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                if (student.phone?.isNotEmpty == true)
                  pw.Text(
                    'Phone: ${student.phone}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INVOICE INFORMATION',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Invoice #: ${invoice.invoiceNumber}',
                  style: pw.TextStyle(fontSize: 11),
                ),
                pw.Text(
                  'Date: ${DateFormat('MMM dd, yyyy').format(invoice.createdAt ?? DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Status: ${invoice.status}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentDetailsTable(Payment payment, Invoice invoice) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _buildTableCell('Description', isHeader: true),
            _buildTableCell('Method', isHeader: true),
            _buildTableCell('Amount', isHeader: true, isAmount: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Payment for Invoice #${invoice.invoiceNumber}'),
            _buildTableCell(payment.method ?? 'Cash'),
            _buildTableCell('\$${payment.amount.toStringAsFixed(2)}',
                isAmount: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentSummary(Payment payment, Invoice invoice) {
    final remainingBalance =
        (invoice.totalAmount ?? 0) - (invoice.amountPaid ?? 0);

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
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
              pw.Text('Invoice Total:', style: pw.TextStyle(fontSize: 12)),
              pw.Text('\$${(invoice.totalAmount ?? 0).toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Paid:', style: pw.TextStyle(fontSize: 12)),
              pw.Text('\$${(invoice.amountPaid ?? 0).toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.Container(
            height: 1,
            color: PdfColors.green300,
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Remaining Balance:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: remainingBalance > 0
                      ? PdfColors.orange600
                      : PdfColors.green600,
                ),
              ),
              pw.Text(
                '\$${remainingBalance.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: remainingBalance > 0
                      ? PdfColors.orange600
                      : PdfColors.green600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNotesSection(Payment payment) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(payment.notes!, style: pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(SettingsController settings) {
    return pw.Column(
      children: [
        pw.Container(
          height: 1,
          color: PdfColors.grey300,
          margin: const pw.EdgeInsets.symmetric(vertical: 10),
        ),
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
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated on',
                    style:
                        pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                pw.Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()),
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
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
}
