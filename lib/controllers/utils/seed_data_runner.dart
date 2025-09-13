// lib/utils/seed_data_runner.dart
import 'package:driving/services/test_data_seeder.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SeedDataRunner {
  /// Run seed data with user confirmation
  static Future<void> runSeedDataWithConfirmation(BuildContext context) async {
    // Check if test data already exists
    final existingData = await TestDataSeeder.instance.checkTestDataExists();

    String message = 'Do you want to create default test data?\n\n';
    message += 'This will create:\n';
    message += '• 6 Test Users (1 Admin, 2 Instructors, 3 Students)\n';
    message += '• 6 Courses (Basic to Advanced)\n';
    message += '• 8 Fleet Vehicles\n\n';

    if (existingData['users'] == true ||
        existingData['courses'] == true ||
        existingData['fleet'] == true) {
      message += '⚠️ Some test data already exists and may be updated.\n\n';
    }

    message += 'Login Credentials:\n';
    message += '📧 admin@test.com | 🔑 admin123\n';
    message += '📧 instructor1@test.com | 🔑 instructor123\n';
    message += '📧 student1@test.com | 🔑 student123';

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_ic_call_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Seed Test Data'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Create Test Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _runSeedDataWithProgress();
    }
  }

  /// Run seed data with progress indicator
  static Future<void> _runSeedDataWithProgress() async {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Creating Test Data...'),
          ],
        ),
        content: Text('Please wait while we set up your test data.'),
      ),
      barrierDismissible: false,
    );

    try {
      await TestDataSeeder.instance.seedAllTestData();

      Get.back(); // Close progress dialog

      // Show success dialog
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Test data created successfully!\n'),
              Text('Login Credentials:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _buildCredentialRow('Admin', 'admin@test.com', 'admin123'),
              _buildCredentialRow(
                  'Instructor', 'instructor1@test.com', 'instructor123'),
              _buildCredentialRow('Student', 'student1@test.com', 'student123'),
              SizedBox(height: 12),
              Text(
                  'You can now use these credentials to test different user roles.',
                  style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Great!'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.back(); // Close progress dialog

      // Show error dialog
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text('Failed to create test data:\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  static Widget _buildCredentialRow(
      String role, String email, String password) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$role:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              '$email | $password',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Quick seed for development (no confirmation)
  static Future<void> quickSeed() async {
    try {
      print('🚀 Quick seeding test data...');
      await TestDataSeeder.instance.seedAllTestData();
      print('✅ Quick seed completed!');
    } catch (e) {
      print('❌ Quick seed failed: $e');
    }
  }

  /// Seed only users (useful for auth testing)
  static Future<void> seedUsersOnly() async {
    Get.dialog(
      AlertDialog(
        title: Text('Seed Users Only'),
        content: Text('Create test users for authentication testing?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              Get.dialog(
                AlertDialog(
                  title: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Creating Users...'),
                    ],
                  ),
                ),
                barrierDismissible: false,
              );

              try {
                await TestDataSeeder.instance.seedUsersOnly();
                Get.back();
                Get.snackbar(
                  'Success',
                  'Test users created successfully!',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.back();
                Get.snackbar(
                  'Error',
                  'Failed to create users: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('Create Users'),
          ),
        ],
      ),
    );
  }

  /// Clear all test data
  static Future<void> clearTestData() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear Test Data'),
          ],
        ),
        content: Text(
          'Are you sure you want to clear all test data?\n\n'
          'This will delete:\n'
          '• All test users\n'
          '• All courses\n'
          '• All fleet vehicles\n'
          '• All schedules\n\n'
          'This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Clearing Data...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      try {
        await TestDataSeeder.instance.clearAllTestData();
        Get.back();
        Get.snackbar(
          'Success',
          'All test data cleared successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.back();
        Get.snackbar(
          'Error',
          'Failed to clear data: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }
}
