// lib/screens/users/alumni_screen.dart
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/user.dart';
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
  List<User> _alumni = [];
  List<User> _filteredAlumni = [];
  List<Map<String, dynamic>> _alumniWithDetails = [];
  bool _isLoading = false;
  String _sortBy = 'graduation_date';
  bool _sortAscending = false;
  String _selectedCourse = 'all';

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _loadAlumniData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 768 && width < 1024;
  }

  Future<void> _loadAlumniData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all users and filter for alumni
      await userController.fetchUsers();
      await scheduleController.fetchSchedules();
      await billingController.fetchBillingData();
      await courseController.fetchCourses();

      _alumni = userController.users
          .where((user) => user.role == 'alumni' || user.status == 'Graduated')
          .toList();

      // Get detailed information for each alumni
      _alumniWithDetails = await _getAlumniWithDetails(_alumni);
      _filteredAlumni = _alumni;
      _applyFiltersAndSort();
    } catch (e) {
      print('Error loading alumni data: $e');
      Get.snackbar(
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

  Future<List<Map<String, dynamic>>> _getAlumniWithDetails(
      List<User> alumni) async {
    List<Map<String, dynamic>> details = [];

    for (var alumnus in alumni) {
      // Get graduation info from timeline
      final graduationInfo = await _getGraduationInfo(alumnus.id!);

      // Get course completion info
      final completedCourses = await _getCompletedCourses(alumnus.id!);

      // Get total lessons completed
      final totalLessons = _getTotalCompletedLessons(alumnus.id!);

      details.add({
        'user': alumnus,
        'graduation_date': graduationInfo['date'],
        'graduation_notes': graduationInfo['notes'],
        'completed_courses': completedCourses,
        'total_lessons': totalLessons,
        'last_activity': _getLastActivity(alumnus.id!),
      });
    }

    return details;
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

    return {
      'date': null,
      'notes': '',
    };
  }

  List<String> _getCompletedCourses(int studentId) {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == studentId)
        .toList();

    List<String> courseNames = [];
    for (var invoice in studentInvoices) {
      final course = courseController.courses.firstWhereOrNull(
        (c) => c.id == invoice.courseId,
      );
      if (course != null && !courseNames.contains(course.name)) {
        courseNames.add(course.name);
      }
    }

    return courseNames;
  }

  int _getTotalCompletedLessons(int studentId) {
    return scheduleController.schedules
        .where((s) =>
            s.studentId == studentId && s.status.toLowerCase() == 'completed')
        .fold<int>(0, (sum, s) => sum + (s.lessonsDeducted));
  }

  DateTime? _getLastActivity(int studentId) {
    final studentSchedules = scheduleController.schedules
        .where((s) => s.studentId == studentId)
        .toList();

    if (studentSchedules.isEmpty) return null;

    studentSchedules.sort((a, b) => b.start.compareTo(a.start));
    return studentSchedules.first.start;
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> filtered = List.from(_alumniWithDetails);

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((alumniData) {
        final user = alumniData['user'] as User;
        return user.fname.toLowerCase().contains(query) ||
            user.lname.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            (user.idnumber?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply course filter
    if (_selectedCourse != 'all') {
      filtered = filtered.where((alumniData) {
        final completedCourses =
            alumniData['completed_courses'] as List<String>;
        return completedCourses.contains(_selectedCourse);
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      dynamic aValue, bValue;

      switch (_sortBy) {
        case 'name':
          final userA = a['user'] as User;
          final userB = b['user'] as User;
          aValue = '${userA.fname} ${userA.lname}';
          bValue = '${userB.fname} ${userB.lname}';
          break;
        case 'graduation_date':
          aValue = a['graduation_date'] as DateTime?;
          bValue = b['graduation_date'] as DateTime?;
          if (aValue == null && bValue == null) return 0;
          if (aValue == null) return 1;
          if (bValue == null) return -1;
          break;
        case 'total_lessons':
          aValue = a['total_lessons'] as int;
          bValue = b['total_lessons'] as int;
          break;
        case 'last_activity':
          aValue = a['last_activity'] as DateTime?;
          bValue = b['last_activity'] as DateTime?;
          if (aValue == null && bValue == null) return 0;
          if (aValue == null) return 1;
          if (bValue == null) return -1;
          break;
        default:
          return 0;
      }

      final comparison = _sortAscending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);

      return comparison;
    });

    setState(() {
      _filteredAlumni = filtered.map((e) => e['user'] as User).toList();
    });
  }

  void _showAlumniDetails(Map<String, dynamic> alumniData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final user = alumniData['user'] as User;
        final graduationDate = alumniData['graduation_date'] as DateTime?;
        final completedCourses =
            alumniData['completed_courses'] as List<String>;
        final totalLessons = alumniData['total_lessons'] as int;
        final lastActivity = alumniData['last_activity'] as DateTime?;

        return Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: _isMobile(context) ? double.infinity : 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: Text(
                          '${user.fname[0]}${user.lname[0]}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Alumni',
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection('Contact Information', [
                          _buildDetailRow('Email', user.email),
                          _buildDetailRow(
                              'Phone', user.phone ?? 'Not provided'),
                          _buildDetailRow(
                              'Address', user.address ?? 'Not provided'),
                          _buildDetailRow(
                              'ID Number', user.idnumber ?? 'Not provided'),
                        ]),
                        SizedBox(height: 20),
                        _buildDetailSection('Graduation Information', [
                          _buildDetailRow(
                            'Graduation Date',
                            graduationDate != null
                                ? DateFormat('MMMM dd, yyyy')
                                    .format(graduationDate)
                                : 'Not recorded',
                          ),
                          _buildDetailRow('Total Lessons Completed',
                              totalLessons.toString()),
                          _buildDetailRow(
                            'Last Activity',
                            lastActivity != null
                                ? DateFormat('MMMM dd, yyyy')
                                    .format(lastActivity)
                                : 'No activity recorded',
                          ),
                        ]),
                        SizedBox(height: 20),
                        _buildDetailSection('Completed Courses', [
                          if (completedCourses.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No courses recorded',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            ...completedCourses
                                .map((course) => Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle,
                                              color: Colors.green, size: 16),
                                          SizedBox(width: 8),
                                          Text(course),
                                        ],
                                      ),
                                    ))
                                .toList(),
                        ]),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _reactivateStudent(user),
                          icon: Icon(Icons.person_add),
                          label: Text('Reactivate as Student'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close),
                          label: Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reactivateStudent(User alumni) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Reactivate Student'),
              content: Text(
                'Are you sure you want to reactivate ${alumni.fname} ${alumni.lname} as an active student? This will move them back to the students list.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text('Reactivate'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      final reactivatedStudent = User(
        id: alumni.id,
        fname: alumni.fname,
        lname: alumni.lname,
        email: alumni.email,
        password: alumni.password,
        phone: alumni.phone,
        address: alumni.address,
        date_of_birth: alumni.date_of_birth,
        gender: alumni.gender,
        idnumber: alumni.idnumber,
        role: 'student', // Change back to student
        status: 'Active', // Change status to active
        created_at: alumni.created_at,
      );

      await DatabaseHelper.instance.updateUser(reactivatedStudent);

      // Add reactivation record to timeline
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
      await _loadAlumniData();

      Get.snackbar(
        'Student Reactivated',
        '${alumni.fname} ${alumni.lname} has been reactivated as a student.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Navigator.of(context).pop(); // Close details dialog
    } catch (e) {
      Get.snackbar(
        'Reactivation Failed',
        'Failed to reactivate student: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  List<Map<String, dynamic>> _getCurrentPageData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    return _alumniWithDetails
        .where((data) => _filteredAlumni.contains(data['user']))
        .toList()
        .sublist(
          startIndex,
          endIndex > _filteredAlumni.length ? _filteredAlumni.length : endIndex,
        );
  }

  int get _totalPages => (_filteredAlumni.length / _itemsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);
    final isTablet = _isTablet(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: ResponsiveText(
          'Alumni Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAlumniData,
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFiltersSection(isMobile),
                _buildStatsSection(isMobile),
                Expanded(
                  child: _buildAlumniList(isMobile),
                ),
                if (_totalPages > 1) _buildPaginationSection(isMobile),
              ],
            ),
    );
  }

  Widget _buildFiltersSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search alumni by name, email, or ID...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => _applyFiltersAndSort(),
          ),
          SizedBox(height: 12),

          // Filters row
          if (isMobile)
            Column(
              children: [
                _buildCourseFilter(),
                SizedBox(height: 12),
                _buildSortOptions(),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _buildCourseFilter()),
                SizedBox(width: 16),
                Expanded(child: _buildSortOptions()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCourseFilter() {
    final courses =
        courseController.courses.map((c) => c.name).toSet().toList();

    return DropdownButtonFormField<String>(
      value: _selectedCourse,
      decoration: InputDecoration(
        labelText: 'Filter by Course',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: [
        DropdownMenuItem(value: 'all', child: Text('All Courses')),
        ...courses
            .map((course) => DropdownMenuItem(
                  value: course,
                  child: Text(course),
                ))
            .toList(),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCourse = value!;
        });
        _applyFiltersAndSort();
      },
    );
  }

  Widget _buildSortOptions() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _sortBy,
            decoration: InputDecoration(
              labelText: 'Sort by',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              DropdownMenuItem(
                  value: 'graduation_date', child: Text('Graduation Date')),
              DropdownMenuItem(value: 'name', child: Text('Name')),
              DropdownMenuItem(
                  value: 'total_lessons', child: Text('Total Lessons')),
              DropdownMenuItem(
                  value: 'last_activity', child: Text('Last Activity')),
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
          icon:
              Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
          tooltip: _sortAscending ? 'Ascending' : 'Descending',
        ),
      ],
    );
  }

  Widget _buildStatsSection(bool isMobile) {
    final totalAlumni = _alumni.length;
    final recentGraduates = _alumni.where((alumni) {
      final graduationInfo = _alumniWithDetails.firstWhereOrNull(
        (data) => (data['user'] as User).id == alumni.id,
      );
      final graduationDate = graduationInfo?['graduation_date'] as DateTime?;
      return graduationDate != null &&
          DateTime.now().difference(graduationDate).inDays <= 30;
    }).length;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: isMobile
          ? Column(
              children: [
                _buildStatCard(
                    'Total Alumni', totalAlumni.toString(), Colors.blue),
                SizedBox(height: 12),
                _buildStatCard('Recent Graduates (30 days)',
                    recentGraduates.toString(), Colors.green),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                      'Total Alumni', totalAlumni.toString(), Colors.blue),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Recent Graduates (30 days)',
                      recentGraduates.toString(), Colors.green),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            title.contains('Total') ? Icons.school : Icons.celebration,
            color: color,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlumniList(bool isMobile) {
    if (_filteredAlumni.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Alumni Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No alumni match your current search criteria.',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final currentPageData = _getCurrentPageData();

    return Container(
      color: Colors.white,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: currentPageData.length,
        itemBuilder: (context, index) {
          final alumniData = currentPageData[index];
          final user = alumniData['user'] as User;
          final graduationDate = alumniData['graduation_date'] as DateTime?;
          final completedCourses =
              alumniData['completed_courses'] as List<String>;
          final totalLessons = alumniData['total_lessons'] as int;

          return Card(
            margin: EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => _showAlumniDetails(alumniData),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: isMobile
                    ? _buildMobileAlumniCard(
                        user, graduationDate, completedCourses, totalLessons)
                    : _buildDesktopAlumniCard(
                        user, graduationDate, completedCourses, totalLessons),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileAlumniCard(User user, DateTime? graduationDate,
      List<String> courses, int totalLessons) {
    return Column(
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
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
        SizedBox(height: 12),
        Divider(height: 1),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoChip(
                'Graduated',
                graduationDate != null
                    ? DateFormat('MMM yyyy').format(graduationDate)
                    : 'Unknown',
                Icons.school,
                Colors.blue,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildInfoChip(
                'Lessons',
                totalLessons.toString(),
                Icons.assignment_turned_in,
                Colors.green,
              ),
            ),
          ],
        ),
        if (courses.isNotEmpty) ...[
          SizedBox(height: 12),
          Text(
            'Courses: ${courses.join(", ")}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopAlumniCard(User user, DateTime? graduationDate,
      List<String> courses, int totalLessons) {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue[100],
          child: Text(
            '${user.fname[0]}${user.lname[0]}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
              fontSize: 18,
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.fname} ${user.lname}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                user.email,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              if (user.phone != null) ...[
                SizedBox(height: 2),
                Text(
                  user.phone!,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Graduated',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                graduationDate != null
                    ? DateFormat('MMM dd, yyyy').format(graduationDate)
                    : 'Unknown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lessons Completed',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                totalLessons.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Courses',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                courses.isNotEmpty ? courses.join(", ") : 'No courses recorded',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      ],
    );
  }

  Widget _buildInfoChip(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _itemsPerPage + 1}-${_currentPage * _itemsPerPage > _filteredAlumni.length ? _filteredAlumni.length : _currentPage * _itemsPerPage} of ${_filteredAlumni.length}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
                icon: Icon(Icons.chevron_left),
              ),
              Text('$_currentPage of $_totalPages'),
              IconButton(
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
                icon: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
