import 'package:driving/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class StudentDetailsScreen extends StatefulWidget {
  final int studentId;

  const StudentDetailsScreen({Key? key, required this.studentId})
      : super(key: key);

  @override
  _StudentDetailsScreenState createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen>
    with SingleTickerProviderStateMixin {
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final BillingController billingController = Get.find<BillingController>();
  final AuthController authController = Get.find<AuthController>();

  User? student;
  final TextEditingController _noteController = TextEditingController();
  List<Map<String, dynamic>> _studentNotes = [];
  List<Map<String, dynamic>> _studentAttachments = [];
  bool _isLoading = true;

  // Enhanced UX properties
  late TabController _tabController;
  bool _showPaymentReminder = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentNotes() async {
    final notes =
        await DatabaseHelper.instance.getNotesForStudent(widget.studentId);
    setState(() {
      _studentNotes = notes;
    });
  }

  Future<void> _fetchStudentAttachments() async {
    final attachments = await DatabaseHelper.instance
        .getAttachmentsForStudent(widget.studentId);
    setState(() {
      _studentAttachments = attachments;
    });
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final existingStudent = userController.users
          .firstWhereOrNull((user) => user.id == widget.studentId);

      if (existingStudent == null || userController.users.isEmpty) {
        await userController.fetchUsers();
      }

      await Future.wait([
        courseController.fetchCourses(),
        scheduleController.fetchSchedules(),
        billingController.fetchBillingData(),
        _fetchStudentNotes(),
        _fetchStudentAttachments(),
      ]);

      setState(() {
        student = userController.users
            .firstWhereOrNull((user) => user.id == widget.studentId);
        _isLoading = false;
        _showPaymentReminder = _checkPaymentReminder();
      });

      if (student == null) {
        Get.snackbar(
          'Error',
          'Student not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load student data: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  bool _checkPaymentReminder() {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == widget.studentId)
        .toList();

    final totalBalance = studentInvoices.fold<double>(
        0.0, (sum, invoice) => sum + invoice.balance);

    return totalBalance > 0;
  }

  Future<void> _addNote() async {
    if (_noteController.text.isNotEmpty) {
      try {
        await DatabaseHelper.instance.insertNote({
          'note_for': widget.studentId,
          'note': _noteController.text,
          'note_by': authController.currentUser.value?.id ?? 0,
        });
        _noteController.clear();
        await _fetchStudentNotes();
        Get.snackbar(
          'Success',
          'Note added successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to add note: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
          SizedBox(height: 16),
          Text(
            'Loading student details...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          SizedBox(height: 16),
          Text(
            'Student not found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'The student you\'re looking for doesn\'t exist.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.arrow_back),
            label: Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade600, Colors.blue.shade800],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
          children: [
            // App Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                  Expanded(
                    child: Text(
                      'Student Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => _showOptionsMenu(),
                  ),
                ],
              ),
            ),

            // Profile Section
            Flexible(
              // Wrap with Flexible to prevent overflow
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8), // Reduced vertical padding
                child: Row(
                  children: [
                    // Enhanced Avatar with Progress Ring
                    Stack(
                      children: [
                        Container(
                          width: 70, // Reduced size
                          height: 70, // Reduced size
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: CircularProgressIndicator(
                            value: _getProgressPercentage(),
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            margin: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade300,
                                  Colors.blue.shade500
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${student!.fname[0]}${student!.lname[0]}'
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 22, // Reduced font size
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20, // Reduced size
                            height: 20, // Reduced size
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: student!.status.toLowerCase() == 'active'
                                  ? Colors.green.shade400
                                  : Colors.orange.shade400,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              student!.status.toLowerCase() == 'active'
                                  ? Icons.check
                                  : Icons.pause,
                              color: Colors.white,
                              size: 10, // Reduced icon size
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(width: 16),

                    // Student Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, // Add this
                        children: [
                          Text(
                            '${student!.fname} ${student!.lname}',
                            style: TextStyle(
                              fontSize: 20, // Reduced font size
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1, // Add maxLines
                            overflow:
                                TextOverflow.ellipsis, // Add overflow handling
                          ),
                          SizedBox(height: 2), // Reduced spacing
                          Text(
                            'ID: ${student!.idnumber}',
                            style: TextStyle(
                              fontSize: 14, // Reduced font size
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: 6), // Reduced spacing
                          Wrap(
                            // Use Wrap instead of Row for better responsiveness
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4), // Reduced padding
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(
                                      16), // Reduced radius
                                ),
                                child: Text(
                                  student!.status,
                                  style: TextStyle(
                                    fontSize: 11, // Reduced font size
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (_showPaymentReminder)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade500,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning,
                                          color: Colors.white,
                                          size: 10), // Reduced icon size
                                      SizedBox(width: 2), // Reduced spacing
                                      Text(
                                        'Payment Due',
                                        style: TextStyle(
                                          fontSize: 9, // Reduced font size
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Quick Stats Row - Fixed overflow issue
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildQuickStat(
                    'Progress',
                    '${(_getProgressPercentage() * 100).toInt()}%',
                    Icons.trending_up,
                  ),
                  _buildQuickStat(
                    'Lessons',
                    '${_getCompletedLessonsCount()}/${_getTotalLessonsCount()}',
                    Icons.school,
                  ),
                  _buildQuickStat(
                    'Next Lesson',
                    _getNextLessonDate(),
                    Icons.schedule,
                  ),
                ],
              ),
            ),

            SizedBox(height: 12), // Reduced bottom spacing
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10), // Reduced padding
        margin: EdgeInsets.symmetric(horizontal: 3), // Reduced margin
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10), // Reduced radius
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Add this
          children: [
            Icon(icon, color: Colors.white, size: 18), // Reduced icon size
            SizedBox(height: 3), // Reduced spacing
            Text(
              value,
              style: TextStyle(
                fontSize: 12, // Reduced font size
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1, // Add maxLines
              overflow: TextOverflow.ellipsis, // Add overflow handling
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9, // Reduced font size
                color: Colors.white.withOpacity(0.8),
              ),
              maxLines: 1, // Add maxLines
              overflow: TextOverflow.ellipsis, // Add overflow handling
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.blue.shade600,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.blue.shade600,
        indicatorWeight: 3,
        labelStyle: TextStyle(fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            icon: Icon(Icons.dashboard),
            text: 'Overview',
          ),
          Tab(
            icon: Icon(Icons.schedule),
            text: 'Schedule (${_getUpcomingLessonsCount()})',
          ),
          Tab(
            icon: Icon(Icons.trending_up),
            text: 'Progress',
          ),
          Tab(
            icon: Icon(Icons.payment),
            text: 'Billing',
          ),
          Tab(
            icon: Icon(Icons.note),
            text: 'Notes (${_studentNotes.length})',
          ),
          Tab(
            icon: Icon(Icons.attach_file),
            text: 'Files (${_studentAttachments.length})',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 35),
          _buildPersonalInfoCard(),
          SizedBox(height: 16),
          _buildLearningStatsCard(),
          SizedBox(height: 16),
          _buildRecentActivityCard(),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.person, color: Colors.blue.shade600),
        title: Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(Icons.email, 'Email', student!.email),
                _buildInfoRow(Icons.phone, 'Phone', student!.phone),
                _buildInfoRow(Icons.location_on, 'Address', student!.address),
                _buildInfoRow(Icons.calendar_today, 'Date of Birth',
                    DateFormat('MMM dd, yyyy').format(student!.date_of_birth)),
                _buildInfoRow(Icons.wc, 'Gender', student!.gender),
                _buildInfoRow(Icons.schedule, 'Member Since',
                    DateFormat('MMM dd, yyyy').format(student!.created_at)),
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
          Icon(icon, size: 20, color: Colors.grey.shade600),
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Learning Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Completed Lessons',
                    _getCompletedLessonsCount().toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Remaining Lessons',
                    _getRemainingLessonsCount().toString(),
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Attendance Rate',
                    '${_getAttendanceRate()}%',
                    Icons.person_pin_circle,
                    Colors.purple,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Overall Progress',
                    '${(_getProgressPercentage() * 100).toInt()}%',
                    Icons.trending_up,
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

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final recentSchedules = scheduleController.schedules
        .where((s) => s.studentId == widget.studentId)
        .take(3)
        .toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                Spacer(),
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: Text('View All'),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (recentSchedules.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No recent activity',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ...recentSchedules
                  .map((schedule) => _buildActivityItem(schedule)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(schedule) {
    final instructor = userController.users.firstWhereOrNull(
      (user) => user.id == schedule.instructorId,
    );

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getScheduleStatusColor(schedule.status),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.classType ?? 'Lesson',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'with ${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? 'Instructor'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM dd').format(schedule.start),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    final studentSchedules = scheduleController.schedules
        .where((schedule) => schedule.studentId == widget.studentId)
        .toList();

    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search schedules...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              SizedBox(width: 16),
              PopupMenuButton<String>(
                icon: Icon(Icons.filter_list),
                onSelected: (value) {
                  setState(() {});
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'all', child: Text('All')),
                  PopupMenuItem(value: 'scheduled', child: Text('Scheduled')),
                  PopupMenuItem(value: 'completed', child: Text('Completed')),
                  PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: studentSchedules.isEmpty
              ? _buildEmptyState(
                  'No schedules found',
                  'This student has no scheduled lessons yet.',
                  Icons.schedule,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: studentSchedules.length,
                  itemBuilder: (context, index) {
                    final schedule = studentSchedules[index];
                    return _buildEnhancedScheduleCard(schedule);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEnhancedScheduleCard(schedule) {
    final instructor = userController.users.firstWhereOrNull(
      (user) => user.id == schedule.instructorId,
    );

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showScheduleDetails(schedule),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getScheduleStatusColor(schedule.status),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      schedule.classType ?? 'Driving Lesson',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getScheduleStatusColor(schedule.status)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      schedule.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getScheduleStatusColor(schedule.status),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    '${DateFormat.yMd().add_jm().format(schedule.start)} - ${DateFormat.jm().format(schedule.end)}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    'Instructor: ${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? 'Instructor'}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressOverviewCard(),
          SizedBox(height: 16),
          _buildLessonHistoryCard(),
        ],
      ),
    );
  }

  Widget _buildProgressOverviewCard() {
    final completedLessons = _getCompletedLessonsCount();
    final totalLessons = _getTotalLessonsCount();
    final progressPercentage = _getProgressPercentage();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Learning Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: progressPercentage,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${(progressPercentage * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        'Complete',
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
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressStat(
                    'Completed', completedLessons.toString(), Colors.green),
                _buildProgressStat(
                    'Remaining',
                    (totalLessons - completedLessons).toString(),
                    Colors.orange),
                _buildProgressStat(
                    'Attendance', '${_getAttendanceRate()}%', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLessonHistoryCard() {
    final recentLessons = scheduleController.schedules
        .where((s) =>
            s.studentId == widget.studentId &&
            s.status.toLowerCase() == 'completed')
        .take(5)
        .toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Recent Lessons',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (recentLessons.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No completed lessons yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ...recentLessons.map((lesson) => _buildLessonHistoryItem(lesson)),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonHistoryItem(lesson) {
    final instructor = userController.users.firstWhereOrNull(
      (user) => user.id == lesson.instructorId,
    );

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.classType ?? 'Driving Lesson',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  'with ${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? 'Instructor'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('MMM dd').format(lesson.start),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '${lesson.lessonsDeducted ?? 1} lesson${lesson.lessonsDeducted == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillingTab() {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == widget.studentId)
        .toList();

    final totalBalance = studentInvoices.fold<double>(
        0.0, (sum, invoice) => sum + invoice.balance);
    final totalPaid = studentInvoices.fold<double>(
        0.0,
        (sum, invoice) =>
            sum + (invoice.totalAmountCalculated - invoice.balance));
    final totalAmount = studentInvoices.fold<double>(
        0.0, (sum, invoice) => sum + invoice.totalAmountCalculated);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Billing Summary
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          color: Colors.blue.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Billing Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBillingSummaryItem(
                          'Total Amount',
                          '\$${totalAmount.toStringAsFixed(2)}',
                          Colors.blue,
                          Icons.receipt_long,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildBillingSummaryItem(
                          'Paid',
                          '\$${totalPaid.toStringAsFixed(2)}',
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBillingSummaryItem(
                          'Outstanding',
                          '\$${totalBalance.toStringAsFixed(2)}',
                          totalBalance > 0 ? Colors.red : Colors.green,
                          totalBalance > 0 ? Icons.warning : Icons.check_circle,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                value: totalAmount > 0
                                    ? totalPaid / totalAmount
                                    : 0,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue.shade600),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${totalAmount > 0 ? ((totalPaid / totalAmount) * 100).toInt() : 0}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              Text(
                                'Paid',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Payment Reminder
          if (totalBalance > 0)
            Card(
              elevation: 2,
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade600),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Reminder',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                          Text(
                            'Outstanding balance of \$${totalBalance.toStringAsFixed(2)} needs to be cleared.',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (totalBalance > 0) SizedBox(height: 16),

          // Invoice Details
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt, color: Colors.blue.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Invoice Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (studentInvoices.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No invoices found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...studentInvoices
                        .map((invoice) => _buildInvoiceItem(invoice)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingSummaryItem(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(invoice) {
    final course = courseController.courses.firstWhereOrNull(
      (c) => c.id == invoice.courseId,
    );

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                course?.name ?? 'Unknown Course',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: invoice.balance > 0
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  invoice.balance > 0 ? 'Pending' : 'Paid',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: invoice.balance > 0
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount:',
                  style: TextStyle(color: Colors.grey.shade600)),
              Text('\$${invoice.totalAmountCalculated.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Balance:', style: TextStyle(color: Colors.grey.shade600)),
              Text('\$${invoice.balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: invoice.balance > 0 ? Colors.red : Colors.green,
                  )),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: invoice.totalAmountCalculated > 0
                ? (invoice.totalAmountCalculated - invoice.balance) /
                    invoice.totalAmountCalculated
                : 0,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return Column(
      children: [
        // Add Note Section
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Note',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'Enter your note here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _addNote,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Notes List
        Expanded(
          child: _studentNotes.isEmpty
              ? _buildEmptyState(
                  'No notes yet',
                  'Add your first note about this student.',
                  Icons.note_add,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _studentNotes.length,
                  itemBuilder: (context, index) {
                    final note = _studentNotes[index];
                    return _buildNoteCard(note);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.note,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note['note'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(
                          DateTime.parse(note['created_at']),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      // Text(note['note_by']?.toString() ?? 'Unknown User',
                      //     style: TextStyle(
                      //       fontSize: 12,
                      //       color: Colors.grey.shade600,
                      //     )),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteNote(note['id']);
                    } else if (value == 'edit') {
                      _editNote(note);
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              note['content'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsTab() {
    return Column(
      children: [
        // Upload Section
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Attachments (${_studentAttachments.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _uploadFile,
                icon: Icon(Icons.upload_file, size: 16),
                label: Text('Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Attachments List
        Expanded(
          child: _studentAttachments.isEmpty
              ? _buildEmptyState(
                  'No attachments',
                  'Upload documents, images, or other files.',
                  Icons.attach_file,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _studentAttachments.length,
                  itemBuilder: (context, index) {
                    final attachment = _studentAttachments[index];
                    return _buildAttachmentCard(attachment);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttachmentCard(Map<String, dynamic> attachment) {
    final fileName = attachment['file_name'] ?? 'Unknown File';
    final fileExtension = fileName.split('.').last.toLowerCase();

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getFileTypeColor(fileExtension).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getFileTypeIcon(fileExtension),
            color: _getFileTypeColor(fileExtension),
          ),
        ),
        title: Text(
          fileName,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Uploaded on ${DateFormat('MMM dd, yyyy').format(
            DateTime.parse(attachment['created_at']),
          )}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'download',
              child: Row(
                children: [
                  Icon(Icons.download, size: 16),
                  SizedBox(width: 8),
                  Text('Download'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'download') {
              _downloadFile(attachment);
            } else if (value == 'delete') {
              _deleteAttachment(attachment['id']);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods for calculations
  double _getProgressPercentage() {
    final totalLessons = _getTotalLessonsCount();
    if (totalLessons == 0) return 0.0;
    final completedLessons = _getCompletedLessonsCount();
    return completedLessons / totalLessons;
  }

  int _getCompletedLessonsCount() {
    return scheduleController.schedules
        .where((s) =>
            s.studentId == widget.studentId &&
            s.status.toLowerCase() == 'completed')
        .fold<int>(0, (sum, s) => sum + (s.lessonsDeducted));
  }

  int _getTotalLessonsCount() {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == widget.studentId)
        .toList();

    return studentInvoices.fold<int>(
        0, (sum, invoice) => sum + invoice.lessons);
  }

  int _getRemainingLessonsCount() {
    return _getTotalLessonsCount() - _getCompletedLessonsCount();
  }

  int _getAttendanceRate() {
    final totalScheduled = scheduleController.schedules
        .where((s) => s.studentId == widget.studentId)
        .length;

    if (totalScheduled == 0) return 100;

    final attended = scheduleController.schedules
        .where((s) => s.studentId == widget.studentId && s.attended == true)
        .length;

    return ((attended / totalScheduled) * 100).round();
  }

  int _getUpcomingLessonsCount() {
    final now = DateTime.now();
    return scheduleController.schedules
        .where((s) => s.studentId == widget.studentId && s.start.isAfter(now))
        .length;
  }

  String _getNextLessonDate() {
    final now = DateTime.now();
    final nextLesson = scheduleController.schedules
        .where((s) => s.studentId == widget.studentId && s.start.isAfter(now))
        .fold<DateTime?>(null, (earliest, s) {
      if (earliest == null || s.start.isBefore(earliest)) {
        return s.start;
      }
      return earliest;
    });

    if (nextLesson == null) return '0';

    final difference = nextLesson.difference(now).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    return DateFormat('MMM dd').format(nextLesson);
  }

  Color _getScheduleStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getFileTypeIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor(String extension) {
    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'jpg':
      case 'jpeg':
        return Colors.green;
      case 'png':
        return Colors.green;
      case 'xls':
      case 'xlsx':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Action methods
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title:
                  Text('Delete Student', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Use context here
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    // Show delete confirmation dialog
    Get.dialog(
      AlertDialog(
        title: Text('Delete Student'),
        content: Text(
            'Are you sure you want to delete this student? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _deleteStudent();
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteStudent() {
    // Delete student logic
    Get.snackbar('Info', 'Student deleted');
  }

  void _showScheduleDetails(schedule) {
    // Show schedule details dialog
    Get.snackbar('Info', 'Show schedule details');
  }

  void _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        // Handle file upload
        Get.snackbar('Success', 'File uploaded successfully');
        await _fetchStudentAttachments();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload file');
    }
  }

  void _downloadFile(Map<String, dynamic> attachment) {
    // Download file logic
    Get.snackbar('Info', 'Downloading ${attachment['file_name']}');
  }

  void _deleteAttachment(int attachmentId) {
    // Delete attachment logic
    Get.snackbar('Info', 'Attachment deleted');
  }

  void _editNote(Map<String, dynamic> note) {
    // Edit note logic
    Get.snackbar('Info', 'Edit note functionality');
  }

  void _deleteNote(int noteId) {
    // Delete note logic
    Get.snackbar('Info', 'Note deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingState()
          : student == null
              ? _buildErrorState()
              : NestedScrollView(
                  headerSliverBuilder:
                      (BuildContext context, bool innerBoxIsScrolled) {
                    return <Widget>[
                      SliverAppBar(
                        expandedHeight: 250.0,
                        floating: false,
                        pinned: false,
                        flexibleSpace: FlexibleSpaceBar(
                          background: _buildEnhancedHeader(),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          child: _buildEnhancedTabBar(),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      // Wrap each tab with proper overflow handling
                      _buildSafeTab(_buildOverviewTab()),
                      _buildSafeTab(_buildScheduleTab()),
                      _buildSafeTab(_buildProgressTab()),
                      _buildSafeTab(_buildBillingTab()),
                      _buildSafeTab(_buildNotesTab()),
                      _buildSafeTab(_buildAttachmentsTab()),
                    ],
                  ),
                ),
    );
  }

// Add this helper method to wrap tabs with overflow protection
  Widget _buildSafeTab(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              maxWidth: constraints.maxWidth,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate({required this.child});

  @override
  double get minExtent => 60.0; // Height of the tab bar

  @override
  double get maxExtent => 60.0; // Height of the tab bar

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
