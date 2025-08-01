// lib/main.dart
import 'package:driving/routes/protected_routes.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/services/app_bindings.dart';
import 'package:driving/services/app_initialization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  // Initialize FFI for Windows
  sqfliteFfiInit();

  // Set the database factory to use FFI
  databaseFactory = databaseFactoryFfi;
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the app with migration
  await AppInitialization.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
      initialBinding: FinalAppBindings(),

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
