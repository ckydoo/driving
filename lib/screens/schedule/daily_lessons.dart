// Filtered Date Lessons Dialog - Shows only schedules matching current filters

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/widgets/schedule_details_dialog.dart';

class FilteredDateLessonsDialog extends StatelessWidget {
  final DateTime selectedDate;
  final List<Schedule> schedules;
  final String filterText;
  final bool hasActiveFilters;

  const FilteredDateLessonsDialog({
    Key? key,
    required this.selectedDate,
    required this.schedules,
    required this.filterText,
    required this.hasActiveFilters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(selectedDate);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader(isToday),
            if (hasActiveFilters) _buildFilterInfo(),
            Flexible(
              child:
                  schedules.isEmpty ? _buildEmptyState() : _buildLessonsList(),
            ),
            _buildDialogActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isToday) {
    final dayName = DateFormat('EEEE').format(selectedDate);
    final dateStr = DateFormat('MMM d, yyyy').format(selectedDate);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isToday ? Colors.blue.shade600 : Colors.grey.shade700,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isToday ? Icons.today : Icons.calendar_today,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${schedules.length} lesson${schedules.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (schedules.isNotEmpty) ...[
            SizedBox(height: 12),
            _buildQuickStats(),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterInfo() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 16,
            color: Colors.blue.shade600,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered: $filterText',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.blue.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final completed = schedules.where((s) => s.attended).length;
    final inProgress = schedules.where((s) => s.isInProgress).length;
    final upcoming = schedules.where((s) => s.isUpcoming).length;
    final cancelled = schedules.where((s) => s.status == 'Cancelled').length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (completed > 0) _buildStatChip('Completed', completed, Colors.green),
        if (inProgress > 0)
          _buildStatChip('In Progress', inProgress, Colors.orange),
        if (upcoming > 0) _buildStatChip('Upcoming', upcoming, Colors.blue),
        if (cancelled > 0) _buildStatChip('Cancelled', cancelled, Colors.red),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String emptyMessage = hasActiveFilters
        ? 'No lessons match the current filters for this date'
        : 'No lessons scheduled for this date';

    String emptySubtitle = hasActiveFilters
        ? 'Try adjusting your filters or schedule a new lesson'
        : 'This day is free for new scheduling';

    return Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasActiveFilters ? Icons.filter_list_off : Icons.event_available,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            emptySubtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsList() {
    // Sort by start time
    final sortedSchedules = List<Schedule>.from(schedules);
    sortedSchedules.sort((a, b) => a.start.compareTo(b.start));

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.all(16),
      itemCount: sortedSchedules.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildLessonCard(sortedSchedules[index]);
      },
    );
  }

  Widget _buildLessonCard(Schedule schedule) {
    final student = Get.find<UserController>().users.firstWhereOrNull(
          (user) => user.id == schedule.studentId,
        );
    final instructor = Get.find<UserController>().users.firstWhereOrNull(
          (user) => user.id == schedule.instructorId,
        );
    final course = Get.find<CourseController>().courses.firstWhereOrNull(
          (c) => c.id == schedule.courseId,
        );

    return InkWell(
      onTap: () {
        // Close current dialog and immediately show new one
        Get.back();

        // Use a post-frame callback to ensure clean transition
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.dialog(ScheduleDetailsDialog(schedule: schedule));
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getCardBackgroundColor(schedule),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getCardBorderColor(schedule),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Time and Status Row
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '${DateFormat.jm().format(schedule.start)} - ${DateFormat.jm().format(schedule.end)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '(${schedule.duration})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(schedule),
              ],
            ),

            SizedBox(height: 12),

            // Student and Course Info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.blue),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${student?.fname ?? 'Unknown'} ${student?.lname ?? ''}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              course?.name ?? 'Unknown Course',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 16, color: Colors.purple),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Instructor: ${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Icon
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            // In Progress Indicator
            if (schedule.isInProgress) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Lesson currently in progress',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Schedule schedule) {
    final status = schedule.statusDisplay;
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogActions() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Get.back(),
              child: Text('Close'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Color _getCardBackgroundColor(Schedule schedule) {
    if (schedule.status == 'Cancelled') return Colors.red.shade50;
    if (schedule.attended) return Colors.green.shade50;
    if (schedule.isInProgress) return Colors.orange.shade50;
    return Colors.blue.shade50;
  }

  Color _getCardBorderColor(Schedule schedule) {
    if (schedule.status == 'Cancelled') return Colors.red.shade300;
    if (schedule.attended) return Colors.green.shade300;
    if (schedule.isInProgress) return Colors.orange.shade300;
    return Colors.blue.shade300;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'missed':
        return Colors.red.shade400;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Icons.play_circle_filled;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'missed':
        return Icons.event_busy;
      default:
        return Icons.schedule;
    }
  }
}
