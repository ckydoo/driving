import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/fleet.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/schedule/daily_schedule_screen.dart';
import 'package:driving/widgets/edit_schedule_form_dialog.dart';
import 'package:driving/widgets/schedule_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class EnhancedScheduleScreen extends StatefulWidget {
  @override
  _EnhancedScheduleScreenState createState() => _EnhancedScheduleScreenState();
}

class _EnhancedScheduleScreenState extends State<EnhancedScheduleScreen>
    with SingleTickerProviderStateMixin {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  final Rx<DateTime> _focusedDay = DateTime.now().obs;
  final Rx<DateTime?> _selectedDay = Rx<DateTime?>(null);
  final DateTime _firstDay = DateTime.utc(2020);
  final DateTime _lastDay = DateTime.utc(2030);

  late TabController _tabController;
  User? _selectedInstructorFilter;
  User? _selectedStudentFilter;
  String? _selectedStatusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  final List<String> _statusOptions = [
    'All',
    'Scheduled',
    'Canceled',
    'Completed',
  ];

  final scheduleController = Get.find<ScheduleController>();
  final userController = Get.find<UserController>();
  final fleetController = Get.find<FleetController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDay.value = DateTime.now();
    Get.put(UserController(), permanent: true);
    Get.put(FleetController(), permanent: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Enhanced Schedule Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Colors.white),
            onPressed: () {
              setState(() {
                _focusedDay.value = DateTime.now();
                _selectedDay.value = DateTime.now();
              });
            },
            tooltip: 'Go to Today',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              await userController.fetchUsers();
              await fleetController.fetchFleet();
              await scheduleController.fetchSchedules();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_month)),
            Tab(text: 'List View', icon: Icon(Icons.list)),
            Tab(text: 'Timeline', icon: Icon(Icons.timeline)),
          ],
        ),
      ),
      body: Obx(() {
        if (scheduleController.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        return TabBarView(
          controller: _tabController,
          children: [
            _buildCalendarView(),
            _buildListView(),
            _buildTimelineView(),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade800,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('New Schedule', style: TextStyle(color: Colors.white)),
        onPressed: () => Get.dialog(const ScheduleFormDialog()),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: Obx(() => Card(
                elevation: 4,
                margin: const EdgeInsets.all(16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildCalendarHeader(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TableCalendar(
                          firstDay: _firstDay,
                          lastDay: _lastDay,
                          focusedDay: _focusedDay.value,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay.value, day);
                          },
                          calendarFormat: _calendarFormat,
                          eventLoader: (day) => _getFilteredSchedules(day),
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            weekendTextStyle:
                                TextStyle(color: Colors.blue.shade800),
                            todayDecoration: BoxDecoration(
                              color: Colors.blue.shade200,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                            ),
                            markerDecoration: BoxDecoration(
                              color: Colors.orange.shade400,
                              shape: BoxShape.circle,
                            ),
                            markersMaxCount: 3,
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay.value = selectedDay;
                              _focusedDay.value = focusedDay;
                            });
                            _showDaySchedules(selectedDay);
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay.value = focusedDay;
                          },
                        ),
                      ),
                      _buildLegend(),
                    ],
                  ),
                ),
              )),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _focusedDay.value = DateTime(
                _focusedDay.value.year,
                _focusedDay.value.month - 1,
              );
            });
          },
        ),
        Text(
          DateFormat('MMMM yyyy').format(_focusedDay.value),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _focusedDay.value = DateTime(
                _focusedDay.value.year,
                _focusedDay.value.month + 1,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Today', Colors.blue.shade200),
          const SizedBox(width: 16),
          _buildLegendItem('Selected', Colors.blue.shade600),
          const SizedBox(width: 16),
          _buildLegendItem('Has Events', Colors.orange.shade400),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: Obx(() {
            final allSchedules = _getAllFilteredSchedules();
            if (allSchedules.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy,
                        size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No schedules found',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              );
            }

            // Group schedules by date
            Map<DateTime, List<Schedule>> groupedSchedules = {};
            for (var schedule in allSchedules) {
              final date = DateTime(
                schedule.start.year,
                schedule.start.month,
                schedule.start.day,
              );
              groupedSchedules.putIfAbsent(date, () => []).add(schedule);
            }

            // Sort dates
            final sortedDates = groupedSchedules.keys.toList()..sort();

            return ListView.builder(
              itemCount: sortedDates.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final daySchedules = groupedSchedules[date]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.blue.shade800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(date),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade800,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${daySchedules.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...daySchedules
                        .map((schedule) => _buildScheduleCard(schedule))
                        .toList(),
                  ],
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTimelineView() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: Obx(() {
            final todaySchedules = _getFilteredSchedules(DateTime.now());
            if (todaySchedules.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timeline, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No schedules for today',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              );
            }

            // Sort schedules by start time
            todaySchedules.sort((a, b) => a.start.compareTo(b.start));

            return ListView.builder(
              itemCount: todaySchedules.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final schedule = todaySchedules[index];
                final isFirst = index == 0;
                final isLast = index == todaySchedules.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    children: [
                      // Timeline
                      Column(
                        children: [
                          if (!isFirst)
                            Container(
                              width: 2,
                              height: 20,
                              color: Colors.grey.shade300,
                            ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _getScheduleStatusColor(schedule),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: Colors.grey.shade300,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Time
                      SizedBox(
                        width: 60,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(schedule.start),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm').format(schedule.end),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Schedule card
                      Expanded(
                        child: _buildScheduleCard(schedule, compact: true),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by student name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchText = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
          ),
          const SizedBox(height: 12),
          // Filter chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: 'Instructor',
                value: _selectedInstructorFilter?.fname ?? 'All',
                onDeleted: _selectedInstructorFilter != null
                    ? () {
                        setState(() {
                          _selectedInstructorFilter = null;
                        });
                      }
                    : null,
                onTap: () => _showInstructorPicker(),
              ),
              _buildFilterChip(
                label: 'Student',
                value: _selectedStudentFilter?.fname ?? 'All',
                onDeleted: _selectedStudentFilter != null
                    ? () {
                        setState(() {
                          _selectedStudentFilter = null;
                        });
                      }
                    : null,
                onTap: () => _showStudentPicker(),
              ),
              _buildFilterChip(
                label: 'Status',
                value: _selectedStatusFilter ?? 'All',
                onDeleted: _selectedStatusFilter != 'All'
                    ? () {
                        setState(() {
                          _selectedStatusFilter = 'All';
                        });
                      }
                    : null,
                onTap: () => _showStatusPicker(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    VoidCallback? onDeleted,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: $value'),
          if (onDeleted != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.close,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ],
        ],
      ),
      onPressed: onTap,
      backgroundColor:
          value != 'All' ? Colors.blue.shade100 : Colors.grey.shade200,
    );
  }

  Widget _buildScheduleCard(Schedule schedule, {bool compact = false}) {
    final student = userController.users.firstWhere(
      (u) => u.id == schedule.studentId,
      orElse: () => User(
        id: -1,
        fname: 'Unknown',
        lname: 'Student',
        email: '',
        password: '',
        gender: '',
        phone: '',
        address: '',
        date_of_birth: DateTime.now(),
        role: '',
        status: '',
        idnumber: '',
        created_at: DateTime.now(),
      ),
    );

    final instructor = userController.users.firstWhere(
      (u) => u.id == schedule.instructorId,
      orElse: () => User(
        id: -1,
        fname: 'Unknown',
        lname: 'Instructor',
        email: '',
        password: '',
        gender: '',
        phone: '',
        address: '',
        date_of_birth: DateTime.now(),
        role: '',
        status: '',
        idnumber: '',
        created_at: DateTime.now(),
      ),
    );

    final statusColor = _getScheduleStatusColor(schedule);
    final isOverdue = schedule.end.isBefore(DateTime.now()) &&
        !schedule.attended &&
        schedule.status != 'Canceled';

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 16,
        vertical: 8,
      ),
      elevation: compact ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isOverdue ? Colors.red.shade300 : Colors.transparent,
          width: isOverdue ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () => _showScheduleDetails(schedule),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${student.fname} ${student.lname}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 14 : 16,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    Chip(
                      label: Text(
                        schedule.status,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: statusColor.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ],
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Instructor: ${instructor.fname} ${instructor.lname}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      schedule.duration,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
              if (isOverdue) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Overdue - Not Attended',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getScheduleStatusColor(Schedule schedule) {
    if (schedule.status == 'Canceled') return Colors.grey;
    if (schedule.attended) return Colors.green;
    if (schedule.end.isBefore(DateTime.now())) return Colors.red;
    return Colors.blue;
  }

  List<Schedule> _getFilteredSchedules(DateTime day) {
    List<Schedule> schedules = scheduleController.getDailySchedules(day);
    return _applyFilters(schedules);
  }

  List<Schedule> _getAllFilteredSchedules() {
    List<Schedule> schedules = scheduleController.schedules.toList();
    return _applyFilters(schedules);
  }

  List<Schedule> _applyFilters(List<Schedule> schedules) {
    // Apply instructor filter
    if (_selectedInstructorFilter != null) {
      schedules = schedules
          .where((s) => s.instructorId == _selectedInstructorFilter!.id)
          .toList();
    }

    // Apply student filter
    if (_selectedStudentFilter != null) {
      schedules = schedules
          .where((s) => s.studentId == _selectedStudentFilter!.id)
          .toList();
    }

    // Apply status filter
    if (_selectedStatusFilter != null && _selectedStatusFilter != 'All') {
      if (_selectedStatusFilter == 'Completed') {
        schedules = schedules.where((s) => s.attended).toList();
      } else {
        schedules =
            schedules.where((s) => s.status == _selectedStatusFilter).toList();
      }
    }

    // Apply search filter
    if (_searchText.isNotEmpty) {
      schedules = schedules.where((s) {
        final student = userController.users.firstWhere(
          (user) => user.id == s.studentId,
          orElse: () => User(
            id: -1,
            fname: '',
            lname: '',
            email: '',
            password: '',
            gender: '',
            phone: '',
            address: '',
            date_of_birth: DateTime.now(),
            role: '',
            status: '',
            idnumber: '',
            created_at: DateTime.now(),
          ),
        );
        final fullName = '${student.fname} ${student.lname}'.toLowerCase();
        return fullName.contains(_searchText.toLowerCase());
      }).toList();
    }

    return schedules;
  }

  void _showInstructorPicker() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Instructor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('All Instructors'),
                    onTap: () {
                      setState(() {
                        _selectedInstructorFilter = null;
                      });
                      Get.back();
                    },
                  ),
                  ...userController.instructors
                      .map((instructor) => ListTile(
                            title:
                                Text('${instructor.fname} ${instructor.lname}'),
                            onTap: () {
                              setState(() {
                                _selectedInstructorFilter = instructor;
                              });
                              Get.back();
                            },
                          ))
                      .toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentPicker() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Student',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('All Students'),
                    onTap: () {
                      setState(() {
                        _selectedStudentFilter = null;
                      });
                      Get.back();
                    },
                  ),
                  ...userController.students
                      .map((student) => ListTile(
                            title: Text('${student.fname} ${student.lname}'),
                            onTap: () {
                              setState(() {
                                _selectedStudentFilter = student;
                              });
                              Get.back();
                            },
                          ))
                      .toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _statusOptions
                    .map((status) => ListTile(
                          title: Text(status),
                          onTap: () {
                            setState(() {
                              _selectedStatusFilter = status;
                            });
                            Get.back();
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDaySchedules(DateTime day) {
    final schedules = _getFilteredSchedules(day);
    if (schedules.isEmpty) {
      Get.to(() => DailyScheduleScreen(selectedDate: day));
    } else {
      Get.bottomSheet(
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d').format(day),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Get.back();
                        Get.to(() => DailyScheduleScreen(selectedDate: day));
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: schedules.length > 3 ? 3 : schedules.length,
                  itemBuilder: (context, index) {
                    return _buildScheduleCard(schedules[index], compact: true);
                  },
                ),
              ),
              if (schedules.length > 3)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '+ ${schedules.length - 3} more schedules',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  void _showScheduleDetails(Schedule schedule) {
    final student = userController.users.firstWhere(
      (u) => u.id == schedule.studentId,
      orElse: () => User(
        id: -1,
        fname: 'Unknown',
        lname: 'Student',
        email: '',
        password: '',
        gender: '',
        phone: '',
        address: '',
        date_of_birth: DateTime.now(),
        role: '',
        status: '',
        idnumber: '',
        created_at: DateTime.now(),
      ),
    );

    final instructor = userController.users.firstWhere(
      (u) => u.id == schedule.instructorId,
      orElse: () => User(
        id: -1,
        fname: 'Unknown',
        lname: 'Instructor',
        email: '',
        password: '',
        gender: '',
        phone: '',
        address: '',
        date_of_birth: DateTime.now(),
        role: '',
        status: '',
        idnumber: '',
        created_at: DateTime.now(),
      ),
    );

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Schedule Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow('Student', '${student.fname} ${student.lname}'),
              _buildDetailRow(
                  'Instructor', '${instructor.fname} ${instructor.lname}'),
              _buildDetailRow('Date',
                  DateFormat('EEEE, MMMM d, yyyy').format(schedule.start)),
              _buildDetailRow('Time',
                  '${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)}'),
              _buildDetailRow('Duration', schedule.duration),
              _buildDetailRow('Status', schedule.status),
              _buildDetailRow('Attended', schedule.attended ? 'Yes' : 'No'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (schedule.status != 'Canceled' &&
                      !schedule.end.isBefore(DateTime.now()))
                    TextButton(
                      onPressed: () {
                        Get.back();
                        Get.dialog(EditScheduleScreen(schedule: schedule));
                      },
                      child: const Text('Edit'),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
