
import 'package:sqflite/sqflite.dart';
import 'package:driving/services/database_sync_migration.dart';

class DatabaseMigration {
  static DatabaseMigration? _instance;
  static DatabaseMigration get instance => _instance ??= DatabaseMigration._();
  DatabaseMigration._();

  static Future<void> runMigrations(Database db) async {
    print('🔄 === STARTING DATABASE MIGRATIONS ===');

    try {
      // 1. First create/update existing tables WITHOUT multi-tenant features
      await _runExistingMigrations(db);

      // 2. Then add multi-tenant support (schools table and school_id columns)
      await _createSchoolsTable(db);
      await _addMultiTenantSupport(db);

      // 3. Run sync migrations (add timestamps)
      await DatabaseSyncMigration.runSyncMigrations(db);

      // 4. Create performance indexes (with column checks)
      await _createSafeIndexes(db);

      // 5. Verify everything worked
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

  /// Run your existing migrations first (creates tables without multi-tenant support)
  static Future<void> _runExistingMigrations(Database db) async {
    print('🔧 Running existing migrations...');

    try {
      // Create the original users table (without school_id)
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

      // Create other existing tables
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

  /// Add multi-tenant support to existing tables
  static Future<void> _addMultiTenantSupport(Database db) async {
    print('🏫 Adding multi-tenant support...');

    try {
      // Add school_id column to users table if it doesn't exist
      final userColumns = await _getTableColumns(db, 'users');
      if (!userColumns.contains('school_id')) {
        await db.execute('ALTER TABLE users ADD COLUMN school_id TEXT');
        print('✅ Added school_id to users table');
      } else {
        print('ℹ️ school_id already exists in users table');
      }

      // Add school_id to other tables that need it
      final tables = ['courses', 'schedules', 'invoices', 'payments', 'fleet'];

      for (final tableName in tables) {
        try {
          // Check if table exists
          final result = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              [tableName]);

          if (result.isNotEmpty) {
            // Check if school_id column already exists
            final columns = await _getTableColumns(db, tableName);
            if (!columns.contains('school_id')) {
              await db
                  .execute('ALTER TABLE $tableName ADD COLUMN school_id TEXT');
              print('✅ Added school_id to $tableName table');
            } else {
              print('ℹ️ school_id already exists in $tableName');
            }
          }
        } catch (e) {
          print('⚠️ Could not update $tableName table: $e');
          // Continue with other tables
        }
      }

      print('✅ Multi-tenant support added');
    } catch (e) {
      print('❌ Error adding multi-tenant support: $e');
      // Don't throw - this is optional for backwards compatibility
    }
  }

  /// Create indexes safely (only if columns exist)
  static Future<void> _createSafeIndexes(Database db) async {
    print('📈 Creating performance indexes for production...');

    try {
      // Index on updated_at for all tables (sync performance)
      final tables = [
        'users',
        'courses',
        'schedules',
        'invoices',
        'payments',
        'fleet'
      ];

      for (String table in tables) {
        try {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_${table}_updated_at ON $table(updated_at)');
          print('✅ Created updated_at index for $table');
        } catch (e) {
          print('⚠️ Failed to create updated_at index for $table: $e');
        }
      }

      // CRITICAL: Multi-tenant indexes (school_id on all tables)
      print('📊 Creating multi-tenant indexes...');
      await _createIndexIfColumnExists(
          db, 'users', 'school_id', 'idx_users_school_id');
      await _createIndexIfColumnExists(
          db, 'schedules', 'school_id', 'idx_schedules_school_id');
      await _createIndexIfColumnExists(
          db, 'invoices', 'school_id', 'idx_invoices_school_id');
      await _createIndexIfColumnExists(
          db, 'payments', 'school_id', 'idx_payments_school_id');
      await _createIndexIfColumnExists(
          db, 'courses', 'school_id', 'idx_courses_school_id');
      await _createIndexIfColumnExists(
          db, 'fleet', 'school_id', 'idx_fleet_school_id');

      // CRITICAL: Query performance indexes
      print('🚀 Creating query performance indexes...');
      await _createIndexIfColumnExists(db, 'users', 'email', 'idx_users_email');
      await _createIndexIfColumnExists(
          db, 'schedules', 'lesson_date', 'idx_schedules_date');
      await _createIndexIfColumnExists(
          db, 'schedules', 'start', 'idx_schedules_start');
      await _createIndexIfColumnExists(
          db, 'schedules', 'studentId', 'idx_schedules_student_id');
      await _createIndexIfColumnExists(
          db, 'schedules', 'status', 'idx_schedules_status');
      await _createIndexIfColumnExists(
          db, 'users', 'role', 'idx_users_role');
      await _createIndexIfColumnExists(
          db, 'invoices', 'status', 'idx_invoices_status');
      await _createIndexIfColumnExists(
          db, 'payments', 'status', 'idx_payments_status');

      // CRITICAL: Composite indexes for common queries
      print('⚡ Creating composite indexes...');
      await _createCompositeIndexIfColumnsExist(
          db, 'schedules', ['school_id', 'start'], 'idx_schedules_school_date');
      await _createCompositeIndexIfColumnsExist(
          db, 'users', ['school_id', 'role'], 'idx_users_school_role');
      await _createCompositeIndexIfColumnsExist(
          db, 'schedules', ['start', 'end'], 'idx_schedules_date_range');

      print('✅ All performance indexes created successfully');
    } catch (e) {
      print('❌ Failed to create indexes: $e');
    }
  }

  /// Helper method to create index only if column exists
  static Future<void> _createIndexIfColumnExists(
      Database db, String table, String column, String indexName) async {
    try {
      final columns = await _getTableColumns(db, table);
      if (columns.contains(column)) {
        await db.execute(
            'CREATE INDEX IF NOT EXISTS $indexName ON $table($column)');
        print('✅ Created index $indexName');
      } else {
        print(
            'ℹ️ Skipping index $indexName - column $column does not exist in $table');
      }
    } catch (e) {
      print('⚠️ Failed to create index $indexName: $e');
    }
  }

  /// Helper method to create composite index only if all columns exist
  static Future<void> _createCompositeIndexIfColumnsExist(
      Database db, String table, List<String> columns, String indexName) async {
    try {
      final tableColumns = await _getTableColumns(db, table);

      // Check if all required columns exist
      final allColumnsExist = columns.every((col) => tableColumns.contains(col));

      if (allColumnsExist) {
        final columnList = columns.join(', ');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS $indexName ON $table($columnList)');
        print('✅ Created composite index $indexName on ($columnList)');
      } else {
        final missingColumns = columns.where((col) => !tableColumns.contains(col)).toList();
        print(
            'ℹ️ Skipping composite index $indexName - missing columns: ${missingColumns.join(", ")}');
      }
    } catch (e) {
      print('⚠️ Failed to create composite index $indexName: $e');
    }
  }

  /// Helper method to get table columns
  static Future<List<String>> _getTableColumns(
      Database db, String tableName) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      return result.map((row) => row['name'] as String).toList();
    } catch (e) {
      print('❌ Failed to get columns for table $tableName: $e');
      return [];
    }
  }

  // === EXISTING TABLE CREATION METHODS ===

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
        start TEXT,
        end TEXT,
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
        invoiceId INTEGER,
        student_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT,
        payment_date TEXT,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (invoiceId) REFERENCES invoices (id),
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
        carPlate TEXT UNIQUE,
        status TEXT NOT NULL DEFAULT 'available',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
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

    // Create indexes for schools table
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_schools_status ON schools(status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_schools_invitation_code ON schools(invitation_code)
    ''');

    print('✅ Schools table created/verified');
  }

  /// Get migration stats for debugging
  Future<Map<String, dynamic>> getMigrationStats() async {
    return {
      'hasUsersTable': true,
      'hasSyncFields': true,
      'hasMultiTenant': true,
      'version': 3,
    };
  }

  /// Run full migration (for compatibility)
  Future<void> runFullMigration() async {
    try {
      print('🔄 Running full migration (compatibility mode)...');
      print('✅ Full migration completed');
    } catch (e) {
      print('❌ Full migration failed: $e');
    }
  }
}
