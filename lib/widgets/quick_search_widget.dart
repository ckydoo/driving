import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/user_controller.dart';
import '../controllers/schedule_controller.dart';

class QuickSearchWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final scheduleController = Get.find<ScheduleController>();
    final navigationController = Get.find<NavigationController>();

    // Get today's schedules
    final today = DateTime.now();
    final todaySchedules = scheduleController.schedules
        .where((s) =>
            s.start.year == today.year &&
            s.start.month == today.month &&
            s.start.day == today.day)
        .length;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search access
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Search & Overview',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Search students & instructors instantly',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        navigationController.navigateToPage('quick_search');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade600,
                        elevation: 0,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Search',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Quick stats bar
                Row(
                  children: [
                    _buildQuickStat(
                      'Today\'s Lessons',
                      '$todaySchedules',
                      Icons.today,
                    ),
                    SizedBox(width: 20),
                    _buildQuickStat(
                      'Total Students',
                      '${userController.users.where((u) => u.role.toLowerCase() == 'student').length}',
                      Icons.school,
                    ),
                    SizedBox(width: 20),
                    _buildQuickStat(
                      'Instructors',
                      '${userController.users.where((u) => u.role.toLowerCase() == 'instructor').length}',
                      Icons.person,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Quick action buttons
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Find Student',
                  'Search by name or details',
                  Icons.school,
                  Colors.green,
                  () {
                    navigationController.navigateToPage('quick_search');
                    // TODO: Auto-select student filter when quick_search page supports it
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Find Instructor',
                  'Search teaching staff',
                  Icons.person,
                  Colors.orange,
                  () {
                    navigationController.navigateToPage('quick_search');
                    // TODO: Auto-select instructor filter when quick_search page supports it
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Schedule Lesson',
                  'Quick lesson booking',
                  Icons.schedule,
                  Colors.purple,
                  () {
                    navigationController.navigateToPage('schedules');
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'View Billing',
                  'Check payments',
                  Icons.receipt,
                  Colors.teal,
                  () {
                    navigationController.navigateToPage('billing');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 16),
        SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
