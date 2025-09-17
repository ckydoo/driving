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

  // Initialize demo data for development
  await _initializeDemoData();

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

/// Initialize demo data for development/testing
Future<void> _initializeDemoData() async {
  try {
    final isFirstRun = await SchoolSelectionController.isFirstRun();
    final hasExistingData = await _hasDemoSchools();

    if (isFirstRun && !hasExistingData) {
      print('🎯 First run detected - creating demo data...');
      await _createDemoSchools();
    } else if (hasExistingData) {
      print('📚 Demo data already exists');
      _printDemoCredentials(); // Show credentials in console
    }
  } catch (e) {
    print('❌ Error initializing demo data: $e');
  }
}

/// Check if demo schools exist
Future<bool> _hasDemoSchools() async {
  try {
    final db = await DatabaseHelper.instance.database;
    final schools = await db.query('schools', limit: 1);
    return schools.isNotEmpty;
  } catch (e) {
    print('❌ Error checking demo schools: $e');
    return false;
  }
}

/// Create demo schools for testing
Future<void> _createDemoSchools() async {
  try {
    final db = await DatabaseHelper.instance.database;

    final sampleSchools = [
      {
        'id': 'school_001',
        'name': 'Metro Driving School',
        'address': '123 Main Street, Harare',
        'location': 'Harare, Zimbabwe',
        'phone': '+263 77 123 4567',
        'email': 'info@metrodriving.co.zw',
        'website': 'www.metrodriving.co.zw',
        'start_time': '08:00',
        'end_time': '18:00',
        'operating_days': 'Mon,Tue,Wed,Thu,Fri,Sat',
        'invitation_code': 'METRO2024',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'school_002',
        'name': 'Safe Drive Academy',
        'address': '456 Oak Avenue, Bulawayo',
        'location': 'Bulawayo, Zimbabwe',
        'phone': '+263 77 987 6543',
        'email': 'contact@safedrive.co.zw',
        'website': 'www.safedrive.co.zw',
        'start_time': '09:00',
        'end_time': '17:00',
        'operating_days': 'Mon,Tue,Wed,Thu,Fri',
        'invitation_code': 'SAFE2024',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final school in sampleSchools) {
      await db.insert(
        'schools',
        school,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Create demo users
    final sampleUsers = [
      {
        'id': 'user_001',
        'school_id': 'school_001',
        'email': 'admin@metro.com',
        'password': 'admin123',
        'role': 'admin',
        'fname': 'John',
        'lname': 'Smith',
        'phone': '+263 77 111 0001',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'user_002',
        'school_id': 'school_002',
        'email': 'admin@safedrive.com',
        'password': 'admin123',
        'role': 'admin',
        'fname': 'Sarah',
        'lname': 'Johnson',
        'phone': '+263 77 222 0001',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      },
      // Universal demo account
      {
        'id': 'user_demo',
        'school_id': 'school_001',
        'email': 'demo@school.com',
        'password': 'demo123',
        'role': 'admin',
        'fname': 'Demo',
        'lname': 'User',
        'phone': '+263 77 000 0000',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final user in sampleUsers) {
      await db.insert(
        'users',
        user,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    print('✅ Demo schools and users created');
    _printDemoCredentials();
  } catch (e) {
    print('❌ Error creating demo schools: $e');
  }
}

/// Print demo credentials for testing
void _printDemoCredentials() {
  print('\n🔑 ===== DEMO LOGIN CREDENTIALS =====');
  print('School: "Metro Driving School" or "METRO2024"');
  print('Email: admin@metro.com | Password: admin123');
  print('');
  print('School: "Safe Drive Academy" or "SAFE2024"');
  print('Email: admin@safedrive.com | Password: admin123');
  print('');
  print('Universal Demo Account:');
  print('Email: demo@school.com | Password: demo123');
  print('=====================================\n');
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
    // Prevent multiple calls
    if (_isNavigating) {
      print('🔄 Navigation already in progress, skipping...');
      return;
    }

    _isNavigating = true;

    try {
      print('🔍 === DETERMINING INITIAL ROUTE WITH SCHOOL SELECTION ===');

      // Wait a bit for controllers to initialize
      await Future.delayed(const Duration(milliseconds: 300));

      // Get required controllers
      final authController = Get.find<SettingsController>();
      final pinController = Get.find<PinController>();

      String initialRoute;

      // Step 1: Check if this is first run or school not configured
      final isFirstRun = await SchoolSelectionController.isFirstRun();
      final isSchoolConfigured = authController.isBusinessInfoComplete();

      if (isFirstRun || !isSchoolConfigured) {
        print(
            '🏫 First run or school not configured - showing school selection');
        initialRoute = '/school-selection';
      } else {
        // Step 2: Check if user is already logged in
        final authCtrl = Get.find<AuthController>();
        if (authCtrl.isLoggedIn.value) {
          print('👤 User already logged in');
          initialRoute = '/main';
        } else {
          // Step 3: Check PIN availability for quick login
          final isUserVerified = await pinController.isUserVerified();
          final shouldUsePinAuth = pinController.shouldUsePinAuth();
          final hasUsers = await _checkIfUsersExist();

          if (isUserVerified && shouldUsePinAuth && hasUsers) {
            print('📱 PIN available - using PIN login');
            initialRoute = '/pin-login';
          } else {
            print('🔐 Going to standard login');
            initialRoute = '/login';
          }
        }
      }

      print('🎯 Initial route determined: $initialRoute');

      // Navigate to the determined route
      if (mounted) {
        Get.offAllNamed(initialRoute);
      }
    } catch (e) {
      debugPrint('❌ Error determining initial route: $e');
      // Always fallback to school selection on error for first-time setup
      if (mounted) {
        Get.offAllNamed('/school-selection');
      }
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
