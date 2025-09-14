// lib/services/auto_seed_initializer.dart - IMPROVED VERSION
import 'package:driving/services/test_data_seeder.dart';
import 'package:driving/services/database_helper.dart';

class AutoSeedInitializer {
  static final AutoSeedInitializer instance = AutoSeedInitializer._internal();
  AutoSeedInitializer._internal();

  /// Initialize app with automatic seeding if needed
  Future<void> initializeWithAutoSeed({
    bool seedIfEmpty = true,
    bool forceReseed = false,
  }) async {
    print('🚀 Auto-seed initializer starting...');

    try {
      if (forceReseed) {
        print('🔄 Force reseeding enabled - clearing existing data...');
        await TestDataSeeder.instance.clearAllTestData();
        await TestDataSeeder.instance.seedAllTestData();
        print('✅ Force reseed completed');
        return;
      }

      if (seedIfEmpty) {
        final needsSeeding = await _shouldSeedDatabase();

        if (needsSeeding) {
          print('📱 Database needs seeding - auto-seeding test data...');
          await TestDataSeeder.instance.seedAllTestData();
          print('✅ Auto-seed completed - ready for testing!');
        } else {
          print('📊 Database has sufficient data - skipping auto-seed');
        }
      }
    } catch (e) {
      print('❌ Auto-seed initialization failed: $e');
      // Don't throw - let app continue even if seeding fails
    }
  }

  /// Enhanced check to determine if database needs seeding
  Future<bool> _shouldSeedDatabase() async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      final courses = await DatabaseHelper.instance.getCourses();
      final fleet = await DatabaseHelper.instance.getFleet();

      // Check if we have essential test users
      final hasAdmin = users
          .any((u) => u['email'] == 'admin@test.com' && u['role'] == 'admin');
      final hasInstructor = users.any((u) =>
          u['email'] == 'instructor1@test.com' && u['role'] == 'instructor');
      final hasStudent = users.any(
          (u) => u['email'] == 'student1@test.com' && u['role'] == 'student');

      // Check if we have basic courses
      final hasBasicCourse =
          courses.any((c) => c['name'] == 'Basic Driving Course');
      final hasAdvancedCourse =
          courses.any((c) => c['name'] == 'Advanced Driving Course');

      // Check if we have fleet vehicles
      final hasVehicles = fleet.isNotEmpty;

      // Need seeding if missing essential data
      final needsSeeding = !hasAdmin ||
          !hasInstructor ||
          !hasStudent ||
          !hasBasicCourse ||
          !hasAdvancedCourse ||
          !hasVehicles;

      if (needsSeeding) {
        print('🔍 Missing essential data:');
        if (!hasAdmin) print('  - Admin user');
        if (!hasInstructor) print('  - Instructor user');
        if (!hasStudent) print('  - Student user');
        if (!hasBasicCourse) print('  - Basic driving course');
        if (!hasAdvancedCourse) print('  - Advanced driving course');
        if (!hasVehicles) print('  - Fleet vehicles');
      }

      return needsSeeding;
    } catch (e) {
      print('❌ Error checking if database needs seeding: $e');
      return true; // Assume needs seeding if we can't check
    }
  }

  /// Check if we have essential test users for login testing
  Future<bool> hasTestUsers() async {
    try {
      final users = await DatabaseHelper.instance.getUsers();

      final hasAdmin = users
          .any((u) => u['email'] == 'admin@test.com' && u['role'] == 'admin');
      final hasInstructor = users.any((u) =>
          u['email'] == 'instructor1@test.com' && u['role'] == 'instructor');
      final hasStudent = users.any(
          (u) => u['email'] == 'student1@test.com' && u['role'] == 'student');

      return hasAdmin && hasInstructor && hasStudent;
    } catch (e) {
      print('❌ Error checking for test users: $e');
      return false;
    }
  }

  /// DEVELOPMENT ONLY: Initialize with development settings
  Future<void> developmentInit() async {
    print('🔧 DEVELOPMENT: Initializing with development settings...');

    // For development, only seed if completely empty
    await initializeWithAutoSeed(
      seedIfEmpty: true,
      forceReseed: false, // CHANGED: Never force reseed on normal startup
    );

    print('✅ DEVELOPMENT: Initialization completed');
  }

  /// DEVELOPMENT ONLY: Force clear and reseed everything
  Future<void> forceReseedForDevelopment() async {
    print('🔄 DEVELOPMENT: Force reseeding all data...');

    await initializeWithAutoSeed(
      seedIfEmpty: false,
      forceReseed: true,
    );

    print('✅ DEVELOPMENT: Force reseed completed');
  }

  /// Get statistics about current data
  Future<Map<String, int>> getDataStatistics() async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      final courses = await DatabaseHelper.instance.getCourses();
      final fleet = await DatabaseHelper.instance.getFleet();

      return {
        'users': users.length,
        'courses': courses.length,
        'vehicles': fleet.length,
      };
    } catch (e) {
      print('❌ Error getting data statistics: $e');
      return {
        'users': 0,
        'courses': 0,
        'vehicles': 0,
      };
    }
  }
}
