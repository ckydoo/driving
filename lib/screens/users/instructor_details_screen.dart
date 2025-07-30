import 'dart:io';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
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
  final TextEditingController _noteController = TextEditingController();
  List<Map<String, dynamic>> _instructorNotes = [];
  List<Map<String, dynamic>> _instructorAttachments = [];
  bool _isLoading = true;

  // Enhanced UX properties
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isExpanded = false;
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstructorData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchInstructorNotes() async {
    final notes =
        await DatabaseHelper.instance.getNotesForStudent(widget.instructorId);
    setState(() {
      _instructorNotes = notes;
    });
  }

  Future<void> _fetchInstructorAttachments() async {
    final attachments = await DatabaseHelper.instance
        .getAttachmentsForStudent(widget.instructorId);
    setState(() {
      _instructorAttachments = attachments;
    });
  }

  Future<void> _loadInstructorData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final existingInstructor = userController.users
          .firstWhereOrNull((user) => user.id == widget.instructorId);

      if (existingInstructor == null || userController.users.isEmpty) {
        await userController.fetchUsers();
      }

      await Future.wait([
        fleetController.fetchFleet(),
        scheduleController.fetchSchedules(),
        _fetchInstructorNotes(),
        _fetchInstructorAttachments(),
      ]);

      setState(() {
        instructor = userController.users
            .firstWhereOrNull((user) => user.id == widget.instructorId);
        _isLoading = false;
      });

      if (instructor == null) {
        Get.snackbar(
          'Error',
          'Instructor not found',
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
        'Failed to load instructor data: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _addNote() async {
    if (_noteController.text.isNotEmpty) {
      try {
        final note = {
          'note_for': widget.instructorId,
          'note': _noteController.text,
          'note_by': authController.currentUser.value?.id ?? 0,
        };
        await DatabaseHelper.instance.insertNote(note);
        _noteController.clear();
        await _fetchInstructorNotes();
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
          ),
          SizedBox(height: 16),
          Text(
            'Loading instructor details...',
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
            'Instructor not found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'The instructor you\'re looking for doesn\'t exist.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back),
            label: Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
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
          colors: [Colors.green.shade600, Colors.green.shade800],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end, // Align content to bottom
            children: [
              // Profile Section
              Row(
                children: [
                  // Enhanced Avatar with Status Indicator
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade300,
                              Colors.green.shade500
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${instructor!.fname[0]}${instructor!.lname[0]}'
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
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
                            size: 12,
                          ),
                        ),
                      ),
                    ],
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
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ID: ${instructor!.idnumber}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
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

                  // Options Menu Button
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => _showOptionsMenu(),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Quick Stats Row
              Row(
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
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTabBar() {
    return Material(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.green.shade600,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.green.shade600,
        indicatorWeight: 3,
        labelStyle: TextStyle(fontWeight: FontWeight.w600),
        labelPadding: EdgeInsets.symmetric(horizontal: 16),
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 25),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.person, color: Colors.green.shade600),
        title: Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        initiallyExpanded: true,
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

  Widget _buildPerformanceCard() {
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
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

  Widget _buildQuickActionsCard() {
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
                Icon(Icons.flash_on, color: Colors.green.shade600),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionChip(
                  'Schedule Lesson',
                  Icons.add_box,
                  Colors.blue,
                  () => _scheduleLesson(),
                ),
                _buildActionChip(
                  'Assign Vehicle',
                  Icons.directions_car,
                  Colors.orange,
                  () => _assignVehicle(),
                ),
                _buildActionChip(
                  'Send Message',
                  Icons.message,
                  Colors.green,
                  () => _sendMessage(),
                ),
                _buildActionChip(
                  'Edit Profile',
                  Icons.edit,
                  Colors.purple,
                  () => _editProfile(),
                ),
                _buildActionChip(
                  'Generate Report',
                  Icons.assessment,
                  Colors.red,
                  () => _generateReport(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    final instructorSchedules = scheduleController.schedules
        .where((schedule) => schedule.instructorId == widget.instructorId)
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
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              SizedBox(width: 16),
              PopupMenuButton<String>(
                icon: Icon(Icons.filter_list),
                onSelected: (value) {
                  setState(() {
                    _filterStatus = value;
                  });
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
          child: instructorSchedules.isEmpty
              ? _buildEmptyState(
                  'No schedules found',
                  'This instructor has no scheduled lessons yet.',
                  Icons.schedule,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: instructorSchedules.length,
                  itemBuilder: (context, index) {
                    final schedule = instructorSchedules[index];
                    return _buildEnhancedScheduleCard(schedule);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEnhancedScheduleCard(schedule) {
    final student = userController.users.firstWhereOrNull(
      (user) => user.id == schedule.studentId,
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
                      '${student?.fname ?? 'Unknown'} ${student?.lname ?? 'Student'}',
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
                  Icon(Icons.school, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    schedule.classType,
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

  Widget _buildVehicleTab() {
    final assignedVehicle = fleetController.fleet.firstWhereOrNull(
      (vehicle) => vehicle.instructor == widget.instructorId,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Spacer(),
                      TextButton.icon(
                        onPressed: () => _assignVehicle(),
                        icon: Icon(Icons.edit, size: 16),
                        label: Text('Change'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  assignedVehicle == null
                      ? _buildNoVehicleState()
                      : _buildVehicleInfo(assignedVehicle),
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

  Widget _buildNoVehicleState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: Colors.orange.shade600,
          ),
          SizedBox(height: 12),
          Text(
            'No Vehicle Assigned',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This instructor needs a vehicle assignment to conduct lessons.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange.shade700),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _assignVehicle(),
            icon: Icon(Icons.add_circle),
            label: Text('Assign Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfo(vehicle) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_car,
                  size: 32,
                  color: Colors.green.shade600,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.make} ${vehicle.model}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    Text(
                      'Year: ${vehicle.modelYear}',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                    Text(
                      'Plate: ${vehicle.carPlate}',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: vehicle.status.toLowerCase() == 'active'
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  vehicle.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: vehicle.status.toLowerCase() == 'active'
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            SizedBox(height: 16),
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
    return Column(
      children: [
        Icon(icon, color: Colors.green.shade600, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
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
                  color: Colors.green.shade800,
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
                      color: Colors.green.shade600,
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
          child: _instructorNotes.isEmpty
              ? _buildEmptyState(
                  'No notes yet',
                  'Add your first note about this instructor.',
                  Icons.note_add,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
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
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.note,
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
                        note['note'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
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
                  'Attachments (${_instructorAttachments.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _uploadFile,
                icon: Icon(Icons.upload_file, size: 16),
                label: Text('Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
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
          child: _instructorAttachments.isEmpty
              ? _buildEmptyState(
                  'No attachments',
                  'Upload documents, images, or other files.',
                  Icons.attach_file,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
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
  int _getActiveStudentsCount() {
    return scheduleController.schedules
        .where((s) => s.instructorId == widget.instructorId)
        .map((s) => s.studentId)
        .toSet()
        .length;
  }

  int _getTotalLessonsCount() {
    return scheduleController.schedules
        .where((s) => s.instructorId == widget.instructorId)
        .length;
  }

  int _getWeeklyLessonsCount() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));

    return scheduleController.schedules
        .where((s) =>
            s.instructorId == widget.instructorId &&
            s.start.isAfter(startOfWeek) &&
            s.start.isBefore(endOfWeek))
        .length;
  }

  int _getMonthlyLessonsCount() {
    final now = DateTime.now();
    return scheduleController.schedules
        .where((s) =>
            s.instructorId == widget.instructorId &&
            s.start.month == now.month &&
            s.start.year == now.year)
        .length;
  }

  int _getCompletionRate() {
    final totalLessons = _getTotalLessonsCount();
    if (totalLessons == 0) return 0;

    final completedLessons = scheduleController.schedules
        .where((s) =>
            s.instructorId == widget.instructorId &&
            s.status.toLowerCase() == 'completed')
        .length;

    return ((completedLessons / totalLessons) * 100).round();
  }

  int _getUpcomingSchedulesCount() {
    final now = DateTime.now();
    return scheduleController.schedules
        .where((s) =>
            s.instructorId == widget.instructorId && s.start.isAfter(now))
        .length;
  }

  int _getVehicleLessonsCount(int vehicleId) {
    return scheduleController.schedules
        .where((s) => s.carId == vehicleId)
        .length;
  }

  int _getVehicleMonthlyLessons(int vehicleId) {
    final now = DateTime.now();
    return scheduleController.schedules
        .where((s) =>
            s.carId == vehicleId &&
            s.start.month == now.month &&
            s.start.year == now.year)
        .length;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit Instructor'),
              onTap: () {
                Navigator.pop(context);
                _editProfile();
              },
            ),
            ListTile(
              leading: Icon(Icons.share),
              title: Text('Share Profile'),
              onTap: () {
                Navigator.pop(context);
                _shareProfile();
              },
            ),
            ListTile(
              leading: Icon(Icons.print),
              title: Text('Print Report'),
              onTap: () {
                Navigator.pop(context);
                _generateReport();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Instructor',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleLesson() {
    // Navigate to schedule creation screen
    Get.snackbar('Info', 'Navigate to schedule lesson screen');
  }

  void _assignVehicle() {
    // Show vehicle assignment dialog
    Get.snackbar('Info', 'Show vehicle assignment dialog');
  }

  void _sendMessage() {
    // Open messaging interface
    Get.snackbar('Info', 'Open messaging interface');
  }

  void _editProfile() {
    // Navigate to edit profile screen
    Get.snackbar('Info', 'Navigate to edit profile screen');
  }

  void _generateReport() {
    // Generate and download report
    Get.snackbar('Info', 'Generating instructor report...');
  }

  void _shareProfile() {
    // Share instructor profile
    Get.snackbar('Info', 'Share instructor profile');
  }

  void _confirmDelete() {
    // Show delete confirmation dialog
    Get.dialog(
      AlertDialog(
        title: Text('Delete Instructor'),
        content: Text(
            'Are you sure you want to delete this instructor? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _deleteInstructor();
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteInstructor() {
    // Delete instructor logic
    Get.snackbar('Info', 'Instructor deleted');
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
        await _fetchInstructorAttachments();
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
          : instructor == null
              ? _buildErrorState()
              : NestedScrollView(
                  headerSliverBuilder:
                      (BuildContext context, bool innerBoxIsScrolled) {
                    return [
                      // Header that scrolls away
                      SliverAppBar(
                        expandedHeight: 280.0,
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

  // Calculate header height based on content
  double _getHeaderHeight() {
    // Base height for app bar, profile info, and stats
    return 280.0; // Adjust this value based on your header content
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
