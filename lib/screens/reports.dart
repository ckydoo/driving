import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/user.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final BillingController billingController = Get.find<BillingController>();
  final FleetController fleetController = Get.find<FleetController>();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeFrameSelector(),
            const SizedBox(height: 20),
            _buildReportSectionTitle('General'),
            _buildTotalCountsCard(),
            const SizedBox(height: 20),
            _buildReportSectionTitle('Users'),
            _buildUserReports(),
            const SizedBox(height: 20),
            _buildReportSectionTitle('Courses'),
            _buildCourseReports(),
            const SizedBox(height: 20),
            _buildReportSectionTitle('Schedules'),
            _buildScheduleReports(),
            const SizedBox(height: 20),
            _buildReportSectionTitle('Billing'),
            _buildBillingReports(),
            const SizedBox(height: 20),
            _buildReportSectionTitle('Vehicles'),
            _buildFleetReports(),
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

  Widget _buildTotalCountsCard() {
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
              'Total Counts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCountItem(
                    'Students',
                    userController.users
                        .where((user) => user.role == 'student')
                        .length,
                    Colors.blue),
                _buildCountItem(
                    'Instructors',
                    userController.users
                        .where((user) => user.role == 'instructor')
                        .length,
                    Colors.green),
                _buildCountItem(
                    'Courses', courseController.courses.length, Colors.orange),
                _buildCountItem(
                    'Vehicles', fleetController.fleet.length, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildUserReports() {
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
              'User Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildInstructorAssignment(),
            const SizedBox(height: 16),
            _buildUserCountByRole(),
            const SizedBox(height: 16),
            _buildActiveInactiveUserCount(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorAssignment() {
    final totalInstructors =
        userController.users.where((user) => user.role == 'instructor').length;
    final assignedInstructors = fleetController.fleet
        .where((vehicle) => vehicle.instructor != 0)
        .map((vehicle) => vehicle.instructor)
        .toSet()
        .length;
    final assignmentPercentage = totalInstructors > 0
        ? (assignedInstructors / totalInstructors) * 100
        : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildPieChartItem('Instructors Assigned', assignedInstructors,
            totalInstructors, Colors.blue),
        _buildPieChartItem(
            'Instructors Unassigned',
            totalInstructors - assignedInstructors,
            totalInstructors,
            Colors.grey),
      ],
    );
  }

  Widget _buildUserCountByRole() {
    final totalUsers = userController.users.length;
    final studentCount =
        userController.users.where((user) => user.role == 'student').length;
    final instructorCount =
        userController.users.where((user) => user.role == 'instructor').length;
    final adminCount =
        userController.users.where((user) => user.role == 'admin').length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildPieChartItem('Students', studentCount, totalUsers, Colors.blue),
        _buildPieChartItem(
            'Instructors', instructorCount, totalUsers, Colors.green),
        _buildPieChartItem('Admins', adminCount, totalUsers, Colors.orange),
      ],
    );
  }

  Widget _buildActiveInactiveUserCount() {
    final totalUsers = userController.users.length;
    final activeUsers =
        userController.users.where((user) => user.status == 'Active').length;
    final inactiveUsers = totalUsers - activeUsers;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildBarChartItem('Active', activeUsers, totalUsers, Colors.green),
        _buildBarChartItem('Inactive', inactiveUsers, totalUsers, Colors.red),
      ],
    );
  }

  Widget _buildPieChartItem(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) * 100 : 0;
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.3),
          ),
          child: Center(
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartItem(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) * 100 : 0;
    return Column(
      children: [
        Container(
          width: 40,
          height: percentage.ceilToDouble(),
          color: color,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseReports() {
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
              'Course Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildCourseStatusBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseStatusBreakdown() {
    final totalCourses = courseController.courses.length;
    final activeCourses = courseController.courses
        .where((course) => course.status == 'active')
        .length;
    final inactiveCourses = totalCourses - activeCourses;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildBarChartItem('Active', activeCourses, totalCourses, Colors.green),
        _buildBarChartItem(
            'Inactive', inactiveCourses, totalCourses, Colors.red),
      ],
    );
  }

  Widget _buildScheduleReports() {
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
              'Schedule Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildScheduleAttendanceBreakdown(),
            const SizedBox(height: 16),
            _buildScheduleCancellationBreakdown(),
            const SizedBox(height: 16),
            _buildInstructorLessonSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleAttendanceBreakdown() {
    final totalSchedules = scheduleController.schedules
        .where((s) => s.start.isAfter(_startDate) && s.start.isBefore(_endDate))
        .length;
    final attendedSchedules = scheduleController.schedules
        .where((s) =>
            s.attended &&
            s.start.isAfter(_startDate) &&
            s.start.isBefore(_endDate))
        .length;
    final missedSchedules = totalSchedules - attendedSchedules;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildBarChartItem(
            'Attended', attendedSchedules, totalSchedules, Colors.green),
        _buildBarChartItem(
            'Missed', missedSchedules, totalSchedules, Colors.red),
      ],
    );
  }

  Widget _buildScheduleCancellationBreakdown() {
    final totalSchedules = scheduleController.schedules
        .where((s) => s.start.isAfter(_startDate) && s.start.isBefore(_endDate))
        .length;
    final canceledSchedules = scheduleController.schedules
        .where((s) =>
            s.status == 'Canceled' &&
            s.start.isAfter(_startDate) &&
            s.start.isBefore(_endDate))
        .length;
    final activeSchedules = totalSchedules - canceledSchedules;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildBarChartItem(
            'Active', activeSchedules, totalSchedules, Colors.blue),
        _buildBarChartItem(
            'Canceled', canceledSchedules, totalSchedules, Colors.orange),
      ],
    );
  }

  Widget _buildInstructorLessonSummary() {
    final instructorLessons = <int, int>{};
    final instructorStudents = <int, int>{};

    for (var schedule in scheduleController.schedules) {
      if (schedule.start.isAfter(_startDate) &&
          schedule.start.isBefore(_endDate) &&
          schedule.attended) {
        instructorLessons.update(schedule.instructorId, (value) => value + 1,
            ifAbsent: () => 1);
        instructorStudents.update(schedule.instructorId, (value) => value + 1,
            ifAbsent: () => 1);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Instructor Lesson Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (instructorLessons.isEmpty)
          const Text('No lessons conducted in this time frame.')
        else
          DataTable(
            columns: const [
              DataColumn(label: Text('Instructor')),
              DataColumn(label: Text('Lessons Taught')),
              DataColumn(label: Text('Students Taught')),
            ],
            rows: instructorLessons.entries.map((entry) {
              final instructor = userController.users.firstWhere(
                (user) => user.id == entry.key,
                orElse: () => User(
                  id: -1,
                  fname: 'Unknown',
                  lname: 'Instructor',
                  email: '',
                  password: '',
                  gender: '',
                  phone: '',
                  address: '',
                  date_of_birth: DateTime.now(),
                  role: '',
                  status: '',
                  idnumber: '',
                  created_at: DateTime.now(),
                ),
              );

              return DataRow(cells: [
                DataCell(Text('${instructor.fname} ${instructor.lname}')),
                DataCell(Text('${entry.value}')),
                DataCell(Text('${instructorStudents[entry.key] ?? 0}')),
              ]);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBillingReports() {
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
              'Billing Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildBillingOverview(),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingOverview() {
    final filteredInvoices = billingController.invoices
        .where((inv) =>
            inv.createdDate.isAfter(_startDate) &&
            inv.createdDate.isBefore(_endDate))
        .toList();

    final totalInvoices = filteredInvoices.length;
    double totalRevenue = 0;
    double totalPaid = 0;
    double totalOutstanding = 0;

    for (var invoice in filteredInvoices) {
      totalRevenue += invoice.totalAmountCalculated;
      totalPaid += invoice.amountPaid;
      totalOutstanding += invoice.balance;
    }

    return Column(
      children: [
        _buildBillingDataItem('Total Invoices', totalInvoices.toString()),
        _buildBillingDataItem(
            'Total Revenue', '\$${totalRevenue.toStringAsFixed(2)}'),
        _buildBillingDataItem('Total Paid', '\$${totalPaid.toStringAsFixed(2)}',
            color: Colors.green),
        _buildBillingDataItem(
            'Total Outstanding', '\$${totalOutstanding.toStringAsFixed(2)}',
            color: Colors.red),
      ],
    );
  }

  Widget _buildBillingDataItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetReports() {
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
              'Vehicles Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildFleetUtilization(),
          ],
        ),
      ),
    );
  }

  Widget _buildFleetUtilization() {
    final totalVehicles = fleetController.fleet.length;
    final assignedVehicles = fleetController.fleet
        .where((vehicle) => vehicle.instructor != 0)
        .length;
    final unassignedVehicles = totalVehicles - assignedVehicles;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildBarChartItem(
            'Assigned', assignedVehicles, totalVehicles, Colors.blue),
        _buildBarChartItem(
            'Unassigned', unassignedVehicles, totalVehicles, Colors.grey),
      ],
    );
  }
}
