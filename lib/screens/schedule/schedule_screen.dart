import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final Rx<DateTime> _focusedDay = DateTime.now().obs;
  final Rx<DateTime?> _selectedDay = Rx<DateTime?>(null);
  String _currentView = 'month'; // month, week, day

  // Filter variables
  String? _selectedInstructorFilter;
  String? _selectedStudentFilter;
  String? _selectedStatusFilter;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildViewToggle(),
          if (_showFilters) _buildFilterSection(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarView(),
                _buildListView(),
                _buildAnalyticsView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFABWithOptions(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      title: Text(
        'Schedule Management',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: Icon(
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined),
          onPressed: () => setState(() => _showFilters = !_showFilters),
          tooltip: 'Toggle Filters',
        ),
        IconButton(
          icon: Icon(Icons.refresh),
          onPressed: _refreshData,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(value: 'export', child: Text('Export Schedule')),
            PopupMenuItem(value: 'settings', child: Text('Settings')),
            PopupMenuItem(value: 'bulk_actions', child: Text('Bulk Actions')),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Theme.of(context).primaryColor,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey,
        tabs: [
          Tab(icon: Icon(Icons.calendar_month), text: 'Calendar'),
          Tab(icon: Icon(Icons.list), text: 'List'),
          Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text('View: ', style: TextStyle(fontWeight: FontWeight.w500)),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'month', label: Text('Month')),
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'day', label: Text('Day')),
            ],
            selected: {_currentView},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _currentView = newSelection.first);
            },
          ),
          Spacer(),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.today, size: 20),
          onPressed: () => _focusedDay.value = DateTime.now(),
          tooltip: 'Go to Today',
        ),
        IconButton(
          icon: Icon(Icons.search, size: 20),
          onPressed: _showSearchDialog,
          tooltip: 'Search',
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildFilterChip('Instructor', _selectedInstructorFilter,
                  (value) => setState(() => _selectedInstructorFilter = value)),
              _buildFilterChip('Student', _selectedStudentFilter,
                  (value) => setState(() => _selectedStudentFilter = value)),
              _buildFilterChip('Status', _selectedStatusFilter,
                  (value) => setState(() => _selectedStatusFilter = value)),
            ],
          ),
          if (_hasActiveFilters()) ...[
            SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: Icon(Icons.clear, size: 16),
                  label: Text('Clear All'),
                ),
                Spacer(),
                Text(
                  '${_getFilteredCount()} lessons found',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, String? value, Function(String?) onChanged) {
    return FilterChip(
      label: Text(value ?? label),
      selected: value != null,
      onSelected: (selected) {
        if (selected) {
          _showFilterOptions(label, onChanged);
        } else {
          onChanged(null);
        }
      },
      avatar: value != null ? Icon(Icons.check, size: 16) : null,
    );
  }

  Widget _buildCalendarView() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildCalendarHeader(),
          Expanded(
            child: TableCalendar(
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2030),
              focusedDay: _focusedDay.value,
              selectedDayPredicate: (day) => isSameDay(_selectedDay.value, day),
              calendarFormat: _getCalendarFormat(),
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.red[400]),
                holidayTextStyle: TextStyle(color: Colors.red[400]),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markersAlignment: Alignment.bottomCenter,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronVisible: false,
                rightChevronVisible: false,
              ),
              onDaySelected: _onDaySelected,
              onPageChanged: (focusedDay) => _focusedDay.value = focusedDay,
            ),
          ),
          if (_selectedDay.value != null) _buildDaySchedulePreview(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: _previousPeriod,
          ),
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getHeaderText(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: _nextPeriod,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySchedulePreview() {
    final events = _getEventsForDay(_selectedDay.value!);

    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(_selectedDay.value!),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              Spacer(),
              TextButton(
                onPressed: () => _openDayView(_selectedDay.value!),
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 8),
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Text(
                      'No lessons scheduled',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) =>
                        _buildScheduleCard(events[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildListHeader(),
          Expanded(
            child: _buildScheduleList(),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Icon(Icons.sort, size: 20),
          SizedBox(width: 8),
          Text('Sort by: '),
          DropdownButton<String>(
            value: 'date',
            underline: SizedBox(),
            items: [
              DropdownMenuItem(value: 'date', child: Text('Date')),
              DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
              DropdownMenuItem(value: 'student', child: Text('Student')),
              DropdownMenuItem(value: 'status', child: Text('Status')),
            ],
            onChanged: (value) {
              // Handle sort change
            },
          ),
          Spacer(),
          Text('${_getTotalCount()} total lessons'),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 10, // Replace with actual data
      itemBuilder: (context, index) => _buildEnhancedScheduleCard(index),
    );
  }

  Widget _buildEnhancedScheduleCard(int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openScheduleDetails(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue[100],
                    child: Text('S${index + 1}'),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Name ${index + 1}',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'with Instructor Name',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge('Scheduled'),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(Icons.access_time, '10:00 - 11:00'),
                  SizedBox(width: 8),
                  _buildInfoChip(Icons.directions_car, 'ABC-123'),
                  SizedBox(width: 8),
                  _buildInfoChip(Icons.location_on, 'Practical'),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(Colors.green),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('6/10 lessons', style: TextStyle(fontSize: 12)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editSchedule(index),
                    icon: Icon(Icons.edit, size: 16),
                    label: Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: () => _cancelSchedule(index),
                    icon: Icon(Icons.cancel, size: 16),
                    label: Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsView() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAnalyticsCards(),
          SizedBox(height: 16),
          _buildAnalyticsChart(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    return Row(
      children: [
        Expanded(
            child: _buildAnalyticsCard('Today', '8', 'Lessons', Colors.blue)),
        SizedBox(width: 12),
        Expanded(
            child: _buildAnalyticsCard(
                'This Week', '42', 'Lessons', Colors.green)),
        SizedBox(width: 12),
        Expanded(
            child: _buildAnalyticsCard(
                'Completion', '87%', 'Rate', Colors.orange)),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, String subtitle, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChart() {
    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Weekly Schedule Chart\n(Chart implementation would go here)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildFABWithOptions() {
    return FloatingActionButton.extended(
      onPressed: _showCreateOptions,
      icon: Icon(Icons.add),
      label: Text('New Lesson'),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(dynamic event) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mock Lesson',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                Text('10:00 - 11:00',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          _buildStatusBadge('Scheduled'),
        ],
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  CalendarFormat _getCalendarFormat() {
    switch (_currentView) {
      case 'week':
        return CalendarFormat.week;
      case 'day':
        return CalendarFormat.week; // TableCalendar doesn't have day format
      default:
        return CalendarFormat.month;
    }
  }

  String _getHeaderText() {
    switch (_currentView) {
      case 'week':
        return 'Week of ${DateFormat('MMM d').format(_focusedDay.value)}';
      case 'day':
        return DateFormat('EEEE, MMMM d').format(_focusedDay.value);
      default:
        return DateFormat('MMMM yyyy').format(_focusedDay.value);
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    // Mock data - replace with actual data from controller
    return day.day % 3 == 0 ? ['Mock Event'] : [];
  }

  bool _hasActiveFilters() {
    return _selectedInstructorFilter != null ||
        _selectedStudentFilter != null ||
        _selectedStatusFilter != null;
  }

  int _getFilteredCount() => 15; // Mock count
  int _getTotalCount() => 25; // Mock count

  // Event handlers
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay.value = selectedDay;
      _focusedDay.value = focusedDay;
    });
  }

  void _previousPeriod() {
    switch (_currentView) {
      case 'week':
        _focusedDay.value = _focusedDay.value.subtract(Duration(days: 7));
        break;
      case 'day':
        _focusedDay.value = _focusedDay.value.subtract(Duration(days: 1));
        break;
      default:
        _focusedDay.value =
            DateTime(_focusedDay.value.year, _focusedDay.value.month - 1);
    }
  }

  void _nextPeriod() {
    switch (_currentView) {
      case 'week':
        _focusedDay.value = _focusedDay.value.add(Duration(days: 7));
        break;
      case 'day':
        _focusedDay.value = _focusedDay.value.add(Duration(days: 1));
        break;
      default:
        _focusedDay.value =
            DateTime(_focusedDay.value.year, _focusedDay.value.month + 1);
    }
  }

  void _refreshData() {
    // Implement refresh logic
    Get.snackbar('Info', 'Refreshing schedule data...');
  }

  void _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _focusedDay.value,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2030),
    );
    if (date != null) {
      _focusedDay.value = date;
    }
  }

  void _showSearchDialog() {
    // Implement search dialog
    Get.dialog(
      AlertDialog(
        title: Text('Search Schedule'),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Search by student, instructor, or course...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('Cancel')),
          ElevatedButton(onPressed: () => Get.back(), child: Text('Search')),
        ],
      ),
    );
  }

  void _showFilterOptions(String filterType, Function(String?) onChanged) {
    // Implement filter options dialog
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select $filterType',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 16),
            // Add filter options here
            ListTile(
              title: Text('Option 1'),
              onTap: () {
                onChanged('Option 1');
                Get.back();
              },
            ),
            ListTile(
              title: Text('Option 2'),
              onTap: () {
                onChanged('Option 2');
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedInstructorFilter = null;
      _selectedStudentFilter = null;
      _selectedStatusFilter = null;
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        Get.snackbar('Export', 'Exporting schedule...');
        break;
      case 'settings':
        Get.snackbar('Settings', 'Opening settings...');
        break;
      case 'bulk_actions':
        _showBulkActionsDialog();
        break;
    }
  }

  void _showBulkActionsDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Bulk Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Duplicate Selected'),
              onTap: () => Get.back(),
            ),
            ListTile(
              leading: Icon(Icons.cancel),
              title: Text('Cancel Selected'),
              onTap: () => Get.back(),
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Send Reminders'),
              onTap: () => Get.back(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('Cancel')),
        ],
      ),
    );
  }

  void _showCreateOptions() {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.add_circle, color: Colors.blue),
              title: Text('Single Lesson'),
              subtitle: Text('Create a single lesson'),
              onTap: () {
                Get.back();
                _createSingleLesson();
              },
            ),
            ListTile(
              leading: Icon(Icons.repeat, color: Colors.green),
              title: Text('Recurring Lessons'),
              subtitle: Text('Create a series of lessons'),
              onTap: () {
                Get.back();
                _createRecurringLessons();
              },
            ),
            ListTile(
              leading: Icon(Icons.import_export, color: Colors.orange),
              title: Text('Import from CSV'),
              subtitle: Text('Bulk import lessons'),
              onTap: () {
                Get.back();
                _importFromCSV();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openDayView(DateTime date) {
    // Navigate to detailed day view
    Get.snackbar(
        'Navigation', 'Opening day view for ${DateFormat.yMd().format(date)}');
  }

  void _openScheduleDetails(int index) {
    Get.snackbar('Details', 'Opening schedule details');
  }

  void _editSchedule(int index) {
    Get.snackbar('Edit', 'Opening edit dialog');
  }

  void _cancelSchedule(int index) {
    Get.dialog(
      AlertDialog(
        title: Text('Cancel Lesson'),
        content: Text('Are you sure you want to cancel this lesson?'),
        actions: [
          TextButton(onPressed: Get.back, child: Text('No')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.snackbar('Cancelled', 'Lesson has been cancelled');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _createSingleLesson() {
    // Open single lesson creation dialog
    Get.snackbar('Create', 'Opening single lesson form');
  }

  void _createRecurringLessons() {
    // Open recurring lessons dialog
    Get.snackbar('Create', 'Opening recurring lessons form');
  }

  void _importFromCSV() {
    // Open CSV import dialog
    Get.snackbar('Import', 'Opening CSV import dialog');
  }
}
