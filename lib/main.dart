import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/subscription_controller.dart';
import 'package:driving/routes/app_routes.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/subscription_cache.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/services/app_bindings.dart';
import 'package:driving/services/api_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/database_migration.dart';
import 'package:driving/services/app_initialization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:driving/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _initializeDatabaseFactory();

  await _initializeCoreDependencies();
  Get.put(SubscriptionController());

  await AppBindings().dependencies();

  runApp(const DrivingSchoolApp());
}

/// Initialize database factory for different platforms
void _initializeDatabaseFactory() {
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SubscriptionCache.initializeTable();
    }
  } catch (e) {
    debugPrint('Database factory initialization failed: $e');
  }
}

Future<void> _initializeCoreDependencies() async {
  try {
    // Configure API service
    _configureApiService();

    // Initialize database and run migrations
    await _initializeDatabaseAndMigrations();
  } catch (e) {
    debugPrint('Core services initialization failed: $e');
  }
}

/// Initialize database and run all migrations
Future<void> _initializeDatabaseAndMigrations() async {
  try {
    final db = await DatabaseHelper.instance.database;
    await DatabaseMigration.runMigrations(db);
    await AppInitialization.initialize();
    await DatabaseHelper.instance.migratePrinterSettings();
  } catch (e) {
    debugPrint('Database/migration initialization failed: $e');
    // Don't throw - let app continue in degraded mode
  }
}

void _configureApiService() {
  // Configure your API base URL here
  const String apiBaseUrl = 'https://drivesyncpro.co.zw/api';

  // Set up API configuration
  ApiService.configure(baseUrl: apiBaseUrl);
}

/// Driving School App
class DrivingSchoolApp extends StatelessWidget {
  const DrivingSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Obx(() {
      final themeMode = AppTheme.mapTheme(settingsController.theme.value);

      return GetMaterialApp(
        title: 'DriveSync Pro',
        theme: AppTheme.theme(isDark: false),
        darkTheme: AppTheme.theme(isDark: true),
        themeMode: themeMode,
        initialRoute: AppRoutes.initial,
        getPages: AppRoutes.routes,
        debugShowCheckedModeBanner: false,
        unknownRoute: GetPage(
          name: '/notfound',
          page: () => const LoginScreen(),
        ),
        home: const AuthenticationWrapper(),
      );
    });
  }
}

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({Key? key}) : super(key: key);

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _determineInitialRoute();
  }

  Future<void> _determineInitialRoute() async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final settingsController = Get.find<SettingsController>();
      final pinController = Get.find<PinController>();
      final authController = Get.find<AuthController>();

      await settingsController.loadSettingsFromDatabase();
      await pinController.isPinEnabled();

      String initialRoute;

      // CRITICAL FIX: Check if users exist FIRST
      final usersExist = await _checkIfUsersExist();

      // Only use PIN login if:
      // 1. Users exist in database (not first run)
      // 2. PIN is set and enabled
      // 3. User was previously verified
      if (usersExist &&
          pinController.isPinSet.value &&
          pinController.isPinEnabled.value &&
          await pinController.isUserVerified()) {
        if (pinController.isLocked.value) {
          initialRoute = '/login';
        } else {
          initialRoute = '/pin-login';
        }
      }
      // User logged in but PIN not set (optional setup)
      else if (authController.isLoggedIn.value &&
          !pinController.isPinSet.value) {
        initialRoute = '/main';
      }
      // Users exist locally - show login
      else if (usersExist) {
        initialRoute = '/login';
      }
      // First time - show login
      else {
        initialRoute = '/login';
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(initialRoute);
      });
    } catch (e) {
      debugPrint('Error determining route: $e');
      Get.offAllNamed('/login');
    } finally {
      _isNavigating = false;
    }
  }

  /// Check if any users exist in database
  Future<bool> _checkIfUsersExist() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final users = await db.query('users', limit: 1);
      return users.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking users: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class MultiTenantRouteObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRouteChange('POP', route);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRouteChange('PUSH', route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logRouteChange('REPLACE', newRoute);
    }
  }

  void _logRouteChange(String action, Route<dynamic> route) {
    try {
      String? routeName = route.settings.name;
      if (routeName != null) {
        debugPrint('Route $action: $routeName');

        // Log with school context if available
        if (Get.isRegistered<SchoolConfigService>()) {
          final schoolConfig = Get.find<SchoolConfigService>();
          if (schoolConfig.isValidConfiguration()) {
            debugPrint(
              'School: ${schoolConfig.schoolName.value} (${schoolConfig.schoolId.value})',
            );
          }
        }
      }
    } catch (e) {
      // Ignore errors in logging
    }
  }
}
