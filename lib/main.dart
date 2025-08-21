// lib/main.dart - Enhanced with Multi-Tenant Architecture
import 'package:driving/routes/protected_routes.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/services/app_bindings.dart';

import 'package:driving/services/app_initialization.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only use FFI on desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  print('🚀 === STARTING MULTI-TENANT DRIVING SCHOOL APP ===');

  // STEP 1: Initialize Firebase with proper options and error handling
  await _initializeFirebase();

  // STEP 2: Initialize core services
  await _initializeCoreServices();

  // STEP 3: Initialize multi-tenant app bindings
  await _initializeMultiTenantBindings();

  print('✅ === APP INITIALIZATION COMPLETED ===');

  runApp(MultiTenantDrivingSchoolApp());
}

/// Initialize Firebase
Future<void> _initializeFirebase() async {
  try {
    print('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('⚠️ App will continue in offline-only mode');
    // Don't rethrow - let app continue without Firebase
  }
}

/// Initialize core services
Future<void> _initializeCoreServices() async {
  try {
    print('⚙️ Initializing core services...');

    // Initialize PIN Controller early (before other controllers that might depend on it)
    Get.put(PinController(), permanent: true);
    print('✅ PinController initialized');
  } catch (e) {
    print('❌ Core services initialization failed: $e');
    print('🚨 Attempting emergency initialization...');

    // Emergency fallback - initialize critical controllers
    EmergencyBindings.initializeMissingControllers();
  }
}

/// Initialize multi-tenant app bindings
Future<void> _initializeMultiTenantBindings() async {
  try {
    print('🏫 Initializing multi-tenant app bindings...');

    // Use enhanced app bindings with multi-tenant support
    await EnhancedAppBindings().dependencies();
    print('✅ Multi-tenant app bindings completed');

    // Optional: Run additional app initialization if needed
    // Note: AppInitialization might duplicate some controller initialization
    // Uncomment only if you need additional initialization steps
    // await AppInitialization.initialize();
    // print('✅ Additional app initialization completed');
  } catch (e) {
    print('❌ Multi-tenant app bindings failed: $e');
    print('🚨 Attempting emergency controller initialization...');

    // Emergency fallback - initialize critical controllers
    EmergencyBindings.initializeMissingControllers();
  }
}

/// Multi-Tenant Driving School App
class MultiTenantDrivingSchoolApp extends StatelessWidget {
  const MultiTenantDrivingSchoolApp({super.key});

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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Use protected routes with middleware
      getPages: ProtectedRoutes.routes,

      // Use AuthenticationWrapper to determine initial route with PIN support
      home: const AuthenticationWrapper(),

      debugShowCheckedModeBanner: false,

      // Handle unknown routes
      unknownRoute: GetPage(
        name: '/notfound',
        page: () => const LoginScreen(),
      ),
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
    // Wait for controllers to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Check if AuthController exists, if not initialize it
      AuthController authController;
      try {
        authController = Get.find<AuthController>();
      } catch (e) {
        // Initialize AuthController if not found
        authController = Get.put(AuthController());
        await Future.delayed(
            const Duration(milliseconds: 200)); // Give it time to initialize
      }

      // Check PIN authentication status
      final pinController = Get.find<PinController>();
      final isUserVerified = await pinController.isUserVerified();

      String initialRoute;

      if (isUserVerified && pinController.shouldUsePinAuth()) {
        // User has previously verified and PIN is enabled
        initialRoute = '/pin-login';
      } else {
        // Default to email/password login
        initialRoute = '/login';
      }

      // Navigate to the determined route
      Get.offAllNamed(initialRoute);
    } catch (e) {
      // Fallback to login if there's any error
      debugPrint('Error determining initial route: $e');
      Get.offAllNamed('/login');
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
              Icon(
                Icons.school,
                size: 80,
                color: Colors.white,
              ),
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
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
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
                'Loading...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
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
                '   School: ${schoolConfig.schoolName.value} (${schoolConfig.schoolId.value})');
          }
        }
      }
    } catch (e) {
      // Ignore errors in logging
    }
  }
}
