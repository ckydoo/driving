// lib/screens/course/enhanced_course_screen.dart
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/course.dart';
import 'package:driving/screens/course/courses_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/course_controller.dart';
import '../../widgets/course_form_dialog.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({Key? key}) : super(key: key);

  @override
  _CourseScreenState createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen>
    with SingleTickerProviderStateMixin {
  final CourseController controller = Get.find<CourseController>();
  final UserController userController = Get.find<UserController>();
  final BillingController billingController = Get.find<BillingController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();

  final TextEditingController _searchController = TextEditingController();
  List<Course> _courses = [];
  List<Course> _searchResults = [];
  List<int> _selectedCourses = [];
  bool _isMultiSelectionActive = false;
  bool _isAllSelected = false;
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _filterStatus = 'all';
  bool _isLoading = true;

  // Pagination variables
  int _currentPage = 1;
  int _rowsPerPage = 12;

  // Tab controller for different views
  late TabController _tabController;

  // Smart recommendations
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _quickStats = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCourses();
    _generateRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Force refresh all data from the source
      await controller.fetchCourses();
      await userController.fetchUsers();
      await billingController.fetchBillingData();
      await scheduleController.fetchSchedules();

      setState(() {
        // Ensure we're getting fresh data from the controller
        _courses = List.from(controller.courses);
        _searchResults = List.from(_courses);

        // Reset filters and search
        _searchController.clear();
        _filterStatus = 'all';
        _sortBy = 'name';
        _sortAscending = true;
        _currentPage = 1;

        // Clear selections
        _selectedCourses.clear();
        _isMultiSelectionActive = false;
        _isAllSelected = false;

        // Regenerate data
        _sortCourses();
        _filterCourses();
        _generateQuickStats();
        _generateRecommendations();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      Get.snackbar(
        'Error',
        'Failed to refresh data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Helper method to determine screen size
  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;
  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1024;
  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  // Get responsive card aspect ratio
  double _getCardAspectRatio(BuildContext context) {
    if (_isMobile(context)) return 1.5;
    if (_isTablet(context)) return 1.3;
    return 1.2;
  }

  void _searchCourses(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = List.from(_courses);
      } else {
        _searchResults = _courses
            .where((course) =>
                course.name.toLowerCase().contains(query.toLowerCase()) ||
                course.status.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _filterCourses();
      _sortCourses();
      _currentPage = 1;
    });
  }

  void _sortCourses() {
    setState(() {
      _searchResults.sort((a, b) {
        dynamic aValue, bValue;
        switch (_sortBy) {
          case 'name':
            aValue = a.name.toLowerCase();
            bValue = b.name.toLowerCase();
            break;
          case 'price':
            aValue = a.price;
            bValue = b.price;
            break;
          case 'status':
            aValue = a.status.toLowerCase();
            bValue = b.status.toLowerCase();
            break;
          case 'created':
            aValue = a.createdAt;
            bValue = b.createdAt;
            break;
          default:
            aValue = a.name.toLowerCase();
            bValue = b.name.toLowerCase();
        }
        return _sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      });
    });
  }

  void _filterCourses() {
    if (_filterStatus != 'all') {
      setState(() {
        _searchResults = _searchResults
            .where((course) =>
                course.status.toLowerCase() == _filterStatus.toLowerCase())
            .toList();
      });
    }
  }

  void _generateQuickStats() {
    final activeCourses =
        _courses.where((c) => c.status.toLowerCase() == 'active').length;
    final totalRevenue = billingController.invoices.fold<double>(
        0.0, (sum, invoice) => sum + invoice.totalAmountCalculated);
    final totalEnrollments = billingController.invoices.length;

    _quickStats = [
      {
        'title': 'Active Courses',
        'value': activeCourses.toString(),
        'icon': Icons.school,
        'color': Colors.green,
        'subtitle': '${_courses.length - activeCourses} inactive',
      },
      {
        'title': 'Total Revenue',
        'value': '\$${totalRevenue.toStringAsFixed(2)}',
        'icon': Icons.attach_money,
        'color': Colors.blue,
        'subtitle': 'From ${totalEnrollments} enrollments',
      },
      {
        'title': 'Total Enrollments',
        'value': totalEnrollments.toString(),
        'icon': Icons.people,
        'color': Colors.purple,
        'subtitle': 'Students enrolled',
      },
    ];
  }

  void _generateRecommendations() {
    _recommendations.clear();

    // Low enrollment courses
    final lowEnrollmentCourses = _courses.where((course) {
      final enrollments = billingController.invoices
          .where((invoice) => scheduleController.schedules
              .any((s) => s.classType == course.name))
          .length;
      return enrollments < 5 && course.status.toLowerCase() == 'active';
    }).length;

    if (lowEnrollmentCourses > 0) {
      _recommendations.add({
        'type': 'warning',
        'title': 'Low Enrollment Alert',
        'description':
            '$lowEnrollmentCourses courses have fewer than 5 enrollments.',
        'action': 'Review Pricing',
        'icon': Icons.trending_down,
        'color': Colors.orange,
        'priority': 'medium',
        'onTap': () => _showLowEnrollmentCourses(),
      });
    }

    // Price optimization
    final highPricedCourses = _courses.where((c) => c.price > 1000).length;
    if (highPricedCourses > 0) {
      _recommendations.add({
        'type': 'suggestion',
        'title': 'Price Optimization',
        'description': '$highPricedCourses courses are priced above \$1000.',
        'action': 'Review Pricing',
        'icon': Icons.price_change,
        'color': Colors.blue,
        'priority': 'low',
        'onTap': () => _showPricingAnalysis(),
      });
    }

    // Inactive courses cleanup
    final inactiveCourses =
        _courses.where((c) => c.status.toLowerCase() == 'inactive').length;
    if (inactiveCourses > 3) {
      _recommendations.add({
        'type': 'info',
        'title': 'Course Cleanup',
        'description': '$inactiveCourses inactive courses taking up space.',
        'action': 'Archive Courses',
        'icon': Icons.cleaning_services,
        'color': Colors.grey,
        'priority': 'low',
        'onTap': () => _showInactiveCourses(),
      });
    }

    // Success metrics
    final recentCourses = _courses
        .where((c) =>
            c.createdAt.isAfter(DateTime.now().subtract(Duration(days: 30))))
        .length;
    if (recentCourses > 0) {
      _recommendations.add({
        'type': 'success',
        'title': 'Course Growth',
        'description': '$recentCourses new courses added this month.',
        'action': 'View Details',
        'icon': Icons.trending_up,
        'color': Colors.green,
        'priority': 'info',
        'onTap': () => _showRecentCourses(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header with stats and controls
          Container(
            padding: EdgeInsets.all(_isMobile(context) ? 12 : 16),
            color: Colors.white,
            child: Column(
              children: [
                // Quick stats cards - responsive
                Container(
                  height: _isMobile(context) ? 110 : 130, // Increased by 10px
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickStats.length,
                    itemBuilder: (context, index) {
                      final stat = _quickStats[index];
                      return Container(
                        width: _isMobile(context) ? 160 : 200,
                        margin: EdgeInsets.only(right: 12),
                        child: _buildStatCard(stat),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),

                // Search and filters - responsive layout
                _buildResponsiveControls(context),
              ],
            ),
          ),

          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[600],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue[600],
              isScrollable: _isMobile(context),
              tabs: [
                Tab(
                  icon: Icon(Icons.list, size: _isMobile(context) ? 20 : 24),
                  text: _isMobile(context) ? 'List' : 'List View',
                ),
                Tab(
                  icon:
                      Icon(Icons.lightbulb, size: _isMobile(context) ? 20 : 24),
                  text: _isMobile(context) ? 'Tips' : 'Recommendations',
                ),
              ],
            ),
          ),

          // Multi-selection bar
          if (_isMultiSelectionActive) _buildMultiSelectionBar(context),

          // Content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListView(),
                      _buildRecommendationsView(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildResponsiveFAB(context),
    );
  }

  Widget _buildResponsiveControls(BuildContext context) {
    if (_isMobile(context)) {
      return Column(
        children: [
          // Search bar - full width on mobile
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search courses...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _searchCourses,
          ),
          SizedBox(height: 12),

          // Filters in a scrollable row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilter(),
                SizedBox(width: 12),
                _buildSortFilter(),
                SizedBox(width: 12),
                _buildResultsCount(),
              ],
            ),
          ),
        ],
      );
    } else {
      // Desktop/tablet layout
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _searchCourses,
            ),
          ),
          SizedBox(width: 16),
          _buildStatusFilter(),
          SizedBox(width: 16),
          _buildSortFilter(),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _sortCourses();
              });
            },
          ),
          Spacer(),
          _buildResultsCount(),
        ],
      );
    }
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: _filterStatus,
        underline: Container(),
        items: [
          DropdownMenuItem(value: 'all', child: Text('All Status')),
          DropdownMenuItem(value: 'active', child: Text('Active')),
          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
        ],
        onChanged: (value) {
          setState(() {
            _filterStatus = value!;
            _filterCourses();
            _currentPage = 1;
          });
        },
      ),
    );
  }

  Widget _buildSortFilter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: _sortBy,
        underline: Container(),
        items: [
          DropdownMenuItem(
              value: 'name',
              child:
                  Text('Sort by Name', style: TextStyle(color: Colors.blue))),
          DropdownMenuItem(value: 'price', child: Text('Sort by Price')),
          DropdownMenuItem(value: 'status', child: Text('Sort by Status')),
          DropdownMenuItem(value: 'created', child: Text('Sort by Date')),
        ],
        onChanged: (value) {
          setState(() {
            _sortBy = value!;
            _sortCourses();
          });
        },
      ),
    );
  }

  Widget _buildResultsCount() {
    return Text(
      '${_searchResults.length} courses',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: _isMobile(context) ? 12 : 14,
      ),
    );
  }

  Widget _buildMultiSelectionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile(context) ? 12 : 16,
        vertical: 8,
      ),
      color: Colors.blue[50],
      child: _isMobile(context)
          ? Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _isAllSelected,
                      onChanged: _toggleSelectAll,
                    ),
                    Text('${_selectedCourses.length} selected'),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _selectedCourses.clear();
                          _isMultiSelectionActive = false;
                          _isAllSelected = false;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.edit, size: 18),
                        label: Text('Bulk Edit'),
                        onPressed: _selectedCourses.isNotEmpty
                            ? () => _bulkEditCourses()
                            : null,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.delete, size: 18),
                        label: Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: _selectedCourses.isNotEmpty
                            ? () => _deleteSelectedCourses()
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Checkbox(
                  value: _isAllSelected,
                  onChanged: _toggleSelectAll,
                ),
                Text('${_selectedCourses.length} selected'),
                Spacer(),
                TextButton.icon(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  label:
                      Text('Bulk Edit', style: TextStyle(color: Colors.blue)),
                  onPressed: _selectedCourses.isNotEmpty
                      ? () => _bulkEditCourses()
                      : null,
                ),
                TextButton.icon(
                  icon: Icon(Icons.delete, color: Colors.red),
                  label: Text('Delete Selected',
                      style: TextStyle(color: Colors.red)),
                  onPressed: _selectedCourses.isNotEmpty
                      ? () => _deleteSelectedCourses()
                      : null,
                ),
              ],
            ),
    );
  }

  Widget _buildResponsiveFAB(BuildContext context) {
    if (_isMobile(context)) {
      return FloatingActionButton.extended(
        onPressed: () async {
          final result = await Get.dialog<bool>(CourseFormDialog());
          if (result == true) {
            await _loadCourses();
          }
        },
        label: Text('Add Course'),
        icon: Icon(Icons.add),
        backgroundColor: Colors.blue[600],
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: () async {
          final result = await Get.dialog<bool>(CourseFormDialog());
          if (result == true) {
            await _loadCourses();
          }
        },
        label: Text('Add Course'),
        icon: Icon(Icons.add),
        backgroundColor: Colors.blue[600],
      );
    }
  }

  Widget _buildStatCard(Map<String, dynamic> stat) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(
            _isMobile(context) ? 10 : 14), // Reduced padding slightly
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important to prevent overflow
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  stat['icon'],
                  color: stat['color'],
                  size: _isMobile(context)
                      ? 18
                      : 22, // Slightly reduced icon size
                ),
                Flexible(
                  child: Text(
                    stat['value'],
                    style: TextStyle(
                      fontSize: _isMobile(context)
                          ? 15
                          : 18, // Slightly reduced font size
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6), // Reduced spacing
            Text(
              stat['title'],
              style: TextStyle(
                fontSize:
                    _isMobile(context) ? 11 : 13, // Slightly reduced font size
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              stat['subtitle'],
              style: TextStyle(
                fontSize:
                    _isMobile(context) ? 9 : 11, // Slightly reduced font size
                color: Colors.grey[500],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    final courses = _getPaginatedCourses();

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.all(_isMobile(context) ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ListView.separated(
              itemCount: courses.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final course = courses[index];
                return _buildCourseListTile(course);
              },
            ),
          ),
        ),
        _buildPagination(),
      ],
    );
  }

  Widget _buildCourseListTile(Course course) {
    final isSelected = _selectedCourses.contains(course.id);
    final enrollments = billingController.invoices
        .where((invoice) =>
            scheduleController.schedules.any((s) => s.classType == course.name))
        .length;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: _isMobile(context) ? 12 : 16,
        vertical: _isMobile(context) ? 4 : 8,
      ),
      leading: _isMobile(context)
          ? (_isMultiSelectionActive
              ? Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleCourseSelection(course.id!),
                )
              : Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: course.status.toLowerCase() == 'active'
                        ? Colors.blue[100]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school,
                    size: 20,
                    color: course.status.toLowerCase() == 'active'
                        ? Colors.blue[600]
                        : Colors.grey[600],
                  ),
                ))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isMultiSelectionActive)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleCourseSelection(course.id!),
                  ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: course.status.toLowerCase() == 'active'
                        ? Colors.blue[100]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school,
                    color: course.status.toLowerCase() == 'active'
                        ? Colors.blue[600]
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
      title: Text(
        course.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: _isMobile(context) ? 14 : 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$enrollments enrollments • Created ${_formatDate(course.createdAt)}',
            style: TextStyle(fontSize: _isMobile(context) ? 12 : 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip(course.status),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\$${course.price}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'edit':
              final result = await Get.dialog<bool>(
                CourseFormDialog(course: course),
              );
              if (result == true) {
                _loadCourses();
              }
              break;
            case 'delete':
              _deleteCourse(course);
              break;
            case 'duplicate':
              _duplicateCourse(course);
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'duplicate',
            child: Row(
              children: [
                Icon(Icons.copy, size: 20),
                SizedBox(width: 8),
                Text('Duplicate'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CourseDetailsScreen(courseId: course.id!),
          ),
        );
      },
      onLongPress: () => _toggleCourseSelection(course.id!),
    );
  }

  Widget _buildRecommendationsView() {
    return Container(
      padding: EdgeInsets.all(_isMobile(context) ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Recommendations',
            style: TextStyle(
              fontSize: _isMobile(context) ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            'AI-powered insights to optimize your course management',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: _isMobile(context) ? 12 : 14,
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: _recommendations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: _isMobile(context) ? 48 : 64,
                            color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No recommendations at this time',
                          style: TextStyle(
                            fontSize: _isMobile(context) ? 16 : 18,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Your course management is on track!',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: _isMobile(context) ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _recommendations.length,
                    itemBuilder: (context, index) {
                      final recommendation = _recommendations[index];
                      return _buildRecommendationCard(recommendation);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    Color cardColor;
    switch (recommendation['type']) {
      case 'urgent':
        cardColor = Colors.red[50]!;
        break;
      case 'warning':
        cardColor = Colors.orange[50]!;
        break;
      case 'success':
        cardColor = Colors.green[50]!;
        break;
      default:
        cardColor = Colors.blue[50]!;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: recommendation['onTap'],
        child: Container(
          padding: EdgeInsets.all(_isMobile(context) ? 12 : 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: recommendation['color'].withOpacity(0.3)),
          ),
          child: _isMobile(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          recommendation['icon'],
                          size: 24,
                          color: recommendation['color'],
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            recommendation['title'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      recommendation['description'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: recommendation['onTap'],
                        style: ElevatedButton.styleFrom(
                          backgroundColor: recommendation['color'],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(recommendation['action']),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      recommendation['icon'],
                      size: 32,
                      color: recommendation['color'],
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recommendation['title'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            recommendation['description'],
                            style: TextStyle(color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: recommendation['onTap'],
                      style: ElevatedButton.styleFrom(
                        backgroundColor: recommendation['color'],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(recommendation['action']),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[100] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isActive ? Colors.green[800] : Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_searchResults.length / _rowsPerPage).ceil();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile(context) ? 12 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: _isMobile(context)
          ? Column(
              children: [
                Text(
                  'Showing ${((_currentPage - 1) * _rowsPerPage) + 1}-${(_currentPage * _rowsPerPage).clamp(0, _searchResults.length)} of ${_searchResults.length}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left),
                      onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                    ),
                    Text('$_currentPage of $totalPages'),
                    IconButton(
                      icon: Icon(Icons.chevron_right),
                      onPressed:
                          _currentPage < totalPages ? _goToNextPage : null,
                    ),
                  ],
                ),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: [6, 12, 24, 48].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value per page'),
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
            )
          : Row(
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
                  items: [6, 12, 24, 48].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value per page'),
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

  List<Course> _getPaginatedCourses() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= _searchResults.length) {
      return [];
    }
    return _searchResults.sublist(startIndex,
        endIndex > _searchResults.length ? _searchResults.length : endIndex);
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _selectedCourses.clear();
        _isMultiSelectionActive = false;
        _isAllSelected = false;
      });
    }
  }

  void _goToNextPage() {
    final totalPages = (_searchResults.length / _rowsPerPage).ceil();
    if (_currentPage < totalPages) {
      setState(() {
        _currentPage++;
        _selectedCourses.clear();
        _isMultiSelectionActive = false;
        _isAllSelected = false;
      });
    }
  }

  void _toggleCourseSelection(int courseId) {
    setState(() {
      if (_selectedCourses.contains(courseId)) {
        _selectedCourses.remove(courseId);
      } else {
        _selectedCourses.add(courseId);
      }
      _isMultiSelectionActive = _selectedCourses.isNotEmpty;
      _isAllSelected = _selectedCourses.length == _getPaginatedCourses().length;
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isAllSelected = value ?? false;
      if (_isAllSelected) {
        _selectedCourses =
            _getPaginatedCourses().map((course) => course.id!).toList();
      } else {
        _selectedCourses.clear();
      }
      _isMultiSelectionActive = _selectedCourses.isNotEmpty;
    });
  }

  void _deleteCourse(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Course'),
        content: Text(
            'Are you sure you want to delete "${course.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await controller.deleteCourse(course.id!);
        await _loadCourses();

        Get.snackbar(
          'Success',
          'Course "${course.name}" deleted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: Duration(seconds: 2),
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to delete course: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: Duration(seconds: 3),
        );
      }
    }
  }

  void _deleteSelectedCourses() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Selected Courses'),
        content: Text(
            'Are you sure you want to delete ${_selectedCourses.length} selected courses? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (int courseId in _selectedCourses) {
          await controller.deleteCourse(courseId);
        }

        setState(() {
          _selectedCourses.clear();
          _isMultiSelectionActive = false;
          _isAllSelected = false;
        });

        await _loadCourses();

        Get.snackbar(
          'Success',
          'Selected courses deleted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: Duration(seconds: 2),
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to delete courses: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: Duration(seconds: 3),
        );
      }
    }
  }

  void _duplicateCourse(Course course) async {
    final duplicatedCourse = Course(
      name: '${course.name} (Copy)',
      price: course.price,
      status: 'inactive',
      createdAt: DateTime.now(),
    );

    try {
      await controller.handleCourse(duplicatedCourse, isUpdate: false);
      _loadCourses();
      Get.snackbar(
        'Success',
        'Course duplicated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to duplicate course: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _bulkEditCourses() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bulk Edit Courses'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Select an action for ${_selectedCourses.length} selected courses:'),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Activate All'),
              onTap: () {
                Navigator.pop(context);
                _bulkUpdateStatus('active');
              },
            ),
            ListTile(
              leading: Icon(Icons.pause_circle, color: Colors.orange),
              title: Text('Deactivate All'),
              onTap: () {
                Navigator.pop(context);
                _bulkUpdateStatus('inactive');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _bulkUpdateStatus(String newStatus) async {
    try {
      for (int courseId in _selectedCourses) {
        final course = _courses.firstWhere((c) => c.id == courseId);
        final updatedCourse = Course(
          id: course.id,
          name: course.name,
          price: course.price,
          status: newStatus,
          createdAt: course.createdAt,
        );
        await controller.handleCourse(updatedCourse, isUpdate: true);
      }

      setState(() {
        _selectedCourses.clear();
        _isMultiSelectionActive = false;
        _isAllSelected = false;
      });
      _loadCourses();

      Get.snackbar(
        'Success',
        'Courses updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update courses: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      return '${(difference / 7).floor()} weeks ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showLowEnrollmentCourses() {
    final lowEnrollmentCourses = _courses.where((course) {
      final enrollments = billingController.invoices
          .where((invoice) => scheduleController.schedules
              .any((s) => s.classType == course.name))
          .length;
      return enrollments < 5 && course.status.toLowerCase() == 'active';
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Low Enrollment Courses'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('These courses have fewer than 5 enrollments:'),
              SizedBox(height: 16),
              ...lowEnrollmentCourses.map((course) => ListTile(
                    leading: Icon(Icons.school, color: Colors.orange),
                    title: Text(course.name),
                    subtitle: Text('\$${course.price}'),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.dialog(CourseFormDialog(course: course));
                      },
                      child: Text('Edit'),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPricingAnalysis() {
    final highPricedCourses = _courses.where((c) => c.price > 1000).toList();
    final avgPrice =
        _courses.fold<double>(0.0, (sum, course) => sum + course.price) /
            _courses.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pricing Analysis'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Average course price: \$${avgPrice.toStringAsFixed(2)}'),
              SizedBox(height: 16),
              Text('High-priced courses (>\$1000):'),
              SizedBox(height: 8),
              ...highPricedCourses.map((course) => ListTile(
                    leading: Icon(Icons.attach_money, color: Colors.red),
                    title: Text(course.name),
                    subtitle: Text('\$${course.price}'),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.dialog(CourseFormDialog(course: course));
                      },
                      child: Text('Adjust'),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInactiveCourses() {
    final inactiveCourses =
        _courses.where((c) => c.status.toLowerCase() == 'inactive').toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Inactive Courses'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Consider archiving these inactive courses:'),
              SizedBox(height: 16),
              ...inactiveCourses.map((course) => ListTile(
                    leading: Icon(Icons.archive, color: Colors.grey),
                    title: Text(course.name),
                    subtitle:
                        Text('Inactive since ${_formatDate(course.createdAt)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await controller.deleteCourse(course.id!);
                            Navigator.pop(context);
                            _loadCourses();
                          },
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Get.dialog(CourseFormDialog(course: course));
                          },
                          child: Text('Edit'),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRecentCourses() {
    final recentCourses = _courses
        .where((c) =>
            c.createdAt.isAfter(DateTime.now().subtract(Duration(days: 30))))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recent Courses'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Courses added in the last 30 days:'),
              SizedBox(height: 16),
              ...recentCourses.map((course) => ListTile(
                    leading: Icon(Icons.new_releases, color: Colors.green),
                    title: Text(course.name),
                    subtitle: Text('Added ${_formatDate(course.createdAt)}'),
                    trailing: _buildStatusChip(course.status),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
