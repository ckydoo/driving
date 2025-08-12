// lib/screens/payments/enhanced_pos_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../controllers/billing_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../models/user.dart';
import '../../models/course.dart';
import '../../models/invoice.dart';
import '../../models/schedule.dart';
import '../../services/lesson_counting_service.dart';
import '../../widgets/responsive_text.dart';

class QuickSearchScreen extends StatefulWidget {
  const QuickSearchScreen({Key? key}) : super(key: key);

  @override
  _QuickSearchScreenState createState() => _QuickSearchScreenState();
}

class _QuickSearchScreenState extends State<QuickSearchScreen> {
  final BillingController billingController = Get.find();
  final UserController userController = Get.find();
  final CourseController courseController = Get.find();
  final ScheduleController scheduleController = Get.find();
  final LessonCountingService lessonService = LessonCountingService.instance;

  // Search and Selection
  final TextEditingController _searchController = TextEditingController();
  User? _selectedStudent;
  List<User> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await userController.fetchUsers();
    await billingController.fetchBillingData();
    await courseController.fetchCourses();
  }

  void _searchStudents(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final students = userController.users
        .where((user) => user.role.toLowerCase() == 'student')
        .where((user) =>
            '${user.fname} ${user.lname}'
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            user.email.toLowerCase().contains(query.toLowerCase()) ||
            (user.idnumber?.toLowerCase().contains(query.toLowerCase()) ??
                false))
        .toList();

    setState(() {
      _searchResults = students;
    });
  }

  void _selectStudent(User student) {
    setState(() {
      _selectedStudent = student;
      _searchResults = [];
      _searchController.text = '${student.fname} ${student.lname}';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStudent = null;
      _searchController.clear();
      _searchResults = [];
    });
  }

  double _getStudentBalance(User student) {
    return billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .fold(0.0, (sum, invoice) => sum + invoice.balance);
  }

  List<Invoice> _getStudentInvoices(User student) {
    return billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();
  }

  Map<Course, int> _getStudentLessonsLeft(User student) {
    Map<Course, int> courseLessons = {};

    for (var course in courseController.courses) {
      final remainingLessons =
          scheduleController.getRemainingLessons(student.id!, course.id!);

      if (remainingLessons > 0) {
        courseLessons[course] = remainingLessons;
      }
    }

    return courseLessons;
  }

  List<Schedule> _getStudentSchedules(User student) {
    return scheduleController.schedules
        .where((schedule) => schedule.studentId == student.id)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  List<Schedule> _getUpcomingSchedules(User student) {
    final now = DateTime.now();
    return _getStudentSchedules(student)
        .where((schedule) =>
            schedule.start.isAfter(now) && schedule.status != 'Cancelled')
        .take(5)
        .toList();
  }

  List<Schedule> _getTodaySchedules(User student) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

    return _getStudentSchedules(student)
        .where((schedule) =>
            schedule.start.isAfter(today) && schedule.start.isBefore(tomorrow))
        .toList();
  }

  List<Schedule> _getRecentSchedules(User student) {
    final now = DateTime.now();
    return _getStudentSchedules(student)
        .where((schedule) => schedule.start.isBefore(now))
        .take(5)
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start));
  }

  String _getInstructorName(int instructorId) {
    final instructor = userController.users
        .firstWhereOrNull((user) => user.id == instructorId);
    return instructor != null
        ? '${instructor.fname} ${instructor.lname}'
        : 'Unknown Instructor';
  }

  String _getCourseName(int courseId) {
    final course = courseController.courses
        .firstWhereOrNull((course) => course.id == courseId);
    return course?.name ?? 'Unknown Course';
  }

  Color _getScheduleStatusColor(Schedule schedule) {
    if (schedule.attended) return Colors.green;
    if (schedule.status == 'Cancelled') return Colors.red;
    if (schedule.isPast && !schedule.attended) return Colors.orange;
    if (schedule.isInProgress) return Colors.blue;
    return Colors.grey[600]!;
  }

  IconData _getScheduleStatusIcon(Schedule schedule) {
    if (schedule.attended) return Icons.check_circle;
    if (schedule.status == 'Cancelled') return Icons.cancel;
    if (schedule.isPast && !schedule.attended) return Icons.warning;
    if (schedule.isInProgress) return Icons.play_circle;
    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: ResponsiveText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          'Quick Search',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          if (_selectedStudent != null)
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Clear Selection',
            ),
        ],
      ),
      body: SingleChildScrollView(
        // Add this wrapper
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Search Section
            _buildStudentSearchSection(),

            SizedBox(height: 20),

            // Student Information Display
            if (_selectedStudent != null) ...[
              _buildStudentInfoCard(),
              SizedBox(height: 20),
              _buildStudentBalanceCard(),
              SizedBox(height: 20),
              _buildStudentLessonsCard(),
              SizedBox(height: 20),
              _buildStudentSchedulesCard(),
            ] else ...[
              _buildNoStudentSelectedCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentSchedulesCard() {
    final student = _selectedStudent!;
    final upcomingSchedules = _getUpcomingSchedules(student);
    final todaySchedules = _getTodaySchedules(student);
    final recentSchedules = _getRecentSchedules(student);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.purple[700],
                size: 24,
              ),
              SizedBox(width: 10),
              ResponsiveText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                'Student Schedules',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Today's Schedules
          if (todaySchedules.isNotEmpty) ...[
            _buildScheduleSection(
              title: "Today's Lessons",
              schedules: todaySchedules,
              icon: Icons.today,
              color: Colors.blue,
            ),
            SizedBox(height: 20),
          ],

          // Upcoming Schedules
          if (upcomingSchedules.isNotEmpty) ...[
            _buildScheduleSection(
              title: 'Upcoming Lessons',
              schedules: upcomingSchedules,
              icon: Icons.upcoming,
              color: Colors.green,
            ),
            SizedBox(height: 20),
          ],

          // Recent Schedules
          if (recentSchedules.isNotEmpty) ...[
            _buildScheduleSection(
              title: 'Recent Lessons',
              schedules: recentSchedules,
              icon: Icons.history,
              color: Colors.orange,
            ),
          ],

          // No schedules message
          if (todaySchedules.isEmpty &&
              upcomingSchedules.isEmpty &&
              recentSchedules.isEmpty) ...[
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600]),
                  SizedBox(width: 10),
                  ResponsiveText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    'No schedules found for this student',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleSection({
    required String title,
    required List<Schedule> schedules,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 8),
            ResponsiveText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ResponsiveText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                '${schedules.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...schedules.map((schedule) => _buildScheduleItem(schedule)).toList(),
      ],
    );
  }

  Widget _buildScheduleItem(Schedule schedule) {
    final statusColor = _getScheduleStatusColor(schedule);
    final statusIcon = _getScheduleStatusIcon(schedule);
    final instructorName = _getInstructorName(schedule.instructorId);
    final courseName = _getCourseName(schedule.courseId);

    final dateFormat = DateFormat('MMM dd');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 16,
            ),
          ),
          SizedBox(width: 12),

          // Schedule Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course and Type
                ResponsiveText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  '$courseName • ${schedule.classType}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 2),

                // Instructor
                ResponsiveText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  'with $instructorName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 2),

                // Date and Time
                ResponsiveText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  '${dateFormat.format(schedule.start)} • ${timeFormat.format(schedule.start)} - ${timeFormat.format(schedule.end)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Duration and Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Lesson Count
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ResponsiveText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  '${schedule.lessonsDeducted} lesson${schedule.lessonsDeducted != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 4),

              // Status
              ResponsiveText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                schedule.statusDisplay,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSearchSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            'Select Student',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 15),
          TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or ID...',
              prefixIcon: Icon(Icons.search, color: Colors.blue[600]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchStudents('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue[600]!),
              ),
            ),
            onChanged: _searchStudents,
          ),

          // Search Results
          if (_searchResults.isNotEmpty) ...[
            SizedBox(height: 10),
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final student = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: ResponsiveText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        '${student.fname[0]}${student.lname[0]}',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: ResponsiveText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      '${student.fname} ${student.lname}',
                      style: TextStyle(),
                    ),
                    subtitle: ResponsiveText(
                      maxLines: 12,
                      overflow: TextOverflow.ellipsis,
                      student.email,
                      style: TextStyle(),
                    ),
                    trailing: student.idnumber != null
                        ? ResponsiveText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            'ID: ${student.idnumber}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          )
                        : null,
                    onTap: () => _selectStudent(student),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    final student = _selectedStudent!;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue[100],
            child: ResponsiveText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              '${student.fname[0]}${student.lname[0]}',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  '${student.fname} ${student.lname}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 5),
                ResponsiveText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  student.email,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                if (student.idnumber != null) ...[
                  SizedBox(height: 5),
                  ResponsiveText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    'ID: ${student.idnumber}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentBalanceCard() {
    final student = _selectedStudent!;
    final balance = _getStudentBalance(student);
    final invoices = _getStudentInvoices(student);
    final overdueCount = invoices
        .where((inv) => inv.balance > 0 && inv.dueDate.isBefore(DateTime.now()))
        .length;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: balance > 0 ? Colors.orange[700] : Colors.green[700],
                size: 24,
              ),
              SizedBox(width: 10),
              ResponsiveText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                'Account Balance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),

          // Balance Amount
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: balance > 0 ? Colors.orange[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: balance > 0 ? Colors.orange[200]! : Colors.green[200]!,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  balance > 0 ? Icons.warning : Icons.check_circle,
                  color: balance > 0 ? Colors.orange[700] : Colors.green[700],
                  size: 32,
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ResponsiveText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        balance > 0 ? 'Outstanding Balance' : 'Account Paid Up',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      ResponsiveText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        '\$${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: balance > 0
                              ? Colors.orange[800]
                              : Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (balance > 0) ...[
            SizedBox(height: 15),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                SizedBox(width: 5),
                ResponsiveText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  '${invoices.length} invoice(s) total',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (overdueCount > 0) ...[
                  SizedBox(width: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ResponsiveText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      '$overdueCount overdue',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentLessonsCard() {
    final student = _selectedStudent!;
    final courseLessons = _getStudentLessonsLeft(student);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school,
                color: Colors.blue[700],
                size: 24,
              ),
              SizedBox(width: 10),
              ResponsiveText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                'Lessons Remaining',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          if (courseLessons.isEmpty) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600]),
                  SizedBox(width: 10),
                  ResponsiveText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    'No remaining lessons found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...courseLessons.entries.map((entry) {
              final course = entry.key;
              final lessonsLeft = entry.value;

              Color statusColor;
              IconData statusIcon;

              if (lessonsLeft <= 0) {
                statusColor = Colors.red;
                statusIcon = Icons.warning;
              } else if (lessonsLeft <= 3) {
                statusColor = Colors.orange;
                statusIcon = Icons.warning_amber;
              } else {
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
              }

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: 24,
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResponsiveText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            course.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          ResponsiveText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            '\$${course.price.toStringAsFixed(2)} per lesson',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ResponsiveText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          '$lessonsLeft',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        ResponsiveText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          lessonsLeft == 1 ? 'lesson left' : 'lessons left',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildNoStudentSelectedCard() {
    return Container(
      // Remove Expanded wrapper
      width: double.infinity,
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 20),
          ResponsiveText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            'No Student Selected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          ResponsiveText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            'Search and select a student above to view their\nbalance and remaining lessons',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
