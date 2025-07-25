// lib/controllers/enhanced_schedule_controller.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/enhanced_schedule.dart';
import '../controllers/billing_controller.dart';
import '../services/database_helper.dart';
import '../services/database_helper_extensions.dart';

class EnhancedScheduleController extends GetxController {
  final RxList<EnhancedSchedule> schedules = <EnhancedSchedule>[].obs;
  final RxList<EnhancedSchedule> filteredSchedules = <EnhancedSchedule>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final DatabaseHelper _dbHelper = Get.find<DatabaseHelper>();

  // Filters
  final RxString selectedInstructorFilter = ''.obs;
  final RxString selectedStudentFilter = ''.obs;
  final RxString selectedStatusFilter = ''.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeDatabase();
    fetchSchedules();
    _setupFilters();
  }

  Future<void> _initializeDatabase() async {
    try {
      await _dbHelper.createEnhancedSchedulesTable();
    } catch (e) {
      print('Error initializing enhanced schedules table: $e');
    }
  }

  void _setupFilters() {
    ever(selectedInstructorFilter, (_) => _applyFilters());
    ever(selectedStudentFilter, (_) => _applyFilters());
    ever(selectedStatusFilter, (_) => _applyFilters());
    ever(searchQuery, (_) => _applyFilters());
  }

  Future<void> fetchSchedules() async {
    try {
      isLoading(true);
      error('');

      final data = await _dbHelper.getEnhancedSchedules();
      final loadedSchedules = <EnhancedSchedule>[];

      for (final json in data) {
        try {
          loadedSchedules.add(EnhancedSchedule.fromJson(json));
        } catch (e) {
          print('Error parsing schedule ${json['id']}: $e');
        }
      }

      schedules.assignAll(loadedSchedules);
      _applyFilters();
    } catch (e) {
      error('Failed to load schedules: ${e.toString()}');
      Get.snackbar('Error', 'Failed to load schedules: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  void _applyFilters() {
    var filtered = schedules.toList();

    // Apply instructor filter
    if (selectedInstructorFilter.value.isNotEmpty &&
        selectedInstructorFilter.value != 'all') {
      final instructorId = int.tryParse(selectedInstructorFilter.value);
      if (instructorId != null) {
        filtered =
            filtered.where((s) => s.instructorId == instructorId).toList();
      }
    }

    // Apply student filter
    if (selectedStudentFilter.value.isNotEmpty &&
        selectedStudentFilter.value != 'all') {
      final studentId = int.tryParse(selectedStudentFilter.value);
      if (studentId != null) {
        filtered = filtered.where((s) => s.studentId == studentId).toList();
      }
    }

    // Apply status filter
    if (selectedStatusFilter.value.isNotEmpty &&
        selectedStatusFilter.value != 'all') {
      filtered = filtered
          .where((s) => s.status == selectedStatusFilter.value)
          .toList();
    }

    // Apply search query
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((s) {
        // You would implement actual search logic here based on your user/course controllers
        return true; // Placeholder
      }).toList();
    }

    filteredSchedules.assignAll(filtered);
  }

  // Check if student has remaining lessons for billing
  Future<bool> checkStudentLessonsRemaining(
      int studentId, int courseId, int lessonsNeeded) async {
    try {
      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) => inv.studentId == studentId && inv.courseId == courseId,
      );

      if (invoice == null) {
        Get.snackbar('Error', 'No invoice found for this student and course');
        return false;
      }

      final usedLessons =
          await _dbHelper.getAttendedLessonsCount(studentId, courseId);
      final remainingLessons = invoice.lessons - usedLessons;

      if (remainingLessons < lessonsNeeded) {
        Get.snackbar(
          'Insufficient Lessons',
          'Student has only $remainingLessons lessons remaining. Cannot schedule $lessonsNeeded lessons.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to check lesson availability: $e');
      return false;
    }
  }

  // Check instructor availability
  Future<bool> checkInstructorAvailability(
      int instructorId, DateTime start, DateTime end,
      {int? excludeScheduleId}) async {
    try {
      final conflictingSchedules = await _dbHelper.getConflictingSchedules(
          instructorId, start, end,
          excludeScheduleId: excludeScheduleId);

      if (conflictingSchedules.isNotEmpty) {
        Get.snackbar(
          'Scheduling Conflict',
          'Instructor is already booked during this time slot',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to check instructor availability: $e');
      return false;
    }
  }

  // Create single schedule
  Future<bool> createSingleSchedule(EnhancedSchedule schedule) async {
    try {
      isLoading(true);

      // Check billing first
      if (!await checkStudentLessonsRemaining(
          schedule.studentId, schedule.courseId, schedule.lessonsDeducted)) {
        return false;
      }

      // Check instructor availability
      if (!await checkInstructorAvailability(
          schedule.instructorId, schedule.start, schedule.end)) {
        return false;
      }

      final id = await _dbHelper.insertEnhancedSchedule(schedule.toJson());
      final newSchedule = schedule.copyWith(id: id);
      schedules.add(newSchedule);
      _applyFilters();

      Get.snackbar(
        'Success',
        'Schedule created successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create schedule: $e');
      return false;
    } finally {
      isLoading(false);
    }
  }

  // Create recurring schedules
  Future<bool> createRecurringSchedules(EnhancedSchedule baseSchedule) async {
    try {
      isLoading(true);

      final generatedSchedules = _generateRecurringSchedules(baseSchedule);

      if (generatedSchedules.isEmpty) {
        Get.snackbar('Error',
            'No schedules could be generated with the current settings');
        return false;
      }

      // Check if student has enough lessons for all occurrences
      final totalLessonsNeeded =
          generatedSchedules.fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      if (!await checkStudentLessonsRemaining(
          baseSchedule.studentId, baseSchedule.courseId, totalLessonsNeeded)) {
        return false;
      }

      // Check instructor availability for all occurrences
      for (final schedule in generatedSchedules) {
        if (!await checkInstructorAvailability(
            schedule.instructorId, schedule.start, schedule.end)) {
          return false;
        }
      }

      // Create parent schedule ID for linking
      final parentId = DateTime.now().millisecondsSinceEpoch.toString();

      // Save all schedules
      for (final schedule in generatedSchedules) {
        final scheduleWithParent =
            schedule.copyWith(parentScheduleId: parentId);
        final id =
            await _dbHelper.insertEnhancedSchedule(scheduleWithParent.toJson());
        schedules.add(scheduleWithParent.copyWith(id: id));
      }

      _applyFilters();

      Get.snackbar(
        'Success',
        '${generatedSchedules.length} recurring schedules created successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create recurring schedules: $e');
      return false;
    } finally {
      isLoading(false);
    }
  }

  List<EnhancedSchedule> _generateRecurringSchedules(
      EnhancedSchedule baseSchedule) {
    final schedules = <EnhancedSchedule>[];
    var currentDate = baseSchedule.start;

    final endDate = baseSchedule.recurrenceEndDate ??
        DateTime.now().add(const Duration(days: 365));

    int count = 0;
    const maxSchedules = 100; // Safety limit

    while ((currentDate.isBefore(endDate) ||
            currentDate.isAtSameMomentAs(endDate)) &&
        (baseSchedule.maxOccurrences == null ||
            count < baseSchedule.maxOccurrences!) &&
        schedules.length < maxSchedules) {
      bool shouldCreateSchedule = false;

      switch (baseSchedule.recurrencePattern) {
        case 'daily':
          shouldCreateSchedule = true;
          break;
        case 'weekly':
          shouldCreateSchedule =
              baseSchedule.selectedDaysOfWeek?.contains(currentDate.weekday) ??
                  false;
          break;
        case 'biweekly':
          shouldCreateSchedule = (count % 2 == 0) &&
              (baseSchedule.selectedDaysOfWeek?.contains(currentDate.weekday) ??
                  false);
          break;
        case 'monthly':
          shouldCreateSchedule = currentDate.day == baseSchedule.start.day;
          break;
        case 'custom':
          shouldCreateSchedule =
              count % (baseSchedule.customInterval ?? 1) == 0;
          break;
      }

      if (shouldCreateSchedule) {
        final duration = baseSchedule.end.difference(baseSchedule.start);
        final newEnd = currentDate.add(duration);

        final newSchedule = baseSchedule.copyWith(
          id: null,
          start: currentDate,
          end: newEnd,
          createdAt: DateTime.now(),
        );

        schedules.add(newSchedule);
      }

      // Move to next iteration
      switch (baseSchedule.recurrencePattern) {
        case 'daily':
          currentDate = currentDate.add(const Duration(days: 1));
          break;
        case 'weekly':
        case 'biweekly':
          currentDate = currentDate.add(const Duration(days: 1));
          break;
        case 'monthly':
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
          );
          break;
        case 'custom':
          currentDate =
              currentDate.add(Duration(days: baseSchedule.customInterval ?? 1));
          break;
      }

      count++;
    }

    return schedules;
  }

  // Update attendance
  Future<void> updateAttendance(
      int scheduleId, AttendanceStatus newStatus) async {
    try {
      isLoading(true);

      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        Get.snackbar('Error', 'Schedule not found');
        return;
      }

      final schedule = schedules[index];

      // Check if this would exceed billed lessons
      if (newStatus == AttendanceStatus.attended &&
          schedule.attendanceStatus != AttendanceStatus.attended) {
        if (!await checkStudentLessonsRemaining(
            schedule.studentId, schedule.courseId, schedule.lessonsDeducted)) {
          return;
        }
      }

      await _dbHelper.updateScheduleAttendance(
          scheduleId, newStatus.toString().split('.').last);

      final updatedSchedule = schedule.copyWith(
        attendanceStatus: newStatus,
        modifiedAt: DateTime.now(),
      );

      schedules[index] = updatedSchedule;
      _applyFilters();

      // Update billing record if needed
      try {
        final billingController = Get.find<BillingController>();
        // Update billing record status logic here
      } catch (e) {
        print('Error updating billing record: $e');
      }

      Get.snackbar(
        'Success',
        'Attendance updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to update attendance: $e');
    } finally {
      isLoading(false);
    }
  }

  // Reschedule
  Future<bool> rescheduleSession(
      int scheduleId, DateTime newStart, DateTime newEnd) async {
    try {
      isLoading(true);

      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        Get.snackbar('Error', 'Schedule not found');
        return false;
      }

      final schedule = schedules[index];

      // Check instructor availability for new time
      if (!await checkInstructorAvailability(
          schedule.instructorId, newStart, newEnd,
          excludeScheduleId: scheduleId)) {
        return false;
      }

      final updatedSchedule = schedule.copyWith(
        start: newStart,
        end: newEnd,
        modifiedAt: DateTime.now(),
      );

      await _dbHelper.updateEnhancedSchedule(updatedSchedule.toJson());
      schedules[index] = updatedSchedule;
      _applyFilters();

      Get.snackbar(
        'Success',
        'Schedule rescheduled successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to reschedule: $e');
      return false;
    } finally {
      isLoading(false);
    }
  }

  // Cancel schedule
  Future<void> cancelSchedule(int scheduleId,
      {bool cancelAllRecurring = false}) async {
    try {
      isLoading(true);

      if (cancelAllRecurring) {
        final schedule = schedules.firstWhereOrNull((s) => s.id == scheduleId);
        if (schedule?.parentScheduleId != null) {
          // Cancel all schedules in the recurring series
          final recurringSchedules = schedules
              .where((s) => s.parentScheduleId == schedule!.parentScheduleId)
              .toList();

          for (final s in recurringSchedules) {
            final cancelledSchedule = s.copyWith(
              status: 'Cancelled',
              modifiedAt: DateTime.now(),
            );
            await _dbHelper.updateEnhancedSchedule(cancelledSchedule.toJson());

            final index = schedules.indexWhere((sch) => sch.id == s.id);
            if (index != -1) {
              schedules[index] = cancelledSchedule;
            }
          }

          Get.snackbar(
            'Success',
            'All recurring schedules cancelled',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        }
      } else {
        // Cancel single schedule
        final index = schedules.indexWhere((s) => s.id == scheduleId);
        if (index == -1) {
          Get.snackbar('Error', 'Schedule not found');
          return;
        }

        final schedule = schedules[index];
        final cancelledSchedule = schedule.copyWith(
          status: 'Cancelled',
          modifiedAt: DateTime.now(),
        );

        await _dbHelper.updateEnhancedSchedule(cancelledSchedule.toJson());
        schedules[index] = cancelledSchedule;

        Get.snackbar(
          'Success',
          'Schedule cancelled successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }

      _applyFilters();
    } catch (e) {
      Get.snackbar('Error', 'Failed to cancel schedule: $e');
    } finally {
      isLoading(false);
    }
  }

  // Delete schedule permanently
  Future<void> deleteSchedule(int scheduleId,
      {bool deleteAllRecurring = false}) async {
    try {
      isLoading(true);

      if (deleteAllRecurring) {
        final schedule = schedules.firstWhereOrNull((s) => s.id == scheduleId);
        if (schedule?.parentScheduleId != null) {
          // Delete all schedules in the recurring series
          final recurringSchedules = schedules
              .where((s) => s.parentScheduleId == schedule!.parentScheduleId)
              .toList();

          for (final s in recurringSchedules) {
            await _dbHelper.deleteEnhancedSchedule(s.id!);
            schedules.removeWhere((sch) => sch.id == s.id);
          }

          Get.snackbar(
            'Success',
            'All recurring schedules deleted',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        }
      } else {
        // Delete single schedule
        await _dbHelper.deleteEnhancedSchedule(scheduleId);
        schedules.removeWhere((s) => s.id == scheduleId);

        Get.snackbar(
          'Success',
          'Schedule deleted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }

      _applyFilters();
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete schedule: $e');
    } finally {
      isLoading(false);
    }
  }

  // Get schedules for a specific day
  List<EnhancedSchedule> getSchedulesForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(Duration(days: 1));

    return filteredSchedules.where((schedule) {
      return schedule.start.isAfter(dayStart) &&
          schedule.start.isBefore(dayEnd) &&
          schedule.status != 'Cancelled';
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  // Get upcoming schedules
  List<EnhancedSchedule> getUpcomingSchedules({int limit = 5}) {
    final now = DateTime.now();
    return filteredSchedules
        .where((s) => s.start.isAfter(now) && s.status != 'Cancelled')
        .take(limit)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  // Get today's stats
  Map<String, int> getTodayStats() {
    final today = DateTime.now();
    final todaySchedules = getSchedulesForDay(today);

    return {
      'total': todaySchedules.length,
      'attended': todaySchedules
          .where((s) => s.attendanceStatus == AttendanceStatus.attended)
          .length,
      'pending': todaySchedules
          .where((s) => s.attendanceStatus == AttendanceStatus.pending)
          .length,
      'absent': todaySchedules
          .where((s) => s.attendanceStatus == AttendanceStatus.absent)
          .length,
    };
  }

  // Search schedules
  Future<void> searchSchedules(String query) async {
    if (query.isEmpty) {
      searchQuery.value = '';
      return;
    }

    try {
      final results = await _dbHelper.searchSchedules(query);
      // Process search results and update filtered schedules
      searchQuery.value = query;
    } catch (e) {
      Get.snackbar('Error', 'Search failed: $e');
    }
  }

  // Clear all filters
  void clearFilters() {
    selectedInstructorFilter.value = '';
    selectedStudentFilter.value = '';
    selectedStatusFilter.value = '';
    searchQuery.value = '';
  }

  // Refresh data
  Future<void> refresh() async {
    await fetchSchedules();
  }
}
