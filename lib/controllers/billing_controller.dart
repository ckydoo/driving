import 'package:driving/models/billing_record.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
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

  Future<List<Map<String, dynamic>>> getPayments() async {
    final db = await _dbHelper.database;
    return await db.query('payments');
  }

  Future<int> insertPayment(Map<String, dynamic> payment) async {
    final db = await _dbHelper.database;
    return await db.insert('payments', payment);
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
        // Fetch payments for the current invoice
        List<Payment> invoicePayments = paymentsData
            .map((json) => Payment.fromJson(json))
            .where((payment) => payment.invoiceId == invoice.id)
            .toList();
        invoice.payments = invoicePayments; // Assign payments to invoice
        fetchedInvoices.add(invoice);
      }

      invoices.assignAll(fetchedInvoices);
      print(
          'BillingController: Invoices after assignAll (invoices): $invoices');
      payments.assignAll(paymentsData.map((json) => Payment.fromJson(json)));
      print(
          'BillingController: Payments after assignAll (payments): $payments');
    } finally {
      isLoading(false);
    }
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

  Future<void> recordPayment(Payment payment) async {
    try {
      isLoading(true);
      await _dbHelper.insertPayment(payment.toJson());
      await _updateInvoiceStatus(payment.invoiceId, payment.amount);
      await fetchBillingData();
    } finally {
      isLoading(false);
    }
  }

  Future<void> _updateInvoiceStatus(int invoiceId, double amount) async {
    final invoice = invoices.firstWhere((inv) => inv.id == invoiceId);
    final newAmountPaid = invoice.amountPaid + amount;
    final status = newAmountPaid >= invoice.totalAmountCalculated
        ? 'paid'
        : newAmountPaid > 0
            ? 'partial'
            : 'unpaid';

    await _dbHelper.updateInvoice(
        {'id': invoiceId, 'amountpaid': newAmountPaid, 'status': status});
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
}
