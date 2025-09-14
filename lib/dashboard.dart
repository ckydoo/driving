// lib/dashboard_fixed.dart
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
              padding: ResponsiveUtils.getPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section - Fixed
                  _buildFixedWelcomeSection(context),
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

  Widget _buildFixedWelcomeSection(BuildContext context) {
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
                _buildWelcomeText(context),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildWelcomeText(context)),
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

  Widget _buildWelcomeText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ResponsiveText(
          style: const TextStyle(),
          'Welcome back!',
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
        'value': '\$${totalIncome.toStringAsFixed(2)}',
        'icon': Icons.attach_money,
        'color': Colors.green,
        'show': authController.hasAnyRole(['admin', 'instructor']),
      },
      {
        'title': 'Unpaid Amount',
        'value': '\$${unpaidInvoices.toStringAsFixed(2)}',
        'icon': Icons.payment,
        'color': Colors.orange,
        'show': authController.hasAnyRole(['admin', 'instructor']),
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
        'subtitle': 'Register a new student',
        'icon': Icons.person_add,
        'color': Colors.blue,
        'route': 'students'
      },
      {
        'title': 'Schedule Lesson',
        'subtitle': 'Book a new lesson',
        'icon': Icons.calendar_today,
        'color': Colors.green,
        'route': 'schedules'
      },
      {
        'title': 'Create Invoice',
        'subtitle': 'Generate new invoice',
        'icon': Icons.receipt,
        'color': Colors.orange,
        'route': 'billing'
      },
      {
        'title': 'Add Vehicle',
        'subtitle': 'Register new vehicle',
        'icon': Icons.directions_car,
        'color': Colors.purple,
        'route': 'vehicles'
      },
    ];

    if (context.isMobile) {
      // Mobile: Simple GridView
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) =>
            _buildFixedQuickActionCard(context, actions[index]),
      );
    } else {
      // Tablet/Desktop: Simple Row
      return Row(
        children: actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < actions.length - 1 ? 12 : 0,
              ),
              child: _buildFixedQuickActionCard(context, action),
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildFixedQuickActionCard(
      BuildContext context, Map<String, dynamic> action) {
    return Container(
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(10),
        tablet: const EdgeInsets.all(12),
        desktop: const EdgeInsets.all(16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final navController = Get.find<NavigationController>();
            navController.navigateToPage(action['route']);
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (action['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(action['icon'],
                    color: action['color'],
                    size: ResponsiveUtils.getValue(context,
                        mobile: 18.0, tablet: 20.0, desktop: 22.0)),
              ),
              SizedBox(
                  height: ResponsiveUtils.getValue(context,
                      mobile: 6.0, tablet: 8.0, desktop: 10.0)),

              // Title
              ResponsiveText(
                style: const TextStyle(),
                action['title'],
                fontSize: ResponsiveUtils.getValue(context,
                    mobile: 11.0, tablet: 12.0, desktop: 14.0),
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Subtitle
              ResponsiveText(
                style: const TextStyle(),
                action['subtitle'],
                fontSize: ResponsiveUtils.getValue(context,
                    mobile: 9.0, tablet: 10.0, desktop: 12.0),
                color: Colors.grey[600],
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

  Widget _buildFixedActivitiesSection(
    BuildContext context,
    BillingController billingController,
    UserController userController,
  ) {
    if (context.isMobile) {
      // Mobile: Stack vertically
      return Column(
        children: [
          _buildFixedRecentActivitiesCard(
              context, billingController, userController),
          const SizedBox(height: 16),
          _buildFixedQuickStatsCard(context, billingController, userController),
        ],
      );
    } else {
      // Tablet/Desktop: Side by side
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _buildFixedRecentActivitiesCard(
                context, billingController, userController),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildFixedQuickStatsCard(
                context, billingController, userController),
          ),
        ],
      );
    }
  }

  Widget _buildFixedRecentActivitiesCard(
    BuildContext context,
    BillingController billingController,
    UserController userController,
  ) {
    // Get recent activities from real data
    final recentPayments = billingController.payments
        .where((p) => p.paymentDate
            .isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .take(context.isMobile ? 2 : 3)
        .toList();

    final recentStudents = userController.users
        .where((u) => u.role == 'student')
        .where((u) => u.created_at
            .isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .take(context.isMobile ? 1 : 2)
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: ResponsiveUtils.getValue(context,
            mobile: 300.0, tablet: 350.0, desktop: 400.0),
      ),
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(18),
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
          ResponsiveText(
            style: const TextStyle(),
            'Recent Activities',
            fontSize: ResponsiveUtils.getValue(context,
                mobile: 16.0, tablet: 17.0, desktop: 18.0),
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          SizedBox(
              height: ResponsiveUtils.getValue(context,
                  mobile: 12.0, tablet: 14.0, desktop: 16.0)),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Show recent student registrations
                  ...recentStudents
                      .map((student) => _buildFixedActivityItem(
                            context,
                            'New student ${student.fname} ${student.lname} registered',
                            _getTimeAgo(student.created_at),
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

                    return _buildFixedActivityItem(
                      context,
                      'Payment received from ${student?.fname ?? 'Unknown'} - ${payment.formattedAmount}',
                      _getTimeAgo(payment.paymentDate),
                      Icons.payment,
                      Colors.green,
                    );
                  }).toList(),

                  // If no recent activities, show placeholder
                  if (recentPayments.isEmpty && recentStudents.isEmpty)
                    _buildFixedActivityItem(
                      context,
                      'No recent activities',
                      'Check back later',
                      Icons.info_outline,
                      Colors.grey,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedActivityItem(
    BuildContext context,
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container - Fixed size
          Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),

          // Text content - Expanded
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getValue(context,
                        mobile: 12.0, tablet: 13.0, desktop: 14.0),
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getValue(context,
                        mobile: 10.0, tablet: 11.0, desktop: 12.0),
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedQuickStatsCard(
    BuildContext context,
    BillingController billingController,
    UserController userController,
  ) {
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

    final stats = [
      {
        'label': 'Today\'s Payments',
        'value': '$todaysPayments',
        'color': Colors.green
      },
      {
        'label': 'Pending Invoices',
        'value': '$pendingInvoices',
        'color': Colors.orange
      },
      {
        'label': 'Total Students',
        'value':
            '${userController.users.where((u) => u.role == 'student').length}',
        'color': Colors.blue
      },
      {
        'label': 'Active Instructors',
        'value':
            '${userController.users.where((u) => u.role == 'instructor' && u.status == 'Active').length}',
        'color': Colors.purple
      },
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: ResponsiveUtils.getValue(context,
            mobile: 300.0, tablet: 350.0, desktop: 400.0),
      ),
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(18),
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
          ResponsiveText(
            style: const TextStyle(),
            'Today\'s Overview',
            fontSize: ResponsiveUtils.getValue(context,
                mobile: 16.0, tablet: 17.0, desktop: 18.0),
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          SizedBox(
              height: ResponsiveUtils.getValue(context,
                  mobile: 12.0, tablet: 14.0, desktop: 16.0)),
          Expanded(
            child: Column(
              children: stats
                  .map((stat) => _buildFixedStatRow(
                      context,
                      stat['label'] as String,
                      stat['value'] as String,
                      stat['color'] as Color))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedStatRow(
      BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveUtils.getValue(context,
                    mobile: 12.0, tablet: 13.0, desktop: 14.0),
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getValue(context,
                  mobile: 8.0, tablet: 10.0, desktop: 12.0),
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveUtils.getValue(context,
                    mobile: 12.0, tablet: 13.0, desktop: 14.0),
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
