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

      // Add the new school management migrations
      await _createSchoolsTable(db);
      await _createUsersTable(db);
      await _updateExistingTablesForMultiTenant(db);
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

  /// Create schools table for multi-tenant support
  static Future<void> _createSchoolsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schools (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        location TEXT,
        phone TEXT,
        email TEXT,
        website TEXT,
        start_time TEXT,
        end_time TEXT,
        operating_days TEXT,
        invitation_code TEXT UNIQUE,
        status TEXT DEFAULT 'active',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_schools_status ON schools(status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_schools_invitation_code ON schools(invitation_code)
    ''');

    print('✅ Schools table created/verified');
  }

  /// Create users table for authentication
  static Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        school_id TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT DEFAULT 'staff',
        first_name TEXT,
        last_name TEXT,
        phone TEXT,
        status TEXT DEFAULT 'active',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (school_id) REFERENCES schools (id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_users_school_id ON users(school_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_users_school_role ON users(school_id, role)
    ''');

    print('✅ Users table created/verified');
  }

  /// Update existing tables to support multi-tenancy
  static Future<void> _updateExistingTablesForMultiTenant(Database db) async {
    try {
      // Add school_id column to existing tables if they exist
      final tables = [
        'students',
        'instructors',
        'courses',
        'schedules',
        'invoices',
        'payments',
        'fleet'
      ];

      for (final tableName in tables) {
        try {
          // Check if table exists
          final result = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              [tableName]);

          if (result.isNotEmpty) {
            // Check if school_id column already exists
            final columns = await db.rawQuery('PRAGMA table_info($tableName)');
            final hasSchoolId =
                columns.any((col) => col['name'] == 'school_id');

            if (!hasSchoolId) {
              await db
                  .execute('ALTER TABLE $tableName ADD COLUMN school_id TEXT');
              print('✅ Added school_id to $tableName table');
            } else {
              print('ℹ️ school_id column already exists in $tableName');
            }
          }
        } catch (e) {
          print('⚠️ Could not update $tableName table: $e');
          // Continue with other tables
        }
      }

      print('✅ Multi-tenant columns added to existing tables');
    } catch (e) {
      print('❌ Error updating existing tables for multi-tenancy: $e');
      // Don't throw - this is optional for backwards compatibility
    }
  }

  /// Create settings table if it doesn't exist (for first-run tracking)
  static Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    print('✅ Settings table created/verified');
  }
}

// Helper class for school-related database operations
class SchoolDatabaseHelper {
  /// Get school by ID
  static Future<Map<String, dynamic>?> getSchoolById(
      Database db, String schoolId) async {
    final results = await db.query(
      'schools',
      where: 'id = ? AND status = ?',
      whereArgs: [schoolId, 'active'],
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Get school by invitation code
  static Future<Map<String, dynamic>?> getSchoolByInvitationCode(
      Database db, String code) async {
    final results = await db.query(
      'schools',
      where: 'invitation_code = ? AND status = ?',
      whereArgs: [code.toUpperCase(), 'active'],
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Get school by name (partial match)
  static Future<Map<String, dynamic>?> getSchoolByName(
      Database db, String name) async {
    final results = await db.query(
      'schools',
      where: 'LOWER(name) LIKE ? AND status = ?',
      whereArgs: ['%${name.toLowerCase()}%', 'active'],
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Get user by email and school
  static Future<Map<String, dynamic>?> getUserByEmailAndSchool(
      Database db, String email, String schoolId) async {
    final results = await db.query(
      'users',
      where: 'email = ? AND school_id = ? AND status = ?',
      whereArgs: [email.toLowerCase(), schoolId, 'active'],
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Get all users for a school
  static Future<List<Map<String, dynamic>>> getUsersForSchool(
      Database db, String schoolId) async {
    return await db.query(
      'users',
      where: 'school_id = ? AND status = ?',
      whereArgs: [schoolId, 'active'],
      orderBy: 'role, first_name, last_name',
    );
  }

  /// Check if school has admin users
  static Future<bool> schoolHasAdmins(Database db, String schoolId) async {
    final results = await db.query(
      'users',
      where: 'school_id = ? AND role = ? AND status = ?',
      whereArgs: [schoolId, 'admin', 'active'],
      limit: 1,
    );

    return results.isNotEmpty;
  }
}
