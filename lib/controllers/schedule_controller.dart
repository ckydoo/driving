import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/models/billing_record.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/schedule.dart';
import '../services/database_helper.dart';
import 'package:driving/widgets/create_invoice_dialog.dart'; // Import the dialog

class ScheduleController extends GetxController {
  final RxList<Schedule> schedules = <Schedule>[].obs;
  final RxBool isLoading = false.obs;
  final DatabaseHelper _dbHelper = Get.find();

  @override
  void onReady() {
    fetchSchedules();
    Get.find<BillingController>().fetchBillingData();
    super.onReady();
  }

  Future<void> fetchSchedules() async {
    try {
      isLoading(true);
      final data = await _dbHelper.getSchedules();
      schedules.assignAll(data.map(Schedule.fromJson));
    } catch (e) {
      Get.snackbar('Error', 'Failed to load schedules: ${e.toString()}');
      print("Error fetching schedules: $e");
    } finally {
      isLoading(false);
    }
  }

  Future<void> toggleAttendance(int scheduleId, bool attended) async {
    try {
      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) return;

      final schedule = schedules[index];
      final lessonsChange = attended
          ? schedule.lessonsDeducted
          : -schedule.lessonsDeducted; // Calculate change

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

      // Update billing record status
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
          // Assuming one billing record per schedule
          await billingController.updateBillingRecordStatus(
            billingRecords.first.id!,
            attended ? "Completed" : "Scheduled",
          );
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to update attendance');
    }
  }

  bool _isBilledLessonsExceeded(Schedule schedule) {
    final billingController = Get.find<BillingController>();
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) =>
          inv.studentId == schedule.studentId &&
          inv.courseId == schedule.courseId,
    );
    // Use lessons here
    final totalLessons = invoice?.lessons ?? 0;

    if (invoice == null) return false; // Handle case where invoice is not found

    // Calculate used lessons from attended schedules excluding current one
    final usedLessons = schedules
        .where((s) =>
            s.studentId == schedule.studentId &&
            s.attended &&
            s.id != schedule.id)
        .fold(0, (sum, s) => sum + s.lessonsDeducted);

    // Add current schedule's lessons if attended
    final potentialAddedLessons =
        schedule.attended ? schedule.lessonsDeducted : 0;

    return (usedLessons + potentialAddedLessons) > (totalLessons);
  }

  double calculateScheduleProgress(Schedule schedule) {
    final billingController = Get.find<BillingController>();
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) =>
          inv.studentId == schedule.studentId &&
          inv.courseId == schedule.courseId,
    );
    // Use lessons here
    final totalLessons = invoice?.lessons ?? 0;

    if (totalLessons == 0) return 0;

    final progress = (schedule.lessonsCompleted / totalLessons) * 100;
    return progress;
  }

  Future<bool> checkAvailability(
      int instructorId, DateTime start, DateTime end) async {
    return !schedules.any((s) {
      return s.instructorId == instructorId &&
          start.isBefore(s.end) &&
          end.isAfter(s.start) &&
          s.status != 'Canceled'; // Only check non-canceled schedules
    });
  }

  Future<void> deleteSchedule(int scheduleId) async {
    try {
      isLoading(true);
      await _dbHelper.deleteSchedule(scheduleId);
      schedules.removeWhere((s) => s.id == scheduleId);
      schedules.refresh();
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete schedule');
    } finally {
      isLoading(false);
    }
  }

  Future<void> addOrUpdateSchedule(Schedule schedule) async {
    try {
      print("addOrUpdateSchedule called with schedule: ${schedule.toJson()}");
      isLoading(true);

      // // Validate session duration
      // final minutes = schedule.end.difference(schedule.start).inMinutes;
      // if (minutes <= 0 || minutes % 30 != 0) {
      //   Get.snackbar(
      //       'Invalid Duration', 'Sessions must be in 30-minute increments',
      //       backgroundColor: Colors.red);
      //   print('Sessions must be in 30-minute increments');
      //   return;
      // }

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

      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == schedule.studentId &&
            inv.courseId == schedule.courseId,
      );

      final exists = schedules.any((s) => s.id == schedule.id);
      print("Schedule exists: $exists");
      if (exists) {
        print("Updating schedule");
        final index = schedules.indexWhere((s) => s.id == schedule.id);
        schedules[index] = schedule;
        await _dbHelper.updateSchedule(schedule.toJson());
        print("Schedule updated");
      } else {
        print("Inserting schedule");
        final id = await _dbHelper.insertSchedule(schedule.toJson());
        print("Schedule inserted with id: $id");
        final newSchedule = schedule.copyWith(id: id);
        schedules.add(newSchedule);

        if (invoice != null) {
          // Calculate billing amount
          double billingAmount = _calculateBillingAmount(newSchedule);

          // Create billing record
          BillingRecord billingRecord = BillingRecord(
            scheduleId: newSchedule.id!,
            invoiceId: invoice.id!,
            studentId: newSchedule.studentId,
            amount: billingAmount,
            dueDate: newSchedule.start.add(Duration(days: 14)), // Example
            status: "Scheduled", createdAt: DateTime.now(),
            description: "Billing for schedule ${newSchedule.id}",
          );
          int billingRecordId =
              await billingController.insertBillingRecord(billingRecord);
          print("Billing record created with id: $billingRecordId");
        } else {
          // Invoice not found: Prompt user
          print(
              "Invoice not found for student ${newSchedule.studentId} and course ${newSchedule.courseId}");
          Get.snackbar(
            "Billing",
            "Invoice not found. Please create an invoice for this student and course.",
            snackPosition: SnackPosition.BOTTOM,
            duration: Duration(seconds: 5),
            mainButton: TextButton(
              onPressed: () {
                Get.back(); // Close the snackbar
                Get.dialog(CreateInvoiceDialog(// Use your dialog
                    //  studentId: newSchedule.studentId,
                    //  courseId: newSchedule.courseId,
                    ));
              },
              child: Text("Create Invoice"),
            ),
          );
        }
      }

      schedules.refresh();
      print("Schedules refreshed");
    } catch (e, stackTrace) {
      print("Error in addOrUpdateSchedule: $e");
      print("StackTrace: $stackTrace");
      Get.snackbar('Error', 'Failed to add/update schedule: ${e.toString()}');
    } finally {
      isLoading(false);
      print("isLoading set to false");
    }
  }

  List<Schedule> getDailySchedules(DateTime day) {
    return schedules
        .where((s) =>
            s.start.year == day.year &&
            s.start.month == day.month &&
            s.start.day == day.day)
        .toList();
  }

  Future<void> updateLessonCompletion(int scheduleId, bool completed) async {
    try {
      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) return;

      final schedule = schedules[index];
      final lessonsChange =
          completed ? schedule.lessonsDeducted : -schedule.lessonsDeducted;
      final newCount = schedule.lessonsCompleted + lessonsChange;

      final updated = schedule.copyWith(
        lessonsCompleted: newCount,
      );

      await _dbHelper.updateSchedule({
        'id': scheduleId,
        'lessonsCompleted': newCount,
      });

      schedules[index] = updated;
      schedules.refresh();
    } catch (e) {
      Get.snackbar('Error', 'Failed to update lesson completion');
    }
  }

  double calculateCourseProgress(int studentId) {
    final billingController = Get.find<BillingController>();
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) => inv.studentId == studentId,
    );
    // Use lessons here
    final totalLessons = invoice?.lessons ?? 0;

    if (totalLessons == 0) return 0;

    final completedLessons = schedules
        .where((s) => s.studentId == studentId && s.attended)
        .fold(0, (sum, s) => sum + s.lessonsDeducted);

    return (completedLessons / totalLessons) * 100;
  }

  int getTotalCompletedLessons(int studentId) {
    return schedules
        .where((s) => s.studentId == studentId && s.attended)
        .fold(0, (sum, s) => sum + s.lessonsDeducted);
  }

  Future<void> cancelSchedule(int scheduleId) async {
    try {
      isLoading(true);
      final schedule = schedules.firstWhere((s) => s.id == scheduleId);
      final updatedSchedule = schedule.copyWith(status: 'Canceled');
      await _dbHelper.updateSchedule(updatedSchedule.toJson());
      final index = schedules.indexWhere((s) => s.id == scheduleId);
      schedules[index] = updatedSchedule;
      schedules.refresh();

      // Handle billing implications of cancellation here
      final billingController = Get.find<BillingController>();
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) =>
            inv.studentId == schedule.studentId &&
            inv.courseId == schedule.courseId,
      );
      if (invoice != null) {
        // Remove billing record
        final billingRecords =
            await billingController.getBillingRecordsForInvoice(invoice.id!);
        if (billingRecords.isNotEmpty) {
          // Assuming one billing record per schedule
          await _dbHelper.deleteBillingRecord(
              billingRecords.first.id!); // Add this method to DatabaseHelper
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to cancel schedule');
    } finally {
      isLoading(false);
    }
  }

  Future<void> rescheduleSchedule(int scheduleId, Schedule newSchedule) async {
    try {
      isLoading(true);
      await cancelSchedule(scheduleId); // Cancel the original

      // Add the new schedule
      final id = await _dbHelper.insertSchedule(newSchedule.toJson());
      schedules.add(newSchedule.copyWith(id: id));
      schedules.refresh();

      Get.snackbar('Success', 'Schedule rescheduled');
    } catch (e) {
      Get.snackbar('Error', 'Failed to reschedule schedule');
    } finally {
      isLoading(false);
    }
  }

  // Helper functions:

  double _calculateBillingAmount(Schedule schedule) {
    // Get billing data
    final billingController = Get.find<BillingController>();
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) => inv.studentId == schedule.studentId,
    );

    // Logic to calculate billing amount based on schedule details
    // (e.g., course price, duration)
    final courseController = Get.find<CourseController>();
    courseController.courses
        .firstWhere((course) => course.id == schedule.courseId);
    // final pricePerLesson = course.price / course.lessons; // Removed
    // return pricePerLesson * schedule.lessonsDeducted;

    // Fetch price per lesson from invoice
    final pricePerLesson =
        invoice?.pricePerLesson ?? 0; // Use pricePerLesson from invoice

    return pricePerLesson * schedule.lessonsDeducted;
  }
}
