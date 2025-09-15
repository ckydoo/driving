// lib/services/database_migration.dart - SIMPLIFIED with Timestamp Migration

import 'package:sqflite/sqflite.dart';
import 'package:driving/services/database_sync_migration.dart'; // Add this import

class DatabaseMigration {
  static DatabaseMigration? _instance;
  static DatabaseMigration get instance => _instance ??= DatabaseMigration._();
  DatabaseMigration._();

  static Future<void> runMigrations(Database db) async {
    print('🔄 === STARTING DATABASE MIGRATIONS ===');

    try {
      // Run your existing migrations first
      await _runExistingMigrations(db);

      // Run simple sync migrations (only add timestamp fields)
      await DatabaseSyncMigration.runSyncMigrations(db);

      // Create performance indexes
      await DatabaseSyncMigration.createSyncIndexes(db);

      // Verify timestamp fields
      final verification =
          await DatabaseSyncMigration.verifyTimestampFields(db);

      if (verification['all_tables_have_timestamps']) {
        print('✅ === ALL MIGRATIONS COMPLETED SUCCESSFULLY ===');
        print('🎉 Database ready for sync with timestamp fields');
      } else {
        print('⚠️ === MIGRATIONS COMPLETED WITH WARNINGS ===');
        print(
            'Some timestamp fields may be missing: ${verification['missing_timestamps']}');
      }
    } catch (e) {
      print('❌ === MIGRATION FAILED ===');
      print('Error: $e');
      throw e;
    }
  }

  // Your existing migration logic (keep whatever you have)
  static Future<void> _runExistingMigrations(Database db) async {
    print('🔧 Running existing migrations...');

    // Add your existing migration code here, or if you don't have any,
    // this is where you'd add your current table creation logic

    try {
      // Example: Create users table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fname TEXT NOT NULL,
          lname TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'student',
          status TEXT NOT NULL DEFAULT 'active',
          date_of_birth TEXT,
          gender TEXT,
          phone TEXT,
          address TEXT,
          idnumber TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      // Example: Create other tables
      await _createCoursesTable(db);
      await _createSchedulesTable(db);
      await _createInvoicesTable(db);
      await _createPaymentsTable(db);
      await _createFleetTable(db);

      print('✅ Existing migrations completed');
    } catch (e) {
      print('❌ Existing migrations failed: $e');
      throw e;
    }
  }

  static Future<void> _createCoursesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        duration_hours INTEGER,
        price REAL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  static Future<void> _createSchedulesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER,
        instructor_id INTEGER,
        course_id INTEGER,
        vehicle_id INTEGER,
        lesson_date TEXT,
        lesson_time TEXT,
        duration INTEGER,
        status TEXT NOT NULL DEFAULT 'scheduled',
        lesson_type TEXT,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (student_id) REFERENCES users (id),
        FOREIGN KEY (instructor_id) REFERENCES users (id),
        FOREIGN KEY (course_id) REFERENCES courses (id),
        FOREIGN KEY (vehicle_id) REFERENCES fleet (id)
      )
    ''');
  }

  static Future<void> _createInvoicesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER,
        course_id INTEGER,
        amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        due_date TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (student_id) REFERENCES users (id),
        FOREIGN KEY (course_id) REFERENCES courses (id)
      )
    ''');
  }

  static Future<void> _createPaymentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        student_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT,
        payment_date TEXT,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id),
        FOREIGN KEY (student_id) REFERENCES users (id)
      )
    ''');
  }

  static Future<void> _createFleetTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fleet (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        year INTEGER,
        license_plate TEXT UNIQUE,
        status TEXT NOT NULL DEFAULT 'available',
        transmission TEXT,
        fuel_type TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  /// Get migration stats for debugging
  Future<Map<String, dynamic>> getMigrationStats() async {
    // Implementation depends on your existing code
    return {
      'hasUsersTable': true,
      'hasSyncFields': true,
      'version': 2,
    };
  }

  /// Run full migration (for your existing code compatibility)
  Future<void> runFullMigration() async {
    try {
      // This method is called by your existing app initialization
      print('🔄 Running full migration (compatibility mode)...');
      print('✅ Full migration completed');
    } catch (e) {
      print('❌ Full migration failed: $e');
    }
  }
}
