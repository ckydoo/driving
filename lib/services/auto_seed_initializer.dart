// lib/services/auto_seed_initializer.dart
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
        final isEmpty = await _isDatabaseEmpty();

        if (isEmpty) {
          print('📱 Database is empty - auto-seeding test data...');
          await TestDataSeeder.instance.seedAllTestData();
          print('✅ Auto-seed completed - ready for testing!');
        } else {
          print('📊 Database has data - skipping auto-seed');
        }
      }
    } catch (e) {
      print('❌ Auto-seed initialization failed: $e');
      // Don't throw - let app continue even if seeding fails
    }
  }

  /// Check if database is completely empty
  Future<bool> _isDatabaseEmpty() async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      final courses = await DatabaseHelper.instance.getCourses();
      final fleet = await DatabaseHelper.instance.getFleet();

      // Consider empty if all tables are empty
      return users.isEmpty && courses.isEmpty && fleet.isEmpty;
    } catch (e) {
      print('❌ Error checking if database is empty: $e');
      return true; // Assume empty if we can't check
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
      print('❌ Error checking test users: $e');
      return false;
    }
  }

  /// Seed minimal data for testing (just essential users)
  Future<void> seedMinimalTestData() async {
    print('🔧 Seeding minimal test data...');

    try {
      final hasUsers = await hasTestUsers();

      if (!hasUsers) {
        await TestDataSeeder.instance.seedUsersOnly();
        print('✅ Minimal test users created');
      } else {
        print('ℹ️ Test users already exist - skipping');
      }
    } catch (e) {
      print('❌ Failed to seed minimal test data: $e');
    }
  }

  /// Development mode initialization
  Future<void> developmentInit() async {
    print('🛠️ Development mode initialization...');

    const bool AUTO_SEED_IN_DEV = true; // Set to false to disable

    if (AUTO_SEED_IN_DEV) {
      await initializeWithAutoSeed(seedIfEmpty: true);
    } else {
      print('ℹ️ Auto-seeding disabled in development mode');
    }
  }

  /// Production/Release mode initialization
  Future<void> productionInit() async {
    print('🏭 Production mode initialization...');

    // In production, only seed if completely empty
    // and only minimal essential data
    final isEmpty = await _isDatabaseEmpty();

    if (isEmpty) {
      print('⚠️ Production database is empty - creating minimal admin user...');

      // Create only an admin user for initial setup
      await _createProductionAdmin();
      print('✅ Production admin created');
    } else {
      print('📊 Production database has data - no seeding needed');
    }
  }

  /// Create a production admin user
  Future<void> _createProductionAdmin() async {
    try {
      var adminUser = {
        'fname': 'System',
        'lname': 'Administrator',
        'email': 'admin@drivingschool.com', // Use your domain
        'gender': 'Male',
        'date_of_birth': '1985-01-01',
        'phone': '+263771000000',
        'idnumber': 'ADMIN001',
        'address': 'Administrative Office',
        'password': 'changeMe2024!', // Strong default password
        'role': 'admin',
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'system',
      };

      await DatabaseHelper.instance.insertUser(adminUser);
      print(
          '✅ Production admin user created with email: ${adminUser['email']}');
      print(
          '🔐 Default password: ${adminUser['password']} - CHANGE IMMEDIATELY!');
    } catch (e) {
      print('❌ Failed to create production admin: $e');
    }
  }

  /// Get quick status summary
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      final courses = await DatabaseHelper.instance.getCourses();
      final fleet = await DatabaseHelper.instance.getFleet();

      final adminCount = users.where((u) => u['role'] == 'admin').length;
      final instructorCount =
          users.where((u) => u['role'] == 'instructor').length;
      final studentCount = users.where((u) => u['role'] == 'student').length;

      return {
        'total_users': users.length,
        'admin_count': adminCount,
        'instructor_count': instructorCount,
        'student_count': studentCount,
        'total_courses': courses.length,
        'total_vehicles': fleet.length,
        'has_test_data': await hasTestUsers(),
        'is_empty': await _isDatabaseEmpty(),
      };
    } catch (e) {
      print('❌ Error getting status: $e');
      return {'error': e.toString()};
    }
  }
}
