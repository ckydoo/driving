// lib/widgets/complete_main_layout.dart
import 'package:driving/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/navigation_controller.dart';
import '../reports/course.dart';
import '../screens/billing/billing_screen.dart';
import '../screens/course/course_screen.dart';
import '../screens/fleet/fleet_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/users/enhanced_users_screen.dart';

class CompleteMainLayout extends StatelessWidget {
  const CompleteMainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize navigation controller
    final NavigationController navController = Get.put(NavigationController());

    return Scaffold(
      body: Row(
        children: [
          // Fixed Left Sidebar
          Container(
            width: 250,
            color: Colors.blueGrey[900],
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'DRIVING SCHOOL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Obx(() {
                        final user = navController.currentUser.value;
                        return user != null
                            ? Column(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      user['name']![0].toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.blueGrey[900],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    user['name']!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    user['role']!,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            : SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
                Divider(color: Colors.white54),

                // Scrollable sidebar items
                Expanded(
                  child: SingleChildScrollView(
                    child: Obx(() => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSidebarItem(
                              Icons.dashboard,
                              'Dashboard',
                              'dashboard',
                              navController.currentPage.value,
                              () => navController.navigateToPage('dashboard'),
                            ),
                            _buildSidebarItem(
                              Icons.book,
                              'Courses',
                              'courses',
                              navController.currentPage.value,
                              () => navController.navigateToPage('courses'),
                            ),
                            _buildSidebarItem(
                              Icons.people,
                              'Students',
                              'students',
                              navController.currentPage.value,
                              () => navController.navigateToPage('students'),
                            ),
                            _buildSidebarItem(
                              Icons.people,
                              'Instructors',
                              'instructors',
                              navController.currentPage.value,
                              () => navController.navigateToPage('instructors'),
                            ),
                            _buildSidebarItem(
                              Icons.directions_car,
                              'Vehicles',
                              'vehicles',
                              navController.currentPage.value,
                              () => navController.navigateToPage('vehicles'),
                            ),
                            _buildSidebarItem(
                              Icons.attach_money,
                              'Payments & Invoices',
                              'billing',
                              navController.currentPage.value,
                              () => navController.navigateToPage('billing'),
                            ),
                            _buildSidebarItem(
                              Icons.schedule,
                              'Bookings',
                              'schedules',
                              navController.currentPage.value,
                              () => navController.navigateToPage('schedules'),
                            ),
                            _buildSidebarItem(
                              Icons.people,
                              'Users',
                              'users',
                              navController.currentPage.value,
                              () => navController.navigateToPage('users'),
                            ),
                            _buildReportsDropdown(navController),
                            _buildSidebarItem(
                              Icons.settings,
                              'Settings',
                              'settings',
                              navController.currentPage.value,
                              () => navController.navigateToPage('settings'),
                            ),
                          ],
                        )),
                  ),
                ),

                // Logout Button
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Divider(color: Colors.white54),
                      ListTile(
                        leading: Icon(Icons.logout, color: Colors.red[300]),
                        title: Text(
                          'Logout',
                          style: TextStyle(color: Colors.red[300]),
                        ),
                        onTap: () => _showLogoutDialog(navController),
                      ),
                      Text(
                        'v1.0.0',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Fixed Top Bar
                Container(
                  height: 60,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Obx(() => Text(
                              navController.getCurrentPageTitle(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                            )),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.notifications,
                              color: Colors.grey[600]),
                          onPressed: () => _showNotificationsDialog(),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.account_circle,
                              color: Colors.grey[600]),
                          onSelected: (String value) {
                            switch (value) {
                              case 'profile':
                                _showProfileDialog(navController);
                                break;
                              case 'settings':
                                navController.navigateToPage('settings');
                                break;
                              case 'logout':
                                _showLogoutDialog(navController);
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(Icons.person, size: 18),
                                  SizedBox(width: 8),
                                  Text('Profile'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'settings',
                              child: Row(
                                children: [
                                  Icon(Icons.settings, size: 18),
                                  SizedBox(width: 8),
                                  Text('Settings'),
                                ],
                              ),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Logout',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Content Area
                Expanded(
                  child: Obx(() =>
                      _getCurrentPageWidget(navController.currentPage.value)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title,
    String pageKey,
    String currentPage,
    VoidCallback onTap,
  ) {
    final isActive = currentPage == pageKey;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue[600] : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white70,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildReportsDropdown(NavigationController navController) {
    return ExpansionTile(
      leading: Icon(Icons.bar_chart, color: Colors.white70),
      title: Text(
        'Reports',
        style: TextStyle(color: Colors.white70),
      ),
      iconColor: Colors.white70,
      collapsedIconColor: Colors.white70,
      children: <Widget>[
        _buildSidebarItem(
          Icons.person,
          'User Reports',
          'user_reports',
          navController.currentPage.value,
          () => navController.navigateToPage('user_reports'),
        ),
        _buildSidebarItem(
          Icons.book,
          'Course Reports',
          'course_reports',
          navController.currentPage.value,
          () => navController.navigateToPage('course_reports'),
        ),
        _buildSidebarItem(
          Icons.calendar_today,
          'Schedule Reports',
          'schedule_reports',
          navController.currentPage.value,
          () => navController.navigateToPage('schedule_reports'),
        ),
        _buildSidebarItem(
          Icons.attach_money,
          'Billing Reports',
          'billing_reports',
          navController.currentPage.value,
          () => navController.navigateToPage('billing_reports'),
        ),
      ],
    );
  }

  Widget _getCurrentPageWidget(String currentPage) {
    switch (currentPage) {
      case 'dashboard':
        return DashboardContent();
      case 'courses':
        return CourseScreen();
      case 'students':
        return EnhancedUsersScreen(role: 'student');
      case 'instructors':
        return EnhancedUsersScreen(role: 'instructor');
      case 'vehicles':
        return FleetScreen();
      case 'billing':
        return BillingScreen();
      case 'schedules':
        return ScheduleScreen();
      case 'users':
        return EnhancedUsersScreen(role: 'admin');
      case 'course_reports':
        return CourseReportsScreen();
      case 'settings':
        return _buildSettingsPage();
      default:
        return DashboardContent();
    }
  }

  Widget _buildSettingsPage() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.school),
              title: Text('School Information'),
              subtitle: Text('Manage school details and preferences'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notifications'),
              subtitle: Text('Configure notification preferences'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.security),
              title: Text('Security'),
              subtitle: Text('Password and security settings'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(NavigationController navController) {
    Get.dialog(
      AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              navController.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(NavigationController navController) {
    final user = navController.currentUser.value;
    if (user == null) return;

    Get.dialog(
      AlertDialog(
        title: Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    user['name']![0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name']!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(user['email']!),
                      Text(
                        user['role']!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              // Navigate to edit profile
            },
            child: Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Notifications'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.person_add, color: Colors.blue),
                ),
                title: Text('New student registered'),
                subtitle: Text('John Doe has been added to the system'),
                trailing: Text('2h ago'),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Icon(Icons.payment, color: Colors.green),
                ),
                title: Text('Payment received'),
                subtitle: Text('Payment from Sarah Smith processed'),
                trailing: Text('4h ago'),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Icon(Icons.schedule, color: Colors.orange),
                ),
                title: Text('Lesson reminder'),
                subtitle: Text('Upcoming lesson in 30 minutes'),
                trailing: Text('30m'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(),
            child: Text('Mark All Read'),
          ),
        ],
      ),
    );
  }
}
