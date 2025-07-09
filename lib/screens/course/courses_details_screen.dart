import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/course_controller.dart';
import '../../models/course.dart';
import '../../widgets/course_form_dialog.dart'; // Import CourseFormDialog

class CourseDetailsScreen extends StatelessWidget {
  final int courseId;

  const CourseDetailsScreen({Key? key, required this.courseId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final CourseController courseController = Get.find<CourseController>();
    final course =
        courseController.courses.firstWhere((course) => course.id == courseId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Course Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Course',
            onPressed: () => Get.dialog(CourseFormDialog(course: course)),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Course',
            onPressed: () => _showDeleteConfirmationDialog(context, course),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 23, 23, 24),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                    Icons.attach_money, 'Price', '\$${course.price}'),
                _buildDetailRow(Icons.star, 'Status', course.status),
                _buildDetailRow(Icons.calendar_today, 'Created At',
                    course.createdAt.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.blueAccent,
            size: 24,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 36, 37, 37),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Course course) {
    Get.dialog(
      AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.find<CourseController>().deleteCourse(course.id!);
              Navigator.of(context).pop(); // Close the dialog
              Get.back(); // Close the details screen
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
