// Updated DatabaseHelper with Firebase sync integration
import 'dart:async';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/billing.dart';
import 'package:driving/models/billing_record.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/fleet.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Import the sync extension
import 'enhanced_database_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Android-specific database initialization
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'driving_school.db');

    return await openDatabase(
      path,
      version: 2, // Increment version to trigger upgrade
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync tracking columns to existing tables
      await DatabaseHelperSyncExtension.addSyncTrackingTriggers(db);
      await DatabaseHelperSyncExtension.addDeletedColumn(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create all your existing tables first...
    await _createAllTables(db);

    // Add sync tracking after table creation
    await DatabaseHelperSyncExtension.addSyncTrackingTriggers(db);
    await DatabaseHelperSyncExtension.addDeletedColumn(db);

    print('Database tables created with sync support');
  }

  Future<void> _createAllTables(Database db) async {
    // All your existing table creation code...
    await db.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE attachments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uploaded_by INTEGER NOT NULL,
        attachment_for INTEGER NOT NULL,
        name TEXT NOT NULL,
        attachment TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE courseinstructor(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        instructor INTEGER NOT NULL,
        course INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE courses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE coursesenrolled(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student INTEGER NOT NULL,
        course INTEGER NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        total_theory INTEGER NOT NULL,
        total_practical INTEGER NOT NULL,
        completed_theory INTEGER NOT NULL DEFAULT 0,
        completed_practical INTEGER NOT NULL DEFAULT 0,
        completed_on DATE,
        status TEXT NOT NULL DEFAULT 'Pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE currencies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        symbol TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE fleet(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carplate TEXT NOT NULL,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        modelyear TEXT NOT NULL,
        instructor INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices(
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       student INTEGER NOT NULL,
       course INTEGER NOT NULL,
       lessons INTEGER NOT NULL,
       price_per_lesson REAL NOT NULL,
       amountpaid REAL NOT NULL DEFAULT 0,
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       due_date TIMESTAMP NOT NULL,
       courseName TEXT ,
       status TEXT NOT NULL DEFAULT 'unpaid',
       total_amount REAL NOT NULL ,
       used_lessons INTEGER NOT NULL DEFAULT 0,
       invoice_number TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_by INTEGER NOT NULL,
        note_for INTEGER NOT NULL,
        note TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user INTEGER NOT NULL,
        type TEXT,
        message TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        is_read INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school INTEGER NOT NULL,
        subject TEXT,
        days INTEGER NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        send_via TEXT NOT NULL,
        timing TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE schedules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start TEXT NOT NULL,
        end TEXT NOT NULL,
        course INTEGER NOT NULL,
        student INTEGER NOT NULL,
        instructor INTEGER NOT NULL,
        class_type TEXT NOT NULL,
        car INTEGER,
        status TEXT NOT NULL,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurrence_pattern TEXT,
        recurrence_end_date TEXT,
        attended INTEGER NOT NULL DEFAULT 0,
        lessonsCompleted INTEGER DEFAULT 0,
        lessonsDeducted INTEGER DEFAULT 0, 
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE timeline(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        title TEXT NOT NULL,
        event_type TEXT,
        description TEXT,
        created_by INTEGER NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (studentId) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE usermessages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receiver INTEGER NOT NULL,
        type TEXT NOT NULL,
        contact TEXT NOT NULL,
        subject TEXT,
        message TEXT,
        sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        status TEXT NOT NULL DEFAULT 'Sent'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS billing_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheduleId INTEGER NOT NULL,
        invoiceId INTEGER NOT NULL,
        studentId INTEGER NOT NULL,
        amount REAL NOT NULL,
        dueDate TEXT,
        status TEXT NOT NULL,
        FOREIGN KEY (scheduleId) REFERENCES schedules(id),
        FOREIGN KEY (invoiceId) REFERENCES invoices(id),
        FOREIGN KEY (studentId) REFERENCES users(id)
      )
    ''');
    await db.execute('''
  CREATE TABLE users(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fname TEXT NOT NULL,
    lname TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,  
    gender TEXT,
    date_of_birth DATE NOT NULL,
    phone TEXT UNIQUE,             
    idnumber TEXT UNIQUE,        
    address TEXT,
    password TEXT NOT NULL,
    course TEXT,
    role TEXT NOT NULL,
    courseIds TEXT,
    status TEXT NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_modified INTEGER DEFAULT ${DateTime.now().toUtc().millisecondsSinceEpoch},
    firebase_synced INTEGER DEFAULT 0,
    deleted INTEGER DEFAULT 0,
    firebase_user_id TEXT UNIQUE     
  )
''');
    await db.execute('''
      CREATE TABLE payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Paid',
        paymentDate TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        notes TEXT,
        reference TEXT,
        receipt_path TEXT,
        receipt_generated INTEGER NOT NULL DEFAULT 0,
        userId INTEGER REFERENCES users(id),
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE billings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheduleId INTEGER NOT NULL,
        studentId INTEGER NOT NULL, 
        amount REAL NOT NULL,
        dueDate TEXT,
        status TEXT,
        FOREIGN KEY (scheduleId) REFERENCES schedules (id),
        FOREIGN KEY (studentId) REFERENCES users (id) 
      )
    ''');

    await db.execute('''
      CREATE TABLE billing_records_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          scheduleId INTEGER NOT NULL,
          invoiceId INTEGER NOT NULL,
          studentId INTEGER NOT NULL,
          amount REAL NOT NULL,
          dueDate TEXT,
          status TEXT NOT NULL,
          FOREIGN KEY (scheduleId) REFERENCES schedules(id),
          FOREIGN KEY (invoiceId) REFERENCES invoices(id),
          FOREIGN KEY (studentId) REFERENCES users(id)
      )
    ''');

    await db.execute('''
  CREATE TABLE known_schools(
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    city TEXT,
    country TEXT,
    last_accessed TEXT,
    access_count INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');

    print('✅ Known schools table created');
  }

  // ==================== SYNC-ENABLED CRUD METHODS ====================

  // ================ USERS TABLE ================
// lib/services/database_helper.dart - Enhanced insertUser method with better error handling

  Future<int> insertUser(User user) async {
    try {
      final db = await database;

      // Prepare user data for insertion
      final userData = user.toJson();

      // Ensure ID is null for new users (database will auto-generate)
      userData.remove('id');

      // Validate required fields
      if (userData['email'] == null ||
          userData['email'].toString().trim().isEmpty) {
        throw Exception('Email is required');
      }

      if (userData['fname'] == null ||
          userData['fname'].toString().trim().isEmpty) {
        throw Exception('First name is required');
      }

      if (userData['lname'] == null ||
          userData['lname'].toString().trim().isEmpty) {
        throw Exception('Last name is required');
      }

      // Set default values for potentially null fields
      userData['created_at'] ??= DateTime.now().toIso8601String();
      userData['status'] ??= 'Active';
      userData['role'] ??= 'student';

      print('📝 Inserting user data: ${userData['email']}');

      // Insert user and get the generated ID
      final insertedId = await DatabaseHelperSyncExtension.insertWithSync(
          db, 'users', userData);

      if (insertedId <= 0) {
        throw Exception(
            'Failed to insert user - invalid ID returned: $insertedId');
      }

      print('✅ User inserted successfully with ID: $insertedId');
      return insertedId;
    } catch (e) {
      print('❌ Error inserting user: $e');

      // Provide more specific error messages
      if (e.toString().contains('UNIQUE constraint failed')) {
        if (e.toString().contains('users.email')) {
          throw Exception('Email address is already registered');
        } else if (e.toString().contains('users.phone')) {
          throw Exception('Phone number is already registered');
        } else if (e.toString().contains('users.idnumber')) {
          throw Exception('ID number is already registered');
        }
      }

      // Re-throw the original error with context
      throw Exception('Failed to save user: ${e.toString()}');
    }
  }

  Future<int> updateUser(User user) async {
    try {
      final db = await database;

      if (user.id == null || user.id! <= 0) {
        throw Exception('Invalid user ID for update');
      }

      final userData = user.toJson();

      // Validate required fields
      if (userData['email'] == null ||
          userData['email'].toString().trim().isEmpty) {
        throw Exception('Email is required');
      }

      print('📝 Updating user data: ID ${user.id}, Email ${userData['email']}');

      final rowsAffected = await DatabaseHelperSyncExtension.updateWithSync(
          db, 'users', userData, 'id = ?', [user.id!]);

      if (rowsAffected == 0) {
        throw Exception('No user found with ID ${user.id}');
      }

      print('✅ User updated successfully: $rowsAffected row(s) affected');
      return rowsAffected;
    } catch (e) {
      print('❌ Error updating user: $e');

      // Provide more specific error messages
      if (e.toString().contains('UNIQUE constraint failed')) {
        if (e.toString().contains('users.email')) {
          throw Exception(
              'Email address is already registered by another user');
        } else if (e.toString().contains('users.phone')) {
          throw Exception('Phone number is already registered by another user');
        } else if (e.toString().contains('users.idnumber')) {
          throw Exception('ID number is already registered by another user');
        }
      }

      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'users', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getUsers({String? role}) async {
    final db = await database;
    if (role != null) {
      return DatabaseHelperSyncExtension.queryWithoutDeleted(
        db,
        'users',
        where: 'LOWER(role) = ?',
        whereArgs: [role.toLowerCase()],
      );
    } else {
      return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'users');
    }
  }

  // ================ SCHEDULES TABLE ================
  Future<int> insertSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'schedules', schedule);
  }

  Future<int> updateSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'schedules', schedule, 'id = ?', [schedule['id']]);
  }

  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'schedules', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'schedules');
  }

  // ================ COURSES TABLE ================
  Future<int> insertCourse(Map<String, dynamic> course) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(db, 'courses', course);
  }

  Future<int> updateCourse(Map<String, dynamic> course) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'courses', course, 'id = ?', [course['id']]);
  }

  Future<int> deleteCourse(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'courses', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getCourses() async {
    final db = await database;

    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'courses');
  }

  // ================ INVOICES TABLE ================
  Future<int> insertInvoice(Map<String, dynamic> invoice) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(db, 'invoices', invoice);
  }

  Future<int> updateInvoice(Map<String, dynamic> invoice) async {
    print('DatabaseHelper: Updating invoice with data: $invoice');
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'invoices', invoice, 'id = ?', [invoice['id']]);
  }

  Future<int> deleteInvoice(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'invoices', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getInvoices() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'invoices');
  }

  // ================ PAYMENTS TABLE ================
  Future<int> insertPayment(Map<String, dynamic> payment) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(db, 'payments', payment);
  }

  Future<int> updatePayment(Map<String, dynamic> payment) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'payments', payment, 'id = ?', [payment['id']]);
  }

  Future<int> deletePayment(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'payments', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getPayments() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'payments');
  }

  // ================ FLEET TABLE ================
  Future<int> insertFleet(Map<String, dynamic> fleet) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(db, 'fleet', fleet);
  }

  Future<int> updateFleet(Map<String, dynamic> fleet) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'fleet', fleet, 'id = ?', [fleet['id']]);
  }

  Future<int> deleteFleet(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'fleet', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getFleet() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'fleet');
  }

  // ================ ATTACHMENTS TABLE ================
  Future<int> insertAttachment(Map<String, dynamic> attachment) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'attachments', attachment);
  }

  Future<int> updateAttachment(Map<String, dynamic> attachment) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'attachments', attachment, 'id = ?', [attachment['id']]);
  }

  Future<int> deleteAttachment(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'attachments', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getAttachments() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'attachments');
  }

  // ================ NOTES TABLE ================
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    print('Note saved');
    return DatabaseHelperSyncExtension.insertWithSync(db, 'notes', note);
  }

  Future<int> updateNote(Map<String, dynamic> note) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'notes', note, 'id = ?', [note['id']]);
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'notes', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'notes');
  }

  // ================ NOTIFICATIONS TABLE ================
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'notifications', notification);
  }

  Future<int> updateNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'notifications', notification, 'id = ?', [notification['id']]);
  }

  Future<int> deleteNotification(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'notifications', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getNotificationsForUser(int userId) async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'notifications',
      where: 'user = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  // ================ BILLING RECORDS TABLE ================
  Future<int> insertBillingRecord(BillingRecord billingRecord) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'billing_records', billingRecord.toJson());
  }

  Future<void> updateBillingRecordStatus(
      int billingRecordId, String status) async {
    final db = await database;
    await DatabaseHelperSyncExtension.updateWithSync(
        db, 'billing_records', {'status': status}, 'id = ?', [billingRecordId]);
  }

  Future<int> deleteBillingRecord(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'billing_records', 'id = ?', [id]);
  }

  Future<List<BillingRecord>> getBillingRecordsForInvoice(int invoiceId) async {
    final db = await database;
    final List<Map<String, dynamic>> results =
        await DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'billing_records',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
    );
    return results.map((json) => BillingRecord.fromJson(json)).toList();
  }

  // ==================== SPECIALIZED QUERY METHODS ====================
  // These methods use special queries, so they might need custom handling

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final results = await DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final results = await DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<Course?> getCourseById(int courseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'courses',
      where: 'id = ?',
      whereArgs: [courseId],
    );

    if (maps.isNotEmpty) {
      return Course.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getInvoicesWithCourseNamesForStudent(
      int studentId) async {
    final db = await database;
    // For complex joins, we'll use raw query but add deleted check
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        invoices.id,
        invoices.student AS studentId,
        invoices.course AS courseId,
        invoices.lessons,
        invoices.price_per_lesson,
        invoices.amountpaid,
        invoices.created_at,
        invoices.due_date,
        invoices.status,
        invoices.total_amount,
        invoices.used_lessons,
        invoices.invoice_number,
        courses.name AS courseName 
      FROM invoices
      INNER JOIN courses ON invoices.course = courses.id  
      WHERE invoices.student = ? 
        AND (invoices.deleted IS NULL OR invoices.deleted = 0)
        AND (courses.deleted IS NULL OR courses.deleted = 0)
    ''', [studentId]);
    print(results);
    return results;
  }

  Future<List<Map<String, dynamic>>> getAttachmentsForStudent(
      int studentId) async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'attachments',
      where: 'attachment_for = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getNotesForStudent(int studentId) async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'notes',
      where: 'note_for = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Payment>> getPaymentsForStudent(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'payments',
      where: 'studentId = ?',
      whereArgs: [studentId],
    );
    return maps.map((map) => Payment.fromJson(map)).toList();
  }

  Future<List<Payment>> getPaymentsForSchedule(int scheduleId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'payments',
      where: 'scheduleId = ?',
      whereArgs: [scheduleId],
    );
    return maps.map((map) => Payment.fromJson(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getBillingForStudent(int studentId) async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'billings',
      where: 'studentId = ?',
      whereArgs: [studentId],
    );
  }

  Future<Billing?> getBillingForSchedule(int scheduleId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await DatabaseHelperSyncExtension.queryWithoutDeleted(
      db,
      'billings',
      where: 'scheduleId = ?',
      whereArgs: [scheduleId],
    );
    if (maps.isNotEmpty) {
      return Billing.fromJson(maps.first);
    }
    return null;
  }

  // ==================== NON-SYNC METHODS ====================
  // Methods that don't need sync (authentication, utilities, etc.)

  Future<bool> emailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  Future<void> updateUserPassword(int userId, String hashedPassword) async {
    final db = await database;
    await DatabaseHelperSyncExtension.updateWithSync(
        db, 'users', {'password': hashedPassword}, 'id = ?', [userId]);
  }

  Future<void> updateUserLastLogin(int userId) async {
    final db = await database;
    await DatabaseHelperSyncExtension.updateWithSync(db, 'users',
        {'last_login': DateTime.now().toIso8601String()}, 'id = ?', [userId]);
  }

  Future<void> createDefaultAdmin() async {
    final db = await database;
    final adminCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users WHERE LOWER(role) = ? AND (deleted IS NULL OR deleted = 0)',
      ['admin'],
    );

    final count = adminCount.first['count'] as int;

    if (count == 0) {
      await insertUser(User(
        id: null,
        fname: 'System',
        lname: 'Administrator',
        email: 'admin@drivingschool.com',
        password:
            'c7ad44cbad762a5da0a452f9e854fdc1e0e7a52a38015f23f3eab1d80b931dd472634dfac71cd34ebc35d16ab7fb8a90c81f975113d6c7538dc69dd8de9077ec',
        gender: 'Male',
        phone: '+1234567890',
        address: '123 Main Street',
        date_of_birth: DateTime.parse('1980-01-01'),
        role: 'admin',
        status: 'Active',
        idnumber: 'ADMIN001',
        created_at: DateTime.now(),
      ));

      print('Default admin user created: admin@drivingschool.com / admin123');
    }
  }

  // ==================== LEGACY METHODS (IF NEEDED) ====================
  // Keep any methods that might be called by existing code but add deprecation notices

  // ==================== LEGACY METHODS (IF NEEDED) ====================
  // Keep any methods that might be called by existing code but add deprecation notices

  List<Fleet> fleet = [];

  @deprecated
  Future<void> fetchFleet() async {
    final List<Map<String, dynamic>> maps = await getFleet();
    fleet = maps.map((map) => Fleet.fromMap(map)).toList();
  }

  @deprecated
  Future<void> saveFleet(List<Fleet> newFleet) async {
    for (final vehicle in newFleet) {
      await insertFleet(vehicle.toMap());
    }
    await fetchFleet(); // Refresh the list after saving
  }

  // ==================== REMAINING TABLES WITH SYNC SUPPORT ====================

  // ================ COURSE INSTRUCTOR TABLE ================
  Future<int> insertCourseInstructor(
      Map<String, dynamic> courseInstructor) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'courseinstructor', courseInstructor);
  }

  Future<int> updateCourseInstructor(
      Map<String, dynamic> courseInstructor) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(db, 'courseinstructor',
        courseInstructor, 'id = ?', [courseInstructor['id']]);
  }

  Future<int> deleteCourseInstructor(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'courseinstructor', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getCourseInstructors() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(
        db, 'courseinstructor');
  }

  // ================ COURSES ENROLLED TABLE ================
  Future<int> insertCourseEnrolled(Map<String, dynamic> courseEnrolled) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'coursesenrolled', courseEnrolled);
  }

  Future<int> updateCourseEnrolled(Map<String, dynamic> courseEnrolled) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(db, 'coursesenrolled',
        courseEnrolled, 'id = ?', [courseEnrolled['id']]);
  }

  Future<int> deleteCourseEnrolled(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'coursesenrolled', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getCoursesEnrolled() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(
        db, 'coursesenrolled');
  }

  // ================ CURRENCIES TABLE ================
  Future<int> insertCurrency(Map<String, dynamic> currency) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'currencies', currency);
  }

  Future<int> updateCurrency(Map<String, dynamic> currency) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'currencies', currency, 'id = ?', [currency['id']]);
  }

  Future<int> deleteCurrency(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'currencies', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getCurrencies() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'currencies');
  }

  // ================ REMINDERS TABLE ================
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'reminders', reminder);
  }

  Future<int> updateReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'reminders', reminder, 'id = ?', [reminder['id']]);
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'reminders', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'reminders');
  }

  // ================ TIMELINE TABLE ================
  Future<int> insertTimeline(Map<String, dynamic> timeline) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(db, 'timeline', timeline);
  }

  Future<int> updateTimeline(Map<String, dynamic> timeline) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'timeline', timeline, 'id = ?', [timeline['id']]);
  }

  Future<int> deleteTimeline(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'timeline', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getTimeline() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'timeline');
  }

  // ================ USER MESSAGES TABLE ================
  Future<int> insertUserMessage(Map<String, dynamic> userMessage) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'usermessages', userMessage);
  }

  Future<int> updateUserMessage(Map<String, dynamic> userMessage) async {
    final db = await database;
    return DatabaseHelperSyncExtension.updateWithSync(
        db, 'usermessages', userMessage, 'id = ?', [userMessage['id']]);
  }

  Future<int> deleteUserMessage(int id) async {
    final db = await database;
    return DatabaseHelperSyncExtension.deleteWithSync(
        db, 'usermessages', 'id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getUserMessages() async {
    final db = await database;
    return DatabaseHelperSyncExtension.queryWithoutDeleted(db, 'usermessages');
  }

  // ================ BILLING RECORDS HISTORY TABLE ================
  Future<int> insertBillingRecordHistory(BillingRecord billingRecord) async {
    final db = await database;
    return DatabaseHelperSyncExtension.insertWithSync(
        db, 'billing_records_history', billingRecord.toJson());
  }

  // ==================== MANUAL SYNC TRIGGER METHODS ====================
  // These methods can be called when you want to force immediate sync for specific data

  Future<void> forceSyncTable(String tableName) async {
    try {
      // Get the sync service and trigger sync for specific table
      // This is a placeholder - you'd implement table-specific sync logic
      print('Forcing sync for table: $tableName');

      // You could implement specific logic here to:
      // 1. Mark all records in the table as needing sync
      // 2. Trigger immediate sync
      // 3. Handle any conflicts
    } catch (e) {
      print('Error forcing sync for $tableName: $e');
    }
  }

  Future<void> markAllRecordsForSync() async {
    final db = await database;
    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet',
      'attachments',
      'notes',
      'notifications',
      'billing_records',
      'timeline',
      'usermessages',
      //'settings'
    ];

    for (String table in tables) {
      try {
        await db.execute('''
          UPDATE $table 
          SET firebase_synced = 0, 
              last_modified = ${DateTime.now().toUtc().millisecondsSinceEpoch}
          WHERE deleted IS NULL OR deleted = 0
        ''');
        print('Marked $table records for sync');
      } catch (e) {
        print('Could not mark $table for sync: $e');
      }
    }
  }

  // ==================== SYNC STATUS METHODS ====================

  Future<Map<String, int>> getSyncStatus() async {
    final db = await database;
    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet',
      'attachments',
      'notes',
      'notifications',
      'billing_records',
      'timeline',
      'usermessages',
      //'settings'
    ];

    Map<String, int> syncStatus = {};

    for (String table in tables) {
      try {
        // Count total records
        final totalResult = await db.rawQuery('''
          SELECT COUNT(*) as count FROM $table 
          WHERE deleted IS NULL OR deleted = 0
        ''');
        final total = totalResult.first['count'] as int;

        // Count synced records
        final syncedResult = await db.rawQuery('''
          SELECT COUNT(*) as count FROM $table 
          WHERE (deleted IS NULL OR deleted = 0) 
          AND firebase_synced = 1
        ''');
        final synced = syncedResult.first['count'] as int;

        syncStatus[table] = synced;
        syncStatus['${table}_total'] = total;
      } catch (e) {
        print('Error getting sync status for $table: $e');
        syncStatus[table] = 0;
        syncStatus['${table}_total'] = 0;
      }
    }

    return syncStatus;
  }

  Future<List<Map<String, dynamic>>> getPendingSyncRecords(String table) async {
    final db = await database;
    try {
      return await db.query(
        table,
        where: '(deleted IS NULL OR deleted = 0) AND firebase_synced = 0',
        orderBy: 'last_modified DESC',
      );
    } catch (e) {
      print('Error getting pending sync records for $table: $e');
      return [];
    }
  }

  // ==================== BACKUP METHODS ====================

  Future<Map<String, List<Map<String, dynamic>>>> exportAllData() async {
    final db = await database;
    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet',
      'attachments',
      'notes',
      'notifications',
      'billing_records',
      'courseinstructor',
      'coursesenrolled',
      'currencies',
      'reminders',
      'timeline',
      'usermessages',
      //'settings'
    ];

    Map<String, List<Map<String, dynamic>>> exportData = {};

    for (String table in tables) {
      try {
        final data =
            await DatabaseHelperSyncExtension.queryWithoutDeleted(db, table);
        exportData[table] = data;
        print('Exported ${data.length} records from $table');
      } catch (e) {
        print('Error exporting $table: $e');
        exportData[table] = [];
      }
    }

    return exportData;
  }

  Future<void> importAllData(
      Map<String, List<Map<String, dynamic>>> importData) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final entry in importData.entries) {
        final table = entry.key;
        final records = entry.value;

        try {
          // Clear existing data
          await txn.delete(table);

          // Insert imported data
          for (final record in records) {
            await txn.insert(table, record);
          }

          print('Imported ${records.length} records to $table');
        } catch (e) {
          print('Error importing to $table: $e');
        }
      }
    });
  }

  // ==================== CLEANUP METHODS ====================

  Future<void> cleanupDeletedRecords() async {
    final db = await database;
    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet',
      'attachments',
      'notes',
      'notifications',
      'billing_records',
      'timeline',
      'usermessages',
      //'settings'
    ];

    for (String table in tables) {
      try {
        // Only remove records that have been synced and are marked as deleted
        final deletedCount = await db.delete(
          table,
          where: 'deleted = 1 AND firebase_synced = 1',
        );

        if (deletedCount > 0) {
          print('Cleaned up $deletedCount deleted records from $table');
        }
      } catch (e) {
        print('Error cleaning up $table: $e');
      }
    }
  }

  Future<void> resetSyncStatus() async {
    final db = await database;
    final tables = [
      'users',
      'courses',
      'schedules',
      'invoices',
      'payments',
      'fleet',
      'attachments',
      'notes',
      'notifications',
      'billing_records',
      'timeline',
      'usermessages',
      //'settings'
    ];

    for (String table in tables) {
      try {
        await db.execute('''
          UPDATE $table 
          SET firebase_synced = 0, 
              last_modified = ${DateTime.now().toUtc().millisecondsSinceEpoch}
        ''');
        print('Reset sync status for $table');
      } catch (e) {
        print('Could not reset sync status for $table: $e');
      }
    }
  }

  // Add this method to your DatabaseHelper class

  /// Safe migration that doesn't conflict with existing columns
  Future<void> addFirebaseSyncSupport() async {
    final db = await database;

    print('🔧 === ADDING FIREBASE SYNC SUPPORT (SAFE) ===');

    final tables = [
      'users',
      'schedules',
      'invoices',
      'payments',
      'attachments',
      'notes',
      'notifications',
      'billing_records',
      'timeline',
      'usermessages'
    ];

    for (String table in tables) {
      print('🔧 Processing table: $table');

      try {
        // Add firebase_user_id column (separate from existing userId/user columns)
        try {
          await db
              .execute('ALTER TABLE $table ADD COLUMN firebase_user_id TEXT');
          print('  ✅ Added firebase_user_id column to $table');
        } catch (e) {
          if (e.toString().contains('duplicate column name')) {
            print('  ✅ firebase_user_id column already exists in $table');
          } else {
            print('  ⚠️ Could not add firebase_user_id to $table: $e');
          }
        }

        // Add firebase_synced column
        try {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN firebase_synced INTEGER DEFAULT 0');
          print('  ✅ Added firebase_synced column to $table');
        } catch (e) {
          if (e.toString().contains('duplicate column name')) {
            print('  ✅ firebase_synced column already exists in $table');
          } else {
            print('  ⚠️ Could not add firebase_synced to $table: $e');
          }
        }

        // Add last_modified column
        try {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN last_modified INTEGER DEFAULT ${DateTime.now().toUtc().millisecondsSinceEpoch}');
          print('  ✅ Added last_modified column to $table');
        } catch (e) {
          if (e.toString().contains('duplicate column name')) {
            print('  ✅ last_modified column already exists in $table');
          } else {
            print('  ⚠️ Could not add last_modified to $table: $e');
          }
        }

        // Add deleted column for soft deletes
        try {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN deleted INTEGER DEFAULT 0');
          print('  ✅ Added deleted column to $table');
        } catch (e) {
          if (e.toString().contains('duplicate column name')) {
            print('  ✅ deleted column already exists in $table');
          } else {
            print('  ⚠️ Could not add deleted to $table: $e');
          }
        }
      } catch (e) {
        print('  ❌ Error processing $table: $e');
      }
    }

    print('🔧 === FIREBASE SYNC COLUMNS ADDED ===\n');
  }

  /// Assign Firebase user ID to all existing records
  Future<void> setFirebaseUserForAllRecords(String firebaseUserId) async {
    final db = await database;

    print('🔧 === SETTING FIREBASE USER FOR ALL RECORDS ===');
    print('🔑 Firebase User ID: $firebaseUserId');

    final tables = [
      'users',
      'schedules',
      'invoices',
      'payments',
      'attachments',
      'notes',
      'notifications'
    ];

    for (String table in tables) {
      try {
        // Update all existing records to have the current firebase_user_id
        await db.execute('''
        UPDATE $table 
        SET firebase_user_id = ?, 
            firebase_synced = 0,
            last_modified = ?
        WHERE firebase_user_id IS NULL OR firebase_user_id = ''
      ''', [firebaseUserId, DateTime.now().toUtc().millisecondsSinceEpoch]);

        // Count how many records were updated
        final countResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $table 
        WHERE firebase_user_id = ?
      ''', [firebaseUserId]);

        final count = countResult.first['count'] as int;
        print('  ✅ $table: Set firebase_user_id for $count records');
      } catch (e) {
        print('  ❌ Error updating $table: $e');
      }
    }

    print('🔧 === FIREBASE USER ASSIGNMENT COMPLETE ===\n');
  }

  /// Complete safe migration
  Future<void> completeSafeMigration() async {
    print('\n🚀 === COMPLETE SAFE MIGRATION ===');

    try {
      // Step 1: Add sync columns (using firebase_user_id instead of user_id)
      await addFirebaseSyncSupport();

      // Step 2: Get Firebase user ID
      final authController = Get.find<AuthController>();
      final firebaseUserId = authController.currentFirebaseUserId;

      if (firebaseUserId == null) {
        print('❌ No Firebase user ID found. Please ensure you are logged in.');
        return;
      }

      // Step 3: Assign firebase_user_id to existing records
      await setFirebaseUserForAllRecords(firebaseUserId);

      print('🚀 === SAFE MIGRATION COMPLETE ===');
      print('✅ Database is ready for sync!');
      print(
          '⚠️  Next step: Update FirebaseSync to use firebase_user_id column');
    } catch (e) {
      print('❌ Error during safe migration: $e');
    }
  }

  // Replace your existing DatabaseHelperSyncExtension methods with these:

  /// Enhanced insert method with debounced sync
  static Future<int> insertWithSync(
      Database db, String table, Map<String, dynamic> values) async {
    // Add sync tracking data
    values['last_modified'] = DateTime.now().toUtc().millisecondsSinceEpoch;
    values['firebase_synced'] = 0;

    // Add firebase_user_id if not present and user is authenticated
    if (values['firebase_user_id'] == null) {
      try {
        final authController = Get.find<AuthController>();
        if (authController.isFirebaseAuthenticated) {
          values['firebase_user_id'] = authController.currentFirebaseUserId;
        }
      } catch (e) {
        print('⚠️ Could not get Firebase user ID: $e');
      }
    }

    final result = await db.insert(table, values);

    // Trigger debounced sync instead of immediate sync
    _triggerSmartSync();

    return result;
  }

// In your enhanced_database_helper.dart updateWithSync method:
  Future<int> updateWithSync(String table, Map<String, dynamic> values,
      {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;

    try {
      final result =
          await db.update(table, values, where: where, whereArgs: whereArgs);

      if (result == 0 && table == 'users') {
        // No rows affected, try insert with conflict resolution
        return await db.insert(table, values,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      return result;
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        return await db.insert(table, values,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      rethrow;
    }
  }

  /// Enhanced delete method with debounced sync
  static Future<int> deleteWithSync(
      Database db, String table, String where, List<dynamic> whereArgs) async {
    try {
      // Try to mark as deleted first (soft delete)
      final result = await db.update(
          table,
          {
            'deleted': 1,
            'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
            'firebase_synced': 0,
          },
          where: where,
          whereArgs: whereArgs);

      // Trigger debounced sync
      _triggerSmartSync();

      return result;
    } catch (e) {
      // If table doesn't have deleted column, do actual delete
      final result = await db.delete(table, where: where, whereArgs: whereArgs);
      _triggerSmartSync();
      return result;
    }
  }

  /// Smart sync triggering with debouncing
  static void _triggerSmartSync() {
    try {
      final syncService = Get.find<MultiTenantFirebaseSyncService>();

      if (syncService.isOnline.value &&
          !syncService.isSyncing.value &&
          syncService.firebaseAvailable.value) {
        // Use debounced sync to prevent too frequent syncs
        syncService.triggerDebouncedSync(delay: const Duration(seconds: 3));

        print('🔄 Smart sync triggered (debounced)');
      } else {
        print('⏸️ Smart sync skipped - conditions not met');
      }
    } catch (e) {
      print('⚠️ Could not trigger smart sync: $e');
    }
  }

  // lib/services/database_helper.dart - Additional methods for school management
// Add these methods to the DatabaseHelper class

  /// Save a known school for future access
  Future<void> saveKnownSchool(Map<String, dynamic> schoolData) async {
    final db = await database;

    try {
      // Check if school already exists
      final existing = await db.query(
        'known_schools',
        where: 'id = ?',
        whereArgs: [schoolData['id']],
      );

      if (existing.isNotEmpty) {
        // Update existing record
        await db.update(
          'known_schools',
          {
            ...schoolData,
            'last_accessed': DateTime.now().toIso8601String(),
            'access_count': (existing.first['access_count'] as int? ?? 0) + 1,
          },
          where: 'id = ?',
          whereArgs: [schoolData['id']],
        );
      } else {
        // Insert new record
        await db.insert('known_schools', {
          ...schoolData,
          'last_accessed': DateTime.now().toIso8601String(),
          'access_count': 1,
        });
      }

      print('✅ Saved known school: ${schoolData['name']}');
    } catch (e) {
      print('❌ Error saving known school: $e');
      throw e;
    }
  }

  /// Get all known schools
  Future<List<Map<String, dynamic>>> getKnownSchools() async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> schools =
          await db.query('known_schools');
      return schools;
    } catch (e) {
      print('❌ Error getting known schools: $e');
      return [];
    }
  }

  /// Clear all known schools
  Future<void> clearKnownSchools() async {
    final db = await database;

    try {
      await db.delete('known_schools');
      print('✅ Cleared all known schools');
    } catch (e) {
      print('❌ Error clearing known schools: $e');
      throw e;
    }
  }
}
