// lib/screens/users/enhanced_users_screen.dart
// ignore_for_file: unused_field

import 'package:driving/screens/users/enhanced_recommendations_screen.dart';
import 'package:driving/screens/users/add_user_screen.dart';
import 'package:driving/screens/users/graduation_screen.dart';
import 'package:driving/screens/users/student_details_screen.dart';
import 'package:driving/screens/users/user_form_dialog.dart';
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
        'title': 'Send Notification',
        'description': 'Send bulk notifications',
        'action': () => _showNotificationDialog(),
        'color': Colors.red,
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

  void _goToNextPage() {
    final totalPages = (_searchResults.length / _rowsPerPage).ceil();
    if (_currentPage < totalPages) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ResponsiveWrapper(
        child: Column(
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
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildTopSection() {
    return Container(
      padding: EdgeInsets.all(context.isMobile ? 12.0 : 16.0),
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
          // Search and Filter Row
          _buildSearchAndFilterRow(),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    if (context.isMobile) {
      return Column(
        children: [
          // Search bar first on mobile
          SizedBox(
            width: double.infinity,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ${widget.role.capitalize}s...',
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
          SizedBox(height: 8),
          // Action buttons row on mobile
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(),
                SizedBox(width: 8),
                _buildSortButton(),
                SizedBox(width: 8),
                if (widget.role.toLowerCase() == 'student') ...[
                  _buildImportButton(),
                  SizedBox(width: 8),
                ],
                _buildRefreshButton(),
              ],
            ),
          ),
        ],
      );
    }

    // Desktop/tablet layout
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search ${widget.role.capitalize}s...',
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
        if (widget.role.toLowerCase() == 'student') ...[
          _buildImportButton(),
          SizedBox(width: 8),
        ],
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildImportButton() {
    if (context.isMobile) {
      return IconButton(
        onPressed: _showImportDialog,
        icon: Icon(Icons.upload_file),
        tooltip: 'Import Students',
        style: IconButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _showImportDialog,
      icon: Icon(Icons.upload_file),
      label: Text('Import Students'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFilterChip() {
    return PopupMenuButton<String>(
      child: Chip(
        label: Text('Filter: ${_filterStatus.capitalize}'),
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
        PopupMenuItem(value: 'date', child: Text('Date Created')),
        PopupMenuItem(value: 'status', child: Text('Status')),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      onPressed: _loadUsers,
      icon: Icon(Icons.refresh),
      tooltip: 'Refresh',
      style: IconButton.styleFrom(
        backgroundColor: Colors.grey[200],
      ),
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
            text: '${widget.role.capitalize}s',
          ),
          Tab(
            icon: Icon(Icons.lightbulb),
            text: 'Recommendations',
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          if (!context.isMobile) _buildHeaderRow(),
          Expanded(
            child: _users.isEmpty
                ? _buildEmptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final users = _getPaginatedUsers();
                      if (users.isEmpty) {
                        return Center(
                          child: ResponsiveText(
                            style: TextStyle(),
                            'No ${widget.role}s found matching your criteria',
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        );
                      }

                      if (context.isMobile) {
                        return ListView.separated(
                          padding: EdgeInsets.all(8),
                          itemCount: users.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return _buildMobileUserCard(user, index);
                          },
                        );
                      } else {
                        return ListView.separated(
                          itemCount: users.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return _buildUserCard(user, index);
                          },
                        );
                      }
                    },
                  ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildMobileUserCard(User user, int index) {
    final isSelected = _selectedUsers.contains(user.id);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
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
        onLongPress: () => _toggleUserSelection(user.id!),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : null,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: Colors.blue[200]!) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isMultiSelectionActive)
                    Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) =>
                          _toggleUserSelection(user.id!),
                    ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      '${user.fname[0]}${user.lname[0]}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
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
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.phone,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(user.status),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID: ${user.idnumber}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => Get.dialog(
                          AddUserScreen(role: widget.role, user: user),
                        ),
                        icon: Icon(Icons.edit, size: 18),
                        tooltip: 'Edit',
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.all(4),
                      ),
                      IconButton(
                        onPressed: () => _showDeleteDialog(user),
                        icon: Icon(Icons.delete, size: 18, color: Colors.red),
                        tooltip: 'Delete',
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.all(4),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(User user, int index) {
    final isSelected = _selectedUsers.contains(user.id);

    return Container(
      color: isSelected ? Colors.blue[50] : null,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isMultiSelectionActive)
              Checkbox(
                value: isSelected,
                onChanged: (bool? value) => _toggleUserSelection(user.id!),
              ),
            CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                '${user.fname[0]}${user.lname[0]}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ),
          ],
        ),
        title: Text(
          '${user.fname} ${user.lname}',
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Phone: ${user.phone}',
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Container(
          width: 120,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusChip(user.status),
              SizedBox(width: 8),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () => Get.dialog(
                      AddUserScreen(role: widget.role, user: user),
                    ),
                  ),
                  PopupMenuItem(
                      child: ListTile(
                        leading: Icon(Icons.star),
                        title: Text('Graduate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                GraduationScreen(student: user),
                          ),
                        );
                      }),
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title:
                          Text('Delete', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () => _showDeleteDialog(user),
                  ),
                ],
                child: Icon(Icons.more_vert),
              ),
            ],
          ),
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
          if (_isMultiSelectionActive)
            Checkbox(
              value: _isAllSelected,
              onChanged: (bool? value) => _toggleSelectAll(value!),
            ),
          Expanded(
              flex: 2,
              child:
                  Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 2,
              child:
                  Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child:
                  Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Status',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Container(
              width: 120,
              child: Text('Actions',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalUsers =
        _searchResults.isNotEmpty ? _searchResults.length : _users.length;
    final totalPages =
        (totalUsers / _rowsPerPage).ceil().clamp(1, double.infinity).toInt();

    if (totalUsers == 0) return SizedBox();

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.isMobile ? 8 : 16,
          vertical: context.isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: context.isMobile
          ? _buildMobilePagination(totalUsers, totalPages)
          : _buildDesktopPagination(totalUsers, totalPages),
    );
  }

  Widget _buildMobilePagination(int totalUsers, int totalPages) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Page $_currentPage of $totalPages',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                '$totalUsers items',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: ElevatedButton.icon(
                onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                icon: Icon(Icons.chevron_left, size: 16),
                label: Text('Prev', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(0, 32),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<int>(
                  value: _rowsPerPage,
                  isDense: true,
                  underline: SizedBox(),
                  items: [10, 25, 50, 100].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value', style: TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (int? value) {
                    if (value != null) {
                      setState(() {
                        _rowsPerPage = value;
                        _currentPage = 1;
                      });
                    }
                  },
                ),
              ),
            ),
            SizedBox(width: 8),
            Flexible(
              child: ElevatedButton.icon(
                onPressed: _currentPage < totalPages ? _goToNextPage : null,
                icon: Icon(Icons.chevron_right, size: 16),
                label: Text('Next', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(0, 32),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopPagination(int totalUsers, int totalPages) {
    // Check available width to determine layout
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;

        if (isCompact) {
          // Use compact layout for medium screens
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Showing ${((_currentPage - 1) * _rowsPerPage) + 1}-${(_currentPage * _rowsPerPage).clamp(0, totalUsers)} of $totalUsers',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rows: ',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        DropdownButton<int>(
                          value: _rowsPerPage,
                          isDense: true,
                          underline: SizedBox(),
                          items: [10, 25, 50, 100].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value',
                                  style: TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (int? value) {
                            if (value != null) {
                              setState(() {
                                _rowsPerPage = value;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, size: 20),
                    onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$_currentPage of $totalPages',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, size: 20),
                    onPressed: _currentPage < totalPages ? _goToNextPage : null,
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          );
        }

        // Full desktop layout
        return Row(
          children: [
            Flexible(
              flex: 2,
              child: Text(
                'Showing ${((_currentPage - 1) * _rowsPerPage) + 1}-${(_currentPage * _rowsPerPage).clamp(0, totalUsers)} of $totalUsers',
                style: TextStyle(color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.chevron_left),
              onPressed: _currentPage > 1 ? _goToPreviousPage : null,
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('$_currentPage of $totalPages'),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right),
              onPressed: _currentPage < totalPages ? _goToNextPage : null,
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rows: ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: [10, 25, 50, 100].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value'),
                    );
                  }).toList(),
                  onChanged: (int? value) {
                    if (value != null) {
                      setState(() {
                        _rowsPerPage = value;
                        _currentPage = 1;
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.isMobile ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.role == 'student' ? Icons.school : Icons.person,
              size: context.isMobile ? 60 : 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            ResponsiveText(
              style: TextStyle(),
              'No ${widget.role}s found',
              fontSize: context.isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
            SizedBox(height: 8),
            ResponsiveText(
              style: TextStyle(),
              'Start by adding your first ${widget.role}',
              fontSize: 16,
              color: Colors.grey[500],
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Get.dialog(AddUserScreen(role: widget.role)),
              icon: Icon(Icons.add),
              label: Text('Add ${widget.role.capitalize}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                    horizontal: context.isMobile ? 20 : 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsView() {
    return EnhancedRecommendationsScreen(role: widget.role);
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => Get.dialog(AddUserScreen(role: widget.role)),
      child: Icon(Icons.add),
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
      tooltip: 'Add ${widget.role.capitalize}',
    );
  }

  // Dialog methods (keeping existing logic)
  void _showImportDialog() {
    if (widget.role.toLowerCase() == 'student') {
      Get.to(() => BulkStudentUploadScreen());
    } else {
      // Show file picker for other roles
      _showFileImportDialog();
    }
  }

  void _showFileImportDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Import ${widget.role.capitalize}s'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a CSV file to import ${widget.role}s'),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                Get.back();
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['csv'],
                );
                if (result != null) {
                  // Handle file import logic
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
    // Implement file import logic
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

  void _showQuickEnrollDialog() {
    // Implement quick enroll dialog
    Get.snackbar('Coming Soon', 'Quick enrollment feature coming soon!');
  }

  void _showVehicleAssignmentDialog() {
    // Implement vehicle assignment dialog
    Get.snackbar('Coming Soon', 'Vehicle assignment feature coming soon!');
  }

  void _showAnalyticsDialog() {
    // Implement analytics dialog
    Get.snackbar('Coming Soon', 'Analytics feature coming soon!');
  }

  void _showNotificationDialog() {
    // Implement notification dialog
    Get.snackbar('Coming Soon', 'Bulk notifications feature coming soon!');
  }
}
