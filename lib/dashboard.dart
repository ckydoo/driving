// lib/dashboard.dart - MINIMAL SAFE VERSION
// Replace your entire dashboard.dart with this code

import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FixedDashboardScreen extends StatelessWidget {
  const FixedDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const FixedDashboardContent(),
    );
  }
}

class FixedDashboardContent extends StatelessWidget {
  const FixedDashboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      try {
        final authController = Get.find<AuthController>();

        // Check authentication state SAFELY
        final isLoggedIn = authController.isLoggedIn.value;
        final currentUser = authController.currentUser.value;

        if (!isLoggedIn || currentUser == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading dashboard...'),
              ],
            ),
          );
        }

        // Safe user data extraction
        final userName = _getSafeName(currentUser);
        final userRole = _getSafeRole(currentUser);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeCard(userName),

              const SizedBox(height: 20),

              // Basic Stats Section
              _buildStatsSection(userRole),

              const SizedBox(height: 20),

              // Recent Activity Section
              _buildRecentActivitySection(),
            ],
          ),
        );
      } catch (e) {
        print('Dashboard build error: $e');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading dashboard'),
              const SizedBox(height: 8),
              Text('$e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Get.offAllNamed('/login'),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        );
      }
    });
  }

  // Safe helper method to get user name
  String _getSafeName(dynamic user) {
    if (user == null) return 'User';

    try {
      // Try to access fname safely
      if (user.fname != null && user.fname.toString().isNotEmpty) {
        return user.fname.toString();
      }

      // Try to access email safely
      if (user.email != null && user.email.toString().isNotEmpty) {
        final email = user.email.toString();
        if (email.contains('@')) {
          return email.split('@')[0];
        }
        return email;
      }

      return 'User';
    } catch (e) {
      print('Error getting safe name: $e');
      return 'User';
    }
  }

  // Safe helper method to get user role
  String _getSafeRole(dynamic user) {
    if (user == null) return 'guest';

    try {
      if (user.role != null) {
        return user.role.toString().toLowerCase();
      }
      return 'guest';
    } catch (e) {
      print('Error getting safe role: $e');
      return 'guest';
    }
  }

  Widget _buildWelcomeCard(String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $userName!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'DriveSync Pro - Drive Smarter, Manage Easier!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(String userRole) {
    return GetBuilder<UserController>(
      builder: (userController) {
        return GetBuilder<BillingController>(
          builder: (billingController) {
            // Safe calculations
            int totalStudents = 0;
            double totalIncome = 0.0;
            int activeInstructors = 0;

            try {
              if (userController.users.isNotEmpty) {
                totalStudents = userController.users
                    .where((user) => user.role == 'student')
                    .length;

                activeInstructors = userController.users
                    .where((user) =>
                        user.role == 'instructor' && user.status == 'Active')
                    .length;
              }

              if (billingController.payments.isNotEmpty) {
                totalIncome = billingController.payments
                    .fold<double>(0, (sum, payment) => sum + payment.amount);
              }
            } catch (e) {
              print('Error calculating stats: $e');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Stats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Students',
                        totalStudents.toString(),
                        Icons.school,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Instructors',
                        activeInstructors.toString(),
                        Icons.person,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (userRole == 'admin' || userRole == 'instructor')
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Income',
                          '\$${totalIncome.toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Icon(Icons.trending_up, color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Column(
            children: [
              ListTile(
                leading: Icon(Icons.school, color: Colors.blue),
                title: Text('New student registration'),
                subtitle: Text('2 hours ago'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.payment, color: Colors.green),
                title: Text('Payment received'),
                subtitle: Text('4 hours ago'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.schedule, color: Colors.orange),
                title: Text('Lesson scheduled'),
                subtitle: Text('6 hours ago'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
