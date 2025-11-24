import 'package:driving/controllers/navigation_controller.dart';
import 'package:driving/controllers/settings_controller.dart';

import 'package:driving/services/lesson_counting_service.dart';
import 'package:driving/services/schedule_status_migration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/user_controller.dart';
import '../controllers/course_controller.dart';
import '../controllers/fleet_controller.dart';
import '../controllers/billing_controller.dart';
import '../services/database_helper.dart';
import '../services/database_migration.dart';

class AppInitialization {
  static Future<void> initialize() async {
    print('🚀 === STARTING APP INITIALIZATION ===');

    try {
      print('📁 Initializing database helper...');
      Get.put(DatabaseHelper.instance, permanent: true);
      print('✅ Database helper initialized');
      print('🔐 Initializing auth controller...');
      Get.put(AuthController(), permanent: true);
      print('✅ Auth controller initialized');
      await _runDatabaseMigration();
      await _runScheduleStatusMigration();
      await _initializeControllers();

      print('✅ === APP INITIALIZATION COMPLETED SUCCESSFULLY ===');
    } catch (e) {
      print('❌ === CRITICAL ERROR DURING APP INITIALIZATION ===');
      print('Error: $e');
      print('Stack trace: ${StackTrace.current}');

      // Show user-friendly error
      _showInitializationError(e);

      // Don't rethrow - let app continue with minimal functionality
    }
  }

  /// Run database migration with error handling
  static Future<void> _runDatabaseMigration() async {
    try {
      print('🔧 Running database migration...');
      await DatabaseMigration.instance.runFullMigration();
      print('✅ Database migration completed successfully');
    } catch (e) {
      print('❌ Database migration failed: $e');
      // Continue anyway - app might still work with existing schema
    }
  }

  /// Run schedule status migration with error handling
  static Future<void> _runScheduleStatusMigration() async {
    try {
      print('📊 Running schedule status migration...');
      await ScheduleStatusMigration.instance.runStatusMigration();
      print('✅ Schedule status migration completed');
    } catch (e) {
      print('❌ Schedule status migration failed: $e');
      // This is not critical - app can continue without this migration
    }
  }

  /// Initialize all controllers with error handling
  static Future<void> _initializeControllers() async {
    try {
      print('🎮 Initializing controllers...');

      // Initialize navigation controller
      Get.put(NavigationController(), permanent: true);
      print('  ✅ Navigation controller initialized');

      // Initialize data controllers
      Get.put(UserController(), permanent: true);
      print('  ✅ User controller initialized');

      Get.put(CourseController(), permanent: true);
      print('  ✅ Course controller initialized');

      Get.put(FleetController(), permanent: true);
      print('  ✅ Fleet controller initialized');

      // Initialize operational controllers
      Get.put(ScheduleController(), permanent: true);
      print('  ✅ Schedule controller initialized');

      Get.put(BillingController(), permanent: true);
      print('  ✅ Billing controller initialized');
      Get.put(SettingsController(), permanent: true);
      print('  ✅ Settings controller initialized');
      Get.put(LessonCountingService(), permanent: true);
      print('✅ All controllers initialized successfully');
    } catch (e) {
      print('❌ Error initializing controllers: $e');
      throw Exception('Failed to initialize controllers: $e');
    }
  }

  /// Show user-friendly initialization error
  static void _showInitializationError(dynamic error) {
    try {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'App Initialization',
        'Some features may not work properly. The app will continue with limited functionality.',
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.orange[100],
        colorText: Colors.orange[800],
        icon: const Icon(Icons.warning, color: Colors.orange),
      );
    } catch (e) {
      // If even snackbar fails, just print
      print('❌ Could not show error snackbar: $e');
    }
  }

  /// Check app health status
  static Future<Map<String, dynamic>> getAppHealthStatus() async {
    final status = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'database_healthy': false,
      'controllers_healthy': false,
      'auth_healthy': false,
      'migration_healthy': false,
    };

    try {
      // Check database
      final db = await DatabaseHelper.instance.database;
      final users =
          await db.rawQuery('SELECT COUNT(*) as count FROM users LIMIT 1');
      status['database_healthy'] = users.isNotEmpty;
    } catch (e) {
      print('Database health check failed: $e');
    }

    try {
      // Check controllers
      final authController = Get.find<AuthController>();
      status['controllers_healthy'] = authController != null;
      status['auth_healthy'] = authController.isLoggedIn.value;
    } catch (e) {
      print('Controllers health check failed: $e');
    }

    try {
      // Check migration status
      final migrationStats =
          await ScheduleStatusMigration.instance.getMigrationStats();
      status['migration_healthy'] =
          migrationStats['hasSchedulesTable'] ?? false;
      status['migration_stats'] = migrationStats;
    } catch (e) {
      print('Migration health check failed: $e');
    }

    return status;
  }
}
