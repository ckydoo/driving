// lib/screens/overview/quick_search_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/billing_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../controllers/course_controller.dart';
import '../../models/user.dart';

class QuickSearchScreen extends StatefulWidget {
  @override
  _QuickSearchScreenState createState() => _QuickSearchScreenState();
}

class _QuickSearchScreenState extends State<QuickSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final userController = Get.find<UserController>();
  final billingController = Get.find<BillingController>();
  final scheduleController = Get.find<ScheduleController>();
  final courseController = Get.find<CourseController>();

  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String _selectedFilter = 'All';
  User? _selectedPerson;

  final List<String> _filterOptions = ['All', 'Students', 'Instructors'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedPerson = null;
      });
    } else {
      _performSearch(_searchController.text);
    }
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = true;
    });

    List<dynamic> results = [];

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    query = query.toLowerCase().trim();

    var users = userController.users.where((user) {
      bool matchesFilter = _selectedFilter == 'All' ||
          (_selectedFilter == 'Students' &&
              user.role.toLowerCase() == 'student') ||
          (_selectedFilter == 'Instructors' &&
              user.role.toLowerCase() == 'instructor');

      if (!matchesFilter) return false;

      String fullName = '${user.fname} ${user.lname}'.toLowerCase();
      String email = user.email.toLowerCase();
      String phone = user.phone.toLowerCase();

      bool matchesQuery = fullName.contains(query) ||
          user.fname.toLowerCase().contains(query) ||
          user.lname.toLowerCase().contains(query) ||
          email.contains(query) ||
          phone
              .replaceAll(RegExp(r'[^\d]'), '')
              .contains(query.replaceAll(RegExp(r'[^\d]'), ''));

      return matchesQuery;
    }).toList();

    users.sort((a, b) {
      String aFullName = '${a.fname} ${a.lname}'.toLowerCase();
      String bFullName = '${b.fname} ${b.lname}'.toLowerCase();

      if (aFullName.startsWith(query) && !bFullName.startsWith(query))
        return -1;
      if (!aFullName.startsWith(query) && bFullName.startsWith(query)) return 1;

      if (a.fname.toLowerCase().startsWith(query) &&
          !b.fname.toLowerCase().startsWith(query)) return -1;
      if (!a.fname.toLowerCase().startsWith(query) &&
          b.fname.toLowerCase().startsWith(query)) return 1;

      return aFullName.compareTo(bFullName);
    });

    results.addAll(users);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectPerson(User person) {
    setState(() {
      _selectedPerson = person;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSearchHeader(),
                  _buildFilterChips(),
                  Expanded(child: _buildSearchResults()),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _selectedPerson != null
                ? _buildPersonDetails()
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Search & Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Search students and instructors to quickly view schedules and billing',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or phone...',
              prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      height: 50,
      child: Row(
        children: _filterOptions.map((filter) {
          bool isSelected = _selectedFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
                if (_searchController.text.isNotEmpty) {
                  _performSearch(_searchController.text);
                }
              },
              selectedColor: Colors.blue.shade100,
              checkmarkColor: Colors.blue.shade800,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue.shade800 : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'Start typing to search',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final person = _searchResults[index] as User;
        bool isSelected = _selectedPerson?.id == person.id;

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected ? Colors.blue.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _selectPerson(person),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Colors.blue.shade200
                        : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: person.role.toLowerCase() == 'student'
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      child: Icon(
                        person.role.toLowerCase() == 'student'
                            ? Icons.school
                            : Icons.person,
                        color: person.role.toLowerCase() == 'student'
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${person.fname} ${person.lname}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            person.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            person.phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: person.role.toLowerCase() == 'student'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        person.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: person.role.toLowerCase() == 'student'
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 24),
          Text(
            'Select a person to view details',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Search and select a student or instructor\nto see their schedule and billing information',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonDetails() {
    if (_selectedPerson == null) return _buildEmptyState();

    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPersonHeader(),
          SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildQuickStats(),
                  SizedBox(height: 24),
                  _buildRecentSchedules(),
                  SizedBox(height: 24),
                  if (_selectedPerson!.role.toLowerCase() == 'student')
                    _buildBillingOverview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _selectedPerson!.role.toLowerCase() == 'student'
              ? [Colors.green.shade600, Colors.green.shade400]
              : [Colors.orange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Icon(
              _selectedPerson!.role.toLowerCase() == 'student'
                  ? Icons.school
                  : Icons.person,
              size: 32,
              color: _selectedPerson!.role.toLowerCase() == 'student'
                  ? Colors.green.shade600
                  : Colors.orange.shade600,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedPerson!.fname} ${_selectedPerson!.lname}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _selectedPerson!.role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.email,
                        size: 16, color: Colors.white.withOpacity(0.9)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedPerson!.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone,
                        size: 16, color: Colors.white.withOpacity(0.9)),
                    SizedBox(width: 6),
                    Text(
                      _selectedPerson!.phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    int totalSchedules = scheduleController.schedules
        .where((s) => _selectedPerson!.role.toLowerCase() == 'student'
            ? s.studentId == _selectedPerson!.id
            : s.instructorId == _selectedPerson!.id)
        .length;

    int completedSchedules = scheduleController.schedules
        .where((s) =>
            (_selectedPerson!.role.toLowerCase() == 'student'
                ? s.studentId == _selectedPerson!.id
                : s.instructorId == _selectedPerson!.id) &&
            s.attended)
        .length;

    int upcomingSchedules = scheduleController.schedules
        .where((s) =>
            (_selectedPerson!.role.toLowerCase() == 'student'
                ? s.studentId == _selectedPerson!.id
                : s.instructorId == _selectedPerson!.id) &&
            s.start.isAfter(DateTime.now()) &&
            s.status.toLowerCase() != 'cancelled')
        .length;

    double totalOwed = 0;
    if (_selectedPerson!.role.toLowerCase() == 'student') {
      totalOwed = billingController.invoices
          .where((inv) => inv.studentId == _selectedPerson!.id)
          .fold<double>(0, (sum, inv) => sum + inv.balance);
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Lessons',
            '$totalSchedules',
            Icons.book,
            Colors.blue,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            '$completedSchedules',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Upcoming',
            '$upcomingSchedules',
            Icons.schedule,
            Colors.orange,
          ),
        ),
        if (_selectedPerson!.role.toLowerCase() == 'student') ...[
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Balance',
              '\$${totalOwed.toStringAsFixed(2)}',
              Icons.account_balance_wallet,
              totalOwed > 0 ? Colors.red : Colors.green,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSchedules() {
    var recentSchedules = scheduleController.schedules
        .where((s) => _selectedPerson!.role.toLowerCase() == 'student'
            ? s.studentId == _selectedPerson!.id
            : s.instructorId == _selectedPerson!.id)
        .toList();

    recentSchedules.sort((a, b) => b.start.compareTo(a.start));
    recentSchedules = recentSchedules.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Recent Schedules',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          if (recentSchedules.isEmpty)
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.schedule, size: 48, color: Colors.grey[300]),
                    SizedBox(height: 8),
                    Text(
                      'No schedules found',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: recentSchedules.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final schedule = recentSchedules[index];
                final course = courseController.courses
                    .firstWhereOrNull((c) => c.id == schedule.courseId);

                bool isUpcoming = schedule.start.isAfter(DateTime.now());
                Color statusColor = _getStatusColor(schedule.status);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(
                      isUpcoming
                          ? Icons.schedule
                          : schedule.attended
                              ? Icons.check_circle
                              : Icons.schedule,
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    course?.name ?? 'Unknown Course',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${DateFormat('MMM dd, yyyy').format(schedule.start)} at ${DateFormat('h:mm a').format(schedule.start)}',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      schedule.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBillingOverview() {
    var studentInvoices = billingController.invoices
        .where((inv) => inv.studentId == _selectedPerson!.id)
        .toList();

    double totalPaid =
        studentInvoices.fold<double>(0, (sum, inv) => sum + inv.amountPaid);
    double totalBalance =
        studentInvoices.fold<double>(0, (sum, inv) => sum + inv.balance);
    int totalLessons =
        studentInvoices.fold<int>(0, (sum, inv) => sum + inv.lessons);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.receipt, color: Colors.green.shade600),
                SizedBox(width: 8),
                Text(
                  'Billing Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Paid:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('\$${totalPaid.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Outstanding Balance:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('\$${totalBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                totalBalance > 0 ? Colors.red : Colors.green)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Lessons:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('$totalLessons',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if (studentInvoices.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${studentInvoices.length} active invoice(s)',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'confirmed':
        return Colors.blue;
      case 'scheduled':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
