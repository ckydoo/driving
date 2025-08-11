// import 'dart:io';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
// import 'package:intl/intl.dart';
// import 'package:csv/csv.dart';
// import 'package:get/get.dart';
// import '../models/payment.dart';
// import '../models/invoice.dart';
// import '../models/user.dart';
// import '../controllers/settings_controller.dart';

// class EnhancedStatementExportService {
  
//   // Generate comprehensive student statement with full business branding
//   static Future<String> generateStudentStatement(
//     User student,
//     List<Invoice> invoices,
//     List<Payment> payments,
//   ) async {
//     final settingsController = Get.find<SettingsController>();
//     final pdf = pw.Document();

//     // Calculate comprehensive summary
//     double totalAmount = 0;
//     double totalPaid = 0;
//     double totalBalance = 0;
//     int totalLessons = 0;
//     int overdueCount = 0;
//     DateTime? oldestInvoice;
//     DateTime? newestInvoice;
//     DateTime? lastPaymentDate;

//     for (var invoice in invoices) {
//       totalAmount += invoice.totalAmountCalculated;
//       totalPaid += invoice.amountPaid;
//       totalBalance += invoice.balance;
//       totalLessons += invoice.lessons;
      
//       if (invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now())) {
//         overdueCount++;
//       }
      
//       if (oldestInvoice == null || invoice.createdAt.isBefore(oldestInvoice)) {
//         oldestInvoice = invoice.createdAt;
//       }
      
//       if (newestInvoice == null || invoice.createdAt.isAfter(newestInvoice)) {
//         newestInvoice = invoice.createdAt;
//       }
//     }

//     // Find last payment date
//     for (var payment in payments) {
//       if (lastPaymentDate == null || payment.paymentDate.isAfter(lastPaymentDate)) {
//         lastPaymentDate = payment.paymentDate;
//       }
//     }

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(24),
//         header: (context) => _buildStatementHeader(settingsController),
//         build: (pw.Context context) {
//           return [
//             pw.SizedBox(height: 20),
            
//             // Statement Title and Period
//             _buildStatementTitle(student, oldestInvoice, newestInvoice),
            
//             pw.SizedBox(height: 24),
            
//             // Account Summary Section
//             _buildAccountSummary(
//               totalAmount, totalPaid, totalBalance, 
//               totalLessons, overdueCount, lastPaymentDate
//             ),
            
//             pw.SizedBox(height: 24),
            
//             // Invoices Table
//             _buildInvoicesTable(invoices),
            
//             pw.SizedBox(height: 20),
            
//             // Payments History
//             if (payments.isNotEmpty) ...[
//               _buildPaymentsTable(payments),
//               pw.SizedBox(height: 20),
//             ],
            
//             // Account Status and Next Steps
//             _buildAccountStatus(totalBalance, overdueCount),
            
//             pw.SizedBox(height: 20),
            
//             // Business Contact Information
//             _buildBusinessContactSection(settingsController),
//           ];
//         },
//         footer: (context) => _buildStatementFooter(settingsController),
//       ),
//     );

//     return await _saveStatementPdf(pdf, student, 'statement');
//   }

//   // Generate enhanced invoice export PDF with business branding
//   static Future<String> generateInvoicesExportPDF(
//     List<Invoice> invoices,
//     List<Payment> payments,
//     List<User> students,
//     {String? studentName, String? exportType = 'invoices'}
//   ) async {
//     final settingsController = Get.find<SettingsController>();
//     final pdf = pw.Document();

//     // Calculate summary statistics
//     double totalAmount = 0;
//     double totalPaid = 0;
//     double totalBalance = 0;
//     int overdueCount = 0;
//     Map<String, int> statusCounts = {};
//     Map<int, String> courseNames = {};

//     for (var invoice in invoices) {
//       totalAmount += invoice.totalAmountCalculated;
//       totalPaid += invoice.amountPaid;
//       totalBalance += invoice.balance;
      
//       if (invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now())) {
//         overdueCount++;
//       }
      
//       statusCounts[invoice.status] = (statusCounts[invoice.status] ?? 0) + 1;
//     }

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(20),
//         header: (context) => _buildExportHeader(settingsController, exportType),
//         build: (pw.Context context) {
//           return [
//             pw.SizedBox(height: 20),
            
//             // Export Summary
//             _buildExportSummary(
//               invoices.length, totalAmount, totalPaid, 
//               totalBalance, overdueCount, statusCounts, studentName
//             ),
            
//             pw.SizedBox(height: 24),
            
//             // Detailed Invoices Table
//             _buildDetailedInvoicesTable(invoices, students, payments),
            
//             pw.SizedBox(height: 20),
            
//             // Statistics and Analysis
//             _buildInvoiceAnalytics(invoices, statusCounts),
//           ];
//         },
//         footer: (context) => _buildExportFooter(settingsController),
//       ),
//     );

//     return await _saveStatementPdf(pdf, null, exportType, customName: studentName);
//   }

//   // Enhanced CSV export with business information header
//   static Future<String> generateEnhancedCSVExport(
//     List<Invoice> invoices,
//     List<Payment> payments,
//     List<User> students,
//     {String? exportType = 'invoices', String? studentName}
//   ) async {
//     final settingsController = Get.find<SettingsController>();
    
//     // Build comprehensive CSV data
//     List<List<dynamic>> csvData = [];
    
//     // Business Information Header
//     csvData.addAll([
//       ['Business Information'],
//       ['Business Name', settingsController.businessName.value],
//       ['Address', '${settingsController.businessAddress.value}, ${settingsController.businessCity.value}, ${settingsController.businessCountry.value}'],
//       ['Phone', settingsController.businessPhone.value],
//       ['Email', settingsController.businessEmail.value],
//       ['Website', settingsController.businessWebsite.value],
//       ['Business Hours', '${settingsController.businessStartTime.value} - ${settingsController.businessEndTime.value}'],
//       ['Operating Days', settingsController.operatingDays.join(', ')],
//       [],
//       ['Export Information'],
//       ['Export Type', exportType?.toUpperCase() ?? 'INVOICES'],
//       ['Export Date', DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now())],
//       ['Total Records', invoices.length.toString()],
//       if (studentName != null) ['Student', studentName],
//       [],
//     ]);
    
//     // Column Headers
//     csvData.add([
//       'Invoice Number',
//       'Student Name',
//       'Student Email',
//       'Student Phone',
//       'Course Name',
//       'Date Created',
//       'Due Date',
//       'Lessons',
//       'Price Per Lesson',
//       'Total Amount',
//       'Amount Paid',
//       'Balance',
//       'Status',
//       'Days Overdue',
//       'Payment Count',
//       'Last Payment Date',
//       'Last Payment Amount',
//       'Completion %'
//     ]);

//     // Invoice data with enhanced information
//     for (var invoice in invoices) {
//       try {
//         final student = students.firstWhere((s) => s.id == invoice.studentId);
//         final invoicePayments = payments.where((p) => p.invoiceId == invoice.id).toList();
        
//         final daysOverdue = invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now())
//             ? DateTime.now().difference(invoice.dueDate).inDays
//             : 0;
            
//         final lastPayment = invoicePayments.isNotEmpty 
//             ? invoicePayments.reduce((a, b) => a.paymentDate.isAfter(b.paymentDate) ? a : b)
//             : null;
            
//         final completionPercentage = invoice.totalAmountCalculated > 0 
//             ? (invoice.amountPaid / invoice.totalAmountCalculated * 100)
//             : 0.0;

//         csvData.add([
//           invoice.invoiceNumber,
//           '${student.fname} ${student.lname}',
//           student.email,
//           student.phone,
//           'Course ${invoice.courseId}', // You can enhance this with actual course names
//           DateFormat('yyyy-MM-dd').format(invoice.createdAt),
//           DateFormat('yyyy-MM-dd').format(invoice.dueDate),
//           invoice.lessons,
//           invoice.pricePerLesson.toStringAsFixed(2),
//           invoice.totalAmountCalculated.toStringAsFixed(2),
//           invoice.amountPaid.toStringAsFixed(2),
//           invoice.balance.toStringAsFixed(2),
//           invoice.status,
//           daysOverdue,
//           invoicePayments.length,
//           lastPayment != null ? DateFormat('yyyy-MM-dd').format(lastPayment.paymentDate) : '',
//           lastPayment?.amount.toStringAsFixed(2) ?? '',
//           completionPercentage.toStringAsFixed(1)
//         ]);
//       } catch (e) {
//         print('Error processing invoice ${invoice.id}: $e');
//       }
//     }

//     // Summary section
//     final totalAmount = invoices.fold(0.0, (sum, inv) => sum + inv.totalAmountCalculated);
//     final totalPaid = invoices.fold(0.0, (sum, inv) => sum + inv.amountPaid);
//     final totalBalance = invoices.fold(0.0, (sum, inv) => sum + inv.balance);
//     final overdueCount = invoices.where((inv) => 
//         inv.balance > 0 && inv.dueDate.isBefore(DateTime.now())).length;

//     csvData.addAll([
//       [],
//       ['Summary Information'],
//       ['Total Invoices', invoices.length.toString()],
//       ['Total Amount', totalAmount.toStringAsFixed(2)],
//       ['Total Paid', totalPaid.toStringAsFixed(2)],
//       ['Total Outstanding', totalBalance.toStringAsFixed(2)],
//       ['Overdue Invoices', overdueCount.toString()],
//       ['Export Generated By', settingsController.businessName.value],
//     ]);

//     // Convert to CSV string
//     String csvString = const ListToCsvConverter().convert(csvData);

//     // Save file
//     return await _saveCSVFile(csvString, exportType, studentName);
//   }

//   // Generate billing report with comprehensive business header
//   static Future<String> generateBillingReportPDF(
//     List<Invoice> invoices,
//     List<Payment> payments,
//     List<User> students,
//     {DateTime? startDate, DateTime? endDate, String? status}
//   ) async {
//     final settingsController = Get.find<SettingsController>();
//     final pdf = pw.Document();

//     // Filter by date range if provided
//     final filteredInvoices = invoices.where((invoice) {
//       bool matchesDate = true;
//       if (startDate != null) {
//         matchesDate = matchesDate && invoice.createdAt.isAfter(startDate);
//       }
//       if (endDate != null) {
//         matchesDate = matchesDate && invoice.createdAt.isBefore(endDate.add(Duration(days: 1)));
//       }
//       if (status != null) {
//         matchesDate = matchesDate && invoice.status == status;
//       }
//       return matchesDate;
//     }).toList();

//     // Calculate comprehensive statistics
//     final analytics = _calculateBillingAnalytics(filteredInvoices, payments);

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(20),
//         header: (context) => _buildReportHeader(settingsController, 'Billing Report'),
//         build: (pw.Context context) {
//           return [
//             pw.SizedBox(height: 20),
            
//             // Report Parameters
//             _buildReportParameters(startDate, endDate, status, filteredInvoices.length),
            
//             pw.SizedBox(height: 20),
            
//             // Executive Summary
//             _buildExecutiveSummary(analytics),
            
//             pw.SizedBox(height: 20),
            
//             // Detailed Analytics
//             _buildDetailedAnalytics(analytics),
            
//             pw.SizedBox(height: 20),
            
//             // Detailed Invoice List
//             _buildBillingReportTable(filteredInvoices, students, payments),
//           ];
//         },
//         footer: (context) => _buildReportFooter(settingsController),
//       ),
//     );

//     return await _saveStatementPdf(pdf, null, 'billing_report');
//   }

//   // Private helper methods

//   static pw.Widget _buildStatementHeader(SettingsController settings) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.only(bottom: 20),
//       decoration: const pw.BoxDecoration(
//         border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 2)),
//       ),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text(
//                 settings.businessName.value.isNotEmpty 
//                   ? settings.businessName.value 
//                   : 'Driving School',
//                 style: pw.TextStyle(
//                   fontSize: 24,
//                   fontWeight: pw.FontWeight.bold,
//                   color: PdfColors.blue800,
//                 ),
//               ),
//               if (settings.businessAddress.value.isNotEmpty) ...[
//                 pw.Text(
//                   settings.businessAddress.value,
//                   style: const pw.TextStyle(fontSize: 12),
//                 ),
//               ],
//               if (settings.businessCity.value.isNotEmpty) ...[
//                 pw.Text(
//                   '${settings.businessCity.value}, ${settings.businessCountry.value}',
//                   style: const pw.TextStyle(fontSize: 12),
//                 ),
//               ],
//             ],
//           ),
//           pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.end,
//             children: [
//               if (settings.businessPhone.value.isNotEmpty) ...[
//                 pw.Text('Phone: ${settings.businessPhone.value}'),
//               ],
//               if (settings.businessEmail.value.isNotEmpty) ...[
//                 pw.Text('Email: ${settings.businessEmail.value}'),
//               ],
//               if (settings.businessWebsite.value.isNotEmpty) ...[
//                 pw.Text('Web: ${settings.businessWebsite.value}'),
//               ],
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildStatementTitle(User student, DateTime? oldestInvoice, DateTime? newestInvoice) {
//     return pw.Container(
//       width: double.infinity,
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: PdfColors.blue50,
//         borderRadius: pw.BorderRadius.circular(8),
//         border: pw.Border.all(color: PdfColors.blue200),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             'ACCOUNT STATEMENT',
//             style: pw.TextStyle(
//               fontSize: 20,
//               fontWeight: pw.FontWeight.bold,
//               color: PdfColors.blue800,
//             ),
//           ),
//           pw.SizedBox(height: 8),
//           pw.Text(
//             'Student: ${student.fname} ${student.lname}',
//             style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//           ),
//           pw.Text('Email: ${student.email}', style: const pw.TextStyle(fontSize: 12)),
//           pw.Text('Phone: ${student.phone}', style: const pw.TextStyle(fontSize: 12)),
//           if (oldestInvoice != null && newestInvoice != null) ...[
//             pw.SizedBox(height: 8),
//             pw.Text(
//               'Statement Period: ${DateFormat('MMM dd, yyyy').format(oldestInvoice)} - ${DateFormat('MMM dd, yyyy').format(newestInvoice)}',
//               style: const pw.TextStyle(fontSize: 11),
//             ),
//           ],
//           pw.Text(
//             'Generated: ${DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now())}',
//             style: const pw.TextStyle(fontSize: 11),
//           ),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildAccountSummary(
//     double totalAmount, double totalPaid, double totalBalance,
//     int totalLessons, int overdueCount, DateTime? lastPaymentDate
//   ) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         border: pw.Border.all(color: PdfColors.grey300),
//         borderRadius: pw.BorderRadius.circular(8),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             'ACCOUNT SUMMARY',
//             style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
//           ),
//           pw.SizedBox(height: 12),
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Text('Total Billed:', style: const pw.TextStyle(fontSize: 12)),
//                   pw.Text('Total Paid:', style: const pw.TextStyle(fontSize: 12)),
//                   pw.Text('Current Balance:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
//                   pw.Text('Total Lessons:', style: const pw.TextStyle(fontSize: 12)),
//                 ],
//               ),
//                               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.end,
//                 children: [
//                   pw.Text(DateFormat('MMMM dd, yyyy').format(DateTime.now())),
//                   if (settings.businessPhone.value.isNotEmpty)
//                     pw.Text(settings.businessPhone.value),
//                 ],
//               ),
//             ],
//           ),
//           pw.Divider(),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildExportSummary(
//     int totalInvoices, double totalAmount, double totalPaid,
//     double totalBalance, int overdueCount, Map<String, int> statusCounts, String? studentName
//   ) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: PdfColors.blue50,
//         borderRadius: pw.BorderRadius.circular(8),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             'EXPORT SUMMARY',
//             style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
//           ),
//           pw.SizedBox(height: 12),
//           if (studentName != null) ...[
//             pw.Text('Student: $studentName', style: const pw.TextStyle(fontSize: 12)),
//             pw.SizedBox(height: 4),
//           ],
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Text('Total Invoices: $totalInvoices'),
//                   pw.Text('Total Amount: \${totalAmount.toStringAsFixed(2)}'),
//                   pw.Text('Total Paid: \${totalPaid.toStringAsFixed(2)}'),
//                   pw.Text('Outstanding: \${totalBalance.toStringAsFixed(2)}'),
//                 ],
//               ),
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Text('Overdue: $overdueCount'),
//                   ...statusCounts.entries.map((entry) =>
//                     pw.Text('${entry.key}: ${entry.value}')
//                   ).toList(),
//                 ],
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildDetailedInvoicesTable(
//     List<Invoice> invoices, List<User> students, List<Payment> payments
//   ) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Text(
//           'DETAILED INVOICE LIST',
//           style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//         ),
//         pw.SizedBox(height: 8),
//         pw.Table(
//           border: pw.TableBorder.all(color: PdfColors.grey300),
//           columnWidths: {
//             0: const pw.FlexColumnWidth(1.5),
//             1: const pw.FlexColumnWidth(2),
//             2: const pw.FlexColumnWidth(1),
//             3: const pw.FlexColumnWidth(1),
//             4: const pw.FlexColumnWidth(1),
//             5: const pw.FlexColumnWidth(1),
//             6: const pw.FlexColumnWidth(1),
//           },
//           children: [
//             // Header
//             pw.TableRow(
//               decoration: const pw.BoxDecoration(color: PdfColors.grey100),
//               children: [
//                 _buildTableCell('Invoice #', isHeader: true),
//                 _buildTableCell('Student', isHeader: true),
//                 _buildTableCell('Date', isHeader: true),
//                 _buildTableCell('Lessons', isHeader: true),
//                 _buildTableCell('Amount', isHeader: true),
//                 _buildTableCell('Paid', isHeader: true),
//                 _buildTableCell('Balance', isHeader: true),
//               ],
//             ),
//             // Data rows
//             ...invoices.map((invoice) {
//               final student = students.firstWhere(
//                 (s) => s.id == invoice.studentId,
//                 orElse: () => User(id: 0, fname: 'Unknown', lname: 'Student', email: '', phone: '', address: '', role: 'student'),
//               );
              
//               return pw.TableRow(
//                 children: [
//                   _buildTableCell(invoice.invoiceNumber),
//                   _buildTableCell('${student.fname} ${student.lname}'),
//                   _buildTableCell(DateFormat('MM/dd/yy').format(invoice.createdAt)),
//                   _buildTableCell(invoice.lessons.toString()),
//                   _buildTableCell('\${invoice.totalAmountCalculated.toStringAsFixed(2)}'),
//                   _buildTableCell('\${invoice.amountPaid.toStringAsFixed(2)}'),
//                   _buildTableCell(
//                     '\${invoice.balance.toStringAsFixed(2)}',
//                     textColor: invoice.balance > 0 ? PdfColors.red : PdfColors.green,
//                   ),
//                 ],
//               );
//             }).toList(),
//           ],
//         ),
//       ],
//     );
//   }

//   static pw.Widget _buildInvoiceAnalytics(List<Invoice> invoices, Map<String, int> statusCounts) {
//     final averageAmount = invoices.isNotEmpty 
//         ? invoices.fold(0.0, (sum, inv) => sum + inv.totalAmountCalculated) / invoices.length
//         : 0.0;
    
//     final averageLessons = invoices.isNotEmpty
//         ? invoices.fold(0, (sum, inv) => sum + inv.lessons) / invoices.length
//         : 0.0;

//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         border: pw.Border.all(color: PdfColors.grey300),
//         borderRadius: pw.BorderRadius.circular(8),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             'ANALYTICS',
//             style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//           ),
//           pw.SizedBox(height: 8),
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Text('Average Invoice: \${averageAmount.toStringAsFixed(2)}'),
//                   pw.Text('Average Lessons: ${averageLessons.toStringAsFixed(1)}'),
//                 ],
//               ),
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Text('Status Distribution:'),
//                   ...statusCounts.entries.map((entry) =>
//                     pw.Text('${entry.key}: ${entry.value} (${(entry.value / invoices.length * 100).toStringAsFixed(1)}%)')
//                   ).toList(),
//                 ],
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildExportFooter(SettingsController settings) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.only(top: 10),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           pw.Text(
//             'Generated by ${settings.businessName.value}',
//             style: const pw.TextStyle(fontSize: 10),
//           ),
//           pw.Text(
//             'Confidential Business Information',
//             style: const pw.TextStyle(fontSize: 10),
//           ),
//         ],
//       ),
//     );
//   }

//   // Billing Report specific methods
//   static pw.Widget _buildReportHeader(SettingsController settings, String reportType) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.only(bottom: 20),
//       decoration: const pw.BoxDecoration(
//         border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 3)),
//       ),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text(
//                 settings.businessName.value,
//                 style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
//               ),
//               pw.Text(
//                 reportType.toUpperCase(),
//                 style: pw.TextStyle(fontSize: 18, color: PdfColors.blue800),
//               ),
//             ],
//           ),
//           pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.end,
//             children: [
//               pw.Text('Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}'),
//               if (settings.businessPhone.value.isNotEmpty)
//                 pw.Text('Phone: ${settings.businessPhone.value}'),
//               if (settings.businessEmail.value.isNotEmpty)
//                 pw.Text('Email: ${settings.businessEmail.value}'),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildReportParameters(
//     DateTime? startDate, DateTime? endDate, String? status, int recordCount
//   ) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(12),
//       decoration: pw.BoxDecoration(
//         color: PdfColors.grey100,
//         borderRadius: pw.BorderRadius.circular(6),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text('REPORT PARAMETERS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//           pw.SizedBox(height: 4),
//           if (startDate != null)
//             pw.Text('Start Date: ${DateFormat('MMM dd, yyyy').format(startDate)}'),
//           if (endDate != null)
//             pw.Text('End Date: ${DateFormat('MMM dd, yyyy').format(endDate)}'),
//           if (status != null)
//             pw.Text('Status Filter: $status'),
//           pw.Text('Total Records: $recordCount'),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildExecutiveSummary(Map<String, dynamic> analytics) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: PdfColors.blue50,
//         borderRadius: pw.BorderRadius.circular(8),
//         border: pw.Border.all(color: PdfColors.blue200),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             'EXECUTIVE SUMMARY',
//             style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
//           ),
//           pw.SizedBox(height: 12),
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Text('Total Revenue: \${analytics['totalRevenue'].toStringAsFixed(2)}'),
//                   pw.Text('Outstanding: \${analytics['totalOutstanding'].toStringAsFixed(2)}'),
//                   pw.Text('Collection Rate: ${analytics['collectionRate'].toStringAsFixed(1)}%'),
//                 ],
//               ),
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Text('Total Invoices: ${analytics['totalInvoices']}'),
//                   pw.Text('Overdue Count: ${analytics['overdueCount']}'),
//                   pw.Text('Avg Invoice: \${analytics['avgInvoice'].toStringAsFixed(2)}'),
//                 ],
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildDetailedAnalytics(Map<String, dynamic> analytics) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         border: pw.Border.all(color: PdfColors.grey300),
//         borderRadius: pw.BorderRadius.circular(8),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             'DETAILED ANALYTICS',
//             style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//           ),
//           pw.SizedBox(height: 8),
//           pw.Text('Payment Performance: ${analytics['paymentPerformance']}'),
//           pw.Text('Risk Assessment: ${analytics['riskLevel']}'),
//           if (analytics['recommendations'] != null) ...[
//             pw.SizedBox(height: 8),
//             pw.Text('Recommendations:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//             ...analytics['recommendations'].map<pw.Widget>((rec) => 
//               pw.Text('• $rec', style: const pw.TextStyle(fontSize: 11))
//             ).toList(),
//           ],
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildBillingReportTable(
//     List<Invoice> invoices, List<User> students, List<Payment> payments
//   ) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Text(
//           'DETAILED INVOICE BREAKDOWN',
//           style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//         ),
//         pw.SizedBox(height: 8),
//         pw.Table(
//           border: pw.TableBorder.all(color: PdfColors.grey300),
//           children: [
//             // Header
//             pw.TableRow(
//               decoration: const pw.BoxDecoration(color: PdfColors.grey100),
//               children: [
//                 _buildTableCell('Invoice', isHeader: true),
//                 _buildTableCell('Student', isHeader: true),
//                 _buildTableCell('Date', isHeader: true),
//                 _buildTableCell('Due', isHeader: true),
//                 _buildTableCell('Amount', isHeader: true),
//                 _buildTableCell('Paid', isHeader: true),
//                 _buildTableCell('Balance', isHeader: true),
//                 _buildTableCell('Status', isHeader: true),
//               ],
//             ),
//             // Data rows
//             ...invoices.map((invoice) {
//               final student = students.firstWhere(
//                 (s) => s.id == invoice.studentId,
//                 orElse: () => User(id: 0, fname: 'Unknown', lname: 'Student', email: '', phone: '', address: '', role: 'student'),
//               );
//               final isOverdue = invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now());
              
//               return pw.TableRow(
//                 children: [
//                   _buildTableCell(invoice.invoiceNumber),
//                   _buildTableCell('${student.fname} ${student.lname}'),
//                   _buildTableCell(DateFormat('MM/dd').format(invoice.createdAt)),
//                   _buildTableCell(DateFormat('MM/dd').format(invoice.dueDate)),
//                   _buildTableCell('\${invoice.totalAmountCalculated.toStringAsFixed(2)}'),
//                   _buildTableCell('\${invoice.amountPaid.toStringAsFixed(2)}'),
//                   _buildTableCell(
//                     '\${invoice.balance.toStringAsFixed(2)}',
//                     textColor: invoice.balance > 0 ? PdfColors.red : PdfColors.green,
//                   ),
//                   _buildTableCell(
//                     invoice.status,
//                     textColor: isOverdue ? PdfColors.red : PdfColors.black,
//                   ),
//                 ],
//               );
//             }).toList(),
//           ],
//         ),
//       ],
//     );
//   }

//   static pw.Widget _buildReportFooter(SettingsController settings) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.only(top: 15),
//       decoration: const pw.BoxDecoration(
//         border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
//       ),
//       child: pw.Column(
//         children: [
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Text(
//                 'Confidential and Proprietary - ${settings.businessName.value}',
//                 style: const pw.TextStyle(fontSize: 9),
//               ),
//               pw.Text(
//                 'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
//                 style: const pw.TextStyle(fontSize: 9),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // Utility methods
//   static pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? textColor}) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(6),
//       child: pw.Text(
//         text,
//         style: pw.TextStyle(
//           fontSize: isHeader ? 10 : 9,
//           fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
//           color: textColor ?? (isHeader ? PdfColors.black : PdfColors.grey800),
//         ),
//       ),
//     );
//   }

//   static Map<String, dynamic> _calculateBillingAnalytics(List<Invoice> invoices, List<Payment> payments) {
//     final totalRevenue = invoices.fold(0.0, (sum, inv) => sum + inv.totalAmountCalculated);
//     final totalPaid = invoices.fold(0.0, (sum, inv) => sum + inv.amountPaid);
//     final totalOutstanding = invoices.fold(0.0, (sum, inv) => sum + inv.balance);
//     final overdueCount = invoices.where((inv) => 
//         inv.balance > 0 && inv.dueDate.isBefore(DateTime.now())).length;
    
//     final collectionRate = totalRevenue > 0 ? (totalPaid / totalRevenue * 100) : 0.0;
//     final avgInvoice = invoices.isNotEmpty ? totalRevenue / invoices.length : 0.0;
    
//     String paymentPerformance;
//     String riskLevel;
//     List<String> recommendations = [];
    
//     if (collectionRate >= 95) {
//       paymentPerformance = 'Excellent';
//       riskLevel = 'Low';
//     } else if (collectionRate >= 85) {
//       paymentPerformance = 'Good';
//       riskLevel = 'Low';
//     } else if (collectionRate >= 70) {
//       paymentPerformance = 'Fair';
//       riskLevel = 'Medium';
//       recommendations.add('Follow up on outstanding invoices');
//     } else {
//       paymentPerformance = 'Poor';
//       riskLevel = 'High';
//       recommendations.addAll([
//         'Implement stricter payment terms',
//         'Review credit approval process',
//         'Consider payment plans for students'
//       ]);
//     }
    
//     if (overdueCount > invoices.length * 0.2) {
//       recommendations.add('Address overdue accounts immediately');
//     }
    
//     return {
//       'totalRevenue': totalRevenue,
//       'totalPaid': totalPaid,
//       'totalOutstanding': totalOutstanding,
//       'totalInvoices': invoices.length,
//       'overdueCount': overdueCount,
//       'collectionRate': collectionRate,
//       'avgInvoice': avgInvoice,
//       'paymentPerformance': paymentPerformance,
//       'riskLevel': riskLevel,
//       'recommendations': recommendations,
//     };
//   }

//   static Future<String> _saveStatementPdf(pw.Document pdf, User? student, String type, {String? customName}) async {
//     final directory = await getApplicationDocumentsDirectory();
//     final reportsDir = Directory('${directory.path}/reports');
//     if (!await reportsDir.exists()) {
//       await reportsDir.create(recursive: true);
//     }

//     final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
//     String fileName;
    
//     if (student != null) {
//       fileName = '${type}_${student.fname}_${student.lname}_$timestamp.pdf';
//     } else if (customName != null) {
//       fileName = '${type}_${customName}_$timestamp.pdf';
//     } else {
//       fileName = '${type}_$timestamp.pdf';
//     }
    
//     final file = File('${reportsDir.path}/$fileName');
//     await file.writeAsBytes(await pdf.save());
    
//     return file.path;
//   }

//   static Future<String> _saveCSVFile(String csvContent, String? type, String? customName) async {
//     final directory = await getApplicationDocumentsDirectory();
//     final reportsDir = Directory('${directory.path}/reports');
//     if (!await reportsDir.exists()) {
//       await reportsDir.create(recursive: true);
//     }

//     final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
//     String fileName;
    
//     if (customName != null) {
//       fileName = '${type ?? 'export'}_${customName}_$timestamp.csv';
//     } else {
//       fileName = '${type ?? 'export'}_$timestamp.csv';
//     }
    
//     final file = File('${reportsDir.path}/$fileName');
//     await file.writeAsString(csvContent);
    
//     return file.path;
//   }
// }.Text('\$${totalAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
//                   pw.Text('\$${totalPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
//                   pw.Text(
//                     '\$${totalBalance.toStringAsFixed(2)}', 
//                     style: pw.TextStyle(
//                       fontSize: 12, 
//                       fontWeight: pw.FontWeight.bold,
//                       color: totalBalance > 0 ? PdfColors.red : PdfColors.green,
//                     ),
//                   ),
//                   pw.Text('${totalLessons} lessons', style: const pw.TextStyle(fontSize: 12)),
//                 ],
//               ),
//             ],
//           ),
//           if (overdueCount > 0) ...[
//             pw.SizedBox(height: 8),
//             pw.Container(
//               padding: const pw.EdgeInsets.all(8),
//               decoration: pw.BoxDecoration(
//                 color: PdfColors.red50,
//                 borderRadius: pw.BorderRadius.circular(4),
//               ),
//               child: pw.Text(
//                 'WARNING: $overdueCount overdue invoice${overdueCount > 1 ? 's' : ''}',
//                 style: pw.TextStyle(fontSize: 11, color: PdfColors.red800, fontWeight: pw.FontWeight.bold),
//               ),
//             ),
//           ],
//           if (lastPaymentDate != null) ...[
//             pw.SizedBox(height: 8),
//             pw.Text(
//               'Last Payment: ${DateFormat('MMM dd, yyyy').format(lastPaymentDate)}',
//               style: const pw.TextStyle(fontSize: 11),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildInvoicesTable(List<Invoice> invoices) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Text(
//           'INVOICE HISTORY',
//           style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//         ),
//         pw.SizedBox(height: 8),
//         pw.Table(
//           border: pw.TableBorder.all(color: PdfColors.grey300),
//           children: [
//             // Header
//             pw.TableRow(
//               decoration: const pw.BoxDecoration(color: PdfColors.grey100),
//               children: [
//                 _buildTableCell('Invoice #', isHeader: true),
//                 _buildTableCell('Date', isHeader: true),
//                 _buildTableCell('Due Date', isHeader: true),
//                 _buildTableCell('Lessons', isHeader: true),
//                 _buildTableCell('Amount', isHeader: true),
//                 _buildTableCell('Paid', isHeader: true),
//                 _buildTableCell('Balance', isHeader: true),
//                 _buildTableCell('Status', isHeader: true),
//               ],
//             ),
//             // Data rows
//             ...invoices.map((invoice) {
//               final isOverdue = invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now());
//               return pw.TableRow(
//                 children: [
//                   _buildTableCell(invoice.invoiceNumber),
//                   _buildTableCell(DateFormat('MM/dd/yy').format(invoice.createdAt)),
//                   _buildTableCell(DateFormat('MM/dd/yy').format(invoice.dueDate)),
//                   _buildTableCell(invoice.lessons.toString()),
//                   _buildTableCell('\$${invoice.totalAmountCalculated.toStringAsFixed(2)}'),
//                   _buildTableCell('\$${invoice.amountPaid.toStringAsFixed(2)}'),
//                   _buildTableCell(
//                     '\$${invoice.balance.toStringAsFixed(2)}',
//                     textColor: invoice.balance > 0 ? PdfColors.red : PdfColors.green,
//                   ),
//                   _buildTableCell(
//                     invoice.status.toUpperCase(),
//                     textColor: isOverdue ? PdfColors.red : PdfColors.black,
//                   ),
//                 ],
//               );
//             }).toList(),
//           ],
//         ),
//       ],
//     );
//   }

//   static pw.Widget _buildPaymentsTable(List<Payment> payments) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Text(
//           'PAYMENT HISTORY',
//           style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//         ),
//         pw.SizedBox(height: 8),
//         pw.Table(
//           border: pw.TableBorder.all(color: PdfColors.grey300),
//           children: [
//             // Header
//             pw.TableRow(
//               decoration: const pw.BoxDecoration(color: PdfColors.grey100),
//               children: [
//                 _buildTableCell('Date', isHeader: true),
//                 _buildTableCell('Reference', isHeader: true),
//                 _buildTableCell('Method', isHeader: true),
//                 _buildTableCell('Amount', isHeader: true),
//                 _buildTableCell('Invoice', isHeader: true),
//               ],
//             ),
//             // Data rows
//             ...payments.map((payment) {
//               return pw.TableRow(
//                 children: [
//                   _buildTableCell(DateFormat('MM/dd/yy').format(payment.paymentDate)),
//                   _buildTableCell(payment.reference ?? 'N/A'),
//                   _buildTableCell(payment.paymentMethod ?? 'Cash'),
//                   _buildTableCell('\$${payment.amount.toStringAsFixed(2)}', textColor: PdfColors.green),
//                   _buildTableCell(payment.invoiceId?.toString() ?? 'N/A'),
//                 ],
//               );
//             }).toList(),
//           ],
//         ),
//       ],
//     );
//   }

//   static pw.Widget _buildAccountStatus(double totalBalance, int overdueCount) {
//     String statusText;
//     PdfColor statusColor;
    
//     if (totalBalance <= 0) {
//       statusText = 'ACCOUNT IN GOOD STANDING';
//       statusColor = PdfColors.green;
//     } else if (overdueCount > 0) {
//       statusText = 'IMMEDIATE ATTENTION REQUIRED';
//       statusColor = PdfColors.red;
//     } else {
//       statusText = 'PAYMENT DUE';
//       statusColor = PdfColors.orange;
//     }

//     return pw.Container(
//       width: double.infinity,
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: statusColor == PdfColors.green ? PdfColors.green50 :
//                statusColor == PdfColors.red ? PdfColors.red50 : PdfColors.orange50,
//         borderRadius: pw.BorderRadius.circular(8),
//         border: pw.Border.all(color: statusColor),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             'ACCOUNT STATUS',
//             style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//           ),
//           pw.SizedBox(height: 8),
//           pw.Text(
//             statusText,
//             style: pw.TextStyle(
//               fontSize: 16,
//               fontWeight: pw.FontWeight.bold,
//               color: statusColor,
//             ),
//           ),
//           if (totalBalance > 0) ...[
//             pw.SizedBox(height: 8),
//             pw.Text(
//               'Outstanding Balance: \$${totalBalance.toStringAsFixed(2)}',
//               style: const pw.TextStyle(fontSize: 12),
//             ),
//             if (overdueCount > 0) ...[
//               pw.Text(
//                 'Overdue Invoices: $overdueCount',
//                 style: pw.TextStyle(fontSize: 12, color: PdfColors.red),
//               ),
//             ],
//           ],
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildBusinessContactSection(SettingsController settings) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: PdfColors.grey50,
//         borderRadius: pw.BorderRadius.circular(8),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             'CONTACT INFORMATION',
//             style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//           ),
//           pw.SizedBox(height: 8),
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   if (settings.businessPhone.value.isNotEmpty) ...[
//                     pw.Text('Phone: ${settings.businessPhone.value}', style: const pw.TextStyle(fontSize: 11)),
//                   ],
//                   if (settings.businessEmail.value.isNotEmpty) ...[
//                     pw.Text('Email: ${settings.businessEmail.value}', style: const pw.TextStyle(fontSize: 11)),
//                   ],
//                   if (settings.businessWebsite.value.isNotEmpty) ...[
//                     pw.Text('Website: ${settings.businessWebsite.value}', style: const pw.TextStyle(fontSize: 11)),
//                   ],
//                 ],
//               ),
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.end,
//                 children: [
//                   pw.Text(
//                     'Business Hours:',
//                     style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
//                   ),
//                   pw.Text(
//                     '${settings.businessStartTime.value} - ${settings.businessEndTime.value}',
//                     style: const pw.TextStyle(fontSize: 11),
//                   ),
//                   if (settings.operatingDays.isNotEmpty) ...[
//                     pw.Text(
//                       settings.operatingDays.join(', '),
//                       style: const pw.TextStyle(fontSize: 10),
//                     ),
//                   ],
//                 ],
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _buildStatementFooter(SettingsController settings) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.only(top: 20),
//       decoration: const pw.BoxDecoration(
//         border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
//       ),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           pw.Text(
//             'Thank you for choosing ${settings.businessName.value}',
//             style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
//           ),
//           pw.Text(
//             'Page ${context.pageNumber} of ${context.pagesCount}',
//             style: const pw.TextStyle(fontSize: 10),
//           ),
//         ],
//       ),
//     );
//   }

//   // Additional helper methods for exports and reports...
  
//   static pw.Widget _buildExportHeader(SettingsController settings, String? exportType) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.only(bottom: 15),
//       child: pw.Column(
//         children: [
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Text(
//                     settings.businessName.value,
//                     style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
//                   ),
//                   pw.Text('${exportType?.toUpperCase() ?? 'EXPORT'} REPORT'),
//                 ],
//               ),
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.end,
//                 children: [
//                   pw.Text(
//                     'Generated on: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
//                     style: const pw.TextStyle(fontSize: 12),
//                   ),
//                   if (settings.businessPhone.value.isNotEmpty)
//                     pw.Text('Phone: ${settings.businessPhone.value}', style: const pw.TextStyle(fontSize: 12)),
//                   if (settings.businessEmail.value.isNotEmpty)
//                     pw.Text('Email: ${settings.businessEmail.value}', style: const pw.TextStyle(fontSize: 12)),
//                 ],

