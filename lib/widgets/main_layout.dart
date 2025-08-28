// lib/widgets/responsive_main_layout.dart - EXACT UX Structure, Just Responsive
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/dashboard.dart';
import 'package:driving/models/user.dart';
import 'package:driving/overview/quick_search_screen.dart';
import 'package:driving/reports/course.dart';
import 'package:driving/screens/billing/billing_screen.dart';
import 'package:driving/screens/course/course_screen.dart';
import 'package:driving/screens/fleet/fleet_screen.dart';
import 'package:driving/screens/profile/profile_screen.dart';
import 'package:driving/screens/receipts/receipt_management_screen.dart';
import 'package:driving/screens/reports/financial_reports_screen.dart';
import 'package:driving/screens/reports/users_reports_screen.dart';
import 'package:driving/screens/schedule/schedule_screen.dart';
import 'package:driving/screens/users/alumni_screen.dart';
import 'package:driving/screens/users/enhanced_users_screen.dart';
import 'package:driving/screens/users/graduation_screen.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/settings/settings_screen.dart';
import 'package:driving/widgets/school_info_widget.dart';
import 'package:driving/widgets/sync_status_widget.dart';
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        )),
                    const SizedBox(height: 8),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              // Navigation items
              Expanded(
                child: SingleChildScrollView(
                  child: Obx(() => Column(
                        children: _buildNavigationItems(navController,
                            autoClose: true),
                      )),
                ),
              ),
              // UPDATED LOGOUT BUTTON WITH SAFE LOGOUT:
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close drawer first
                      _performSafeLogout(); // USE SAFE LOGOUT METHOD
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
                Text(
                  settingsController.businessPhone.value.isNotEmpty
                      ? settingsController.businessPhone.value
                      : 'Management System',
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
                onPressed: _performSafeLogout, // USE SAFE LOGOUT METHOD
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
// Update your _buildMobileTopBar method in lib/widgets/main_layout.dart

  Widget _buildMobileTopBar(NavigationController navController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 80, // Increased height for mobile
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Hamburger menu - bigger touch target
              Container(
                width: 56,
                height: 56,
                child: IconButton(
                  icon: const Icon(Icons.menu, size: 35), // Bigger icon
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  tooltip: 'Menu',
                  splashRadius: 28,
                ),
              ),
              // Page title with better constraints
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Obx(() => Text(
                        navController.getCurrentPageTitle(),
                        style: const TextStyle(
                          fontSize: 20, // Increased font size
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )),
                ),
              ),

              // SYNC ICON - NEW ADDITION
              const SyncIconWidget(),
              // POS button
              Container(
                width: 56,
                height: 56,
                child: IconButton(
                  onPressed: () => navController.navigateToPage('pos'),
                  icon: const Icon(Icons.payment, size: 35), // Bigger icon
                  tooltip: 'POS',
                  splashRadius: 24,
                ),
              ),
              // Search button
              Container(
                width: 56,
                height: 56,
                child: IconButton(
                  icon: const Icon(Icons.search, size: 35), // Bigger icon
                  tooltip: 'Search',
                  onPressed: () => navController.navigateToPage('quick_search'),
                  splashRadius: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Update your _buildDesktopTopBar method in lib/widgets/main_layout.dart

  Widget _buildDesktopTopBar(NavigationController navController) {
    return Container(
      height: 64, // Slightly taller for desktop
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
          // SYNC STATUS WIDGET - NEW ADDITION
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: SyncStatusWidget(
              showText: true, // Show text on desktop for more info
              showTooltip: true,
            ),
          ),
          // POS button
          IconButton(
            onPressed: () {
              navController.navigateToPage('pos');
            },
            icon: const Icon(Icons.payment),
            tooltip: 'POS',
          ),
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              navController.navigateToPage('quick_search');
            },
          ),

          // User menu dropdown (your existing code)
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Get.to(ProfileScreen());
                  break;
                case 'settings':
                  navController.navigateToPage('settings');
                  break;
                case 'logout':
                  _performSafeLogout(); // Your existing logout method
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
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue,
                    child: Obx(() {
                      final AuthController authController =
                          Get.find<AuthController>();
                      final user = authController.currentUser.value;
                      return Text(
                        user?.fname?.substring(0, 1).toUpperCase() ?? 'U',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_drop_down),
                ],
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
    // SAFE USER ROLE ACCESS:
    final user = navController.authController.currentUser.value;
    if (user == null || !navController.authController.isLoggedIn.value) {
      return []; // Return empty list if no user
    }
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
        Icons.people_alt,
        'Alumni',
        'alumni',
        navController.currentPage.value,
        () {
          navController.navigateToPage('alumni');
          if (autoClose) Navigator.of(context).pop();
        },
      ));

      widgets.addAll(_buildFinancesDropdown(navController, autoClose));

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

  List<Widget> _buildFinancesDropdown(
      NavigationController navController, bool autoClose) {
    List<Widget> widgets = [];
    final isExpanded = navController.isDropdownExpanded('financial_group');

    // Dropdown header
    widgets.add(Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => navController.toggleDropdown('financial_group'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payment_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Finance',
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
        'POS',
        'pos',
        navController.currentPage.value,
        () {
          navController.navigateToPage('pos');
          if (autoClose) Navigator.of(context).pop();
        },
      ));

      widgets.add(_buildDropdownChild(
        Icons.people_alt,
        'Receipts',
        'receipts',
        navController.currentPage.value,
        () {
          navController.navigateToPage('receipts');
          if (autoClose) Navigator.of(context).pop();
        },
      ));
      widgets.add(_buildDropdownChild(
        Icons.people_alt,
        'Invoices',
        'billing',
        navController.currentPage.value,
        () {
          navController.navigateToPage('billing');
          if (autoClose) Navigator.of(context).pop();
        },
      ));
    }

    return widgets;
  }

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
        Icons.balance,
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
        'Users Reports',
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

// 5. ADD THIS NEW SAFE LOGOUT METHOD TO YOUR _ResponsiveMainLayoutState CLASS:
  Future<void> _performSafeLogout() async {
    // Show the enhanced confirmation dialog first
    _showEnhancedLogoutDialog();
  }

  // ENHANCED LOGOUT CONFIRMATION DIALOG
  void _showEnhancedLogoutDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout,
              color: Colors.red.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirm Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to logout?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Internet connectivity warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.wifi_off,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Internet Required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You may need internet connection to log back in to your account.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Dynamic sync status info
            _buildSyncStatusWarning(),
          ],
        ),
        actions: [
          // Cancel Button
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Logout Button with dynamic state
          _buildLogoutButton(),
        ],
      ),
      barrierDismissible: false, // Prevent accidental dismissal
    );
  }

  // BUILD SYNC STATUS WARNING WIDGET
  Widget _buildSyncStatusWarning() {
    try {
      final syncService = Get.find<FixedLocalFirstSyncService>();

      return Obx(() {
        final isSyncing = syncService.isSyncing.value;
        final isOnline = syncService.isOnline.value;

        if (isSyncing) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(
                    color: Colors.blue.shade200,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Data is currently syncing...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else if (!isOnline) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(
                    color: Colors.red.shade200,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      color: Colors.red.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Currently offline - some data may not be synced.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      });
    } catch (e) {
      // If sync service not available, just return empty widget
      return const SizedBox.shrink();
    }
  }

  // BUILD LOGOUT BUTTON WITH DYNAMIC STATE
  Widget _buildLogoutButton() {
    try {
      final syncService = Get.find<FixedLocalFirstSyncService>();

      return Obx(() {
        final isSyncing = syncService.isSyncing.value;

        return ElevatedButton.icon(
          onPressed: isSyncing
              ? null // Disable if syncing
              : () async {
                  Get.back(); // Close dialog
                  await _executeEnhancedLogout();
                },
          icon: isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.logout),
          label: Text(isSyncing ? 'Syncing...' : 'Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isSyncing ? Colors.grey.shade400 : Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      });
    } catch (e) {
      // If sync service not available, show simple button
      return ElevatedButton.icon(
        onPressed: () async {
          Get.back(); // Close dialog
          await _executeEnhancedLogout();
        },
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  // ENHANCED LOGOUT EXECUTION WITH SYNC HANDLING
  Future<void> _executeEnhancedLogout() async {
    try {
      final authController = Get.find<AuthController>();

      // Show loading dialog
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Logging out...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Finalizing data sync',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Step 2: Perform the actual logout
      await authController.signOut();

      // Step 3: Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      // Step 4: Show success message
      Get.snackbar(
        'Logged Out',
        'You have been successfully logged out',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        icon: Icon(
          Icons.check_circle,
          color: Colors.green.shade600,
        ),
        duration: const Duration(seconds: 2),
      );

      // Step 5: Navigate to login
      Get.offAllNamed('/login');
    } catch (e) {
      print('❌ Error during logout: $e');

      // Close loading dialog on error
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      // Show error message but still try to logout
      Get.snackbar(
        'Logout Warning',
        'There was an issue during logout, but you have been signed out.',
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade800,
        icon: Icon(
          Icons.warning,
          color: Colors.orange.shade600,
        ),
        duration: const Duration(seconds: 4),
      );

      // Force navigation to login even on error
      try {
        final authController = Get.find<AuthController>();
        await authController.signOut();
      } catch (_) {}

      Get.offAllNamed('/login');
    }
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

      case 'alumni':
        return const AlumniScreen();
      default:
        return const FixedDashboardContent();
    }
  }
}
