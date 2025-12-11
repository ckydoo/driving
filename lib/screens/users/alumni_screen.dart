import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/course.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:driving/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AlumniScreen extends StatefulWidget {
  const AlumniScreen({Key? key}) : super(key: key);

  @override
  _AlumniScreenState createState() => _AlumniScreenState();
}

class _AlumniScreenState extends State<AlumniScreen> {
  final UserController userController = Get.find<UserController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final BillingController billingController = Get.find<BillingController>();
  final CourseController courseController = Get.find<CourseController>();

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _enrichedAlumni = [];
  List<Map<String, dynamic>> _filteredAlumni = [];
  bool _isLoading = false;
  String _sortBy = 'graduation_date';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadEnhancedAlumniData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  Future<void> _loadEnhancedAlumniData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all required data
      await userController.fetchUsers();
      await scheduleController.fetchSchedules();
      await billingController.fetchBillingData();
      await courseController.fetchCourses();

      // Get alumni users
      final alumni = userController.users
          .where((user) => user.role == 'alumni' || user.status == 'Graduated')
          .toList();

      // Only enrich if we have alumni
      if (alumni.isNotEmpty) {
        _enrichedAlumni = await _enrichAlumniData(alumni);
        _filteredAlumni = List.from(_enrichedAlumni);
        _applyFiltersAndSort();
      } else {
        _enrichedAlumni = [];
        _filteredAlumni = [];
      }
    } catch (e) {
      print('Error loading alumni data: $e');
      _enrichedAlumni = [];
      _filteredAlumni = [];
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Failed to load alumni data: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _enrichAlumniData(
      List<User> alumni) async {
    List<Map<String, dynamic>> enrichedData = [];

    for (var alumnus in alumni) {
      // Get all schedules for this alumnus
      final allSchedules = scheduleController.schedules
          .where((s) => s.studentId == alumnus.id)
          .toList();

      final completedSchedules = allSchedules
          .where((s) =>
              (s.status.toLowerCase() == 'completed' || s.attended))
          .toList();

      // Get instructor breakdown
      final instructorBreakdown = _getInstructorBreakdown(completedSchedules);

      // Get course breakdown
      final courseBreakdown =
          _getCourseBreakdown(completedSchedules, alumnus.id!);

      // Get lesson type breakdown
      final lessonTypeBreakdown = _getLessonTypeBreakdown(completedSchedules);

      // Get graduation info
      final graduationInfo = await _getGraduationInfo(alumnus.id!);

      // Get payment summary
      final paymentSummary = _getPaymentSummary(alumnus.id!);

      // Get training timeline
      final trainingTimeline = _getTrainingTimeline(allSchedules);

      // Calculate statistics
      final stats = _calculateStudentStats(allSchedules, completedSchedules);

      enrichedData.add({
        'user': alumnus,
        'graduation_date': graduationInfo['date'],
        'graduation_notes': graduationInfo['notes'],
        'total_lessons': completedSchedules.length,
        'total_hours': completedSchedules.fold<double>(
            0.0, (sum, s) => sum + _getScheduleDuration(s)),
        'instructor_breakdown': instructorBreakdown,
        'course_breakdown': courseBreakdown,
        'lesson_type_breakdown': lessonTypeBreakdown,
        'payment_summary': paymentSummary,
        'training_timeline': trainingTimeline,
        'stats': stats,
        'primary_instructor': _getPrimaryInstructor(instructorBreakdown),
        'completion_rate': _getCompletionRate(allSchedules),
        'training_duration': _getTrainingDuration(allSchedules),
      });
    }

    return enrichedData;
  }

  Map<String, dynamic> _getInstructorBreakdown(List<Schedule> schedules) {
    Map<int, Map<String, dynamic>> instructorData = {};

    for (var schedule in schedules) {
      final instructorId = schedule.instructorId;
      final instructor = userController.users.firstWhereOrNull(
        (u) => u.id == instructorId && u.role == 'instructor',
      );

      if (instructor != null) {
        if (!instructorData.containsKey(instructorId)) {
          instructorData[instructorId] = {
            'instructor': instructor,
            'lessons': 0,
            'hours': 0.0,
            'theory_lessons': 0,
            'practical_lessons': 0,
          };
        }

        instructorData[instructorId]!['lessons'] += 1;
        instructorData[instructorId]!['hours'] +=
            _getScheduleDuration(schedule);

        if (schedule.classType.toLowerCase() == 'theory') {
          instructorData[instructorId]!['theory_lessons'] += 1;
        } else {
          instructorData[instructorId]!['practical_lessons'] += 1;
        }
      }
    }

    return {
      'total_instructors': instructorData.length,
      'instructors': instructorData.values.toList(),
    };
  }

  Map<String, dynamic> _getCourseBreakdown(
      List<Schedule> schedules, int studentId) {
    Map<int, Map<String, dynamic>> courseData = {};

    for (var schedule in schedules) {
      final courseId = schedule.courseId;
      final course = courseController.courses.firstWhereOrNull(
        (c) => c.id == courseId,
      );

      if (course != null) {
        if (!courseData.containsKey(courseId)) {
          final invoice = billingController.invoices.firstWhereOrNull(
            (inv) => inv.studentId == studentId && inv.courseId == courseId,
          );

          courseData[courseId] = {
            'course': course,
            'lessons_completed': 0,
            'lessons_paid': invoice?.lessons ?? 0,
            'amount_paid': invoice?.amountPaid ?? 0.0,
            'hours': 0.0,
            'theory_lessons': 0,
            'practical_lessons': 0,
          };
        }

        courseData[courseId]!['lessons_completed'] += 1;
        courseData[courseId]!['hours'] += _getScheduleDuration(schedule);

        if (schedule.classType.toLowerCase() == 'theory') {
          courseData[courseId]!['theory_lessons'] += 1;
        } else {
          courseData[courseId]!['practical_lessons'] += 1;
        }
      }
    }

    return {
      'total_courses': courseData.length,
      'courses': courseData.values.toList(),
    };
  }

  Map<String, int> _getLessonTypeBreakdown(List<Schedule> schedules) {
    Map<String, int> breakdown = {'theory': 0, 'practical': 0, 'other': 0};

    for (var schedule in schedules) {
      final type = schedule.classType.toLowerCase();
      if (type == 'theory') {
        breakdown['theory'] = breakdown['theory']! + 1;
      } else if (type == 'practical') {
        breakdown['practical'] = breakdown['practical']! + 1;
      } else {
        breakdown['other'] = breakdown['other']! + 1;
      }
    }

    return breakdown;
  }

  Map<String, dynamic> _getPaymentSummary(int studentId) {
    final studentInvoices = billingController.invoices
        .where((inv) => inv.studentId == studentId)
        .toList();

    final totalAmount =
        studentInvoices.fold<double>(0.0, (sum, inv) => sum + inv.totalAmount);
    final totalPaid =
        studentInvoices.fold<double>(0.0, (sum, inv) => sum + inv.amountPaid);
    final totalLessonsPaid =
        studentInvoices.fold<int>(0, (sum, inv) => sum + inv.lessons);

    return {
      'total_invoices': studentInvoices.length,
      'total_amount': totalAmount,
      'total_paid': totalPaid,
      'outstanding_balance': totalAmount - totalPaid,
      'total_lessons_paid': totalLessonsPaid,
    };
  }

  List<Map<String, dynamic>> _getTrainingTimeline(List<Schedule> schedules) {
    final sortedSchedules = schedules.toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    List<Map<String, dynamic>> timeline = [];

    if (sortedSchedules.isNotEmpty) {
      timeline.add({
        'type': 'start',
        'date': sortedSchedules.first.start,
        'title': 'Training Started',
        'description': 'First lesson scheduled',
      });

      // Add milestone markers (every 10 lessons)
      var lessonCount = 0;
      for (var schedule in sortedSchedules.where((s) => s.attended)) {
        lessonCount++;
        if (lessonCount % 10 == 0) {
          timeline.add({
            'type': 'milestone',
            'date': schedule.start,
            'title': '${lessonCount} Lessons Completed',
            'description': 'Training milestone reached',
          });
        }
      }

      if (sortedSchedules.any((s) => s.attended)) {
        final lastLesson = sortedSchedules.where((s) => s.attended).last;
        timeline.add({
          'type': 'completion',
          'date': lastLesson.start,
          'title': 'Training Completed',
          'description': 'Final lesson completed',
        });
      }
    }

    return timeline;
  }

  Map<String, dynamic> _calculateStudentStats(
      List<Schedule> allSchedules, List<Schedule> completedSchedules) {
    final totalScheduled = allSchedules.length;
    final totalCompleted = completedSchedules.length;
    final missedLessons = allSchedules
        .where((s) =>
            s.status == 'Missed' ||
            (!s.attended && s.start.isBefore(DateTime.now())))
        .length;

    return {
      'total_scheduled': totalScheduled,
      'total_completed': totalCompleted,
      'total_missed': missedLessons,
      'completion_rate': totalScheduled > 0
          ? (totalCompleted / totalScheduled * 100).round()
          : 0,
      'attendance_rate': totalScheduled > 0
          ? ((totalScheduled - missedLessons) / totalScheduled * 100).round()
          : 0,
    };
  }

  String _getPrimaryInstructor(Map<String, dynamic> instructorBreakdown) {
    final instructors =
        instructorBreakdown['instructors'] as List<Map<String, dynamic>>;
    if (instructors.isEmpty) return 'No instructor recorded';

    final primaryInstructor =
        instructors.reduce((a, b) => a['lessons'] > b['lessons'] ? a : b);

    final instructor = primaryInstructor['instructor'] as User;
    return '${instructor.fname} ${instructor.lname}';
  }

  double _getCompletionRate(List<Schedule> schedules) {
    if (schedules.isEmpty) return 0.0;
    final completed = schedules.where((s) => s.attended).length;
    return (completed / schedules.length * 100);
  }

  String _getTrainingDuration(List<Schedule> schedules) {
    if (schedules.isEmpty) return 'No training record';

    schedules.sort((a, b) => a.start.compareTo(b.start));
    final start = schedules.first.start;
    final end = schedules.last.start;
    final duration = end.difference(start).inDays;

    if (duration < 30) return '$duration days';
    if (duration < 365) return '${(duration / 30).round()} months';
    return '${(duration / 365).toStringAsFixed(1)} years';
  }

  double _getScheduleDuration(Schedule schedule) {
    return schedule.end.difference(schedule.start).inMinutes / 60.0;
  }

  Future<Map<String, dynamic>> _getGraduationInfo(int studentId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'timeline',
        where: 'studentId = ? AND event_type = ?',
        whereArgs: [studentId, 'graduation'],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (result.isNotEmpty) {
        return {
          'date': DateTime.parse(result.first['created_at'] as String),
          'notes': result.first['description'] as String? ?? '',
        };
      }
    } catch (e) {
      print('Error getting graduation info: $e');
    }

    return {'date': null, 'notes': ''};
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> filtered = List.from(_enrichedAlumni);

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((data) {
        final user = data['user'] as User;
        final primaryInstructor = data['primary_instructor'] as String;
        return user.fname.toLowerCase().contains(query) ||
            user.lname.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            primaryInstructor.toLowerCase().contains(query) ||
            (user.idnumber?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          final userA = a['user'] as User;
          final userB = b['user'] as User;
          final comparison = '${userA.fname} ${userA.lname}'
              .compareTo('${userB.fname} ${userB.lname}');
          return _sortAscending ? comparison : -comparison;
        case 'graduation_date':
          final dateA = a['graduation_date'] as DateTime?;
          final dateB = b['graduation_date'] as DateTime?;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return _sortAscending ? 1 : -1;
          if (dateB == null) return _sortAscending ? -1 : 1;
          final comparison = dateA.compareTo(dateB);
          return _sortAscending ? comparison : -comparison;
        case 'total_lessons':
          final comparison =
              (a['total_lessons'] as int).compareTo(b['total_lessons'] as int);
          return _sortAscending ? comparison : -comparison;
        case 'total_hours':
          final comparison = (a['total_hours'] as double)
              .compareTo(b['total_hours'] as double);
          return _sortAscending ? comparison : -comparison;
        default:
          return 0;
      }
    });

    setState(() {
      _filteredAlumni = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: ResponsiveText(
          'Alumni Directory',
          style: TextStyle(),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadEnhancedAlumniData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(isMobile),
                _buildFiltersAndSearch(isMobile),
                Expanded(
                  child: _filteredAlumni.isEmpty
                      ? _buildEmptyState()
                      : isMobile
                          ? _buildMobileList()
                          : _buildDesktopView(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final totalAlumni = _enrichedAlumni.length;
    final totalLessons = _enrichedAlumni.fold<int>(
        0, (sum, data) => sum + (data['total_lessons'] as int));
    final totalHours = _enrichedAlumni.fold<double>(
        0.0, (sum, data) => sum + (data['total_hours'] as double));
    final avgLessons =
        totalAlumni > 0 ? (totalLessons / totalAlumni).round() : 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.blue[700], size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alumni Overview',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Graduated students and their training achievements',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          isMobile
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                      _buildStatCard('Total Alumni', totalAlumni.toString(),
                          Icons.people, Colors.blue),
                      SizedBox(height: 8),
                      _buildStatCard('Total Lessons', totalLessons.toString(),
                          Icons.book, Colors.green),
                      SizedBox(height: 8),
                      _buildStatCard(
                          'Total Hours',
                          totalHours.toStringAsFixed(0),
                          Icons.access_time,
                          Colors.orange),
                    ])
              : Row(children: [
                  Expanded(
                      child: _buildStatCard('Total Alumni',
                          totalAlumni.toString(), Icons.people, Colors.blue)),
                  SizedBox(width: 8),
                  Expanded(
                      child: _buildStatCard('Total Lessons',
                          totalLessons.toString(), Icons.book, Colors.green)),
                  SizedBox(width: 8),
                  Expanded(
                      child: _buildStatCard(
                          'Total Hours',
                          totalHours.toStringAsFixed(0),
                          Icons.access_time,
                          Colors.orange)),
                  SizedBox(width: 8),
                  Expanded(
                      child: _buildStatCard(
                          'Avg Lessons',
                          avgLessons.toString(),
                          Icons.trending_up,
                          Colors.purple)),
                ]),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(title,
              style: TextStyle(fontSize: 12, color: color),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search alumni by name, email, or instructor...',
              prefixIcon: Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (value) => _applyFiltersAndSort(),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'graduation_date',
                        child: Text('Graduation Date')),
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(
                        value: 'total_lessons', child: Text('Total Lessons')),
                    DropdownMenuItem(
                        value: 'total_hours', child: Text('Total Hours')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    _applyFiltersAndSort();
                  },
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                  _applyFiltersAndSort();
                },
                icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredAlumni.length,
      itemBuilder: (context, index) {
        final data = _filteredAlumni[index];
        return _buildMobileAlumniCard(data);
      },
    );
  }

  Widget _buildMobileAlumniCard(Map<String, dynamic> data) {
    final user = data['user'] as User;
    final graduationDate = data['graduation_date'] as DateTime?;
    final totalLessons = data['total_lessons'] as int;
    final totalHours = data['total_hours'] as double;
    final primaryInstructor = data['primary_instructor'] as String;
    final completionRate = data['completion_rate'] as double;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showAlumniDetails(data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      '${user.fname[0]}${user.lname[0]}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue[700]),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.fname} ${user.lname}',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(user.email,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Alumni',
                      style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMobileStatItem(
                            'Lessons', totalLessons.toString(), Icons.book),
                        _buildMobileStatItem('Hours',
                            totalHours.toStringAsFixed(0), Icons.access_time),
                        _buildMobileStatItem(
                            'Rate',
                            '${completionRate.toStringAsFixed(0)}%',
                            Icons.trending_up),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Primary: $primaryInstructor',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                    if (graduationDate != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            'Graduated: ${DateFormat('MMM dd, yyyy').format(graduationDate)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.blue[600]),
        SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildDesktopView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: MediaQuery.of(context).size.width,
        child: DataTable(
          headingRowColor:
              MaterialStateColor.resolveWith((states) => Colors.grey[100]!),
          columns: [
            DataColumn(
                label: Text('Alumni',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Graduation Date',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Lessons',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Hours',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Primary Instructor',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Completion Rate',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Actions',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredAlumni.map((data) {
            final user = data['user'] as User;
            final graduationDate = data['graduation_date'] as DateTime?;
            final totalLessons = data['total_lessons'] as int;
            final totalHours = data['total_hours'] as double;
            final primaryInstructor = data['primary_instructor'] as String;
            final completionRate = data['completion_rate'] as double;

            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          '${user.fname[0]}${user.lname[0]}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700]),
                        ),
                      ),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${user.fname} ${user.lname}',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(user.email,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    graduationDate != null
                        ? DateFormat('MMM dd, yyyy').format(graduationDate)
                        : 'Not recorded',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                DataCell(
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      totalLessons.toString(),
                      style: TextStyle(
                          color: Colors.blue[800], fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                DataCell(
                  Text('${totalHours.toStringAsFixed(1)}h',
                      style: TextStyle(fontSize: 13)),
                ),
                DataCell(
                  Text(primaryInstructor, style: TextStyle(fontSize: 13)),
                ),
                DataCell(
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: completionRate / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: completionRate >= 80
                                  ? Colors.green
                                  : completionRate >= 60
                                      ? Colors.orange
                                      : Colors.red,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('${completionRate.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.visibility,
                            size: 18, color: Colors.blue),
                        onPressed: () => _showAlumniDetails(data),
                        tooltip: 'View Details',
                      ),
                      IconButton(
                        icon: Icon(Icons.school, size: 18, color: Colors.green),
                        onPressed: () => _reactivateStudent(user),
                        tooltip: 'Reactivate as Student',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No Alumni Found',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Graduate your first student to see them here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showAlumniDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _AlumniDetailsDialog(
        data: data,
        onReactivate: _reactivateStudent,
      ),
    );
  }

  Future<void> _reactivateStudent(User alumni) async {
    try {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Reactivate Student'),
                content: Text(
                  'Are you sure you want to reactivate ${alumni.fname} ${alumni.lname} as an active student?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: Text('Reactivate'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirmed) return;

      // Validate that we have a valid alumni object
      if (alumni.id == null) {
        throw Exception('Invalid student data');
      }

      final reactivatedStudent = User(
        id: alumni.id,
        schoolId: alumni.schoolId, // ✅ Preserve school_id
        firebaseUserId: alumni.firebaseUserId, // ✅ Preserve firebase_user_id
        fname: alumni.fname,
        lname: alumni.lname,
        email: alumni.email,
        password: alumni.password,
        phone: alumni.phone,
        address: alumni.address,
        date_of_birth: alumni.date_of_birth,
        gender: alumni.gender,
        idnumber: alumni.idnumber,
        role: 'student',
        status: 'Active',
        created_at: alumni.created_at,
      );

      await DatabaseHelper.instance
          .updateUser(reactivatedStudent as Map<String, dynamic>);

      // Add timeline record
      final db = await DatabaseHelper.instance.database;
      await db.insert('timeline', {
        'studentId': alumni.id,
        'event_type': 'reactivation',
        'title': 'Student Reactivated',
        'description':
            'Alumni ${alumni.fname} ${alumni.lname} was reactivated as a student.',
        'created_at': DateTime.now().toIso8601String(),
        'created_by': Get.find<AuthController>().currentUser.value?.id ?? 0,
      });

      // Refresh data
      await userController.fetchUsers();
      await _loadEnhancedAlumniData();

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Success',
        '${alumni.fname} ${alumni.lname} has been reactivated as a student.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      print('Error reactivating student: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Failed to reactivate student: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }
}

class _AlumniDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(User) onReactivate;

  const _AlumniDetailsDialog({
    required this.data,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final user = data['user'] as User;
    final graduationDate = data['graduation_date'] as DateTime?;
    final instructorBreakdown =
        data['instructor_breakdown'] as Map<String, dynamic>;
    final courseBreakdown = data['course_breakdown'] as Map<String, dynamic>;
    final lessonTypeBreakdown =
        data['lesson_type_breakdown'] as Map<String, int>;
    final paymentSummary = data['payment_summary'] as Map<String, dynamic>;
    final stats = data['stats'] as Map<String, dynamic>;
    final trainingDuration = data['training_duration'] as String;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    '${user.fname[0]}${user.lname[0]}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700]),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.fname} ${user.lname}',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(user.email,
                          style: TextStyle(color: Colors.grey[600])),
                      if (graduationDate != null)
                        Text(
                          'Graduated: ${DateFormat('MMMM dd, yyyy').format(graduationDate)}',
                          style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Training Overview
                    _buildSection(
                      'Training Overview',
                      [
                        _buildStatRow(
                            'Total Lessons', '${data['total_lessons']}'),
                        _buildStatRow('Total Hours',
                            '${(data['total_hours'] as double).toStringAsFixed(1)}h'),
                        _buildStatRow('Training Duration', trainingDuration),
                        _buildStatRow('Completion Rate',
                            '${(data['completion_rate'] as double).toStringAsFixed(0)}%'),
                        _buildStatRow(
                            'Attendance Rate', '${stats['attendance_rate']}%'),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Lesson Breakdown
                    _buildSection(
                      'Lesson Breakdown',
                      [
                        _buildStatRow('Theory Lessons',
                            '${lessonTypeBreakdown['theory']}'),
                        _buildStatRow('Practical Lessons',
                            '${lessonTypeBreakdown['practical']}'),
                        if (lessonTypeBreakdown['other']! > 0)
                          _buildStatRow('Other Lessons',
                              '${lessonTypeBreakdown['other']}'),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Instructor Information
                    _buildSection(
                      'Instructor Information',
                      [
                        Text(
                            'Worked with ${instructorBreakdown['total_instructors']} instructor(s)'),
                        SizedBox(height: 12),
                        ...(instructorBreakdown['instructors']
                                as List<Map<String, dynamic>>)
                            .map((instrData) {
                          final instructor = instrData['instructor'] as User;
                          final lessons = instrData['lessons'] as int;
                          final hours = instrData['hours'] as double;
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${instructor.fname} ${instructor.lname}',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '$lessons lessons • ${hours.toStringAsFixed(1)} hours',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                                Text(
                                  'Theory: ${instrData['theory_lessons']} • Practical: ${instrData['practical_lessons']}',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Course Information
                    _buildSection(
                      'Course Information',
                      [
                        Text(
                            'Enrolled in ${courseBreakdown['total_courses']} course(s)'),
                        SizedBox(height: 12),
                        ...(courseBreakdown['courses']
                                as List<Map<String, dynamic>>)
                            .map((courseData) {
                          final course = courseData['course'] as Course;
                          final completed =
                              courseData['lessons_completed'] as int;
                          final paid = courseData['lessons_paid'] as int;
                          final amount = courseData['amount_paid'] as double;
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.name,
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Completed: $completed/$paid lessons',
                                  style: TextStyle(
                                      color: Colors.grey[700], fontSize: 12),
                                ),
                                Text(
                                  'Paid: \$${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: Colors.grey[700], fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Payment Summary
                    _buildSection(
                      'Payment Summary',
                      [
                        _buildStatRow('Total Invoices',
                            '${paymentSummary['total_invoices']}'),
                        _buildStatRow('Total Amount',
                            '\$${(paymentSummary['total_amount'] as double).toStringAsFixed(2)}'),
                        _buildStatRow('Amount Paid',
                            '\$${(paymentSummary['total_paid'] as double).toStringAsFixed(2)}'),
                        _buildStatRow('Outstanding',
                            '\$${(paymentSummary['outstanding_balance'] as double).toStringAsFixed(2)}'),
                        _buildStatRow('Lessons Paid For',
                            '${paymentSummary['total_lessons_paid']}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the details dialog
                    onReactivate(user); // Call the parent's reactivate method
                  },
                  icon: Icon(Icons.school, size: 18),
                  label: Text('Reactivate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800]),
        ),
        SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
