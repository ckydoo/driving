// lib/dashboard_updated.dart
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UpdatedDashboardScreen extends StatelessWidget {
  const UpdatedDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CompleteMainLayout();
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<UserController>(
      builder: (userController) {
        return GetBuilder<BillingController>(
          builder: (billingController) {
            // Calculate real values - Fixed income calculation
            final totalStudents = userController.users
                .where((user) => user.role == 'student')
                .length;

            // Calculate total income from all payments, not just paid invoices
            final totalIncome = billingController.payments
                .fold<double>(0, (sum, payment) => sum + payment.amount);

            final unpaidInvoices = billingController.invoices
                .fold<double>(0, (sum, invoice) => sum + invoice.balance);

            final activeInstructors = userController.users
                .where((user) =>
                    user.role == 'instructor' && user.status == 'Active')
                .length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeSection(),
                  const SizedBox(height: 24),

                  // Statistics Cards with real data
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Students',
                          '$totalStudents',
                          Icons.school,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Total Income',
                          '\$${totalIncome.toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Unpaid Amount',
                          '\$${unpaidInvoices.toStringAsFixed(2)}',
                          Icons.payment,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Active Instructors',
                          '$activeInstructors',
                          Icons.person,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Quick Actions Section with functionality
                  _buildQuickActionsSection(),

                  const SizedBox(height: 32),

                  // Real data sections
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildRecentActivitiesCard(
                            billingController, userController),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildQuickStatsCard(
                            billingController, userController),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s what\'s happening with your driving school today.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Icon(
            Icons.school,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Icon(Icons.trending_up, color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Add Student',
                'Register a new student',
                Icons.person_add,
                Colors.blue,
                () {
                  final navController = Get.find<NavigationController>();
                  navController.navigateToPage('students');
                  // You could also show a dialog or navigate to add student form
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Schedule Lesson',
                'Book a new lesson',
                Icons.calendar_today,
                Colors.green,
                () {
                  final navController = Get.find<NavigationController>();
                  navController.navigateToPage('schedule');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Create Invoice',
                'Generate new invoice',
                Icons.receipt,
                Colors.orange,
                () {
                  final navController = Get.find<NavigationController>();
                  navController.navigateToPage('billing');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Add Vehicle',
                'Register new vehicle',
                Icons.directions_car,
                Colors.purple,
                () {
                  final navController = Get.find<NavigationController>();
                  navController.navigateToPage('fleet');
                },
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesCard(
      BillingController billingController, UserController userController) {
    // Get recent activities from real data
    final recentPayments = billingController.payments
        .where((p) =>
            p.paymentDate.isAfter(DateTime.now().subtract(Duration(days: 7))))
        .take(4)
        .toList();

    final recentStudents = userController.users
        .where((u) => u.role == 'student' && u.created_at != null)
        .where((u) =>
            u.created_at!.isAfter(DateTime.now().subtract(Duration(days: 7))))
        .take(2)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Show recent student registrations
          ...recentStudents
              .map((student) => _buildActivityItem(
                    'New student ${student.fname} ${student.lname} registered',
                    _getTimeAgo(student.created_at!),
                    Icons.person_add,
                    Colors.blue,
                  ))
              .toList(),

          // Show recent payments
          ...recentPayments.map((payment) {
            final invoice = billingController.invoices.firstWhereOrNull(
              (inv) => inv.id == payment.invoiceId,
            );
            final student = userController.users.firstWhereOrNull(
              (user) => user.id == invoice?.studentId,
            );

            return _buildActivityItem(
              'Payment received from ${student?.fname ?? 'Unknown'} - ${payment.formattedAmount}',
              _getTimeAgo(payment.paymentDate),
              Icons.payment,
              Colors.green,
            );
          }).toList(),

          // If no recent activities, show placeholder
          if (recentPayments.isEmpty && recentStudents.isEmpty)
            _buildActivityItem(
              'No recent activities',
              'Check back later',
              Icons.info_outline,
              Colors.grey,
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard(
      BillingController billingController, UserController userController) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    // Calculate today's statistics
    final todaysPayments = billingController.payments
        .where((p) =>
            p.paymentDate.isAfter(todayStart) &&
            p.paymentDate.isBefore(todayEnd))
        .length;

    final pendingInvoices = billingController.invoices
        .where((inv) => inv.status == 'pending' || inv.balance > 0)
        .length;

    final totalVehicles =
        0; // You'll need to get this from FleetController when available

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('Today\'s Payments', '$todaysPayments', Colors.green),
          _buildStatRow('Pending Invoices', '$pendingInvoices', Colors.orange),
          _buildStatRow(
              'Total Students',
              '${userController.users.where((u) => u.role == 'student').length}',
              Colors.blue),
          _buildStatRow(
              'Active Instructors',
              '${userController.users.where((u) => u.role == 'instructor' && u.status == 'Active').length}',
              Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
