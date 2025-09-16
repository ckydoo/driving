// Simplified DatabaseHelper without Firebase sync
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
    print('Database tables created');
  }

  Future<void> _createAllTables(Database db) async {
    // === SETTINGS TABLE ===
    await db.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // === ATTACHMENTS TABLE ===
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

    // === COURSE INSTRUCTOR MAPPING ===
    await db.execute('''
      CREATE TABLE courseinstructor(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        instructor INTEGER NOT NULL,
        course INTEGER NOT NULL
      )
    ''');

    // === COURSES TABLE ===
    await db.execute('''
      CREATE TABLE courses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // === COURSE ENROLLMENT ===
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

    // === CURRENCIES TABLE ===
    await db.execute('''
      CREATE TABLE currencies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        symbol TEXT NOT NULL
      )
    ''');

    // === FLEET TABLE ===
    await db.execute('''
      CREATE TABLE fleet(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carplate TEXT NOT NULL,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        modelyear TEXT NOT NULL,
        instructor INTEGER
      )
    ''');

    // === INVOICES TABLE ===
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
       courseName TEXT,
       status TEXT NOT NULL DEFAULT 'unpaid',
       total_amount REAL NOT NULL,
       used_lessons INTEGER NOT NULL DEFAULT 0,
       invoice_number TEXT NOT NULL UNIQUE
      )
    ''');

    // === NOTES TABLE ===
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_by INTEGER NOT NULL,
        note_for INTEGER NOT NULL,
        note TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // === NOTIFICATIONS TABLE ===
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

    // === REMINDERS TABLE ===
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

    // === SCHEDULES TABLE ===
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

    // === TIMELINE TABLE ===
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

    // === USER MESSAGES TABLE ===
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

    // === BILLING RECORDS TABLE ===
    await db.execute('''
      CREATE TABLE billing_records (
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

    // === USERS TABLE ===
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
        last_login TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_login_method TEXT
      )
    ''');

    // === PAYMENTS TABLE ===
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
        receipt_generated_at TEXT,
        cloud_storage_path TEXT,
        receipt_file_size INTEGER,
        receipt_type TEXT,
        receipt_generated INTEGER NOT NULL DEFAULT 0,
        userId INTEGER REFERENCES users(id),
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // === BILLINGS TABLE ===
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

    // === BILLING RECORDS HISTORY TABLE ===
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

    // === KNOWN SCHOOLS TABLE ===
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

    print('✅ All tables created');
  }

  // ==================== SIMPLIFIED CRUD METHODS ====================

  // ================ USERS TABLE ================
  Future<int> insertUser(Map<String, dynamic> user) async {
    try {
      final db = await database;

      // Remove ID for new users (auto-generated)
      user.remove('id');

      // Validate required fields
      if (user['email'] == null || user['email'].toString().trim().isEmpty) {
        throw Exception('Email is required');
      }

      // Set default values
      user['created_at'] ??= DateTime.now().toIso8601String();
      user['status'] ??= 'Active';
      user['role'] ??= 'student';

      print('📝 Inserting user data: ${user['email']}');

      // Check for existing user BEFORE inserting
      final existingUsers = await db.query('users',
          where: 'idnumber = ? OR email = ?',
          whereArgs: [user['idnumber'], user['email']]);

      if (existingUsers.isNotEmpty) {
        final existing = existingUsers.first;
        print('User already exists: ${existing['email']}, updating instead...');

        // Update existing user instead
        user['id'] = existing['id'];
        final updatedRows = await db.update('users', user,
            where: 'id = ?', whereArgs: [existing['id']]);

        if (updatedRows > 0) {
          print('✅ User updated successfully: ${existing['id']}');
          return existing['id'] as int;
        }
      }

      // Insert new user if not exists
      final insertedId = await db.insert('users', user);

      if (insertedId <= 0) {
        throw Exception(
            'Failed to insert user - invalid ID returned: $insertedId');
      }

      print('✅ User inserted successfully with ID: $insertedId');
      return insertedId;
    } catch (e) {
      print('❌ Error inserting user: $e');

      // Provide specific error messages
      if (e.toString().contains('UNIQUE constraint failed')) {
        if (e.toString().contains('users.email')) {
          throw Exception('Email address is already registered');
        } else if (e.toString().contains('users.phone')) {
          throw Exception('Phone number is already registered');
        } else if (e.toString().contains('users.idnumber')) {
          throw Exception('ID number is already registered');
        }
      }

      throw Exception('Failed to save user: ${e.toString()}');
    }
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    try {
      final db = await database;

      if (user['id'] == null || user['id'] <= 0) {
        throw Exception('Invalid user ID for update');
      }

      // Validate required fields
      if (user['email'] == null || user['email'].toString().trim().isEmpty) {
        throw Exception('Email is required');
      }

      print('📝 Updating user data: ID ${user['id']}, Email ${user['email']}');

      final rowsAffected = await db.update(
        'users',
        user,
        where: 'id = ?',
        whereArgs: [user['id']],
      );

      if (rowsAffected == 0) {
        throw Exception('No user found with ID ${user['id']}');
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
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getUsers({String? role}) async {
    final db = await database;
    if (role != null) {
      return await db.query('users',
          where: 'LOWER(role) = ?', whereArgs: [role.toLowerCase()]);
    } else {
      return await db.query('users');
    }
  }

  // ================ SCHEDULES TABLE ================
  Future<int> insertSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    return await db.insert('schedules', schedule);
  }

  Future<int> updateSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    return await db.update('schedules', schedule,
        where: 'id = ?', whereArgs: [schedule['id']]);
  }

  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await database;
    return await db.query('schedules');
  }

  // ================ COURSES TABLE ================
  Future<int> insertCourse(Map<String, dynamic> course) async {
    final db = await database;
    return await db.insert('courses', course);
  }

  Future<int> updateCourse(Map<String, dynamic> course) async {
    final db = await database;
    return await db
        .update('courses', course, where: 'id = ?', whereArgs: [course['id']]);
  }

  Future<int> deleteCourse(int id) async {
    final db = await database;
    return await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getCourses() async {
    final db = await database;
    return await db.query('courses');
  }

  // ================ INVOICES TABLE ================
  Future<int> insertInvoice(Map<String, dynamic> invoice) async {
    final db = await database;
    return await db.insert('invoices', invoice);
  }

  Future<int> updateInvoice(Map<String, dynamic> invoice) async {
    print('DatabaseHelper: Updating invoice with data: $invoice');
    final db = await database;
    return await db.update('invoices', invoice,
        where: 'id = ?', whereArgs: [invoice['id']]);
  }

  Future<int> deleteInvoice(int id) async {
    final db = await database;
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getInvoices() async {
    final db = await database;
    return await db.query('invoices');
  }

  // ================ PAYMENTS TABLE ================
  Future<int> insertPayment(Map<String, dynamic> payment) async {
    final db = await database;
    return await db.insert('payments', payment);
  }

  Future<int> updatePayment(Map<String, dynamic> payment) async {
    final db = await database;
    return await db.update('payments', payment,
        where: 'id = ?', whereArgs: [payment['id']]);
  }

  Future<int> deletePayment(int id) async {
    final db = await database;
    return await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getPayments() async {
    final db = await database;
    return await db.query('payments');
  }

  // ================ FLEET TABLE ================
  Future<int> insertFleet(Map<String, dynamic> fleet) async {
    final db = await database;
    return await db.insert('fleet', fleet);
  }

  Future<int> updateFleet(Map<String, dynamic> fleet) async {
    final db = await database;
    return await db
        .update('fleet', fleet, where: 'id = ?', whereArgs: [fleet['id']]);
  }

  Future<int> deleteFleet(int id) async {
    final db = await database;
    return await db.delete('fleet', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getFleet() async {
    final db = await database;
    return await db.query('fleet');
  }

  // ================ ATTACHMENTS TABLE ================
  Future<int> insertAttachment(Map<String, dynamic> attachment) async {
    final db = await database;
    return await db.insert('attachments', attachment);
  }

  Future<int> updateAttachment(Map<String, dynamic> attachment) async {
    final db = await database;
    return await db.update('attachments', attachment,
        where: 'id = ?', whereArgs: [attachment['id']]);
  }

  Future<int> deleteAttachment(int id) async {
    final db = await database;
    return await db.delete('attachments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAttachments() async {
    final db = await database;
    return await db.query('attachments');
  }

  // ================ NOTES TABLE ================
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    print('Note saved');
    return await db.insert('notes', note);
  }

  Future<int> updateNote(Map<String, dynamic> note) async {
    final db = await database;
    return await db
        .update('notes', note, where: 'id = ?', whereArgs: [note['id']]);
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await database;
    return await db.query('notes');
  }

  // ================ NOTIFICATIONS TABLE ================
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return await db.insert('notifications', notification);
  }

  Future<int> updateNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return await db.update('notifications', notification,
        where: 'id = ?', whereArgs: [notification['id']]);
  }

  Future<int> deleteNotification(int id) async {
    final db = await database;
    return await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getNotificationsForUser(int userId) async {
    final db = await database;
    return await db.query('notifications',
        where: 'user = ?', whereArgs: [userId], orderBy: 'created_at DESC');
  }

  // ================ BILLING RECORDS TABLE ================
  Future<int> insertBillingRecord(Map<String, dynamic> billingRecord) async {
    final db = await database;
    return await db.insert('billing_records', billingRecord);
  }

  Future<void> updateBillingRecordStatus(
      int billingRecordId, String status) async {
    final db = await database;
    await db.update('billing_records', {'status': status},
        where: 'id = ?', whereArgs: [billingRecordId]);
  }

  Future<int> deleteBillingRecord(int id) async {
    final db = await database;
    return await db.delete('billing_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getBillingRecordsForInvoice(
      int invoiceId) async {
    final db = await database;
    return await db.query('billing_records',
        where: 'invoiceId = ?', whereArgs: [invoiceId]);
  }

  // ==================== SPECIALIZED QUERY METHODS ====================
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final results = await db.query('users',
        where: 'LOWER(email) = ?', whereArgs: [email.toLowerCase()], limit: 1);

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final results =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCourseById(int courseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('courses', where: 'id = ?', whereArgs: [courseId]);

    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getInvoicesWithCourseNamesForStudent(
      int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
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
    ''',
      [studentId],
    );
    print(results);
    return results;
  }

  Future<List<Map<String, dynamic>>> getAttachmentsForStudent(
      int studentId) async {
    final db = await database;
    return await db.query('attachments',
        where: 'attachment_for = ?',
        whereArgs: [studentId],
        orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getNotesForStudent(int studentId) async {
    final db = await database;
    return await db.query('notes',
        where: 'note_for = ?',
        whereArgs: [studentId],
        orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getPaymentsForStudent(
      int studentId) async {
    final db = await database;
    return await db
        .query('payments', where: 'studentId = ?', whereArgs: [studentId]);
  }

  Future<List<Map<String, dynamic>>> getPaymentsForSchedule(
      int scheduleId) async {
    final db = await database;
    return await db
        .query('payments', where: 'scheduleId = ?', whereArgs: [scheduleId]);
  }

  Future<List<Map<String, dynamic>>> getBillingForStudent(int studentId) async {
    final db = await database;
    return await db
        .query('billings', where: 'studentId = ?', whereArgs: [studentId]);
  }

  Future<Map<String, dynamic>?> getBillingForSchedule(int scheduleId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db
        .query('billings', where: 'scheduleId = ?', whereArgs: [scheduleId]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // ==================== NON-SYNC METHODS ====================
  Future<bool> emailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  Future<void> updateUserPassword(int userId, String hashedPassword) async {
    final db = await database;
    await db.update('users', {'password': hashedPassword},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> updateUserLastLogin(int userId) async {
    final db = await database;
    await db.update('users', {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [userId]);
  }

  // ==================== REMAINING TABLES ====================

  // ================ COURSE INSTRUCTOR TABLE ================
  Future<int> insertCourseInstructor(
      Map<String, dynamic> courseInstructor) async {
    final db = await database;
    return await db.insert('courseinstructor', courseInstructor);
  }

  Future<int> updateCourseInstructor(
      Map<String, dynamic> courseInstructor) async {
    final db = await database;
    return await db.update('courseinstructor', courseInstructor,
        where: 'id = ?', whereArgs: [courseInstructor['id']]);
  }

  Future<int> deleteCourseInstructor(int id) async {
    final db = await database;
    return await db
        .delete('courseinstructor', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getCourseInstructors() async {
    final db = await database;
    return await db.query('courseinstructor');
  }

  // ================ COURSES ENROLLED TABLE ================
  Future<int> insertCourseEnrolled(Map<String, dynamic> courseEnrolled) async {
    final db = await database;
    return await db.insert('coursesenrolled', courseEnrolled);
  }

  Future<int> updateCourseEnrolled(Map<String, dynamic> courseEnrolled) async {
    final db = await database;
    return await db.update('coursesenrolled', courseEnrolled,
        where: 'id = ?', whereArgs: [courseEnrolled['id']]);
  }

  Future<int> deleteCourseEnrolled(int id) async {
    final db = await database;
    return await db.delete('coursesenrolled', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getCoursesEnrolled() async {
    final db = await database;
    return await db.query('coursesenrolled');
  }

  // ================ CURRENCIES TABLE ================
  Future<int> insertCurrency(Map<String, dynamic> currency) async {
    final db = await database;
    return await db.insert('currencies', currency);
  }

  Future<int> updateCurrency(Map<String, dynamic> currency) async {
    final db = await database;
    return await db.update('currencies', currency,
        where: 'id = ?', whereArgs: [currency['id']]);
  }

  Future<int> deleteCurrency(int id) async {
    final db = await database;
    return await db.delete('currencies', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getCurrencies() async {
    final db = await database;
    return await db.query('currencies');
  }

  // ================ REMINDERS TABLE ================
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder);
  }

  Future<int> updateReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.update('reminders', reminder,
        where: 'id = ?', whereArgs: [reminder['id']]);
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await database;
    return await db.query('reminders');
  }

  // ================ TIMELINE TABLE ================
  Future<int> insertTimeline(Map<String, dynamic> timeline) async {
    final db = await database;
    return await db.insert('timeline', timeline);
  }

  Future<int> updateTimeline(Map<String, dynamic> timeline) async {
    final db = await database;
    return await db.update('timeline', timeline,
        where: 'id = ?', whereArgs: [timeline['id']]);
  }

  Future<int> deleteTimeline(int id) async {
    final db = await database;
    return await db.delete('timeline', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getTimeline() async {
    final db = await database;
    return await db.query('timeline');
  }

  // ================ USER MESSAGES TABLE ================
  Future<int> insertUserMessage(Map<String, dynamic> userMessage) async {
    final db = await database;
    return await db.insert('usermessages', userMessage);
  }

  Future<int> updateUserMessage(Map<String, dynamic> userMessage) async {
    final db = await database;
    return await db.update('usermessages', userMessage,
        where: 'id = ?', whereArgs: [userMessage['id']]);
  }

  Future<int> deleteUserMessage(int id) async {
    final db = await database;
    return await db.delete('usermessages', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getUserMessages() async {
    final db = await database;
    return await db.query('usermessages');
  }

  // ================ BILLING RECORDS HISTORY TABLE ================
  Future<int> insertBillingRecordHistory(
      Map<String, dynamic> billingRecord) async {
    final db = await database;
    return await db.insert('billing_records_history', billingRecord);
  }

  // ================ KNOWN SCHOOLS TABLE ================
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
      final List<Map<String, dynamic>> schools = await db.query(
        'known_schools',
      );
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
