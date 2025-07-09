import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/reports/course.dart';
import 'package:driving/screens/billing/billing_screen.dart';
import 'package:driving/screens/course/course_screen.dart';
import 'package:driving/screens/fleet/fleet_screen.dart';
import 'package:driving/screens/schedule/schedule_screen.dart';
import 'package:driving/screens/users/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final billingController = Get.find<BillingController>();

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 250,
            color: Colors.blueGrey[900],
            child: Column(
              children: [
                // Scrollable sidebar items
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'DRIVING SCHOOL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Divider(color: Colors.white54),
                        _buildSidebarItem(Icons.dashboard, 'Dashboard', () {}),
                        _buildSidebarItem(Icons.book, 'Courses', () {
                          Get.to(() => CourseScreen());
                        }),
                        _buildSidebarItem(Icons.people, 'Students', () {
                          Get.to(() => UsersScreen(role: 'student'));
                        }),
                        _buildSidebarItem(Icons.people, 'Instructors', () {
                          Get.to(() => UsersScreen(role: 'instructor'));
                        }),
                        _buildSidebarItem(Icons.car_crash, 'Vehicles', () {
                          Get.to(() => FleetScreen());
                        }),
                        _buildSidebarItem(
                            Icons.attach_money, 'Payments & Invoices', () {
                          Get.to(() => BillingScreen());
                        }),
                        _buildSidebarItem(Icons.schedule, 'Bookings', () {
                          Get.to(() => ScheduleScreen());
                        }),
                        _buildSidebarItem(Icons.people, 'Users', () {
                          Get.to(() => UsersScreen(role: 'admin'));
                        }),
                        _buildReportsDropdown(),
                        _buildSidebarItem(Icons.settings, 'Settings', () {}),
                      ],
                    ),
                  ),
                ),
                // Version text at the bottom
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  // Statistics Cards - Now using Obx to update dynamically
                  Obx(() {
                    // Calculate data here
                    final totalStudents = userController.users
                        .where((user) => user.role == 'student')
                        .length;
                    final totalIncome = billingController.invoices
                        .where((invoice) =>
                            invoice.status == 'paid') // Check status here
                        .fold<double>(
                            0, (sum, invoice) => sum + (invoice.amountPaid));
                    final unpaidInvoices = billingController.invoices
                        // We now calculate based on the balance directly
                        .fold<double>(
                            0, (sum, invoice) => sum + invoice.balance);

                    return Row(
                      children: [
                        _buildStatCard(
                            'Total Students', '$totalStudents', Colors.blue),
                        SizedBox(width: 16),
                        _buildStatCard(
                            'Income',
                            '\$${totalIncome.toStringAsFixed(2)}',
                            Colors.green),
                        SizedBox(width: 16),
                        _buildStatCard(
                            'Unpaid Invoices',
                            '\$${unpaidInvoices.toStringAsFixed(2)}',
                            Colors.orange),
                      ],
                    );
                  }),
                  SizedBox(height: 32),
                  // Charts or Additional Reports
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Student Growth',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // Placeholder for a chart
                                  Container(
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: Text(
                                        'Chart Placeholder',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Class Attendance',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // Placeholder for a chart
                                  Container(
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: Text(
                                        'Chart Placeholder',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
  }

  // Helper method to build sidebar items
  Widget _buildSidebarItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(color: Colors.white),
      ),
      onTap: onTap,
    );
  }

  // Helper method to build statistic cards
  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsDropdown() {
    return ExpansionTile(
      leading: const Icon(Icons.bar_chart, color: Colors.white),
      title: const Text(
        'Reports',
        style: TextStyle(color: Colors.white),
      ),
      children: <Widget>[
        _buildSidebarItem(Icons.person, 'User Reports', () {}),
        _buildSidebarItem(Icons.book, 'Course Reports', () {
          Get.to(() => CourseReportsScreen());
        }),
        _buildSidebarItem(Icons.calendar_today, 'Schedule Reports', () {}),
        _buildSidebarItem(Icons.attach_money, 'Billing Reports', () {}),
        _buildSidebarItem(Icons.directions_car, 'Fleet Reports', () {}),
      ],
    );
  }
}
