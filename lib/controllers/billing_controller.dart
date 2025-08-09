import 'dart:io';

import 'package:csv/csv.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/models/billing_record.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/receipt_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import '../services/database_helper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class BillingController extends GetxController {
  final RxList<Invoice> invoices = <Invoice>[].obs;
  final RxList<Payment> payments = <Payment>[].obs;
  final RxBool isLoading = false.obs;

  final DatabaseHelper _dbHelper = Get.find();

  @override
  void onInit() {
    super.onInit();
    // Fetch all billing data initially
    fetchBillingData();
  }

  Future<int> insertBillingRecord(BillingRecord billingRecord) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('billing_records', billingRecord.toJson());
  }

  Future<List<Payment>> getPaymentsForInvoice(int invoiceId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'payments',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
    );
    return results.map((json) => Payment.fromJson(json)).toList();
  }

  Future<List<BillingRecord>> getBillingRecordsForInvoice(int invoiceId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> results = await db.query(
      'billing_records',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
    );
    return results.map((json) => BillingRecord.fromJson(json)).toList();
  }

  Future<void> updateBillingRecordStatus(
      int billingRecordId, String status) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'billing_records',
      {'status': status},
      where: 'id = ?',
      whereArgs: [billingRecordId],
    );
    // Optionally refresh billing data if needed
    // await fetchBillingData();
  }

  Future<int> insertBillingRecordHistory(BillingRecord billingRecord) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('billing_records_history', billingRecord.toJson());
  }

  // Delete an invoice
  Future<void> deleteInvoice(int invoiceId) async {
    await DatabaseHelper.instance.deleteInvoice(invoiceId);
    fetchBillingData(); // Refresh the list of invoices
  }

  // Edit an invoice
  Future<void> editInvoice(Invoice invoice) async {
    await DatabaseHelper.instance.updateInvoice(invoice.toMap());
    fetchBillingData(); // Refresh the list of invoices
  }

// Enhanced getCourseName method with better error handling
  Future<String> getCourseName(int courseId) async {
    try {
      print('Getting course name for courseId: $courseId');
      final course = await DatabaseHelper.instance.getCourseById(courseId);
      final courseName = course?.name ?? 'Course ID: $courseId';
      print('Course name found: $courseName');
      return courseName;
    } catch (e) {
      print('Error getting course name for ID $courseId: $e');
      return 'Course ID: $courseId';
    }
  }

  Future<void> fetchBillingDataForStudent(int studentId) async {
    try {
      isLoading(true);
      print(
          'BillingController: fetchBillingDataForStudent called for studentId: $studentId'); // ADD THIS
      final data = await _dbHelper.getBillingForStudent(studentId);
      print(
          'BillingController: Data from _dbHelper.getBillingForStudent: $data'); // ADD THIS
      invoices.assignAll(data.map((json) => Invoice.fromJson(json)));
      print(
          'BillingController: Invoices after assignAll: $invoices'); // ADD THIS
    } finally {
      isLoading(false);
    }
  }

  Future<void> generateInvoice({
    required int studentId,
    required int courseId,
    required int lessons,
    required double pricePerLesson,
  }) async {
    try {
      final db = await DatabaseHelper().database;

      // Generate a unique invoice number
      String invoiceNumber = await _generateInvoiceNumber();

      await db.insert('invoices', {
        'invoice_number': invoiceNumber, // Add this field
        'student': studentId,
        'course': courseId,
        'lessons': lessons,
        'price_per_lesson': pricePerLesson,
        'amountpaid': 0.0,
        'created_at': DateTime.now().toIso8601String(),
        'due_date': DateTime.now().add(Duration(days: 30)).toIso8601String(),
        'status': 'unpaid',
        'total_amount': lessons * pricePerLesson,
      });

      // Refresh the invoice list
      await fetchBillingData();
    } catch (e) {
      Get.snackbar('Error', 'Failed to create invoice: ${e.toString()}');
      throw e;
    }
  }

  Future<String> _generateInvoiceNumber() async {
    final db = await DatabaseHelper().database;

    // Get current date for prefix
    final now = DateTime.now();
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}';

    // Get count of invoices for this month
    final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM invoices WHERE invoice_number LIKE ?",
        ['INV-$datePrefix-%']);

    final count = result.first['count'] as int;
    final sequenceNumber = (count + 1).toString().padLeft(4, '0');

    return 'INV-$datePrefix-$sequenceNumber';
  }

  Future<void> updateUsedLessons(int invoiceId, int usedLessons) async {
    try {
      final index = invoices.indexWhere((inv) => inv.id == invoiceId);
      if (index == -1) {
        throw Exception('Invoice not found');
      }

      final invoice = invoices[index];

      // Update in the database
      await _dbHelper.updateInvoice({
        'id': invoiceId,
        'used_lessons':
            usedLessons, // Add this field to your database if not exists
      });

      // Update locally - you might need to add usedLessons field to your Invoice model
      // For now, we'll track it through the existing lessons field relationship
      final updatedInvoice = invoice.copyWith(
          // If you have a usedLessons field in Invoice model, update it here
          // usedLessons: usedLessons,
          );

      invoices[index] = updatedInvoice;
      invoices.refresh();
    } catch (e) {
      print('Error updating used lessons: ${e.toString()}');
      throw Exception('Failed to update lesson usage');
    }
  }

  Future<List<Map<String, dynamic>>> getPayments() async {
    final db = await _dbHelper.database;
    return await db.query('payments');
  }

  Future<void> fetchBillingData() async {
    try {
      isLoading(true);
      print('BillingController: fetchBillingData called');
      final invoicesData = await _dbHelper.getInvoices();
      print(
          'BillingController: Data from _dbHelper.getInvoices: $invoicesData');
      final paymentsData = await _dbHelper.getPayments();
      print(
          'BillingController: Data from _dbHelper.getPayments: $paymentsData');

      List<Invoice> fetchedInvoices = [];
      for (var invoiceData in invoicesData) {
        Invoice invoice = Invoice.fromJson(invoiceData);
        List<Payment> invoicePayments = paymentsData
            .map((json) => Payment.fromJson(json))
            .where((payment) => payment.invoiceId == invoice.id)
            .toList();
        invoice.payments = invoicePayments;
        fetchedInvoices.add(invoice);
      }

      invoices.assignAll(fetchedInvoices);
      payments.assignAll(paymentsData.map((json) => Payment.fromJson(json)));
    } finally {
      isLoading(false);
    }
  }

  Future<void> recordPayment(Payment payment) async {
    print('=== STARTING recordPayment ===');
    print(
        'Payment details: Invoice ID: ${payment.invoiceId}, Amount: ${payment.amount}');

    try {
      isLoading(true);
      print('Setting isLoading to true');

      // Insert payment with debug
      print('About to insert payment into database...');
      print('Payment data to insert: ${payment.toJson()}');

      final paymentId = await _dbHelper.insertPayment(payment.toJson());
      print('✓ Payment inserted successfully with ID: $paymentId');

      // Verify payment was inserted
      final db = await _dbHelper.database;
      final insertedPayment =
          await db.query('payments', where: 'id = ?', whereArgs: [paymentId]);
      print('✓ Verified inserted payment: $insertedPayment');

      // Update invoice status with debug
      print('About to call _updateInvoiceStatus...');
      await _updateInvoiceStatus(payment.invoiceId, payment.amount);
      print('✓ _updateInvoiceStatus completed successfully');

      // Refresh billing data
      print('About to refresh billing data...');
      await fetchBillingData();
      print('✓ Billing data refreshed');

      print('=== recordPayment COMPLETED SUCCESSFULLY ===');
    } catch (e) {
      print('=== ERROR in recordPayment ===');
      print('Error: $e');
      print('Stack trace: ${e.toString()}');
      rethrow;
    } finally {
      isLoading(false);
      print('Setting isLoading to false');
    }
  }

// STEP 3: Updated _updateInvoiceStatus that gets data from database directly
  Future<void> _updateInvoiceStatus(int invoiceId, double amount) async {
    print('=== STARTING _updateInvoiceStatus ===');
    print('Invoice ID: $invoiceId, Payment Amount: $amount');

    try {
      final db = await _dbHelper.database;

      // Get current invoice data from database (not memory)
      final invoiceResults = await db.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      if (invoiceResults.isEmpty) {
        throw Exception('Invoice $invoiceId not found in database');
      }

      final invoiceData = invoiceResults.first;
      print('Current invoice data from DB: $invoiceData');

      // Get current amount paid
      final currentAmountPaid =
          (invoiceData['amountpaid'] as num?)?.toDouble() ?? 0.0;
      print('Current amount paid: $currentAmountPaid');

      // Calculate new amounts
      final newAmountPaid = currentAmountPaid + amount;
      print('New amount paid will be: $newAmountPaid');

      // Calculate total amount
      final totalAmount = (invoiceData['total_amount'] as num?)?.toDouble() ??
          ((invoiceData['lessons'] as num).toDouble() *
              (invoiceData['price_per_lesson'] as num).toDouble());
      print('Total amount: $totalAmount');

      // Determine new status
      String newStatus;
      if (newAmountPaid >= totalAmount) {
        newStatus = 'paid';
      } else if (newAmountPaid > 0) {
        newStatus = 'partial';
      } else {
        newStatus = 'unpaid';
      }

      print('New status will be: $newStatus');

      // Update the invoice
      final updateData = {
        'amountpaid': newAmountPaid,
        'status': newStatus,
      };

      print('Updating invoice with data: $updateData');

      final rowsUpdated = await db.update(
        'invoices',
        updateData,
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      print('✓ Database update completed. Rows affected: $rowsUpdated');

      // Verify the update
      final verifyResults = await db.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      if (verifyResults.isNotEmpty) {
        final updatedData = verifyResults.first;
        print(
            '✓ Verification - Updated invoice: amountpaid = ${updatedData['amountpaid']}, status = ${updatedData['status']}');
      }

      print('=== _updateInvoiceStatus COMPLETED ===');
    } catch (e) {
      print('=== ERROR in _updateInvoiceStatus ===');
      print('Error: $e');
      rethrow;
    }
  }

  Future<void> recordPaymentWithReceipt(
      Payment payment, Invoice invoice, User student) async {
    print('=== STARTING recordPaymentWithReceipt ===');

    try {
      isLoading(true);

      // Generate reference if not provided
      final reference = payment.reference ?? ReceiptService.generateReference();

      // Create payment with reference
      final paymentWithReference = payment.copyWith(reference: reference);

      // Insert payment
      final paymentId =
          await _dbHelper.insertPayment(paymentWithReference.toJson());
      print('✓ Payment inserted with ID: $paymentId');

      // Update invoice status
      await _updateInvoiceStatus(payment.invoiceId, payment.amount);
      print('✓ Invoice status updated');

      // Generate receipt
      try {
        final receiptPath = await ReceiptService.generateReceipt(
          paymentWithReference.copyWith(id: paymentId),
          invoice,
          student,
          'Your Driving School', // Replace with your school name
        );

        // Update payment with receipt path
        await _dbHelper.updatePayment({
          'id': paymentId,
          'receipt_path': receiptPath,
          'receipt_generated': 1,
        });

        print('✓ Receipt generated at: $receiptPath');

        // Refresh billing data
        await fetchBillingData();

        // Show success with receipt options
        Get.snackbar(
          'Payment Recorded',
          'Payment recorded and receipt generated successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () => ReceiptService.printReceipt(receiptPath),
            child: const Text('Print Receipt',
                style: TextStyle(color: Colors.white)),
          ),
        );
      } catch (receiptError) {
        print('Warning: Receipt generation failed: $receiptError');
        // Still refresh data even if receipt fails
        await fetchBillingData();

        Get.snackbar(
          'Payment Recorded',
          'Payment recorded but receipt generation failed',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.shade600,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('ERROR in recordPaymentWithReceipt: $e');
      rethrow;
    } finally {
      isLoading(false);
    }
  }

  Future<void> regenerateReceipt(int paymentId) async {
    try {
      final payment = payments.firstWhere((p) => p.id == paymentId);
      final invoice = invoices.firstWhere((inv) => inv.id == payment.invoiceId);

      // You'll need to get the student data - add this method to your UserController
      // final student = await userController.getUserById(invoice.studentId);

      // For now, assuming you have access to student data
      // Replace this with actual student lookup
      final receiptPath = await ReceiptService.generateReceipt(
        payment,
        invoice,
        User(
            fname: 'Student',
            lname: 'Name',
            email: 'student@example.com',
            password: '',
            gender: '',
            phone: '',
            address: '',
            date_of_birth: DateTime.now(),
            role: 'student',
            status: 'active',
            idnumber: '',
            created_at: DateTime.now()), // Replace with actual student

        'Your Driving School',
      );

      // Update payment with new receipt path
      await _dbHelper.updatePayment({
        'id': paymentId,
        'receipt_path': receiptPath,
        'receipt_generated': 1,
      });

      await fetchBillingData();

      Get.snackbar(
        'Receipt Generated',
        'Receipt has been regenerated successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to regenerate receipt: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }
  // Add this method to your existing BillingController

  /// Creates an invoice directly (used during student enrollment)
  Future<int> createInvoice(Invoice invoice) async {
    try {
      isLoading(true);

      // Insert invoice into database
      final invoiceId = await _dbHelper.insertInvoice(invoice.toJson());

      // Add to local list for immediate UI update
      final newInvoice = invoice.copyWith(id: invoiceId);
      invoices.add(newInvoice);
      invoices.refresh();

      print(
          '✓ Invoice created successfully: ID $invoiceId, Amount: \$${invoice.totalAmountCalculated}');

      return invoiceId;
    } catch (e) {
      print('ERROR creating invoice: $e');
      rethrow;
    } finally {
      isLoading(false);
    }
  }

  /// Enhanced version that also handles course name lookup
  Future<int> createInvoiceWithCourse(
      int studentId, Course course, int lessons, DateTime dueDate) async {
    try {
      isLoading(true);

      final invoice = Invoice(
        studentId: studentId,
        courseId: course.id!,
        lessons: lessons,
        pricePerLesson: course.price.toDouble(),
        createdAt: DateTime.now(),
        dueDate: dueDate,
        status: 'unpaid',
        invoiceNumber: await _generateInvoiceNumber(),
        amountPaid: 0.0,
        totalAmount: lessons * course.price.toDouble(),
      );

      final invoiceId = await _dbHelper.insertInvoice(invoice.toJson());

      // Add to local list
      final newInvoice = invoice.copyWith(id: invoiceId);
      invoices.add(newInvoice);
      invoices.refresh();

      // Log the creation for audit trail
      print('✓ Auto-invoice created during enrollment:');
      print('  Student ID: $studentId');
      print('  Course: ${course.name}');
      print('  Lessons: $lessons');
      print('  Price per lesson: \$${course.price}');
      print('  Total: \$${invoice.totalAmountCalculated}');
      print('  Due date: ${dueDate.toString().split(' ')[0]}');

      return invoiceId;
    } catch (e) {
      print('ERROR in createInvoiceWithCourse: $e');
      Get.snackbar(
        'Invoice Creation Failed',
        'Student was created but invoice creation failed: ${e.toString()}',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
      rethrow;
    } finally {
      isLoading(false);
    }
  }

// Also add this helper method to DatabaseHelper if not already present
  Future<int> insertInvoice(Map<String, dynamic> invoice) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('invoices', invoice);
  }

  Future<void> updateInvoicePayment({
    required int invoiceId,
    required double paymentAmount,
    required String paymentMethod,
    required String notes,
  }) async {
    final payment = Payment(
      invoiceId: invoiceId,
      amount: paymentAmount,
      paymentDate: DateTime.now(),
      notes: notes,
      method: paymentMethod,
    );
    await recordPayment(payment);
  }

  Future<void> processBulkPayment({
    required List<Map<String, dynamic>> studentsData,
    required double paymentAmount,
    required String paymentMethod,
    required String notes,
  }) async {
    try {
      // Calculate total outstanding amount
      double totalOutstanding =
          studentsData.fold(0.0, (sum, data) => sum + data['balance']);

      // Determine payment distribution
      for (var studentData in studentsData) {
        final User student = studentData['student'];
        final List<Invoice> invoices = studentData['invoices'];
        final double studentBalance = studentData['balance'];

        // Calculate proportional payment for this student
        double studentPayment =
            (studentBalance / totalOutstanding) * paymentAmount;

        // Apply payment to student's invoices (oldest first)
        double remainingPayment = studentPayment;

        for (var invoice in invoices) {
          if (remainingPayment <= 0) break;

          double invoiceBalance =
              invoice.totalAmountCalculated - invoice.amountPaid;
          if (invoiceBalance <= 0) continue;

          double paymentForInvoice = remainingPayment > invoiceBalance
              ? invoiceBalance
              : remainingPayment;

          // Update invoice payment
          await updateInvoicePayment(
            invoiceId: invoice.id!,
            paymentAmount: paymentForInvoice,
            paymentMethod: paymentMethod,
            notes: notes.isNotEmpty ? notes : 'Bulk payment',
          );

          remainingPayment -= paymentForInvoice;
        }
      }

      // Refresh billing data
      await fetchBillingData();
    } catch (e) {
      throw Exception('Failed to process bulk payment: $e');
    }
  }

  Future<void> updateInvoice(Map<String, dynamic> updatedInvoiceData) async {
    try {
      isLoading(true);
      print(
          'BillingController: updateInvoice called with data: $updatedInvoiceData');

      // Update in database
      await _dbHelper.updateInvoice(updatedInvoiceData);
      print('✓ Invoice updated in database');

      // Force refresh all billing data
      await fetchBillingData();
      print('✓ Billing data refreshed after update');

      // Notify other controllers that billing data has changed
      Get.find<ScheduleController>().refreshBillingData();

      Get.snackbar(
        'Success',
        'Invoice updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('BillingController: Error updating invoice: ${e.toString()}');
      Get.snackbar('Error', 'Failed to update invoice: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  // Enhanced addLessonsBack method
  Future<void> addLessonsBack(int studentId, int lessonsToAdd) async {
    try {
      print(
          'BillingController: addLessonsBack called with studentId: $studentId, lessonsToAdd: $lessonsToAdd');

      final index = invoices.indexWhere((inv) => inv.studentId == studentId);
      print('BillingController: index of invoice: $index');

      if (index == -1) {
        print('BillingController: Invoice not found for studentId: $studentId');
        Get.snackbar('Error', 'No invoice found for this student');
        return;
      }

      final invoice = invoices[index];
      print('BillingController: Found invoice with ${invoice.lessons} lessons');

      final updatedLessons = invoice.lessons + lessonsToAdd;
      print('BillingController: Updated lessons count: $updatedLessons');

      // Update in the database
      await _dbHelper.updateInvoice({
        'id': invoice.id,
        'lessons': updatedLessons,
      });
      print('✓ Invoice updated in DB');

      // Force refresh all data instead of just local update
      await fetchBillingData();
      print('✓ Billing data refreshed');

      // Notify schedule controller
      Get.find<ScheduleController>().refreshBillingData();

      Get.snackbar(
        'Success',
        'Added $lessonsToAdd lessons. Total now: $updatedLessons',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('BillingController: Error in addLessonsBack: ${e.toString()}');
      Get.snackbar('Error', 'Failed to update billing info: ${e.toString()}');
    }
  }

// Enhanced CSV export with course details
  Future<void> exportAllInvoicesCSV() async {
    try {
      isLoading(true);

      await fetchBillingData();

      if (invoices.isEmpty) {
        Get.snackbar('No Data', 'No invoices found to export');
        return;
      }

      // Prepare enhanced CSV data with course information
      List<List<dynamic>> csvData = [
        [
          'Invoice Number',
          'Student ID',
          'Student Name',
          'Student Email',
          'Course ID',
          'Course Name',
          'Date Created',
          'Due Date',
          'Lessons Purchased',
          'Price Per Lesson',
          'Total Amount',
          'Amount Paid',
          'Balance',
          'Status',
          'Payment Count',
          'Last Payment Date',
          'Days Overdue',
          'Course Total Value',
          'Payment Percentage'
        ],
      ];

      // Process each invoice with detailed course information
      for (var invoice in invoices) {
        try {
          // Get student details
          final student = await _dbHelper.getUserById(invoice.studentId);
          final studentName = student != null
              ? '${student['fname']} ${student['lname']}'
              : 'Unknown';
          final studentEmail = student?['email'] ?? 'Unknown';

          // Get course name
          final courseName = await getCourseName(invoice.courseId);

          // Get payment information
          final payments = await getPaymentsForInvoice(invoice.id!);
          final lastPaymentDate = payments.isNotEmpty
              ? payments
                  .map((p) => p.paymentDate)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
              : null;

          // Calculate additional metrics
          final daysOverdue =
              invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now())
                  ? DateTime.now().difference(invoice.dueDate).inDays
                  : 0;

          final courseTotal = invoice.lessons * invoice.pricePerLesson;
          final paymentPercentage =
              courseTotal > 0 ? (invoice.amountPaid / courseTotal * 100) : 0.0;

          csvData.add([
            invoice.invoiceNumber,
            invoice.studentId,
            studentName,
            studentEmail,
            invoice.courseId,
            courseName,
            DateFormat('yyyy-MM-dd').format(invoice.createdAt),
            DateFormat('yyyy-MM-dd').format(invoice.dueDate),
            invoice.lessons,
            invoice.pricePerLesson.toStringAsFixed(2),
            invoice.totalAmountCalculated.toStringAsFixed(2),
            invoice.amountPaid.toStringAsFixed(2),
            invoice.balance.toStringAsFixed(2),
            invoice.status,
            payments.length,
            lastPaymentDate != null
                ? DateFormat('yyyy-MM-dd').format(lastPaymentDate)
                : '',
            daysOverdue > 0 ? daysOverdue.toString() : '0',
            courseTotal.toStringAsFixed(2),
            paymentPercentage.toStringAsFixed(1)
          ]);
        } catch (e) {
          print('Error processing invoice ${invoice.id}: $e');
          // Continue with next invoice
        }
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Generate filename with timestamp
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.]'), '_');
      final fileName = 'detailed_invoices_export_$timestamp.csv';

      // Save file using file picker
      final String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Detailed Invoices Export',
        fileName: fileName,
        allowedExtensions: ['csv'],
      );

      if (filePath != null) {
        final file = File(filePath);
        await file.writeAsString(csvString);

        Get.snackbar(
          'Export Successful',
          'Detailed invoices with course information exported to $filePath',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      } else {
        Get.snackbar('Export Cancelled', 'No file path selected');
      }
    } catch (e) {
      Get.snackbar(
        'Export Failed',
        'Failed to export detailed invoices: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

// Generate comprehensive billing report PDF with enhanced course information
  Future<void> generateBillingReportPDF({
    DateTime? startDate,
    DateTime? endDate,
    int? studentId,
    String? status,
  }) async {
    try {
      isLoading(true);

      // Set default date range if not provided
      startDate ??= DateTime.now().subtract(Duration(days: 30));
      endDate ??= DateTime.now();

      // Filter invoices based on criteria
      List<Invoice> filteredInvoices = invoices.where((invoice) {
        bool matchesDate = invoice.createdAt.isAfter(startDate!) &&
            invoice.createdAt.isBefore(endDate!.add(Duration(days: 1)));
        bool matchesStudent =
            studentId == null || invoice.studentId == studentId;
        bool matchesStatus = status == null || invoice.status == status;

        return matchesDate && matchesStudent && matchesStatus;
      }).toList();

      if (filteredInvoices.isEmpty) {
        Get.snackbar('No Data', 'No invoices found for the specified criteria');
        return;
      }

      final pdf = pw.Document();

      // Pre-fetch all course names to avoid async issues in PDF generation
      Map<int, String> courseNames = {};
      Map<int, double> coursePrices = {};

      for (var invoice in filteredInvoices) {
        if (!courseNames.containsKey(invoice.courseId)) {
          try {
            final course =
                await DatabaseHelper.instance.getCourseById(invoice.courseId);
            courseNames[invoice.courseId] = course?.name ?? 'Unknown Course';
            coursePrices[invoice.courseId] =
                course?.price?.toDouble() ?? invoice.pricePerLesson;
            print(
                'Cached course: ${courseNames[invoice.courseId]} (ID: ${invoice.courseId})');
          } catch (e) {
            print('Error fetching course ${invoice.courseId}: $e');
            courseNames[invoice.courseId] = 'Course ID: ${invoice.courseId}';
            coursePrices[invoice.courseId] = invoice.pricePerLesson;
          }
        }
      }

      // Pre-fetch all student names
      Map<int, String> studentNames = {};
      for (var invoice in filteredInvoices) {
        if (!studentNames.containsKey(invoice.studentId)) {
          try {
            final student = await _dbHelper.getUserById(invoice.studentId);
            studentNames[invoice.studentId] = student != null
                ? '${student['fname']} ${student['lname']}'
                : 'Unknown Student';
          } catch (e) {
            studentNames[invoice.studentId] =
                'Student ID: ${invoice.studentId}';
          }
        }
      }

      // Calculate comprehensive statistics
      double totalRevenue = 0;
      double totalPaid = 0;
      double totalOutstanding = 0;
      int totalLessons = 0;
      int paidInvoices = 0;
      int overdueInvoices = 0;
      Map<String, int> statusCounts = {};
      Map<String, double> courseRevenue = {};
      Map<String, int> courseLessons = {};
      Map<String, List<Invoice>> courseInvoicesMap = {};

      for (var invoice in filteredInvoices) {
        totalRevenue += invoice.totalAmountCalculated;
        totalPaid += invoice.amountPaid;
        totalOutstanding += invoice.balance;
        totalLessons += invoice.lessons;

        if (invoice.status == 'paid') paidInvoices++;
        if (invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now())) {
          overdueInvoices++;
        }

        // Count by status
        statusCounts[invoice.status] = (statusCounts[invoice.status] ?? 0) + 1;

        // Revenue and lessons by course using cached names
        String courseName = courseNames[invoice.courseId] ?? 'Unknown Course';
        courseRevenue[courseName] =
            (courseRevenue[courseName] ?? 0) + invoice.totalAmountCalculated;
        courseLessons[courseName] =
            (courseLessons[courseName] ?? 0) + invoice.lessons;

        // Group invoices by course for detailed breakdown
        if (!courseInvoicesMap.containsKey(courseName)) {
          courseInvoicesMap[courseName] = [];
        }
        courseInvoicesMap[courseName]!.add(invoice);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Text(
                      'COMPREHENSIVE BILLING REPORT',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Period: ${DateFormat('MMM dd, yyyy').format(startDate!)} - ${DateFormat('MMM dd, yyyy').format(endDate!)}',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Executive Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EXECUTIVE SUMMARY',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                  'Total Invoices: ${filteredInvoices.length}'),
                              pw.Text('Paid Invoices: $paidInvoices'),
                              pw.Text('Overdue Invoices: $overdueInvoices'),
                              pw.Text('Total Lessons: $totalLessons'),
                              pw.Text(
                                  'Avg Lessons/Invoice: ${(totalLessons / filteredInvoices.length).toStringAsFixed(1)}'),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                  'Total Revenue: \$${totalRevenue.toStringAsFixed(2)}'),
                              pw.Text(
                                  'Amount Collected: \$${totalPaid.toStringAsFixed(2)}'),
                              pw.Text(
                                  'Outstanding: \$${totalOutstanding.toStringAsFixed(2)}'),
                              pw.Text(
                                  'Collection Rate: ${((totalPaid / totalRevenue) * 100).toStringAsFixed(1)}%'),
                              pw.Text(
                                  'Avg Invoice Value: \$${(totalRevenue / filteredInvoices.length).toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Enhanced Course Revenue Breakdown with Pricing Details
              pw.Text(
                'COURSE REVENUE & PRICING BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('Course Name', isHeader: true),
                        _buildTableCell('Total Lessons', isHeader: true),
                        _buildTableCell('Avg Price/Lesson', isHeader: true),
                        _buildTableCell('Total Revenue', isHeader: true),
                        _buildTableCell('% of Total', isHeader: true),
                      ],
                    ),
                    ...courseRevenue.entries.map((entry) {
                      String courseName = entry.key;
                      double revenue = entry.value;
                      int lessons = courseLessons[courseName] ?? 0;
                      double avgPricePerLesson =
                          lessons > 0 ? revenue / lessons : 0;
                      double percentage = (revenue / totalRevenue) * 100;

                      return pw.TableRow(
                        children: [
                          _buildTableCell(courseName),
                          _buildTableCell(lessons.toString()),
                          _buildTableCell(
                              '\$${avgPricePerLesson.toStringAsFixed(2)}'),
                          _buildTableCell('\$${revenue.toStringAsFixed(2)}'),
                          _buildTableCell('${percentage.toStringAsFixed(1)}%'),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Status Breakdown
              pw.Text(
                'INVOICE STATUS BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  children: statusCounts.entries.map((entry) {
                    double percentage =
                        (entry.value / filteredInvoices.length) * 100;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('${entry.key.toUpperCase()}: ${entry.value}'),
                          pw.Text('${percentage.toStringAsFixed(1)}%'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              pw.SizedBox(height: 20),

              // Detailed Invoice List with Course Information
              pw.Text(
                'DETAILED INVOICE LIST WITH COURSE INFORMATION',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),

              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FixedColumnWidth(50), // Invoice #
                  1: const pw.FixedColumnWidth(75), // Student
                  2: const pw.FixedColumnWidth(90), // Course (increased width)
                  3: const pw.FixedColumnWidth(30), // Lessons
                  4: const pw.FixedColumnWidth(35), // Price/Lesson
                  5: const pw.FixedColumnWidth(40), // Total
                  6: const pw.FixedColumnWidth(40), // Paid
                  7: const pw.FixedColumnWidth(40), // Balance
                  8: const pw.FixedColumnWidth(35), // Status
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Invoice #', isHeader: true),
                      _buildTableCell('Student', isHeader: true),
                      _buildTableCell('Course', isHeader: true),
                      _buildTableCell('Lessons', isHeader: true),
                      _buildTableCell('Price/Lesson', isHeader: true),
                      _buildTableCell('Total', isHeader: true),
                      _buildTableCell('Paid', isHeader: true),
                      _buildTableCell('Balance', isHeader: true),
                      _buildTableCell('Status', isHeader: true),
                    ],
                  ),
                  // Data rows using cached names
                  ...filteredInvoices.map((invoice) {
                    final studentName =
                        studentNames[invoice.studentId] ?? 'Unknown';
                    final courseName =
                        courseNames[invoice.courseId] ?? 'Unknown Course';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(invoice.invoiceNumber),
                        _buildTableCell(studentName),
                        _buildTableCell(courseName),
                        _buildTableCell(invoice.lessons.toString()),
                        _buildTableCell(
                            '\$${invoice.pricePerLesson.toStringAsFixed(2)}'),
                        _buildTableCell(
                            '\$${invoice.totalAmountCalculated.toStringAsFixed(2)}'),
                        _buildTableCell(
                            '\$${invoice.amountPaid.toStringAsFixed(2)}'),
                        _buildTableCell(
                          '\$${invoice.balance.toStringAsFixed(2)}',
                          textColor: invoice.balance > 0
                              ? PdfColors.red
                              : PdfColors.green,
                        ),
                        _buildTableCell(
                          invoice.status.toUpperCase(),
                          textColor: invoice.status == 'paid'
                              ? PdfColors.green
                              : invoice.balance > 0 &&
                                      invoice.dueDate.isBefore(DateTime.now())
                                  ? PdfColors.red
                                  : PdfColors.blue,
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 20),

              // Payment Breakdown by Course using pre-grouped data
              pw.Text(
                'PAYMENT BREAKDOWN BY COURSE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 10),

              ...courseInvoicesMap.entries.map((entry) {
                String courseName = entry.key;
                List<Invoice> courseInvoices = entry.value;

                double courseTotalBilled = courseInvoices.fold(
                    0.0, (sum, inv) => sum + inv.totalAmountCalculated);
                double courseTotalPaid = courseInvoices.fold(
                    0.0, (sum, inv) => sum + inv.amountPaid);
                double courseBalance = courseTotalBilled - courseTotalPaid;
                int totalCourseLessons =
                    courseInvoices.fold(0, (sum, inv) => sum + inv.lessons);

                // Get typical course price (from first invoice or course data)
                double typicalPrice = courseInvoices.isNotEmpty
                    ? courseInvoices.first.pricePerLesson
                    : 0.0;

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '$courseName (${courseInvoices.length} invoices)',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Total Lessons: $totalCourseLessons'),
                                pw.Text(
                                    'Standard Price/Lesson: \$${typicalPrice.toStringAsFixed(2)}'),
                                pw.Text(
                                    'Avg Price/Lesson: \$${totalCourseLessons > 0 ? (courseTotalBilled / totalCourseLessons).toStringAsFixed(2) : "0.00"}'),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                    'Total Billed: \$${courseTotalBilled.toStringAsFixed(2)}'),
                                pw.Text(
                                    'Total Paid: \$${courseTotalPaid.toStringAsFixed(2)}'),
                                pw.Text(
                                  'Balance: \$${courseBalance.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                    color: courseBalance > 0
                                        ? PdfColors.red
                                        : PdfColors.green,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),

              pw.SizedBox(height: 30),

              // Footer
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Divider(),
                    pw.Text(
                      'This report was generated automatically by the Driving School Management System',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'All amounts are in USD. Course pricing reflects actual billed rates.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Generate filename with timestamp
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.]'), '_');
      final fileName = 'billing_report_detailed_$timestamp.pdf';

      // Save file using file picker
      final String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Detailed Billing Report',
        fileName: fileName,
        allowedExtensions: ['pdf'],
      );

      if (filePath != null) {
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());

        Get.snackbar(
          'Report Generated',
          'Detailed billing report with course information saved to $filePath',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      } else {
        Get.snackbar('Export Cancelled', 'No file path selected');
      }
    } catch (e) {
      print('Error in generateBillingReportPDF: $e');
      Get.snackbar(
        'Report Failed',
        'Failed to generate detailed report: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

// Helper method for PDF table cells
  pw.Widget _buildTableCell(String text,
      {bool isHeader = false, PdfColor? textColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? (isHeader ? PdfColors.black : PdfColors.grey800),
        ),
      ),
    );
  }

// Get student name by ID (helper method)
  Future<String> getStudentName(int studentId) async {
    try {
      final student = await _dbHelper.getUserById(studentId);
      return student != null
          ? '${student['fname']} ${student['lname']}'
          : 'Unknown Student';
    } catch (e) {
      return 'Unknown Student';
    }
  }

// Export overdue invoices specifically
  Future<void> exportOverdueInvoicesCSV() async {
    try {
      isLoading(true);

      await fetchBillingData();

      // Filter overdue invoices
      List<Invoice> overdueInvoices = invoices.where((invoice) {
        return invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now());
      }).toList();

      if (overdueInvoices.isEmpty) {
        Get.snackbar('No Data', 'No overdue invoices found');
        return;
      }

      // Sort by days overdue (most overdue first)
      overdueInvoices.sort((a, b) {
        int aDaysOverdue = DateTime.now().difference(a.dueDate).inDays;
        int bDaysOverdue = DateTime.now().difference(b.dueDate).inDays;
        return bDaysOverdue.compareTo(aDaysOverdue);
      });

      // Prepare CSV data
      List<List<dynamic>> csvData = [
        [
          'Invoice Number',
          'Student ID',
          'Student Name',
          'Student Email',
          'Student Phone',
          'Course Name',
          'Due Date',
          'Days Overdue',
          'Total Amount',
          'Amount Paid',
          'Balance Due',
          'Original Lessons',
          'Last Payment Date',
          'Contact Priority'
        ],
      ];

      // Process each overdue invoice
      for (var invoice in overdueInvoices) {
        try {
          final student = await _dbHelper.getUserById(invoice.studentId);
          final studentName = student != null
              ? '${student['fname']} ${student['lname']}'
              : 'Unknown';
          final studentEmail = student?['email'] ?? 'Unknown';
          final studentPhone = student?['phone'] ?? 'Unknown';

          final courseName = await getCourseName(invoice.courseId);
          final payments = await getPaymentsForInvoice(invoice.id!);
          final lastPaymentDate = payments.isNotEmpty
              ? payments
                  .map((p) => p.paymentDate)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
              : null;

          final daysOverdue = DateTime.now().difference(invoice.dueDate).inDays;

          // Determine contact priority based on days overdue and amount
          String priority = 'LOW';
          if (daysOverdue > 60 || invoice.balance > 500) {
            priority = 'HIGH';
          } else if (daysOverdue > 30 || invoice.balance > 200) {
            priority = 'MEDIUM';
          }

          csvData.add([
            invoice.invoiceNumber,
            invoice.studentId,
            studentName,
            studentEmail,
            studentPhone,
            courseName,
            DateFormat('yyyy-MM-dd').format(invoice.dueDate),
            daysOverdue,
            invoice.totalAmountCalculated.toStringAsFixed(2),
            invoice.amountPaid.toStringAsFixed(2),
            invoice.balance.toStringAsFixed(2),
            invoice.lessons,
            lastPaymentDate != null
                ? DateFormat('yyyy-MM-dd').format(lastPaymentDate)
                : 'No payments',
            priority
          ]);
        } catch (e) {
          print('Error processing overdue invoice ${invoice.id}: $e');
        }
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Generate filename with timestamp
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.]'), '_');
      final fileName = 'overdue_invoices_$timestamp.csv';

      // Save file using file picker
      final String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Overdue Invoices Export',
        fileName: fileName,
        allowedExtensions: ['csv'],
      );

      if (filePath != null) {
        final file = File(filePath);
        await file.writeAsString(csvString);

        Get.snackbar(
          'Export Successful',
          'Overdue invoices exported to $filePath\n${overdueInvoices.length} overdue invoices found',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      } else {
        Get.snackbar('Export Cancelled', 'No file path selected');
      }
    } catch (e) {
      Get.snackbar(
        'Export Failed',
        'Failed to export overdue invoices: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }
}
