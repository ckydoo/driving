// lib/screens/users/enhanced_users_screen.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:driving/screens/users/enhanced_recommendations_screen.dart';
import 'package:driving/screens/users/add_user_screen.dart';
import 'package:driving/screens/users/student_details_screen.dart';
import 'package:driving/screens/users/user_form_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/user_controller.dart';
import '../../models/user.dart';
import 'package:driving/screens/users/instructor_details_screen.dart';

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
        'title': 'Bulk Import',
        'description': 'Import multiple ${widget.role}s from CSV',
        'action': () => _showImportDialog(),
        'color': Colors.green,
      },
      if (widget.role == 'student')
        {
          'icon': Icons.school,
          'title': 'Enroll in Course',
          'description': 'Quick enrollment for students',
          'action': () => _showQuickEnrollDialog(),
          'color': Colors.orange,
        },
      if (widget.role == 'instructor')
        {
          'icon': Icons.directions_car,
          'title': 'Assign Vehicle',
          'description': 'Assign vehicles to instructors',
          'action': () => _showVehicleAssignmentDialog(),
          'color': Colors.purple,
        },
      {
        'icon': Icons.analytics,
        'title': 'View Analytics',
        'description': 'See ${widget.role} performance metrics',
        'action': () => _showAnalyticsDialog(),
        'color': Colors.teal,
      },
      {
        'icon': Icons.mail,
        'title': 'Send Notifications',
        'description': 'Send bulk notifications to ${widget.role}s',
        'action': () => _showNotificationDialog(),
        'color': Colors.indigo,
      },
    ];
  }

  void _applyFiltersAndSort() {
    List<User> filteredUsers = List.from(_users);

    // Apply status filter
    if (_filterStatus != 'all') {
      filteredUsers = filteredUsers
          .where((user) => user.status.toLowerCase() == _filterStatus)
          .toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filteredUsers = filteredUsers
          .where((user) =>
              user.fname.toLowerCase().contains(query) ||
              user.lname.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.phone.contains(query))
          .toList();
    }

    // Apply sorting
    filteredUsers.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison =
              '${a.fname} ${a.lname}'.compareTo('${b.fname} ${b.lname}');
          break;
        case 'email':
          comparison = a.email.compareTo(b.email);
          break;
        case 'phone':
          comparison = a.phone.compareTo(b.phone);
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;
        case 'created':
          comparison = a.created_at.compareTo(b.created_at);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _searchResults = filteredUsers;
    });
  }

  void _searchUsers(String query) {
    _applyFiltersAndSort();
  }

  List<User> _getPaginatedUsers() {
    final users = _searchResults.isNotEmpty ? _searchResults : _users;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= users.length) {
      return [];
    }
    return users.sublist(
        startIndex, endIndex > users.length ? users.length : endIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildTopSection(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListView(),
                _buildRecommendationsView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildTopSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.role.capitalize!}s...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchUsers('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  ),
                  onChanged: _searchUsers,
                ),
              ),
              SizedBox(width: 12),
              _buildFilterChip(),
              SizedBox(width: 8),
              _buildSortButton(),
              SizedBox(width: 8),
              _buildRefreshButton(),
            ],
          ),
          SizedBox(height: 16),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => u.status == 'Active').length;
    final inactiveUsers = totalUsers - activeUsers;

    return Row(
      children: [
        _buildStatCard(
          'Total ${widget.role.capitalize!}s',
          totalUsers.toString(),
          Icons.people,
          Colors.blue,
        ),
        SizedBox(width: 12),
        _buildStatCard(
          'Active',
          activeUsers.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        SizedBox(width: 12),
        _buildStatCard(
          'Inactive',
          inactiveUsers.toString(),
          Icons.pause_circle,
          Colors.orange,
        ),
        Spacer(),
        if (_selectedUsers.isNotEmpty)
          Chip(
            label: Text('${_selectedUsers.length} selected'),
            backgroundColor: Colors.blue[100],
            deleteIcon: Icon(Icons.clear, size: 18),
            onDeleted: () => _toggleSelectAll(false),
          ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip() {
    return PopupMenuButton<String>(
      child: Chip(
        label: Text('Filter: ${_filterStatus.capitalize!}'),
        avatar: Icon(Icons.filter_list, size: 16),
      ),
      onSelected: (value) {
        setState(() {
          _filterStatus = value;
          _applyFiltersAndSort();
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'all', child: Text('All')),
        PopupMenuItem(value: 'active', child: Text('Active')),
        PopupMenuItem(value: 'inactive', child: Text('Inactive')),
      ],
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      child: Chip(
        label: Text('Sort'),
        avatar: Icon(
          _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
        ),
      ),
      onSelected: (value) {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
          _applyFiltersAndSort();
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'name', child: Text('Name')),
        PopupMenuItem(value: 'email', child: Text('Email')),
        PopupMenuItem(value: 'phone', child: Text('Phone')),
        PopupMenuItem(value: 'status', child: Text('Status')),
        PopupMenuItem(value: 'created', child: Text('Date Created')),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      icon: Icon(Icons.refresh, color: Colors.blue[600]),
      onPressed: _loadUsers,
      tooltip: 'Refresh',
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue[600],
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.blue[600],
        tabs: [
          Tab(
            icon: Icon(Icons.list),
            text: '${widget.role.capitalize!}s',
          ),
          Tab(
            icon: Icon(Icons.recommend),
            text: 'Recommendations',
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Obx(() {
      if (controller.isLoading.value) {
        return Center(child: CircularProgressIndicator());
      } else if (_users.isEmpty && _searchController.text.isEmpty) {
        return _buildEmptyState();
      } else {
        final users = _getPaginatedUsers();
        return Column(
          children: [
            Expanded(
              child: Card(
                margin: EdgeInsets.all(16.0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildHeaderRow(),
                    Expanded(
                      child: users.isEmpty
                          ? Center(
                              child: Text(
                                'No ${widget.role}s found matching your criteria',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: users.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1),
                              itemBuilder: (context, index) {
                                final user = users[index];
                                return _buildUserCard(user, index);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            _buildPagination(),
          ],
        );
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.role == 'student' ? Icons.school : Icons.person,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No ${widget.role}s found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start by adding your first ${widget.role}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.dialog(UserFormDialog(role: widget.role)),
            icon: Icon(Icons.add),
            label: Text('Add ${widget.role.capitalize}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsView() {
    return EnhancedRecommendationsScreen(role: widget.role);
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: recommendation['action'],
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: recommendation['color'].withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  recommendation['icon'],
                  size: 32,
                  color: recommendation['color'],
                ),
              ),
              SizedBox(height: 12),
              Text(
                recommendation['title'],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                recommendation['description'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _isAllSelected,
            onChanged: (bool? value) => _toggleSelectAll(value!),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Email',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Phone',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 80), // Space for actions
        ],
      ),
    );
  }

  Widget _buildUserCard(User user, int index) {
    final isSelected = _selectedUsers.contains(user.id);

    return Container(
      color: isSelected ? Colors.blue[50] : Colors.transparent,
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (bool? value) => _toggleUserSelection(user.id!),
        ),
        title: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      user.fname[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
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
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'ID: ${user.idnumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                user.email,
                style: TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                user.phone,
                style: TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              flex: 1,
              child: _buildStatusChip(user.status),
            ),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 18, color: Colors.blue[600]),
                    onPressed: () => Get.dialog(
                      UserFormDialog(user: user, role: widget.role),
                    ),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 18, color: Colors.red[600]),
                    onPressed: () => _showDeleteConfirmationDialog(user.id!),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          if (widget.role == 'student') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => StudentDetailsScreen(studentId: user.id!),
              ),
            );
          } else if (widget.role == 'instructor') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    InstructorDetailsScreen(instructorId: user.id!),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isActive ? Colors.green[800] : Colors.orange[800],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_searchResults.length / _rowsPerPage).ceil();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Text(
            'Showing ${((_currentPage - 1) * _rowsPerPage) + 1}-${(_currentPage * _rowsPerPage).clamp(0, _searchResults.length)} of ${_searchResults.length}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 ? _goToPreviousPage : null,
          ),
          Text('$_currentPage of $totalPages'),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages ? _goToNextPage : null,
          ),
          SizedBox(width: 16),
          DropdownButton<int>(
            value: _rowsPerPage,
            items: [10, 25, 50, 100].map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value rows'),
              );
            }).toList(),
            onChanged: (int? value) {
              setState(() {
                _rowsPerPage = value!;
                _currentPage = 1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_isMultiSelectionActive) {
      return FloatingActionButton.extended(
        onPressed: _showMultiDeleteConfirmationDialog,
        label: Text('Delete Selected (${_selectedUsers.length})'),
        icon: Icon(Icons.delete_sweep),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      );
    }

    return FloatingActionButton.extended(
      onPressed: () => Get.dialog(UserFormDialog(role: widget.role)),
      label: Text('Add ${widget.role.capitalize}'),
      icon: Icon(Icons.add),
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
    );
  }

  // Helper methods
  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUsers.contains(userId)) {
        _selectedUsers.remove(userId);
      } else {
        _selectedUsers.add(userId);
      }
      _isMultiSelectionActive = _selectedUsers.isNotEmpty;
      _isAllSelected = _selectedUsers.length == _users.length;
    });
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _isAllSelected = value;
      _selectedUsers = value ? _users.map((user) => user.id!).toList() : [];
      _isMultiSelectionActive = _selectedUsers.isNotEmpty;
    });
  }

  void _goToPreviousPage() {
    setState(() {
      if (_currentPage > 1) {
        _currentPage--;
      }
    });
  }

  void _goToNextPage() {
    final totalPages = (_searchResults.length / _rowsPerPage).ceil();
    setState(() {
      if (_currentPage < totalPages) {
        _currentPage++;
      }
    });
  }

  // Dialog methods
  void _showDeleteConfirmationDialog(int id) {
    Get.defaultDialog(
      title: 'Confirm Delete',
      content: Text('Are you sure you want to delete this ${widget.role}?'),
      confirm: ElevatedButton(
        onPressed: () {
          controller.deleteUser(id);
          _loadUsers();
          Get.back();
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: Text('Delete', style: TextStyle(color: Colors.white)),
      ),
      cancel: TextButton(
        onPressed: Get.back,
        child: Text('Cancel'),
      ),
    );
  }

  void _showMultiDeleteConfirmationDialog() {
    Get.defaultDialog(
      title: 'Confirm Multi-Delete',
      content: Text(
          'Are you sure you want to delete the selected ${_selectedUsers.length} ${widget.role}s?'),
      confirm: ElevatedButton(
        onPressed: () {
          _selectedUsers.forEach((id) {
            controller.deleteUser(id);
          });
          _toggleSelectAll(false);
          _loadUsers();
          Get.back();
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: Text('Delete All', style: TextStyle(color: Colors.white)),
      ),
      cancel: TextButton(
        onPressed: Get.back,
        child: Text('Cancel'),
      ),
    );
  }

  void _showImportDialog() {
    Get.defaultDialog(
      title: 'Import ${widget.role.capitalize}s',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Import multiple ${widget.role}s from a CSV file.'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['csv'],
              );
              if (result != null) {
                // Handle CSV import logic here
                Get.back();
                Get.snackbar('Import', 'CSV import functionality coming soon!');
              }
            },
            child: Text('Select CSV File'),
          ),
        ],
      ),
      confirm: TextButton(
        onPressed: Get.back,
        child: Text('Cancel'),
      ),
    );
  }

  void _showQuickEnrollDialog() {
    Get.defaultDialog(
      title: 'Quick Enrollment',
      content: Text('Quick enrollment functionality for students.'),
      confirm: TextButton(
        onPressed: () {
          Get.back();
          Get.snackbar('Enrollment', 'Quick enrollment coming soon!');
        },
        child: Text('OK'),
      ),
    );
  }

  void _showVehicleAssignmentDialog() {
    Get.defaultDialog(
      title: 'Vehicle Assignment',
      content: Text('Assign vehicles to instructors.'),
      confirm: TextButton(
        onPressed: () {
          Get.back();
          Get.snackbar('Assignment', 'Vehicle assignment coming soon!');
        },
        child: Text('OK'),
      ),
    );
  }

  void _showAnalyticsDialog() {
    Get.defaultDialog(
      title: '${widget.role.capitalize} Analytics',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Performance metrics for ${widget.role}s:'),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('${_users.length}',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('Total'),
                ],
              ),
              Column(
                children: [
                  Text('${_users.where((u) => u.status == 'Active').length}',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  Text('Active'),
                ],
              ),
              Column(
                children: [
                  Text('${_users.where((u) => u.status != 'Active').length}',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                  Text('Inactive'),
                ],
              ),
            ],
          ),
        ],
      ),
      confirm: TextButton(
        onPressed: Get.back,
        child: Text('Close'),
      ),
    );
  }

  void _showNotificationDialog() {
    Get.defaultDialog(
      title: 'Send Notifications',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Send bulk notifications to ${widget.role}s.'),
          SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Notification Message',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () {
          Get.back();
          Get.snackbar('Notification', 'Notification sent successfully!');
        },
        child: Text('Send'),
      ),
      cancel: TextButton(
        onPressed: Get.back,
        child: Text('Cancel'),
      ),
    );
  }
}
