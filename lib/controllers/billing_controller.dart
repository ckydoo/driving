import 'package:driving/models/billing_record.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/receipt_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/database_helper.dart';

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

  Future<void> updateInvoice(Map<String, dynamic> updatedInvoiceData) async {
    try {
      isLoading(true);
      print(
          'BillingController: updateInvoice called with data: $updatedInvoiceData'); // ADD THIS
      await _dbHelper.updateInvoice(updatedInvoiceData);
      await fetchBillingData(); // Refresh the invoice list
    } catch (e) {
      print(
          'BillingController: Error updating invoice: ${e.toString()}'); // ADD THIS
      Get.snackbar('Error', 'Failed to update invoice');
    } finally {
      isLoading(false);
    }
  }

  // Edit an invoice
  Future<void> editInvoice(Invoice invoice) async {
    await DatabaseHelper.instance.updateInvoice(invoice.toMap());
    fetchBillingData(); // Refresh the list of invoices
  }

// BillingController
  Future<String> getCourseName(int courseId) async {
    // Fetch the course name from your database or service
    final course = await DatabaseHelper.instance.getCourseById(courseId);
    return course?.name ?? 'Unknown Course';
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
      isLoading(true);
      final existingInvoice = invoices.firstWhereOrNull(
        (inv) => inv.studentId == studentId && inv.courseId == courseId,
      );

      if (existingInvoice != null) {
        // Update existing invoice
        final updatedLessons = existingInvoice.lessons + lessons;
        final updatedTotalAmount = updatedLessons * pricePerLesson;
        final updatedInvoice = existingInvoice.copyWith(
          lessons: updatedLessons,
          totalAmount: updatedTotalAmount,
          // You might want to adjust dueDate here based on your logic
        );
        await _dbHelper.updateInvoice(updatedInvoice.toJson());
      } else {
        // Create new invoice
        final invoice = Invoice(
          studentId: studentId,
          courseId: courseId,
          lessons: lessons,
          pricePerLesson: pricePerLesson,
          totalAmount: lessons * pricePerLesson,
          createdDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 30)),
        );
        await _dbHelper.insertInvoice(invoice.toJson());
      }
      await fetchBillingData();
    } finally {
      isLoading(false);
    }
  }

  Future<void> addLessonsBack(int studentId, int lessonsToAdd) async {
    try {
      print(
          'BillingController: addLessonsBack called with studentId: $studentId, lessonsToAdd: $lessonsToAdd'); // ADD THIS
      final index = invoices.indexWhere((inv) => inv.studentId == studentId);
      print('BillingController: index of invoice: $index'); // ADD THIS
      if (index == -1) {
        print(
            'BillingController: Invoice not found for studentId: $studentId'); // ADD THIS
        return;
      }

      final invoice = invoices[index];
      print(
          'BillingController: Found invoice: ${invoice.toString()}'); // ADD THIS  (You might need to override toString() in your Invoice model)
      final updatedLessons = invoice.lessons + lessonsToAdd;
      print(
          'BillingController: Updated lessons count: $updatedLessons'); // ADD THIS

      // Update in the database
      await _dbHelper.updateInvoice({
        'id': invoice.id,
        'lessons': updatedLessons,
      });
      print('BillingController: Invoice updated in DB'); // ADD THIS

      // Update locally
      final updatedInvoice = invoice.copyWith(lessons: updatedLessons);
      invoices[index] = updatedInvoice;
      invoices.refresh();
      print('BillingController: Invoice updated locally'); // ADD THIS
    } catch (e) {
      print(
          'BillingController: Error in addLessonsBack: ${e.toString()}'); // ADD THIS
      Get.snackbar('Error', 'Failed to update billing info');
    }
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
}
