// lib/main.dart - FIXED VERSION with proper database initialization
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/school_selection_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/routes/app_routes.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/services/app_bindings.dart';
import 'package:driving/services/api_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/database_migration.dart';
import 'package:driving/services/app_initialization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 === STARTING DRIVING SCHOOL APP ===');

  // STEP 1: Initialize database factory FIRST (critical for desktop platforms)
  _initializeDatabaseFactory();

  // STEP 2: Initialize core dependencies
  await _initializeCoreDependencies();

  // STEP 3: Initialize app bindings (which includes all controllers and sync)
  await AppBindings().dependencies();

  print('✅ === APP INITIALIZATION COMPLETED ===');
  runApp(const DrivingSchoolApp());
}

/// Initialize database factory for different platforms
void _initializeDatabaseFactory() {
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      print('✅ Database factory initialized for desktop platform');
    } else {
      print('✅ Using default database factory for mobile platform');
    }
  } catch (e) {
    print('❌ Database factory initialization failed: $e');
    print('⚠️ App may not work properly on this platform');
  }
}

Future<void> _initializeCoreDependencies() async {
  print('🚀 Initializing core dependencies...');

  try {
    // Configure API service
    _configureApiService();

    // Initialize database and run migrations
    await _initializeDatabaseAndMigrations();

    print('✅ Core services initialization completed');
  } catch (e) {
    print('❌ Core services initialization failed: $e');
    print('⚠️ App will continue with limited functionality');
  }
}

/// Initialize database and run all migrations
Future<void> _initializeDatabaseAndMigrations() async {
  try {
    print('🗄️ Initializing database and running migrations...');

    final db = await DatabaseHelper.instance.database;
    await DatabaseMigration.runMigrations(db);
    await AppInitialization.initialize();

    print('✅ Database and migrations completed successfully');
  } catch (e) {
    print('❌ Database/migration initialization failed: $e');
    print('⚠️ App will continue but some features may not work');
    // Don't throw - let app continue in degraded mode
  }
}

void _configureApiService() {
  // Configure your API base URL here
  // You should replace this with your actual Laravel API URL
  const String apiBaseUrl = 'https://driving.fonpos.co.zw/api';

  // Set up API configuration
  ApiService.configure(baseUrl: apiBaseUrl);

  print('✅ API Service configured with base URL: $apiBaseUrl');
}

/// Driving School App
class DrivingSchoolApp extends StatelessWidget {
  const DrivingSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'DriveSync Pro',

      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Use protected routes with middleware
      getPages: AppRoutes.routes,
      // Use AuthenticationWrapper to determine initial route with school selection
      home: const AuthenticationWrapper(),

      debugShowCheckedModeBanner: false,

      // Handle unknown routes
      unknownRoute: GetPage(name: '/notfound', page: () => const LoginScreen()),
    );
  }
}

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({Key? key}) : super(key: key);

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  // Add this flag as a class member
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
      print('🔍 === DETERMINING INITIAL ROUTE - TABLE CONFLICT FIX ===');
      await Future.delayed(const Duration(milliseconds: 300));

      final settingsController = Get.find<SettingsController>();
      final pinController = Get.find<PinController>();
      final authController = Get.find<AuthController>();

      // CRITICAL: Load settings first to check both tables
      await settingsController.loadSettingsFromDatabase();
      await pinController.isPinEnabled();

      String initialRoute;

      // STEP 1: Check if business/school setup is complete (checks both tables now)
      final isSchoolSetupComplete = settingsController.isBusinessInfoComplete();
      final isFirstRun = await SchoolSelectionController.isFirstRun();

      print('🏫 School setup complete: $isSchoolSetupComplete');
      print('🏫 First run: $isFirstRun');
      print(
          '📊 Settings state: ${settingsController.getBusinessInfoSummary()}');

      if (!isSchoolSetupComplete || isFirstRun) {
        print('🏫 School setup needed - redirect to school selection');
        initialRoute = '/school-selection';
      }
      // STEP 2: Check PIN authentication
      else if (pinController.isPinSet.value &&
          pinController.isPinEnabled.value &&
          await pinController.isUserVerified()) {
        print('🔐 PIN authentication available');

        if (pinController.isLocked.value) {
          print('🔒 PIN is locked - redirect to login');
          initialRoute = '/login';
        } else {
          print('📱 Redirecting to PIN login');
          initialRoute = '/pin-login';
        }
      }
      // STEP 3: Check if user logged in but PIN not set
      else if (authController.isLoggedIn.value &&
          !pinController.isPinSet.value) {
        print('👤 User logged in, setting up PIN');
        initialRoute = '/pin-setup';
      }
      // STEP 4: Check if users exist
      else if (await _checkIfUsersExist()) {
        print('👥 Users exist - redirect to login');
        initialRoute = '/login';
      }
      // STEP 5: Fallback
      else {
        print('🔑 Fallback to login');
        initialRoute = '/login';
      }

      print('🎯 Initial route determined: $initialRoute');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(initialRoute);
      });
    } catch (e) {
      print('❌ Error determining route: $e');
      Get.offAllNamed('/login');
    } finally {
      _isNavigating = false;
    }
  }

  Future<bool> _checkSchoolConfiguration() async {
    try {
      // Check if school data exists in database
      final db = await DatabaseHelper.instance.database;

      // Check schools table
      final schoolResult = await db.query('schools', limit: 1);

      // Check settings table for school configuration
      final settingsResult = await db.query(
        'settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: ['business_name', 'school_id', 'enable_multi_tenant'],
      );

      // School is configured if:
      // 1. At least one school exists in schools table
      // 2. Business name is set
      // 3. School ID is set
      bool hasSchoolData = schoolResult.isNotEmpty;
      bool hasBusinessName = settingsResult.any((row) =>
          row['key'] == 'business_name' &&
          row['value'] != null &&
          row['value'].toString().trim().isNotEmpty);
      bool hasSchoolId = settingsResult.any((row) =>
          row['key'] == 'school_id' &&
          row['value'] != null &&
          row['value'].toString().trim().isNotEmpty);

      bool isConfigured = hasSchoolData && hasBusinessName && hasSchoolId;

      print('🏫 School configuration check:');
      print('   Has school data: $hasSchoolData');
      print('   Has business name: $hasBusinessName');
      print('   Has school ID: $hasSchoolId');
      print('   Is configured: $isConfigured');

      return isConfigured;
    } catch (e) {
      print('❌ Error checking school configuration: $e');
      return false;
    }
  }

  /// Check if user has stored authentication
  Future<bool> _checkStoredAuthentication() async {
    try {
      // Check if there are any users in the database
      final db = await DatabaseHelper.instance.database;
      final users = await db.query('users', limit: 1);

      if (users.isEmpty) {
        print('👥 No users found in database');
        return false;
      }

      // Check if auth controller has remembered login
      final authController = Get.find<AuthController>();

      // Load remembered email if exists
      await authController.loadRememberedEmail();

      bool hasRememberedEmail = authController.userEmail.value.isNotEmpty;

      print('🔐 Authentication check:');
      print('   Has users: ${users.isNotEmpty}');
      print('   Has remembered email: $hasRememberedEmail');

      // If we have users and potentially remembered login, consider as having auth
      return users.isNotEmpty;
    } catch (e) {
      print('❌ Error checking stored authentication: $e');
      return false;
    }
  }

  // Helper method to check if users exist
  Future<bool> _checkIfUsersExist() async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      return users.isNotEmpty;
    } catch (e) {
      print('⚠️ Error checking users: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade600,
              Colors.blue.shade400,
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Icon(Icons.school, size: 80, color: Colors.white),
              SizedBox(height: 24),

              // Title
              Text(
                'DRIVING SCHOOL',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),

              Text(
                'Management System',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              SizedBox(height: 40),

              // Loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),

              Text(
                'Initializing...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
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
        print('🧭 Route $action: $routeName');

        // Log with school context if available
        if (Get.isRegistered<SchoolConfigService>()) {
          final schoolConfig = Get.find<SchoolConfigService>();
          if (schoolConfig.isValidConfiguration()) {
            print(
              '   School: ${schoolConfig.schoolName.value} (${schoolConfig.schoolId.value})',
            );
          }
        }
      }
    } catch (e) {
      // Ignore errors in logging
    }
  }
}
