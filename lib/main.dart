import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/sync_controller.dart';
import 'package:driving/routes/app_routes.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/controllers/school_selection_controller.dart'; // Add this import
import 'package:driving/services/api_service.dart';
import 'package:driving/services/app_bindings.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/app_initialization.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/database_migration.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/school_api_service.dart'; // Add this import
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only use FFI on desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  print('🚀 === STARTING DRIVING SCHOOL APP ===');

  // Initialize database
  final db = await DatabaseHelper.instance.database;
  await DatabaseMigration.runMigrations(db);
  await AppInitialization.initialize();

  // Initialize core services (simplified)
  await _initializeCoreServices();

  print('✅ === APP INITIALIZATION COMPLETED ===');

  runApp(DrivingSchoolApp());
}

Future<void> _initializeCoreServices() async {
  try {
    print('⚙️ Initializing core services...');

    // Initialize API Service configuration
    _configureApiService();

    // Initialize PIN Controller early
    if (!Get.isRegistered<PinController>()) {
      Get.put<PinController>(PinController(), permanent: true);
      print('✅ PinController initialized');
    }

    // Initialize Settings Controller (but skip school config)
    if (!Get.isRegistered<SettingsController>()) {
      Get.put<SettingsController>(SettingsController(), permanent: true);

      final settingsController = Get.find<SettingsController>();
      await settingsController.loadSettingsFromDatabase();
      print('✅ SettingsController initialized');
    }

    // Initialize Auth Controller
    if (!Get.isRegistered<AuthController>()) {
      Get.put<AuthController>(AuthController(), permanent: true);
      print('✅ AuthController initialized');
    }

    if (!Get.isRegistered<NavigationController>()) {
      Get.put<NavigationController>(NavigationController(), permanent: true);
      print('✅ NavigationController initialized');
    }

    // Initialize Sync Controller (before Auth)
    if (!Get.isRegistered<SyncController>()) {
      Get.put<SyncController>(SyncController(), permanent: true);
      print('✅ Sync Controller initialized');
    }

    // Initialize School Config Service
    if (!Get.isRegistered<SchoolConfigService>()) {
      Get.put<SchoolConfigService>(SchoolConfigService(), permanent: true);
      print('✅ SchoolConfigService initialized');
    }

    // Set up auth-sync integration
    _setupAuthSyncIntegration();

    print('✅ Core services initialization completed');
  } catch (e) {
    print('❌ Core services initialization failed: $e');
    // Continue anyway - app should still work with basic functionality
  }
}

void _configureApiService() {
  // Configure your API base URL here
  // You should replace this with your actual Laravel API URL
  const String apiBaseUrl = 'http://192.168.9.103:8000/api';

  // Set up API configuration
  ApiService.configure(baseUrl: apiBaseUrl);

  print('✅ API Service configured with base URL: $apiBaseUrl');
}

void _setupAuthSyncIntegration() {
  try {
    final authController = Get.find<AuthController>();
    final syncController = Get.find<SyncController>();

    // Listen to auth state changes
    ever(authController.isLoggedIn, (bool isLoggedIn) {
      if (isLoggedIn) {
        print('🔄 User logged in - sync will use existing API token');

        // Token is already set by ApiService.login()
        // Start sync after login
        Future.delayed(Duration(seconds: 2), () {
          syncController.performInitialSync();
        });
      } else {
        print('🔄 User logged out - clearing sync...');
        syncController.stopSync();
      }
    });

    print('✅ Auth-Sync integration configured');
  } catch (e) {
    print('❌ Auth-Sync integration failed: $e');
  }
}

/// Driving School App
class DrivingSchoolApp extends StatelessWidget {
  const DrivingSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Driving School Management',

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
  @override
  void initState() {
    super.initState();
    _determineInitialRoute();
  }

  Future<void> _determineInitialRoute() async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      print('🔍 === DETERMINING INITIAL ROUTE - PIN AFTER SCHOOL SETUP ===');
      await Future.delayed(const Duration(milliseconds: 300));

      final settingsController = Get.find<SettingsController>();
      final pinController = Get.find<PinController>();
      final authController = Get.find<AuthController>();

      String initialRoute;

      // STEP 1: Check if this is completely first run (no school setup)
      final isFirstRun = await SchoolSelectionController.isFirstRun();
      final isSchoolConfigured = settingsController.isBusinessInfoComplete();

      if (isFirstRun || !isSchoolConfigured) {
        print('🏫 First time setup - need school selection');
        initialRoute = '/school-selection';
      }
      // STEP 2: Check if user has PIN setup (after school setup)
      else if (pinController.isPinSet.value &&
          pinController.isPinEnabled.value) {
        print('🔐 PIN is set - using PIN authentication');
        if (pinController.isLocked.value) {
          print('🔒 PIN is locked - redirect to login');
          initialRoute = '/login';
        } else {
          print('📱 Redirecting to PIN login');
          initialRoute = '/pin-login';
        }
      }
      // STEP 3: Check if user is logged in but no PIN setup (after school join/registration)
      else if (authController.isLoggedIn.value &&
          !pinController.isPinSet.value) {
        print('👤 User logged in after school setup - redirect to PIN setup');
        initialRoute = '/pin-setup';
      }
      // STEP 4: No authentication - show login (shouldn't happen after school setup)
      else {
        print('🔑 No authentication - showing login');
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

  // Add this flag as a class member
  bool _isNavigating = false;

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
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRouteChange('PUSH', route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRouteChange('POP', route);
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
