import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/engagement_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class EngagementController extends GetxController {
  final RxBool isLoadingBriefing = false.obs;
  final RxBool isLoadingOverdue = false.obs;

  final RxMap<String, dynamic> instructorBriefing = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> overdueBoard =
      <Map<String, dynamic>>[].obs;

  final RxString error = ''.obs;

  AuthController get _auth => Get.find<AuthController>();

  bool get isInstructor =>
      _auth.currentUser.value?.role.toLowerCase() == 'instructor';
  bool get isAdmin => _auth.currentUser.value?.role.toLowerCase() == 'admin';

  int get paymentsDueCount {
    final list = instructorBriefing['payments_due'];
    if (list is List) return list.length;
    return 0;
  }

  int get lessonsTodayCount {
    final value = instructorBriefing['total_lessons'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Future<void> refreshDashboardEngagement({
    required bool briefingEnabled,
    required bool overdueEnabled,
  }) async {
    error.value = '';

    final futures = <Future<void>>[];

    if (briefingEnabled && (isInstructor || isAdmin)) {
      futures.add(fetchInstructorBriefing());
    }

    if (overdueEnabled && isAdmin) {
      futures.add(fetchOverdueBoard());
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> fetchInstructorBriefing() async {
    try {
      isLoadingBriefing.value = true;
      final currentUser = _auth.currentUser.value;
      final instructorId = currentUser?.role.toLowerCase() == 'instructor'
          ? currentUser?.id
          : null;

      final data = await EngagementService.getInstructorDailyBriefing(
        date: DateTime.now(),
        instructorId: instructorId,
      );

      if (data != null) {
        instructorBriefing.assignAll(data);
      }
    } catch (e) {
      debugPrint('EngagementController.fetchInstructorBriefing error: $e');
      error.value = 'Failed to load instructor briefing.';
    } finally {
      isLoadingBriefing.value = false;
    }
  }

  Future<void> fetchOverdueBoard() async {
    try {
      isLoadingOverdue.value = true;
      final rows = await EngagementService.getOverdueBoard();
      overdueBoard.assignAll(rows);
    } catch (e) {
      debugPrint('EngagementController.fetchOverdueBoard error: $e');
      error.value = 'Failed to load overdue board.';
    } finally {
      isLoadingOverdue.value = false;
    }
  }
}
