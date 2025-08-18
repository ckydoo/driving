// lib/main.dart - Fixed Firebase initialization
import 'package:driving/routes/protected_routes.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/services/app_bindings.dart';
import 'package:driving/services/app_initialization.dart';
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

      // REMOVED: Don't call AppBindings() again since we already did it in main()
      // initialBinding: AppBindings(),

      // Use protected routes with middleware
      getPages: ProtectedRoutes.routes,

      // Start with login screen and let authentication handle the flow
      initialRoute: '/login',

      debugShowCheckedModeBanner: false,

      // Handle unknown routes
      unknownRoute: GetPage(
        name: '/notfound',
        page: () => const LoginScreen(),
      ),
    );
  }
}
