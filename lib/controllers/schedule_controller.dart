import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/billing_record.dart';
import 'package:driving/services/consistency_checker_service.dart';
import 'package:driving/services/lesson_counting_service.dart';
import 'package:driving/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/schedule.dart';
import '../services/database_helper.dart';
import '../services/schedule_status_migration.dart';
import '../constant/schedule_status.dart';

class ScheduleController extends GetxController {
  final RxList<Schedule> schedules = <Schedule>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final DatabaseHelper _dbHelper = Get.find();

  // Filtered schedules for performance
  final RxList<Schedule> filteredSchedules = <Schedule>[].obs;

  // Filter criteria
  final RxString selectedInstructorFilter = ''.obs;
  final RxString selectedStudentFilter = ''.obs;
  final RxString selectedStatusFilter = ''.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onReady() {
    super.onReady();
    fetchSchedules();

    // Initialize billing controller
    try {
      Get.find<BillingController>().fetchBillingData();
    } catch (e) {
      print('BillingController not found: $e');
    }

    // Set up reactive filters
    ever(selectedInstructorFilter, (_) => _applyFilters());
    ever(selectedStudentFilter, (_) => _applyFilters());
    ever(selectedStatusFilter, (_) => _applyFilters());
    ever(searchQuery, (_) => _applyFilters());
  }

  Future<void> fetchSchedules() async {
    try {
      isLoading(true);
      error('');

      final data = await _dbHelper.getSchedules();

      if (data.isEmpty) {
        schedules.clear();
        filteredSchedules.clear();
        return;
      }

      // Convert data to Schedule objects with error handling
      final List<Schedule> loadedSchedules = [];
      for (final scheduleData in data) {
        try {
          final schedule = Schedule.fromJson(scheduleData);
          loadedSchedules.add(schedule);
        } catch (e) {
          print('Error parsing schedule ${scheduleData['id']}: $e');
          // Continue with other schedules
        }
      }

      schedules.assignAll(loadedSchedules);
      _applyFilters();
    } catch (e) {
      error('Failed to load schedules: ${e.toString()}');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Failed to load schedules: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print("Error fetching schedules: $e");
    } finally {
      isLoading(false);
    }
  }

  void _applyFilters() {
    var filtered = schedules.where((schedule) {
      // Apply instructor filter
      if (selectedInstructorFilter.value.isNotEmpty) {
        final instructor = _getInstructorById(schedule.instructorId);
        final instructorName =
            instructor != null ? '${instructor.fname} ${instructor.lname}' : '';
        if (instructorName != selectedInstructorFilter.value) {
          return false;
        }
      }

      // Apply student filter
      if (selectedStudentFilter.value.isNotEmpty) {
        final student = _getStudentById(schedule.studentId);
        final studentName =
            student != null ? '${student.fname} ${student.lname}' : '';
        if (studentName != selectedStudentFilter.value) {
          return false;
        }
      }

      // Apply status filter
      if (selectedStatusFilter.value.isNotEmpty) {
        if (schedule.statusDisplay != selectedStatusFilter.value) {
          return false;
        }
      }

      // Apply search query
      if (searchQuery.value.isNotEmpty) {
        final student = _getStudentById(schedule.studentId);
        final instructor = _getInstructorById(schedule.instructorId);
        final course = _getCourseById(schedule.courseId);

        final query = searchQuery.value.toLowerCase();
        final searchableText = [
          student?.fname ?? '',
          student?.lname ?? '',
          instructor?.fname ?? '',
          instructor?.lname ?? '',
          course?.name ?? '',
          schedule.classType,
          schedule.status,
        ].join(' ').toLowerCase();

        if (!searchableText.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    filteredSchedules.assignAll(filtered);
    // FIXED: Force update to ensure UI refreshes
    filteredSchedules.refresh();
  }

  // Helper methods to get related data
  dynamic _getStudentById(int id) {
    try {
      final userController = Get.find<UserController>();
      return userController.users.firstWhereOrNull(
        (user) => user.id == id && user.role.toLowerCase() == 'student',
      );
    } catch (e) {
      print('UserController not found: $e');
      return null;
    }
  }

  dynamic _getInstructorById(int id) {
    try {
      final userController = Get.find<UserController>();
      return userController.users.firstWhereOrNull(
        (user) => user.id == id && user.role.toLowerCase() == 'instructor',
      );
    } catch (e) {
      print('UserController not found: $e');
      return null;
    }
  }

  dynamic _getCourseById(int id) {
    try {
      final courseController = Get.find<CourseController>();
      return courseController.courses.firstWhereOrNull(
        (course) => course.id == id,
      );
    } catch (e) {
      print('CourseController not found: $e');
      return null;
    }
  }

  // Filter methods
  void setInstructorFilter(String? instructor) {
    selectedInstructorFilter.value = instructor ?? '';
  }

  void setStudentFilter(String? student) {
    selectedStudentFilter.value = student ?? '';
  }

  void setStatusFilter(String? status) {
    selectedStatusFilter.value = status ?? '';
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void clearFilters() {
    selectedInstructorFilter.value = '';
    selectedStudentFilter.value = '';
    selectedStatusFilter.value = '';
    searchQuery.value = '';
  }

  bool get hasActiveFilters {
    return selectedInstructorFilter.value.isNotEmpty ||
        selectedStudentFilter.value.isNotEmpty ||
        selectedStatusFilter.value.isNotEmpty ||
        searchQuery.value.isNotEmpty;
  }

  // Get schedules for a specific day
  List<Schedule> getSchedulesForDay(DateTime day) {
    return filteredSchedules.where((schedule) {
      return schedule.start.year == day.year &&
          schedule.start.month == day.month &&
          schedule.start.day == day.day;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  // Get upcoming schedules
  List<Schedule> get upcomingSchedules {
    final now = DateTime.now();
    return filteredSchedules.where((schedule) {
      return schedule.start.isAfter(now) && schedule.status != 'Cancelled';
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  // Get today's schedules
  List<Schedule> get todaySchedules {
    return getSchedulesForDay(DateTime.now());
  }

  // Statistics
  Map<String, int> get scheduleStats {
    final stats = <String, int>{
      'total': schedules.length,
      'scheduled': 0,
      'completed': 0,
      'cancelled': 0,
      'inProgress': 0,
      'upcoming': 0,
      'today': 0,
    };

    for (final schedule in schedules) {
      final status = schedule.statusDisplay.toLowerCase();

      if (stats.containsKey(status)) {
        stats[status] = stats[status]! + 1;
      }

      if (schedule.isUpcoming) {
        stats['upcoming'] = stats['upcoming']! + 1;
      }

      if (schedule.isToday) {
        stats['today'] = stats['today']! + 1;
      }
    }

    return stats;
  }

  // Refresh data
  void refreshData() {
    fetchSchedules();
  }

  // Enhanced Schedule Controller with Past Date Validation
  bool _isValidScheduleDate(DateTime selectedDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduleDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    return scheduleDate.isAtSameMomentAs(today) || scheduleDate.isAfter(today);
  }

// Enhanced method to validate schedule before creation/update
  Future<bool> validateScheduleDateTime(DateTime start, DateTime end,
      {int? excludeScheduleId}) async {
    // Check if scheduling date is not in the past
    if (!_isValidScheduleDate(start)) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Invalid Date',
        'Cannot schedule lessons for past dates. Please select today or a future date.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error, color: Colors.white),
        duration: Duration(seconds: 4),
      );
      return false;
    }

    // Check if end time is after start time
    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Invalid Time',
        'End time must be after start time.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error, color: Colors.white),
        duration: Duration(seconds: 3),
      );
      return false;
    }

    // Check if lesson duration is reasonable (at least 30 minutes, max 4 hours)
    final duration = end.difference(start);
    if (duration.inMinutes < 30) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Invalid Duration',
        'Lesson duration must be at least 30 minutes.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error, color: Colors.white),
        duration: Duration(seconds: 3),
      );
      return false;
    }

    if (duration.inHours > 4) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Invalid Duration',
        'Lesson duration cannot exceed 4 hours.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error, color: Colors.white),
        duration: Duration(seconds: 3),
      );
      return false;
    }

    return true;
  }

// Helper method to check availability with optional exclusion
  Future<bool> checkAvailability(int instructorId, DateTime start, DateTime end,
      {int? excludeId}) async {
    return !schedules.any((s) {
      if (excludeId != null && s.id == excludeId)
        return false; // Exclude current schedule when editing

      return s.instructorId == instructorId &&
          start.isBefore(s.end) &&
          end.isAfter(s.start) &&
          s.status != 'Cancelled';
    });
  }

  Future<bool> checkBillingLessons(
      int studentId, int courseId, int requiredLessons) async {
    try {
      final billingController = Get.find<BillingController>();

      // GET ALL invoices instead of just one
      final invoices = billingController.invoices
          .where(
            (inv) => inv.studentId == studentId && inv.courseId == courseId,
          )
          .toList();

      if (invoices.isEmpty) return true;

      // SUM total lessons from all invoices
      final totalLessons =
          invoices.fold<int>(0, (sum, invoice) => sum + invoice.lessons);

      final usedLessons = schedules
          .where((s) =>
              s.studentId == studentId && s.courseId == courseId && s.attended)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      return (usedLessons + requiredLessons) <= totalLessons;
    } catch (e) {
      print('Error checking billing lessons: $e');
      return false;
    }
  }

// Method to get minimum selectable date (today)
  DateTime getMinimumScheduleDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

// Method to get maximum selectable date (1 year from now)
  DateTime getMaximumScheduleDate() {
    final now = DateTime.now();
    return DateTime(now.year + 1, now.month, now.day);
  }

  Future<void> _deductLessonsFromBilling(Schedule schedule) async {
    try {
      final billingController = Get.find<BillingController>();

      // GET ALL invoices for this student/course
      final invoices = billingController.invoices
          .where(
            (inv) =>
                inv.studentId == schedule.studentId &&
                inv.courseId == schedule.courseId,
          )
          .toList();

      if (invoices.isNotEmpty) {
        // Calculate total available lessons
        final totalLessons =
            invoices.fold<int>(0, (sum, invoice) => sum + invoice.lessons);

        // Calculate current used lessons (including this new schedule)
        final usedLessons =
            getUsedLessons(schedule.studentId, schedule.courseId) +
                schedule.lessonsDeducted;

        // Check if we have enough lessons
        if (usedLessons > totalLessons) {
          throw Exception(
              'Insufficient lessons remaining. Total available: $totalLessons, Will be used: $usedLessons');
        }

        // Note: You might want to update the "used_lessons" tracking
        // across multiple invoices here if needed
      }
    } catch (e) {
      rethrow;
    }
  }

  int getEffectiveLessonsUsed(int studentId, int courseId) {
    final settingsController = Get.find<SettingsController>();

    if (settingsController.countScheduledLessons.value) {
      // Count both scheduled and attended lessons
      return schedules
          .where((s) =>
              s.studentId == studentId &&
              s.courseId == courseId &&
              (s.attended || s.status != 'Cancelled'))
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);
    } else {
      // Only count attended lessons
      return schedules
          .where((s) =>
              s.studentId == studentId && s.courseId == courseId && s.attended)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);
    }
  }

  /// Updated to use centralized lesson counting service
  bool canCreateSchedule(int studentId, int courseId, int lessonsToDeduct) {
    return LessonCountingService.instance
        .canScheduleLessons(studentId, courseId, lessonsToDeduct);
  }

  /// Updated to use centralized lesson counting service
  Map<String, int> getLessonUsageStats(int studentId, int courseId) {
    return LessonCountingService.instance
        .getLessonUsageStats(studentId, courseId);
  }

  /// Helper method for consistent billing record updates
  Future<void> _updateBillingRecordStatus(
      Schedule schedule, bool attended) async {
    try {
      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == schedule.studentId &&
            inv.courseId == schedule.courseId,
      );

      if (invoice != null) {
        final billingRecords =
            await billingController.getBillingRecordsForInvoice(invoice.id!);
        if (billingRecords.isNotEmpty) {
          await billingController.updateBillingRecordStatus(
            billingRecords.first.id!,
            attended ? 'Completed' : 'Pending',
          );
        }
      }
    } catch (e) {
      print('Error updating billing record: $e');
      // Don't throw - this is a secondary operation that shouldn't fail the main operation
    }
  }

  /// Ensure status and attendance are consistent
  Schedule _ensureStatusConsistency(Schedule schedule) {
    String correctStatus = schedule.status;
    bool correctAttended = schedule.attended;

    // Rule 1: If attended = true, status must be 'Completed'
    if (schedule.attended && schedule.status != ScheduleStatus.completed) {
      correctStatus = ScheduleStatus.completed;
    }

    // Rule 2: If status = 'Completed', attended must be true
    if (schedule.status == ScheduleStatus.completed && !schedule.attended) {
      correctAttended = true;
    }

    // Rule 3: If past and not attended, should be 'Missed'
    if (schedule.isPast &&
        !correctAttended &&
        correctStatus != ScheduleStatus.cancelled) {
      correctStatus = ScheduleStatus.missed;
    }

    // Rule 4: If future and not attended, should be 'Scheduled'
    if (!schedule.isPast &&
        !correctAttended &&
        correctStatus == ScheduleStatus.missed) {
      correctStatus = ScheduleStatus.scheduled;
    }

    // Return corrected schedule if changes were needed
    if (correctStatus != schedule.status ||
        correctAttended != schedule.attended) {
      print(
          'Schedule consistency correction: status ${schedule.status} -> $correctStatus, attended ${schedule.attended} -> $correctAttended');

      return schedule.copyWith(
        status: correctStatus,
        attended: correctAttended,
      );
    }

    return schedule;
  }

  /// Create billing record if auto-creation is enabled
  Future<void> _createBillingRecordIfNeeded(Schedule schedule) async {
    try {
      final settingsController = Get.find<SettingsController>();
      if (!settingsController.autoCreateBillingRecords.value) return;

      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == schedule.studentId &&
            inv.courseId == schedule.courseId,
      );

      if (invoice != null) {
        final billingRecord = BillingRecord(
          invoiceId: invoice.id!,
          scheduleId: schedule.id!,
          studentId: schedule.studentId,
          amount: 0.0, // Will be calculated based on course rates
          status: schedule.attended ? 'Completed' : 'Pending',
          createdAt: DateTime.now(),
        );

        await billingController.insertBillingRecord(billingRecord);
      }
    } catch (e) {
      print('Error creating billing record: $e');
      // Don't throw - billing record creation is secondary
    }
  }

  /// ENHANCED: Run consistency migration with better reporting
  Future<void> runStatusMigration() async {
    try {
      isLoading(true);

      // Get pre-migration stats
      final preMigrationStats =
          await ConsistencyCheckerService.instance.runFullConsistencyCheck();
      print('Pre-migration consistency check completed');

      // Run the actual migration
      await ScheduleStatusMigration.instance.runStatusMigration();

      // Run our enhanced consistency fixes
      await ConsistencyCheckerService.instance.fixAllInconsistencies();

      // Reload schedules after migration
      await fetchSchedules();

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Migration Complete',
        'Schedule migration and consistency fixes completed successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    } catch (e) {
      print('Error in migration: $e');
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Migration Error',
        'Migration failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  /// ENHANCED: Fix inconsistent schedules using the new service
  Future<void> fixInconsistentSchedules() async {
    try {
      isLoading(true);

      final results =
          await ConsistencyCheckerService.instance.fixAllInconsistencies();

      // Reload schedules to reflect fixes
      await fetchSchedules();

      final totalFixed =
          results.values.fold<int>(0, (sum, count) => sum + count);

      if (totalFixed > 0) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Fixes Applied',
          'Fixed $totalFixed inconsistencies successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'No Issues Found',
          'All schedules are already consistent',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error fixing inconsistencies: $e');
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to fix inconsistencies: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  /// Get inconsistent schedules using centralized logic
  List<Schedule> get inconsistentSchedules {
    return schedules.where((schedule) {
      // Check if attended and status are aligned
      if (schedule.attended && schedule.status != ScheduleStatus.completed) {
        return true;
      }

      if (schedule.status == ScheduleStatus.completed && !schedule.attended) {
        return true;
      }

      // Check if past lessons should be marked as missed
      if (schedule.isPast &&
          !schedule.attended &&
          schedule.status == ScheduleStatus.scheduled) {
        return true;
      }

      return false;
    }).toList();
  }

  /// Check system consistency on demand
  Future<void> runConsistencyCheck() async {
    try {
      isLoading(true);

      final results =
          await ConsistencyCheckerService.instance.runFullConsistencyCheck();
      final report =
          ConsistencyCheckerService.instance.generateDetailedReport(results);

      print('=== CONSISTENCY CHECK RESULTS ===');
      print(report);

      // Show summary to user
      final attendanceIssues =
          (results['attendance_status_mismatches'] as List).length;
      final lessonIssues = (results['lesson_count_issues'] as List).length;
      final billingIssues = (results['billing_record_issues'] as List).length;
      final totalIssues = attendanceIssues + lessonIssues + billingIssues;

      if (totalIssues == 0) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'System Healthy',
          'No consistency issues found',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Issues Found',
          '$totalIssues consistency issues detected. Check logs for details.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
        );
      }
    } catch (e) {
      print('Error running consistency check: $e');
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Check Error',
          'Failed to run consistency check: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  /// Updated calculateScheduleProgress to use centralized logic
  double calculateScheduleProgress(Schedule schedule) {
    try {
      final stats = LessonCountingService.instance
          .getLessonUsageStats(schedule.studentId, schedule.courseId);

      final totalLessons = stats['total'] ?? 0;
      if (totalLessons == 0) return 0.0;

      final usedLessons = stats['used'] ?? 0;
      return (usedLessons / totalLessons).clamp(0.0, 1.0);
    } catch (e) {
      print('Error calculating progress: $e');
      return 0.0;
    }
  }

  // ISSUE ANALYSIS AND FIX for ScheduleController

// The main issue is in these methods:

// 2. getUsedLessons method (similar logic but used elsewhere)
  int getUsedLessons(int studentId, int courseId) {
    final settingsController = Get.find<SettingsController>();

    if (settingsController.countScheduledLessons.value) {
      // Count both scheduled and attended lessons (exclude cancelled)
      return schedules
          .where((s) =>
              s.studentId == studentId &&
              s.courseId == courseId &&
              s.status.toLowerCase() != 'cancelled')
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);
    } else {
      // Only count attended lessons
      return schedules
          .where((s) =>
              s.studentId == studentId && s.courseId == courseId && s.attended)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);
    }
  }

  Future<void> refreshBillingData() async {
    try {
      final billingController = Get.find<BillingController>();
      await billingController.fetchBillingData();
      print('✓ Billing data refreshed in ScheduleController');
    } catch (e) {
      print('Error refreshing billing data: $e');
    }
  }

  int getRemainingLessons(int studentId, int courseId) {
    final billingController = Get.find<BillingController>();

    // GET ALL invoices for this student/course combination
    final invoices = billingController.invoices
        .where(
          (inv) => inv.studentId == studentId && inv.courseId == courseId,
        )
        .toList();

    if (invoices.isEmpty) return 0;

    // SUM all lessons from all invoices
    final totalLessons =
        invoices.fold<int>(0, (sum, invoice) => sum + invoice.lessons);

    // Use the centralized getUsedLessons method for consistency
    final usedLessons = getUsedLessons(studentId, courseId);
    final remaining = (totalLessons - usedLessons).clamp(0, totalLessons);

    // Debug logging to help troubleshoot
    print('DEBUG: Student $studentId, Course $courseId');
    print('Found ${invoices.length} invoices for student');
    for (var i = 0; i < invoices.length; i++) {
      print('  Invoice ${i + 1}: ${invoices[i].lessons} lessons');
    }
    print('Total lessons across all invoices: $totalLessons');
    print('Used lessons: $usedLessons');
    print('Remaining lessons: $remaining');

    return remaining;
  }

// DEBUGGING METHOD: Add this to help troubleshoot
  void debugBillingAndSchedules(int studentId, int courseId) {
    final billingController = Get.find<BillingController>();
    final settingsController = Get.find<SettingsController>();

    // GET ALL invoices for this student/course
    final invoices = billingController.invoices
        .where(
          (inv) => inv.studentId == studentId && inv.courseId == courseId,
        )
        .toList();

    final studentSchedules = schedules
        .where((s) => s.studentId == studentId && s.courseId == courseId)
        .toList();

    print('=== BILLING DEBUG ===');
    print('Student ID: $studentId, Course ID: $courseId');
    print('Found ${invoices.length} invoices for student');

    int totalLessons = 0;
    for (var i = 0; i < invoices.length; i++) {
      print(
          'Invoice ${i + 1}: ID=${invoices[i].id}, Lessons=${invoices[i].lessons}');
      totalLessons += invoices[i].lessons;
    }
    print('Total lessons across all invoices: $totalLessons');

    print(
        'Total schedules for this student/course: ${studentSchedules.length}');
    print(
        'countScheduledLessons setting: ${settingsController.countScheduledLessons.value}');

    for (var schedule in studentSchedules) {
      print('Schedule ID: ${schedule.id}, Status: ${schedule.status}, '
          'Attended: ${schedule.attended}, LessonsDeducted: ${schedule.lessonsDeducted}');
    }

    final usedLessons = getUsedLessons(studentId, courseId);
    final remainingLessons = getRemainingLessons(studentId, courseId);

    print('Used lessons: $usedLessons');
    print('Remaining lessons: $remainingLessons');
    print('=== END DEBUG ===');
  }

  // Key methods that need SyncService.trackChange integration:

// 1. In addOrUpdateSchedule method - track schedule creation and updates
  Future<void> addOrUpdateSchedule(Schedule schedule,
      {bool silent = false}) async {
    try {
      isLoading(true);

      if (schedule.id == null) {
        // Creating new schedule
        final newSchedule = await _dbHelper.insertSchedule(schedule.toJson());
        final scheduleWithId = Schedule.fromJson({
          ...schedule.toJson(),
          'id': newSchedule,
        });

        // 🔄 TRACK THE SCHEDULE CREATION FOR SYNC
        await SyncService.trackChange(
            'schedules', scheduleWithId.toJson(), 'create');
        print('📝 Tracked schedule creation for sync');

        // FIXED: Deduct lessons from billing when scheduling (not just attending)
        await _deductLessonsFromBilling(scheduleWithId);

        schedules.add(scheduleWithId);
      } else {
        // Updating existing schedule
        await _dbHelper.updateSchedule(schedule.toJson());

        // 🔄 TRACK THE SCHEDULE UPDATE FOR SYNC
        await SyncService.trackChange('schedules', schedule.toJson(), 'update');
        print('📝 Tracked schedule update for sync');

        final index = schedules.indexWhere((s) => s.id == schedule.id);
        if (index != -1) {
          schedules[index] = schedule;
        }
      }

      // FIXED: Ensure UI updates by refreshing observables
      schedules.refresh();
      _applyFilters();

      // Force update to ensure UI reflects changes
      update();
      if (!silent) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Success',
          schedule.id == null
              ? 'Schedule created successfully'
              : 'Schedule updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (!silent) {
        Get.snackbar(
            snackPosition: SnackPosition.BOTTOM,
            'Error',
            'Failed to save schedule: ${e.toString()}');
      }
      rethrow; // Re-throw to handle in calling code
    } finally {
      isLoading(false);
    }
  }

// 2. In deleteSchedule method - track schedule deletion
  Future<void> deleteSchedule(int scheduleId) async {
    try {
      isLoading(true);

      // 🔄 TRACK THE SCHEDULE DELETION FOR SYNC
      await SyncService.trackChange('schedules', {'id': scheduleId}, 'delete');
      print('📝 Tracked schedule deletion for sync');

      await _dbHelper.deleteSchedule(scheduleId);
      schedules.removeWhere((s) => s.id == scheduleId);
      schedules.refresh();
      _applyFilters();

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Success',
        'Schedule deleted successfully',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to delete schedule: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

// 3. In cancelSchedule method - track schedule status change
  Future<void> cancelSchedule(int scheduleId) async {
    try {
      isLoading(true);

      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        Get.snackbar(
            snackPosition: SnackPosition.BOTTOM, 'Error', 'Schedule not found');
        return;
      }

      final schedule = schedules[index];

      // Update schedule status to cancelled and ensure not attended
      final updated = schedule.copyWith(
        status: ScheduleStatus.cancelled,
        attended: false,
      );

      final updateData = {
        'id': scheduleId,
        'status': ScheduleStatus.cancelled,
        'attended': 0,
      };

      await _dbHelper.updateSchedule(updateData);

      // 🔄 TRACK THE SCHEDULE STATUS UPDATE FOR SYNC
      await SyncService.trackChange('schedules', updateData, 'update');
      print('📝 Tracked schedule cancellation for sync');

      schedules[index] = updated;
      schedules.refresh();
      _applyFilters();

      // Handle billing record
      try {
        final billingController = Get.find<BillingController>();
        final invoice = billingController.invoices.firstWhereOrNull(
          (inv) =>
              inv.studentId == schedule.studentId &&
              inv.courseId == schedule.courseId,
        );

        if (invoice != null) {
          final billingRecords =
              await billingController.getBillingRecordsForInvoice(invoice.id!);
          if (billingRecords.isNotEmpty) {
            await _dbHelper.deleteInvoice(billingRecords.first.id!);
          }
        }
      } catch (e) {
        print('Error handling billing record: $e');
      }

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Success',
        'Schedule cancelled successfully',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to cancel schedule: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

// 4. In rescheduleSchedule method - track both old and new schedule changes
  Future<void> rescheduleSchedule(int scheduleId, Schedule newSchedule) async {
    try {
      isLoading(true);

      // Mark original as rescheduled instead of cancelled
      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index != -1) {
        final original = schedules[index];
        final updated = original.copyWith(
          status: ScheduleStatus.rescheduled,
          attended: false,
        );

        final updateData = {
          'id': scheduleId,
          'status': ScheduleStatus.rescheduled,
          'attended': 0,
        };

        await _dbHelper.updateSchedule(updateData);

        // 🔄 TRACK THE ORIGINAL SCHEDULE STATUS UPDATE FOR SYNC
        await SyncService.trackChange('schedules', updateData, 'update');
        print('📝 Tracked original schedule reschedule status for sync');

        schedules[index] = updated;
      }

      // Add new schedule with proper status
      final newScheduleWithStatus = newSchedule.copyWith(
        status: ScheduleStatus.scheduled,
        attended: false,
      );

      await addOrUpdateSchedule(newScheduleWithStatus);

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Success',
        'Schedule rescheduled successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to reschedule: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

// 5. In toggleAttendance method - track attendance and status changes
  Future<void> toggleAttendance(int scheduleId, bool attended) async {
    try {
      isLoading(true);

      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        Get.snackbar(
            snackPosition: SnackPosition.BOTTOM, 'Error', 'Schedule not found');
        return;
      }

      final schedule = schedules[index];

      // CONSISTENCY CHECK: Validate lesson availability before marking attended
      if (attended) {
        final canMark = LessonCountingService.instance
            .validateScheduleChange(schedule, willBeAttended: true);

        if (!canMark) {
          final remaining = LessonCountingService.instance
              .getRemainingLessons(schedule.studentId, schedule.courseId);

          Get.snackbar(
            snackPosition: SnackPosition.BOTTOM,
            'Lesson Limit Exceeded',
            'Cannot mark as attended. Remaining lessons: $remaining',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
      }

      // ALWAYS SYNC: Determine correct status based on attendance and timing
      String newStatus;
      if (attended) {
        newStatus = ScheduleStatus.completed;
      } else if (schedule.isPast && !attended) {
        newStatus = ScheduleStatus.missed;
      } else {
        newStatus = ScheduleStatus.scheduled;
      }

      final updated = schedule.copyWith(
        attended: attended,
        status: newStatus, // Always sync these two fields
      );

      // ATOMIC UPDATE: Update both attendance and status together
      final updateData = {
        'id': scheduleId,
        'attended': attended ? 1 : 0,
        'status': newStatus,
      };

      await _dbHelper.updateSchedule(updateData);

      // 🔄 TRACK THE ATTENDANCE STATUS UPDATE FOR SYNC
      await SyncService.trackChange('schedules', updateData, 'update');
      print('📝 Tracked schedule attendance toggle for sync');

      // Update local state
      schedules[index] = updated;
      schedules.refresh();
      _applyFilters();

      // Update billing record status consistently
      await _updateBillingRecordStatus(schedule, attended);

      Get.snackbar(
        'Success',
        attended ? 'Marked as attended' : 'Marked as not attended',
        backgroundColor: attended ? Colors.green : Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error toggling attendance: $e');
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to update attendance: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

// 6. In createSchedule method - track schedule creation
  Future<void> createSchedule(Schedule schedule) async {
    try {
      isLoading(true);

      // PRE-VALIDATION: Check lesson availability
      if (!LessonCountingService.instance.canScheduleLessons(
          schedule.studentId, schedule.courseId, schedule.lessonsDeducted)) {
        final remaining = LessonCountingService.instance
            .getRemainingLessons(schedule.studentId, schedule.courseId);

        throw Exception(
            'Insufficient lessons available. Needed: ${schedule.lessonsDeducted}, Available: $remaining');
      }

      // CONSISTENCY CHECK: Ensure status and attendance are aligned
      final consistentSchedule = _ensureStatusConsistency(schedule);

      // Create in database
      final id = await _dbHelper.insertSchedule(consistentSchedule.toJson());
      final createdSchedule = consistentSchedule.copyWith(id: id);

      // 🔄 TRACK THE SCHEDULE CREATION FOR SYNC
      await SyncService.trackChange(
          'schedules', createdSchedule.toJson(), 'create');
      print('📝 Tracked schedule creation for sync');

      // Update local state
      schedules.add(createdSchedule);
      schedules.refresh();
      _applyFilters();

      // Create billing record if needed
      await _createBillingRecordIfNeeded(createdSchedule);

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Success',
        'Schedule created successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error creating schedule: $e');
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to create schedule: ${e.toString()}');
      rethrow;
    } finally {
      isLoading(false);
    }
  }

// 7. In updateSchedule method - track schedule updates
  Future<void> updateSchedule(Schedule schedule, {bool silent = false}) async {
    try {
      isLoading(true);

      final updateData = {
        'id': schedule.id,
        'status': schedule.status,
        'attended': schedule.attended ? 1 : 0,
      };

      await _dbHelper.updateSchedule(updateData);

      // 🔄 TRACK THE SCHEDULE UPDATE FOR SYNC
      await SyncService.trackChange('schedules', updateData, 'update');
      print('📝 Tracked schedule update for sync');

      final index = schedules.indexWhere((s) => s.id == schedule.id);
      if (index != -1) {
        schedules[index] = schedule;
        schedules.refresh();
      }

      // Only show snackbar if not silent
      if (!silent) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Success',
          'Schedule updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (!silent) {
        Get.snackbar(
            snackPosition: SnackPosition.BOTTOM,
            'Error',
            'Failed to update schedule: ${e.toString()}');
      }
      throw e;
    } finally {
      isLoading(false);
    }
  }

// 8. In createMultipleSchedules method - track bulk schedule creation
  Future<void> createMultipleSchedules(List<Schedule> schedulesToCreate) async {
    try {
      isLoading(true);

      if (schedulesToCreate.isEmpty) {
        throw Exception('No schedules to create');
      }

      // GROUP VALIDATION: Check total lesson requirements by student/course
      final lessonRequirements = <String, int>{};
      for (final schedule in schedulesToCreate) {
        final key = '${schedule.studentId}_${schedule.courseId}';
        lessonRequirements[key] =
            (lessonRequirements[key] ?? 0) + schedule.lessonsDeducted;
      }

      // Validate each group
      for (final entry in lessonRequirements.entries) {
        final parts = entry.key.split('_');
        final studentId = int.parse(parts[0]);
        final courseId = int.parse(parts[1]);
        final lessonsNeeded = entry.value;

        if (!LessonCountingService.instance
            .canScheduleLessons(studentId, courseId, lessonsNeeded)) {
          final available = LessonCountingService.instance
              .getRemainingLessons(studentId, courseId);
          throw Exception(
              'Insufficient lessons for student $studentId, course $courseId. Needed: $lessonsNeeded, Available: $available');
        }
      }

      // Create all schedules (they're pre-validated)
      final createdSchedules = <Schedule>[];
      for (final schedule in schedulesToCreate) {
        final consistentSchedule = _ensureStatusConsistency(schedule);
        final id = await _dbHelper.insertSchedule(consistentSchedule.toJson());
        final createdSchedule = consistentSchedule.copyWith(id: id);

        // 🔄 TRACK EACH SCHEDULE CREATION FOR SYNC
        await SyncService.trackChange(
            'schedules', createdSchedule.toJson(), 'create');
        print('📝 Tracked bulk schedule creation for sync');

        createdSchedules.add(createdSchedule);
      }

      // Update local state
      schedules.addAll(createdSchedules);
      schedules.refresh();
      _applyFilters();

      // Create billing records if needed
      for (final schedule in createdSchedules) {
        await _createBillingRecordIfNeeded(schedule);
      }

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Bulk Creation Success',
        'Created ${createdSchedules.length} schedules successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error in bulk schedule creation: $e');
      Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Bulk Creation Error',
          'Failed to create schedules: ${e.toString()}');
      rethrow;
    } finally {
      isLoading(false);
    }
  }

// 9. Enhanced updateLessonProgress method - track status changes
  // CRITICAL FIX: Never update attended/completed schedules
  Future<void> updateLessonProgress() async {
    try {
      final now = DateTime.now();
      bool hasUpdates = false;
      final updatedSchedules = <Map<String, dynamic>>[];

      for (int i = 0; i < schedules.length; i++) {
        final schedule = schedules[i];
        final currentStatus = schedule.status;
        final correctStatus = schedule.statusDisplay;

        // If a lesson is marked as attended and completed, leave it alone
        if (schedule.attended && currentStatus == ScheduleStatus.completed) {
          continue; // Don't touch this schedule!
        }

        // This prevents changing "Completed" back to "Missed"
        if (currentStatus == ScheduleStatus.completed) {
          continue; // Don't touch completed schedules!
        }

        // Only update if status has actually changed
        if (currentStatus != correctStatus) {
          final updateData = {
            'id': schedule.id,
            'status': correctStatus,
          };

          await _dbHelper.updateSchedule(updateData);

          // 🔄 TRACK THE STATUS UPDATE FOR SYNC
          await SyncService.trackChange('schedules', updateData, 'update');

          schedules[i] = schedule.copyWith(status: correctStatus);
          updatedSchedules.add(updateData);
          hasUpdates = true;

          print(
              '🔄 Auto-updated schedule ${schedule.id}: $currentStatus → $correctStatus');
        }
      }

      if (hasUpdates) {
        print(
            '📝 Tracked ${updatedSchedules.length} schedule status updates for sync');
        schedules.refresh();
        _applyFilters();
      }
    } catch (e) {
      print('Error updating lesson progress: $e');
    }
  }
}
