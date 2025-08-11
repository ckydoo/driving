import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/billing_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../models/user.dart';

class UsersReportsScreen extends StatefulWidget {
  @override
  _UsersReportsScreenState createState() => _UsersReportsScreenState();
}

class _UsersReportsScreenState extends State<UsersReportsScreen> {
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final BillingController billingController = Get.find<BillingController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final SettingsController settingsController = Get.find<SettingsController>();

  String selectedReportType = '';
  DateTimeRange? selectedDateRange;
  bool isGenerating = false;

  final Map<String, List<Map<String, dynamic>>> reportCategories = {
    'User Overview Reports': [
      {
        'id': 'all_users_report',
        'title': 'Complete User Directory',
        'description':
            'Comprehensive list of all users with detailed information',
        'icon': Icons.people,
        'color': Colors.blue,
        'type': 'document'
      },
      {
        'id': 'user_summary',
        'title': 'User Summary by Role',
        'description': 'Statistical breakdown of users by role and status',
        'icon': Icons.bar_chart,
        'color': Colors.green,
        'type': 'document'
      },
      {
        'id': 'registration_trends',
        'title': 'Registration Trends Report',
        'description': 'User registration patterns over time',
        'icon': Icons.trending_up,
        'color': Colors.purple,
        'type': 'document'
      },
    ],
    'Student Reports': [
      {
        'id': 'student_directory',
        'title': 'Student Directory',
        'description': 'Complete list of students with contact information',
        'icon': Icons.school,
        'color': Colors.teal,
        'type': 'document'
      },
      {
        'id': 'student_status_report',
        'title': 'Student Status Analysis',
        'description': 'Breakdown of students by status and activity',
        'icon': Icons.assignment,
        'color': Colors.orange,
        'type': 'document'
      },
      {
        'id': 'student_progress_report',
        'title': 'Student Progress Overview',
        'description': 'Student lesson progress and course completion status',
        'icon': Icons.timeline,
        'color': Colors.indigo,
        'type': 'document'
      },
      {
        'id': 'inactive_students',
        'title': 'Inactive Students Report',
        'description': 'List of inactive students for reactivation campaigns',
        'icon': Icons.person_off,
        'color': Colors.red,
        'type': 'document'
      },
    ],
    'Instructor Reports': [
      {
        'id': 'instructor_directory',
        'title': 'Instructor Directory',
        'description': 'Complete list of instructors with credentials',
        'icon': Icons.person,
        'color': Colors.cyan,
        'type': 'document'
      },
      {
        'id': 'instructor_workload',
        'title': 'Instructor Workload Analysis',
        'description': 'Teaching load and schedule distribution per instructor',
        'icon': Icons.work,
        'color': Colors.brown,
        'type': 'document'
      },
      {
        'id': 'instructor_performance',
        'title': 'Instructor Performance Report',
        'description': 'Student success rates and feedback by instructor',
        'icon': Icons.star,
        'color': Colors.amber,
        'type': 'document'
      },
    ],
    'Administrative Reports': [
      {
        'id': 'access_permissions',
        'title': 'User Access & Permissions',
        'description': 'User roles and system access permissions audit',
        'icon': Icons.security,
        'color': Colors.deepPurple,
        'type': 'document'
      },
      {
        'id': 'user_activity',
        'title': 'User Activity Report',
        'description': 'Last login and system usage patterns',
        'icon': Icons.history,
        'color': Colors.pink,
        'type': 'document'
      },
      {
        'id': 'data_quality',
        'title': 'User Data Quality Report',
        'description': 'Incomplete profiles and missing information',
        'icon': Icons.data_usage,
        'color': Colors.lime,
        'type': 'document'
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    // Load fresh user data when screen opens
    _refreshData();
  }

  Future<void> _refreshData() async {
    await userController.fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Reports'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (selectedReportType.isNotEmpty)
            IconButton(
              icon: Icon(Icons.date_range),
              onPressed: _selectDateRange,
              tooltip: 'Select Date Range',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
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

  pw.Widget _buildPDFStudentProgressReport() {
    final progressData = _getStudentProgressData();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Student Progress Overview',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildPDFTableCell('Student Name', isHeader: true),
                _buildPDFTableCell('Course', isHeader: true),
                _buildPDFTableCell('Progress', isHeader: true),
                _buildPDFTableCell('Status', isHeader: true),
                _buildPDFTableCell('Next Lesson', isHeader: true),
              ],
            ),
            // Data rows
            ...progressData
                .map((data) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(data['student']),
                        _buildPDFTableCell(data['course']),
                        _buildPDFTableCell(
                            '${data['completed']}/${data['total']} (${data['progress'].toStringAsFixed(1)}%)'),
                        _buildPDFTableCell(data['status']),
                        _buildPDFTableCell(data['nextLesson']),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFStudentStatusReport() {
    final statusData = _getStudentStatusData();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Student Status Analysis',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildPDFTableCell('Status Category', isHeader: true),
                _buildPDFTableCell('Count', isHeader: true),
                _buildPDFTableCell('Percentage', isHeader: true),
                _buildPDFTableCell('Description', isHeader: true),
              ],
            ),
            // Data rows
            ...statusData
                .map((data) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(data['category']),
                        _buildPDFTableCell(data['count'].toString()),
                        _buildPDFTableCell(
                            '${data['percentage'].toStringAsFixed(1)}%'),
                        _buildPDFTableCell(data['description']),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFInstructorWorkloadReport() {
    final workloadData = _getInstructorWorkloadData();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Instructor Workload Analysis',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildPDFTableCell('Instructor', isHeader: true),
                _buildPDFTableCell('Active Students', isHeader: true),
                _buildPDFTableCell('Weekly Lessons', isHeader: true),
                _buildPDFTableCell('Monthly Hours', isHeader: true),
                _buildPDFTableCell('Workload Status', isHeader: true),
              ],
            ),
            // Data rows
            ...workloadData
                .map((data) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(data['name']),
                        _buildPDFTableCell(data['students'].toString()),
                        _buildPDFTableCell(data['weeklyLessons'].toString()),
                        _buildPDFTableCell(data['monthlyHours'].toString()),
                        _buildPDFTableCell(data['workloadStatus']),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFAccessPermissionsReport() {
    final permissionsData = _getAccessPermissionsData();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'User Access & Permissions Audit',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildPDFTableCell('User', isHeader: true),
                _buildPDFTableCell('Role', isHeader: true),
                _buildPDFTableCell('Dashboard', isHeader: true),
                _buildPDFTableCell('Students', isHeader: true),
                _buildPDFTableCell('Billing', isHeader: true),
                _buildPDFTableCell('Reports', isHeader: true),
              ],
            ),
            // Data rows
            ...permissionsData
                .map((data) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(data['name']),
                        _buildPDFTableCell(
                            data['role'].toString().toUpperCase()),
                        _buildPDFTableCell(data['dashboard'] ? 'Yes' : 'No'),
                        _buildPDFTableCell(data['students'] ? 'Yes' : 'No'),
                        _buildPDFTableCell(data['billing'] ? 'Yes' : 'No'),
                        _buildPDFTableCell(data['reports'] ? 'Yes' : 'No'),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  Widget _buildReportSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedReportType.isEmpty ? null : selectedReportType,
              hint: Text('Select Report Type'),
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _getAllReports().map((report) {
                return DropdownMenuItem<String>(
                  value: report['id'],
                  child: Text(report['title']),
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
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: isGenerating ? null : () => _printReport(),
                  icon: isGenerating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.print),
                  label: Text(isGenerating ? 'Preparing...' : 'Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isGenerating ? null : () => _generateReport('pdf'),
                  icon: isGenerating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.file_download),
                  label: Text(isGenerating ? 'Generating...' : 'Export PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReportCategoriesView() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: reportCategories.length,
      itemBuilder: (context, index) {
        final category = reportCategories.keys.elementAt(index);
        final reports = reportCategories[category]!;

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(
              category,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            children: reports.map((report) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: report['color'],
                  child: Icon(report['icon'], color: Colors.white),
                ),
                title: Text(
                  report['title'],
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(report['description']),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  setState(() {
                    selectedReportType = report['id'];
                  });
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSelectedReportView() {
    final report = _getReportById(selectedReportType);
    if (report == null) return SizedBox.shrink();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: report['color'],
                        child: Icon(report['icon'], color: Colors.white),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report['title'],
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              report['description'],
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (selectedDateRange != null) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range, color: Colors.blue.shade600),
                          SizedBox(width: 8),
                          Text(
                            'Date Range: ${DateFormat('MMM d, yyyy').format(selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(selectedDateRange!.end)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildDetailedReportPreview(report),
        ],
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
              'Report Preview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildReportDataTable(report['id']),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This preview shows sample data. Use "Print" to send directly to your printer or "Export PDF" to save the complete report.',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportDataTable(String reportId) {
    switch (reportId) {
      case 'all_users_report':
        return _buildAllUsersTable();
      case 'user_summary':
        return _buildUserSummaryTable();
      case 'student_directory':
        return _buildStudentDirectoryTable();
      case 'student_status_report':
        return _buildStudentStatusTable();
      case 'instructor_directory':
        return _buildInstructorDirectoryTable();
      case 'instructor_workload':
        return _buildInstructorWorkloadTable();
      case 'access_permissions':
        return _buildAccessPermissionsTable();
      case 'inactive_students':
        return _buildInactiveStudentsTable();
      case 'registration_trends':
        return _buildRegistrationTrendsTable();
      case 'student_progress_report':
        return _buildStudentProgressTable();
      case 'instructor_performance':
        return _buildInstructorPerformanceTable();
      case 'user_activity':
        return _buildUserActivityTable();
      case 'data_quality':
        return _buildDataQualityTable();
      default:
        return Text('Report data will be displayed here');
    }
  }

  Widget _buildAllUsersTable() {
    final users = userController.users.take(10).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Full Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('ID Number')),
          DataColumn(label: Text('Registration Date')),
        ],
        rows: users
            .map((user) => DataRow(cells: [
                  DataCell(Text('${user.fname} ${user.lname}')),
                  DataCell(Text(user.email)),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user.role),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          user.status == 'Active' ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.status,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                  DataCell(Text(user.phone)),
                  DataCell(Text(user.idnumber)),
                  DataCell(
                      Text(DateFormat('MMM d, yyyy').format(user.created_at))),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildUserSummaryTable() {
    final summaryData = _getUserSummaryData();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Total Users')),
          DataColumn(label: Text('Active')),
          DataColumn(label: Text('Inactive')),
          DataColumn(label: Text('This Month')),
          DataColumn(label: Text('Percentage')),
        ],
        rows: summaryData
            .map((data) => DataRow(cells: [
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(data['role']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['role'].toString().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                  DataCell(Text(data['total'].toString())),
                  DataCell(Text(data['active'].toString(),
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text(data['inactive'].toString(),
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold))),
                  DataCell(Text(data['thisMonth'].toString())),
                  DataCell(Text('${data['percentage'].toStringAsFixed(1)}%')),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildStudentDirectoryTable() {
    final students = userController.students.take(10).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Student Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Gender')),
          DataColumn(label: Text('Date of Birth')),
          DataColumn(label: Text('Address')),
          DataColumn(label: Text('Status')),
        ],
        rows: students
            .map((student) => DataRow(cells: [
                  DataCell(Text('${student.fname} ${student.lname}')),
                  DataCell(Text(student.email)),
                  DataCell(Text(student.phone)),
                  DataCell(Text(student.gender)),
                  DataCell(Text(
                      DateFormat('MMM d, yyyy').format(student.date_of_birth))),
                  DataCell(
                      Text(student.address, overflow: TextOverflow.ellipsis)),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: student.status == 'Active'
                          ? Colors.green
                          : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      student.status,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildStudentStatusTable() {
    final statusData = _getStudentStatusData();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Status Category')),
          DataColumn(label: Text('Count')),
          DataColumn(label: Text('Percentage')),
          DataColumn(label: Text('Description')),
        ],
        rows: statusData
            .map((data) => DataRow(cells: [
                  DataCell(Text(data['category'])),
                  DataCell(Text(data['count'].toString())),
                  DataCell(Text('${data['percentage'].toStringAsFixed(1)}%')),
                  DataCell(Text(data['description'])),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildInstructorDirectoryTable() {
    final instructors = userController.instructors.take(10).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Instructor Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('ID Number')),
          DataColumn(label: Text('Students Assigned')),
          DataColumn(label: Text('Status')),
        ],
        rows: instructors
            .map((instructor) => DataRow(cells: [
                  DataCell(Text('${instructor.fname} ${instructor.lname}')),
                  DataCell(Text(instructor.email)),
                  DataCell(Text(instructor.phone)),
                  DataCell(Text(instructor.idnumber)),
                  DataCell(Text(
                      _getInstructorStudentCount(instructor.id!).toString())),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: instructor.status == 'Active'
                          ? Colors.green
                          : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      instructor.status,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildInstructorWorkloadTable() {
    final workloadData = _getInstructorWorkloadData();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Instructor')),
          DataColumn(label: Text('Active Students')),
          DataColumn(label: Text('Weekly Lessons')),
          DataColumn(label: Text('This Month Hours')),
          DataColumn(label: Text('Workload Status')),
        ],
        rows: workloadData
            .map((data) => DataRow(cells: [
                  DataCell(Text(data['name'])),
                  DataCell(Text(data['students'].toString())),
                  DataCell(Text(data['weeklyLessons'].toString())),
                  DataCell(Text(data['monthlyHours'].toString())),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: data['workloadColor'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['workloadStatus'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildAccessPermissionsTable() {
    final permissionsData = _getAccessPermissionsData();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Dashboard')),
          DataColumn(label: Text('Students')),
          DataColumn(label: Text('Billing')),
          DataColumn(label: Text('Reports')),
          DataColumn(label: Text('Settings')),
        ],
        rows: permissionsData
            .map((data) => DataRow(cells: [
                  DataCell(Text(data['name'])),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(data['role']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['role'].toString().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                  DataCell(Icon(data['dashboard'] ? Icons.check : Icons.close,
                      color: data['dashboard'] ? Colors.green : Colors.red)),
                  DataCell(Icon(data['students'] ? Icons.check : Icons.close,
                      color: data['students'] ? Colors.green : Colors.red)),
                  DataCell(Icon(data['billing'] ? Icons.check : Icons.close,
                      color: data['billing'] ? Colors.green : Colors.red)),
                  DataCell(Icon(data['reports'] ? Icons.check : Icons.close,
                      color: data['reports'] ? Colors.green : Colors.red)),
                  DataCell(Icon(data['settings'] ? Icons.check : Icons.close,
                      color: data['settings'] ? Colors.green : Colors.red)),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildInactiveStudentsTable() {
    final inactiveStudents = userController.students
        .where((student) => student.status == 'Inactive')
        .take(10)
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Student Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Last Activity')),
          DataColumn(label: Text('Days Inactive')),
          DataColumn(label: Text('Suggested Action')),
        ],
        rows: inactiveStudents
            .map((student) => DataRow(cells: [
                  DataCell(Text('${student.fname} ${student.lname}')),
                  DataCell(Text(student.email)),
                  DataCell(Text(student.phone)),
                  DataCell(Text(
                      DateFormat('MMM d, yyyy').format(student.created_at))),
                  DataCell(Text(DateTime.now()
                      .difference(student.created_at)
                      .inDays
                      .toString())),
                  DataCell(Text('Contact for reactivation')),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildRegistrationTrendsTable() {
    final trendsData = _getRegistrationTrendsData();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Month')),
          DataColumn(label: Text('New Students')),
          DataColumn(label: Text('New Instructors')),
          DataColumn(label: Text('Total Registrations')),
          DataColumn(label: Text('Growth Rate')),
        ],
        rows: trendsData
            .map((data) => DataRow(cells: [
                  DataCell(Text(data['month'])),
                  DataCell(Text(data['students'].toString())),
                  DataCell(Text(data['instructors'].toString())),
                  DataCell(Text(data['total'].toString())),
                  DataCell(Text('${data['growth'].toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: data['growth'] >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ))),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildStudentProgressTable() {
    final progressData = _getStudentProgressData();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Student')),
          DataColumn(label: Text('Course')),
          DataColumn(label: Text('Lessons Progress')),
          DataColumn(label: Text('Progress %')),
          DataColumn(label: Text('Next Lesson')),
          DataColumn(label: Text('Status')),
        ],
        rows: progressData
            .map((data) => DataRow(cells: [
                  DataCell(Text(data['student'])),
                  DataCell(Text(data['course'])),
                  DataCell(Text('${data['completed']}/${data['total']}')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${data['progress'].toStringAsFixed(1)}%'),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: (data['progress'] / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              data['progress'] >= 100
                                  ? Colors.blue
                                  : data['progress'] >= 80
                                      ? Colors.green
                                      : data['progress'] >= 50
                                          ? Colors.orange
                                          : Colors.red),
                        ),
                      ),
                    ],
                  )),
                  DataCell(Text(data['nextLesson'])),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(data['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['status'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                ]))
            .toList(),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Fully Scheduled':
        return Colors.blue;
      case 'Nearly Scheduled':
        return Colors.green;
      case 'Partially Scheduled':
        return Colors.orange;
      case 'Starting':
        return Colors.amber;
      case 'Not Scheduled':
        return Colors.grey;
      case 'Not Enrolled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInstructorPerformanceTable() {
    final performanceData = _getInstructorPerformanceData();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Instructor')),
          DataColumn(label: Text('Students Taught')),
          DataColumn(label: Text('Pass Rate')),
          DataColumn(label: Text('Avg. Rating')),
          DataColumn(label: Text('Lessons This Month')),
          DataColumn(label: Text('Performance')),
        ],
        rows: performanceData
            .map((data) => DataRow(cells: [
                  DataCell(Text(data['instructor'])),
                  DataCell(Text(data['studentsTaught'].toString())),
                  DataCell(Text('${data['passRate'].toStringAsFixed(1)}%')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      SizedBox(width: 4),
                      Text(data['rating'].toStringAsFixed(1)),
                    ],
                  )),
                  DataCell(Text(data['lessonsThisMonth'].toString())),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: data['performanceColor'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['performance'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildUserActivityTable() {
    final activityData = _getUserActivityData();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Last Login')),
          DataColumn(label: Text('Login Frequency')),
          DataColumn(label: Text('Activity Level')),
          DataColumn(label: Text('Status')),
        ],
        rows: activityData
            .map((data) => DataRow(cells: [
                  DataCell(Text(data['user'])),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(data['role']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['role'].toString().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                  DataCell(Text(data['lastLogin'])),
                  DataCell(Text(data['frequency'])),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: data['activityColor'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['activityLevel'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                  DataCell(Text(data['status'])),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildDataQualityTable() {
    final qualityData = _getDataQualityData();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Profile Completion')),
          DataColumn(label: Text('Missing Fields')),
          DataColumn(label: Text('Data Quality')),
          DataColumn(label: Text('Action Required')),
        ],
        rows: qualityData
            .map((data) => DataRow(cells: [
                  DataCell(Text(data['user'])),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(data['role']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['role'].toString().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${data['completion']}%'),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: LinearProgressIndicator(
                          value: data['completion'] / 100,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              data['completion'] >= 80
                                  ? Colors.green
                                  : data['completion'] >= 50
                                      ? Colors.orange
                                      : Colors.red),
                        ),
                      ),
                    ],
                  )),
                  DataCell(Text(data['missingFields'])),
                  DataCell(Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: data['qualityColor'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['quality'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                  DataCell(Text(data['action'])),
                ]))
            .toList(),
      ),
    );
  }

  // Data generation methods
  List<Map<String, dynamic>> _getUserSummaryData() {
    final students = userController.students;
    final instructors = userController.instructors;
    final admins =
        userController.users.where((u) => u.role == 'admin').toList();
    final totalUsers = userController.users.length;

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);

    return [
      {
        'role': 'student',
        'total': students.length,
        'active': students.where((s) => s.status == 'Active').length,
        'inactive': students.where((s) => s.status == 'Inactive').length,
        'thisMonth':
            students.where((s) => s.created_at.isAfter(thisMonth)).length,
        'percentage': totalUsers > 0 ? (students.length / totalUsers) * 100 : 0,
      },
      {
        'role': 'instructor',
        'total': instructors.length,
        'active': instructors.where((i) => i.status == 'Active').length,
        'inactive': instructors.where((i) => i.status == 'Inactive').length,
        'thisMonth':
            instructors.where((i) => i.created_at.isAfter(thisMonth)).length,
        'percentage':
            totalUsers > 0 ? (instructors.length / totalUsers) * 100 : 0,
      },
      {
        'role': 'admin',
        'total': admins.length,
        'active': admins.where((a) => a.status == 'Active').length,
        'inactive': admins.where((a) => a.status == 'Inactive').length,
        'thisMonth':
            admins.where((a) => a.created_at.isAfter(thisMonth)).length,
        'percentage': totalUsers > 0 ? (admins.length / totalUsers) * 100 : 0,
      },
    ];
  }

  List<Map<String, dynamic>> _getStudentStatusData() {
    final students = userController.students;
    final totalStudents = students.length;

    final activeStudents = students.where((s) => s.status == 'Active').length;
    final inactiveStudents =
        students.where((s) => s.status == 'Inactive').length;
    final newStudents = students
        .where((s) => DateTime.now().difference(s.created_at).inDays <= 30)
        .length;
    final longTermStudents = students
        .where((s) => DateTime.now().difference(s.created_at).inDays > 180)
        .length;

    return [
      {
        'category': 'Active Students',
        'count': activeStudents,
        'percentage':
            totalStudents > 0 ? (activeStudents / totalStudents) * 100 : 0,
        'description': 'Currently enrolled and active',
      },
      {
        'category': 'Inactive Students',
        'count': inactiveStudents,
        'percentage':
            totalStudents > 0 ? (inactiveStudents / totalStudents) * 100 : 0,
        'description': 'Not currently active',
      },
      {
        'category': 'New Students (30 days)',
        'count': newStudents,
        'percentage':
            totalStudents > 0 ? (newStudents / totalStudents) * 100 : 0,
        'description': 'Registered in the last 30 days',
      },
      {
        'category': 'Long-term Students',
        'count': longTermStudents,
        'percentage':
            totalStudents > 0 ? (longTermStudents / totalStudents) * 100 : 0,
        'description': 'Enrolled for more than 6 months',
      },
    ];
  }

  List<Map<String, dynamic>> _getInstructorWorkloadData() {
    final instructors = userController.instructors.take(10).toList();
    return instructors.map((instructor) {
      final studentCount = _getInstructorStudentCount(instructor.id!);
      final weeklyLessons = (studentCount * 2.5).round(); // Estimate
      final monthlyHours = weeklyLessons * 4 * 1.5; // Estimate

      String workloadStatus;
      Color workloadColor;

      if (monthlyHours > 120) {
        workloadStatus = 'Overloaded';
        workloadColor = Colors.red;
      } else if (monthlyHours > 80) {
        workloadStatus = 'Full';
        workloadColor = Colors.orange;
      } else if (monthlyHours > 40) {
        workloadStatus = 'Moderate';
        workloadColor = Colors.green;
      } else {
        workloadStatus = 'Light';
        workloadColor = Colors.blue;
      }

      return {
        'name': '${instructor.fname} ${instructor.lname}',
        'students': studentCount,
        'weeklyLessons': weeklyLessons,
        'monthlyHours': monthlyHours,
        'workloadStatus': workloadStatus,
        'workloadColor': workloadColor,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getAccessPermissionsData() {
    final users = userController.users.take(10).toList();
    return users.map((user) {
      final role = user.role.toLowerCase();
      return {
        'name': '${user.fname} ${user.lname}',
        'role': user.role,
        'dashboard': ['admin', 'instructor', 'student'].contains(role),
        'students': ['admin', 'instructor'].contains(role),
        'billing': ['admin'].contains(role),
        'reports': ['admin', 'instructor'].contains(role),
        'settings': ['admin', 'instructor', 'student'].contains(role),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getRegistrationTrendsData() {
    final users = userController.users;
    final months = <String, Map<String, int>>{};

    // Generate data for last 6 months
    for (int i = 5; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i * 30));
      final monthKey = DateFormat('MMM yyyy').format(date);
      months[monthKey] = {'students': 0, 'instructors': 0, 'total': 0};
    }

    // Count registrations by month (simulated data for demo)
    int baseStudents = 5;
    int baseInstructors = 1;

    return months.entries.map((entry) {
      final students = baseStudents + (DateTime.now().millisecond % 10);
      final instructors = baseInstructors + (DateTime.now().millisecond % 3);
      final total = students + instructors;
      final growth = (DateTime.now().millisecond % 40) - 20.0; // -20% to +20%

      return {
        'month': entry.key,
        'students': students,
        'instructors': instructors,
        'total': total,
        'growth': growth,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getStudentProgressData() {
    final students = userController.students.take(10).toList();
    return students.map((student) {
      // Get actual invoices for this student (same logic as quick_search)
      final studentInvoices = billingController.invoices
          .where((invoice) => invoice.studentId == student.id)
          .toList();

      if (studentInvoices.isEmpty) {
        return {
          'student': '${student.fname} ${student.lname}',
          'course': 'Not Enrolled',
          'completed': 0,
          'total': 0,
          'progress': 0.0,
          'nextLesson': 'Enroll in Course',
          'status': 'Not Enrolled',
        };
      }

      // Use the first invoice for progress calculation
      final invoice = studentInvoices.first;

      // Get course name (same logic as quick_search)
      final course = courseController.courses.firstWhereOrNull(
        (c) => c.id == invoice.courseId,
      );
      final courseName = course?.name ?? 'Unknown Course';

      // Use the EXACT same logic as quick_search for remaining lessons
      final remainingLessons =
          scheduleController.getRemainingLessons(student.id!, invoice.courseId);
      final totalBilledLessons = invoice.lessons;

      // Calculate scheduled lessons from total - remaining
      final scheduledLessons = totalBilledLessons - remainingLessons;
      final progress = totalBilledLessons > 0
          ? (scheduledLessons / totalBilledLessons) * 100
          : 0.0;

      // Get next lesson info from future schedules (same logic as quick_search)
      final now = DateTime.now();
      final upcomingSchedules = scheduleController.schedules
          .where((s) =>
              s.studentId == student.id &&
              s.courseId == invoice.courseId &&
              s.start.isAfter(now) &&
              s.status != 'Cancelled')
          .toList();

      upcomingSchedules.sort((a, b) => a.start.compareTo(b.start));
      final nextLesson = upcomingSchedules.isNotEmpty
          ? DateFormat('MMM d, h:mm a').format(upcomingSchedules.first.start)
          : 'No upcoming lessons';

      String status;
      if (progress >= 100) {
        status = 'Fully Scheduled';
      } else if (progress >= 80) {
        status = 'Nearly Scheduled';
      } else if (progress >= 50) {
        status = 'Partially Scheduled';
      } else if (progress > 0) {
        status = 'Starting';
      } else {
        status = 'Not Scheduled';
      }

      return {
        'student': '${student.fname} ${student.lname}',
        'course': courseName,
        'completed': scheduledLessons,
        'total': totalBilledLessons,
        'progress': progress,
        'nextLesson': nextLesson,
        'status': status,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getInstructorPerformanceData() {
    final instructors = userController.instructors.take(10).toList();
    return instructors.map((instructor) {
      final studentsTaught = _getInstructorStudentCount(instructor.id!);
      final passRate = 75.0 + (DateTime.now().millisecond % 25); // 75-100%
      final rating = 3.5 + (DateTime.now().millisecond % 15) / 10; // 3.5-5.0
      final lessonsThisMonth = studentsTaught * 8;

      String performance;
      Color performanceColor;

      if (passRate >= 90 && rating >= 4.5) {
        performance = 'Excellent';
        performanceColor = Colors.green;
      } else if (passRate >= 80 && rating >= 4.0) {
        performance = 'Good';
        performanceColor = Colors.blue;
      } else if (passRate >= 70 && rating >= 3.5) {
        performance = 'Average';
        performanceColor = Colors.orange;
      } else {
        performance = 'Needs Improvement';
        performanceColor = Colors.red;
      }

      return {
        'instructor': '${instructor.fname} ${instructor.lname}',
        'studentsTaught': studentsTaught,
        'passRate': passRate,
        'rating': rating,
        'lessonsThisMonth': lessonsThisMonth,
        'performance': performance,
        'performanceColor': performanceColor,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getUserActivityData() {
    final users = userController.users.take(10).toList();
    return users.map((user) {
      final daysSinceLogin = DateTime.now().millisecond % 30;
      final loginFrequency = daysSinceLogin < 3
          ? 'Daily'
          : daysSinceLogin < 7
              ? 'Weekly'
              : daysSinceLogin < 14
                  ? 'Bi-weekly'
                  : 'Monthly';

      String activityLevel;
      Color activityColor;

      if (daysSinceLogin < 3) {
        activityLevel = 'High';
        activityColor = Colors.green;
      } else if (daysSinceLogin < 7) {
        activityLevel = 'Medium';
        activityColor = Colors.orange;
      } else {
        activityLevel = 'Low';
        activityColor = Colors.red;
      }

      return {
        'user': '${user.fname} ${user.lname}',
        'role': user.role,
        'lastLogin': DateFormat('MMM d, yyyy')
            .format(DateTime.now().subtract(Duration(days: daysSinceLogin))),
        'frequency': loginFrequency,
        'activityLevel': activityLevel,
        'activityColor': activityColor,
        'status': user.status,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getDataQualityData() {
    final users = userController.users.take(10).toList();
    return users.map((user) {
      int completionScore = 100;
      List<String> missingFields = [];

      if (user.phone.isEmpty) {
        completionScore -= 20;
        missingFields.add('Phone');
      }
      if (user.address.isEmpty) {
        completionScore -= 15;
        missingFields.add('Address');
      }
      if (user.idnumber.isEmpty) {
        completionScore -= 25;
        missingFields.add('ID Number');
      }

      String quality;
      Color qualityColor;
      String action;

      if (completionScore >= 90) {
        quality = 'Excellent';
        qualityColor = Colors.green;
        action = 'None required';
      } else if (completionScore >= 70) {
        quality = 'Good';
        qualityColor = Colors.blue;
        action = 'Minor updates';
      } else if (completionScore >= 50) {
        quality = 'Fair';
        qualityColor = Colors.orange;
        action = 'Profile update needed';
      } else {
        quality = 'Poor';
        qualityColor = Colors.red;
        action = 'Urgent update required';
      }

      return {
        'user': '${user.fname} ${user.lname}',
        'role': user.role,
        'completion': completionScore,
        'missingFields':
            missingFields.isEmpty ? 'None' : missingFields.join(', '),
        'quality': quality,
        'qualityColor': qualityColor,
        'action': action,
      };
    }).toList();
  }

  int _getInstructorStudentCount(int instructorId) {
    // This would normally query the schedules or courses to get actual student count
    // For demo purposes, returning a random number
    return (instructorId % 15) + 5; // 5-20 students
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'instructor':
        return Colors.blue;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
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

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
      });
    }
  }

  Future<void> _printReport() async {
    setState(() {
      isGenerating = true;
    });

    try {
      final report = _getReportById(selectedReportType);
      if (report == null) return;

      // Generate PDF document for printing
      final pdf = await _createPrintablePDF(report);

      // Print directly to available printers
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            '${report['title']}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
        format: PdfPageFormat.a4,
      );

      Get.snackbar(
        'Print Ready',
        'Report sent to printer successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Print Error',
        'Failed to print report: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  Future<pw.Document> _createPrintablePDF(Map<String, dynamic> report) async {
    final pdf = pw.Document();

    // Create PDF document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    report['title'],
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('MMM d, yyyy').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Report description
            pw.Text(
              report['description'],
              style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),

            // Date range if selected
            if (selectedDateRange != null) ...[
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Date Range: ${DateFormat('MMM d, yyyy').format(selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(selectedDateRange!.end)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Report content based on type
            _buildPDFReportContent(selectedReportType),
          ];
        },
      ),
    );

    return pdf;
  }

  Future<void> _generateReport(String type) async {
    setState(() {
      isGenerating = true;
    });

    try {
      if (type == 'pdf') {
        await _generatePDFReport();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to generate report: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  Future<void> _generatePDFReport() async {
    final pdf = pw.Document();
    final report = _getReportById(selectedReportType);

    if (report == null) return;

    // Create PDF document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    report['title'],
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('MMM d, yyyy').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Report description
            pw.Text(
              report['description'],
              style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),

            // Date range if selected
            if (selectedDateRange != null) ...[
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Date Range: ${DateFormat('MMM d, yyyy').format(selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(selectedDateRange!.end)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Report content based on type
            _buildPDFReportContent(selectedReportType),
          ];
        },
      ),
    );

    // Save PDF
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Users Report',
        fileName:
            '${report['title']}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(await pdf.save());

        Get.snackbar(
          'Success',
          'Report saved successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      throw Exception('Failed to save PDF: ${e.toString()}');
    }
  }

  pw.Widget _buildPDFReportContent(String reportId) {
    switch (reportId) {
      case 'all_users_report':
        return _buildPDFAllUsersReport();
      case 'user_summary':
        return _buildPDFUserSummaryReport();
      case 'student_directory':
        return _buildPDFStudentDirectoryReport();
      case 'instructor_directory':
        return _buildPDFInstructorDirectoryReport();
      case 'student_progress_report':
        return _buildPDFStudentProgressReport();
      case 'student_status_report':
        return _buildPDFStudentStatusReport();
      case 'instructor_workload':
        return _buildPDFInstructorWorkloadReport();
      case 'access_permissions':
        return _buildPDFAccessPermissionsReport();
      default:
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Report Content',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
                'This report contains detailed information about users in the system.'),
            pw.SizedBox(height: 12),
            pw.Text('Total Users: ${userController.users.length}'),
            pw.Text('Students: ${userController.students.length}'),
            pw.Text('Instructors: ${userController.instructors.length}'),
          ],
        );
    }
  }

  pw.Widget _buildPDFAllUsersReport() {
    final users = userController.users;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Summary Statistics',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _buildPDFStatCard('Total Users', users.length.toString()),
            _buildPDFStatCard(
                'Students', userController.students.length.toString()),
            _buildPDFStatCard(
                'Instructors', userController.instructors.length.toString()),
            _buildPDFStatCard('Active Users',
                users.where((u) => u.status == 'Active').length.toString()),
          ],
        ),
        pw.SizedBox(height: 24),

        // Users table
        pw.Text(
          'Complete User Directory',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(2.5),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildPDFTableCell('Full Name', isHeader: true),
                _buildPDFTableCell('Email', isHeader: true),
                _buildPDFTableCell('Role', isHeader: true),
                _buildPDFTableCell('Status', isHeader: true),
                _buildPDFTableCell('Registration Date', isHeader: true),
              ],
            ),
            // Data rows
            ...users
                .map((user) => pw.TableRow(
                      children: [
                        _buildPDFTableCell('${user.fname} ${user.lname}'),
                        _buildPDFTableCell(user.email),
                        _buildPDFTableCell(user.role.toUpperCase()),
                        _buildPDFTableCell(user.status),
                        _buildPDFTableCell(
                            DateFormat('MMM d, yyyy').format(user.created_at)),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFUserSummaryReport() {
    final summaryData = _getUserSummaryData();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'User Summary by Role',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildPDFTableCell('Role', isHeader: true),
                _buildPDFTableCell('Total', isHeader: true),
                _buildPDFTableCell('Active', isHeader: true),
                _buildPDFTableCell('Inactive', isHeader: true),
                _buildPDFTableCell('This Month', isHeader: true),
                _buildPDFTableCell('Percentage', isHeader: true),
              ],
            ),
            // Data rows
            ...summaryData
                .map((data) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(
                            data['role'].toString().toUpperCase()),
                        _buildPDFTableCell(data['total'].toString()),
                        _buildPDFTableCell(data['active'].toString()),
                        _buildPDFTableCell(data['inactive'].toString()),
                        _buildPDFTableCell(data['thisMonth'].toString()),
                        _buildPDFTableCell(
                            '${data['percentage'].toStringAsFixed(1)}%'),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFStudentDirectoryReport() {
    final students = userController.students;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Student Directory',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildPDFTableCell('Student Name', isHeader: true),
                _buildPDFTableCell('Email', isHeader: true),
                _buildPDFTableCell('Phone', isHeader: true),
                _buildPDFTableCell('Status', isHeader: true),
                _buildPDFTableCell('Registration', isHeader: true),
              ],
            ),
            // Data rows
            ...students
                .map((student) => pw.TableRow(
                      children: [
                        _buildPDFTableCell('${student.fname} ${student.lname}'),
                        _buildPDFTableCell(student.email),
                        _buildPDFTableCell(student.phone),
                        _buildPDFTableCell(student.status),
                        _buildPDFTableCell(DateFormat('MMM d, yyyy')
                            .format(student.created_at)),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFInstructorDirectoryReport() {
    final instructors = userController.instructors;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Instructor Directory',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildPDFTableCell('Instructor Name', isHeader: true),
                _buildPDFTableCell('Email', isHeader: true),
                _buildPDFTableCell('Phone', isHeader: true),
                _buildPDFTableCell('ID Number', isHeader: true),
                _buildPDFTableCell('Status', isHeader: true),
              ],
            ),
            // Data rows
            ...instructors
                .map((instructor) => pw.TableRow(
                      children: [
                        _buildPDFTableCell(
                            '${instructor.fname} ${instructor.lname}'),
                        _buildPDFTableCell(instructor.email),
                        _buildPDFTableCell(instructor.phone),
                        _buildPDFTableCell(instructor.idnumber),
                        _buildPDFTableCell(instructor.status),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFStatCard(String title, String value) {
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
