// lib/services/test_data_seeder.dart
import 'package:driving/services/database_helper.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class TestDataSeeder {
  static final TestDataSeeder instance = TestDataSeeder._internal();
  TestDataSeeder._internal();

  /// Hash password using SHA256
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Seed all default test data
  Future<void> seedAllTestData() async {
    print('🌱 Starting to seed test data...');

    try {
      await seedDefaultUsers();
      await seedDefaultCourses();
      await seedDefaultFleet();

      print('✅ All test data seeded successfully!');
      print('\n📋 LOGIN CREDENTIALS:');
      print('📧 Admin: admin@test.com | 🔑 Password: admin123');
      print('📧 Instructor: instructor1@test.com | 🔑 Password: instructor123');
      print('📧 Student: student1@test.com | 🔑 Password: student123');
    } catch (e) {
      print('❌ Error seeding test data: $e');
      throw Exception('Failed to seed test data: $e');
    }
  }

  /// Create default users for testing
  Future<void> seedDefaultUsers() async {
    print('👥 Seeding default users...');

    final defaultUsers = [
      // Admin User
      {
        'fname': 'System',
        'lname': 'Administrator',
        'email': 'admin@test.com',
        'gender': 'Male',
        'date_of_birth': '1985-01-15',
        'phone': '+263771234567',
        'idnumber': 'ADM001',
        'address': '123 Admin Street, Harare, Zimbabwe',
        'password': _hashPassword('admin123'),
        'course': null,
        'role': 'admin',
        'courseIds': null,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'email',
      },

      // Instructor 1
      {
        'fname': 'John',
        'lname': 'Smith',
        'email': 'instructor1@test.com',
        'gender': 'Male',
        'date_of_birth': '1980-05-20',
        'phone': '+263772345678',
        'idnumber': 'INS001',
        'address': '456 Instructor Avenue, Harare, Zimbabwe',
        'password': _hashPassword('instructor123'),
        'course': 'Practical Driving',
        'role': 'instructor',
        'courseIds': '1,2,3',
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'email',
      },

      // Instructor 2
      {
        'fname': 'Mary',
        'lname': 'Johnson',
        'email': 'instructor2@test.com',
        'gender': 'Female',
        'date_of_birth': '1978-12-10',
        'phone': '+263773456789',
        'idnumber': 'INS002',
        'address': '789 Teaching Road, Harare, Zimbabwe',
        'password': _hashPassword('instructor123'),
        'course': 'Defensive Driving',
        'role': 'instructor',
        'courseIds': '2,4',
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'email',
      },

      // Student 1
      {
        'fname': 'Alice',
        'lname': 'Brown',
        'email': 'student1@test.com',
        'gender': 'Female',
        'date_of_birth': '1995-08-25',
        'phone': '+263774567890',
        'idnumber': 'STU001',
        'address': '321 Student Lane, Harare, Zimbabwe',
        'password': _hashPassword('student123'),
        'course': 'Basic Driving Course',
        'role': 'student',
        'courseIds': '1',
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'email',
      },

      // Student 2
      {
        'fname': 'David',
        'lname': 'Wilson',
        'email': 'student2@test.com',
        'gender': 'Male',
        'date_of_birth': '1992-03-14',
        'phone': '+263775678901',
        'idnumber': 'STU002',
        'address': '654 Learning Street, Harare, Zimbabwe',
        'password': _hashPassword('student123'),
        'course': 'Advanced Driving Course',
        'role': 'student',
        'courseIds': '2',
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'email',
      },

      // Student 3
      {
        'fname': 'Sarah',
        'lname': 'Davis',
        'email': 'student3@test.com',
        'gender': 'Female',
        'date_of_birth': '1998-11-05',
        'phone': '+263776789012',
        'idnumber': 'STU003',
        'address': '987 Practice Avenue, Harare, Zimbabwe',
        'password': _hashPassword('student123'),
        'course': 'Motorcycle Training',
        'role': 'student',
        'courseIds': '3',
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'email',
      },
    ];

    for (final user in defaultUsers) {
      try {
        await DatabaseHelper.instance.insertUser(user);
        print('✅ Created user: ${user['email']} (${user['role']})');
      } catch (e) {
        print('⚠️ User ${user['email']} might already exist: $e');
      }
    }

    print('👥 Default users seeding completed');
  }

  /// Create default courses
  Future<void> seedDefaultCourses() async {
    print('📚 Seeding default courses...');

    final defaultCourses = [
      {
        'name': 'Basic Driving Course',
        'price': 450,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Advanced Driving Course',
        'price': 650,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Motorcycle Training',
        'price': 350,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Defensive Driving',
        'price': 280,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Commercial Vehicle License',
        'price': 850,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Refresher Course',
        'price': 200,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final course in defaultCourses) {
      try {
        await DatabaseHelper.instance.insertCourse(course);
        print('✅ Created course: ${course['name']} - \$${course['price']}');
      } catch (e) {
        print('⚠️ Course ${course['name']} might already exist: $e');
      }
    }

    print('📚 Default courses seeding completed');
  }

  /// Create default fleet vehicles
  Future<void> seedDefaultFleet() async {
    print('🚗 Seeding default fleet...');

    final defaultVehicles = [
      {
        'carPlate': 'ABC-1234',
        'make': 'Toyota',
        'model': 'Corolla',
        'modelYear': '2020',
        'instructor': 2, // Assigned to instructor1 (John Smith)
      },
      {
        'carPlate': 'DEF-5678',
        'make': 'Nissan',
        'model': 'Sunny',
        'modelYear': '2019',
        'instructor': 3, // Assigned to instructor2 (Mary Johnson)
      },
      {
        'carPlate': 'GHI-9012',
        'make': 'Honda',
        'model': 'Civic',
        'modelYear': '2021',
        'instructor': 0, // Unassigned
      },
      {
        'carPlate': 'JKL-3456',
        'make': 'Mazda',
        'model': '3',
        'modelYear': '2018',
        'instructor': 0, // Unassigned
      },
      {
        'carPlate': 'MNO-7890',
        'make': 'Ford',
        'model': 'Focus',
        'modelYear': '2022',
        'instructor': 2, // Assigned to instructor1 (John Smith) - second car
      },
      {
        'carPlate': 'PQR-2468',
        'make': 'Hyundai',
        'model': 'Elantra',
        'modelYear': '2020',
        'instructor': 0, // Unassigned
      },
      {
        'carPlate': 'STU-1357',
        'make': 'Volkswagen',
        'model': 'Polo',
        'modelYear': '2019',
        'instructor': 0, // Unassigned
      },
      {
        'carPlate': 'VWX-9753',
        'make': 'Suzuki',
        'model': 'Swift',
        'modelYear': '2021',
        'instructor': 3, // Assigned to instructor2 (Mary Johnson) - second car
      },
    ];

    for (final vehicle in defaultVehicles) {
      try {
        await DatabaseHelper.instance.insertFleet(vehicle);
        final status = vehicle['instructor'] == 0 ? 'Unassigned' : 'Assigned';
        print(
            '✅ Created vehicle: ${vehicle['make']} ${vehicle['model']} (${vehicle['carPlate']}) - $status');
      } catch (e) {
        print('⚠️ Vehicle ${vehicle['carPlate']} might already exist: $e');
      }
    }

    print('🚗 Default fleet seeding completed');
  }

  /// Clear all test data (useful for reset)
  Future<void> clearAllTestData() async {
    print('🧹 Clearing all test data...');

    try {
      final db = await DatabaseHelper.instance.database;

      // Clear in reverse order due to foreign key constraints
      await db.delete('schedules');
      await db.delete('fleet');
      await db.delete('courses');
      await db.delete('users');

      print('✅ All test data cleared successfully');
    } catch (e) {
      print('❌ Error clearing test data: $e');
      throw Exception('Failed to clear test data: $e');
    }
  }

  /// Seed specific user types only
  Future<void> seedUsersOnly(
      {List<String> roles = const ['admin', 'instructor', 'student']}) async {
    print('👥 Seeding users only for roles: $roles');

    final defaultUsers = [
      {
        'fname': 'System',
        'lname': 'Administrator',
        'email': 'admin@test.com',
        'role': 'admin',
        'password': _hashPassword('admin123'),
        'phone': '+263771234567',
        'idnumber': 'ADM001',
        'gender': 'Male',
        'date_of_birth': '1985-01-15',
        'address': '123 Admin Street, Harare, Zimbabwe',
        'course': '', // Changed from null
        'courseIds': '', // Changed from null
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'email',
      },
      {
        'fname': 'John',
        'lname': 'Smith',
        'email': 'instructor1@test.com',
        'role': 'instructor',
        'password': _hashPassword('instructor123'),
        'phone': '+263772345678',
        'idnumber': 'INS001',
        'gender': 'Male',
        'date_of_birth': '1980-05-20',
        'address': '456 Instructor Avenue, Harare, Zimbabwe',
        'course': 'Practical Driving',
        'courseIds': '1,2,3',
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'email',
      },
      {
        'fname': 'Alice',
        'lname': 'Brown',
        'email': 'student1@test.com',
        'role': 'student',
        'password': _hashPassword('student123'),
        'phone': '+263774567890',
        'idnumber': 'STU001',
        'gender': 'Female',
        'date_of_birth': '1995-08-25',
        'address': '321 Student Lane, Harare, Zimbabwe',
        'course': 'Basic Driving Course',
        'courseIds': '1',
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
        'last_login_method': 'email',
      },
    ];

    final filteredUsers =
        defaultUsers.where((user) => roles.contains(user['role'])).toList();

    for (final user in filteredUsers) {
      try {
        // Create a clean copy and ensure proper data types
        final cleanUser = Map<String, dynamic>.from(user);

        // Ensure all fields are proper string types
        cleanUser.forEach((key, value) {
          if (value != null) {
            cleanUser[key] = value.toString();
          } else {
            cleanUser[key] = '';
          }
        });

        await DatabaseHelper.instance.insertUser(cleanUser);
        print('✅ Created ${cleanUser['role']}: ${cleanUser['email']}');
      } catch (e) {
        print('⚠️ User ${user['email']} might already exist: $e');
      }
    }
  }

  /// Check if test data already exists
  Future<Map<String, bool>> checkTestDataExists() async {
    try {
      final users = await DatabaseHelper.instance.getUsers();
      final courses = await DatabaseHelper.instance.getCourses();
      final fleet = await DatabaseHelper.instance.getFleet();

      return {
        'users': users.any((u) => u['email'] == 'admin@test.com'),
        'courses': courses.any((c) => c['name'] == 'Basic Driving Course'),
        'fleet': fleet.any((v) => v['carPlate'] == 'ABC-1234'),
      };
    } catch (e) {
      print('❌ Error checking test data: $e');
      return {'users': false, 'courses': false, 'fleet': false};
    }
  }
}
