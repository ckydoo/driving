// lib/dashboard.dart - FIXED NULL SAFETY VERSION
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/controllers/utils/responsive_utils.dart';
import 'package:driving/widgets/main_layout.dart';
import 'package:driving/widgets/responsive_extensions.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FixedDashboardScreen extends StatelessWidget {
  const FixedDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveMainLayout();
  }
}

class FixedDashboardContent extends StatelessWidget {
  const FixedDashboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return GetBuilder<UserController>(
      builder: (userController) {
        return GetBuilder<BillingController>(
          builder: (billingController) {
            // SAFE: Check authentication before proceeding
            if (!authController.isLoggedIn.value ||
                authController.currentUser.value == null) {
              // Return a loading or error widget if user is not authenticated
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading user data...'),
                  ],
                ),
              );
            }

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
              // <-- This is line 52 - Now SAFE
              padding: ResponsiveUtils.getPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section - Fixed
                  _buildFixedWelcomeSection(context, authController),
                  SizedBox(
                      height: ResponsiveUtils.getValue(context,
                          mobile: 16.0, tablet: 20.0, desktop: 24.0)),

                  // Statistics Cards - Fixed
                  _buildFixedStatsSection(
                    context,
                    authController,
                    totalStudents,
                    totalIncome,
                    unpaidInvoices,
                    activeInstructors,
                  ),

                  SizedBox(
                      height: ResponsiveUtils.getValue(context,
                          mobile: 20.0, tablet: 24.0, desktop: 32.0)),

                  // SAFE: Check user role before showing role-specific content
                  if (authController.hasAnyRole(['admin', 'instructor']))
                    _buildFixedQuickActions(context),

                  SizedBox(
                      height: ResponsiveUtils.getValue(context,
                          mobile: 20.0, tablet: 24.0, desktop: 32.0)),

                  // Real data sections - Fixed
                  if (authController.hasAnyRole(['admin', 'instructor']))
                    _buildFixedActivitiesSection(
                        context, billingController, userController),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFixedWelcomeSection(
      BuildContext context, AuthController authController) {
    return Container(
      width: double.infinity,
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(24),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ResponsiveUtils.getValue(context,
            mobile: 12.0, tablet: 14.0, desktop: 16.0)),
      ),
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.school,
                  size: ResponsiveUtils.getValue(context,
                      mobile: 40.0, tablet: 50.0, desktop: 60.0),
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                _buildWelcomeText(context, authController),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildWelcomeText(context, authController)),
                const SizedBox(width: 16),
                Icon(
                  Icons.school,
                  size: ResponsiveUtils.getValue(context,
                      mobile: 60.0, tablet: 70.0, desktop: 80.0),
                  color: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
    );
  }

  Widget _buildWelcomeText(
      BuildContext context, AuthController authController) {
    // Use safe access to userFirstName
    final welcomeName = authController.isUserDataAvailable
        ? authController.userFirstName
        : 'User';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ResponsiveText(
          style: const TextStyle(),
          'Welcome back, $welcomeName!',
          fontSize: ResponsiveUtils.getValue(context,
              mobile: 22.0, tablet: 25.0, desktop: 28.0),
          fontWeight: FontWeight.bold,
          color: Colors.white,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        ResponsiveText(
          style: const TextStyle(),
          'DriveSync Pro - Drive Smarter, Manage Easier!',
          fontSize: ResponsiveUtils.getValue(context,
              mobile: 13.0, tablet: 15.0, desktop: 16.0),
          color: Colors.white.withOpacity(0.9),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFixedStatsSection(
    BuildContext context,
    AuthController authController,
    int totalStudents,
    double totalIncome,
    double unpaidInvoices,
    int activeInstructors,
  ) {
    final stats = <Map<String, dynamic>>[
      {
        'title': 'Total Students',
        'value': '$totalStudents',
        'icon': Icons.school,
        'color': Colors.blue,
        'show': true,
      },
      {
        'title': 'Total Income',
        'value': '\${totalIncome.toStringAsFixed(2)}',
        'icon': Icons.attach_money,
        'color': Colors.green,
        'show': authController
            .hasAnyRole(['admin', 'instructor']), // SAFE: Uses safe method
      },
      {
        'title': 'Unpaid Amount',
        'value': '\${unpaidInvoices.toStringAsFixed(2)}',
        'icon': Icons.payment,
        'color': Colors.orange,
        'show': authController
            .hasAnyRole(['admin', 'instructor']), // SAFE: Uses safe method
      },
      {
        'title': 'Active Instructors',
        'value': '$activeInstructors',
        'icon': Icons.person,
        'color': Colors.purple,
        'show': true,
      },
    ].where((stat) => stat['show'] == true).toList();

    if (context.isMobile) {
      // Mobile: Simple GridView without LayoutBuilder
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) =>
            _buildFixedStatCard(context, stats[index]),
      );
    } else {
      // Tablet/Desktop: Simple Row
      return Row(
        children: stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < stats.length - 1 ? 16 : 0,
              ),
              child: _buildFixedStatCard(context, stat),
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildFixedStatCard(BuildContext context, Map<String, dynamic> stat) {
    return Container(
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(16),
        desktop: const EdgeInsets.all(20),
      ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (stat['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(stat['icon'],
                    color: stat['color'],
                    size: ResponsiveUtils.getValue(context,
                        mobile: 18.0, tablet: 20.0, desktop: 22.0)),
              ),
              Icon(Icons.trending_up,
                  color: Colors.green,
                  size: ResponsiveUtils.getValue(context,
                      mobile: 14.0, tablet: 15.0, desktop: 16.0)),
            ],
          ),
          const SizedBox(height: 12),

          // Value Text
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ResponsiveText(
                style: const TextStyle(),
                stat['value'],
                fontSize: ResponsiveUtils.getValue(context,
                    mobile: 18.0, tablet: 20.0, desktop: 24.0),
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Title Text
          ResponsiveText(
            style: const TextStyle(),
            stat['title'],
            fontSize: ResponsiveUtils.getValue(context,
                mobile: 11.0, tablet: 12.0, desktop: 14.0),
            color: Colors.grey[600],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFixedQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText(
          style: const TextStyle(),
          'Quick Actions',
          fontSize: ResponsiveUtils.getValue(context,
              mobile: 18.0, tablet: 19.0, desktop: 20.0),
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
        SizedBox(
            height: ResponsiveUtils.getValue(context,
                mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        _buildFixedQuickActionsGrid(context),
      ],
    );
  }

  Widget _buildFixedQuickActionsGrid(BuildContext context) {
    final actions = [
      {
        'title': 'Add Student',
        'icon': Icons.person_add,
        'color': Colors.blue,
        'onTap': () => Get.toNamed('/students'),
      },
      {
        'title': 'Create Invoice',
        'icon': Icons.receipt_long,
        'color': Colors.green,
        'onTap': () => Get.toNamed('/billing'),
      },
      {
        'title': 'Schedule Lesson',
        'icon': Icons.schedule,
        'color': Colors.orange,
        'onTap': () => Get.toNamed('/schedules'),
      },
      {
        'title': 'Fleet Management',
        'icon': Icons.directions_car,
        'color': Colors.purple,
        'onTap': () => Get.toNamed('/fleet'),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.isMobile ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: context.isMobile ? 1.2 : 1.1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: action['onTap'] as VoidCallback,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  action['icon'] as IconData,
                  color: action['color'] as Color,
                  size: 28,
                ),
                const SizedBox(height: 8),
                ResponsiveText(
                  style: const TextStyle(),
                  action['title'] as String,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFixedActivitiesSection(
    BuildContext context,
    BillingController billingController,
    UserController userController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText(
          style: const TextStyle(),
          'Recent Activities',
          fontSize: ResponsiveUtils.getValue(context,
              mobile: 18.0, tablet: 19.0, desktop: 20.0),
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
        SizedBox(
            height: ResponsiveUtils.getValue(context,
                mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        _buildFixedActivityCards(context, billingController, userController),
      ],
    );
  }

  Widget _buildFixedActivityCards(
    BuildContext context,
    BillingController billingController,
    UserController userController,
  ) {
    // Get recent activities
    final recentPayments = billingController.payments.take(3).toList();

    final recentStudents = userController.users
        .where((user) => user.role == 'student')
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Recent Payments',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          if (recentPayments.isEmpty)
            Text(
              'No recent payments',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            ...recentPayments.map((payment) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Payment #${payment.receiptNumber}',
                        style: TextStyle(color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\${payment.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          const SizedBox(height: 20),
          Text(
            'Recent Students',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          if (recentStudents.isEmpty)
            Text(
              'No recent students',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            ...recentStudents.map((student) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        '${student.fname.isNotEmpty ? student.fname[0] : 'S'}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${student.fname} ${student.lname}',
                        style: TextStyle(color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: student.status == 'Active'
                            ? Colors.green[100]
                            : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        student.status,
                        style: TextStyle(
                          color: student.status == 'Active'
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
