// lib/screens/reports/financial_reports_screen.dart
import 'package:driving/models/payment.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../controllers/billing_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/settings_controller.dart';

class FinancialReportsScreen extends StatefulWidget {
  @override
  _FinancialReportsScreenState createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  final BillingController billingController = Get.find<BillingController>();
  final CourseController courseController = Get.find<CourseController>();
  final UserController userController = Get.find<UserController>();
  final SettingsController settingsController = Get.find<SettingsController>();

  String selectedReportType = '';
  DateTimeRange? selectedDateRange;
  bool isGenerating = false;

  final Map<String, List<Map<String, dynamic>>> reportCategories = {
    'Sales & Revenue Reports': [
      {
        'id': 'sales_report',
        'title': 'Detailed Sales Report',
        'description':
            'Complete list of all sales transactions with customer details',
        'icon': Icons.receipt_long,
        'color': Colors.green,
        'type': 'document'
      },
      {
        'id': 'daily_sales',
        'title': 'Daily Sales Summary',
        'description': 'Day-by-day breakdown of sales with totals',
        'icon': Icons.today,
        'color': Colors.blue,
        'type': 'document'
      },
      {
        'id': 'course_sales',
        'title': 'Sales by Course',
        'description': 'Detailed breakdown of sales for each course',
        'icon': Icons.school,
        'color': Colors.purple,
        'type': 'document'
      },
    ],
    'Payment Reports': [
      {
        'id': 'payment_register',
        'title': 'Payment Register',
        'description': 'Chronological list of all payments received',
        'icon': Icons.payment,
        'color': Colors.teal,
        'type': 'document'
      },
      {
        'id': 'payment_methods',
        'title': 'Payment Methods Report',
        'description': 'Breakdown of payments by method (Cash, Mobile, etc.)',
        'icon': Icons.credit_card,
        'color': Colors.orange,
        'type': 'document'
      },
      {
        'id': 'outstanding_payments',
        'title': 'Outstanding Payments Report',
        'description': 'Detailed list of unpaid invoices and overdue accounts',
        'icon': Icons.warning,
        'color': Colors.red,
        'type': 'document'
      },
    ],
    'Customer Reports': [
      {
        'id': 'customer_statements',
        'title': 'Customer Account Statements',
        'description': 'Individual customer transaction history',
        'icon': Icons.person,
        'color': Colors.indigo,
        'type': 'document'
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Reports'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (selectedReportType.isNotEmpty)
            IconButton(
              icon: Icon(Icons.date_range),
              onPressed: _selectDateRange,
              tooltip: 'Select Date Range',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildReportSelector(),
          Expanded(
            child: selectedReportType.isEmpty
                ? _buildReportCategoriesView()
                : _buildSelectedReportView(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDataTable(String reportId) {
    switch (reportId) {
      case 'sales_report':
        return _buildSalesReportTable();
      case 'payment_register':
        return _buildPaymentRegisterTable();
      case 'outstanding_payments':
        return _buildOutstandingPaymentsTable();
      case 'customer_statements':
        return _buildCustomerStatementsTable();
      case 'daily_sales':
        return _buildDailySalesTable();
      case 'course_sales':
        return _buildCourseSalesTable();
      default:
        return Text('Report data will be displayed here');
    }
  }

  pw.Widget _buildPDFSalesReport() {
    final salesData = _getSalesReportData();
    final totalAmount =
        salesData.fold(0.0, (sum, sale) => sum + sale['amount']);
    final avgSale = salesData.isNotEmpty ? totalAmount / salesData.length : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Summary section
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.green200),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('Total Sales',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Transactions',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text(salesData.length.toString(),
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Average Sale',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${avgSale.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Detailed transactions table
        pw.Text('Detailed Sales Transactions',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FlexColumnWidth(1.5),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2.5),
            3: pw.FlexColumnWidth(2),
            4: pw.FlexColumnWidth(1.5),
            5: pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildPDFTableCell('Date', isHeader: true),
                _buildPDFTableCell('Invoice #', isHeader: true),
                _buildPDFTableCell('Customer', isHeader: true),
                _buildPDFTableCell('Course', isHeader: true),
                _buildPDFTableCell('Amount', isHeader: true),
                _buildPDFTableCell('Method', isHeader: true),
              ],
            ),
            // Data rows
            ...salesData
                .map((sale) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(
                            DateFormat('MM/dd/yyyy').format(sale['date'])),
                        _buildPDFTableCell(sale['invoiceNumber']),
                        _buildPDFTableCell(sale['customerName']),
                        _buildPDFTableCell(sale['courseName']),
                        _buildPDFTableCell(
                            '\$${sale['amount'].toStringAsFixed(2)}'),
                        _buildPDFTableCell(sale['paymentMethod']),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFPaymentRegister() {
    final payments = _getFilteredPayments();
    final totalAmount =
        payments.fold(0.0, (sum, payment) => sum + payment.amount);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Summary
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.blue200),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('Total Received',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Total Payments',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text(payments.length.toString(),
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Payment register table
        pw.Text('Payment Register',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildPDFTableCell('Date', isHeader: true),
                _buildPDFTableCell('Receipt #', isHeader: true),
                _buildPDFTableCell('Customer', isHeader: true),
                _buildPDFTableCell('Amount', isHeader: true),
                _buildPDFTableCell('Method', isHeader: true),
                _buildPDFTableCell('Reference', isHeader: true),
              ],
            ),
            // Data rows
            ...payments.map((payment) {
              final invoice = billingController.invoices
                  .firstWhere((inv) => inv.id == payment.invoiceId);
              final student = userController.users
                  .firstWhere((user) => user.id == invoice.studentId);

              return pw.TableRow(
                children: [
                  _buildPDFTableCell(
                      DateFormat('MM/dd/yyyy').format(payment.paymentDate)),
                  _buildPDFTableCell(payment.receiptNumber),
                  _buildPDFTableCell('${student.fname} ${student.lname}'),
                  _buildPDFTableCell('\$${payment.amount.toStringAsFixed(2)}'),
                  _buildPDFTableCell(payment.displayMethod),
                  _buildPDFTableCell(payment.reference ?? '-'),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFOutstandingPayments() {
    final outstandingInvoices = _getOutstandingInvoices();
    final totalOutstanding =
        outstandingInvoices.fold(0.0, (sum, inv) => sum + inv.balance);
    final overdueCount = outstandingInvoices
        .where((inv) =>
            inv.dueDate != null && inv.dueDate!.isBefore(DateTime.now()))
        .length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Summary
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.red50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.red200),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('Total Outstanding',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${totalOutstanding.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Outstanding Invoices',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text(outstandingInvoices.length.toString(),
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Overdue Invoices',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text(overdueCount.toString(),
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Outstanding invoices table
        pw.Text('Outstanding Invoices Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildPDFTableCell('Invoice #', isHeader: true),
                _buildPDFTableCell('Customer', isHeader: true),
                _buildPDFTableCell('Due Date', isHeader: true),
                _buildPDFTableCell('Total', isHeader: true),
                _buildPDFTableCell('Paid', isHeader: true),
                _buildPDFTableCell('Balance', isHeader: true),
                _buildPDFTableCell('Days Overdue', isHeader: true),
              ],
            ),
            // Data rows
            ...outstandingInvoices.map((invoice) {
              final student = userController.users
                  .firstWhere((user) => user.id == invoice.studentId);
              final daysOverdue = invoice.dueDate != null &&
                      invoice.dueDate!.isBefore(DateTime.now())
                  ? DateTime.now().difference(invoice.dueDate!).inDays
                  : 0;

              return pw.TableRow(
                children: [
                  _buildPDFTableCell(invoice.invoiceNumber),
                  _buildPDFTableCell('${student.fname} ${student.lname}'),
                  _buildPDFTableCell(invoice.dueDate != null
                      ? DateFormat('MM/dd/yyyy').format(invoice.dueDate!)
                      : '-'),
                  _buildPDFTableCell(
                      '\$${invoice.totalAmountCalculated.toStringAsFixed(2)}'),
                  _buildPDFTableCell(
                      '\$${invoice.amountPaid.toStringAsFixed(2)}'),
                  _buildPDFTableCell('\$${invoice.balance.toStringAsFixed(2)}'),
                  _buildPDFTableCell(
                      daysOverdue > 0 ? daysOverdue.toString() : '-'),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFCustomerStatements() {
    final customerData = _getCustomerStatementsData();
    final totalOutstanding =
        customerData.fold(0.0, (sum, customer) => sum + customer['balance']);
    final totalInvoiced = customerData.fold(
        0.0, (sum, customer) => sum + customer['totalInvoiced']);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Summary
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.indigo200),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('Total Customers',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text(customerData.length.toString(),
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Total Invoiced',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${totalInvoiced.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Total Outstanding',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${totalOutstanding.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Customer statements table
        pw.Text('Customer Account Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildPDFTableCell('Customer', isHeader: true),
                _buildPDFTableCell('Total Invoiced', isHeader: true),
                _buildPDFTableCell('Total Paid', isHeader: true),
                _buildPDFTableCell('Balance', isHeader: true),
                _buildPDFTableCell('Last Payment', isHeader: true),
                _buildPDFTableCell('Status', isHeader: true),
              ],
            ),
            // Data rows
            ...customerData
                .map((customer) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(customer['name']),
                        _buildPDFTableCell(
                            '\$${customer['totalInvoiced'].toStringAsFixed(2)}'),
                        _buildPDFTableCell(
                            '\$${customer['totalPaid'].toStringAsFixed(2)}'),
                        _buildPDFTableCell(
                            '\$${customer['balance'].toStringAsFixed(2)}'),
                        _buildPDFTableCell(
                            customer['lastPayment'] ?? 'No payments'),
                        _buildPDFTableCell(customer['status']),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFDailySales() {
    final dailySales = _getDailySalesData();
    final totalSales =
        dailySales.fold(0.0, (sum, day) => sum + day['totalSales']);
    final avgDaily =
        dailySales.isNotEmpty ? totalSales / dailySales.length : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Summary
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.blue200),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('Total Sales',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${totalSales.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Days Covered',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text(dailySales.length.toString(),
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Avg Daily Sales',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${avgDaily.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Daily sales table
        pw.Text('Daily Sales Breakdown',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildPDFTableCell('Date', isHeader: true),
                _buildPDFTableCell('Transactions', isHeader: true),
                _buildPDFTableCell('Total Sales', isHeader: true),
                _buildPDFTableCell('Cash', isHeader: true),
                _buildPDFTableCell('Mobile', isHeader: true),
                _buildPDFTableCell('Other', isHeader: true),
              ],
            ),
            // Data rows
            ...dailySales.map((day) {
              final otherAmount =
                  day['totalSales'] - day['cash'] - day['mobile'];
              return pw.TableRow(
                children: [
                  _buildPDFTableCell(
                      DateFormat('MM/dd/yyyy').format(day['date'])),
                  _buildPDFTableCell(day['transactions'].toString()),
                  _buildPDFTableCell(
                      '\$${day['totalSales'].toStringAsFixed(2)}'),
                  _buildPDFTableCell('\$${day['cash'].toStringAsFixed(2)}'),
                  _buildPDFTableCell('\$${day['mobile'].toStringAsFixed(2)}'),
                  _buildPDFTableCell('\$${otherAmount.toStringAsFixed(2)}'),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFCourseSales() {
    final courseSales = _getCourseSalesData();
    final totalSales =
        courseSales.fold(0.0, (sum, course) => sum + course['totalSales']);
    final totalOutstanding =
        courseSales.fold(0.0, (sum, course) => sum + course['outstanding']);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Summary
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.purple50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.purple200),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('Total Course Sales',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${totalSales.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Active Courses',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text(courseSales.length.toString(),
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Total Outstanding',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text('\$${totalOutstanding.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Course sales table
        pw.Text('Course Sales Analysis',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildPDFTableCell('Course', isHeader: true),
                _buildPDFTableCell('Students', isHeader: true),
                _buildPDFTableCell('Total Sales', isHeader: true),
                _buildPDFTableCell('Avg/Student', isHeader: true),
                _buildPDFTableCell('Outstanding', isHeader: true),
                _buildPDFTableCell('Collection %', isHeader: true),
              ],
            ),
            // Data rows
            ...courseSales.map((course) {
              final totalInvoiced =
                  course['totalSales'] + course['outstanding'];
              final collectionRate = totalInvoiced > 0
                  ? (course['totalSales'] / totalInvoiced * 100)
                  : 0.0;

              return pw.TableRow(
                children: [
                  _buildPDFTableCell(course['courseName']),
                  _buildPDFTableCell(course['studentCount'].toString()),
                  _buildPDFTableCell(
                      '\$${course['totalSales'].toStringAsFixed(2)}'),
                  _buildPDFTableCell(
                      '\$${course['avgPerStudent'].toStringAsFixed(2)}'),
                  _buildPDFTableCell(
                      '\$${course['outstanding'].toStringAsFixed(2)}'),
                  _buildPDFTableCell('${collectionRate.toStringAsFixed(1)}%'),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSalesReportTable() {
    // Get sales data (payments) with customer and course details
    final salesData = _getSalesReportData().take(10).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
              label:
                  Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Invoice #',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Customer',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Course',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Amount',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Method',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: salesData
            .map((sale) => DataRow(cells: [
                  DataCell(Text(DateFormat('MM/dd/yyyy').format(sale['date']))),
                  DataCell(Text(sale['invoiceNumber'])),
                  DataCell(Text(sale['customerName'])),
                  DataCell(Text(sale['courseName'])),
                  DataCell(Text('\$${sale['amount'].toStringAsFixed(2)}')),
                  DataCell(Text(sale['paymentMethod'])),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildPaymentRegisterTable() {
    final payments = _getFilteredPayments().take(10).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
              label:
                  Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Receipt #',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Customer',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Amount',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Method',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Reference',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: payments.map((payment) {
          final invoice = billingController.invoices
              .firstWhere((inv) => inv.id == payment.invoiceId);
          final student = userController.users
              .firstWhere((user) => user.id == invoice.studentId);

          return DataRow(cells: [
            DataCell(
                Text(DateFormat('MM/dd/yyyy').format(payment.paymentDate))),
            DataCell(Text(payment?.receiptNumber ?? 'N/A')),
            DataCell(Text('${student.fname} ${student.lname}')),
            DataCell(Text('\$${payment.amount.toStringAsFixed(2)}')),
            DataCell(Text(payment.displayMethod)),
            DataCell(Text(payment.reference ?? '-')),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildOutstandingPaymentsTable() {
    final outstandingInvoices = _getOutstandingInvoices().take(10).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
              label: Text('Invoice #',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Customer',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Issue Date',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Due Date',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Total Amount',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('Paid', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Balance',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Days Overdue',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: outstandingInvoices.map((invoice) {
          final student = userController.users
              .firstWhere((user) => user.id == invoice.studentId);
          final daysOverdue = invoice.dueDate != null &&
                  invoice.dueDate!.isBefore(DateTime.now())
              ? DateTime.now().difference(invoice.dueDate!).inDays
              : 0;

          return DataRow(cells: [
            DataCell(Text(invoice.invoiceNumber)),
            DataCell(Text('${student.fname} ${student.lname}')),
            DataCell(Text(DateFormat('MM/dd/yyyy').format(invoice.createdAt))),
            DataCell(Text(invoice.dueDate != null
                ? DateFormat('MM/dd/yyyy').format(invoice.dueDate!)
                : '-')),
            DataCell(
                Text('\$${invoice.totalAmountCalculated.toStringAsFixed(2)}')),
            DataCell(Text('\$${invoice.amountPaid.toStringAsFixed(2)}')),
            DataCell(Text(
              '\$${invoice.balance.toStringAsFixed(2)}',
              style: TextStyle(
                color: invoice.balance > 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            )),
            DataCell(Text(
              daysOverdue > 0 ? daysOverdue.toString() : '-',
              style: TextStyle(
                color: daysOverdue > 0 ? Colors.red : Colors.grey,
                fontWeight:
                    daysOverdue > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildCustomerStatementsTable() {
    final customerData = _getCustomerStatementsData().take(10).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
              label: Text('Customer',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Total Invoiced',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Total Paid',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Balance',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Last Payment',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Status',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: customerData
            .map((customer) => DataRow(cells: [
                  DataCell(Text(customer['name'])),
                  DataCell(Text(
                      '\$${customer['totalInvoiced'].toStringAsFixed(2)}')),
                  DataCell(
                      Text('\$${customer['totalPaid'].toStringAsFixed(2)}')),
                  DataCell(Text(
                    '\$${customer['balance'].toStringAsFixed(2)}',
                    style: TextStyle(
                      color:
                          customer['balance'] > 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  )),
                  DataCell(Text(customer['lastPayment'] ?? 'No payments')),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: customer['status'] == 'Current'
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      customer['status'],
                      style: TextStyle(
                        color: customer['status'] == 'Current'
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  )),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildDailySalesTable() {
    final dailySales = _getDailySalesData().take(10).toList();

    return DataTable(
      columns: [
        DataColumn(
            label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Transactions',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Total Sales',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Cash', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Mobile', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: dailySales
          .map((day) => DataRow(cells: [
                DataCell(Text(DateFormat('MM/dd/yyyy').format(day['date']))),
                DataCell(Text(day['transactions'].toString())),
                DataCell(Text('\$${day['totalSales'].toStringAsFixed(2)}')),
                DataCell(Text('\$${day['cash'].toStringAsFixed(2)}')),
                DataCell(Text('\$${day['mobile'].toStringAsFixed(2)}')),
              ]))
          .toList(),
    );
  }

  Widget _buildCourseSalesTable() {
    final courseSales = _getCourseSalesData().take(10).toList();

    return DataTable(
      columns: [
        DataColumn(
            label:
                Text('Course', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Students',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Total Sales',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Avg per Student',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Outstanding',
                style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: courseSales
          .map((course) => DataRow(cells: [
                DataCell(Text(course['courseName'])),
                DataCell(Text(course['studentCount'].toString())),
                DataCell(Text('\$${course['totalSales'].toStringAsFixed(2)}')),
                DataCell(
                    Text('\$${course['avgPerStudent'].toStringAsFixed(2)}')),
                DataCell(Text('\$${course['outstanding'].toStringAsFixed(2)}')),
              ]))
          .toList(),
    );
  }

  // Data generation methods
  List<Map<String, dynamic>> _getSalesReportData() {
    final now = DateTime.now();
    final startDate =
        selectedDateRange?.start ?? DateTime(now.year, now.month, 1);
    final endDate = selectedDateRange?.end ?? now;

    List<Map<String, dynamic>> salesData = [];

    final filteredPayments = billingController.payments.where((payment) {
      return payment.paymentDate.isAfter(startDate) &&
          payment.paymentDate.isBefore(endDate.add(Duration(days: 1)));
    }).toList();

    for (var payment in filteredPayments) {
      final invoice = billingController.invoices.firstWhere(
        (inv) => inv.id == payment.invoiceId,
      );

      if (invoice != null) {
        final student = userController.users.firstWhere(
          (user) => user.id == invoice.studentId,
        );

        final course = courseController.courses.firstWhere(
          (c) => c.id == invoice.courseId,
        );

        if (student != null && course != null) {
          salesData.add({
            'date': payment.paymentDate,
            'invoiceNumber': invoice.invoiceNumber,
            'customerName': '${student.fname} ${student.lname}',
            'courseName': course.name,
            'amount': payment.amount,
            'paymentMethod': payment.displayMethod,
            'reference': payment.reference ?? '-',
          });
        }
      }
    }

    salesData.sort((a, b) => b['date'].compareTo(a['date']));
    return salesData;
  }

  List<Payment> _getFilteredPayments() {
    final now = DateTime.now();
    final startDate =
        selectedDateRange?.start ?? DateTime(now.year, now.month, 1);
    final endDate = selectedDateRange?.end ?? now;

    return billingController.payments.where((payment) {
      return payment.paymentDate.isAfter(startDate) &&
          payment.paymentDate.isBefore(endDate.add(Duration(days: 1)));
    }).toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
  }

  List<dynamic> _getOutstandingInvoices() {
    return billingController.invoices.where((invoice) {
      return invoice.balance > 0;
    }).toList()
      ..sort((a, b) => a.dueDate?.compareTo(b.dueDate ?? DateTime.now()) ?? 0);
  }

  List<Map<String, dynamic>> _getCustomerStatementsData() {
    Map<int, Map<String, dynamic>> customerData = {};

    // Group data by customer
    for (var invoice in billingController.invoices) {
      if (!customerData.containsKey(invoice.studentId)) {
        final student = userController.users.firstWhere(
          (user) => user.id == invoice.studentId,
        );

        if (student != null) {
          customerData[invoice.studentId] = {
            'name': '${student.fname} ${student.lname}',
            'totalInvoiced': 0.0,
            'totalPaid': 0.0,
            'balance': 0.0,
            'lastPayment': null,
          };
        }
      }

      if (customerData.containsKey(invoice.studentId)) {
        customerData[invoice.studentId]!['totalInvoiced'] +=
            invoice.totalAmountCalculated;
        customerData[invoice.studentId]!['totalPaid'] += invoice.amountPaid;
        customerData[invoice.studentId]!['balance'] += invoice.balance;
      }
    }

    // Add last payment dates
    for (var payment in billingController.payments) {
      final invoice = billingController.invoices.firstWhere(
        (inv) => inv.id == payment.invoiceId,
      );

      if (invoice != null && customerData.containsKey(invoice.studentId)) {
        final currentLastPaymentDate =
            customerData[invoice.studentId]!['lastPaymentDate'] as DateTime?;

        if (currentLastPaymentDate == null ||
            payment.paymentDate.isAfter(currentLastPaymentDate)) {
          customerData[invoice.studentId]!['lastPaymentDate'] =
              payment.paymentDate;
          customerData[invoice.studentId]!['lastPayment'] =
              DateFormat('MM/dd/yyyy').format(payment.paymentDate);
        }
      }
    }

    // Add status
    customerData.forEach((customerId, data) {
      data['status'] = data['balance'] > 0 ? 'Outstanding' : 'Current';
    });

    return customerData.values.toList();
  }

  List<Map<String, dynamic>> _getDailySalesData() {
    final now = DateTime.now();
    final startDate =
        selectedDateRange?.start ?? DateTime(now.year, now.month, 1);
    final endDate = selectedDateRange?.end ?? now;

    Map<String, Map<String, dynamic>> dailyData = {};

    final filteredPayments = billingController.payments.where((payment) {
      return payment.paymentDate.isAfter(startDate) &&
          payment.paymentDate.isBefore(endDate.add(Duration(days: 1)));
    }).toList();

    for (var payment in filteredPayments) {
      final dateKey = DateFormat('yyyy-MM-dd').format(payment.paymentDate);

      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = {
          'date': payment.paymentDate,
          'transactions': 0,
          'totalSales': 0.0,
          'cash': 0.0,
          'mobile': 0.0,
        };
      }

      dailyData[dateKey]!['transactions'] += 1;
      dailyData[dateKey]!['totalSales'] += payment.amount;

      if (payment.method.toLowerCase() == 'cash') {
        dailyData[dateKey]!['cash'] += payment.amount;
      } else if (payment.method.toLowerCase().contains('mobile')) {
        dailyData[dateKey]!['mobile'] += payment.amount;
      }
    }

    return dailyData.values.toList()
      ..sort((a, b) => b['date'].compareTo(a['date']));
  }

  List<Map<String, dynamic>> _getCourseSalesData() {
    Map<int, Map<String, dynamic>> courseData = {};

    // Initialize course data
    for (var course in courseController.courses) {
      courseData[course.id!] = {
        'courseName': course.name,
        'studentCount': 0,
        'totalSales': 0.0,
        'outstanding': 0.0,
      };
    }

    // Process invoices to get course statistics
    for (var invoice in billingController.invoices) {
      if (courseData.containsKey(invoice.courseId)) {
        courseData[invoice.courseId]!['studentCount'] += 1;
        courseData[invoice.courseId]!['totalSales'] += invoice.amountPaid;
        courseData[invoice.courseId]!['outstanding'] += invoice.balance;
      }
    }

    // Calculate average per student
    courseData.forEach((courseId, data) {
      final studentCount = data['studentCount'] as int;
      data['avgPerStudent'] =
          studentCount > 0 ? data['totalSales'] / studentCount : 0.0;
    });

    return courseData.values.toList()
      ..sort((a, b) => b['totalSales'].compareTo(a['totalSales']));
  }

  List<Map<String, dynamic>> _getAllReports() {
    List<Map<String, dynamic>> allReports = [];
    reportCategories.values.forEach((reports) {
      allReports.addAll(reports);
    });
    return allReports;
  }

  Map<String, dynamic>? _getReportById(String id) {
    for (var reports in reportCategories.values) {
      for (var report in reports) {
        if (report['id'] == id) return report;
      }
    }
    return null;
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 30)),
            end: DateTime.now(),
          ),
    );

    if (picked != null && picked != selectedDateRange) {
      setState(() {
        selectedDateRange = picked;
      });
    }
  }

  void _generateReport(String type) async {
    if (selectedReportType.isEmpty) return;

    setState(() {
      isGenerating = true;
    });

    try {
      if (type == 'view') {
        await _showDetailedReportDialog();
      } else if (type == 'pdf') {
        await _generatePDFReport();
      }
    } catch (e) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Failed to generate report: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  Widget _buildFullReportData(String reportId) {
    switch (reportId) {
      case 'sales_report':
        return _buildFullSalesReport();
      case 'payment_register':
        return _buildFullPaymentRegister();
      case 'outstanding_payments':
        return _buildFullOutstandingPayments();
      case 'customer_statements':
        return _buildFullCustomerStatements();
      case 'daily_sales':
        return _buildFullDailySales();
      case 'course_sales':
        return _buildFullCourseSales();
      default:
        return Text('Full report data will be displayed here');
    }
  }

  Widget _buildFullSalesReport() {
    final salesData = _getSalesReportData();
    final totalAmount =
        salesData.fold(0.0, (sum, sale) => sum + sale['amount']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'Total Sales',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '\$${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    salesData.length.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Average Sale',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '\$${salesData.isNotEmpty ? (totalAmount / salesData.length).toStringAsFixed(2) : '0.00'}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Detailed Transactions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Invoice #')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Course')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Method')),
              DataColumn(label: Text('Reference')),
            ],
            rows: salesData
                .map((sale) => DataRow(cells: [
                      DataCell(Text(
                          DateFormat('MM/dd/yyyy HH:mm').format(sale['date']))),
                      DataCell(Text(sale['invoiceNumber'])),
                      DataCell(Text(sale['customerName'])),
                      DataCell(Text(sale['courseName'])),
                      DataCell(Text('\$${sale['amount'].toStringAsFixed(2)}')),
                      DataCell(Text(sale['paymentMethod'])),
                      DataCell(Text(sale['reference'])),
                    ]))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFullPaymentRegister() {
    final payments = _getFilteredPayments();
    final totalAmount =
        payments.fold(0.0, (sum, payment) => sum + payment.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Total Received',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('\$${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800)),
                ],
              ),
              Column(
                children: [
                  Text('Total Payments',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(payments.length.toString(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Text('Payment Register',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Receipt #')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Method')),
              DataColumn(label: Text('Reference')),
              DataColumn(label: Text('Notes')),
            ],
            rows: payments.map((payment) {
              final invoice = billingController.invoices
                  .firstWhere((inv) => inv.id == payment.invoiceId);
              final student = userController.users
                  .firstWhere((user) => user.id == invoice.studentId);

              return DataRow(cells: [
                DataCell(Text(DateFormat('MM/dd/yyyy HH:mm')
                    .format(payment.paymentDate))),
                DataCell(Text(payment.receiptNumber)),
                DataCell(Text('${student.fname} ${student.lname}')),
                DataCell(Text('\$${payment.amount.toStringAsFixed(2)}')),
                DataCell(Text(payment.displayMethod)),
                DataCell(Text(payment.reference ?? '-')),
                DataCell(Text(payment.notes ?? '-')),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFullOutstandingPayments() {
    final outstandingInvoices = _getOutstandingInvoices();
    final totalOutstanding =
        outstandingInvoices.fold(0.0, (sum, inv) => sum + inv.balance);
    final overdueCount = outstandingInvoices
        .where((inv) =>
            inv.dueDate != null && inv.dueDate!.isBefore(DateTime.now()))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Total Outstanding',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('\$${totalOutstanding.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800)),
                ],
              ),
              Column(
                children: [
                  Text('Outstanding Invoices',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(outstandingInvoices.length.toString(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800)),
                ],
              ),
              Column(
                children: [
                  Text('Overdue Invoices',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(overdueCount.toString(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Text('Outstanding Invoices Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Invoice #')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Course')),
              DataColumn(label: Text('Issue Date')),
              DataColumn(label: Text('Due Date')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Paid')),
              DataColumn(label: Text('Balance')),
              DataColumn(label: Text('Days Overdue')),
              DataColumn(label: Text('Status')),
            ],
            rows: outstandingInvoices.map((invoice) {
              final student = userController.users
                  .firstWhere((user) => user.id == invoice.studentId);
              final course = courseController.courses.firstWhere(
                (c) => c.id == invoice.courseId,
              );
              final daysOverdue = invoice.dueDate != null &&
                      invoice.dueDate!.isBefore(DateTime.now())
                  ? DateTime.now().difference(invoice.dueDate!).inDays
                  : 0;

              return DataRow(cells: [
                DataCell(Text(invoice.invoiceNumber)),
                DataCell(Text('${student.fname} ${student.lname}')),
                DataCell(Text(course?.name ?? 'Unknown Course')),
                DataCell(
                    Text(DateFormat('MM/dd/yyyy').format(invoice.createdAt))),
                DataCell(Text(invoice.dueDate != null
                    ? DateFormat('MM/dd/yyyy').format(invoice.dueDate!)
                    : '-')),
                DataCell(Text(
                    '\$${invoice.totalAmountCalculated.toStringAsFixed(2)}')),
                DataCell(Text('\$${invoice.amountPaid.toStringAsFixed(2)}')),
                DataCell(Text('\$${invoice.balance.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold))),
                DataCell(Text(daysOverdue > 0 ? daysOverdue.toString() : '-',
                    style: TextStyle(
                        color: daysOverdue > 0 ? Colors.red : Colors.grey))),
                DataCell(Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: daysOverdue > 0
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysOverdue > 0 ? 'OVERDUE' : 'OUTSTANDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: daysOverdue > 0
                          ? Colors.red.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                )),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFullCustomerStatements() {
    final customerData = _getCustomerStatementsData();
    final totalOutstanding =
        customerData.fold(0.0, (sum, customer) => sum + customer['balance']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Total Customers',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(customerData.length.toString(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800)),
                ],
              ),
              Column(
                children: [
                  Text('Total Outstanding',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('\$${totalOutstanding.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Text('Customer Account Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Total Invoiced')),
              DataColumn(label: Text('Total Paid')),
              DataColumn(label: Text('Balance')),
              DataColumn(label: Text('Last Payment')),
              DataColumn(label: Text('Status')),
            ],
            rows: customerData
                .map((customer) => DataRow(cells: [
                      DataCell(Text(customer['name'])),
                      DataCell(Text(
                          '\$${customer['totalInvoiced'].toStringAsFixed(2)}')),
                      DataCell(Text(
                          '\$${customer['totalPaid'].toStringAsFixed(2)}')),
                      DataCell(
                          Text('\$${customer['balance'].toStringAsFixed(2)}',
                              style: TextStyle(
                                color: customer['balance'] > 0
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ))),
                      DataCell(Text(customer['lastPayment'] ?? 'No payments')),
                      DataCell(Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: customer['status'] == 'Current'
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(customer['status'],
                            style: TextStyle(
                              color: customer['status'] == 'Current'
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            )),
                      )),
                    ]))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFullDailySales() {
    final dailySales = _getDailySalesData();
    final totalSales =
        dailySales.fold(0.0, (sum, day) => sum + day['totalSales']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Total Sales',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('\$${totalSales.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800)),
                ],
              ),
              Column(
                children: [
                  Text('Days Covered',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(dailySales.length.toString(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800)),
                ],
              ),
              Column(
                children: [
                  Text('Avg Daily Sales',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(
                      '\$${dailySales.isNotEmpty ? (totalSales / dailySales.length).toStringAsFixed(2) : '0.00'}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Text('Daily Sales Breakdown',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        DataTable(
          columns: [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Transactions')),
            DataColumn(label: Text('Total Sales')),
            DataColumn(label: Text('Cash')),
            DataColumn(label: Text('Mobile')),
            DataColumn(label: Text('Other')),
          ],
          rows: dailySales.map((day) {
            final otherAmount = day['totalSales'] - day['cash'] - day['mobile'];
            return DataRow(cells: [
              DataCell(
                  Text(DateFormat('EEE, MMM dd, yyyy').format(day['date']))),
              DataCell(Text(day['transactions'].toString())),
              DataCell(Text('\$${day['totalSales'].toStringAsFixed(2)}')),
              DataCell(Text('\$${day['cash'].toStringAsFixed(2)}')),
              DataCell(Text('\$${day['mobile'].toStringAsFixed(2)}')),
              DataCell(Text('\$${otherAmount.toStringAsFixed(2)}')),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFullCourseSales() {
    final courseSales = _getCourseSalesData();
    final totalSales =
        courseSales.fold(0.0, (sum, course) => sum + course['totalSales']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Total Course Sales',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('\$${totalSales.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800)),
                ],
              ),
              Column(
                children: [
                  Text('Active Courses',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(courseSales.length.toString(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Text('Course Sales Analysis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        DataTable(
          columns: [
            DataColumn(label: Text('Course')),
            DataColumn(label: Text('Students')),
            DataColumn(label: Text('Total Sales')),
            DataColumn(label: Text('Avg per Student')),
            DataColumn(label: Text('Outstanding')),
            DataColumn(label: Text('Collection Rate')),
          ],
          rows: courseSales.map((course) {
            final totalInvoiced = course['totalSales'] + course['outstanding'];
            final collectionRate = totalInvoiced > 0
                ? (course['totalSales'] / totalInvoiced * 100)
                : 0.0;

            return DataRow(cells: [
              DataCell(Text(course['courseName'])),
              DataCell(Text(course['studentCount'].toString())),
              DataCell(Text('\$${course['totalSales'].toStringAsFixed(2)}')),
              DataCell(Text('\$${course['avgPerStudent'].toStringAsFixed(2)}')),
              DataCell(Text('\$${course['outstanding'].toStringAsFixed(2)}',
                  style: TextStyle(
                      color: course['outstanding'] > 0
                          ? Colors.red
                          : Colors.green))),
              DataCell(Text('${collectionRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: collectionRate >= 80
                        ? Colors.green
                        : collectionRate >= 60
                            ? Colors.orange
                            : Colors.red,
                    fontWeight: FontWeight.bold,
                  ))),
            ]);
          }).toList(),
        ),
      ],
    );
  }

// Fixed _generatePDFReport method for mobile compatibility
  Future<void> _generatePDFReport() async {
    final report = _getReportById(selectedReportType);
    if (report == null) return;

    try {
      final pdf = pw.Document();

      // Add cover page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return _buildPDFContent(selectedReportType);
          },
        ),
      );

      // Generate the PDF bytes
      final pdfBytes = await pdf.save();

      // Save file with different approach for mobile vs desktop
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = '${selectedReportType}_report_$timestamp.pdf';

      // Check if running on mobile platform
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile approach - save to documents directory and optionally share
        final directory = await getApplicationDocumentsDirectory();
        final reportsDir = Directory('${directory.path}/reports');
        if (!await reportsDir.exists()) {
          await reportsDir.create(recursive: true);
        }

        final file = File('${reportsDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        // Show success message with file location
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Export Successful',
          '${report['title']} saved to: ${file.path}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
          mainButton: TextButton(
            onPressed: () {
              // You can add share functionality here if needed
              // Share.shareFiles([file.path], text: 'Report exported');
            },
            child: Text('Share', style: TextStyle(color: Colors.white)),
          ),
        );
      } else {
        // Desktop approach - use FilePicker.saveFile normally
        final String? filePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save ${report['title']}',
          fileName: fileName,
          allowedExtensions: ['pdf'],
        );

        if (filePath != null) {
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          Get.snackbar(
            snackPosition: SnackPosition.BOTTOM,
            'Export Successful',
            '${report['title']} exported to $filePath',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Export Failed',
        'Failed to export PDF: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

// Alternative method using FilePicker with bytes (if you prefer this approach)
  Future<void> _generatePDFReportAlternative() async {
    final report = _getReportById(selectedReportType);
    if (report == null) return;

    try {
      final pdf = pw.Document();

      // Add cover page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return _buildPDFContent(selectedReportType);
          },
        ),
      );

      // Generate the PDF bytes first
      final pdfBytes = await pdf.save();
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = '${selectedReportType}_report_$timestamp.pdf';

      // Use FilePicker with bytes parameter for mobile compatibility
      final String? result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save ${report['title']}',
        fileName: fileName,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes, // This is key for mobile compatibility
      );

      if (result != null) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Export Successful',
          '${report['title']} exported successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Export Failed',
        'Failed to export PDF: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  pw.Widget _buildPDFContent(String reportId) {
    final now = DateTime.now();
    final dateRange = selectedDateRange != null
        ? '${DateFormat('MMM dd, yyyy').format(selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(selectedDateRange!.end)}'
        : 'All Time';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Container(
          padding: pw.EdgeInsets.only(bottom: 20),
          decoration: pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue800, width: 3)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settingsController.businessName.value.isNotEmpty
                        ? settingsController.businessName.value
                        : 'Driving School',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    _getReportById(reportId)?['title'] ?? 'Financial Report',
                    style: pw.TextStyle(fontSize: 18, color: PdfColors.blue800),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                      'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(now)}'),
                  pw.Text('Period: $dateRange'),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Report content
        _buildPDFReportContent(reportId),
      ],
    );
  }

  pw.Widget _buildPDFReportContent(String reportId) {
    switch (reportId) {
      case 'sales_report':
        return _buildPDFSalesReport();
      case 'payment_register':
        return _buildPDFPaymentRegister();
      case 'outstanding_payments':
        return _buildPDFOutstandingPayments();
      case 'customer_statements':
        return _buildPDFCustomerStatements();
      case 'daily_sales':
        return _buildPDFDailySales();
      case 'course_sales':
        return _buildPDFCourseSales();
      default:
        return pw.Text('Report content will be displayed here');
    }
  }

  Widget _buildReportCategoriesView() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: reportCategories.length,
      itemBuilder: (context, index) {
        final category = reportCategories.keys.elementAt(index);
        final reports = reportCategories[category]!;

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 4,
          child: ExpansionTile(
            title: Text(
              category,
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            leading: Icon(
              Icons.folder,
              color: Colors.blue.shade800,
              size: isTablet ? 28 : 24,
            ),
            children:
                reports.map((report) => _buildReportTile(report)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildReportTile(Map<String, dynamic> report) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(isMobile ? 6 : 8),
        decoration: BoxDecoration(
          color: (report['color'] as Color).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          report['icon'],
          color: report['color'],
          size: isMobile ? 20 : 24,
        ),
      ),
      title: Text(
        report['title'],
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 14 : 16,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4),
          Text(
            report['description'],
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Document Report',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      onTap: () {
        setState(() {
          selectedReportType = report['id'];
        });
      },
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  Widget _buildSelectedReportView() {
    final report = _getReportById(selectedReportType);
    if (report == null) return Center(child: Text('Report not found'));

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportHeaderCard(report),
          SizedBox(height: 16),
          _buildDetailedReportPreview(report),
        ],
      ),
    );
  }

  Widget _buildReportHeaderCard(Map<String, dynamic> report) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile)
              _buildMobileReportHeader(report)
            else
              _buildDesktopReportHeader(report),
            if (selectedDateRange != null) ...[
              SizedBox(height: 16),
              _buildDateRangeDisplay(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileReportHeader(Map<String, dynamic> report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (report['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                report['icon'],
                color: report['color'],
                size: 28,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report['title'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          report['description'],
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopReportHeader(Map<String, dynamic> report) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (report['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            report['icon'],
            color: report['color'],
            size: 32,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report['title'],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                report['description'],
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeDisplay() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: Colors.blue.shade800),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Date Range: ${DateFormat('MMM dd, yyyy').format(selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(selectedDateRange!.end)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDataView(String reportId) {
    switch (reportId) {
      case 'sales_report':
        return _buildMobileSalesView();
      case 'payment_register':
        return _buildMobilePaymentView();
      case 'outstanding_payments':
        return _buildMobileOutstandingView();
      case 'customer_statements':
        return _buildMobileCustomerView();
      case 'daily_sales':
        return _buildMobileDailySalesView();
      case 'course_sales':
        return _buildMobileCourseSalesView();
      default:
        return Text('Mobile view for this report is being prepared...');
    }
  }

  Widget _buildPreviewNotice() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.amber.shade700),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This is a preview showing the first 10 records. Click "Export PDF" to generate the complete report with all data.',
              style: TextStyle(
                color: Colors.amber.shade800,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetailedReportDialog() async {
    final report = _getReportById(selectedReportType);
    if (report == null) return;

    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: isMobile
                ? MediaQuery.of(context).size.width * 0.95
                : MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        report['title'],
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isMobile)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _generatePDFReport();
                            },
                            icon: Icon(Icons.download),
                            label: Text('Export PDF'),
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isMobile) ...[
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _generatePDFReport();
                      },
                      icon: Icon(Icons.download),
                      label: Text('Export PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
                Divider(),
                if (selectedDateRange != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Period: ${DateFormat('MMM dd, yyyy').format(selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(selectedDateRange!.end)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildFullReportData(selectedReportType),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportSelector() {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: isDesktop
          ? _buildDesktopReportSelector()
          : _buildMobileReportSelector(),
    );
  }

  Widget _buildDesktopReportSelector() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: selectedReportType.isEmpty ? null : selectedReportType,
            hint: Text('Select Report Type'),
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true, // Fix dropdown overflow
            items: _getAllReports().map((report) {
              return DropdownMenuItem<String>(
                value: report['id'],
                child: Text(
                  report['title'],
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedReportType = value ?? '';
              });
            },
          ),
        ),
        SizedBox(width: 16),
        if (selectedReportType.isNotEmpty)
          Expanded(
            flex: 2,
            child: _buildActionButtons(),
          ),
      ],
    );
  }

  Widget _buildMobileReportSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: selectedReportType.isEmpty ? null : selectedReportType,
          hint: Text('Select Report Type'),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          isExpanded: true, // Fix dropdown overflow
          items: _getAllReports().map((report) {
            return DropdownMenuItem<String>(
              value: report['id'],
              child: Container(
                width: double.infinity,
                child: Text(
                  report['title'],
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedReportType = value ?? '';
            });
          },
        ),
        if (selectedReportType.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildActionButtons(),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isDesktop) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: isGenerating ? null : () => _generateReport('view'),
            icon: Icon(Icons.visibility, size: 16),
            label: Text('Preview'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          ElevatedButton.icon(
            onPressed: isGenerating ? null : () => _generateReport('pdf'),
            icon: isGenerating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.file_download, size: 16),
            label: Text(isGenerating ? 'Generating...' : 'Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      );
    }

    // Mobile view - only show Export PDF button
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Remove the Preview button for mobile
        ElevatedButton.icon(
          onPressed: isGenerating ? null : () => _generateReport('pdf'),
          icon: isGenerating
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(Icons.file_download),
          label: Text(isGenerating ? 'Generating PDF...' : 'Export PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSalesView() {
    final salesData = _getSalesReportData().take(10).toList();

    if (salesData.isEmpty) {
      return _buildEmptyStateCard(
          'No sales data found for the selected period.');
    }

    return Column(
      children: salesData
          .map((sale) => Card(
                margin: EdgeInsets.only(bottom: 8),
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              sale['invoiceNumber'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '\$${sale['amount'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        sale['customerName'],
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              sale['courseName'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormat('MM/dd/yyyy').format(sale['date']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sale['paymentMethod'],
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (sale['reference'] != '-')
                            Text(
                              'Ref: ${sale['reference']}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMobilePaymentView() {
    final payments = _getFilteredPayments().take(10).toList();

    if (payments.isEmpty) {
      return _buildEmptyStateCard('No payments found for the selected period.');
    }

    return Column(
      children: payments.map((payment) {
        final invoice = billingController.invoices
            .firstWhere((inv) => inv.id == payment.invoiceId);
        final student = userController.users
            .firstWhere((user) => user.id == invoice.studentId);

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        payment.receiptNumber ?? 'N/A',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${payment.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '${student.fname} ${student.lname}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        payment.displayMethod,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('MM/dd/yyyy').format(payment.paymentDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (payment.reference != null &&
                    payment.reference!.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    'Ref: ${payment.reference}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileOutstandingView() {
    final outstandingInvoices = _getOutstandingInvoices().take(10).toList();

    if (outstandingInvoices.isEmpty) {
      return _buildEmptyStateCard('No outstanding payments found.');
    }

    return Column(
      children: outstandingInvoices.map((invoice) {
        final student = userController.users
            .firstWhere((user) => user.id == invoice.studentId);
        final daysOverdue =
            invoice.dueDate != null && invoice.dueDate!.isBefore(DateTime.now())
                ? DateTime.now().difference(invoice.dueDate!).inDays
                : 0;

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        invoice.invoiceNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${invoice.balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '${student.fname} ${student.lname}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Total: \$${invoice.totalAmountCalculated.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Paid: \$${invoice.amountPaid.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (daysOverdue > 0) ...[
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$daysOverdue days overdue',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileCustomerView() {
    final customerData = _getCustomerStatementsData().take(10).toList();

    if (customerData.isEmpty) {
      return _buildEmptyStateCard('No customer data found.');
    }

    return Column(
      children: customerData
          .map((customer) => Card(
                margin: EdgeInsets.only(bottom: 8),
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              customer['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: customer['status'] == 'Current'
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              customer['status'],
                              style: TextStyle(
                                fontSize: 10,
                                color: customer['status'] == 'Current'
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Invoiced: \$${customer['totalInvoiced'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Paid: \$${customer['totalPaid'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Balance: \$${customer['balance'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: customer['balance'] > 0
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (customer['lastPayment'] != null)
                            Expanded(
                              child: Text(
                                'Last: ${customer['lastPayment']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMobileDailySalesView() {
    final dailySales = _getDailySalesData().take(10).toList();

    if (dailySales.isEmpty) {
      return _buildEmptyStateCard(
          'No daily sales data found for the selected period.');
    }

    return Column(
      children: dailySales
          .map((day) => Card(
                margin: EdgeInsets.only(bottom: 8),
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('MMM dd, yyyy').format(day['date']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '\$${day['totalSales'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${day['transactions']} transactions',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Cash: \$${day['cash'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Mobile: \$${day['mobile'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMobileCourseSalesView() {
    final courseSales = _getCourseSalesData().take(10).toList();

    if (courseSales.isEmpty) {
      return _buildEmptyStateCard('No course sales data found.');
    }

    return Column(
      children: courseSales
          .map((course) => Card(
                margin: EdgeInsets.only(bottom: 8),
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              course['courseName'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '\$${course['totalSales'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${course['studentCount']} students',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Avg: \$${course['avgPerStudent'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Outstanding: \$${course['outstanding'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: course['outstanding'] > 0
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildEmptyStateCard(String message) {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedReportPreview(Map<String, dynamic> report) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Preview (First 10 Records)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            // Use the new responsive preview container instead
            _buildResponsivePreviewContainer(report['id']),
            SizedBox(height: 16),
            _buildPreviewNotice(),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsivePreviewContainer(String reportId) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;

    // Always use mobile view for mobile devices
    if (isMobile) {
      return _buildMobileDataView(reportId);
    }

    // For tablet and desktop, use constrained scrollable table
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: screenWidth - 64, // Account for card padding
        maxHeight: 400, // Set maximum height for preview
      ),
      child: isTablet
          ? _buildTabletPreviewTable(reportId)
          : _buildDesktopPreviewTable(reportId),
    );
  }

  Widget _buildTabletPreviewTable(String reportId) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 64,
          ),
          child: _buildCompactDataTable(reportId),
        ),
      ),
    );
  }

  Widget _buildDesktopPreviewTable(String reportId) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 64,
          ),
          child: _buildReportDataTable(reportId),
        ),
      ),
    );
  }

  Widget _buildCompactDataTable(String reportId) {
    // Compact version of data tables for tablet view
    switch (reportId) {
      case 'sales_report':
        return _buildCompactSalesTable();
      case 'payment_register':
        return _buildCompactPaymentTable();
      case 'outstanding_payments':
        return _buildCompactOutstandingTable();
      case 'customer_statements':
        return _buildCompactCustomerTable();
      case 'daily_sales':
        return _buildCompactDailySalesTable();
      case 'course_sales':
        return _buildCompactCourseSalesTable();
      default:
        return Text('Preview data will be displayed here');
    }
  }

  Widget _buildCompactSalesTable() {
    final salesData = _getSalesReportData().take(10).toList();

    if (salesData.isEmpty) {
      return _buildEmptyStateCard(
          'No sales data found for the selected period.');
    }

    return DataTable(
      columnSpacing: 8,
      headingRowHeight: 40,
      dataRowHeight: 36,
      columns: [
        DataColumn(
          label: Expanded(
            child: Text('Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Invoice',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Amount',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
      rows: salesData
          .map((sale) => DataRow(
                cells: [
                  DataCell(
                    Container(
                      constraints: BoxConstraints(maxWidth: 80),
                      child: Text(
                        DateFormat('MM/dd').format(sale['date']),
                        style: TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      constraints: BoxConstraints(maxWidth: 80),
                      child: Text(
                        sale['invoiceNumber'],
                        style: TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      constraints: BoxConstraints(maxWidth: 100),
                      child: Text(
                        sale['customerName'],
                        style: TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '\$${sale['amount'].toStringAsFixed(2)}',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildCompactPaymentTable() {
    final payments = _getFilteredPayments().take(10).toList();

    if (payments.isEmpty) {
      return _buildEmptyStateCard('No payments found for the selected period.');
    }

    return DataTable(
      columnSpacing: 8,
      headingRowHeight: 40,
      dataRowHeight: 36,
      columns: [
        DataColumn(
          label: Expanded(
            child: Text('Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Receipt',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Amount',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
      rows: payments.map((payment) {
        final invoice = billingController.invoices
            .firstWhere((inv) => inv.id == payment.invoiceId);
        final student = userController.users
            .firstWhere((user) => user.id == invoice.studentId);

        return DataRow(
          cells: [
            DataCell(
              Container(
                constraints: BoxConstraints(maxWidth: 80),
                child: Text(
                  DateFormat('MM/dd').format(payment.paymentDate),
                  style: TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              Container(
                constraints: BoxConstraints(maxWidth: 80),
                child: Text(
                  payment.receiptNumber ?? 'N/A',
                  style: TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              Container(
                constraints: BoxConstraints(maxWidth: 100),
                child: Text(
                  '${student.fname} ${student.lname}',
                  style: TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              Text(
                '\$${payment.amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCompactOutstandingTable() {
    final outstandingInvoices = _getOutstandingInvoices().take(10).toList();

    if (outstandingInvoices.isEmpty) {
      return _buildEmptyStateCard('No outstanding payments found.');
    }

    return DataTable(
      columnSpacing: 8,
      headingRowHeight: 40,
      dataRowHeight: 36,
      columns: [
        DataColumn(
          label: Expanded(
            child: Text('Invoice',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Balance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
      rows: outstandingInvoices.map((invoice) {
        final student = userController.users
            .firstWhere((user) => user.id == invoice.studentId);
        final daysOverdue =
            invoice.dueDate != null && invoice.dueDate!.isBefore(DateTime.now())
                ? DateTime.now().difference(invoice.dueDate!).inDays
                : 0;

        return DataRow(
          cells: [
            DataCell(
              Container(
                constraints: BoxConstraints(maxWidth: 80),
                child: Text(
                  invoice.invoiceNumber,
                  style: TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              Container(
                constraints: BoxConstraints(maxWidth: 100),
                child: Text(
                  '${student.fname} ${student.lname}',
                  style: TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              Text(
                '\$${invoice.balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
            ),
            DataCell(
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: daysOverdue > 0
                      ? Colors.red.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  daysOverdue > 0 ? 'OVERDUE' : 'DUE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: daysOverdue > 0
                        ? Colors.red.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCompactCustomerTable() {
    final customerData = _getCustomerStatementsData().take(10).toList();

    if (customerData.isEmpty) {
      return _buildEmptyStateCard('No customer data found.');
    }

    return DataTable(
      columnSpacing: 8,
      headingRowHeight: 40,
      dataRowHeight: 36,
      columns: [
        DataColumn(
          label: Expanded(
            child: Text('Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Invoiced',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Balance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
      rows: customerData
          .map((customer) => DataRow(
                cells: [
                  DataCell(
                    Container(
                      constraints: BoxConstraints(maxWidth: 100),
                      child: Text(
                        customer['name'],
                        style: TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '\$${customer['totalInvoiced'].toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  DataCell(
                    Text(
                      '\$${customer['balance'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color:
                            customer['balance'] > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: customer['status'] == 'Current'
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        customer['status'],
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: customer['status'] == 'Current'
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildCompactDailySalesTable() {
    final dailySales = _getDailySalesData().take(10).toList();

    if (dailySales.isEmpty) {
      return _buildEmptyStateCard(
          'No daily sales data found for the selected period.');
    }

    return DataTable(
      columnSpacing: 8,
      headingRowHeight: 40,
      dataRowHeight: 36,
      columns: [
        DataColumn(
          label: Expanded(
            child: Text('Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Sales',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Trans.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Cash',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
      rows: dailySales
          .map((day) => DataRow(
                cells: [
                  DataCell(
                    Container(
                      constraints: BoxConstraints(maxWidth: 80),
                      child: Text(
                        DateFormat('MM/dd').format(day['date']),
                        style: TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '\$${day['totalSales'].toStringAsFixed(0)}',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  DataCell(
                    Text(
                      day['transactions'].toString(),
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  DataCell(
                    Text(
                      '\$${day['cash'].toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildCompactCourseSalesTable() {
    final courseSales = _getCourseSalesData().take(10).toList();

    if (courseSales.isEmpty) {
      return _buildEmptyStateCard('No course sales data found.');
    }

    return DataTable(
      columnSpacing: 8,
      headingRowHeight: 40,
      dataRowHeight: 36,
      columns: [
        DataColumn(
          label: Expanded(
            child: Text('Course',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Students',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Sales',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text('Outstanding',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
      rows: courseSales
          .map((course) => DataRow(
                cells: [
                  DataCell(
                    Container(
                      constraints: BoxConstraints(maxWidth: 100),
                      child: Text(
                        course['courseName'],
                        style: TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      course['studentCount'].toString(),
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  DataCell(
                    Text(
                      '\$${course['totalSales'].toStringAsFixed(0)}',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  DataCell(
                    Text(
                      '\$${course['outstanding'].toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: course['outstanding'] > 0
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }

  // Update the existing _buildResponsiveDataTable method to only be used in dialog view
  Widget _buildResponsiveDataTable(String reportId) {
    // This method is now only used in the detailed dialog view
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return _buildMobileDataView(reportId);
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: _buildReportDataTable(reportId),
        ),
      );
    }
  }
}
