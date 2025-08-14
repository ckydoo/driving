// lib/screens/users/enhanced_users_screen.dart
// ignore_for_file: unused_field

import 'package:driving/screens/users/enhanced_recommendations_screen.dart';
import 'package:driving/screens/users/add_user_screen.dart';
import 'package:driving/screens/users/graduation_screen.dart';
import 'package:driving/screens/users/student_details_screen.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/widgets/responsive_extensions.dart';
import 'package:driving/widgets/responsive_wrapper.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/user_controller.dart';
import '../../models/user.dart';
import 'package:driving/screens/users/instructor_details_screen.dart';
import 'package:driving/screens/users/bulk_student_upload_screen.dart';

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
      Get.snackbar('Error', 'Failed to load ${widget.role}s: $e');
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
          'Successfully deleted $selectedCount ${widget.role}${selectedCount > 1 ? 's' : ''}',
          backgroundColor: Colors.green[100],
          colorText: Colors.green[800],
          duration: Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Partial Success',
          'Deleted ${selectedCount - failedDeletions.length} users. Failed: ${failedDeletions.join(', ')}',
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[800],
          duration: Duration(seconds: 5),
        );
      }

      _exitMultiSelectionMode();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete selected ${widget.role}s: $e',
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

    final selectedCount = _selectedUsers.length;
    final confirmed = await _showBulkGraduateConfirmation(selectedCount);

    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final failedGraduations = <String>[];

      for (final userId in _selectedUsers) {
        try {
          final user = _users.firstWhere((u) => u.id == userId);
          await _graduateStudent(user);
        } catch (e) {
          final user = _users.firstWhere((u) => u.id == userId);
          failedGraduations.add('${user.fname} ${user.lname}');
        }
      }

      await _loadUsers();

      if (failedGraduations.isEmpty) {
        Get.snackbar(
          'Success',
          'Successfully graduated $selectedCount student${selectedCount > 1 ? 's' : ''}',
          backgroundColor: Colors.green[100],
          colorText: Colors.green[800],
          duration: Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Partial Success',
          'Graduated ${selectedCount - failedGraduations.length} students. Failed: ${failedGraduations.join(', ')}',
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[800],
          duration: Duration(seconds: 5),
        );
      }

      _exitMultiSelectionMode();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to graduate selected students: $e',
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

  Future<void> _graduateStudent(User student) async {
    // Same graduation logic as in GraduationScreen
    final updatedStudent = User(
      id: student.id,
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

    await DatabaseHelper.instance.updateUser(updatedStudent);
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
                  Text('Bulk Delete Confirmation'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete $count selected ${widget.role}${count > 1 ? 's' : ''}?',
                    style: TextStyle(fontSize: 16),
                  ),
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
                        Icon(Icons.warning_amber, color: Colors.red[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This action cannot be undone.',
                            style: TextStyle(
                              color: Colors.red[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Delete All'),
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
                  ResponsiveText(
                    'Confirm Bulk Graduate ',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to graduate $count selected student${count > 1 ? 's' : ''}?',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'This action will:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  _buildActionItem('• Move students to alumni status'),
                  _buildActionItem('• Mark students as graduated'),
                  _buildActionItem('• Add graduation records to timeline'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Students with outstanding balances or pending schedules may require individual review.',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Graduate All'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _buildActionItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);
    final isTablet = _isTablet(context);

    return ResponsiveWrapper(
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: ResponsiveText(
            '${widget.role.capitalize}s Management',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.blue[700],
          elevation: 0,
          actions: [
            if (!_isMultiSelectionActive && widget.role == 'student')
              IconButton(
                icon: Icon(Icons.upload_file, color: Colors.white),
                onPressed: () => Get.to(() => BulkStudentUploadScreen()),
                tooltip: 'Import Students',
              ),
            if (!_isMultiSelectionActive)
              IconButton(
                icon: Icon(Icons.checklist, color: Colors.white),
                onPressed: _enterMultiSelectionMode,
                tooltip: 'Multi-select mode',
              ),
            if (_isMultiSelectionActive)
              IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: _exitMultiSelectionMode,
                tooltip: 'Exit multi-select',
              ),
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
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
            _buildTabBar(),

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
          backgroundColor: Colors.blue[700],
          child: Icon(Icons.add, color: Colors.white),
          tooltip: 'Add New ${widget.role.capitalize}',
        ),
      ),
    );
  }

  Widget _buildMultiSelectionBar(bool isMobile) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!, width: 1),
        ),
      ),
      child:
          isMobile ? _buildMobileSelectionBar() : _buildDesktopSelectionBar(),
    );
  }

  Widget _buildMobileSelectionBar() {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: _isAllSelected,
              onChanged: (_) => _toggleSelectAll(),
              activeColor: Colors.blue[700],
            ),
            Expanded(
              child: Text(
                '${_selectedUsers.length} selected',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ),
            if (_isProcessing)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                ),
              ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.delete, size: 18),
                label: Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: _selectedUsers.isNotEmpty && !_isProcessing
                    ? _bulkDelete
                    : null,
              ),
            ),
            if (widget.role == 'student') ...[
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.school, size: 18),
                  label: Text('Graduate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: _selectedUsers.isNotEmpty && !_isProcessing
                      ? _bulkGraduate
                      : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopSelectionBar() {
    return Row(
      children: [
        Checkbox(
          value: _isAllSelected,
          onChanged: (_) => _toggleSelectAll(),
          activeColor: Colors.blue[700],
        ),
        Text(
          '${_selectedUsers.length} selected',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.blue[800],
          ),
        ),
        Spacer(),
        if (_isProcessing) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            ),
          ),
          SizedBox(width: 16),
        ],
        TextButton.icon(
          icon: Icon(Icons.delete, color: Colors.red, size: 18),
          label: Text('Delete', style: TextStyle(color: Colors.red)),
          onPressed:
              _selectedUsers.isNotEmpty && !_isProcessing ? _bulkDelete : null,
        ),
        if (widget.role == 'student') ...[
          SizedBox(width: 8),
          TextButton.icon(
            icon: Icon(Icons.school, color: Colors.green, size: 18),
            label: Text('Graduate', style: TextStyle(color: Colors.green)),
            onPressed: _selectedUsers.isNotEmpty && !_isProcessing
                ? _bulkGraduate
                : null,
          ),
        ],
      ],
    );
  }

  Widget _buildSearchAndFilters(bool isMobile) {
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
              hintText: 'Search ${widget.role}s by name, email...',
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => _applyFiltersAndSort(),
          ),
          SizedBox(height: 12),

          // Filters and sort
          if (isMobile)
            Column(
              children: [
                _buildStatusFilter(),
                SizedBox(height: 8),
                _buildSortOptions(),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _buildStatusFilter()),
                SizedBox(width: 16),
                Expanded(child: _buildSortOptions()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _filterStatus,
      decoration: InputDecoration(
        labelText: 'Filter by Status',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
        DropdownMenuItem(value: 'active', child: Text('Active')),
        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
        DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
      ],
      onChanged: (value) {
        setState(() {
          _filterStatus = value!;
          _applyFiltersAndSort();
        });
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
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              DropdownMenuItem(value: 'name', child: Text('Name')),
              DropdownMenuItem(value: 'email', child: Text('Email')),
              DropdownMenuItem(value: 'date', child: Text('Date Added')),
              DropdownMenuItem(value: 'status', child: Text('Status')),
            ],
            onChanged: (value) {
              setState(() {
                _sortBy = value!;
                _applyFiltersAndSort();
              });
            },
          ),
        ),
        SizedBox(width: 8),
        IconButton(
          icon: Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            color: Colors.blue[700],
          ),
          onPressed: () {
            setState(() {
              _sortAscending = !_sortAscending;
              _applyFiltersAndSort();
            });
          },
          tooltip: _sortAscending ? 'Sort Descending' : 'Sort Ascending',
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue[700],
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.blue[700],
        indicatorWeight: 3,
        tabs: [
          Tab(
            icon: Icon(Icons.list),
            text: '${widget.role.capitalize}s List',
          ),
          Tab(
            icon: Icon(Icons.recommend),
            text: 'Quick Actions',
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
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No ${widget.role}s found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[50],
          child: Row(
            children: [
              Text(
                'Showing ${_getPaginatedResults().length} of ${_searchResults.length} ${widget.role}s',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
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
          child: ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: _getPaginatedResults().length,
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

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue[200]! : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
          child: Padding(
            padding: EdgeInsets.all(16),
            child: isMobile
                ? _buildMobileUserCard(user, isSelected)
                : _buildDesktopUserCard(user, isSelected),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileUserCard(User user, bool isSelected) {
    return Column(
      children: [
        Row(
          children: [
            if (_isMultiSelectionActive)
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) => _toggleUserSelection(user.id!),
                  activeColor: Colors.blue[700],
                ),
              ),
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue[100],
              child: Text(
                '${user.fname[0]}${user.lname[0]}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                  fontSize: 16,
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
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _buildStatusChip(user.status),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Phone: ${user.phone}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!_isMultiSelectionActive)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                onSelected: (value) => _handleMenuAction(value, user),
                itemBuilder: (context) => _buildMenuItems(user),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopUserCard(User user, bool isSelected) {
    return Row(
      children: [
        if (_isMultiSelectionActive)
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Checkbox(
              value: isSelected,
              onChanged: (bool? value) => _toggleUserSelection(user.id!),
              activeColor: Colors.blue[700],
            ),
          ),
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blue[100],
          child: Text(
            '${user.fname[0]}${user.lname[0]}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
              fontSize: 16,
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.fname} ${user.lname}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                user.email,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            user.phone,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 16),
        _buildStatusChip(user.status),
        SizedBox(width: 16),
        if (!_isMultiSelectionActive)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            onSelected: (value) => _handleMenuAction(value, user),
            itemBuilder: (context) => _buildMenuItems(user),
          ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'active':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'inactive':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      case 'suspended':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.capitalize!,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(User user) {
    return [
      PopupMenuItem<String>(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit, color: Colors.blue),
          title: Text('Edit'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (widget.role == 'student')
        PopupMenuItem<String>(
          value: 'graduate',
          child: ListTile(
            leading: Icon(Icons.school, color: Colors.green),
            title: Text('Graduate'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      PopupMenuItem<String>(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('Delete', style: TextStyle(color: Colors.red)),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
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
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Rows per page selector
          Row(
            children: [
              Text(
                'Rows per page:',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(width: 8),
              DropdownButton<int>(
                value: _rowsPerPage,
                items: [5, 10, 20, 50].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value'),
                  );
                }).toList(),
                onChanged: (int? value) {
                  setState(() {
                    _rowsPerPage = value!;
                    _currentPage = 1;
                  });
                },
                underline: SizedBox(),
              ),
            ],
          ),

          // Pagination controls
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.first_page),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage = 1)
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPage',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.last_page),
                onPressed: _currentPage < _totalPages
                    ? () => setState(() => _currentPage = _totalPages)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Existing methods from original implementation
  void _showImportDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Import ${widget.role.capitalize}s'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a CSV file to import multiple ${widget.role}s.'),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['csv'],
                );
                if (result != null) {
                  _handleFileImport(result.files.first);
                }
              },
              icon: Icon(Icons.file_upload),
              label: Text('Choose File'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _handleFileImport(PlatformFile file) {
    Get.snackbar(
      'Import Started',
      'Processing file: ${file.name}',
      backgroundColor: Colors.blue[100],
      colorText: Colors.blue[800],
    );
  }

  void _showDeleteDialog(User user) {
    Get.dialog(
      AlertDialog(
        title: Text('Delete ${widget.role.capitalize}'),
        content: Text(
            'Are you sure you want to delete ${user.fname} ${user.lname}?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              try {
                await controller.deleteUser(user.id!);
                _loadUsers();
                Get.snackbar(
                  'Success',
                  '${widget.role.capitalize} deleted successfully',
                  backgroundColor: Colors.green[100],
                  colorText: Colors.green[800],
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to delete ${widget.role}: $e',
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
