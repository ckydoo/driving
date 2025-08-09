// lib/services/student_import_service.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/user_controller.dart';
import '../models/user.dart';
import 'student_validation_service.dart';

class StudentImportService {
  static final StudentImportService _instance =
      StudentImportService._internal();
  factory StudentImportService() => _instance;
  StudentImportService._internal();

  final UserController _userController = Get.find<UserController>();
  final StudentValidationService _validationService =
      StudentValidationService();

  /// Import students with progress tracking and detailed error reporting
  Future<ImportResult> importStudents(
    List<Map<String, dynamic>> studentsData, {
    Function(ImportProgress)? onProgress,
    bool skipDuplicates = true,
  }) async {
    ImportResult result = ImportResult();

    try {
      // Step 1: Validate all data
      onProgress?.call(ImportProgress(
        currentStep: 'Validating data...',
        currentIndex: 0,
        totalItems: studentsData.length,
        successCount: 0,
        errorCount: 0,
      ));

      ValidationResult validationResult =
          await _validationService.validateStudentData(studentsData);

      if (validationResult.hasErrors && validationResult.validCount == 0) {
        result.success = false;
        result.errors.addAll(validationResult.errors);
        result.warnings.addAll(validationResult.warnings);
        return result;
      }

      // Step 2: Process valid students
      List<Map<String, dynamic>> studentsToProcess =
          validationResult.validStudents;

      if (!skipDuplicates) {
        studentsToProcess.addAll(validationResult.duplicateStudents);
      }

      result.totalProcessed = studentsToProcess.length;
      result.duplicatesSkipped = validationResult.duplicateCount;
      result.warnings.addAll(validationResult.warnings);

      // Step 3: Create users one by one
      for (int i = 0; i < studentsToProcess.length; i++) {
        Map<String, dynamic> studentData = studentsToProcess[i];

        onProgress?.call(ImportProgress(
          currentStep:
              'Creating student ${i + 1} of ${studentsToProcess.length}...',
          currentIndex: i + 1,
          totalItems: studentsToProcess.length,
          successCount: result.successCount,
          errorCount: result.errorCount,
          currentStudentName:
              '${studentData['First Name']} ${studentData['Last Name']}',
        ));

        try {
          // Normalize data
          Map<String, dynamic> normalizedData =
              _validationService.normalizeStudentData(studentData);

          // Create User object
          User newStudent = User(
            fname: normalizedData['First Name'],
            lname: normalizedData['Last Name'],
            email: normalizedData['Email'],
            password: normalizedData['Password'],
            gender: normalizedData['Gender'],
            phone: normalizedData['Phone'],
            address: normalizedData['Address'],
            date_of_birth: DateTime.parse(normalizedData['Date of Birth']),
            role: 'student',
            status: normalizedData['Status'],
            idnumber: normalizedData['ID Number'],
            created_at: DateTime.now(),
          );

          // Create user in database
          await _userController.handleUser(newStudent);

          result.successCount++;
          result.createdStudents.add({
            'name': '${newStudent.fname} ${newStudent.lname}',
            'email': newStudent.email,
            'rowNumber': normalizedData['_rowNumber'],
          });
        } catch (e) {
          result.errorCount++;
          String errorMessage =
              'Row ${studentData['_rowNumber']}: ${e.toString()}';
          result.errors.add(errorMessage);
          result.failedStudents.add({
            'name': '${studentData['First Name']} ${studentData['Last Name']}',
            'email': studentData['Email'],
            'error': e.toString(),
            'rowNumber': studentData['_rowNumber'],
          });
        }

        // Small delay to prevent overwhelming the database
        await Future.delayed(Duration(milliseconds: 50));
      }

      // Step 4: Final validation and cleanup
      result.success = result.successCount > 0;

      // Refresh user list
      await _userController.fetchUsers();
    } catch (e) {
      result.success = false;
      result.errors.add('Import process failed: ${e.toString()}');
    }

    return result;
  }

  /// Generate a detailed import report
  String generateImportReport(ImportResult result) {
    StringBuffer report = StringBuffer();

    report.writeln('=== STUDENT IMPORT REPORT ===');
    report.writeln('Import Date: ${DateTime.now().toString()}');
    report.writeln('');

    // Summary
    report.writeln('SUMMARY:');
    report.writeln('Total Processed: ${result.totalProcessed}');
    report.writeln('Successfully Created: ${result.successCount}');
    report.writeln('Errors: ${result.errorCount}');
    report.writeln('Duplicates Skipped: ${result.duplicatesSkipped}');
    report.writeln('Warnings: ${result.warnings.length}');
    report.writeln('');

    // Successful imports
    if (result.createdStudents.isNotEmpty) {
      report.writeln('SUCCESSFULLY CREATED STUDENTS:');
      for (var student in result.createdStudents) {
        report.writeln(
            '✓ ${student['name']} (${student['email']}) - Row ${student['rowNumber']}');
      }
      report.writeln('');
    }

    // Failed imports
    if (result.failedStudents.isNotEmpty) {
      report.writeln('FAILED IMPORTS:');
      for (var student in result.failedStudents) {
        report.writeln(
            '✗ ${student['name']} (${student['email']}) - Row ${student['rowNumber']}');
        report.writeln('  Error: ${student['error']}');
      }
      report.writeln('');
    }

    // Errors
    if (result.errors.isNotEmpty) {
      report.writeln('ERRORS:');
      for (String error in result.errors) {
        report.writeln('• $error');
      }
      report.writeln('');
    }

    // Warnings
    if (result.warnings.isNotEmpty) {
      report.writeln('WARNINGS:');
      for (String warning in result.warnings) {
        report.writeln('• $warning');
      }
      report.writeln('');
    }

    return report.toString();
  }
}

class ImportResult {
  bool success = false;
  int totalProcessed = 0;
  int successCount = 0;
  int errorCount = 0;
  int duplicatesSkipped = 0;
  List<String> errors = [];
  List<String> warnings = [];
  List<Map<String, dynamic>> createdStudents = [];
  List<Map<String, dynamic>> failedStudents = [];

  double get successRate =>
      totalProcessed > 0 ? successCount / totalProcessed : 0.0;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

class ImportProgress {
  final String currentStep;
  final int currentIndex;
  final int totalItems;
  final int successCount;
  final int errorCount;
  final String? currentStudentName;

  ImportProgress({
    required this.currentStep,
    required this.currentIndex,
    required this.totalItems,
    required this.successCount,
    required this.errorCount,
    this.currentStudentName,
  });

  double get progress => totalItems > 0 ? currentIndex / totalItems : 0.0;
  String get progressText => '$currentIndex / $totalItems';
}
