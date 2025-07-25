// lib/services/database_helper_extensions.dart
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

extension EnhancedScheduleExtension on DatabaseHelper {
  // Create enhanced schedules table
  Future<void> createEnhancedSchedulesTable() async {
    print('Creating enhanced schedules table...');
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS enhanced_schedules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start TEXT NOT NULL,
        end TEXT NOT NULL,
        course INTEGER NOT NULL,
        student INTEGER NOT NULL,
        instructor INTEGER NOT NULL,
        car INTEGER,
        class_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Scheduled',
        attendance_status TEXT NOT NULL DEFAULT 'pending',
        lessons_deducted INTEGER NOT NULL DEFAULT 1,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurrence_pattern TEXT,
        recurrence_end_date TEXT,
        max_occurrences INTEGER,
        selected_days TEXT,
        custom_interval INTEGER,
        parent_schedule_id TEXT,
        created_at TEXT NOT NULL,
        modified_at TEXT,
        notes TEXT,
        FOREIGN KEY (course) REFERENCES courses(id),
        FOREIGN KEY (student) REFERENCES users(id),
        FOREIGN KEY (instructor) REFERENCES users(id),
        FOREIGN KEY (car) REFERENCES fleet(id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_enhanced_schedules_instructor_date 
      ON enhanced_schedules(instructor, start)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_enhanced_schedules_student_date 
      ON enhanced_schedules(student, start)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_enhanced_schedules_parent 
      ON enhanced_schedules(parent_schedule_id)
    ''');
  }

  Future<List<Map<String, dynamic>>> getEnhancedSchedules() async {
    final db = await database;
    return await db.query('enhanced_schedules', orderBy: 'start ASC');
  }

  Future<int> insertEnhancedSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    return await db.insert('enhanced_schedules', schedule);
  }

  Future<void> updateEnhancedSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    await db.update(
      'enhanced_schedules',
      schedule,
      where: 'id = ?',
      whereArgs: [schedule['id']],
    );
  }

  Future<void> deleteEnhancedSchedule(int id) async {
    final db = await database;
    await db.delete(
      'enhanced_schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSchedulesByParentId(
      String parentId) async {
    final db = await database;
    return await db.query(
      'enhanced_schedules',
      where: 'parent_schedule_id = ?',
      whereArgs: [parentId],
      orderBy: 'start ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getSchedulesForStudent(
      int studentId) async {
    final db = await database;
    return await db.query(
      'enhanced_schedules',
      where: 'student = ?',
      whereArgs: [studentId],
      orderBy: 'start DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSchedulesForInstructor(
      int instructorId) async {
    final db = await database;
    return await db.query(
      'enhanced_schedules',
      where: 'instructor = ?',
      whereArgs: [instructorId],
      orderBy: 'start ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getSchedulesByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    return await db.query(
      'enhanced_schedules',
      where: 'start >= ? AND start <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'start ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getConflictingSchedules(
      int instructorId, DateTime start, DateTime end,
      {int? excludeScheduleId}) async {
    final db = await database;
    String whereClause =
        'instructor = ? AND start < ? AND end > ? AND status != ?';
    List<dynamic> whereArgs = [
      instructorId,
      end.toIso8601String(),
      start.toIso8601String(),
      'Cancelled'
    ];

    if (excludeScheduleId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeScheduleId);
    }

    return await db.query(
      'enhanced_schedules',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<int> getAttendedLessonsCount(int studentId, int courseId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(lessons_deducted) as total
      FROM enhanced_schedules 
      WHERE student = ? AND course = ? AND attendance_status = 'attended'
    ''', [studentId, courseId]);

    return result.first['total'] as int? ?? 0;
  }

  Future<List<Map<String, dynamic>>> getSchedulesByStatus(String status) async {
    final db = await database;
    return await db.query(
      'enhanced_schedules',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'start ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getSchedulesByAttendanceStatus(
      String attendanceStatus) async {
    final db = await database;
    return await db.query(
      'enhanced_schedules',
      where: 'attendance_status = ?',
      whereArgs: [attendanceStatus],
      orderBy: 'start ASC',
    );
  }

  Future<void> updateScheduleAttendance(
      int scheduleId, String attendanceStatus) async {
    final db = await database;
    await db.update(
      'enhanced_schedules',
      {
        'attendance_status': attendanceStatus,
        'modified_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  Future<void> bulkUpdateSchedulesByParentId(
      String parentId, Map<String, dynamic> updates) async {
    final db = await database;
    updates['modified_at'] = DateTime.now().toIso8601String();
    await db.update(
      'enhanced_schedules',
      updates,
      where: 'parent_schedule_id = ?',
      whereArgs: [parentId],
    );
  }

  Future<Map<String, dynamic>?> getScheduleById(int id) async {
    final db = await database;
    final results = await db.query(
      'enhanced_schedules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> searchSchedules(String query) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT es.*, 
             u1.fname || ' ' || u1.lname as student_name,
             u2.fname || ' ' || u2.lname as instructor_name,
             c.name as course_name
      FROM enhanced_schedules es
      LEFT JOIN users u1 ON es.student = u1.id
      LEFT JOIN users u2 ON es.instructor = u2.id  
      LEFT JOIN courses c ON es.course = c.id
      WHERE (u1.fname LIKE ? OR u1.lname LIKE ? OR 
             u2.fname LIKE ? OR u2.lname LIKE ? OR 
             c.name LIKE ?)
      ORDER BY es.start ASC
    ''', List.filled(5, '%$query%'));
  }
}
