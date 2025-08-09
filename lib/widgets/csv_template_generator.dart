// lib/widgets/csv_template_generator.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/screens/users/bulk_student_upload_screen.dart';

class CsvTemplateGenerator {
  static Future<void> downloadStudentTemplate() async {
    try {
      // Define the CSV headers and sample data
      List<List<String>> csvData = [
        // Headers
        [
          'First Name',
          'Last Name',
          'Email',
          'Phone',
          'Address',
          'Date of Birth',
          'Gender',
          'ID Number',
          'Status',
          'Password'
        ],
        // Sample data rows
        [
          'John',
          'Doe',
          'john.doe@example.com',
          '+263771234567',
          '123 Main Street, Harare',
          '1995-01-15',
          'Male',
          'STU001',
          'active',
          'defaultPass123'
        ],
        [
          'Jane',
          'Smith',
          'jane.smith@example.com',
          '+263772345678',
          '456 Oak Avenue, Bulawayo',
          '1998-03-22',
          'Female',
          'STU002',
          'active',
          'defaultPass123'
        ],
        [
          'Michael',
          'Johnson',
          'michael.johnson@example.com',
          '+263773456789',
          '789 Pine Road, Mutare',
          '1996-07-08',
          'Male',
          'STU003',
          'active',
          'defaultPass123'
        ]
      ];

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Get the downloads directory or let user choose location
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // Create the file
        final file = File('$selectedDirectory/student_template.csv');
        await file.writeAsString(csvString);

        Get.snackbar(
          'Success',
          'Template downloaded to: ${file.path}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          'Cancelled',
          'Template download cancelled',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to download template: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  static Widget buildTemplateDownloadButton() {
    return OutlinedButton.icon(
      onPressed: downloadStudentTemplate,
      icon: Icon(Icons.download, size: 16),
      label: Text('Download Template'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: BorderSide(color: Colors.blue),
      ),
    );
  }

  static Widget buildTemplateInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Need a template?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Download our CSV template with sample data to get started quickly.',
              style: TextStyle(color: Colors.blue.shade600),
            ),
            SizedBox(height: 12),
            buildTemplateDownloadButton(),
          ],
        ),
      ),
    );
  }
}

// Extension method to add template download to the bulk upload screen
extension BulkStudentUploadTemplateExtension on BulkStudentUploadScreen {
  Widget buildFileSelectionWithTemplate() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Template download card
        CsvTemplateGenerator.buildTemplateInfoCard(),
        SizedBox(height: 24),

        // Original file selection content
        Container(
          padding: EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload,
                size: 64,
                color: Colors.blue,
              ),
              SizedBox(height: 24),
              Text(
                'Upload Student Data',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Select a CSV file containing student information',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed:
                    () {}, // This would be connected to your _selectFile method
                icon: Icon(Icons.file_upload),
                label: Text('Select CSV File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
