// lib/controllers/schedule_controller.dart
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/billing_record.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/schedule.dart';
import '../services/database_helper.dart';
import 'package:driving/widgets/create_invoice_dialog.dart';

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

  // Attendance management
  Future<void> toggleAttendance(int scheduleId, bool attended) async {
    try {
      isLoading(true);

      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        Get.snackbar('Error', 'Schedule not found');
        return;
      }

      final schedule = schedules[index];
      final lessonsChange =
          attended ? schedule.lessonsDeducted : -schedule.lessonsDeducted;

      // Create temporary schedule with proposed changes
      final tempSchedule = schedule.copyWith(
        attended: attended,
        lessonsCompleted: schedule.lessonsCompleted + lessonsChange,
      );

      if (attended && _isBilledLessonsExceeded(tempSchedule)) {
        Get.snackbar(
          'Lesson Limit Exceeded',
          'Cannot mark as attended. Student has no remaining lessons.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final updated = schedule.copyWith(
        attended: attended,
        lessonsCompleted: schedule.lessonsCompleted + lessonsChange,
      );

      await _dbHelper.updateSchedule({
        'id': scheduleId,
        'attended': attended ? 1 : 0,
        'lessonsCompleted': updated.lessonsCompleted,
      });

      schedules[index] = updated;
      schedules.refresh();
      _applyFilters();

      // Update billing record status if billing controller exists
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
      }

      Get.snackbar(
        'Success',
        attended ? 'Marked as attended' : 'Marked as not attended',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to update attendance: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  bool _isBilledLessonsExceeded(Schedule schedule) {
    try {
      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == schedule.studentId &&
            inv.courseId == schedule.courseId,
      );

      if (invoice == null) return false;

      final totalLessons = invoice.lessons;
      final usedLessons = schedules
          .where((s) =>
              s.studentId == schedule.studentId &&
              s.courseId == schedule.courseId &&
              s.attended)
          .fold<int>(0, (sum, s) => sum + s.lessonsDeducted);

      final potentialAddedLessons =
          schedule.attended ? schedule.lessonsDeducted : 0;

      return (usedLessons + potentialAddedLessons) > totalLessons;
    } catch (e) {
      print('Error checking billing lessons: $e');
      return false;
    }
  }

  // Schedule management
  Future<void> addOrUpdateSchedule(Schedule schedule) async {
    try {
      isLoading(true);

      // Check availability
      if (!await checkAvailability(
          schedule.instructorId, schedule.start, schedule.end)) {
        Get.snackbar(
          'Scheduling Conflict',
          'The selected instructor is already booked for this time slot.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      if (schedule.id == null) {
        // Adding new schedule
        final id = await _dbHelper.insertSchedule(schedule.toJson());
        final newSchedule = schedule.copyWith(id: id);
        schedules.add(newSchedule);
      } else {
        // Updating existing schedule
        await _dbHelper.updateSchedule(schedule.toJson());
        final index = schedules.indexWhere((s) => s.id == schedule.id);
        if (index != -1) {
          schedules[index] = schedule;
        }
      }

      schedules.refresh();
      _applyFilters();

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
    } finally {
      isLoading(false);
    }
  }

  Future<bool> checkAvailability(
      int instructorId, DateTime start, DateTime end) async {
    return !schedules.any((s) {
      return s.instructorId == instructorId &&
          start.isBefore(s.end) &&
          end.isAfter(s.start) &&
          s.status != 'Cancelled';
    });
  }

  Future<void> cancelSchedule(int scheduleId) async {
    try {
      isLoading(true);

      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        Get.snackbar('Error', 'Schedule not found');
        return;
      }

      final schedule = schedules[index];
      final cancelledSchedule = schedule.copyWith(status: 'Cancelled');

      await _dbHelper.updateSchedule({
        'id': scheduleId,
        'status': 'Cancelled',
      });

      schedules[index] = cancelledSchedule;
      schedules.refresh();
      _applyFilters();

      // Handle billing record cleanup if needed
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

  Future<void> rescheduleSchedule(int scheduleId, Schedule newSchedule) async {
    try {
      isLoading(true);

      await cancelSchedule(scheduleId);
      await addOrUpdateSchedule(newSchedule);

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

  // Progress calculation
  double calculateScheduleProgress(Schedule schedule) {
    try {
      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == schedule.studentId &&
            inv.courseId == schedule.courseId,
      );

      final totalLessons = invoice?.lessons ?? 0;
      if (totalLessons == 0) return 0;

      final progress = (schedule.lessonsCompleted / totalLessons) * 100;
      return progress.clamp(0.0, 100.0);
    } catch (e) {
      print('Error calculating progress: $e');
      return 0;
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

    final now = DateTime.now();

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
}
