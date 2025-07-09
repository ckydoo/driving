import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/models/user.dart';
import 'package:flutter/material.dart';
import '../../models/fleet.dart';
import 'package:get/get.dart';
import '../../controllers/user_controller.dart';
import '../../widgets/fleet_form_dialog.dart'; // Import FleetFormDialog

class FleetDetailsScreen extends StatelessWidget {
  final int fleetId;

  const FleetDetailsScreen({Key? key, required this.fleetId}) : super(key: key);

  String _getInstructorName(int instructorId) {
    final userController = Get.find<UserController>();

    // Check if users are still loading
    if (userController.isLoading.value) {
      return 'Loading...';
    }

    final instructor = userController.users.firstWhere(
      (user) =>
          user.id == instructorId && user.role.toLowerCase() == 'instructor',
      orElse: () => User(
        id: -1,
        fname: 'Unknown',
        lname: 'Instructor',
        email: '',
        date_of_birth: DateTime.now(),
        password: '',
        role: '',
        status: '',
        created_at: DateTime.now(),
        gender: '',
        phone: '',
        address: '',
        idnumber: '',
      ),
    );
    return instructor.id == -1
        ? 'Unknown Instructor'
        : '${instructor.fname} ${instructor.lname}';
  }

  @override
  Widget build(BuildContext context) {
    final FleetController fleetController = Get.find<FleetController>();
    final fleet =
        fleetController.fleet.firstWhere((vehicle) => vehicle.id == fleetId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vehicle Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            Colors.blue.shade800, // Darker blue for professionalism
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit Vehicle',
            onPressed: () => Get.dialog(FleetFormDialog(vehicle: fleet)),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'Delete Vehicle',
            onPressed: () => _showDeleteConfirmationDialog(fleet),
          ),
        ],
      ),
      body: Obx(
        () {
          // Show a loading indicator while user data is loading
          final userController = Get.find<UserController>();
          if (userController.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.blue, // Match app bar color
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fleet.make} ${fleet.model}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 7, 7, 7),
                      ),
                    ),
                    const SizedBox(height: 24), // Increased spacing

                    _buildDetailRow(
                        Icons.directions_car, 'Car Plate', fleet.carPlate),
                    _buildDetailRow(
                        Icons.calendar_today, 'Model Year', fleet.modelYear),
                    _buildDetailRow(Icons.person, 'Instructor',
                        _getInstructorName(fleet.instructor)),
                    // Add more details as needed
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0), // Added padding
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade800, size: 24),
          const SizedBox(width: 16), // Increased spacing
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 63, 61, 61),
              ),
              children: [
                TextSpan(text: '$label: '),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(Fleet fleet) {
    Get.defaultDialog(
      title: 'Confirm Delete',
      content: const Text('Are you sure you want to delete this vehicle?'),
      confirm: TextButton(
        onPressed: () {
          Get.find<FleetController>().deleteFleet(fleet.id!);
          Get.back(); // Close the dialog
          Get.back(); // Close the details screen
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.red, // Consistent delete button color
        ),
        child: const Text('Delete'),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }
}
