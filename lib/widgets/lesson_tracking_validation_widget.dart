// lib/widgets/lesson_tracking_validation_widget.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/schedule_controller.dart';

/// Widget for validating and maintaining lesson tracking system integrity
class LessonTrackingValidationWidget extends StatelessWidget {
  const LessonTrackingValidationWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheduleController = Get.find<ScheduleController>();

    return Card(
      elevation: 4,
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  'Lesson Tracking System Health',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Validate the integrity of lesson tracking, billing calculations, and status consistency.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 20),
            
            // Validation Actions
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Run Full Validation
                Obx(() => ElevatedButton.icon(
                  onPressed: scheduleController.isLoading.value
                      ? null
                      : () => scheduleController.validateLessonTrackingSystem(),
                  icon: scheduleController.isLoading.value
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.check_circle),
                  label: Text('Run Full Validation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                )),

                // Fix Inconsistencies
                Obx(() => ElevatedButton.icon(
                  onPressed: scheduleController.isLoading.value
                      ? null
                      : () => scheduleController.fixInconsistentSchedules(),
                  icon: scheduleController.isLoading.value
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.auto_fix_high),
                  label: Text('Fix Status Issues'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                )),

                // Run Status Migration
                Obx(() => ElevatedButton.icon(
                  onPressed: scheduleController.isLoading.value
                      ? null
                      : () => scheduleController.runStatusMigration(),
                  icon: scheduleController.isLoading.value
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.update),
                  label: Text('Run Status Migration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                )),
              ],
            ),

            SizedBox(height: 20),

            // Key Principles
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Principles',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildPrincipleItem(
                    '✅ Only attended/completed lessons are deducted from billing',
                  ),
                  _buildPrincipleItem(
                    '✅ Marking attendance automatically sets status to "completed"',
                  ),
                  _buildPrincipleItem(
                    '✅ All progress calculations use attended lessons only',
                  ),
                  _buildPrincipleItem(
                    '✅ Scheduling does NOT deduct lessons (only attendance does)',
                  ),
                  _buildPrincipleItem(
                    '✅ Status and attendance flags must always be consistent',
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // System Status
            Obx(() {
              final inconsistentCount = scheduleController.inconsistentSchedules.length;
              final totalSchedules = scheduleController.schedules.length;
              
              return Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: inconsistentCount == 0 ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: inconsistentCount == 0 ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      inconsistentCount == 0 ? Icons.check_circle : Icons.warning,
                      color: inconsistentCount == 0 ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inconsistentCount == 0
                            ? 'All $totalSchedules schedules are consistent'
                            : '$inconsistentCount of $totalSchedules schedules have status/attendance inconsistencies',
                        style: TextStyle(
                          color: inconsistentCount == 0 ? Colors.green.shade700 : Colors.orange.shade700,
                          fontWeight: FontWeight.medium,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPrincipleItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}