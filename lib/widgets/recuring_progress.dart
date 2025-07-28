// Progress Dialog Widget for Recurring Schedule - Issue 3 fix

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RecurringScheduleProgressDialog extends StatelessWidget {
  final int totalSchedules;
  final Function(int successCount, int conflictCount) onComplete;

  const RecurringScheduleProgressDialog({
    Key? key,
    required this.totalSchedules,
    required this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize controller
    Get.put(RecurringScheduleProgressController(
      totalSchedules: totalSchedules,
      onComplete: onComplete,
    ));

    return GetBuilder<RecurringScheduleProgressController>(
      builder: (controller) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  CircularProgressIndicator(
                    value: controller.isComplete ? 1.0 : controller.progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      controller.isComplete ? Colors.green : Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.isComplete
                              ? 'Schedule Creation Complete'
                              : 'Creating Recurring Schedules',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          controller.isComplete
                              ? 'All schedules processed'
                              : 'Processing ${controller.currentIndex} of ${controller.totalSchedules}...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Progress Bar
              LinearProgressIndicator(
                value: controller.progress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  controller.isComplete ? Colors.green : Colors.blue,
                ),
              ),

              SizedBox(height: 16),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    'Successful',
                    controller.successCount.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                  _buildStatItem(
                    'Conflicts',
                    controller.conflictCount.toString(),
                    Colors.orange,
                    Icons.warning,
                  ),
                  _buildStatItem(
                    'Total',
                    controller.totalSchedules.toString(),
                    Colors.blue,
                    Icons.event,
                  ),
                ],
              ),

              if (controller.isComplete) ...[
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => controller.finish(),
                    child: Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class RecurringScheduleProgressController extends GetxController {
  final int totalSchedules;
  final Function(int successCount, int conflictCount) onComplete;

  int currentIndex = 0;
  int successCount = 0;
  int conflictCount = 0;
  bool isComplete = false;

  RecurringScheduleProgressController({
    required this.totalSchedules,
    required this.onComplete,
  });

  double get progress =>
      totalSchedules > 0 ? currentIndex / totalSchedules : 0.0;

  void updateProgress(int index, int total, int success, int conflicts) {
    currentIndex = index;
    successCount = success;
    conflictCount = conflicts;
    update();
  }

  void complete(int success, int conflicts) {
    currentIndex = totalSchedules;
    successCount = success;
    conflictCount = conflicts;
    isComplete = true;
    update();
  }

  void finish() {
    onComplete(successCount, conflictCount);
    Get.delete<RecurringScheduleProgressController>();
  }
}
