// lib/widgets/main_layout.dart - Updated with dropdown support
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/dashboard.dart';
import 'package:driving/overview/quick_search_screen.dart';
import 'package:driving/reports/course.dart';
import 'package:driving/screens/billing/billing_screen.dart';
import 'package:driving/screens/course/course_screen.dart';
import 'package:driving/screens/fleet/fleet_screen.dart';
import 'package:driving/screens/receipts/receipt_management_screen.dart';
import 'package:driving/screens/reports/financial_reports_screen.dart';
import 'package:driving/screens/reports/users_reports_screen.dart';
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
    final SettingsController settingsController =
        Get.find<SettingsController>();

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
                        Obx(() => Text(
                              settingsController.businessName.value.isNotEmpty
                                  ? settingsController.businessName.value
                                  : 'Driving School',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            )),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  navController.getRoleBadgeColor(),
                              radius: 20,
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
                                      fontWeight: FontWeight.w500,
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

                  // Navigation items (filtered by role) with dropdown support
                  Expanded(
                    child: ListView(
                      children: navController.navigationItems
                          .expand((item) =>
                              _buildNavigationItems(item, navController))
                          .toList(),
                    ),
                  ),

                  // Logout button
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => navController.logout(),
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          elevation: 0,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Top navigation bar and content area
            Expanded(
              child: Column(
                children: [
                  // Top navigation bar
                  Container(
                    height: 60,
                    color: Colors.white,
                    child: Row(
                      children: [
                        // Page title
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Obx(() => Text(
                                  navController.getCurrentPageTitle(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                )),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            navController.navigateToPage('pos');
                          },
                          icon: const Icon(Icons.payment),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          tooltip: 'Search',
                          onPressed: () {
                            navController.navigateToPage('quick_search');
                          },
                        ),

                        // User menu dropdown
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'profile':
                                // Handle profile navigation
                                break;
                              case 'settings':
                                navController.navigateToPage('settings');
                                break;
                              case 'logout':
                                navController.logout();
                                break;
                            }
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
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

  // Build navigation items with dropdown support
  List<Widget> _buildNavigationItems(
      NavigationItem item, NavigationController navController) {
    final userRole =
        navController.authController.currentUser.value!.role.toLowerCase();

    // Filter children based on user role
    List<NavigationItem>? filteredChildren;
    if (item.children != null) {
      filteredChildren = item.children!
          .where((child) => child.requiredRoles.contains(userRole))
          .toList();
    }

    if (item.isDropdown &&
        filteredChildren != null &&
        filteredChildren.isNotEmpty) {
      // This is a dropdown with accessible children
      List<Widget> widgets = [];

      // Add the dropdown header
      widgets.add(_buildDropdownHeader(item, navController));

      // Add children if dropdown is expanded
      if (navController.isDropdownExpanded(item.pageKey)) {
        widgets.addAll(
          filteredChildren
              .map((child) => _buildDropdownChild(child, navController)),
        );
      }

      return widgets;
    } else if (!item.isDropdown) {
      // Regular navigation item
      return [
        _buildSidebarItem(
          item.icon,
          item.title,
          item.pageKey,
          navController.currentPage.value,
          () => navController.navigateToPage(item.pageKey),
        )
      ];
    }

    // Hide dropdown if no accessible children
    return [];
  }

  // Build dropdown header
  Widget _buildDropdownHeader(
      NavigationItem item, NavigationController navController) {
    final isExpanded = navController.isDropdownExpanded(item.pageKey);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => navController.toggleDropdown(item.pageKey),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build dropdown child item
  Widget _buildDropdownChild(
      NavigationItem item, NavigationController navController) {
    final isActive = navController.currentPage.value == item.pageKey;

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 8, top: 2, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => navController.navigateToPage(item.pageKey),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? Colors.white24 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isActive ? Colors.white : Colors.white60,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build regular sidebar item
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? Colors.white24 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getCurrentPageWidget(String pageKey) {
    switch (pageKey) {
      case 'dashboard':
        return const DashboardContent();
      case 'students':
        return const EnhancedUsersScreen(
          key: ValueKey('student_screen'),
          role: 'student',
        );
      case 'instructors':
        return const EnhancedUsersScreen(
          key: ValueKey('instructor_screen'),
          role: 'instructor',
        );
      case 'courses':
        return const CourseScreen();
      case 'vehicles':
        return const FleetScreen();
      case 'schedules':
        return ScheduleScreen();
      case 'billing':
        return const BillingScreen();
      case 'receipts':
        return const ReceiptManagementScreen();
      case 'pos':
        return const POSScreen();
      case 'financial_reports':
        return FinancialReportsScreen();
      case 'user_reports':
        return UsersReportsScreen();
      case 'users':
        return const EnhancedUsersScreen(
          key: ValueKey('admin_users_screen'),
          role: 'admin',
        );
      case 'quick_search':
        return const QuickSearchScreen();
      case 'settings':
        return SettingsScreen();
      default:
        return const DashboardContent();
    }
  }
}
