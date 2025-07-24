// lib/screens/users/enhanced_recommendations_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/fleet_controller.dart';
import '../../controllers/billing_controller.dart';
import '../../controllers/schedule_controller.dart';
import 'add_user_screen.dart';

class EnhancedRecommendationsScreen extends StatefulWidget {
  final String role;

  const EnhancedRecommendationsScreen({Key? key, required this.role})
      : super(key: key);

  @override
  _EnhancedRecommendationsScreenState createState() =>
      _EnhancedRecommendationsScreenState();
}

class _EnhancedRecommendationsScreenState
    extends State<EnhancedRecommendationsScreen> {
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final FleetController fleetController = Get.find<FleetController>();
  final BillingController billingController = Get.find<BillingController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();

  List<Map<String, dynamic>> _smartRecommendations = [];
  List<Map<String, dynamic>> _quickActions = [];
  List<Map<String, dynamic>> _insights = [];

  @override
  void initState() {
    super.initState();
    _generateRecommendations();
  }

  void _generateRecommendations() {
    _generateSmartRecommendations();
    _generateQuickActions();
    _generateInsights();
  }

  void _generateSmartRecommendations() {
    _smartRecommendations.clear();

    final users =
        userController.users.where((u) => u.role == widget.role).toList();
    final activeUsers = users.where((u) => u.status == 'Active').length;
    final inactiveUsers = users.length - activeUsers;

    // Smart recommendations based on data analysis
    if (users.isEmpty) {
      _smartRecommendations.add({
        'type': 'urgent',
        'title': 'No ${widget.role}s in system',
        'description':
            'Start by adding your first ${widget.role} to begin operations',
        'action': 'Add ${widget.role.capitalize}',
        'icon': Icons.person_add,
        'color': Colors.red,
        'priority': 'high',
        'onTap': () => Get.to(() => AddUserScreen(role: widget.role)),
      });
    } else {
      // Data-driven recommendations
      if (inactiveUsers > 0) {
        _smartRecommendations.add({
          'type': 'warning',
          'title': 'Inactive ${widget.role}s detected',
          'description':
              '$inactiveUsers ${widget.role}s are inactive. Review and reactivate or remove them.',
          'action': 'Review Inactive ${widget.role.capitalize}s',
          'icon': Icons.person_off,
          'color': Colors.orange,
          'priority': 'medium',
          'onTap': () => _showInactiveUsers(),
        });
      }

      if (widget.role == 'student') {
        _generateStudentRecommendations(users);
      } else if (widget.role == 'instructor') {
        _generateInstructorRecommendations(users);
      }

      // General recommendations
      if (users.length < 5) {
        _smartRecommendations.add({
          'type': 'suggestion',
          'title': 'Grow your ${widget.role} base',
          'description':
              'You have ${users.length} ${widget.role}s. Consider marketing to attract more.',
          'action': 'Marketing Tips',
          'icon': Icons.trending_up,
          'color': Colors.blue,
          'priority': 'low',
          'onTap': () => _showMarketingTips(),
        });
      }
    }

    // Performance recommendations
    final recentUsers = users
        .where((u) => DateTime.now().difference(u.created_at).inDays <= 30)
        .length;

    if (recentUsers > 0) {
      _smartRecommendations.add({
        'type': 'success',
        'title': 'Great growth this month!',
        'description':
            '$recentUsers new ${widget.role}s joined this month. Keep up the momentum!',
        'action': 'View Growth Analytics',
        'icon': Icons.celebration,
        'color': Colors.green,
        'priority': 'info',
        'onTap': () => _showGrowthAnalytics(),
      });
    }
  }

  void _generateStudentRecommendations(List users) {
    // Student-specific recommendations
    final studentsWithoutInvoices = users
        .where((student) => !billingController.invoices
            .any((invoice) => invoice.studentId == student.id))
        .length;

    if (studentsWithoutInvoices > 0) {
      _smartRecommendations.add({
        'type': 'urgent',
        'title': 'Students without invoices',
        'description':
            '$studentsWithoutInvoices students don\'t have invoices. Create invoices to track payments.',
        'action': 'Create Missing Invoices',
        'icon': Icons.receipt_long,
        'color': Colors.red,
        'priority': 'high',
        'onTap': () => _createMissingInvoices(),
      });
    }

    final studentsWithoutSchedules = users
        .where((student) => !scheduleController.schedules
            .any((schedule) => schedule.studentId == student.id))
        .length;

    if (studentsWithoutSchedules > 0) {
      _smartRecommendations.add({
        'type': 'warning',
        'title': 'Students need scheduling',
        'description':
            '$studentsWithoutSchedules students haven\'t been scheduled for lessons.',
        'action': 'Schedule Lessons',
        'icon': Icons.schedule,
        'color': Colors.orange,
        'priority': 'medium',
        'onTap': () => _scheduleStudentLessons(),
      });
    }
  }

  void _generateInstructorRecommendations(List users) {
    // Instructor-specific recommendations
    final instructorsWithoutVehicles = users
        .where((instructor) => !fleetController.fleet
            .any((vehicle) => vehicle.instructor == instructor.id))
        .length;

    if (instructorsWithoutVehicles > 0) {
      _smartRecommendations.add({
        'type': 'warning',
        'title': 'Instructors need vehicles',
        'description':
            '$instructorsWithoutVehicles instructors don\'t have assigned vehicles.',
        'action': 'Assign Vehicles',
        'icon': Icons.directions_car,
        'color': Colors.orange,
        'priority': 'medium',
        'onTap': () => _assignVehiclesToInstructors(),
      });
    }

    // Check instructor workload
    final instructorWorkload = users.map((instructor) {
      final scheduleCount = scheduleController.schedules
          .where((s) =>
              s.instructorId == instructor.id &&
              s.start.isAfter(DateTime.now()) &&
              s.start.isBefore(DateTime.now().add(Duration(days: 7))))
          .length;
      return {'instructor': instructor, 'schedules': scheduleCount};
    }).toList();

    final overloadedInstructors =
        instructorWorkload.where((item) => item['schedules'] > 20).length;
    final underutilizedInstructors =
        instructorWorkload.where((item) => item['schedules'] < 5).length;

    if (overloadedInstructors > 0) {
      _smartRecommendations.add({
        'type': 'urgent',
        'title': 'Instructor overload detected',
        'description':
            '$overloadedInstructors instructors have heavy schedules this week.',
        'action': 'Balance Workload',
        'icon': Icons.warning,
        'color': Colors.red,
        'priority': 'high',
        'onTap': () => _balanceInstructorWorkload(),
      });
    }

    if (underutilizedInstructors > 0) {
      _smartRecommendations.add({
        'type': 'suggestion',
        'title': 'Optimize instructor usage',
        'description':
            '$underutilizedInstructors instructors have light schedules. Consider reassigning lessons.',
        'action': 'Optimize Schedules',
        'icon': Icons.schedule,
        'color': Colors.blue,
        'priority': 'low',
        'onTap': () => _optimizeInstructorSchedules(),
      });
    }
  }

  void _generateQuickActions() {
    _quickActions = [
      {
        'title': 'Add New ${widget.role.capitalize}',
        'description': 'Register a new ${widget.role} in the system',
        'icon': Icons.person_add,
        'color': Colors.blue,
        'onTap': () => Get.to(() => AddUserScreen(role: widget.role)),
      },
      {
        'title': 'Import from CSV',
        'description': 'Bulk import ${widget.role}s from a CSV file',
        'icon': Icons.upload_file,
        'color': Colors.green,
        'onTap': () => _showImportDialog(),
      },
      {
        'title': 'Export ${widget.role.capitalize} List',
        'description': 'Download ${widget.role} data as CSV',
        'icon': Icons.download,
        'color': Colors.purple,
        'onTap': () => _exportUserList(),
      },
      {
        'title': 'Send Notifications',
        'description': 'Send bulk messages to ${widget.role}s',
        'icon': Icons.notifications,
        'color': Colors.orange,
        'onTap': () => _sendBulkNotifications(),
      },
      if (widget.role == 'student') ...[
        {
          'title': 'Quick Enrollment',
          'description': 'Enroll students in courses quickly',
          'icon': Icons.school,
          'color': Colors.teal,
          'onTap': () => _quickEnrollment(),
        },
        {
          'title': 'Payment Reminders',
          'description': 'Send payment reminders to students',
          'icon': Icons.payment,
          'color': Colors.red,
          'onTap': () => _sendPaymentReminders(),
        },
      ],
      if (widget.role == 'instructor') ...[
        {
          'title': 'Schedule Optimization',
          'description': 'Optimize instructor schedules',
          'icon': Icons.auto_awesome,
          'color': Colors.indigo,
          'onTap': () => _optimizeSchedules(),
        },
        {
          'title': 'Performance Review',
          'description': 'Review instructor performance',
          'icon': Icons.analytics,
          'color': Colors.cyan,
          'onTap': () => _performanceReview(),
        },
      ],
    ];
  }

  void _generateInsights() {
    final users =
        userController.users.where((u) => u.role == widget.role).toList();

    _insights = [
      {
        'title': 'Total ${widget.role.capitalize}s',
        'value': '${users.length}',
        'icon': Icons.people,
        'color': Colors.blue,
        'trend': _calculateGrowthTrend(users),
      },
      {
        'title': 'Active ${widget.role.capitalize}s',
        'value': '${users.where((u) => u.status == 'Active').length}',
        'icon': Icons.check_circle,
        'color': Colors.green,
        'trend': null,
      },
      {
        'title': 'This Month',
        'value':
            '${users.where((u) => DateTime.now().difference(u.created_at).inDays <= 30).length}',
        'icon': Icons.calendar_month,
        'color': Colors.orange,
        'trend': null,
      },
      if (widget.role == 'student') ...[
        {
          'title': 'With Active Invoices',
          'value':
              '${users.where((u) => billingController.invoices.any((i) => i.studentId == u.id && i.balance > 0)).length}',
          'icon': Icons.receipt,
          'color': Colors.red,
          'trend': null,
        },
        {
          'title': 'Scheduled This Week',
          'value': '${_getStudentsScheduledThisWeek()}',
          'icon': Icons.schedule,
          'color': Colors.purple,
          'trend': null,
        },
      ],
      if (widget.role == 'instructor') ...[
        {
          'title': 'With Vehicles',
          'value':
              '${users.where((u) => fleetController.fleet.any((v) => v.instructor == u.id)).length}',
          'icon': Icons.directions_car,
          'color': Colors.teal,
          'trend': null,
        },
        {
          'title': 'Active This Week',
          'value': '${_getActiveInstructorsThisWeek()}',
          'icon': Icons.work,
          'color': Colors.indigo,
          'trend': null,
        },
      ],
    ];
  }

  String? _calculateGrowthTrend(List users) {
    final thisMonth = users
        .where((u) => DateTime.now().difference(u.created_at).inDays <= 30)
        .length;

    final lastMonth = users.where((u) {
      final daysDiff = DateTime.now().difference(u.created_at).inDays;
      return daysDiff > 30 && daysDiff <= 60;
    }).length;

    if (lastMonth == 0) return null;

    final growth = ((thisMonth - lastMonth) / lastMonth * 100).round();
    return growth > 0 ? '+$growth%' : '$growth%';
  }

  int _getStudentsScheduledThisWeek() {
    final weekStart =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final weekEnd = weekStart.add(Duration(days: 7));

    return scheduleController.schedules
        .where((s) => s.start.isAfter(weekStart) && s.start.isBefore(weekEnd))
        .map((s) => s.studentId)
        .toSet()
        .length;
  }

  int _getActiveInstructorsThisWeek() {
    final weekStart =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final weekEnd = weekStart.add(Duration(days: 7));

    return scheduleController.schedules
        .where((s) => s.start.isAfter(weekStart) && s.start.isBefore(weekEnd))
        .map((s) => s.instructorId)
        .toSet()
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInsightsSection(),
            SizedBox(height: 24),
            _buildSmartRecommendationsSection(),
            SizedBox(height: 24),
            _buildQuickActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.role.capitalize} Insights',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _insights.length,
          itemBuilder: (context, index) {
            final insight = _insights[index];
            return _buildInsightCard(insight);
          },
        ),
      ],
    );
  }

  Widget _buildInsightCard(Map<String, dynamic> insight) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              insight['icon'],
              size: 24,
              color: insight['color'],
            ),
            SizedBox(height: 8),
            Text(
              insight['value'],
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: insight['color'],
              ),
            ),
            SizedBox(height: 4),
            Text(
              insight['title'],
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (insight['trend'] != null) ...[
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: insight['trend'].startsWith('+')
                      ? Colors.green[100]
                      : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  insight['trend'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: insight['trend'].startsWith('+')
                        ? Colors.green[800]
                        : Colors.red[800],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSmartRecommendationsSection() {
    if (_smartRecommendations.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Recommendations',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _smartRecommendations.length,
          itemBuilder: (context, index) {
            final recommendation = _smartRecommendations[index];
            return _buildRecommendationCard(recommendation);
          },
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    Color borderColor;
    Color backgroundColor;

    switch (recommendation['type']) {
      case 'urgent':
        borderColor = Colors.red;
        backgroundColor = Colors.red[50]!;
        break;
      case 'warning':
        borderColor = Colors.orange;
        backgroundColor = Colors.orange[50]!;
        break;
      case 'suggestion':
        borderColor = Colors.blue;
        backgroundColor = Colors.blue[50]!;
        break;
      case 'success':
        borderColor = Colors.green;
        backgroundColor = Colors.green[50]!;
        break;
      default:
        borderColor = Colors.grey;
        backgroundColor = Colors.grey[50]!;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.all(16),
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: recommendation['color'].withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              recommendation['icon'],
              color: recommendation['color'],
              size: 24,
            ),
          ),
          title: Text(
            recommendation['title'],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(recommendation['description']),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: recommendation['onTap'],
                style: ElevatedButton.styleFrom(
                  backgroundColor: recommendation['color'],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(recommendation['action']),
              ),
            ],
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: recommendation['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              recommendation['priority'].toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: recommendation['color'],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _quickActions.length,
          itemBuilder: (context, index) {
            final action = _quickActions[index];
            return _buildQuickActionCard(action);
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: action['onTap'],
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: action['color'].withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  action['icon'],
                  size: 28,
                  color: action['color'],
                ),
              ),
              SizedBox(height: 12),
              Text(
                action['title'],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                action['description'],
                style: TextStyle(
                  fontSize: 11,
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

  // Action methods
  void _showInactiveUsers() {
    Get.snackbar(
        'Info', 'Showing inactive ${widget.role}s feature coming soon!');
  }

  void _showMarketingTips() {
    Get.dialog(
      AlertDialog(
        title: Text('Marketing Tips for ${widget.role.capitalize}s'),
        content: Text('Marketing strategies and tips will be available here.'),
        actions: [
          TextButton(onPressed: Get.back, child: Text('Close')),
        ],
      ),
    );
  }

  void _showGrowthAnalytics() {
    Get.snackbar('Analytics', 'Growth analytics feature coming soon!');
  }

  void _createMissingInvoices() {
    Get.snackbar('Invoices', 'Bulk invoice creation feature coming soon!');
  }

  void _scheduleStudentLessons() {
    Get.snackbar('Scheduling', 'Bulk lesson scheduling feature coming soon!');
  }

  void _assignVehiclesToInstructors() {
    Get.snackbar('Vehicles', 'Vehicle assignment feature coming soon!');
  }

  void _balanceInstructorWorkload() {
    Get.snackbar('Workload', 'Workload balancing feature coming soon!');
  }

  void _optimizeInstructorSchedules() {
    Get.snackbar('Optimization', 'Schedule optimization feature coming soon!');
  }

  void _showImportDialog() {
    Get.snackbar('Import', 'CSV import feature coming soon!');
  }

  void _exportUserList() {
    Get.snackbar('Export', 'CSV export feature coming soon!');
  }

  void _sendBulkNotifications() {
    Get.snackbar('Notifications', 'Bulk notifications feature coming soon!');
  }

  void _quickEnrollment() {
    Get.snackbar('Enrollment', 'Quick enrollment feature coming soon!');
  }

  void _sendPaymentReminders() {
    Get.snackbar('Reminders', 'Payment reminders feature coming soon!');
  }

  void _optimizeSchedules() {
    Get.snackbar('Schedules', 'Schedule optimization feature coming soon!');
  }

  void _performanceReview() {
    Get.snackbar('Performance', 'Performance review feature coming soon!');
  }
}
