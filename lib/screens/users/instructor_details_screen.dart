import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/models/fleet.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class InstructorDetailsScreen extends StatefulWidget {
  final int instructorId;

  const InstructorDetailsScreen({Key? key, required this.instructorId})
      : super(key: key);

  @override
  _InstructorDetailsScreenState createState() =>
      _InstructorDetailsScreenState();
}

class _InstructorDetailsScreenState extends State<InstructorDetailsScreen>
    with SingleTickerProviderStateMixin {
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final FleetController fleetController = Get.find<FleetController>();
  final AuthController authController = Get.find<AuthController>();

  User? instructor;
  TabController? _tabController;
  bool _isLoading = true;

  // Mock data for demonstration - replace with actual data fetching
  List<Map<String, dynamic>> _instructorNotes = [];
  List<Map<String, dynamic>> _instructorAttachments = [];
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchInstructorData();
    _fetchInstructorNotes();
    _fetchInstructorAttachments();
  }

  // Check if we should show mobile layout
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  // Check if we should show tablet layout
  bool _isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1024;
  }

  Future<void> _fetchInstructorData() async {
    try {
      await userController.fetchUsers();
      instructor = userController.users.firstWhereOrNull(
        (user) => user.id == widget.instructorId && user.role == 'instructor',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchInstructorNotes() async {
    // Simulate fetching notes
    _instructorNotes = [
      {
        'id': 1,
        'content': 'Excellent instructor with great student feedback',
        'created_at': DateTime.now().subtract(Duration(days: 2)),
        'author': 'Admin'
      },
    ];
  }

  Future<void> _fetchInstructorAttachments() async {
    // Simulate fetching attachments
    _instructorAttachments = [
      {
        'id': 1,
        'file_name': 'instructor_certificate.pdf',
        'file_size': '2.3 MB',
        'uploaded_at': DateTime.now().subtract(Duration(days: 10)),
      },
    ];
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isMobile(context)) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingState()
          : instructor == null
              ? _buildErrorState()
              : Column(
                  children: [
                    // Mobile Header
                    Container(
                      height: 290.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade400
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: _buildMobileHeader(),
                      ),
                    ),
                    // Mobile Tab Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            spreadRadius: 1,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildMobileTabBar(),
                    ),
                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildScheduleTab(),
                          _buildVehicleTab(),
                          _buildNotesTab(),
                          _buildAttachmentsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingState()
          : instructor == null
              ? _buildErrorState()
              : NestedScrollView(
                  headerSliverBuilder:
                      (BuildContext context, bool innerBoxIsScrolled) {
                    return [
                      // Header that scrolls away
                      SliverAppBar(
                        expandedHeight: _isTablet(context) ? 250.0 : 290.0,
                        floating: false,
                        pinned: false,
                        backgroundColor: Colors.green.shade600,
                        flexibleSpace: FlexibleSpaceBar(
                          background: _buildEnhancedHeader(),
                          collapseMode: CollapseMode.pin,
                        ),
                      ),
                      // Sticky tab bar - this stays fixed when scrolling
                      SliverPersistentHeader(
                        pinned: true, // This makes the tab bar stick
                        delegate: _StickyTabBarDelegate(
                          child: _buildEnhancedTabBar(),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildScheduleTab(),
                      _buildVehicleTab(),
                      _buildNotesTab(),
                      _buildAttachmentsTab(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      height: 290.0, // Fixed height for the header
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        // Add scrolling if content overflows
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Important to prevent infinite height
          children: [
            // Top Row with back button
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showOptionsMenu(),
                ),
              ],
            ),

            SizedBox(height: 12), // Reduced from 20

            // Profile section
            Row(
              children: [
                // Avatar
                Container(
                  width: 70, // Reduced from 80
                  height: 70, // Reduced from 80
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30, // Reduced from 35
                        backgroundColor: Colors.white,
                        child: Text(
                          instructor!.fname[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 24, // Reduced from 28
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ),
                      // Status indicator
                      Positioned(
                        bottom: 2, // Adjusted position
                        right: 2, // Adjusted position
                        child: Container(
                          width: 16, // Reduced from 20
                          height: 16, // Reduced from 20
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: instructor!.status.toLowerCase() == 'active'
                                ? Colors.green.shade400
                                : Colors.orange.shade400,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            instructor!.status.toLowerCase() == 'active'
                                ? Icons.check
                                : Icons.pause,
                            color: Colors.white,
                            size: 10, // Reduced from 12
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 12), // Reduced from 16

                // Instructor Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${instructor!.fname} ${instructor!.lname}',
                        style: TextStyle(
                          fontSize: 18, // Reduced from 20
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2), // Reduced from 4
                      Text(
                        'ID: ${instructor!.idnumber}',
                        style: TextStyle(
                          fontSize: 12, // Reduced from 14
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      SizedBox(height: 6), // Reduced from 8
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4), // Reduced padding
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          instructor!.status,
                          style: TextStyle(
                            fontSize: 10, // Reduced from 12
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12), // Reduced from 20

            // Mobile Quick Stats
            Row(
              children: [
                _buildMobileQuickStat(
                  'Students',
                  _getActiveStudentsCount().toString(),
                  Icons.people,
                ),
                _buildMobileQuickStat(
                  'Lessons',
                  _getTotalLessonsCount().toString(),
                  Icons.school,
                ),
                _buildMobileQuickStat(
                  'This Week',
                  _getWeeklyLessonsCount().toString(),
                  Icons.calendar_today,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileQuickStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8), // Reduced vertical padding
        margin: EdgeInsets.symmetric(horizontal: 2), // Reduced margin
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8), // Smaller radius
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important for Column
          children: [
            Icon(icon, color: Colors.white, size: 16), // Reduced from 18
            SizedBox(height: 2), // Reduced from 4
            Text(
              value,
              style: TextStyle(
                fontSize: 14, // Reduced from 16
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9, // Reduced from 10
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: Colors.green.shade600,
      unselectedLabelColor: Colors.grey.shade600,
      indicatorColor: Colors.green.shade600,
      indicatorWeight: 3,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      labelPadding: EdgeInsets.symmetric(horizontal: 12),
      tabs: [
        Tab(
          icon: Icon(Icons.info_outline, size: 20),
          text: 'Overview',
        ),
        Tab(
          icon: Icon(Icons.schedule, size: 20),
          text: 'Schedule',
        ),
        Tab(
          icon: Icon(Icons.directions_car, size: 20),
          text: 'Vehicle',
        ),
        Tab(
          icon: Icon(Icons.note, size: 20),
          text: 'Notes',
        ),
        Tab(
          icon: Icon(Icons.attach_file, size: 20),
          text: 'Files',
        ),
      ],
    );
  }

  Widget _buildEnhancedHeader() {
    final isSmallScreen = _isTablet(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Column(
            children: [
              // Top Row
              Row(
                children: [
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => _showOptionsMenu(),
                  ),
                ],
              ),

              SizedBox(height: isSmallScreen ? 15 : 20),

              // Profile section
              Row(
                children: [
                  // Avatar
                  Container(
                    width: isSmallScreen ? 90 : 100,
                    height: isSmallScreen ? 90 : 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: isSmallScreen ? 40 : 45,
                          backgroundColor: Colors.white,
                          child: Text(
                            instructor!.fname[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 30 : 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ),
                        // Status indicator
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  instructor!.status.toLowerCase() == 'active'
                                      ? Colors.green.shade400
                                      : Colors.orange.shade400,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              instructor!.status.toLowerCase() == 'active'
                                  ? Icons.check
                                  : Icons.pause,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 16),

                  // Instructor Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${instructor!.fname} ${instructor!.lname}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 22 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ID: ${instructor!.idnumber}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            instructor!.status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: isSmallScreen ? 15 : 20),

              // Quick Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickStat(
                    'Students',
                    _getActiveStudentsCount().toString(),
                    Icons.people,
                  ),
                  _buildQuickStat(
                    'Lessons',
                    _getTotalLessonsCount().toString(),
                    Icons.school,
                  ),
                  _buildQuickStat(
                    'This Week',
                    _getWeeklyLessonsCount().toString(),
                    Icons.calendar_today,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    final isSmallScreen = _isTablet(context);

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTabBar() {
    final isSmallScreen = _isTablet(context);

    return Material(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.green.shade600,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.green.shade600,
        indicatorWeight: 3,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isSmallScreen ? 13 : 14,
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
        tabs: [
          Tab(
            icon: Icon(Icons.info_outline),
            text: 'Overview',
          ),
          Tab(
            icon: Icon(Icons.schedule),
            text: 'Schedule (${_getUpcomingSchedulesCount()})',
          ),
          Tab(
            icon: Icon(Icons.directions_car),
            text: 'Vehicle',
          ),
          Tab(
            icon: Icon(Icons.note),
            text: 'Notes (${_instructorNotes.length})',
          ),
          Tab(
            icon: Icon(Icons.attach_file),
            text: 'Files (${_instructorAttachments.length})',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final isSmallScreen = _isMobile(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isSmallScreen ? 15 : 25),
          _buildPersonalInfoCard(),
          SizedBox(height: 16),
          _buildPerformanceCard(),
          SizedBox(height: 16),
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    final isSmallScreen = _isMobile(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.person, color: Colors.green.shade600),
        title: Text(
          'Personal Information',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        initiallyExpanded: !isSmallScreen,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(Icons.email, 'Email', instructor!.email),
                _buildInfoRow(Icons.phone, 'Phone', instructor!.phone),
                _buildInfoRow(
                    Icons.location_on, 'Address', instructor!.address),
                _buildInfoRow(
                    Icons.calendar_today,
                    'Date of Birth',
                    DateFormat('MMM dd, yyyy')
                        .format(instructor!.date_of_birth)),
                _buildInfoRow(Icons.wc, 'Gender', instructor!.gender),
                _buildInfoRow(Icons.schedule, 'Member Since',
                    DateFormat('MMM dd, yyyy').format(instructor!.created_at)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isSmallScreen = _isMobile(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: isSmallScreen
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(left: 24),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            )
          : Row(
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

  Widget _buildPerformanceCard() {
    final isSmallScreen = _isMobile(context);

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
                Icon(Icons.trending_up, color: Colors.green.shade600),
                SizedBox(width: 8),
                Text(
                  'Performance Metrics',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Responsive grid
            if (isSmallScreen)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Active Students',
                          _getActiveStudentsCount().toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          'Total Lessons',
                          _getTotalLessonsCount().toString(),
                          Icons.school,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'This Month',
                          _getMonthlyLessonsCount().toString(),
                          Icons.calendar_view_month,
                          Colors.purple,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          'Completion Rate',
                          '${_getCompletionRate()}%',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Active Students',
                          _getActiveStudentsCount().toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          'Total Lessons',
                          _getTotalLessonsCount().toString(),
                          Icons.school,
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
                          'This Month',
                          _getMonthlyLessonsCount().toString(),
                          Icons.calendar_view_month,
                          Colors.purple,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          'Completion Rate',
                          '${_getCompletionRate()}%',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
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
    final isSmallScreen = _isMobile(context);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isSmallScreen ? 24 : 28),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    final isSmallScreen = _isMobile(context);

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
                Icon(Icons.speed, color: Colors.green.shade600),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Responsive action buttons
            if (isSmallScreen)
              Column(
                children: [
                  _buildActionButton(
                    'Schedule Lesson',
                    Icons.add_circle,
                    Colors.blue,
                    () => _scheduleLesson(),
                  ),
                  SizedBox(height: 8),
                  _buildActionButton(
                    'Assign Vehicle',
                    Icons.directions_car,
                    Colors.orange,
                    () => _assignVehicle(),
                  ),
                  SizedBox(height: 8),
                  _buildActionButton(
                    'Send Message',
                    Icons.message,
                    Colors.green,
                    () => _sendMessage(),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Schedule Lesson',
                      Icons.add_circle,
                      Colors.blue,
                      () => _scheduleLesson(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'Assign Vehicle',
                      Icons.directions_car,
                      Colors.orange,
                      () => _assignVehicle(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'Send Message',
                      Icons.message,
                      Colors.green,
                      () => _sendMessage(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(title, style: TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    final isSmallScreen = _isMobile(context);
    final instructorSchedules = scheduleController.schedules
        .where((schedule) => schedule.instructorId == widget.instructorId)
        .toList();

    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: isSmallScreen
              ? Column(
                  children: [
                    TextField(
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
                    SizedBox(height: 12),
                    PopupMenuButton<String>(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_list),
                            SizedBox(width: 8),
                            Text('Filter'),
                          ],
                        ),
                      ),
                      onSelected: (value) {
                        setState(() {});
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'all', child: Text('All')),
                        PopupMenuItem(
                            value: 'scheduled', child: Text('Scheduled')),
                        PopupMenuItem(
                            value: 'completed', child: Text('Completed')),
                        PopupMenuItem(
                            value: 'cancelled', child: Text('Cancelled')),
                      ],
                    ),
                  ],
                )
              : Row(
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
                        PopupMenuItem(
                            value: 'scheduled', child: Text('Scheduled')),
                        PopupMenuItem(
                            value: 'completed', child: Text('Completed')),
                        PopupMenuItem(
                            value: 'cancelled', child: Text('Cancelled')),
                      ],
                    ),
                  ],
                ),
        ),

        Expanded(
          child: instructorSchedules.isEmpty
              ? _buildEmptyState(
                  'No schedules found',
                  'This instructor has no scheduled lessons yet.',
                  Icons.schedule,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  itemCount: instructorSchedules.length,
                  itemBuilder: (context, index) {
                    final schedule = instructorSchedules[index];
                    return _buildScheduleCard(schedule);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(schedule) {
    final isSmallScreen = _isMobile(context);

    // Get student name using studentId
    final student = userController.users.firstWhereOrNull(
      (user) =>
          user.id == schedule.studentId && user.role.toLowerCase() == 'student',
    );
    final studentName = student != null
        ? '${student.fname} ${student.lname}'
        : 'Unknown Student';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 16, color: Colors.grey.shade600),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${DateFormat.yMd().add_jm().format(schedule.start)} - ${DateFormat.jm().format(schedule.end)}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: isSmallScreen ? 13 : 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school,
                              size: 16, color: Colors.grey.shade600),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              schedule.classType,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: isSmallScreen ? 13 : 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isSmallScreen)
                  _buildStatusChip(schedule.status ?? 'scheduled'),
              ],
            ),
            if (isSmallScreen) ...[
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _buildStatusChip(schedule.status ?? 'scheduled'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.toLowerCase() == 'completed'
                ? Icons.check_circle
                : status.toLowerCase() == 'cancelled'
                    ? Icons.cancel
                    : Icons.schedule,
            size: 16,
            color: color,
          ),
          SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTab() {
    final isSmallScreen = _isMobile(context);
    final assignedVehicle = fleetController.fleet.firstWhereOrNull(
      (vehicle) => vehicle.instructor == widget.instructorId,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      Icon(Icons.directions_car, color: Colors.green.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Assigned Vehicle',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Spacer(),
                      TextButton.icon(
                        onPressed: () => _assignVehicle(),
                        icon: Icon(Icons.edit, size: 14),
                        label: Text(''),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  assignedVehicle == null
                      ? _buildEmptyVehicleState()
                      : _buildVehicleDetails(assignedVehicle),
                ],
              ),
            ),
          ),
          if (assignedVehicle != null) ...[
            SizedBox(height: 16),
            _buildVehicleStatsCard(assignedVehicle),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyVehicleState() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Vehicle Assigned',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This instructor has not been assigned a vehicle yet.',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _assignVehicle(),
            child: Text('Assign Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetails(vehicle) {
    final isSmallScreen = _isMobile(context);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car,
                  color: Colors.green.shade600, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.make} ${vehicle.model}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    Text(
                      'License: ${vehicle.carPlate}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    Text(
                      'Year: ${vehicle.modelYear}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleStatsCard(vehicle) {
    final isSmallScreen = _isMobile(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Usage',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            SizedBox(height: 16),

            // Responsive stats layout
            if (isSmallScreen)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Total Lessons',
                          _getVehicleLessonsCount(vehicle.id).toString(),
                          Icons.school,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          'This Month',
                          _getVehicleMonthlyLessons(vehicle.id).toString(),
                          Icons.calendar_month,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildStatItem(
                    'Maintenance',
                    'Good',
                    Icons.build,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Total Lessons',
                      _getVehicleLessonsCount(vehicle.id).toString(),
                      Icons.school,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'This Month',
                      _getVehicleMonthlyLessons(vehicle.id).toString(),
                      Icons.calendar_month,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Maintenance',
                      'Good',
                      Icons.build,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final isSmallScreen = _isMobile(context);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon,
              color: Colors.green.shade600, size: isSmallScreen ? 20 : 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    final isSmallScreen = _isMobile(context);

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
                  color: Colors.green.shade800,
                ),
              ),
              SizedBox(height: 12),
              if (isSmallScreen)
                Column(
                  children: [
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter your note here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addNote,
                        child: Text('Add Note'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter your note here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _addNote,
                      child: Text('Add Note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Notes List
        Expanded(
          child: _instructorNotes.isEmpty
              ? _buildEmptyState(
                  'No notes yet',
                  'Add notes about this instructor\'s performance and behavior.',
                  Icons.note,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  itemCount: _instructorNotes.length,
                  itemBuilder: (context, index) {
                    final note = _instructorNotes[index];
                    return _buildNoteCard(note);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final isSmallScreen = _isMobile(context);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    note['author'][0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note['author'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy - hh:mm a')
                            .format(note['created_at']),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isSmallScreen ? 12 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editNote(note);
                    if (value == 'delete') _deleteNote(note['id']);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              note['content'],
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 15,
                height: 1.4,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: isSmallScreen ? 4 : 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsTab() {
    final isSmallScreen = _isMobile(context);

    return Column(
      children: [
        // Upload Section
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            children: [
              Text(
                'Instructor Documents',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _uploadFile,
                icon: Icon(Icons.upload_file),
                label: Text('Upload File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  minimumSize:
                      isSmallScreen ? Size(double.infinity, 48) : Size(200, 48),
                ),
              ),
            ],
          ),
        ),

        // Files List
        Expanded(
          child: _instructorAttachments.isEmpty
              ? _buildEmptyState(
                  'No files uploaded',
                  'Upload certificates, licenses, or other documents.',
                  Icons.attach_file,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  itemCount: _instructorAttachments.length,
                  itemBuilder: (context, index) {
                    final attachment = _instructorAttachments[index];
                    return _buildAttachmentCard(attachment);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttachmentCard(Map<String, dynamic> attachment) {
    final isSmallScreen = _isMobile(context);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.insert_drive_file,
            color: Colors.green.shade600,
          ),
        ),
        title: Text(
          attachment['file_name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 14 : 16,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Size: ${attachment['file_size']}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isSmallScreen ? 12 : 13,
              ),
            ),
            Text(
              'Uploaded: ${DateFormat('MMM dd, yyyy').format(attachment['uploaded_at'])}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isSmallScreen ? 12 : 13,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'download') _downloadFile(attachment);
            if (value == 'delete') _deleteAttachment(attachment['id']);
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'download', child: Text('Download')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Instructor Details'),
        backgroundColor: Colors.green.shade600,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading instructor details...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Instructor Not Found'),
        backgroundColor: Colors.green.shade600,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Instructor Not Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'The requested instructor could not be found.',
              style: TextStyle(color: Colors.grey[500]),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for data calculations
  int _getActiveStudentsCount() {
    return userController.users
        .where((user) =>
            user.role == 'student' && user.status.toLowerCase() == 'active')
        .length;
  }

  int _getTotalLessonsCount() {
    return scheduleController.schedules
        .where((schedule) => schedule.instructorId == widget.instructorId)
        .length;
  }

  int _getWeeklyLessonsCount() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(Duration(days: 6));

    return scheduleController.schedules
        .where((schedule) =>
            schedule.instructorId == widget.instructorId &&
            schedule.start.isAfter(weekStart) &&
            schedule.start.isBefore(weekEnd))
        .length;
  }

  int _getMonthlyLessonsCount() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    return scheduleController.schedules
        .where((schedule) =>
            schedule.instructorId == widget.instructorId &&
            schedule.start.isAfter(monthStart) &&
            schedule.start.isBefore(monthEnd))
        .length;
  }

  int _getCompletionRate() {
    final totalLessons = _getTotalLessonsCount();
    if (totalLessons == 0) return 0;

    final completedLessons = scheduleController.schedules
        .where((schedule) =>
            schedule.instructorId == widget.instructorId &&
            schedule.status?.toLowerCase() == 'completed')
        .length;

    return ((completedLessons / totalLessons) * 100).round();
  }

  int _getUpcomingSchedulesCount() {
    final now = DateTime.now();
    return scheduleController.schedules
        .where((schedule) =>
            schedule.instructorId == widget.instructorId &&
            schedule.start.isAfter(now))
        .length;
  }

  int _getVehicleLessonsCount(int vehicleId) {
    // This would typically fetch from a database
    // For now, return a mock value
    return 45;
  }

  int _getVehicleMonthlyLessons(int vehicleId) {
    // This would typically fetch from a database
    // For now, return a mock value
    return 12;
  }

  // Action methods
  void _showOptionsMenu() {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue),
              title: Text('Edit Instructor'),
              onTap: () {
                Get.back();
                _editInstructor();
              },
            ),
            ListTile(
              leading: Icon(Icons.message, color: Colors.green),
              title: Text('Send Message'),
              onTap: () {
                Get.back();
                _sendMessage();
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: Colors.orange),
              title: Text(instructor!.status.toLowerCase() == 'active'
                  ? 'Deactivate'
                  : 'Activate'),
              onTap: () {
                Get.back();
                _toggleStatus();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Instructor'),
              onTap: () {
                Get.back();
                _deleteInstructor();
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _scheduleLesson() {
    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Info',
        'Schedule lesson functionality');
  }

  void _assignVehicle() {
    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Info',
        'Assign vehicle functionality');
  }

  void _sendMessage() {
    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Info',
        'Send message functionality');
  }

  void _editInstructor() {
    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Info',
        'Edit instructor functionality');
  }

  void _toggleStatus() {
    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Info',
        'Toggle status functionality');
  }

  void _deleteInstructor() {
    Get.dialog(
      AlertDialog(
        title: Text('Delete Instructor'),
        content: Text('Are you sure you want to delete this instructor?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                  snackPosition: SnackPosition.BOTTOM,
                  'Info',
                  'Delete instructor functionality');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addNote() {
    if (_noteController.text.trim().isEmpty) {
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM, 'Error', 'Please enter a note');
      return;
    }

    setState(() {
      _instructorNotes.insert(0, {
        'id': DateTime.now().toUtc().millisecondsSinceEpoch,
        'content': _noteController.text.trim(),
        'created_at': DateTime.now(),
        'author': authController.currentUser.value?.fname ?? 'Admin',
      });
      _noteController.clear();
    });

    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Success',
        'Note added successfully');
  }

  void _editNote(Map<String, dynamic> note) {
    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM, 'Info', 'Edit note functionality');
  }

  void _deleteNote(int noteId) {
    setState(() {
      _instructorNotes.removeWhere((note) => note['id'] == noteId);
    });
    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM, 'Success', 'Note deleted');
  }

  Future<void> _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() {
          _instructorAttachments.insert(0, {
            'id': DateTime.now().toUtc().millisecondsSinceEpoch,
            'file_name': result.files.first.name,
            'file_size':
                '${(result.files.first.size / 1024 / 1024).toStringAsFixed(1)} MB',
            'uploaded_at': DateTime.now(),
          });
        });
        Get.snackbar(
            snackPosition: SnackPosition.BOTTOM,
            'Success',
            'File uploaded successfully');
      }
    } catch (e) {
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to upload file');
    }
  }

  void _downloadFile(Map<String, dynamic> attachment) {
    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Info',
        'Downloading ${attachment['file_name']}');
  }

  void _deleteAttachment(int attachmentId) {
    setState(() {
      _instructorAttachments
          .removeWhere((attachment) => attachment['id'] == attachmentId);
    });
    Get.snackbar(
        snackPosition: SnackPosition.BOTTOM, 'Success', 'File deleted');
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: shrinkOffset > 0
            ? [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  spreadRadius: 1,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  double get maxExtent => 60.0; // Fixed height for tab bar

  @override
  double get minExtent => 60.0; // Same as maxExtent for consistent height

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
