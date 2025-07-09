import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/user.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:driving/services/database_helper.dart'; // Import DatabaseHelper
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CourseReportsScreen extends StatefulWidget {
  @override
  _CourseReportsScreenState createState() => _CourseReportsScreenState();
}

class _CourseReportsScreenState extends State<CourseReportsScreen> {
  final CourseController courseController = Get.find<CourseController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final BillingController billingController = Get.find<BillingController>();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await courseController.fetchCourses();
    await scheduleController.fetchSchedules();
    await billingController.fetchBillingData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Course Progress & Revenue',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showDownloadOptionsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeFrameSelector(),
            const SizedBox(height: 20),
            _buildCourseProgressAndRevenue(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFrameSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton(
              child: const Text('Today'),
              onPressed: () => _setTimeFrame(
                  DateTime.now(), DateTime.now().add(const Duration(days: 1))),
            ),
            TextButton(
              child: const Text('This Week'),
              onPressed: () => _setTimeFrame(_getThisWeekStart(),
                  DateTime.now().add(const Duration(days: 7))),
            ),
            TextButton(
              child: const Text('This Month'),
              onPressed: () => _setTimeFrame(_getThisMonthStart(),
                  DateTime.now().add(const Duration(days: 30))),
            ),
            TextButton(
              child: const Text('All Time'),
              onPressed: () => _setTimeFrame(DateTime(2000),
                  DateTime.now().add(const Duration(days: 3650))),
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _showDateRangePicker(),
            ),
          ],
        ),
      ),
    );
  }

  void _setTimeFrame(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
  }

  DateTime _getThisWeekStart() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  DateTime _getThisMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Widget _buildReportSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
      ),
    );
  }

  Widget _buildCourseProgressAndRevenue() {
    return Obx(() {
      if (courseController.isLoading.value ||
          scheduleController.isLoading.value ||
          billingController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final reportData = _generateCourseReportData();

      if (reportData.isEmpty) {
        return const Center(
            child: Text('No data available for the selected period.'));
      }

      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Course Progress and Revenue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDataTable(reportData),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDataTable(List<Map<String, dynamic>> reportData) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Course')),
        DataColumn(label: Text('Students')),
        DataColumn(label: Text('Completed Lessons')),
        DataColumn(label: Text('Total Lessons')),
        DataColumn(label: Text('Progress %')),
        DataColumn(label: Text('Revenue')),
      ],
      rows: reportData.map((data) {
        return DataRow(cells: [
          DataCell(Text(data['courseName'])),
          DataCell(Text('${data['studentCount']}')),
          DataCell(Text('${data['completedLessons']}')),
          DataCell(Text('${data['totalLessons']}')),
          DataCell(Text('${data['progress'].toStringAsFixed(1)}%')),
          DataCell(Text('\$${data['revenue'].toStringAsFixed(2)}')),
        ]);
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _generateCourseReportData() {
    final reportData = <Map<String, dynamic>>[];

    for (var course in courseController.courses) {
      // Filter schedules within the date range
      final courseSchedules = scheduleController.schedules
          .where((s) =>
              s.courseId == course.id &&
              s.start.isAfter(_startDate) &&
              s.start.isBefore(_endDate))
          .toList();

      if (courseSchedules.isEmpty) continue; // Skip courses with no schedules

      int studentCount = courseSchedules.map((s) => s.studentId).toSet().length;
      int totalLessons = courseSchedules.length;
      int completedLessons =
          courseSchedules.where((s) => s.attended).length; // Simplified
      double progress =
          totalLessons > 0 ? (completedLessons / totalLessons) * 100 : 0;

      // Calculate revenue (simplified: assuming each schedule generates course price)
      int revenue = courseSchedules.length * course.price;

      reportData.add({
        'courseName': course.name,
        'studentCount': studentCount,
        'totalLessons': totalLessons,
        'completedLessons': completedLessons,
        'progress': progress,
        'revenue': revenue,
      });
    }

    return reportData;
  }

  void _showDownloadOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download Options'),
          content: const Text('Choose the format to download the report.'),
          actions: [
            TextButton(
              child: const Text('CSV'),
              onPressed: () {
                Navigator.of(context).pop();
                _downloadCsv();
              },
            ),
            TextButton(
              child: const Text('PDF'),
              onPressed: () {
                Navigator.of(context).pop();
                _downloadPdf();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadCsv() async {
    final reportData = _generateCourseReportData();
    if (reportData.isEmpty) {
      Get.snackbar('No Data', 'No data to download.',
          backgroundColor: Colors.orange);
      return;
    }

    List<List<dynamic>> csvData = [
      [
        'Course',
        'Students',
        'Completed Lessons',
        'Total Lessons',
        'Progress %',
        'Revenue'
      ],
      ...reportData
          .map((data) => [
                data['courseName'],
                data['studentCount'],
                data['completedLessons'],
                data['totalLessons'],
                '${data['progress'].toStringAsFixed(1)}%',
                '\$${data['revenue'].toStringAsFixed(2)}',
              ])
          .toList(),
    ];

    String csv = const ListToCsvConverter().convert(csvData);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/course_report.csv';
      final file = File(path);
      await file.writeAsString(csv);

      Get.snackbar('Download Complete', 'CSV report saved to: $path',
          backgroundColor: Colors.green);
    } catch (e) {
      Get.snackbar('Error', 'Failed to save CSV: $e',
          backgroundColor: Colors.red);
    }
  }

  Future<void> _downloadPdf() async {
    final reportData = _generateCourseReportData();
    if (reportData.isEmpty) {
      Get.snackbar('No Data', 'No data to download.',
          backgroundColor: Colors.orange);
      return;
    }

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Course Progress and Revenue Report',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(
                    'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
                pw.SizedBox(height: 20),
                _buildPdfTable(reportData),
              ],
            ),
          );
        },
      ),
    );

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/course_report.pdf';
      final file = File(path);
      await file.writeAsBytes(await doc.save());

      Get.snackbar('Download Complete', 'PDF report saved to: $path',
          backgroundColor: Colors.green);
    } catch (e) {
      Get.snackbar('Error', 'Failed to save PDF: $e',
          backgroundColor: Colors.red);
    }
  }

  pw.Widget _buildPdfTable(List<Map<String, dynamic>> reportData) {
    return pw.Table.fromTextArray(
      context: null,
      data: <List<String>>[
        <String>[
          'Course',
          'Students',
          'Completed Lessons',
          'Total Lessons',
          'Progress %',
          'Revenue'
        ],
        ...reportData.map((data) => <String>[
              data['courseName'],
              '${data['studentCount']}',
              '${data['completedLessons']}',
              '${data['totalLessons']}',
              '${data['progress'].toStringAsFixed(1)}%',
              '\$${data['revenue'].toStringAsFixed(2)}',
            ])
      ],
      border: pw.TableBorder.all(),
    );
  }
}
