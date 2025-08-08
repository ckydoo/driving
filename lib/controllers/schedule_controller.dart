// lib/controllers/schedule_controller.dart
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/billing_record.dart';
import 'package:driving/services/consistency_checker_service.dart';
import 'package:driving/services/lesson_counting_service.dart';
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

  Future<void> deleteSchedule(int scheduleId) async {
    try {
      isLoading(true);

      await _dbHelper.deleteSchedule(scheduleId);
      schedules.removeWhere((s) => s.id == scheduleId);
      schedules.refresh();
      _applyFilters();

      Get.snackbar(
        'Success',
        'Schedule deleted successfully',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete schedule: ${e.toString()}');
    } finally {
      isLoading(false);
    }
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
// Add this method to your existing ScheduleController class

// Add this method to prevent scheduling in the past
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
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) => inv.studentId == studentId && inv.courseId == courseId,
      );

      if (invoice == null) return true;

      final usedLessons = schedules
          .where((s) =>
              s.studentId == studentId && s.courseId == courseId && s.attended)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      return (usedLessons + requiredLessons) > invoice.lessons;
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

  // Fixed Schedule Controller - Issue 1: Scheduling but not deducting lessons from billed lessons

  Future<void> addOrUpdateSchedule(Schedule schedule) async {
    try {
      isLoading(true);

      if (schedule.id == null) {
        // Creating new schedule
        final newSchedule = await _dbHelper.insertSchedule(schedule.toJson());
        final scheduleWithId = Schedule.fromJson({
          ...schedule.toJson(),
          'id': newSchedule,
        });

        // FIXED: Deduct lessons from billing when scheduling (not just attending)
        await _deductLessonsFromBilling(scheduleWithId);

        schedules.add(scheduleWithId);
      } else {
        // Updating existing schedule
        await _dbHelper.updateSchedule(schedule.toJson());
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

      Get.snackbar(
        'Success',
        schedule.id == null
            ? 'Schedule created successfully'
            : 'Schedule updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to save schedule: ${e.toString()}');
      rethrow; // Re-throw to handle in calling code
    } finally {
      isLoading(false);
    }
  }

// New method to handle lesson deduction from billing
  Future<void> _deductLessonsFromBilling(Schedule schedule) async {
    try {
      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == schedule.studentId &&
            inv.courseId == schedule.courseId,
      );

      if (invoice != null) {
        // Calculate current used lessons (including this new schedule)
        final usedLessons =
            getUsedLessons(schedule.studentId, schedule.courseId) +
                schedule.lessonsDeducted;

        // Check if we have enough lessons
        if (usedLessons > invoice.lessons) {
          print(
              'Insufficient lessons remaining. Please add more lessons to the invoice.');
        }

        // Update the invoice to reflect used lessons
        await billingController.updateUsedLessons(invoice.id!, usedLessons);
      }
    } catch (e) {
      rethrow; // Re-throw to handle in calling method
    }
  }

  /// Cancel schedule with proper status update
  Future<void> cancelSchedule(int scheduleId) async {
    try {
      isLoading(true);

      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        Get.snackbar('Error', 'Schedule not found');
        return;
      }

      final schedule = schedules[index];

      // Update schedule status to cancelled and ensure not attended
      final updated = schedule.copyWith(
        status: ScheduleStatus.cancelled,
        attended: false,
      );

      await _dbHelper.updateSchedule({
        'id': scheduleId,
        'status': ScheduleStatus.cancelled,
        'attended': 0,
      });

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
            await _dbHelper.deleteBillingRecord(billingRecords.first.id!);
          }
        }
      } catch (e) {
        print('Error handling billing record: $e');
      }

      Get.snackbar(
        'Success',
        'Schedule cancelled successfully',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to cancel schedule: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  /// Reschedule with proper status handling
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

        await _dbHelper.updateSchedule({
          'id': scheduleId,
          'status': ScheduleStatus.rescheduled,
          'attended': 0,
        });

        schedules[index] = updated;
      }

      // Add new schedule with proper status
      final newScheduleWithStatus = newSchedule.copyWith(
        status: ScheduleStatus.scheduled,
        attended: false,
      );

      await addOrUpdateSchedule(newScheduleWithStatus);

      Get.snackbar(
        'Success',
        'Schedule rescheduled successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to reschedule: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  /// Update lesson progress with consistent status logic
  Future<void> updateLessonProgress() async {
    try {
      final now = DateTime.now();
      bool hasUpdates = false;

      for (int i = 0; i < schedules.length; i++) {
        final schedule = schedules[i];
        final currentStatus = schedule.status;
        final correctStatus = schedule.statusDisplay;

        // Only update if status has actually changed
        if (currentStatus != correctStatus) {
          await _dbHelper.updateSchedule({
            'id': schedule.id,
            'status': correctStatus,
          });

          schedules[i] = schedule.copyWith(status: correctStatus);
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        schedules.refresh();
        _applyFilters();
      }
    } catch (e) {
      print('Error updating lesson progress: $e');
    }
  }

// Add this method to ScheduleController
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

  int getUsedLessons(int studentId, int courseId) {
    return LessonCountingService.instance.getUsedLessons(studentId, courseId);
  }

  /// Updated to use centralized lesson counting service
  int getRemainingLessons(int studentId, int courseId) {
    return LessonCountingService.instance
        .getRemainingLessons(studentId, courseId);
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

  /// ENHANCED: Toggle attendance with full consistency checking
  Future<void> toggleAttendance(int scheduleId, bool attended) async {
    try {
      isLoading(true);

      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        Get.snackbar('Error', 'Schedule not found');
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
      await _dbHelper.updateSchedule({
        'id': scheduleId,
        'attended': attended ? 1 : 0,
        'status': newStatus,
      });

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
      Get.snackbar('Error', 'Failed to update attendance: ${e.toString()}');
    } finally {
      isLoading(false);
    }
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

  /// ENHANCED: Create schedule with comprehensive validation
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

      // Update local state
      schedules.add(createdSchedule);
      schedules.refresh();
      _applyFilters();

      // Create billing record if needed
      await _createBillingRecordIfNeeded(createdSchedule);

      Get.snackbar(
        'Success',
        'Schedule created successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error creating schedule: $e');
      Get.snackbar('Error', 'Failed to create schedule: ${e.toString()}');
      rethrow;
    } finally {
      isLoading(false);
    }
  }

  /// ENHANCED: Update schedule with consistency checks
  Future<void> updateSchedule(Schedule schedule) async {
    try {
      isLoading(true);

      final index = schedules.indexWhere((s) => s.id == schedule.id);
      if (index == -1) {
        throw Exception('Schedule not found');
      }

      final originalSchedule = schedules[index];

      // Check if lesson deduction changed and validate availability
      if (schedule.lessonsDeducted != originalSchedule.lessonsDeducted) {
        final lessonDifference =
            schedule.lessonsDeducted - originalSchedule.lessonsDeducted;

        if (lessonDifference > 0) {
          // Adding lessons - check availability
          if (!LessonCountingService.instance.canScheduleLessons(
              schedule.studentId, schedule.courseId, lessonDifference)) {
            final remaining = LessonCountingService.instance
                .getRemainingLessons(schedule.studentId, schedule.courseId);

            throw Exception(
                'Insufficient lessons for update. Additional needed: $lessonDifference, Available: $remaining');
          }
        }
      }

      // CONSISTENCY CHECK: Ensure status and attendance alignment
      final consistentSchedule = _ensureStatusConsistency(schedule);

      // Update database
      await _dbHelper.updateSchedule(consistentSchedule.toJson());

      // Update local state
      schedules[index] = consistentSchedule;
      schedules.refresh();
      _applyFilters();

      Get.snackbar(
        'Success',
        'Schedule updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error updating schedule: $e');
      Get.snackbar('Error', 'Failed to update schedule: ${e.toString()}');
      rethrow;
    } finally {
      isLoading(false);
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
        'Migration Complete',
        'Schedule migration and consistency fixes completed successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    } catch (e) {
      print('Error in migration: $e');
      Get.snackbar(
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
          'Fixes Applied',
          'Fixed $totalFixed inconsistencies successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'No Issues Found',
          'All schedules are already consistent',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error fixing inconsistencies: $e');
      Get.snackbar('Error', 'Failed to fix inconsistencies: ${e.toString()}');
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

  /// ENHANCED: Bulk create schedules with validation
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
        createdSchedules.add(consistentSchedule.copyWith(id: id));
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
        'Bulk Creation Success',
        'Created ${createdSchedules.length} schedules successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error in bulk schedule creation: $e');
      Get.snackbar(
          'Bulk Creation Error', 'Failed to create schedules: ${e.toString()}');
      rethrow;
    } finally {
      isLoading(false);
    }
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
          'System Healthy',
          'No consistency issues found',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
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
          'Check Error', 'Failed to run consistency check: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  /// Updated _isBilledLessonsExceeded to use centralized logic
  bool _isBilledLessonsExceeded(Schedule schedule) {
    return !LessonCountingService.instance
        .validateScheduleChange(schedule, willBeAttended: schedule.attended);
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
}
