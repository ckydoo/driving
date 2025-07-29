import 'package:driving/models/billing.dart';
import 'package:driving/models/billing_record.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/fleet.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/models/user.dart';
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

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create all tables based on the schema
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
   total_amount REAL NOT NULL 
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
    attended INTEGER NOT NULL DEFAULT 0,
    lessonsCompleted INTEGER DEFAULT 0,
    
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
''');
    await db.execute('''
      CREATE TABLE timeline(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user INTEGER NOT NULL,
        activity TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
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
        email TEXT NOT NULL,
        gender TEXT,
        date_of_birth DATE NOT NULL,
        phone TEXT,
        idnumber TEXT,
        address TEXT,
        password TEXT NOT NULL,
        course TEXT,
        role TEXT NOT NULL,
            courseIds TEXT,
        status TEXT NOT NULL DEFAULT 'Active',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
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

    // **IMPORTANT: Create default admin user immediately after table creation**
    await _createDefaultAdminUser(db);
    print('Database tables created and default admin user inserted');
  }

// Create default admin user - called during database creation
  Future<void> _createDefaultAdminUser(Database db) async {
    try {
      // Check if any admin users exist
      final adminCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM users WHERE LOWER(role) = ?',
        ['admin'],
      );

      final count = adminCount.first['count'] as int;

      if (count == 0) {
        // Hash the password: admin123
        const hashedPassword =
            'c7ad44cbad762a5da0a452f9e854fdc1e0e7a52a38015f23f3eab1d80b931dd472634dfac71cd34ebc35d16ab7fb8a90c81f975113d6c7538dc69dd8de9077ec';

        await db.insert('users', {
          'fname': 'System',
          'lname': 'Administrator',
          'email': 'admin@drivingschool.com',
          'password': hashedPassword,
          'gender': 'Male',
          'phone': '+1234567890',
          'address': '123 Main Street',
          'date_of_birth': '1980-01-01',
          'role': 'admin',
          'status': 'Active',
          'idnumber': 'ADMIN001',
          'created_at': DateTime.now().toIso8601String(),
        });

        print('✅ Default admin user created successfully');
        print('📧 Email: admin@drivingschool.com');
        print('🔑 Password: admin123');

        // Also create a sample instructor for testing
        await db.insert('users', {
          'fname': 'John',
          'lname': 'Instructor',
          'email': 'instructor@drivingschool.com',
          'password': hashedPassword, // Same password: admin123
          'gender': 'Male',
          'phone': '+1234567891',
          'address': '456 Oak Street',
          'date_of_birth': '1985-05-15',
          'role': 'instructor',
          'status': 'Active',
          'idnumber': 'INST001',
          'created_at': DateTime.now().toIso8601String(),
        });

        // Create a sample student for testing
        await db.insert('users', {
          'fname': 'Jane',
          'lname': 'Student',
          'email': 'student@drivingschool.com',
          'password': hashedPassword, // Same password: admin123
          'gender': 'Female',
          'phone': '+1234567892',
          'address': '789 Pine Street',
          'date_of_birth': '1995-03-20',
          'role': 'student',
          'status': 'Active',
          'idnumber': 'STU001',
          'created_at': DateTime.now().toIso8601String(),
        });

        print('✅ Sample users created for testing');
      } else {
        print('ℹ️ Admin user already exists');
      }
    } catch (e) {
      print('❌ Error creating default admin user: $e');
    }
  }

// Add this method to manually create users if needed
  Future<void> ensureDefaultUsersExist() async {
    final db = await database;
    await _createDefaultAdminUser(db);
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final results = await db.query(
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
    final results = await db.query(
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

  Future<bool> emailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  Future<void> updateUserPassword(int userId, String hashedPassword) async {
    final db = await database;
    await db.update(
      'users',
      {'password': hashedPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateUserLastLogin(int userId) async {
    final db = await database;
    await db.update(
      'users',
      {'last_login': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

// Create default admin user if none exists
  Future<void> createDefaultAdmin() async {
    final db = await database;
    final adminCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users WHERE LOWER(role) = ?',
      ['admin'],
    );

    final count = adminCount.first['count'] as int;

    if (count == 0) {
      // Create default admin user
      await db.insert('users', {
        'fname': 'System',
        'lname': 'Administrator',
        'email': 'admin@drivingschool.com',
        'password':
            'c7ad44cbad762a5da0a452f9e854fdc1e0e7a52a38015f23f3eab1d80b931dd472634dfac71cd34ebc35d16ab7fb8a90c81f975113d6c7538dc69dd8de9077ec', // admin123 hashed
        'gender': 'Male',
        'phone': '+1234567890',
        'address': '123 Main Street',
        'date_of_birth': '1980-01-01',
        'role': 'admin',
        'status': 'Active',
        'idnumber': 'ADMIN001',
        'created_at': DateTime.now().toIso8601String(),
      });

      print('Default admin user created: admin@drivingschool.com / admin123');
    }
  }

  // ==================== CRUD Methods for Each Table ====================
// Add these methods to DatabaseHelper class
  Future<int> insertBillingRecord(BillingRecord billingRecord) async {
    final db = await database;
    return await db.insert('billing_records', billingRecord.toJson());
  }

  Future<List<BillingRecord>> getBillingRecordsForInvoice(int invoiceId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'billing_records',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
    );
    return results.map((json) => BillingRecord.fromJson(json)).toList();
  }

  Future<void> updateBillingRecordStatus(
      int billingRecordId, String status) async {
    final db = await database;
    await db.update(
      'billing_records',
      {'status': status},
      where: 'id = ?',
      whereArgs: [billingRecordId],
    );
    // Optionally refresh billing data if needed
    // await fetchBillingData();
  }

  Future<int> insertBillingRecordHistory(BillingRecord billingRecord) async {
    final db = await database;
    return await db.insert('billing_records_history', billingRecord.toJson());
  }

  Future<List<Payment>> getPaymentsForStudent(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where:
          'studentId = ?', // Assuming you have a studentId column in your payments table
      whereArgs: [studentId],
    );
    return List.generate(maps.length, (i) {
      return Payment.fromJson(maps[i]);
    });
  }

  Future<List<Map<String, dynamic>>> getInvoicesWithCourseNamesForStudent(
      int studentId) async {
    final db = await database;
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
    courses.name AS courseName 
FROM invoices
INNER JOIN courses ON invoices.course = courses.id  
WHERE invoices.student = ?  
  ''', [studentId]);
    print(results);
    return results;
  }

  Future<int> deleteBillingRecord(int id) async {
    Database db = await database;
    return await db.delete(
      'billing_records', // Ensure this is your billing record table name
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getBillingForStudent(int studentId) async {
    final db = await database;
    return await db.query(
      'billings',
      where:
          'studentId = ?', // Assuming you have a studentId column in your billings table
      whereArgs: [studentId],
    );
  }

  Future<List<Map<String, dynamic>>> getPayments() async {
    final db = await database;
    return await db.query('payments');
  }

  Future<int> insertPayment(Map<String, dynamic> payment) async {
    final db = await database;
    return await db.insert('payments', payment);
  }

  Future<List<Map<String, dynamic>>> getUsers({String? role}) async {
    final db = await instance.database;
    if (role != null) {
      return await db.query(
        'users',
        where: 'LOWER(role) = ?', // Case-insensitive comparison
        whereArgs: [role.toLowerCase()],
      );
    } else {
      return await db.query('users');
    }
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    return db.insert('users', user.toJson());
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return db.update(
      'users',
      user.toJson(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // Attachments Table
  Future<int> insertAttachment(Map<String, dynamic> attachment) async {
    Database db = await database;
    return await db.insert('attachments', attachment);
  }

  Future<List<Map<String, dynamic>>> getAttachments() async {
    Database db = await database;
    return await db.query('attachments');
  }

  Future<int> updateAttachment(Map<String, dynamic> attachment) async {
    Database db = await database;
    return await db.update(
      'attachments',
      attachment,
      where: 'id = ?',
      whereArgs: [attachment['id']],
    );
  }

  Future<int> deleteAttachment(int id) async {
    Database db = await database;
    return await db.delete(
      'attachments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CourseInstructor Table
  Future<int> insertCourseInstructor(
      Map<String, dynamic> courseInstructor) async {
    Database db = await database;
    return await db.insert('courseinstructor', courseInstructor);
  }

  Future<List<Map<String, dynamic>>> getCourseInstructors() async {
    Database db = await database;
    return await db.query('courseinstructor');
  }

  Future<int> updateCourseInstructor(
      Map<String, dynamic> courseInstructor) async {
    Database db = await database;
    return await db.update(
      'courseinstructor',
      courseInstructor,
      where: 'id = ?',
      whereArgs: [courseInstructor['id']],
    );
  }

  Future<int> deleteCourseInstructor(int id) async {
    Database db = await database;
    return await db.delete(
      'courseinstructor',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Courses Table
  Future<int> insertCourse(Map<String, dynamic> course) async {
    Database db = await database;
    return await db.insert('courses', course);
  }

  Future<List<Map<String, dynamic>>> getCourses() async {
    Database db = await database;
    return await db.query('courses');
  }

  Future<int> updateCourse(Map<String, dynamic> course) async {
    Database db = await database;
    return await db.update(
      'courses',
      course,
      where: 'id = ?',
      whereArgs: [course['id']],
    );
  }

  Future<int> deleteCourse(int id) async {
    Database db = await database;
    return await db.delete(
      'courses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CoursesEnrolled Table
  Future<int> insertCourseEnrolled(Map<String, dynamic> courseEnrolled) async {
    Database db = await database;
    return await db.insert('coursesenrolled', courseEnrolled);
  }

  Future<List<Map<String, dynamic>>> getCoursesEnrolled() async {
    Database db = await database;
    return await db.query('coursesenrolled');
  }

  Future<int> updateCourseEnrolled(Map<String, dynamic> courseEnrolled) async {
    Database db = await database;
    return await db.update(
      'coursesenrolled',
      courseEnrolled,
      where: 'id = ?',
      whereArgs: [courseEnrolled['id']],
    );
  }

  Future<int> deleteCourseEnrolled(int id) async {
    Database db = await database;
    return await db.delete(
      'coursesenrolled',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Currencies Table
  Future<int> insertCurrency(Map<String, dynamic> currency) async {
    Database db = await database;
    return await db.insert('currencies', currency);
  }

  Future<List<Map<String, dynamic>>> getCurrencies() async {
    Database db = await database;
    return await db.query('currencies');
  }

  Future<int> updateCurrency(Map<String, dynamic> currency) async {
    Database db = await database;
    return await db.update(
      'currencies',
      currency,
      where: 'id = ?',
      whereArgs: [currency['id']],
    );
  }

  Future<int> deleteCurrency(int id) async {
    Database db = await database;
    return await db.delete(
      'currencies',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Fleet Table
  Future<int> insertFleet(Map<String, dynamic> fleet) async {
    Database db = await database;
    return await db.insert('fleet', fleet);
  }

  Future<List<Map<String, dynamic>>> getFleet() async {
    Database db = await database;
    return await db.query('fleet');
  }

  Future<int> updateFleet(Map<String, dynamic> fleet) async {
    Database db = await database;
    return await db.update(
      'fleet',
      fleet,
      where: 'id = ?',
      whereArgs: [fleet['id']],
    );
  }

  Future<int> deleteFleet(int id) async {
    Database db = await database;
    return await db.delete(
      'fleet',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Invoices Table
  Future<int> insertInvoice(Map<String, dynamic> invoice) async {
    Database db = await database;
    return await db.insert('invoices', invoice);
  }

  Future<List<Map<String, dynamic>>> getInvoices() async {
    Database db = await database;
    return await db.query('invoices');
  }

  Future<int> updateInvoice(Map<String, dynamic> invoice) async {
    print(
        'DatabaseHelper: Updating invoice with data: $invoice'); // Add this debug line
    final db = await database;
    return await db.update(
      'invoices',
      invoice,
      where: 'id = ?',
      whereArgs: [invoice['id']],
    );
  }

  Future<int> deleteInvoice(int id) async {
    Database db = await database;
    return await db.delete(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAttachmentsForStudent(
      int studentId) async {
    final db = await database;
    return await db.query(
      'attachments',
      where: 'attachment_for = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getNotesForStudent(int studentId) async {
    final db = await database;
    return await db.query(
      'notes',
      where: 'note_for = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC', // Order by creation time if needed
    );
  }

  // Notes Table
  Future<int> insertNote(Map<String, dynamic> note) async {
    Database db = await database;
    print('Note saved');
    return await db.insert('notes', note);
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    Database db = await database;
    return await db.query('notes');
  }

  Future<int> updateNote(Map<String, dynamic> note) async {
    Database db = await database;
    return await db.update(
      'notes',
      note,
      where: 'id = ?',
      whereArgs: [note['id']],
    );
  }

  Future<int> deleteNote(int id) async {
    Database db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Notifications Table

  Future<int> insertNotification(Map<String, dynamic> notification) async {
    Database db = await database;
    return await db.insert('notifications', notification);
  }

  Future<List<Map<String, dynamic>>> getNotificationsForUser(int userId) async {
    Database db = await database;
    return await db.query(
      'notifications',
      where: 'user = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updateNotification(Map<String, dynamic> notification) async {
    Database db = await database;
    return await db.update(
      'notifications',
      notification,
      where: 'id = ?',
      whereArgs: [notification['id']],
    );
  }

  Future<int> deleteNotification(int id) async {
    Database db = await database;
    return await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updatePayment(Map<String, dynamic> payment) async {
    Database db = await database;
    return await db.update(
      'payments',
      payment,
      where: 'id = ?',
      whereArgs: [payment['id']],
    );
  }

  Future<int> deletePayment(int id) async {
    Database db = await database;
    return await db.delete(
      'payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  List<Fleet> fleet = [];

  Future<void> fetchFleet() async {
    final List<Map<String, dynamic>> maps = await _database!.query('fleet');
    fleet = maps.map((map) => Fleet.fromMap(map)).toList();
  }

  Future<void> saveFleet(List<Fleet> newFleet) async {
    for (final vehicle in newFleet) {
      await _database!.insert(
        'fleet',
        vehicle.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await fetchFleet(); // Refresh the list after saving
  }

  Future<Course?> getCourseById(int courseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
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

  // Reminders Table
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    Database db = await database;
    return await db.insert('reminders', reminder);
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    Database db = await database;
    return await db.query('reminders');
  }

  Future<int> updateReminder(Map<String, dynamic> reminder) async {
    Database db = await database;
    return await db.update(
      'reminders',
      reminder,
      where: 'id = ?',
      whereArgs: [reminder['id']],
    );
  }

  Future<int> deleteReminder(int id) async {
    Database db = await database;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Schedules Table
  Future<int> insertSchedule(Map<String, dynamic> schedule) async {
    Database db = await database;
    return await db.insert('schedules', schedule);
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    Database db = await database;
    return await db.query('schedules');
  }

  Future<int> updateSchedule(Map<String, dynamic> schedule) async {
    Database db = await database;
    return await db.update(
      'schedules',
      schedule,
      where: 'id = ?',
      whereArgs: [schedule['id']],
    );
  }

  Future<int> deleteSchedule(int id) async {
    Database db = await database;
    return await db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Timeline Table
  Future<int> insertTimeline(Map<String, dynamic> timeline) async {
    Database db = await database;
    return await db.insert('timeline', timeline);
  }

  Future<List<Map<String, dynamic>>> getTimeline() async {
    Database db = await database;
    return await db.query('timeline');
  }

  Future<int> updateTimeline(Map<String, dynamic> timeline) async {
    Database db = await database;
    return await db.update(
      'timeline',
      timeline,
      where: 'id = ?',
      whereArgs: [timeline['id']],
    );
  }

  Future<int> deleteTimeline(int id) async {
    Database db = await database;
    return await db.delete(
      'timeline',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // UserMessages Table
  Future<int> insertUserMessage(Map<String, dynamic> userMessage) async {
    Database db = await database;
    return await db.insert('usermessages', userMessage);
  }

  Future<List<Map<String, dynamic>>> getUserMessages() async {
    Database db = await database;
    return await db.query('usermessages');
  }

  Future<int> updateUserMessage(Map<String, dynamic> userMessage) async {
    Database db = await database;
    return await db.update(
      'usermessages',
      userMessage,
      where: 'id = ?',
      whereArgs: [userMessage['id']],
    );
  }

  Future<int> deleteUserMessage(int id) async {
    Database db = await database;
    return await db.delete(
      'usermessages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Billing?> getBillingForSchedule(int scheduleId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'billings', // Replace with your billing table name
      where:
          'scheduleId = ?', // Assuming you have a scheduleId column in your billing table
      whereArgs: [scheduleId],
    );
    if (maps.isNotEmpty) {
      return Billing.fromJson(maps.first);
    }
    return null;
  }

  Future<List<Payment>> getPaymentsForSchedule(int scheduleId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments', // Replace with your payments table name
      where:
          'scheduleId = ?', // Assuming you have a scheduleId column in your payments table
      whereArgs: [scheduleId],
    );
    return List.generate(maps.length, (i) {
      return Payment.fromJson(maps[i]);
    });
  }
}
