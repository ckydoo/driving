// lib/widgets/responsive_main_layout.dart - EXACT UX Structure, Just Responsive
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/sync_controller.dart';
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
import 'package:driving/settings/settings_screen.dart';
import 'package:driving/widgets/school_info_widget.dart';
import 'package:driving/widgets/sync_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  DateTime? _lastBackPressed;
  static const Duration _exitTimeLimit = Duration(seconds: 2);

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

    return WillPopScope(
      onWillPop: () => _handleBackButton(context),
      child: Scaffold(
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
      ),
    );
  }

  // Add this method to handle the double tap exit functionality
  Future<bool> _handleBackButton(BuildContext context) async {
    final now = DateTime.now();

    // Check if this is the first back press or if too much time has passed
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > _exitTimeLimit) {
      // First back press - show toast and record time
      _lastBackPressed = now;

      // Show toast message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Press back again to exit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey.shade800,
          duration: _exitTimeLimit,
          behavior: SnackBarBehavior.fixed,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Don't exit the app yet
      return false;
    } else {
      // Second back press within time limit - exit the app
      SystemNavigator.pop();
      return true;
    }
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
              // Header with school name and user profile
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // School name
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

                    // User Profile Section - NEW
                    Obx(() {
                      final user = authController.currentUser.value;
                      if (user == null) {
                        return const SizedBox.shrink();
                      }

                      final userName = user.fname ?? user.email ?? 'User';

                      final userRole = user.role ?? 'User';

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop(); // Close drawer
                          Get.to(ProfileScreen());
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // User Avatar
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue.shade600,
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // User Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // User Name
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    const SizedBox(height: 2),

                                    // User Role
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade600,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        userRole.toUpperCase(),
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

                              // Arrow indicator
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white60,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Navigation items
              Expanded(
                child: SingleChildScrollView(
                  child: Obx(() => Column(
                        children: _buildNavigationItems(navController,
                            autoClose: true),
                      )),
                ),
              ),

              // Logout button
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
          height: 80, // Keep your existing height
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Hamburger menu - keep your existing styling
              Container(
                width: 56,
                height: 56,
                child: IconButton(
                  icon: const Icon(Icons.menu, size: 35),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  tooltip: 'Menu',
                  splashRadius: 28,
                ),
              ),

              // Page title - keep your existing styling
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Obx(() => Text(
                        navController.getCurrentPageTitle(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )),
                ),
              ),

              // NEW: Simple Sync Button - Tap to sync
              Container(
                width: 56,
                height: 56,
                child: GetX<SyncController>(
                  builder: (syncController) => IconButton(
                    icon: Icon(
                      syncController.getSyncStatusIcon(),
                      size: 25,
                      color: syncController.getSyncStatusColor(),
                    ),
                    tooltip: syncController.isSyncing.value
                        ? 'Syncing...'
                        : 'Tap to sync',
                    onPressed: syncController.isSyncing.value
                        ? null
                        : () => syncController.performSmartSync(),
                    splashRadius: 24,
                  ),
                ),
              ),

              // NEW: POS Button
              Container(
                width: 56,
                height: 56,
                child: IconButton(
                  icon: const Icon(Icons.payment, size: 25),
                  tooltip: 'POS',
                  onPressed: () => navController.navigateToPage('pos'),
                  splashRadius: 24,
                ),
              ),

              // Search button - keep your existing styling
              Container(
                width: 56,
                height: 56,
                child: IconButton(
                  icon: const Icon(Icons.search, size: 35),
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

  Widget _buildDesktopTopBar(NavigationController navController) {
    final AuthController authController = Get.find<AuthController>();

    return Container(
      height: 64,
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

          // SIMPLE FIX: Just use the compact sync widget directly
          GetX<SyncController>(
            builder: (syncController) => Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: syncController.getSyncStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: syncController.getSyncStatusColor().withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    syncController.getSyncStatusIcon(),
                    color: syncController.getSyncStatusColor(),
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    syncController.syncStatus.value,
                    style: TextStyle(
                      color: syncController.getSyncStatusColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => syncController.performSmartSync(),
                    child: Icon(
                      Icons.refresh,
                      color: syncController.getSyncStatusColor(),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: 8),

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

          // User menu dropdown
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Get.to(() => ProfileScreen());
                  break;
                case 'settings':
                  navController.navigateToPage('settings');
                  break;
                case 'logout':
                  authController.signOut();
                  break;
              }
            },
            icon: Obx(() => CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    authController.currentUserName
                            .substring(0, 1)
                            .toUpperCase() ??
                        'U',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                )),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(width: 16),
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

// 1. Replace your _performSafeLogout method:
  Future<void> _performSafeLogout() async {
    // Simple confirmation dialog without Obx
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
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
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to logout?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Any unsaved changes will be lost.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Cancel Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Logout Button - NO OBX HERE
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
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
            ),
          ],
        );
      },
    );

    // If user confirmed logout
    if (confirmed == true) {
      await _executeSimpleLogout();
    }
  }

  // 2. Replace your logout execution method:
  Future<void> _executeSimpleLogout() async {
    try {
      // Show simple loading dialog without Obx
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Logging out...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      );

      // Wait a moment for UI to update
      await Future.delayed(const Duration(milliseconds: 500));

      // Perform the actual logout
      final authController = Get.find<AuthController>();
      await authController.signOut();

      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Navigate to login immediately
      Get.offAllNamed('/login');

      // Show success message after navigation
      Future.delayed(const Duration(milliseconds: 300), () {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
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
      });
    } catch (e) {
      print('❌ Error during logout: $e');

      // Close loading dialog on error
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Force navigation to login even on error
      Get.offAllNamed('/login');

      // Show error message after navigation
      Future.delayed(const Duration(milliseconds: 300), () {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Logout Complete',
          'You have been logged out',
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade800,
          icon: Icon(
            Icons.warning,
            color: Colors.orange.shade600,
          ),
          duration: const Duration(seconds: 3),
        );
      });
    }
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
    case 'reports':
      return FinancialReportsScreen();
    case 'course_reports':
      return const CourseReportsScreen();
    case 'alumni':
      return const AlumniScreen();
    default:
      return const FixedDashboardContent();
  }
}
