import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/screens/users/enhanced_recommendations_screen.dart';
import 'package:driving/screens/users/add_user_screen.dart';
import 'package:driving/screens/users/graduation_screen.dart';
import 'package:driving/screens/users/student_details_screen.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/widgets/responsive_extensions.dart';
import 'package:driving/widgets/responsive_wrapper.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/user_controller.dart';
import '../../models/user.dart';
import 'package:driving/screens/users/instructor_details_screen.dart';
import 'package:driving/screens/users/bulk_student_upload_screen.dart';
import 'package:driving/screens/users/widgets/eligibility_dialog.dart';

class EnhancedUsersScreen extends StatefulWidget {
  final String role;

  const EnhancedUsersScreen({Key? key, required this.role}) : super(key: key);

  @override
  _EnhancedUsersScreenState createState() => _EnhancedUsersScreenState();
}

class _EnhancedUsersScreenState extends State<EnhancedUsersScreen>
    with SingleTickerProviderStateMixin {
  final UserController controller = Get.find<UserController>();
  late Future<List<User>> _usersFuture;
  final TextEditingController _searchController = TextEditingController();
  List<User> _users = [];
  List<User> _searchResults = [];
  List<int> _selectedUsers = [];
  bool _isMultiSelectionActive = false;
  bool _isAllSelected = false;
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _filterStatus = 'all';
  bool _isProcessing = false;

  // Pagination variables
  int _currentPage = 1;
  int _rowsPerPage = 10;

  // Tab controller for view modes
  late TabController _tabController;
  int _currentViewIndex = 0;

  // Recommendations
  List<Map<String, dynamic>> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
    _generateRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _loadUsers() async {
    try {
      final users = await controller.fetchUsers();
      setState(() {
        // Filter users by the current role being viewed
        _users = users
            .where(
                (user) => user.role.toLowerCase() == widget.role.toLowerCase())
            .toList();
        _applyFiltersAndSort();
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load ${widget.role}s',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    }
  }

  void _generateRecommendations() {
    _recommendations = [
      {
        'icon': Icons.person_add,
        'title': 'Add New ${widget.role.capitalize}',
        'description': 'Quick access to add a new ${widget.role}',
        'action': () => Get.to(() => AddUserScreen(role: widget.role)),
        'color': Colors.blue,
      },
      {
        'icon': Icons.upload_file,
        'title': 'Import Students',
        'description': 'Import multiple students from CSV file',
        'action': () => Get.to(() => BulkStudentUploadScreen()),
        'color': Colors.green,
      },
    ];
  }

  void _applyFiltersAndSort() {
    List<User> filteredUsers = List.from(_users);

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filteredUsers = filteredUsers.where((user) {
        return user.fname.toLowerCase().contains(query) ||
            user.lname.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);
      }).toList();
    }

    // Apply status filter
    if (_filterStatus != 'all') {
      filteredUsers = filteredUsers
          .where((user) => user.status.toLowerCase() == _filterStatus)
          .toList();
    }

    // Apply sorting
    filteredUsers.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.fname.compareTo(b.fname);
          break;
        case 'email':
          comparison = a.email.compareTo(b.email);
          break;
        case 'date':
          comparison = a.created_at.compareTo(b.created_at);
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _searchResults = filteredUsers;
    });
  }

  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUsers.contains(userId)) {
        _selectedUsers.remove(userId);
      } else {
        _selectedUsers.add(userId);
      }
      _updateSelectionState();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedUsers.clear();
      } else {
        _selectedUsers =
            _getPaginatedResults().map((user) => user.id!).toList();
      }
      _updateSelectionState();
    });
  }

  void _updateSelectionState() {
    final paginatedResults = _getPaginatedResults();
    _isAllSelected = paginatedResults.isNotEmpty &&
        paginatedResults.every((user) => _selectedUsers.contains(user.id));

    if (_selectedUsers.isEmpty) {
      _isMultiSelectionActive = false;
    }
  }

  void _enterMultiSelectionMode() {
    setState(() {
      _isMultiSelectionActive = true;
    });
  }

  void _exitMultiSelectionMode() {
    setState(() {
      _isMultiSelectionActive = false;
      _selectedUsers.clear();
      _isAllSelected = false;
    });
  }

  List<User> _getPaginatedResults() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    return _searchResults.sublist(
      startIndex,
      endIndex > _searchResults.length ? _searchResults.length : endIndex,
    );
  }

  int get _totalPages => (_searchResults.length / _rowsPerPage).ceil();

  // Bulk Actions
  Future<void> _bulkDelete() async {
    if (_selectedUsers.isEmpty) return;

    final selectedCount = _selectedUsers.length;
    final confirmed = await _showBulkDeleteConfirmation(selectedCount);

    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final failedDeletions = <String>[];

      for (final userId in _selectedUsers) {
        try {
          await controller.deleteUser(userId);
        } catch (e) {
          final user = _users.firstWhere((u) => u.id == userId);
          failedDeletions.add('${user.fname} ${user.lname}');
        }
      }

      await _loadUsers();

      if (failedDeletions.isEmpty) {
        Get.snackbar(
          'Success',
          'Deleted $selectedCount ${widget.role}${selectedCount > 1 ? 's' : ''}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[800],
          duration: Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Partial Success',
          'Deleted ${selectedCount - failedDeletions.length} users',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[800],
          duration: Duration(seconds: 5),
        );
      }

      _exitMultiSelectionMode();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete selected ${widget.role}s',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        duration: Duration(seconds: 3),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _bulkGraduate() async {
    if (_selectedUsers.isEmpty || widget.role != 'student') return;

    final selectedStudents =
        _users.where((user) => _selectedUsers.contains(user.id)).toList();
    final eligibilityResults = await _checkBulkEligibility(selectedStudents);
    final eligibleStudents = eligibilityResults
        .where((result) => result['eligible'] == true)
        .toList();
    final ineligibleStudents = eligibilityResults
        .where((result) => result['eligible'] == false)
        .toList();
    final shouldProceed =
        await _showEligibilityDialog(eligibleStudents, ineligibleStudents);
    if (!shouldProceed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final failedGraduations = <String>[];
      int successCount = 0;
      for (final studentResult in eligibleStudents) {
        try {
          final student = studentResult['student'] as User;
          await _graduateStudent(student);
          successCount++;
        } catch (e) {
          final student = studentResult['student'] as User;
          failedGraduations.add('${student.fname} ${student.lname}');
        }
      }

      await _loadUsers();
      if (failedGraduations.isEmpty && successCount > 0) {
        Get.snackbar(
          'Success',
          'Graduated $successCount student${successCount > 1 ? 's' : ''}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[800],
          duration: Duration(seconds: 4),
        );
      } else if (successCount > 0) {
        Get.snackbar(
          'Partial Success',
          'Graduated $successCount students',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[800],
          duration: Duration(seconds: 5),
        );
      } else {
        Get.snackbar(
          'No Graduations',
          'No students could be graduated',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[800],
          duration: Duration(seconds: 4),
        );
      }

      _exitMultiSelectionMode();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to graduate students',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        duration: Duration(seconds: 3),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _checkBulkEligibility(
      List<User> students) async {
    List<Map<String, dynamic>> results = [];

    // Get all necessary data
    await controller.fetchUsers();
    final scheduleController = Get.find<ScheduleController>();
    final billingController = Get.find<BillingController>();

    await scheduleController.fetchSchedules();
    await billingController.fetchBillingData();

    const int minimumRequiredLessons = 1; // Only need 1 lesson

    for (final student in students) {
      // 1. Check completed lessons
      final completedSchedules = scheduleController.schedules
          .where((schedule) =>
              schedule.studentId == student.id &&
              schedule.status == 'Completed' &&
              schedule.attended == true)
          .toList();

      final totalLessonsCompleted = completedSchedules.fold<int>(
          0, (sum, schedule) => sum + schedule.lessonsDeducted);

      final hasCompletedRequiredLessons =
          totalLessonsCompleted >= minimumRequiredLessons;

      // 2. Check remaining schedules
      final remainingSchedules = scheduleController.schedules
          .where((schedule) =>
              schedule.studentId == student.id &&
              schedule.status != 'Completed' &&
              schedule.status != 'Cancelled' &&
              schedule.start.isAfter(DateTime.now()))
          .toList();

      // 3. Check outstanding balance
      final outstandingInvoices = billingController.invoices
          .where((invoice) =>
              invoice.studentId == student.id && invoice.balance > 0)
          .toList();

      final totalOutstandingBalance = outstandingInvoices.fold(
          0.0, (sum, invoice) => sum + invoice.balance);

      // 4. SIMPLIFIED ELIGIBILITY CHECK
      final isEligible = hasCompletedRequiredLessons &&
          remainingSchedules.isEmpty &&
          totalOutstandingBalance <= 0;

      // 5. Build reason list for ineligible students
      List<String> missingRequirements = [];
      if (!hasCompletedRequiredLessons) {
        missingRequirements.add('Must attend at least 1 lesson');
      }
      if (remainingSchedules.isNotEmpty) {
        missingRequirements.add('${remainingSchedules.length} pending lessons');
      }
      if (totalOutstandingBalance > 0) {
        missingRequirements
            .add('\$${totalOutstandingBalance.toStringAsFixed(2)} outstanding');
      }

      results.add({
        'student': student,
        'eligible': isEligible,
        'completedLessons': totalLessonsCompleted,
        'requiredLessons': minimumRequiredLessons,
        'pendingLessons': remainingSchedules.length,
        'outstandingBalance': totalOutstandingBalance,
        'missingRequirements': missingRequirements,
      });
    }

    return results;
  }

  Future<bool> _showEligibilityDialog(List<Map<String, dynamic>> eligible,
      List<Map<String, dynamic>> ineligible) async {
    return await EligibilityDialog.show(context, eligible, ineligible);
  }

  Future<void> _graduateStudent(User student) async {
    // Same graduation logic as in GraduationScreen
    final updatedStudent = User(
      id: student.id,
      schoolId: student.schoolId, // ✅ Preserve school_id
      firebaseUserId: student.firebaseUserId, // ✅ Preserve firebase_user_id
      fname: student.fname,
      lname: student.lname,
      email: student.email,
      password: student.password,
      phone: student.phone,
      address: student.address,
      date_of_birth: student.date_of_birth,
      gender: student.gender,
      idnumber: student.idnumber,
      role: 'alumni',
      status: 'Graduated',
      created_at: student.created_at,
    );

    await DatabaseHelper.instance
        .updateUser(updatedStudent as Map<String, dynamic>);
  }

  Future<bool> _showBulkDeleteConfirmation(int count) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete ${widget.role}s'),
                ],
              ),
              content: Text(
                'Delete $count selected ${widget.role}${count > 1 ? 's' : ''}? This action cannot be undone.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<bool> _showBulkGraduateConfirmation(int count) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.school, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Graduate Students'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Graduate $count selected student${count > 1 ? 's' : ''}?',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This will move students to alumni status.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child:
                      Text('Graduate', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '${widget.role.capitalize}s',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isMultiSelectionActive && widget.role == 'student')
            IconButton(
              icon: Icon(Icons.upload_file),
              onPressed: () => Get.to(() => BulkStudentUploadScreen()),
              tooltip: 'Import Students',
            ),
          if (!_isMultiSelectionActive)
            IconButton(
              icon: Icon(Icons.checklist),
              onPressed: _enterMultiSelectionMode,
              tooltip: 'Select Multiple',
            ),
          if (_isMultiSelectionActive)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: _exitMultiSelectionMode,
              tooltip: 'Cancel Selection',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Multi-selection action bar
          if (_isMultiSelectionActive) _buildMultiSelectionBar(isMobile),

          // Search and filters
          _buildSearchAndFilters(isMobile),

          // Tab bar for different views
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[600],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue[600],
              tabs: [
                Tab(
                  icon: Icon(Icons.list, size: 20),
                  text: 'List',
                ),
                Tab(
                  icon: Icon(Icons.bolt, size: 20),
                  text: 'Quick Actions',
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsersList(isMobile),
                EnhancedRecommendationsScreen(
                  role: widget.role,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => AddUserScreen(role: widget.role)),
        backgroundColor: Colors.blue[600],
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Add ${widget.role.capitalize}',
      ),
    );
  }

  Widget _buildMultiSelectionBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[50],
      child: Row(
        children: [
          Checkbox(
            value: _isAllSelected,
            onChanged: (value) => _toggleSelectAll(),
          ),
          SizedBox(width: 8),
          Text(
            '${_selectedUsers.length} selected',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Spacer(),
          if (widget.role == 'student')
            TextButton.icon(
              onPressed: _isProcessing ? null : _bulkGraduate,
              icon: Icon(Icons.school, size: 18),
              label: Text('Graduate'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green[700],
              ),
            ),
          SizedBox(width: 8),
          TextButton.icon(
            onPressed: _isProcessing ? null : _bulkDelete,
            icon: Icon(Icons.delete, size: 18),
            label: Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[700],
            ),
          ),
          SizedBox(width: 8),
          TextButton(
            onPressed: _exitMultiSelectionMode,
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search ${widget.role}s...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => _applyFiltersAndSort(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(bool isMobile) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No ${widget.role}s found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results summary
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[50],
          child: Row(
            children: [
              Text(
                '${_searchResults.length} ${widget.role}s',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(),
              if (_totalPages > 1)
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),

        // Users list
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.all(16),
            itemCount: _getPaginatedResults().length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = _getPaginatedResults()[index];
              return _buildUserCard(user, isMobile);
            },
          ),
        ),

        // Pagination
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildUserCard(User user, bool isMobile) {
    final isSelected = _selectedUsers.contains(user.id);
    final statusColor = user.status.toLowerCase() == 'active'
        ? Colors.green
        : user.status.toLowerCase() == 'inactive'
            ? Colors.red
            : Colors.orange;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Colors.blue[600]!, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (_isMultiSelectionActive) {
            _toggleUserSelection(user.id!);
          } else {
            _navigateToUserDetails(user);
          }
        },
        onLongPress: () {
          if (!_isMultiSelectionActive) {
            _enterMultiSelectionMode();
            _toggleUserSelection(user.id!);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection checkbox
              if (_isMultiSelectionActive)
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleUserSelection(user.id!),
                  ),
                ),

              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.fname[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${user.fname} ${user.lname}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user.status,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (user.phone.isNotEmpty)
                      Text(
                        user.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),

              // Action menu
              if (!_isMultiSelectionActive)
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(value, user),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    if (widget.role == 'student')
                      PopupMenuItem(
                        value: 'graduate',
                        child: Row(
                          children: [
                            Icon(Icons.school, size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Graduate'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, User user) {
    switch (action) {
      case 'edit':
        Get.dialog(AddUserScreen(role: widget.role, user: user));
        break;
      case 'graduate':
        if (widget.role == 'student') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GraduationScreen(student: user),
            ),
          );
        }
        break;
      case 'delete':
        _showDeleteDialog(user);
        break;
    }
  }

  void _navigateToUserDetails(User user) {
    if (widget.role == 'student') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StudentDetailsScreen(studentId: user.id!),
        ),
      );
    } else if (widget.role == 'instructor') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InstructorDetailsScreen(instructorId: user.id!),
        ),
      );
    }
  }

  Widget _buildPagination() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rows per page
          DropdownButton<int>(
            value: _rowsPerPage,
            items: [10, 25, 50]
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value per page'),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _rowsPerPage = value!;
                _currentPage = 1;
              });
            },
          ),
          Spacer(),

          // Navigation buttons
          IconButton(
            onPressed:
                _currentPage == 1 ? null : () => setState(() => _currentPage--),
            icon: Icon(Icons.chevron_left),
          ),
          Text('Page $_currentPage of $_totalPages'),
          IconButton(
            onPressed: _currentPage == _totalPages
                ? null
                : () => setState(() => _currentPage++),
            icon: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.role}'),
        content: Text(
            'Delete ${user.fname} ${user.lname}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await controller.deleteUser(user.id!);
                _loadUsers();
                Get.snackbar(
                  'Success',
                  '${widget.role.capitalize} deleted',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green[100],
                  colorText: Colors.green[800],
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to delete ${widget.role}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red[100],
                  colorText: Colors.red[800],
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
