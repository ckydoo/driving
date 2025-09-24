import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/screens/users/instructor_details_screen.dart';
import 'package:flutter/material.dart';
import '../../models/fleet.dart';
import 'package:get/get.dart';
import '../../controllers/user_controller.dart';
import '../../widgets/fleet_form_dialog.dart';
import 'package:intl/intl.dart';
import '../../widgets/responsive_text.dart';

class FleetDetailsScreen extends StatefulWidget {
  final int fleetId;

  const FleetDetailsScreen({Key? key, required this.fleetId}) : super(key: key);

  @override
  _FleetDetailsScreenState createState() => _FleetDetailsScreenState();
}

class _FleetDetailsScreenState extends State<FleetDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FleetController fleetController = Get.find<FleetController>();
  final UserController userController = Get.find<UserController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getInstructorName(int instructorId) {
    if (instructorId == 0) return 'Unassigned';

    if (userController.isLoading.value) {
      return 'Loading...';
    }

    final instructor = userController.users.firstWhere(
      (user) =>
          user.id == instructorId && user.role.toLowerCase() == 'instructor',
      orElse: () => User(
        id: -1,
        fname: 'Unknown',
        lname: 'Instructor',
        email: '',
        date_of_birth: DateTime.now(),
        password: '',
        role: '',
        status: '',
        created_at: DateTime.now(),
        gender: '',
        phone: '',
        address: '',
        idnumber: '',
      ),
    );
    return instructor.id == -1
        ? 'Unknown Instructor'
        : '${instructor.fname} ${instructor.lname}';
  }

  String _getStudentName(int studentId) {
    if (studentId == 0) return 'Unknown Student';

    if (userController.isLoading.value) {
      return 'Loading...';
    }

    final student = userController.users.firstWhere(
      (user) => user.id == studentId && user.role.toLowerCase() == 'student',
      orElse: () => User(
        id: -1,
        fname: 'Unknown',
        lname: 'Student',
        email: '',
        date_of_birth: DateTime.now(),
        password: '',
        role: '',
        status: '',
        created_at: DateTime.now(),
        gender: '',
        phone: '',
        address: '',
        idnumber: '',
      ),
    );
    return student.id == -1
        ? 'Unknown Student'
        : '${student.fname} ${student.lname}';
  }

  User? _getInstructor(int instructorId) {
    if (instructorId == 0) return null;

    try {
      return userController.users.firstWhere(
        (user) =>
            user.id == instructorId && user.role.toLowerCase() == 'instructor',
      );
    } catch (e) {
      return null;
    }
  }

  int _getVehicleAge(String modelYear) {
    return DateTime.now().year - int.parse(modelYear);
  }

  Color _getStatusColor(Fleet fleet) {
    if (fleet.instructor == 0) return Colors.orange;
    final age = _getVehicleAge(fleet.modelYear);
    if (age > 10) return Colors.red;
    if (age > 5) return Colors.amber;
    return Colors.green;
  }

  String _getStatusResponsiveText(Fleet fleet) {
    if (fleet.instructor == 0) return 'Available';
    final age = _getVehicleAge(fleet.modelYear);
    if (age > 10) return 'Assigned (Old)';
    if (age > 5) return 'Assigned (Aging)';
    return 'Assigned';
  }

  List<Schedule> _getTodaysSchedules(Fleet fleet) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return scheduleController.schedules.where((schedule) {
      // Check if schedule is for this vehicle (carId matches fleet id)
      final isForThisVehicle = schedule.carId == fleet.id;
      // Check if schedule is today
      final isToday = schedule.start.isAfter(startOfDay) &&
          schedule.start.isBefore(endOfDay);

      return isForThisVehicle && isToday;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  List<Schedule> _getVehicleHistory(Fleet fleet) {
    return scheduleController.schedules.where((schedule) {
      return schedule.carId == fleet.id;
    }).toList()
      ..sort((a, b) => b.start.compareTo(a.start)); // Most recent first
  }

  Map<String, dynamic> _getVehicleStatistics(Fleet fleet) {
    final allSchedules = _getVehicleHistory(fleet);
    final completedLessons = allSchedules.where((s) => s.attended).length;
    final totalScheduled = allSchedules.length;
    final currentMonth = DateTime.now();
    final thisMonthSchedules = allSchedules
        .where((s) =>
            s.start.year == currentMonth.year &&
            s.start.month == currentMonth.month)
        .length;

    // Calculate total hours driven
    final totalMinutes = allSchedules
        .where((s) => s.attended)
        .fold(0, (sum, s) => sum + s.end.difference(s.start).inMinutes);
    final totalHours = totalMinutes / 60;

    // Get unique students
    final uniqueStudents = allSchedules.map((s) => s.studentId).toSet().length;

    // Calculate monthly average
    final monthsInService = DateTime.now()
            .difference(DateTime.parse(fleet.modelYear + '-01-01'))
            .inDays /
        30.44; // Average days per month

    final monthlyAverage =
        monthsInService > 0 ? completedLessons / monthsInService : 0;

    return {
      'totalLessons': completedLessons,
      'totalScheduled': totalScheduled,
      'thisMonth': thisMonthSchedules,
      'totalHours': totalHours,
      'uniqueStudents': uniqueStudents,
      'monthlyAverage': monthlyAverage,
      'utilizationRate':
          totalScheduled > 0 ? (completedLessons / totalScheduled) * 100 : 0,
    };
  }

  List<Map<String, dynamic>> _getMaintenanceRecommendations(Fleet fleet) {
    final vehicleAge = _getVehicleAge(fleet.modelYear);
    final stats = _getVehicleStatistics(fleet);
    final recommendations = <Map<String, dynamic>>[];

    // Age-based recommendations
    if (vehicleAge > 10) {
      recommendations.add({
        'type': 'urgent',
        'title': 'Consider Replacement',
        'description':
            'Vehicle is ${vehicleAge} years old and may need frequent repairs.',
        'icon': Icons.warning,
        'color': Colors.red,
        'priority': 'High',
      });
    } else if (vehicleAge > 7) {
      recommendations.add({
        'type': 'warning',
        'title': 'Increased Maintenance',
        'description':
            'Vehicle aging requires more frequent service intervals.',
        'icon': Icons.build,
        'color': Colors.orange,
        'priority': 'Medium',
      });
    }

    // Usage-based recommendations
    if (stats['totalHours'] > 500) {
      recommendations.add({
        'type': 'info',
        'title': 'High Usage Vehicle',
        'description':
            'This vehicle has been used extensively (${stats['totalHours'].toStringAsFixed(1)} hours total).',
        'icon': Icons.schedule,
        'color': Colors.blue,
        'priority': 'Medium',
      });
    }

    // Utilization recommendations
    if (stats['utilizationRate'] < 70) {
      recommendations.add({
        'type': 'suggestion',
        'title': 'Low Utilization',
        'description':
            'Vehicle utilization is ${stats['utilizationRate'].toStringAsFixed(1)}%. Consider reassignment.',
        'icon': Icons.trending_down,
        'color': Colors.grey,
        'priority': 'Low',
      });
    }

    // Default maintenance reminders
    recommendations.add({
      'type': 'maintenance',
      'title': 'Regular Service Due',
      'description':
          'Schedule regular maintenance check based on usage and age.',
      'icon': Icons.car_repair,
      'color': Colors.green,
      'priority': 'Low',
    });

    return recommendations;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (userController.isLoading.value) {
        return Scaffold(
          appBar: AppBar(
            title: const ResponsiveText(
              'Vehicle Details',
              style: TextStyle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.blue.shade800,
          ),
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final fleet = fleetController.fleet.firstWhere(
        (vehicle) => vehicle.id == widget.fleetId,
        orElse: () => Fleet(
          id: -1,
          carPlate: '',
          make: '',
          model: '',
          modelYear: '',
          instructor: 0,
          status: 'available',
        ),
      );

      if (fleet.id == -1) {
        return Scaffold(
          appBar: AppBar(
            title: const ResponsiveText(
              'Vehicle Not Found',
              style: TextStyle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.blue.shade800,
          ),
          body: const Center(
            child: ResponsiveText(
              'Vehicle not found',
              style: TextStyle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }

      final instructor = _getInstructor(fleet.instructor);
      final vehicleAge = _getVehicleAge(fleet.modelYear);
      final statusColor = _getStatusColor(fleet);
      final statusText = _getStatusResponsiveText(fleet);

      return Scaffold(
        appBar: AppBar(
          title: ResponsiveText(
            '${fleet.make} ${fleet.model}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.blue.shade800,
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    Get.dialog(FleetFormDialog(vehicle: fleet));
                    break;
                  case 'delete':
                    _showDeleteConfirmationDialog(fleet);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      ResponsiveText(
                        'Edit Vehicle',
                        style: TextStyle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      ResponsiveText('Delete Vehicle',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            isScrollable: MediaQuery.of(context).size.width < 400,
            tabs: const [
              Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
              Tab(text: 'Schedule', icon: Icon(Icons.schedule)),
              Tab(text: 'History', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(
                fleet, instructor, vehicleAge, statusColor, statusText),
            _buildScheduleTab(fleet),
            _buildHistoryTab(fleet),
          ],
        ),
      );
    });
  }

  Widget _buildOverviewTab(Fleet fleet, User? instructor, int vehicleAge,
      Color statusColor, String statusText) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(constraints.maxWidth > 600 ? 16.0 : 12.0),
          child: Column(
            children: [
              // Vehicle Header Card - Responsive
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: EdgeInsets.all(constraints.maxWidth > 600 ? 24 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade600,
                        Colors.blue.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: LayoutBuilder(
                    builder: (context, cardConstraints) {
                      if (cardConstraints.maxWidth > 400) {
                        return Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ResponsiveText(
                                    '${fleet.make} ${fleet.model}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  ResponsiveText(
                                    fleet.carPlate,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: ResponsiveText(
                                      statusText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ResponsiveText(
                              '${fleet.make} ${fleet.model}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            ResponsiveText(
                              fleet.carPlate,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ResponsiveText(
                                statusText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Vehicle Details
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(constraints.maxWidth > 600 ? 20 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ResponsiveText(
                        'Vehicle Information',
                        style: TextStyle(
                          fontSize: constraints.maxWidth > 600 ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(Icons.confirmation_number,
                          'License Plate', fleet.carPlate),
                      _buildDetailRow(
                          Icons.calendar_today, 'Model Year', fleet.modelYear),
                      _buildDetailRow(Icons.access_time, 'Vehicle Age',
                          '$vehicleAge years'),
                      _buildDetailRow(Icons.build, 'Make', fleet.make),
                      _buildDetailRow(Icons.car_rental, 'Model', fleet.model),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Instructor Information
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(constraints.maxWidth > 600 ? 20 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ResponsiveText(
                        'Assignment Information',
                        style: TextStyle(
                          fontSize: constraints.maxWidth > 600 ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (instructor != null) ...[
                        _buildDetailRow(
                          Icons.person,
                          'Assigned Instructor',
                          '${instructor.fname} ${instructor.lname}',
                        ),
                        _buildDetailRow(Icons.email, 'Email', instructor.email),
                        _buildDetailRow(
                          Icons.phone,
                          'Phone',
                          instructor.phone.isNotEmpty
                              ? instructor.phone
                              : 'Not provided',
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.orange.shade600,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              ResponsiveText(
                                'Vehicle Not Assigned',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ResponsiveText(
                                'This vehicle is currently available for assignment',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Get.dialog(FleetFormDialog(vehicle: fleet));
                                },
                                icon: const Icon(Icons.assignment_ind),
                                label: const ResponsiveText(
                                  'Assign Instructor',
                                  style: TextStyle(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
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

              const SizedBox(height: 16),

              // Vehicle Condition & Recommendations
              if (vehicleAge > 5)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding:
                        EdgeInsets.all(constraints.maxWidth > 600 ? 20 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResponsiveText(
                          'Recommendations',
                          style: TextStyle(
                            fontSize: constraints.maxWidth > 600 ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: vehicleAge > 10
                                ? Colors.red.shade50
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: vehicleAge > 10
                                  ? Colors.red.shade200
                                  : Colors.amber.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                vehicleAge > 10
                                    ? Icons.error_outline
                                    : Icons.warning_amber,
                                color: vehicleAge > 10
                                    ? Colors.red.shade600
                                    : Colors.amber.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ResponsiveText(
                                      vehicleAge > 10
                                          ? 'Consider Replacement'
                                          : 'Monitor Vehicle Age',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: vehicleAge > 10
                                            ? Colors.red.shade800
                                            : Colors.amber.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ResponsiveText(
                                      vehicleAge > 10
                                          ? 'This vehicle is over 10 years old and may require frequent maintenance.'
                                          : 'This vehicle is aging and should be monitored for maintenance needs.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: vehicleAge > 10
                                            ? Colors.red.shade700
                                            : Colors.amber.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleTab(Fleet fleet) {
    final todaysSchedules = _getTodaysSchedules(fleet);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: EdgeInsets.all(constraints.maxWidth > 600 ? 16.0 : 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ResponsiveText(
                      'Today\'s Schedule',
                      style: TextStyle(
                        fontSize: constraints.maxWidth > 600 ? 22 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ResponsiveText(
                      '${todaysSchedules.length} lesson${todaysSchedules.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (todaysSchedules.isEmpty)
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.free_breakfast,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          ResponsiveText(
                            'No lessons scheduled today',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ResponsiveText(
                            'This vehicle is available for booking',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: todaysSchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = todaysSchedules[index];
                      final studentName = _getStudentName(schedule.studentId);
                      final instructorName =
                          _getInstructorName(schedule.instructorId);
                      final isCompleted = schedule.attended;
                      final isPast = DateTime.now().isAfter(schedule.end);
                      final isCurrent =
                          DateTime.now().isAfter(schedule.start) &&
                              DateTime.now().isBefore(schedule.end);

                      Color statusColor;
                      String statusText;
                      IconData statusIcon;

                      if (isCompleted) {
                        statusColor = Colors.green;
                        statusText = 'Completed';
                        statusIcon = Icons.check_circle;
                      } else if (isCurrent) {
                        statusColor = Colors.blue;
                        statusText = 'In Progress';
                        statusIcon = Icons.play_circle;
                      } else if (isPast) {
                        statusColor = Colors.orange;
                        statusText = 'Missed';
                        statusIcon = Icons.warning;
                      } else {
                        statusColor = Colors.grey;
                        statusText = 'Scheduled';
                        statusIcon = Icons.schedule;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, cardConstraints) {
                                  if (cardConstraints.maxWidth > 400) {
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ResponsiveText(
                                                studentName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              ResponsiveText(
                                                'with $instructorName',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                statusIcon,
                                                size: 14,
                                                color: statusColor,
                                              ),
                                              const SizedBox(width: 4),
                                              ResponsiveText(
                                                statusText,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ResponsiveText(
                                          studentName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: ResponsiveText(
                                                'with $instructorName',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    statusIcon,
                                                    size: 14,
                                                    color: statusColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  ResponsiveText(
                                                    statusText,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 18,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      ResponsiveText(
                                        '${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.timer,
                                        size: 18,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      ResponsiveText(
                                        schedule.duration,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ResponsiveText(
                                          schedule.classType,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (schedule.status == 'Canceled') ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cancel,
                                        size: 16,
                                        color: Colors.red.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ResponsiveText(
                                          'This lesson has been canceled',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(Fleet fleet) {
    final vehicleHistory = _getVehicleHistory(fleet);
    final stats = _getVehicleStatistics(fleet);
    final recommendations = _getMaintenanceRecommendations(fleet);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(constraints.maxWidth > 600 ? 16.0 : 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Usage Statistics
              ResponsiveText(
                'Usage Statistics',
                style: TextStyle(
                  fontSize: constraints.maxWidth > 600 ? 22 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Stats Grid - Responsive with fixed height
              SizedBox(
                height: constraints.maxWidth > 600
                    ? 200
                    : 180, // Fixed height to prevent overflow
                child: LayoutBuilder(
                  builder: (context, gridConstraints) {
                    int crossAxisCount;
                    double childAspectRatio;
                    if (gridConstraints.maxWidth > 800) {
                      crossAxisCount = 4;
                      childAspectRatio = 1.1;
                    } else if (gridConstraints.maxWidth > 600) {
                      crossAxisCount = 2;
                      childAspectRatio = 1.3;
                    } else {
                      crossAxisCount = 2;
                      childAspectRatio = 1.0;
                    }

                    return GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _buildStatCard({
                          'title': 'Total Lessons',
                          'value': stats['totalLessons'].toString(),
                          'subtitle': 'Completed',
                          'icon': Icons.check_circle,
                          'color': Colors.green,
                        }),
                        _buildStatCard({
                          'title': 'This Month',
                          'value': stats['thisMonth'].toString(),
                          'subtitle': 'Scheduled',
                          'icon': Icons.calendar_month,
                          'color': Colors.blue,
                        }),
                        _buildStatCard({
                          'title': 'Driving Hours',
                          'value': stats['totalHours'].toStringAsFixed(1),
                          'subtitle': 'Total hours',
                          'icon': Icons.access_time,
                          'color': Colors.purple,
                        }),
                        _buildStatCard({
                          'title': 'Students Taught',
                          'value': stats['uniqueStudents'].toString(),
                          'subtitle': 'Different students',
                          'icon': Icons.people,
                          'color': Colors.orange,
                        }),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Utilization Rate
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize:
                        MainAxisSize.min, // Important: minimize column size
                    children: [
                      ResponsiveText(
                        'Vehicle Performance',
                        style: TextStyle(
                          fontSize: constraints.maxWidth > 600 ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: ResponsiveText(
                              'Utilization Rate',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.black54),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ResponsiveText(
                            '${stats['utilizationRate'].toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: stats['utilizationRate'] > 80
                                  ? Colors.green
                                  : stats['utilizationRate'] > 60
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: stats['utilizationRate'] / 100,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          stats['utilizationRate'] > 80
                              ? Colors.green
                              : stats['utilizationRate'] > 60
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: ResponsiveText(
                              'Monthly Average',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.black54),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ResponsiveText(
                            '${stats['monthlyAverage'].toStringAsFixed(1)} lessons',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Maintenance & Recommendations
              ResponsiveText(
                'Maintenance & Recommendations',
                style: TextStyle(
                  fontSize: constraints.maxWidth > 600 ? 22 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Recommendations list with constrained height
              Column(
                mainAxisSize: MainAxisSize.min,
                children: recommendations
                    .map((rec) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: rec['color'].withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      rec['icon'],
                                      size: 18,
                                      color: rec['color'],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: ResponsiveText(
                                                rec['title'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: rec['color']
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: ResponsiveText(
                                                rec['priority'],
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: rec['color'],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ResponsiveText(
                                          rec['description'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 24),

              // Recent Activity
              ResponsiveText(
                'Recent Activity',
                style: TextStyle(
                  fontSize: constraints.maxWidth > 600 ? 22 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              if (vehicleHistory.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        ResponsiveText(
                          'No lesson history found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ResponsiveText(
                          'This vehicle hasn\'t been used for any lessons yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: vehicleHistory.take(10).map((schedule) {
                    final studentName = _getStudentName(schedule.studentId);
                    final instructorName =
                        _getInstructorName(schedule.instructorId);
                    final isCompleted = schedule.attended;
                    final daysDiff =
                        DateTime.now().difference(schedule.start).inDays;

                    String timeAgo;
                    if (daysDiff == 0) {
                      timeAgo = 'Today';
                    } else if (daysDiff == 1) {
                      timeAgo = 'Yesterday';
                    } else if (daysDiff < 7) {
                      timeAgo = '$daysDiff days ago';
                    } else if (daysDiff < 30) {
                      timeAgo = '${(daysDiff / 7).floor()} weeks ago';
                    } else {
                      timeAgo =
                          DateFormat('MMM dd, yyyy').format(schedule.start);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                            builder: (context, cardConstraints) {
                              if (cardConstraints.maxWidth > 400) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isCompleted
                                            ? Colors.green.shade100
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isCompleted
                                            ? Icons.check_circle
                                            : schedule.status == 'Canceled'
                                                ? Icons.cancel
                                                : Icons.schedule,
                                        color: isCompleted
                                            ? Colors.green.shade600
                                            : schedule.status == 'Canceled'
                                                ? Colors.red.shade600
                                                : Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ResponsiveText(
                                            studentName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          ResponsiveText(
                                            'with $instructorName • ${schedule.classType}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ResponsiveText(
                                          timeAgo,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        ResponsiveText(
                                          schedule.duration,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? Colors.green.shade100
                                                : Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            isCompleted
                                                ? Icons.check_circle
                                                : schedule.status == 'Canceled'
                                                    ? Icons.cancel
                                                    : Icons.schedule,
                                            color: isCompleted
                                                ? Colors.green.shade600
                                                : schedule.status == 'Canceled'
                                                    ? Colors.red.shade600
                                                    : Colors.grey.shade600,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ResponsiveText(
                                            studentName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        ResponsiveText(
                                          timeAgo,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: ResponsiveText(
                                            'with $instructorName • ${schedule.classType}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        ResponsiveText(
                                          schedule.duration,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              if (vehicleHistory.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Get.snackbar(
                          snackPosition: SnackPosition.BOTTOM,
                          'Feature Coming Soon',
                          'Full history view will be available in the next update',
                          backgroundColor: Colors.blue,
                          colorText: Colors.white,
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: ResponsiveText(
                        'View All ${vehicleHistory.length} Records',
                        style: const TextStyle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                      ),
                    ),
                  ),
                ),

              // Add extra padding at the bottom for safety
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8), // Reduced padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Important: minimize size
          children: [
            Container(
              width: 28, // Slightly smaller
              height: 28,
              decoration: BoxDecoration(
                color: stat['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                stat['icon'],
                size: 16, // Smaller icon
                color: stat['color'],
              ),
            ),
            const SizedBox(height: 6), // Reduced spacing
            FittedBox(
              child: ResponsiveText(
                stat['value'],
                style: const TextStyle(
                  fontSize: 16, // Slightly smaller
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 2),
            ResponsiveText(
              stat['title'],
              style: const TextStyle(
                fontSize: 11, // Smaller
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
              maxLines: 2, // Allow 2 lines for title
              overflow: TextOverflow.ellipsis,
            ),
            if (stat['subtitle'] != null) ...[
              const SizedBox(height: 2),
              ResponsiveText(
                stat['subtitle'],
                style: TextStyle(
                  fontSize: 9, // Very small
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.blue.shade600,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: ResponsiveText(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ResponsiveText(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(Fleet fleet) {
    Get.defaultDialog(
      title: 'Confirm Delete',
      titleStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
      content: Column(
        children: [
          Icon(
            Icons.warning_amber,
            color: Colors.red.shade400,
            size: 48,
          ),
          const SizedBox(height: 16),
          ResponsiveText(
            'Are you sure you want to delete this vehicle?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ResponsiveText(
            '${fleet.make} ${fleet.model} (${fleet.carPlate})',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.red.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ResponsiveText(
                    'This action cannot be undone.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () {
          Get.find<FleetController>().deleteFleet(fleet.id!);
          Get.back(); // Close the dialog
          Get.back(); // Close the details screen
          Get.snackbar(
            snackPosition: SnackPosition.BOTTOM,
            'Success',
            'Vehicle deleted successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const ResponsiveText(
          'Delete',
          style: TextStyle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const ResponsiveText(
          'Cancel',
          style: TextStyle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
