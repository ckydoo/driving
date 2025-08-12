// lib/widgets/responsive_main_layout.dart - EXACT UX Structure, Just Responsive
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

class ResponsiveMainLayout extends StatefulWidget {
  const ResponsiveMainLayout({Key? key}) : super(key: key);

  @override
  State<ResponsiveMainLayout> createState() => _ResponsiveMainLayoutState();
}

class _ResponsiveMainLayoutState extends State<ResponsiveMainLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Check if we should show mobile layout
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  @override
  Widget build(BuildContext context) {
    final NavigationController navController = Get.find<NavigationController>();
    final AuthController authController = Get.find<AuthController>();
    final SettingsController settingsController =
        Get.find<SettingsController>();

    return Scaffold(
      key: _scaffoldKey,
      // Show drawer only on mobile
      drawer: _isMobile(context)
          ? _buildMobileDrawer(
              navController, authController, settingsController)
          : null,
      body: Obx(() {
        // Check if user is logged in
        if (!authController.isLoggedIn.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offAllNamed('/login');
          });
          return const Center(child: CircularProgressIndicator());
        }

        // Mobile Layout (< 768px) - Drawer + content
        if (_isMobile(context)) {
          return Column(
            children: [
              _buildMobileTopBar(navController),
              Expanded(child: _buildContentArea(navController)),
            ],
          );
        }

        // Desktop Layout (>= 768px) - Your exact current structure
        return Row(
          children: [
            _buildDesktopSidebar(
                navController, authController, settingsController),
            Expanded(
              child: Column(
                children: [
                  _buildDesktopTopBar(navController),
                  Expanded(child: _buildContentArea(navController)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  // Mobile top bar with hamburger menu
  Widget _buildMobileTopBar(NavigationController navController) {
    return Container(
      height: 60,
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            // Hamburger menu
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            // Page title
            Expanded(
              child: Obx(() => Text(
                    navController.getCurrentPageTitle(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )),
            ),
            // Quick actions
            IconButton(
              onPressed: () => navController.navigateToPage('pos'),
              icon: const Icon(Icons.payment),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => navController.navigateToPage('quick_search'),
            ),
          ],
        ),
      ),
    );
  }

  // Desktop top bar - EXACT copy of your current structure
  Widget _buildDesktopTopBar(NavigationController navController) {
    return Container(
      height: 60,
      color: Colors.white,
      child: Row(
        children: [
          // Page title
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
          // User menu dropdown - EXACT copy
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
                  Get.find<AuthController>().logout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
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
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Mobile drawer - Exact content as desktop sidebar but in drawer format
  Widget _buildMobileDrawer(
    NavigationController navController,
    AuthController authController,
    SettingsController settingsController,
  ) {
    return Drawer(
      child: Container(
        color: Colors.blueGrey[900],
        child: SafeArea(
          child: Column(
            children: [
              // Header with user info - EXACT copy
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        )),
                    const SizedBox(height: 8),
                    const Text(
                      'Management System',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Navigation items - EXACT copy but auto-close drawer on tap
              Expanded(
                child: SingleChildScrollView(
                  child: Obx(() => Column(
                        children: _buildNavigationItems(navController,
                            autoClose: true),
                      )),
                ),
              ),
              // Logout button - EXACT copy
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close drawer first
                      authController.logout();
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Desktop sidebar - EXACT copy of your current structure
  Widget _buildDesktopSidebar(
    NavigationController navController,
    AuthController authController,
    SettingsController settingsController,
  ) {
    return Container(
      width: 250,
      color: Colors.blueGrey[900],
      child: Column(
        children: [
          // Header with user info - EXACT copy
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    )),
                const SizedBox(height: 8),
                const Text(
                  'Management System',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Navigation items - EXACT copy
          Expanded(
            child: SingleChildScrollView(
              child: Obx(() => Column(
                    children: _buildNavigationItems(navController),
                  )),
            ),
          ),
          // Logout button - EXACT copy
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: authController.logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build navigation items - EXACT copy of your logic
  List<Widget> _buildNavigationItems(NavigationController navController,
      {bool autoClose = false}) {
    final userRole =
        navController.authController.currentUser.value!.role.toLowerCase();

    List<Widget> widgets = [];

    // Dashboard - visible to all
    widgets.add(_buildSidebarItem(
      Icons.dashboard,
      'Dashboard',
      'dashboard',
      navController.currentPage.value,
      () {
        navController.navigateToPage('dashboard');
        if (autoClose) Navigator.of(context).pop();
      },
    ));

    // Role-based navigation items - EXACT copy of your logic
    if (userRole == 'admin' || userRole == 'instructor') {
      widgets.add(_buildSidebarItem(
        Icons.school,
        'Students',
        'students',
        navController.currentPage.value,
        () {
          navController.navigateToPage('students');
          if (autoClose) Navigator.of(context).pop();
        },
      ));
    }

    if (userRole == 'admin') {
      widgets.add(_buildSidebarItem(
        Icons.person,
        'Instructors',
        'instructors',
        navController.currentPage.value,
        () {
          navController.navigateToPage('instructors');
          if (autoClose) Navigator.of(context).pop();
        },
      ));

      widgets.add(_buildSidebarItem(
        Icons.people,
        'All Users',
        'users',
        navController.currentPage.value,
        () {
          navController.navigateToPage('users');
          if (autoClose) Navigator.of(context).pop();
        },
      ));
    }

    if (userRole == 'admin' || userRole == 'instructor') {
      widgets.add(_buildSidebarItem(
        Icons.book,
        'Courses',
        'courses',
        navController.currentPage.value,
        () {
          navController.navigateToPage('courses');
          if (autoClose) Navigator.of(context).pop();
        },
      ));

      widgets.add(_buildSidebarItem(
        Icons.schedule,
        'Schedules',
        'schedules',
        navController.currentPage.value,
        () {
          navController.navigateToPage('schedules');
          if (autoClose) Navigator.of(context).pop();
        },
      ));
    }

    if (userRole == 'admin') {
      widgets.add(_buildSidebarItem(
        Icons.directions_car,
        'Fleet',
        'vehicles',
        navController.currentPage.value,
        () {
          navController.navigateToPage('vehicles');
          if (autoClose) Navigator.of(context).pop();
        },
      ));

      widgets.add(_buildSidebarItem(
        Icons.attach_money,
        'Billing',
        'billing',
        navController.currentPage.value,
        () {
          navController.navigateToPage('billing');
          if (autoClose) Navigator.of(context).pop();
        },
      ));

      widgets.add(_buildSidebarItem(
        Icons.receipt,
        'Receipts',
        'receipts',
        navController.currentPage.value,
        () {
          navController.navigateToPage('receipts');
          if (autoClose) Navigator.of(context).pop();
        },
      ));

      // Reports dropdown - EXACT copy of your dropdown logic
      widgets.addAll(_buildReportsDropdown(navController, autoClose));
    }

    // Settings - visible to all
    widgets.add(_buildSidebarItem(
      Icons.settings,
      'Settings',
      'settings',
      navController.currentPage.value,
      () {
        navController.navigateToPage('settings');
        if (autoClose) Navigator.of(context).pop();
      },
    ));

    return widgets;
  }

  // Build reports dropdown - EXACT copy of your dropdown logic
  List<Widget> _buildReportsDropdown(
      NavigationController navController, bool autoClose) {
    List<Widget> widgets = [];
    final isExpanded = navController.isDropdownExpanded('reports');

    // Dropdown header
    widgets.add(Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => navController.toggleDropdown('reports'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.analytics,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Reports',
                    style: TextStyle(
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
    ));

    // Dropdown children
    if (isExpanded) {
      widgets.add(_buildDropdownChild(
        Icons.analytics,
        'Financial Reports',
        'financial_reports',
        navController.currentPage.value,
        () {
          navController.navigateToPage('financial_reports');
          if (autoClose) Navigator.of(context).pop();
        },
      ));

      widgets.add(_buildDropdownChild(
        Icons.people_alt,
        'User Reports',
        'user_reports',
        navController.currentPage.value,
        () {
          navController.navigateToPage('user_reports');
          if (autoClose) Navigator.of(context).pop();
        },
      ));
    }

    return widgets;
  }

  // Build dropdown child item - EXACT copy
  Widget _buildDropdownChild(
    IconData icon,
    String title,
    String pageKey,
    String currentPage,
    VoidCallback onTap,
  ) {
    final isActive = currentPage == pageKey;

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 8, top: 2, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? Colors.white24 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.white60,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
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

  // Build regular sidebar item - EXACT copy
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

  // Content area - EXACT copy
  Widget _buildContentArea(NavigationController navController) {
    return Obx(() {
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
              Text('You do not have permission to access this page.'),
            ],
          ),
        );
      }

      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[100],
        child: _getCurrentPageWidget(currentPage),
      );
    });
  }

  // Get current page widget - EXACT copy
  Widget _getCurrentPageWidget(String pageKey) {
    switch (pageKey) {
      case 'dashboard':
        return const FixedDashboardContent();
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
        return const FixedDashboardContent();
    }
  }
}
