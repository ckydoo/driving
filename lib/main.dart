// lib/main.dart - FIXED VERSION with proper database initialization
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/school_selection_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/subscription_controller.dart';
import 'package:driving/routes/app_routes.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/subscription_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
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
  // CRITICAL: Initialize Stripe FIRST before anything else
  await _initializeStripe();
  // STEP 1: Initialize database factory FIRST (critical for desktop platforms)
  _initializeDatabaseFactory();

  // STEP 2: Initialize core dependencies
  await _initializeCoreDependencies();
  Get.put(SubscriptionController());
  Stripe.publishableKey =
      "pk_test_your_publishable_key_here"; // Add your Stripe publishable key

  // STEP 3: Initialize app bindings (which includes all controllers and sync)
  await AppBindings().dependencies();

  print('✅ === APP INITIALIZATION COMPLETED ===');
  runApp(const DrivingSchoolApp());
}

/// Initialize Stripe with proper configuration
Future<void> _initializeStripe() async {
  print('💳 Initializing Stripe...');

  try {
    // ============================================
    // STRIPE CONFIGURATION
    // ============================================

    // YOUR STRIPE PUBLISHABLE KEY
    // Replace this with your actual Stripe key
    const stripePublishableKey =
        'pk_test_51SBdNe4IPjryss42NdJPH4l504YGckq7apiZI48usKi0QSRG65E8qEtByVP307sfIJIstrpF3Z17pDjxiz7HoJcK00nwrBuBSx';

    // Validate key exists
    if (stripePublishableKey.isEmpty) {
      print('❌ ERROR: Stripe publishable key is empty!');
      print('❌ Add your key in main.dart line ~45');
      throw Exception('Stripe key not configured');
    }

    // Validate key format
    if (!stripePublishableKey.startsWith('pk_test_') &&
        !stripePublishableKey.startsWith('pk_live_')) {
      print('❌ ERROR: Invalid Stripe key format!');
      print('❌ Key should start with pk_test_ or pk_live_');
      throw Exception('Invalid Stripe key format');
    }

    // Set Stripe publishable key - THIS IS THE CRITICAL LINE
    Stripe.publishableKey = stripePublishableKey;

    // Optional: Set merchant identifier for Apple Pay (iOS only)
    if (Platform.isIOS) {
      Stripe.merchantIdentifier = 'merchant.com.yourdomain.drivesync';
      print('✅ Apple Pay merchant ID set');
    }

    // Log which environment we're using
    if (stripePublishableKey.startsWith('pk_test_')) {
      print('✅ Stripe initialized in TEST mode');
      print('💡 Test cards:');
      print('   - Success: 4242 4242 4242 4242');
      print('   - Decline: 4000 0000 0000 0002');
      print('   - 3D Secure: 4000 0025 0000 3155');
    } else if (stripePublishableKey.startsWith('pk_live_')) {
      print('✅ Stripe initialized in LIVE/PRODUCTION mode');
      print('⚠️  WARNING: Using live Stripe keys!');
    }

    print('✅ Stripe initialization completed successfully');
  } catch (e) {
    print('❌ CRITICAL ERROR: Stripe initialization failed!');
    print('❌ Error: $e');
    print('❌ Subscription features will NOT work!');
    // Don't throw - let app continue but subscriptions won't work
  }
}

/// Initialize database factory for different platforms
void _initializeDatabaseFactory() {
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SubscriptionCache.initializeTable();

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
  const String apiBaseUrl = 'http://192.168.8.172:8000/api';

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
      initialRoute: AppRoutes.initial, // ✅ Use routes system
      getPages: AppRoutes.routes,
      debugShowCheckedModeBanner: false,
      unknownRoute: GetPage(name: '/notfound', page: () => const LoginScreen()),
      home: const AuthenticationWrapper(),

      // Handle unknown routes
    );
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
      print('🔍 === DETERMINING INITIAL ROUTE - COMPLETE FIX ===');
      await Future.delayed(const Duration(milliseconds: 300));

      final settingsController = Get.find<SettingsController>();
      final pinController = Get.find<PinController>();
      final authController = Get.find<AuthController>();

      // CRITICAL: Load settings first to check both tables
      await settingsController.loadSettingsFromDatabase();
      await pinController.isPinEnabled();

      String initialRoute;

      // STEP 1: Check if business/school setup is complete
      final isSchoolSetupComplete = await _checkSchoolConfigurationFixed();

      print('🏫 School setup complete: $isSchoolSetupComplete');
      print(
          '📊 Settings state: ${settingsController.getBusinessInfoSummary()}');

      if (!isSchoolSetupComplete) {
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

  /// FIXED: More lenient school configuration check with auto-sync
  Future<bool> _checkSchoolConfigurationFixed() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Method 1: Check schools table
      final schoolResult = await db.query('schools', limit: 1);
      bool hasSchoolInTable = schoolResult.isNotEmpty;

      // Method 2: Check settings table
      final settingsResult = await db.query(
        'settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: ['business_name', 'school_id', 'enable_multi_tenant'],
      );

      bool hasBusinessName = settingsResult.any((row) =>
          row['key'] == 'business_name' &&
          row['value'] != null &&
          row['value'].toString().trim().isNotEmpty);

      bool hasSchoolId = settingsResult.any((row) =>
          row['key'] == 'school_id' &&
          row['value'] != null &&
          row['value'].toString().trim().isNotEmpty);

      // FIXED: Configuration is valid if EITHER:
      // 1. We have a school in the schools table AND a school_id in settings
      // 2. OR we have business_name in settings (fallback for single-tenant)
      bool isConfigured = (hasSchoolInTable && hasSchoolId) || hasBusinessName;

      print('🏫 School configuration check (FIXED):');
      print('   Has school in table: $hasSchoolInTable');
      print('   Has business name: $hasBusinessName');
      print('   Has school ID: $hasSchoolId');
      print('   Is configured: $isConfigured');

      // ADDITIONAL FIX: If we have school in table but no school_id in settings,
      // automatically sync them
      if (hasSchoolInTable && !hasSchoolId) {
        print('🔧 Auto-fixing: Syncing school ID to settings...');
        final schoolData = schoolResult.first;
        final schoolId = schoolData['id']?.toString();

        if (schoolId != null && schoolId.isNotEmpty) {
          await db.insert(
            'settings',
            {'key': 'school_id', 'value': schoolId},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // Also sync other school data to settings if missing
          if (!hasBusinessName && schoolData['name'] != null) {
            await db.insert(
              'settings',
              {'key': 'business_name', 'value': schoolData['name']},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          print('✅ Auto-fix complete - school data synced to settings');
          return true;
        }
      }

      return isConfigured;
    } catch (e) {
      print('❌ Error checking school configuration: $e');
      return false;
    }
  }

  /// Check if user has stored authentication
  Future<bool> _checkStoredAuthentication() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final users = await db.query('users', limit: 1);

      if (users.isEmpty) {
        print('👥 No users found in database');
        return false;
      }

      final authController = Get.find<AuthController>();
      return authController.isLoggedIn.value;
    } catch (e) {
      print('❌ Error checking stored authentication: $e');
      return false;
    }
  }

  /// Check if any users exist in database
  Future<bool> _checkIfUsersExist() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final users = await db.query('users', limit: 1);
      return users.isNotEmpty;
    } catch (e) {
      print('❌ Error checking users: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
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
