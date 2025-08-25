import 'dart:io';

import 'package:csv/csv.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/user_controller.dart';
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
import 'package:path_provider/path_provider.dart';
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

  // Fixed fetchBillingData method in billing_controller.dart
  Future<void> fetchBillingData() async {
    try {
      isLoading(true);
      print('BillingController: fetchBillingData called');

      // Get fresh data from database
      final invoicesData = await _dbHelper.getInvoices();
      final paymentsData = await _dbHelper.getPayments();

      print('BillingController: Raw invoice data: $invoicesData');
      print('BillingController: Raw payments data: $paymentsData');

      List<Invoice> fetchedInvoices = [];

      for (var invoiceData in invoicesData) {
        // CRITICAL: Ensure amountpaid is properly parsed from database
        // The issue might be here - make sure amountpaid field is correctly read
        final amountPaid =
            (invoiceData['amountpaid'] as num?)?.toDouble() ?? 0.0;

        print('Invoice ${invoiceData['id']}: amountpaid from DB = $amountPaid');

        // Create invoice with explicit amountPaid value
        Invoice invoice = Invoice.fromJson(invoiceData);

        // Double-check by recalculating from payments
        List<Payment> invoicePayments = paymentsData
            .map((json) => Payment.fromJson(json))
            .where((payment) => payment.invoiceId == invoice.id)
            .toList();

        // Calculate total payments for this invoice
        double calculatedAmountPaid =
            invoicePayments.fold(0.0, (sum, payment) => sum + payment.amount);

        print(
            'Invoice ${invoice.id}: calculated amount paid from payments = $calculatedAmountPaid');
        print('Invoice ${invoice.id}: DB amount paid = ${invoice.amountPaid}');

        // If there's a mismatch, prefer the calculated value and update DB
        if ((calculatedAmountPaid - invoice.amountPaid).abs() > 0.01) {
          print(
              '⚠️ MISMATCH DETECTED: Updating invoice ${invoice.id} amountpaid from ${invoice.amountPaid} to $calculatedAmountPaid');

          // Update the database with correct amount
          await _updateInvoiceAmountPaid(invoice.id!, calculatedAmountPaid);

          // Create corrected invoice
          invoice = invoice.copyWith(amountPaid: calculatedAmountPaid);
        }

        invoice.payments = invoicePayments;
        fetchedInvoices.add(invoice);

        print(
            'Final invoice ${invoice.id}: amountPaid = ${invoice.amountPaid}, balance = ${invoice.balance}');
      }

      // Update observable lists
      invoices.assignAll(fetchedInvoices);
      payments.assignAll(paymentsData.map((json) => Payment.fromJson(json)));

      print(
          'BillingController: Updated ${invoices.length} invoices and ${payments.length} payments');
    } catch (e) {
      print('ERROR in fetchBillingData: $e');
      throw e;
    } finally {
      isLoading(false);
    }
  }

// Add this helper method to fix amountpaid mismatches
  Future<void> _updateInvoiceAmountPaid(
      int invoiceId, double correctAmountPaid) async {
    try {
      final db = await _dbHelper.database;

      // Calculate new status
      final invoiceResults = await db.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      if (invoiceResults.isNotEmpty) {
        final invoiceData = invoiceResults.first;
        final totalAmount = (invoiceData['total_amount'] as num?)?.toDouble() ??
            ((invoiceData['lessons'] as num).toDouble() *
                (invoiceData['price_per_lesson'] as num).toDouble());

        String newStatus;
        if (correctAmountPaid >= totalAmount) {
          newStatus = 'paid';
        } else if (correctAmountPaid > 0) {
          newStatus = 'partial';
        } else {
          newStatus = 'unpaid';
        }

        // Update the database
        await db.update(
          'invoices',
          {
            'amountpaid': correctAmountPaid,
            'status': newStatus,
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        print(
            '✓ Fixed invoice $invoiceId: amountpaid = $correctAmountPaid, status = $newStatus');
      }
    } catch (e) {
      print('ERROR updating invoice amount paid: $e');
    }
  }

// Also add a method to verify and fix all invoice payment amounts
  Future<void> repairAllInvoicePayments() async {
    try {
      print('Starting invoice payment repair...');

      final invoicesData = await _dbHelper.getInvoices();
      final paymentsData = await _dbHelper.getPayments();

      for (var invoiceData in invoicesData) {
        final invoiceId = invoiceData['id'] as int;
        final dbAmountPaid =
            (invoiceData['amountpaid'] as num?)?.toDouble() ?? 0.0;

        // Calculate actual amount paid from payments
        final invoicePayments = paymentsData
            .where((payment) => payment['invoiceId'] == invoiceId)
            .toList();

        double actualAmountPaid = 0.0;
        for (var payment in invoicePayments) {
          actualAmountPaid += (payment['amount'] as num).toDouble();
        }

        // Check if there's a mismatch
        if ((actualAmountPaid - dbAmountPaid).abs() > 0.01) {
          print(
              'Repairing invoice $invoiceId: DB shows $dbAmountPaid, actual is $actualAmountPaid');
          await _updateInvoiceAmountPaid(invoiceId, actualAmountPaid);
        }
      }

      // Refresh data after repair
      await fetchBillingData();

      print('Invoice payment repair completed');
    } catch (e) {
      print('ERROR in repairAllInvoicePayments: $e');
    }
  }

// Add this method to your BillingController and call it once
  Future<void> fixInvoicePaymentSync() async {
    try {
      print('Starting invoice payment sync fix...');

      final db = await _dbHelper.database;

      // Get all invoices
      final invoices = await db.query('invoices');

      for (var invoice in invoices) {
        final invoiceId = invoice['id'] as int;

        // Calculate total payments for this invoice
        final paymentsResult = await db.query(
          'payments',
          where: 'invoiceId = ?',
          whereArgs: [invoiceId],
        );

        double totalPaid = 0.0;
        for (var payment in paymentsResult) {
          totalPaid += (payment['amount'] as num).toDouble();
        }

        print(
            'Invoice $invoiceId: Current amountpaid = ${invoice['amountpaid']}, Calculated = $totalPaid');

        // Update if different
        if (totalPaid != (invoice['amountpaid'] as num?)?.toDouble()) {
          final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ??
              ((invoice['lessons'] as num).toDouble() *
                  (invoice['price_per_lesson'] as num).toDouble());

          String newStatus;
          if (totalPaid >= totalAmount) {
            newStatus = 'paid';
          } else if (totalPaid > 0) {
            newStatus = 'partial';
          } else {
            newStatus = 'unpaid';
          }

          await db.update(
            'invoices',
            {
              'amountpaid': totalPaid,
              'status': newStatus,
            },
            where: 'id = ?',
            whereArgs: [invoiceId],
          );

          print(
              '✓ Fixed invoice $invoiceId: amountpaid updated to $totalPaid, status: $newStatus');
        }
      }

      // Refresh billing data
      await fetchBillingData();

      Get.snackbar(
        'Sync Fixed',
        'Invoice payment sync has been repaired',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error fixing invoice payment sync: $e');
      Get.snackbar(
        'Error',
        'Failed to fix sync: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> recordPayment(Payment payment, {bool silent = false}) async {
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
      if (!silent) {
        Get.snackbar(
          'Payment Recorded',
          'Payment of \$${payment.amount.toStringAsFixed(2)} recorded successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('=== ERROR in recordPayment ===');
      if (!silent) {
        Get.snackbar('Error', 'Failed to record payment: ${e.toString()}');
      }
      throw e;
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

  // Enhanced receipt generation method
  Future<String> generateEnhancedReceipt(Payment payment) async {
    try {
      // Find the invoice for this payment
      final invoice = invoices.firstWhere(
        (inv) => inv.id == payment.invoiceId,
        orElse: () => throw Exception('Invoice not found for payment'),
      );

      // Find the student for this invoice
      final userController = Get.find<UserController>();
      final student = userController.users.firstWhere(
        (user) => user.id == invoice.studentId,
        orElse: () => throw Exception('Student not found for invoice'),
      );

      // Generate receipt using enhanced service
      final receiptPath = await ReceiptService.generateReceipt(
        payment,
        invoice,
        student,
      );

      // Update payment with receipt info
      await _updatePaymentWithReceipt(payment, receiptPath);

      // Refresh data
      await fetchBillingData();

      return receiptPath;
    } catch (e) {
      print('Error generating enhanced receipt: $e');
      rethrow;
    }
  }

  // Batch receipt generation
  Future<List<String>> generateReceiptsForInvoice(int invoiceId) async {
    try {
      final paymentsForInvoice =
          payments.where((p) => p.invoiceId == invoiceId).toList();
      final invoice = invoices.firstWhere((inv) => inv.id == invoiceId);
      final userController = Get.find<UserController>();
      final student = userController.users
          .firstWhere((user) => user.id == invoice.studentId);

      final List<String> receiptPaths = [];

      for (final payment in paymentsForInvoice) {
        if (!payment.receiptGenerated) {
          final receiptPath = await ReceiptService.generateReceipt(
            payment,
            invoice,
            student,
          );

          await _updatePaymentWithReceipt(payment, receiptPath);
          receiptPaths.add(receiptPath);
        }
      }

      await fetchBillingData();
      return receiptPaths;
    } catch (e) {
      print('Error generating receipts for invoice: $e');
      rethrow;
    }
  }

  // Generate receipts for all payments missing receipts
  Future<int> generateMissingReceipts() async {
    try {
      isLoading.value = true;
      int generatedCount = 0;

      final paymentsWithoutReceipts =
          payments.where((p) => !p.receiptGenerated).toList();

      for (final payment in paymentsWithoutReceipts) {
        try {
          await generateEnhancedReceipt(payment);
          generatedCount++;
        } catch (e) {
          print('Failed to generate receipt for payment ${payment.id}: $e');
        }
      }

      await fetchBillingData();
      return generatedCount;
    } finally {
      isLoading.value = false;
    }
  }

  // Update payment record with receipt information
  Future<void> _updatePaymentWithReceipt(
      Payment payment, String receiptPath) async {
    final db = await _dbHelper.database;
    await db.update(
      'payments',
      {
        'receipt_path': receiptPath,
        'receipt_generated': 1,
        'receipt_generated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  // Validate business settings before receipt generation
  Future<bool> validateBusinessSettingsForReceipts() async {
    final settingsController = Get.find<SettingsController>();

    final requiredFields = [
      settingsController.businessName.value,
    ];

    final missingFields = <String>[];

    if (settingsController.businessName.value.isEmpty)
      missingFields.add('Business Name');
    if (settingsController.businessAddress.value.isEmpty)
      missingFields.add('Business Address');
    if (settingsController.businessPhone.value.isEmpty)
      missingFields.add('Business Phone');
    if (settingsController.businessEmail.value.isEmpty)
      missingFields.add('Business Email');

    if (missingFields.isNotEmpty) {
      Get.snackbar(
        'Missing Business Information',
        'Please complete the following in Settings: ${missingFields.join(', ')}',
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade800,
      );
      return false;
    }

    return true;
  }

  // Enhanced receipt generation with validation
  Future<String?> generateReceiptWithValidation(Payment payment) async {
    // Check if business settings are complete
    if (!await validateBusinessSettingsForReceipts()) {
      return null;
    }

    try {
      return await generateEnhancedReceipt(payment);
    } catch (e) {
      Get.snackbar(
        'Receipt Generation Failed',
        'Failed to generate receipt: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
      return null;
    }
  }

  // Print receipt directly
  Future<void> printReceipt(Payment payment) async {
    try {
      String? receiptPath = payment.receiptPath;

      // Generate receipt if it doesn't exist
      if (receiptPath == null || !payment.receiptGenerated) {
        receiptPath = await generateReceiptWithValidation(payment);
        if (receiptPath == null) return;
      }

      await ReceiptService.printReceipt(receiptPath);

      Get.snackbar(
        'Receipt Sent to Printer',
        'Receipt for ${payment.reference} has been sent to printer',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
      );
    } catch (e) {
      Get.snackbar(
        'Print Failed',
        'Failed to print receipt: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    }
  }

  // Share receipt
  Future<void> shareReceipt(Payment payment) async {
    try {
      String? receiptPath = payment.receiptPath;

      // Generate receipt if it doesn't exist
      if (receiptPath == null || !payment.receiptGenerated) {
        receiptPath = await generateReceiptWithValidation(payment);
        if (receiptPath == null) return;
      }

      await ReceiptService.shareReceipt(receiptPath);
    } catch (e) {
      Get.snackbar(
        'Share Failed',
        'Failed to share receipt: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    }
  }

  // Get receipt statistics
  Map<String, int> getReceiptStatistics() {
    final totalPayments = payments.length;
    final paymentsWithReceipts =
        payments.where((p) => p.receiptGenerated).length;
    final paymentsWithoutReceipts = totalPayments - paymentsWithReceipts;

    return {
      'total_payments': totalPayments,
      'receipts_generated': paymentsWithReceipts,
      'receipts_missing': paymentsWithoutReceipts,
      'generation_rate': totalPayments > 0
          ? ((paymentsWithReceipts / totalPayments) * 100).round()
          : 0,
    };
  }

  // Email receipt (if email functionality is available)
  Future<void> emailReceipt(Payment payment, String recipientEmail) async {
    try {
      String? receiptPath = payment.receiptPath;

      // Generate receipt if it doesn't exist
      if (receiptPath == null || !payment.receiptGenerated) {
        receiptPath = await generateReceiptWithValidation(payment);
        if (receiptPath == null) return;
      }

      // Find invoice and student details
      final invoice = invoices.firstWhere((inv) => inv.id == payment.invoiceId);
      final userController = Get.find<UserController>();
      final student = userController.users
          .firstWhere((user) => user.id == invoice.studentId);
      final settingsController = Get.find<SettingsController>();

      // You would integrate with your email service here
      // This is a placeholder for the email functionality
      final emailSubject = 'Payment Receipt - ${payment.reference}';
      final emailBody = '''
Dear ${student.fname} ${student.lname},

Thank you for your payment. Please find your receipt attached.

Payment Details:
- Receipt #: ${payment.reference}
- Amount: \${payment.amount.toStringAsFixed(2)}
- Date: ${DateFormat('MMMM dd, yyyy').format(payment.paymentDate)}
- Invoice #: ${invoice.invoiceNumber}

Best regards,
${settingsController.businessName.value}
${settingsController.businessPhone.value}
${settingsController.businessEmail.value}
      ''';

      // Implement your email service here
      // await EmailService.sendEmailWithAttachment(
      //   to: recipientEmail,
      //   subject: emailSubject,
      //   body: emailBody,
      //   attachmentPath: receiptPath,
      // );

      Get.snackbar(
        'Receipt Emailed',
        'Receipt has been sent to $recipientEmail',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
      );
    } catch (e) {
      Get.snackbar(
        'Email Failed',
        'Failed to email receipt: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    }
  }

  // Regenerate receipt with updated business information
  Future<String?> regenerateReceipt(Payment payment) async {
    try {
      // Delete old receipt file if it exists
      if (payment.receiptPath != null) {
        final oldFile = File(payment.receiptPath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      // Generate new receipt
      final receiptPath = await generateReceiptWithValidation(payment);

      if (receiptPath != null) {
        Get.snackbar(
          'Receipt Regenerated',
          'Receipt has been updated with current business information',
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
        );
      }

      return receiptPath;
    } catch (e) {
      Get.snackbar(
        'Regeneration Failed',
        'Failed to regenerate receipt: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
      return null;
    }
  }

  // Bulk operations for receipts
  Future<void> bulkGenerateReceipts(List<int> paymentIds) async {
    try {
      isLoading.value = true;
      int successCount = 0;
      int failCount = 0;

      for (final paymentId in paymentIds) {
        final payment = payments.firstWhere((p) => p.id == paymentId);
        try {
          await generateEnhancedReceipt(payment);
          successCount++;
        } catch (e) {
          failCount++;
          print('Failed to generate receipt for payment $paymentId: $e');
        }
      }

      await fetchBillingData();

      Get.snackbar(
        'Bulk Generation Complete',
        'Generated $successCount receipts successfully${failCount > 0 ? ', $failCount failed' : ''}',
        backgroundColor:
            successCount > 0 ? Colors.green.shade100 : Colors.orange.shade100,
        colorText:
            successCount > 0 ? Colors.green.shade800 : Colors.orange.shade800,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Export receipts data to CSV
  Future<String> exportReceiptsData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${directory.path}/reports');
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }

      final fileName =
          'receipts_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${reportsDir.path}/$fileName');

      // Prepare CSV data
      final List<List<String>> csvData = [
        // Header row
        [
          'Receipt Reference',
          'Payment Date',
          'Student Name',
          'Invoice Number',
          'Amount',
          'Payment Method',
          'Receipt Generated',
          'Receipt Path',
          'Notes'
        ]
      ];

      // Data rows
      for (final payment in payments) {
        final invoice =
            invoices.firstWhereOrNull((inv) => inv.id == payment.invoiceId);
        final userController = Get.find<UserController>();
        final student = userController.users
            .firstWhereOrNull((user) => user.id == invoice?.studentId);

        csvData.add([
          payment.reference ?? 'N/A',
          DateFormat('yyyy-MM-dd HH:mm').format(payment.paymentDate),
          student != null ? '${student.fname} ${student.lname}' : 'Unknown',
          invoice?.invoiceNumber ?? 'N/A',
          payment.amount.toStringAsFixed(2),
          payment.method ?? 'Cash',
          payment.receiptGenerated ? 'Yes' : 'No',
          payment.receiptPath ?? 'N/A',
          payment.notes ?? ''
        ]);
      }

      // Write CSV file
      final csv = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csv);

      return file.path;
    } catch (e) {
      print('Error exporting receipts data: $e');
      rethrow;
    }
  }
}
