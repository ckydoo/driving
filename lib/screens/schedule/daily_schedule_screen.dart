import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/fleet.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/user.dart';
import 'package:driving/widgets/edit_schedule_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class DailyScheduleScreen extends StatefulWidget {
  final DateTime selectedDate;

  const DailyScheduleScreen({Key? key, required this.selectedDate})
      : super(key: key);

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen> {
  final ScheduleController controller = Get.find<ScheduleController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Daily Schedule - ${DateFormat.yMMMd().format(widget.selectedDate)}',
          style: Theme.of(context).textTheme.titleLarge, // Use titleLarge style
        ),
        centerTitle: true, // Center the title
        elevation: 2, // Add a subtle shadow
      ),
      body: _buildScheduleList(),
    );
  }

  Widget _buildScheduleList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final dailySchedules = controller
          .getDailySchedules(widget.selectedDate); // Use widget.selectedDate

      if (dailySchedules.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No schedules found for this day',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: dailySchedules.length,
        padding:
            const EdgeInsets.symmetric(vertical: 8), // Add padding to the list
        itemBuilder: (context, index) {
          final schedule = dailySchedules[index];
          return _buildScheduleItem(schedule);
        },
      );
    });
  }

  Widget _buildScheduleItem(Schedule schedule) {
    final billingController = Get.find<BillingController>();
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) => inv.studentId == schedule.studentId,
    );
    final totalLessons = invoice?.lessons ?? 0;
    final overallProgress =
        controller.calculateCourseProgress(schedule.studentId);

    // Calculate remainingLessons here, taking attended status into account
    final remainingLessons =
        totalLessons - overallProgress * totalLessons ~/ 100;
    print(remainingLessons);
    // Check if the lesson time has passed
    final now = DateTime.now();
    final lessonEndTime = schedule.end;
    final isLessonPast = now.isAfter(lessonEndTime);

    // Determine if the schedule is canceled
    final isCanceled = schedule.status == 'Canceled';

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8), // More padding
      elevation: 1, // Subtle shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // Rounded corners
      ),
      child: InkWell(
        // Add touch feedback
        onTap: () {
          // You can add an onTap action here if needed, like showing details
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCanceled
                        ? 'Canceled: Lesson #${schedule.lessonsCompleted + 1}'
                        : 'Lesson #${schedule.lessonsCompleted + 1}',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          decoration:
                              isCanceled ? TextDecoration.lineThrough : null,
                          color: isCanceled ? Colors.grey : null,
                          fontWeight: FontWeight.w600, // Bolden the title
                        ),
                  ),
                  _buildLessonStatus(schedule, isCanceled: isCanceled),
                ],
              ),
              const Divider(height: 16),
              _buildUserInfo(schedule.studentId, 'Student'),
              _buildUserInfo(schedule.instructorId, 'Instructor'),
              if (schedule.carId != null) _buildVehicleInfo(schedule.carId!),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Time: ${DateFormat('HH:mm').format(schedule.start)} - ${DateFormat('HH:mm').format(schedule.end)}',
                    style: TextStyle(
                      color: isCanceled ? Colors.grey : Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.calendar_month,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Date: ${DateFormat.yMMMd().format(schedule.start)}',
                    style: TextStyle(
                      color: isCanceled ? Colors.grey : Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Duration: ${schedule.duration}',
                    style: TextStyle(
                      color: isCanceled ? Colors.grey : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildProgressIndicator(overallProgress, remainingLessons),
              if (!isCanceled)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isLessonPast)
                      IconButton(
                        icon: Icon(
                          schedule.attended
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          controller.toggleAttendance(
                              schedule.id!, !schedule.attended);
                        },
                      ),
                    if (!isLessonPast)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => Get.dialog(EditScheduleScreen(
                          schedule: schedule,
                        )),
                      ),
                    if (!isLessonPast)
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        tooltip: 'Cancel Schedule',
                        onPressed: () => _showCancelDialog(schedule, context),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLessonStatus(Schedule schedule, {bool isCanceled = false}) {
    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (isCanceled) {
      statusText = 'Canceled';
      statusIcon = Icons.cancel;
      statusColor = Colors.grey;
    } else if (schedule.attended) {
      statusText = 'Attended';
      statusIcon = Icons.check_circle; // Use filled icon
      statusColor = Colors.green;
    } else if (DateTime.now().isBefore(schedule.start)) {
      // Check if the lesson is in the future
      statusText = 'Pending';
      statusIcon = Icons.pending;
      statusColor = Colors.orange;
    } else {
      statusText = 'Missed';
      statusIcon = Icons.highlight_off; // Use a more fitting icon
      statusColor = Colors.red;
    }

    return Row(
      children: [
        Icon(
          statusIcon,
          color: statusColor,
          size: 20, // Increased size
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.w500, // Slightly bolder
            //  fontStyle: isCanceled ? FontStyle.italic : null, // Italic style for canceled
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(double progress, int remainingLessons) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 80
                  ? Colors.green
                  : progress >= 50
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Course Progress: ${progress.toStringAsFixed(1)}% (${remainingLessons.abs()} ${remainingLessons >= 0 ? 'to go' : 'over'})',
            style: const TextStyle(
                fontSize: 12, color: Colors.black54), // Muted color
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(int userId, String role) {
    final userController = Get.find<UserController>();
    return Obx(() {
      final user = userController.users.firstWhere(
        (u) => u.id == userId,
        orElse: () => User(
          id: -1,
          fname: 'Loading...',
          lname: '',
          email: '',
          password: '',
          gender: '',
          phone: '',
          address: '',
          date_of_birth: DateTime.now(),
          role: '',
          status: '',
          idnumber: '',
          created_at: DateTime.now(),
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              role == 'Student' ? Icons.school : Icons.person,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              '$role: ${user.fname} ${user.lname}',
              style: TextStyle(
                color: user.id == -1 ? Colors.grey : Colors.black87,
                fontStyle: user.id == -1 ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildVehicleInfo(int vehicleId) {
    final fleetController = Get.find<FleetController>();
    return Obx(() {
      final vehicle = fleetController.fleet.firstWhere(
        (v) => v.id == vehicleId,
        orElse: () => Fleet(
          id: -1,
          make: 'Loading...',
          model: '',
          carPlate: '',
          modelYear: '',
          instructor: 0,
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(Icons.directions_car, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              'Vehicle: ${vehicle.make} ${vehicle.model} (${vehicle.carPlate})',
              style: TextStyle(
                color: vehicle.id == -1 ? Colors.grey : Colors.black87,
                fontStyle: vehicle.id == -1 ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showCancelDialog(Schedule schedule, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cancel Schedule',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: Text(
            'Are you sure you want to cancel this schedule?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('No', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Yes',
                  style: TextStyle(color: Theme.of(context).primaryColor)),
              onPressed: () {
                controller.cancelSchedule(schedule.id!);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
