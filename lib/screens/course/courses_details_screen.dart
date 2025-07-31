// lib/screens/course/_course_details_screen.dart
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/widgets/course_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/course_controller.dart';
import '../../models/course.dart';
import 'package:fl_chart/fl_chart.dart';

class CourseDetailsScreen extends StatefulWidget {
  final int courseId;

  const CourseDetailsScreen({Key? key, required this.courseId})
      : super(key: key);

  @override
  _CourseDetailsScreenState createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with SingleTickerProviderStateMixin {
  final CourseController courseController = Get.find<CourseController>();
  final UserController userController = Get.find<UserController>();
  final BillingController billingController = Get.find<BillingController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();

  Course? course;
  bool _isLoading = true;
  late TabController _tabController;

  // Analytics data
  int _totalEnrollments = 0;
  double _totalRevenue = 0.0;
  int _activeStudents = 0;
  int _completedLessons = 0;
  List<Map<String, dynamic>> _recentEnrollments = [];
  List<Map<String, dynamic>> _monthlyStats = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCourseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await courseController.fetchCourses();
      await userController.fetchUsers();
      await billingController.fetchBillingData();
      await scheduleController.fetchSchedules();

      setState(() {
        course = courseController.courses.firstWhereOrNull(
          (c) => c.id == widget.courseId,
        );

        if (course != null) {
          _calculateAnalytics();
        }
        _isLoading = false;
      });

      if (course == null) {
        Get.snackbar(
          'Error',
          'Course not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load course data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _calculateAnalytics() {
    if (course == null) return;

    // Calculate enrollments and revenue
    final courseSchedules = scheduleController.schedules
        .where((s) => s.classType == course!.name)
        .toList();

    _totalEnrollments = courseSchedules.length;
    _activeStudents = courseSchedules.map((s) => s.studentId).toSet().length;

    _completedLessons = courseSchedules
        .where((s) => s.status.toLowerCase() == 'completed')
        .length;

    // Calculate revenue from invoices
    _totalRevenue = billingController.invoices
        .where((invoice) =>
            courseSchedules.any((s) => s.studentId == invoice.studentId))
        .fold<double>(
            0.0, (sum, invoice) => sum + invoice.totalAmountCalculated);

    // Get recent enrollments (last 10)
    _recentEnrollments = courseSchedules.map((schedule) {
      final student = userController.users.firstWhereOrNull(
        (u) => u.id == schedule.studentId,
      );
      return {
        'studentName': student != null
            ? '${student.fname} ${student.lname}'
            : 'Unknown Student',
        'enrollmentDate': schedule.start,
        'status': schedule.status,
        'studentId': schedule.studentId,
      };
    }).toList()
      ..sort((a, b) => (b['enrollmentDate'] as DateTime)
          .compareTo(a['enrollmentDate'] as DateTime));

    if (_recentEnrollments.length > 10) {
      _recentEnrollments = _recentEnrollments.take(10).toList();
    }

    // Calculate monthly stats for the last 6 months
    _monthlyStats = _calculateMonthlyStats(courseSchedules);
  }

  List<Map<String, dynamic>> _calculateMonthlyStats(List<dynamic> schedules) {
    final now = DateTime.now();
    final months = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      final monthSchedules = schedules
          .where((s) => s.start.isAfter(month) && s.start.isBefore(nextMonth))
          .toList();

      months.add({
        'month': DateFormat('MMM').format(month),
        'enrollments': monthSchedules.length,
        'completed': monthSchedules
            .where((s) => s.status.toLowerCase() == 'completed')
            .length,
      });
    }

    return months;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : course == null
              ? Center(child: Text('Course not found'))
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildQuickStats(),
                          _buildTabBarSection(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: Colors.blue[600],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          course!.name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue[400]!,
                Colors.blue[600]!,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 20,
                top: 80,
                child: Icon(
                  Icons.school,
                  size: 120,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: course!.status.toLowerCase() == 'active'
                            ? Colors.green[400]
                            : Colors.orange[400],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        course!.status.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '\$${course!.price}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Course Price',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.edit, color: Colors.white),
          onPressed: () async {
            final result = await Get.dialog<bool>(
              CourseFormDialog(course: course),
            );
            if (result == true) {
              _loadCourseData();
            }
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'duplicate':
                await _duplicateCourse();
                break;
              case 'delete':
                await _deleteCourse();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'duplicate',
              child: Row(
                children: [
                  Icon(Icons.copy, size: 20),
                  SizedBox(width: 8),
                  Text('Duplicate Course'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 8),
                  Text('Export Data'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Course', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
              child: _buildStatCard('Total Enrollments',
                  _totalEnrollments.toString(), Icons.people, Colors.blue)),
          SizedBox(width: 12),
          Expanded(
              child: _buildStatCard('Active Students',
                  _activeStudents.toString(), Icons.person_pin, Colors.green)),
          SizedBox(width: 12),
          Expanded(
              child: _buildStatCard(
                  'Total Revenue',
                  '\$${_totalRevenue.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.orange)),
          SizedBox(width: 12),
          Expanded(
              child: _buildStatCard(
                  'Completed Lessons',
                  _completedLessons.toString(),
                  Icons.check_circle,
                  Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBarSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue[600],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.blue[600],
            tabs: [
              Tab(icon: Icon(Icons.info), text: 'Overview'),
              Tab(icon: Icon(Icons.people), text: 'Students'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
          Container(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildStudentsTab(),
                _buildAnalyticsTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Course Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow(Icons.school, 'Course Name', course!.name),
          _buildInfoRow(Icons.attach_money, 'Price', '\$${course!.price}'),
          _buildInfoRow(Icons.circle, 'Status', course!.status),
          _buildInfoRow(Icons.calendar_today, 'Created',
              DateFormat('MMM dd, yyyy').format(course!.createdAt)),
          SizedBox(height: 24),
          Text(
            'Performance Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Enrollment Rate'),
                    Text('${_totalEnrollments} students',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Completion Rate'),
                    Text(
                        '${_totalEnrollments > 0 ? ((_completedLessons / _totalEnrollments) * 100).toStringAsFixed(1) : 0}%',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Revenue per Student'),
                    Text(
                        '\$${_activeStudents > 0 ? (_totalRevenue / _activeStudents).toStringAsFixed(2) : 0}',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Enrollments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _recentEnrollments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No enrollments yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _recentEnrollments.length,
                    itemBuilder: (context, index) {
                      final enrollment = _recentEnrollments[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _getStatusColor(enrollment['status']),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(enrollment['studentName']),
                          subtitle: Text(
                            'Enrolled: ${DateFormat('MMM dd, yyyy').format(enrollment['enrollmentDate'])}',
                          ),
                          trailing: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(enrollment['status'])
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              enrollment['status'],
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(enrollment['status']),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          onTap: () {
                            // Navigate to student details
                            // Navigator.push(...);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enrollment Trends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 10),
            Container(
              height: 250,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _monthlyStats.isEmpty
                      ? Center(child: Text('No data available'))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _monthlyStats
                                    .map((m) => m['enrollments'] as int)
                                    .reduce((a, b) => a > b ? a : b)
                                    .toDouble() +
                                2,
                            barTouchData: BarTouchData(enabled: true),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() < _monthlyStats.length) {
                                      return Text(_monthlyStats[value.toInt()]
                                          ['month']);
                                    }
                                    return Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups:
                                _monthlyStats.asMap().entries.map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value['enrollments'].toDouble(),
                                    color: Colors.blue[400],
                                    width: 20,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsCard(
                    'Avg. Monthly Enrollments',
                    _monthlyStats.isEmpty
                        ? '0'
                        : (_monthlyStats
                                    .map((m) => m['enrollments'] as int)
                                    .reduce((a, b) => a + b) /
                                _monthlyStats.length)
                            .toStringAsFixed(1),
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 5),
                Expanded(
                  child: _buildAnalyticsCard(
                    'Success Rate',
                    '${_totalEnrollments > 0 ? ((_completedLessons / _totalEnrollments) * 100).toStringAsFixed(1) : 0}%',
                    Icons.check_circle,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Course Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.edit, color: Colors.blue),
                  title: Text('Edit Course Details'),
                  subtitle: Text('Update name, price, and status'),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    final result = await Get.dialog<bool>(
                      CourseFormDialog(course: course),
                    );
                    if (result == true) {
                      _loadCourseData();
                    }
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.copy, color: Colors.green),
                  title: Text('Duplicate Course'),
                  subtitle: Text('Create a copy of this course'),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: _duplicateCourse,
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete Course'),
                  subtitle: Text('Permanently remove this course'),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: _deleteCourse,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
      case 'scheduled':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _duplicateCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Duplicate Course'),
        content: Text('Create a copy of "${course!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Duplicate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final duplicatedCourse = Course(
          name: '${course!.name} (Copy)',
          price: course!.price,
          status: 'inactive',
          createdAt: DateTime.now(),
        );

        await courseController.handleCourse(duplicatedCourse, isUpdate: false);
        Get.snackbar(
          'Success',
          'Course duplicated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to duplicate course: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _deleteCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${course!.name}"?'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will also remove all associated enrollments and cannot be undone.',
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await courseController.deleteCourse(course!.id!);
        Get.snackbar(
          'Success',
          'Course deleted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Navigator.of(context).pop();
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to delete course: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }
}
