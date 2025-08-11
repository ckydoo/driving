// lib/widgets/main_layout.dart
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/dashboard.dart';
import 'package:driving/overview/quick_search_screen.dart';
import 'package:driving/reports/course.dart';
import 'package:driving/screens/billing/billing_screen.dart';
import 'package:driving/screens/course/course_screen.dart';
import 'package:driving/screens/fleet/fleet_screen.dart';
import 'package:driving/screens/receipts/receipt_management_screen.dart';
import 'package:driving/screens/schedule/schedule_screen.dart';
import 'package:driving/screens/users/enhanced_users_screen.dart';
import 'package:driving/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/screens/payments/pos.dart';
import '../controllers/navigation_controller.dart';

class CompleteMainLayout extends StatelessWidget {
  const CompleteMainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final NavigationController navController = Get.find<NavigationController>();
    final AuthController authController = Get.find<AuthController>();

    return Scaffold(
      body: Obx(() {
        // Check if user is logged in
        if (!authController.isLoggedIn.value) {
          // Redirect to login if not authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offAllNamed('/login');
          });
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Row(
          children: [
            // Fixed Left Sidebar with role-based navigation
            Container(
              width: 250,
              color: Colors.blueGrey[900],
              child: Column(
                children: [
                  // Header with user info
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Myla Driving School',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // User info with role badge
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  navController.getRoleBadgeColor(),
                              child: Text(
                                navController.currentUserName
                                    .split(' ')
                                    .map((name) => name[0])
                                    .take(2)
                                    .join(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    navController.currentUserName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: navController.getRoleBadgeColor(),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      navController.currentUserRole
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24),

                  // Navigation items (filtered by role)
                  Expanded(
                    child: ListView(
                      children: navController.navigationItems.map((item) {
                        return _buildSidebarItem(
                          item.icon,
                          item.title,
                          item.pageKey,
                          navController.currentPage.value,
                          () => navController.navigateToPage(item.pageKey),
                        );
                      }).toList(),
                    ),
                  ),

                  // Logout button
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLogoutDialog(navController),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Bar with user actions
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          Text(
                            navController.getCurrentPageTitle(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          // Search bar (optional)
                          if (authController
                              .hasAnyRole(['admin', 'instructor']))
                            IconButton(
                              icon:
                                  Icon(Icons.payment, color: Colors.grey[600]),
                              onPressed: () =>
                                  navController.navigateToPage('pos'),
                            ),
                          // Search bar (optional)
                          if (authController
                              .hasAnyRole(['admin', 'instructor']))
                            IconButton(
                              icon: Icon(Icons.search, color: Colors.grey[600]),
                              onPressed: () =>
                                  navController.navigateToPage('quick_search'),
                            ),
                          IconButton(
                            icon: Icon(Icons.notifications,
                                color: Colors.grey[600]),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 16),
                          // User menu
                          PopupMenuButton<String>(
                            onSelected: (value) {
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
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      navController.getRoleBadgeColor(),
                                  radius: 18,
                                  child: Text(
                                    navController.currentUserName
                                        .split(' ')
                                        .map((name) => name[0])
                                        .take(2)
                                        .join(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'profile',
                                child: Row(
                                  children: [
                                    Icon(Icons.person, size: 18),
                                    SizedBox(width: 8),
                                    Text('Profile'),
                                  ],
                                ),
                              ),
                              if (navController.hasAccessToPage('settings'))
                                const PopupMenuItem<String>(
                                  value: 'settings',
                                  child: Row(
                                    children: [
                                      Icon(Icons.settings, size: 18),
                                      SizedBox(width: 8),
                                      Text('Settings'),
                                    ],
                                  ),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
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
                    child: Obx(() {
                      final currentPage = navController.currentPage.value;

                      // Check access before rendering
                      if (!navController.hasAccessToPage(currentPage)) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.block,
                                size: 64,
                                color: Colors.red,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Access Denied',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'You do not have permission to access this page.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return _getCurrentPageWidget(currentPage);
                    }),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  Widget _getCurrentPageWidget(String currentPage) {
    switch (currentPage) {
      case 'dashboard':
        return const DashboardContent();
      case 'courses':
        return CourseScreen();
      case 'students':
        return EnhancedUsersScreen(
            role: 'student', key: const ValueKey('students'));
      case 'instructors':
        return EnhancedUsersScreen(
            role: 'instructor', key: const ValueKey('instructors'));
      case 'vehicles':
        return FleetScreen();
      case 'quick_search':
        return QuickSearchScreen();
      case 'receipts':
        return ReceiptManagementScreen();
      case 'billing':
        return BillingScreen();
      case 'schedules':
        return ScheduleScreen();
      case 'users':
        return EnhancedUsersScreen(role: 'admin');
      case 'course_reports':
        return CourseReportsScreen();
      case 'settings':
        return SettingsScreen();
      case 'pos':
        return POSScreen();
      default:
        return const DashboardContent();
    }
  }

  void _showLogoutDialog(NavigationController navController) {
    Get.dialog(
      AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(NavigationController navController) {
    Get.dialog(
      AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: navController.getRoleBadgeColor(),
                  child: Text(
                    navController.currentUserName
                        .split(' ')
                        .map((name) => name[0])
                        .take(2)
                        .join(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        navController.currentUserName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: navController.getRoleBadgeColor(),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          navController.currentUserRole.toUpperCase(),
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
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Email: ${navController.currentUserEmail}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
