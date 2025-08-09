// lib/services/student_validation_service.dart
import 'package:get/get.dart';
import '../controllers/user_controller.dart';
import '../models/user.dart';

class StudentValidationService {
  static final StudentValidationService _instance =
      StudentValidationService._internal();
  factory StudentValidationService() => _instance;
  StudentValidationService._internal();

  final UserController _userController = Get.find<UserController>();

  /// Comprehensive validation for student data
  Future<ValidationResult> validateStudentData(
      List<Map<String, dynamic>> studentsData) async {
    List<String> errors = [];
    List<String> warnings = [];
    List<Map<String, dynamic>> validStudents = [];
    List<Map<String, dynamic>> duplicateStudents = [];

    // Get existing users for duplicate checking
    await _userController.fetchUsers();
    List<User> existingUsers = _userController.users;

    for (int i = 0; i < studentsData.length; i++) {
      Map<String, dynamic> studentData = studentsData[i];
      List<String> rowErrors = [];
      List<String> rowWarnings = [];

      // Basic validation
      _validateRequiredFields(studentData, rowErrors, i + 2);
      _validateEmailFormat(studentData, rowErrors, i + 2);
      _validatePhoneNumber(studentData, rowErrors, rowWarnings, i + 2);
      _validateDateOfBirth(studentData, rowErrors, i + 2);
      _validateGender(studentData, rowErrors, i + 2);
      _validateIdNumber(studentData, rowErrors, i + 2);

      // Duplicate checking
      DuplicateCheckResult duplicateResult =
          _checkForDuplicates(studentData, existingUsers, studentsData, i);
      if (duplicateResult.isDuplicate) {
        if (duplicateResult.isExistingUser) {
          rowErrors.add(
              'Row ${i + 2}: Student already exists in system (${duplicateResult.duplicateField})');
        } else {
          rowWarnings.add(
              'Row ${i + 2}: Duplicate found in CSV (${duplicateResult.duplicateField})');
        }
      }

      // Age validation
      _validateAge(studentData, rowWarnings, i + 2);

      if (rowErrors.isEmpty) {
        if (duplicateResult.isDuplicate) {
          duplicateStudents.add({
            ...studentData,
            '_rowNumber': i + 2,
            '_duplicateReason': duplicateResult.duplicateField,
            '_isExistingUser': duplicateResult.isExistingUser,
          });
        } else {
          validStudents.add({
            ...studentData,
            '_rowNumber': i + 2,
          });
        }
      }

      errors.addAll(rowErrors);
      warnings.addAll(rowWarnings);
    }

    return ValidationResult(
      validStudents: validStudents,
      duplicateStudents: duplicateStudents,
      errors: errors,
      warnings: warnings,
      totalProcessed: studentsData.length,
    );
  }

  void _validateRequiredFields(
      Map<String, dynamic> studentData, List<String> errors, int rowNumber) {
    List<String> requiredFields = [
      'First Name',
      'Last Name',
      'Email',
      'Phone',
      'Address',
      'Date of Birth',
      'Gender',
      'ID Number'
    ];

    for (String field in requiredFields) {
      if (studentData[field]?.toString().trim().isEmpty ?? true) {
        errors.add('Row $rowNumber: Missing required field: $field');
      }
    }
  }

  void _validateEmailFormat(
      Map<String, dynamic> studentData, List<String> errors, int rowNumber) {
    String? email = studentData['Email']?.toString().trim();
    if (email?.isNotEmpty == true && !GetUtils.isEmail(email!)) {
      errors.add('Row $rowNumber: Invalid email format: $email');
    }
  }

  void _validatePhoneNumber(Map<String, dynamic> studentData,
      List<String> errors, List<String> warnings, int rowNumber) {
    String? phone = studentData['Phone']?.toString().trim();
    if (phone?.isNotEmpty == true) {
      // Remove spaces and special characters for validation
      String cleanPhone = phone!.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      // Check if it's a valid Zimbabwe number format
      if (!RegExp(r'^\+?263[0-9]{9}$').hasMatch(cleanPhone) &&
          !RegExp(r'^0[0-9]{9}$').hasMatch(cleanPhone)) {
        warnings.add(
            'Row $rowNumber: Phone number format may be incorrect. Expected: +263XXXXXXXXX or 0XXXXXXXXX');
      }

      // Check minimum length
      if (cleanPhone.length < 10) {
        errors.add('Row $rowNumber: Phone number too short: $phone');
      }
    }
  }

  void _validateDateOfBirth(
      Map<String, dynamic> studentData, List<String> errors, int rowNumber) {
    String? dobString = studentData['Date of Birth']?.toString().trim();
    if (dobString?.isNotEmpty == true) {
      try {
        DateTime dob = DateTime.parse(dobString!);
        DateTime now = DateTime.now();

        // Check if date is in the future
        if (dob.isAfter(now)) {
          errors.add('Row $rowNumber: Date of birth cannot be in the future');
        }

        // Check if date is too far in the past (more than 100 years ago)
        if (dob.isBefore(now.subtract(Duration(days: 365 * 100)))) {
          errors.add(
              'Row $rowNumber: Date of birth seems too old (more than 100 years ago)');
        }
      } catch (e) {
        errors
            .add('Row $rowNumber: Invalid date format. Use YYYY-MM-DD format');
      }
    }
  }

  void _validateAge(
      Map<String, dynamic> studentData, List<String> warnings, int rowNumber) {
    String? dobString = studentData['Date of Birth']?.toString().trim();
    if (dobString?.isNotEmpty == true) {
      try {
        DateTime dob = DateTime.parse(dobString!);
        DateTime now = DateTime.now();
        int age = now.year - dob.year;
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          age--;
        }

        // Warning for very young students
        if (age < 16) {
          warnings.add('Row $rowNumber: Student is under 16 years old');
        }

        // Warning for very old students
        if (age > 65) {
          warnings.add('Row $rowNumber: Student is over 65 years old');
        }
      } catch (e) {
        // Date parsing error already handled in main validation
      }
    }
  }

  void _validateGender(
      Map<String, dynamic> studentData, List<String> errors, int rowNumber) {
    String? gender = studentData['Gender']?.toString().trim().toLowerCase();
    if (gender?.isNotEmpty == true) {
      List<String> validGenders = ['male', 'female', 'm', 'f'];
      if (!validGenders.contains(gender)) {
        errors.add('Row $rowNumber: Invalid gender. Use Male, Female, M, or F');
      }
    }
  }

  void _validateIdNumber(
      Map<String, dynamic> studentData, List<String> errors, int rowNumber) {
    String? idNumber = studentData['ID Number']?.toString().trim();
    if (idNumber?.isNotEmpty == true) {
      // Check for valid Zimbabwe ID format (basic validation)
      if (idNumber!.length < 2) {
        errors.add('Row $rowNumber: ID Number too short');
      }

      // Check for special characters that might cause issues
      if (RegExp(r'[<>"\\/|?*]').hasMatch(idNumber)) {
        errors.add('Row $rowNumber: ID Number contains invalid characters');
      }
    }
  }

  DuplicateCheckResult _checkForDuplicates(
      Map<String, dynamic> studentData,
      List<User> existingUsers,
      List<Map<String, dynamic>> allStudentsData,
      int currentIndex) {
    String email = studentData['Email']?.toString().trim().toLowerCase() ?? '';
    String idNumber = studentData['ID Number']?.toString().trim() ?? '';
    String phone = studentData['Phone']?.toString().trim() ?? '';

    // Normalize phone for comparison
    if (phone.isNotEmpty) {
      phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (phone.startsWith('0') && phone.length == 10) {
        phone = '+263${phone.substring(1)}';
      }
    }

    // Check against existing users in database
    for (User user in existingUsers) {
      if (user.email.toLowerCase() == email && email.isNotEmpty) {
        return DuplicateCheckResult(true, true, 'Email: $email');
      }
      if (user.idnumber == idNumber && idNumber.isNotEmpty) {
        return DuplicateCheckResult(true, true, 'ID Number: $idNumber');
      }

      // Normalize existing user phone for comparison
      String existingPhone = user.phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (existingPhone.startsWith('0') && existingPhone.length == 10) {
        existingPhone = '+263${existingPhone.substring(1)}';
      }

      if (existingPhone == phone && phone.isNotEmpty) {
        return DuplicateCheckResult(true, true, 'Phone: $phone');
      }
    }

    // Check against other rows in the same CSV
    for (int i = 0; i < allStudentsData.length; i++) {
      if (i == currentIndex) continue; // Skip current row

      Map<String, dynamic> otherStudent = allStudentsData[i];
      String otherEmail =
          otherStudent['Email']?.toString().trim().toLowerCase() ?? '';
      String otherIdNumber = otherStudent['ID Number']?.toString().trim() ?? '';
      String otherPhone = otherStudent['Phone']?.toString().trim() ?? '';

      // Normalize other phone for comparison
      if (otherPhone.isNotEmpty) {
        otherPhone = otherPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        if (otherPhone.startsWith('0') && otherPhone.length == 10) {
          otherPhone = '+263${otherPhone.substring(1)}';
        }
      }

      if (email.isNotEmpty && email == otherEmail) {
        return DuplicateCheckResult(
            true, false, 'Email: $email (Row ${i + 2})');
      }
      if (idNumber.isNotEmpty && idNumber == otherIdNumber) {
        return DuplicateCheckResult(
            true, false, 'ID Number: $idNumber (Row ${i + 2})');
      }
      if (phone.isNotEmpty && phone == otherPhone) {
        return DuplicateCheckResult(
            true, false, 'Phone: $phone (Row ${i + 2})');
      }
    }

    return DuplicateCheckResult(false, false, '');
  }

  /// Normalize student data before saving
  Map<String, dynamic> normalizeStudentData(Map<String, dynamic> studentData) {
    Map<String, dynamic> normalized = Map.from(studentData);

    // Normalize gender
    String gender = normalized['Gender']?.toString().trim().toLowerCase() ?? '';
    if (gender == 'm' || gender == 'male') {
      normalized['Gender'] = 'Male';
    } else if (gender == 'f' || gender == 'female') {
      normalized['Gender'] = 'Female';
    }

    // Normalize phone number
    String phone = normalized['Phone']?.toString().trim() ?? '';
    if (phone.isNotEmpty) {
      // Remove spaces and special characters
      phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      // Convert local format to international
      if (phone.startsWith('0') && phone.length == 10) {
        phone = '+263${phone.substring(1)}';
      }
      normalized['Phone'] = phone;
    }

    // Normalize email
    normalized['Email'] =
        normalized['Email']?.toString().trim().toLowerCase() ?? '';

    // Trim all string fields
    normalized.forEach((key, value) {
      if (value is String) {
        normalized[key] = value.trim();
      }
    });

    // Set default values
    normalized['Role'] = 'student';
    normalized['Status'] =
        normalized['Status']?.toString().trim().toLowerCase() ?? 'active';
    normalized['Password'] =
        normalized['Password']?.toString().trim().isNotEmpty == true
            ? normalized['Password']
            : 'defaultPass123';

    return normalized;
  }
}

class ValidationResult {
  final List<Map<String, dynamic>> validStudents;
  final List<Map<String, dynamic>> duplicateStudents;
  final List<String> errors;
  final List<String> warnings;
  final int totalProcessed;

  ValidationResult({
    required this.validStudents,
    required this.duplicateStudents,
    required this.errors,
    required this.warnings,
    required this.totalProcessed,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasDuplicates => duplicateStudents.isNotEmpty;
  int get validCount => validStudents.length;
  int get errorCount =>
      totalProcessed - validStudents.length - duplicateStudents.length;
  int get duplicateCount => duplicateStudents.length;
}

class DuplicateCheckResult {
  final bool isDuplicate;
  final bool isExistingUser;
  final String duplicateField;

  DuplicateCheckResult(
      this.isDuplicate, this.isExistingUser, this.duplicateField);
}
