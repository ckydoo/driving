import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/subscription_controller.dart';
import 'package:driving/routes/app_routes.dart';
import 'package:driving/screens/auth/login_screen.dart';
import 'package:driving/screens/startup/splash_screen.dart';
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
    _configureApiService();

    await _initializeDatabaseAndMigrations();
  } catch (e) {
    debugPrint('Core services initialization failed: $e');
  }
}

Future<void> _initializeDatabaseAndMigrations() async {
  try {
    final db = await DatabaseHelper.instance.database;
    await DatabaseMigration.runMigrations(db);
    await AppInitialization.initialize();
    await DatabaseHelper.instance.migratePrinterSettings();
  } catch (e) {
    debugPrint('Database/migration initialization failed: $e');
  }
}

void _configureApiService() {
  const String apiBaseUrl = 'https://drivesyncpro.co.zw/api';

  ApiService.configure(baseUrl: apiBaseUrl);
}

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
        home: const SplashScreen(),
      );
    });
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
      debugPrint('Error logging route change: $e');
    }
  }
}
