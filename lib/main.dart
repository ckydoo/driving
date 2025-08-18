// lib/main.dart - Fixed version preserving all your original code + PIN authentication
import 'package:driving/routes/protected_routes.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/services/app_bindings.dart';
import 'package:driving/services/app_initialization.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
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

  // FIXED: Initialize Firebase with proper options and error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('⚠️ App will continue in offline-only mode');
    // Don't rethrow - let app continue without Firebase
  }

  // Initialize PIN Controller early (before other controllers that might depend on it)
  Get.put(PinController(), permanent: true);
  print('✅ PinController initialized');

  // Initialize app bindings AFTER Firebase
  try {
    await AppBindings().dependencies();
    print('✅ App bindings completed');

    // Note: AppInitialization might duplicate some controller initialization
    // Comment out if you get duplicate controller errors
    await AppInitialization.initialize();
    print('✅ App initialization completed');
  } catch (e) {
    print('❌ App initialization failed: $e');
    print('🚨 Attempting emergency controller initialization...');

    // Emergency fallback - initialize critical controllers
    EmergencyBindings.initializeMissingControllers();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

// Emergency fallback for missing controllers
class EmergencyBindings {
  static void initializeMissingControllers() {
    try {
      // Ensure PinController exists
      if (!Get.isRegistered<PinController>()) {
        Get.put(PinController(), permanent: true);
        print('🔧 Emergency: PinController initialized');
      }

      // Ensure AuthController exists
      if (!Get.isRegistered<AuthController>()) {
        Get.put(AuthController(), permanent: true);
        print('🔧 Emergency: AuthController initialized');
      }
    } catch (e) {
      print('🚨 Emergency initialization failed: $e');
    }
  }
}
