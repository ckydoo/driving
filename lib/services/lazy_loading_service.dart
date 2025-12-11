import 'package:sqflite/sqflite.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/user.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/models/fleet.dart';

/// Lazy loading service for efficient data pagination
/// Reduces initial load time by only loading visible data
class LazyLoadingService {
  static const int INITIAL_LOAD_SIZE = 50;
  static const int PAGE_SIZE = 25;

  /// Load initial schedules (recent + upcoming)
  /// Only loads last 30 days + future schedules for fast startup
  static Future<Map<String, dynamic>> loadInitialSchedules({
    required String? schoolId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 30));

    try {
      // Load only recent schedules (last 30 days + upcoming)
      final maps = await db.query(
        'schedules',
        where: schoolId != null ? 'school_id = ? AND start >= ?' : 'start >= ?',
        whereArgs: schoolId != null
            ? [schoolId, oneMonthAgo.toIso8601String()]
            : [oneMonthAgo.toIso8601String()],
        orderBy: 'start DESC',
        limit: INITIAL_LOAD_SIZE,
      );

      final schedules = maps.map((m) => Schedule.fromJson(m)).toList();
      final hasMore = maps.length >= INITIAL_LOAD_SIZE;

      return {
        'schedules': schedules,
        'hasMore': hasMore,
        'offset': INITIAL_LOAD_SIZE,
      };
    } catch (e) {
      print('❌ Error loading initial schedules: $e');
      return {
        'schedules': <Schedule>[],
        'hasMore': false,
        'offset': 0,
      };
    }
  }

  /// Load more schedules (pagination)
  static Future<Map<String, dynamic>> loadMoreSchedules({
    required String? schoolId,
    required int offset,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'schedules',
        where: schoolId != null ? 'school_id = ?' : null,
        whereArgs: schoolId != null ? [schoolId] : null,
        orderBy: 'start DESC',
        limit: PAGE_SIZE,
        offset: offset,
      );

      final schedules = maps.map((m) => Schedule.fromJson(m)).toList();
      final hasMore = maps.length >= PAGE_SIZE;

      return {
        'schedules': schedules,
        'hasMore': hasMore,
        'offset': offset + PAGE_SIZE,
      };
    } catch (e) {
      print('❌ Error loading more schedules: $e');
      return {
        'schedules': <Schedule>[],
        'hasMore': false,
        'offset': offset,
      };
    }
  }

  /// Load schedules for a specific date range (efficient filtering)
  static Future<List<Schedule>> loadSchedulesForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    required String? schoolId,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'schedules',
        where: schoolId != null
            ? 'school_id = ? AND start >= ? AND start <= ?'
            : 'start >= ? AND start <= ?',
        whereArgs: schoolId != null
            ? [schoolId, startDate.toIso8601String(), endDate.toIso8601String()]
            : [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'start ASC',
      );

      return maps.map((m) => Schedule.fromJson(m)).toList();
    } catch (e) {
      print('❌ Error loading schedules for date range: $e');
      return [];
    }
  }

  /// Load schedules for a specific student (efficient lookup with index)
  static Future<List<Schedule>> loadSchedulesForStudent({
    required int studentId,
    required String? schoolId,
    int? limit,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'schedules',
        where: schoolId != null
            ? 'school_id = ? AND studentId = ?'
            : 'studentId = ?',
        whereArgs: schoolId != null ? [schoolId, studentId] : [studentId],
        orderBy: 'start DESC',
        limit: limit,
      );

      return maps.map((m) => Schedule.fromJson(m)).toList();
    } catch (e) {
      print('❌ Error loading schedules for student: $e');
      return [];
    }
  }

  /// Load schedules by status (efficient lookup with index)
  static Future<List<Schedule>> loadSchedulesByStatus({
    required String status,
    required String? schoolId,
    int? limit,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'schedules',
        where: schoolId != null
            ? 'school_id = ? AND status = ?'
            : 'status = ?',
        whereArgs: schoolId != null ? [schoolId, status] : [status],
        orderBy: 'start DESC',
        limit: limit,
      );

      return maps.map((m) => Schedule.fromJson(m)).toList();
    } catch (e) {
      print('❌ Error loading schedules by status: $e');
      return [];
    }
  }

  /// Get total count of schedules (fast - uses indexes)
  static Future<int> getTotalScheduleCount({
    required String? schoolId,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final result = await db.rawQuery(
        schoolId != null
            ? 'SELECT COUNT(*) as count FROM schedules WHERE school_id = ?'
            : 'SELECT COUNT(*) as count FROM schedules',
        schoolId != null ? [schoolId] : null,
      );

      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error getting schedule count: $e');
      return 0;
    }
  }

  /// Search schedules (optimized with limit)
  static Future<List<Schedule>> searchSchedules({
    required String query,
    required String? schoolId,
    int limit = 50,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Search in student name, instructor name, or notes
      final maps = await db.rawQuery(
        '''
        SELECT s.* FROM schedules s
        LEFT JOIN users student ON s.studentId = student.id
        LEFT JOIN users instructor ON s.instructorId = instructor.id
        WHERE ${schoolId != null ? 's.school_id = ? AND ' : ''}
        (
          student.fname LIKE ? OR
          student.lname LIKE ? OR
          instructor.fname LIKE ? OR
          instructor.lname LIKE ? OR
          s.notes LIKE ?
        )
        ORDER BY s.start DESC
        LIMIT ?
        ''',
        schoolId != null
            ? [
                schoolId,
                '%$query%',
                '%$query%',
                '%$query%',
                '%$query%',
                '%$query%',
                limit,
              ]
            : [
                '%$query%',
                '%$query%',
                '%$query%',
                '%$query%',
                '%$query%',
                limit,
              ],
      );

      return maps.map((m) => Schedule.fromJson(m)).toList();
    } catch (e) {
      print('❌ Error searching schedules: $e');
      return [];
    }
  }

  // ============================================================
  // USER LAZY LOADING METHODS
  // ============================================================

  /// Load initial users (paginated)
  static Future<Map<String, dynamic>> loadInitialUsers({
    required String? schoolId,
    String? role, // Optional: filter by role (student, instructor, etc.)
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      String? whereClause;
      List<dynamic>? whereArgs;

      if (schoolId != null && role != null) {
        whereClause = 'school_id = ? AND role = ?';
        whereArgs = [schoolId, role];
      } else if (schoolId != null) {
        whereClause = 'school_id = ?';
        whereArgs = [schoolId];
      } else if (role != null) {
        whereClause = 'role = ?';
        whereArgs = [role];
      }

      final maps = await db.query(
        'users',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
        limit: INITIAL_LOAD_SIZE,
      );

      final users = maps.map((m) => User.fromJson(m)).toList();
      final hasMore = maps.length >= INITIAL_LOAD_SIZE;

      return {
        'users': users,
        'hasMore': hasMore,
        'offset': INITIAL_LOAD_SIZE,
      };
    } catch (e) {
      print('❌ Error loading initial users: $e');
      return {
        'users': <User>[],
        'hasMore': false,
        'offset': 0,
      };
    }
  }

  /// Load more users (pagination)
  static Future<Map<String, dynamic>> loadMoreUsers({
    required String? schoolId,
    required int offset,
    String? role,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      String? whereClause;
      List<dynamic>? whereArgs;

      if (schoolId != null && role != null) {
        whereClause = 'school_id = ? AND role = ?';
        whereArgs = [schoolId, role];
      } else if (schoolId != null) {
        whereClause = 'school_id = ?';
        whereArgs = [schoolId];
      } else if (role != null) {
        whereClause = 'role = ?';
        whereArgs = [role];
      }

      final maps = await db.query(
        'users',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
        limit: PAGE_SIZE,
        offset: offset,
      );

      final users = maps.map((m) => User.fromJson(m)).toList();
      final hasMore = maps.length >= PAGE_SIZE;

      return {
        'users': users,
        'hasMore': hasMore,
        'offset': offset + PAGE_SIZE,
      };
    } catch (e) {
      print('❌ Error loading more users: $e');
      return {
        'users': <User>[],
        'hasMore': false,
        'offset': offset,
      };
    }
  }

  /// Search users by name or email
  static Future<List<User>> searchUsers({
    required String query,
    required String? schoolId,
    String? role,
    int limit = 50,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      String whereClause = '(fname LIKE ? OR lname LIKE ? OR email LIKE ?)';
      List<dynamic> whereArgs = ['%$query%', '%$query%', '%$query%'];

      if (schoolId != null) {
        whereClause = 'school_id = ? AND $whereClause';
        whereArgs.insert(0, schoolId);
      }

      if (role != null) {
        whereClause = '$whereClause AND role = ?';
        whereArgs.add(role);
      }

      final maps = await db.query(
        'users',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'fname ASC',
        limit: limit,
      );

      return maps.map((m) => User.fromJson(m)).toList();
    } catch (e) {
      print('❌ Error searching users: $e');
      return [];
    }
  }

  // ============================================================
  // COURSE LAZY LOADING METHODS
  // ============================================================

  /// Load initial courses
  static Future<Map<String, dynamic>> loadInitialCourses({
    required String? schoolId,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'courses',
        where: schoolId != null ? 'school_id = ?' : null,
        whereArgs: schoolId != null ? [schoolId] : null,
        orderBy: 'name ASC',
        limit: INITIAL_LOAD_SIZE,
      );

      final courses = maps.map((m) => Course.fromJson(m)).toList();
      final hasMore = maps.length >= INITIAL_LOAD_SIZE;

      return {
        'courses': courses,
        'hasMore': hasMore,
        'offset': INITIAL_LOAD_SIZE,
      };
    } catch (e) {
      print('❌ Error loading initial courses: $e');
      return {
        'courses': <Course>[],
        'hasMore': false,
        'offset': 0,
      };
    }
  }

  /// Load more courses (pagination)
  static Future<Map<String, dynamic>> loadMoreCourses({
    required String? schoolId,
    required int offset,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'courses',
        where: schoolId != null ? 'school_id = ?' : null,
        whereArgs: schoolId != null ? [schoolId] : null,
        orderBy: 'name ASC',
        limit: PAGE_SIZE,
        offset: offset,
      );

      final courses = maps.map((m) => Course.fromJson(m)).toList();
      final hasMore = maps.length >= PAGE_SIZE;

      return {
        'courses': courses,
        'hasMore': hasMore,
        'offset': offset + PAGE_SIZE,
      };
    } catch (e) {
      print('❌ Error loading more courses: $e');
      return {
        'courses': <Course>[],
        'hasMore': false,
        'offset': offset,
      };
    }
  }

  // ============================================================
  // INVOICE/PAYMENT LAZY LOADING METHODS
  // ============================================================

  /// Load initial invoices (most recent first)
  static Future<Map<String, dynamic>> loadInitialInvoices({
    required String? schoolId,
    String? status, // Optional: filter by status (paid, unpaid, overdue)
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      String? whereClause;
      List<dynamic>? whereArgs;

      if (schoolId != null && status != null) {
        whereClause = 'school_id = ? AND status = ?';
        whereArgs = [schoolId, status];
      } else if (schoolId != null) {
        whereClause = 'school_id = ?';
        whereArgs = [schoolId];
      } else if (status != null) {
        whereClause = 'status = ?';
        whereArgs = [status];
      }

      final maps = await db.query(
        'invoices',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
        limit: INITIAL_LOAD_SIZE,
      );

      final invoices = maps.map((m) => Invoice.fromJson(m)).toList();
      final hasMore = maps.length >= INITIAL_LOAD_SIZE;

      return {
        'invoices': invoices,
        'hasMore': hasMore,
        'offset': INITIAL_LOAD_SIZE,
      };
    } catch (e) {
      print('❌ Error loading initial invoices: $e');
      return {
        'invoices': <Invoice>[],
        'hasMore': false,
        'offset': 0,
      };
    }
  }

  /// Load more invoices (pagination)
  static Future<Map<String, dynamic>> loadMoreInvoices({
    required String? schoolId,
    required int offset,
    String? status,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      String? whereClause;
      List<dynamic>? whereArgs;

      if (schoolId != null && status != null) {
        whereClause = 'school_id = ? AND status = ?';
        whereArgs = [schoolId, status];
      } else if (schoolId != null) {
        whereClause = 'school_id = ?';
        whereArgs = [schoolId];
      } else if (status != null) {
        whereClause = 'status = ?';
        whereArgs = [status];
      }

      final maps = await db.query(
        'invoices',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
        limit: PAGE_SIZE,
        offset: offset,
      );

      final invoices = maps.map((m) => Invoice.fromJson(m)).toList();
      final hasMore = maps.length >= PAGE_SIZE;

      return {
        'invoices': invoices,
        'hasMore': hasMore,
        'offset': offset + PAGE_SIZE,
      };
    } catch (e) {
      print('❌ Error loading more invoices: $e');
      return {
        'invoices': <Invoice>[],
        'hasMore': false,
        'offset': offset,
      };
    }
  }

  /// Load initial payments
  static Future<Map<String, dynamic>> loadInitialPayments({
    required String? schoolId,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'payments',
        where: schoolId != null ? 'school_id = ?' : null,
        whereArgs: schoolId != null ? [schoolId] : null,
        orderBy: 'created_at DESC',
        limit: INITIAL_LOAD_SIZE,
      );

      final payments = maps.map((m) => Payment.fromJson(m)).toList();
      final hasMore = maps.length >= INITIAL_LOAD_SIZE;

      return {
        'payments': payments,
        'hasMore': hasMore,
        'offset': INITIAL_LOAD_SIZE,
      };
    } catch (e) {
      print('❌ Error loading initial payments: $e');
      return {
        'payments': <Payment>[],
        'hasMore': false,
        'offset': 0,
      };
    }
  }

  /// Load more payments (pagination)
  static Future<Map<String, dynamic>> loadMorePayments({
    required String? schoolId,
    required int offset,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'payments',
        where: schoolId != null ? 'school_id = ?' : null,
        whereArgs: schoolId != null ? [schoolId] : null,
        orderBy: 'created_at DESC',
        limit: PAGE_SIZE,
        offset: offset,
      );

      final payments = maps.map((m) => Payment.fromJson(m)).toList();
      final hasMore = maps.length >= PAGE_SIZE;

      return {
        'payments': payments,
        'hasMore': hasMore,
        'offset': offset + PAGE_SIZE,
      };
    } catch (e) {
      print('❌ Error loading more payments: $e');
      return {
        'payments': <Payment>[],
        'hasMore': false,
        'offset': offset,
      };
    }
  }

  // ============================================================
  // FLEET LAZY LOADING METHODS
  // ============================================================

  /// Load initial fleet vehicles
  static Future<Map<String, dynamic>> loadInitialFleet({
    required String? schoolId,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'fleet',
        where: schoolId != null ? 'school_id = ?' : null,
        whereArgs: schoolId != null ? [schoolId] : null,
        orderBy: 'make ASC, model ASC',
        limit: INITIAL_LOAD_SIZE,
      );

      final fleet = maps.map((m) => Fleet.fromJson(m)).toList();
      final hasMore = maps.length >= INITIAL_LOAD_SIZE;

      return {
        'fleet': fleet,
        'hasMore': hasMore,
        'offset': INITIAL_LOAD_SIZE,
      };
    } catch (e) {
      print('❌ Error loading initial fleet: $e');
      return {
        'fleet': <Fleet>[],
        'hasMore': false,
        'offset': 0,
      };
    }
  }

  /// Load more fleet vehicles (pagination)
  static Future<Map<String, dynamic>> loadMoreFleet({
    required String? schoolId,
    required int offset,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final maps = await db.query(
        'fleet',
        where: schoolId != null ? 'school_id = ?' : null,
        whereArgs: schoolId != null ? [schoolId] : null,
        orderBy: 'make ASC, model ASC',
        limit: PAGE_SIZE,
        offset: offset,
      );

      final fleet = maps.map((m) => Fleet.fromJson(m)).toList();
      final hasMore = maps.length >= PAGE_SIZE;

      return {
        'fleet': fleet,
        'hasMore': hasMore,
        'offset': offset + PAGE_SIZE,
      };
    } catch (e) {
      print('❌ Error loading more fleet: $e');
      return {
        'fleet': <Fleet>[],
        'hasMore': false,
        'offset': offset,
      };
    }
  }

  /// Search fleet by make, model, or registration
  static Future<List<Fleet>> searchFleet({
    required String query,
    required String? schoolId,
    int limit = 50,
  }) async {
    final db = await DatabaseHelper.instance.database;

    try {
      String whereClause = '(make LIKE ? OR model LIKE ? OR registration LIKE ?)';
      List<dynamic> whereArgs = ['%$query%', '%$query%', '%$query%'];

      if (schoolId != null) {
        whereClause = 'school_id = ? AND $whereClause';
        whereArgs.insert(0, schoolId);
      }

      final maps = await db.query(
        'fleet',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'make ASC',
        limit: limit,
      );

      return maps.map((m) => Fleet.fromJson(m)).toList();
    } catch (e) {
      print('❌ Error searching fleet: $e');
      return [];
    }
  }
}
