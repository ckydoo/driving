// lib/screens/users/bulk_student_upload_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/user_controller.dart';
import '../../models/user.dart';

class BulkStudentUploadScreen extends StatefulWidget {
  const BulkStudentUploadScreen({Key? key}) : super(key: key);

  @override
  _BulkStudentUploadScreenState createState() =>
      _BulkStudentUploadScreenState();
}

class _BulkStudentUploadScreenState extends State<BulkStudentUploadScreen>
    with SingleTickerProviderStateMixin {
  final UserController _userController = Get.find<UserController>();

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // File processing state
  String? _selectedFileName;
  List<List<dynamic>> _csvData = [];
  List<Map<String, dynamic>> _previewData = [];
  List<String> _csvHeaders = [];
  Map<String, String> _fieldMapping = {};
  List<String> _validationErrors = [];
  List<Map<String, dynamic>> _validStudents = [];

  // UI state
  bool _isFileSelected = false;
  bool _isMappingComplete = false;
  bool _isValidating = false;
  bool _isUploading = false;
  bool _showPreview = false;
  int _currentStep = 0;

  // Upload results
  int _successCount = 0;
  int _errorCount = 0;
  List<String> _uploadErrors = [];

  // Required fields for student creation
  final List<String> _requiredFields = [
    'First Name',
    'Last Name',
    'Email',
    'Phone',
    'Address',
    'Date of Birth',
    'Gender',
    'ID Number'
  ];

  // Optional fields
  final Map<String, String> _optionalFields = {
    'Status': 'active',
    'Password': 'defaultPass123',
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeFieldMapping();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  void _initializeFieldMapping() {
    _fieldMapping = {
      'First Name': '',
      'Last Name': '',
      'Email': '',
      'Phone': '',
      'Address': '',
      'Date of Birth': '',
      'Gender': '',
      'ID Number': '',
      'Status': '',
      'Password': '',
    };
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Step 1: File Selection
  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _isFileSelected = true;
          _currentStep = 1;
        });
        await _processCsvFile(result.files.single.bytes!);
      }
    } catch (e) {
      _showErrorSnackbar('Error selecting file: ${e.toString()}');
    }
  }

  Future<void> _processCsvFile(List<int> bytes) async {
    try {
      String csvString = utf8.decode(bytes);
      List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString);

      if (csvTable.isEmpty) {
        _showErrorSnackbar('CSV file is empty');
        return;
      }

      setState(() {
        _csvData = csvTable;
        _csvHeaders =
            csvTable.first.map((header) => header.toString().trim()).toList();
        _previewData = csvTable.skip(1).take(5).map((row) {
          Map<String, dynamic> rowMap = {};
          for (int i = 0; i < _csvHeaders.length && i < row.length; i++) {
            rowMap[_csvHeaders[i]] = row[i]?.toString() ?? '';
          }
          return rowMap;
        }).toList();
      });

      _autoMapFields();
    } catch (e) {
      _showErrorSnackbar('Error processing CSV: ${e.toString()}');
    }
  }

  void _autoMapFields() {
    // Auto-map common field variations
    final Map<String, List<String>> commonMappings = {
      'First Name': ['firstname', 'first_name', 'fname', 'given_name'],
      'Last Name': ['lastname', 'last_name', 'lname', 'surname', 'family_name'],
      'Email': ['email', 'email_address', 'mail'],
      'Phone': ['phone', 'phone_number', 'mobile', 'cell', 'telephone'],
      'Address': ['address', 'street_address', 'location'],
      'Date of Birth': ['date_of_birth', 'dob', 'birth_date', 'birthdate'],
      'Gender': ['gender', 'sex'],
      'ID Number': [
        'id_number',
        'idnumber',
        'id',
        'student_id',
        'identification'
      ],
      'Status': ['status', 'account_status'],
      'Password': ['password', 'pwd'],
    };

    for (String requiredField in _fieldMapping.keys) {
      String? matchedHeader = _csvHeaders.firstWhereOrNull((header) {
        String normalizedHeader = header.toLowerCase().replaceAll(' ', '_');
        List<String> variations = commonMappings[requiredField] ?? [];
        return variations.contains(normalizedHeader) ||
            header.toLowerCase() == requiredField.toLowerCase();
      });

      if (matchedHeader != null) {
        _fieldMapping[requiredField] = matchedHeader;
      }
    }
  }

  // Step 2: Field Mapping
  Widget _buildFieldMappingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Map CSV columns to student fields',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: _requiredFields
                  .map((field) => _buildFieldMappingRow(field, true))
                  .toList()
                ..addAll(_optionalFields.keys
                    .map((field) => _buildFieldMappingRow(field, false))),
            ),
          ),
        ),
        SizedBox(height: 16),
        if (_previewData.isNotEmpty) _buildPreviewSection(),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed:
                    _canProceedToValidation() ? _proceedToValidation : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Validate Data'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFieldMappingRow(String field, bool isRequired) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              field + (isRequired ? ' *' : ''),
              style: TextStyle(
                fontWeight: isRequired ? FontWeight.bold : FontWeight.normal,
                color: isRequired ? Colors.black : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: _fieldMapping[field]?.isEmpty == true
                  ? null
                  : _fieldMapping[field],
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: isRequired ? 'Select column' : 'Optional',
              ),
              items: [
                DropdownMenuItem<String>(
                  value: '',
                  child: Text('-- Not mapped --',
                      style: TextStyle(color: Colors.grey)),
                ),
                ..._csvHeaders.map((header) => DropdownMenuItem<String>(
                      value: header,
                      child: Text(header),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _fieldMapping[field] = value ?? '';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Preview (First 5 rows)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: _csvHeaders
                    .map((header) => DataColumn(
                          label: Text(header,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ))
                    .toList(),
                rows: _previewData
                    .map((row) => DataRow(
                          cells: _csvHeaders
                              .map((header) => DataCell(
                                    Text(row[header]?.toString() ?? ''),
                                  ))
                              .toList(),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceedToValidation() {
    return _requiredFields
        .every((field) => _fieldMapping[field]?.isNotEmpty == true);
  }

  // Step 3: Data Validation
  Future<void> _proceedToValidation() async {
    setState(() {
      _currentStep = 2;
      _isValidating = true;
      _validationErrors.clear();
      _validStudents.clear();
    });

    await _validateData();

    setState(() {
      _isValidating = false;
      _isMappingComplete = true;
    });
  }

  Future<void> _validateData() async {
    List<Map<String, dynamic>> validStudents = [];
    List<String> errors = [];

    // Skip header row
    for (int i = 1; i < _csvData.length; i++) {
      List<dynamic> row = _csvData[i];
      Map<String, dynamic> studentData = {};
      List<String> rowErrors = [];

      // Map fields
      for (String field in _fieldMapping.keys) {
        String csvColumn = _fieldMapping[field] ?? '';
        if (csvColumn.isNotEmpty) {
          int columnIndex = _csvHeaders.indexOf(csvColumn);
          if (columnIndex >= 0 && columnIndex < row.length) {
            studentData[field] = row[columnIndex]?.toString()?.trim() ?? '';
          }
        }
      }

      // Add default values for optional fields
      _optionalFields.forEach((field, defaultValue) {
        if (studentData[field]?.isEmpty ?? true) {
          studentData[field] = defaultValue;
        }
      });

      // Validate required fields
      for (String field in _requiredFields) {
        if (studentData[field]?.isEmpty ?? true) {
          rowErrors.add('Row ${i + 1}: Missing $field');
        }
      }

      // Validate email format
      if (studentData['Email']?.isNotEmpty == true) {
        if (!GetUtils.isEmail(studentData['Email'])) {
          rowErrors.add('Row ${i + 1}: Invalid email format');
        }
      }

      // Validate date of birth
      if (studentData['Date of Birth']?.isNotEmpty == true) {
        try {
          DateTime.parse(studentData['Date of Birth']);
        } catch (e) {
          rowErrors.add('Row ${i + 1}: Invalid date format (use YYYY-MM-DD)');
        }
      }

      // Validate gender
      if (studentData['Gender']?.isNotEmpty == true) {
        String gender = studentData['Gender'].toLowerCase();
        if (!['male', 'female', 'm', 'f'].contains(gender)) {
          rowErrors
              .add('Row ${i + 1}: Invalid gender (use Male/Female or M/F)');
        }
      }

      if (rowErrors.isEmpty) {
        // Normalize data
        studentData['Gender'] = _normalizeGender(studentData['Gender']);
        studentData['Role'] = 'student';
        validStudents.add(studentData);
      } else {
        errors.addAll(rowErrors);
      }
    }

    setState(() {
      _validStudents = validStudents;
      _validationErrors = errors;
    });
  }

  String _normalizeGender(String gender) {
    String normalized = gender.toLowerCase();
    if (normalized == 'm' || normalized == 'male') return 'Male';
    if (normalized == 'f' || normalized == 'female') return 'Female';
    return gender;
  }

  Widget _buildValidationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Validation Results',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),

        // Summary cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Valid Records',
                _validStudents.length.toString(),
                Colors.green,
                Icons.check_circle,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Errors',
                _validationErrors.length.toString(),
                Colors.red,
                Icons.error,
              ),
            ),
          ],
        ),

        SizedBox(height: 16),

        // Error list
        if (_validationErrors.isNotEmpty) ...[
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Validation Errors',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...(_validationErrors.take(10).map((error) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $error',
                            style: TextStyle(color: Colors.red.shade600)),
                      ))),
                  if (_validationErrors.length > 10)
                    Text(
                        '... and ${_validationErrors.length - 10} more errors'),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
        ],

        // Valid students preview
        if (_validStudents.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Valid Students Preview',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Gender')),
                      ],
                      rows: _validStudents
                          .take(5)
                          .map((student) => DataRow(
                                cells: [
                                  DataCell(Text(
                                      '${student['First Name']} ${student['Last Name']}')),
                                  DataCell(Text(student['Email'] ?? '')),
                                  DataCell(Text(student['Phone'] ?? '')),
                                  DataCell(Text(student['Gender'] ?? '')),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
                  if (_validStudents.length > 5)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                          '... and ${_validStudents.length - 5} more students'),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
        ],

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: Text('Back to Mapping'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _validStudents.isNotEmpty ? _uploadStudents : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text('Upload Students'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  // Step 4: Upload
  Future<void> _uploadStudents() async {
    setState(() {
      _isUploading = true;
      _currentStep = 3;
      _successCount = 0;
      _errorCount = 0;
      _uploadErrors.clear();
    });

    for (int i = 0; i < _validStudents.length; i++) {
      try {
        Map<String, dynamic> studentData = _validStudents[i];

        User newStudent = User(
          fname: studentData['First Name'],
          lname: studentData['Last Name'],
          email: studentData['Email'],
          password: studentData['Password'],
          gender: studentData['Gender'],
          phone: studentData['Phone'],
          address: studentData['Address'],
          date_of_birth: DateTime.parse(studentData['Date of Birth']),
          role: 'student',
          status: studentData['Status'],
          idnumber: studentData['ID Number'],
          created_at: DateTime.now(),
        );

        await _userController.handleUser(newStudent);
        _successCount++;
      } catch (e) {
        _errorCount++;
        _uploadErrors.add('Row ${i + 2}: ${e.toString()}');
      }

      // Update progress
      setState(() {});
    }

    setState(() {
      _isUploading = false;
    });

    _showCompletionDialog();
  }

  Widget _buildUploadStep() {
    if (_isUploading) {
      double progress = (_successCount + _errorCount) / _validStudents.length;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: progress),
          SizedBox(height: 16),
          Text(
              'Uploading students... ${_successCount + _errorCount}/${_validStudents.length}'),
          SizedBox(height: 8),
          Text('Success: $_successCount, Errors: $_errorCount'),
        ],
      );
    }

    return Column(
      children: [
        Icon(Icons.cloud_upload, size: 64, color: Colors.green),
        SizedBox(height: 16),
        Text(
          'Upload Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text('Successfully uploaded $_successCount students'),
        if (_errorCount > 0) Text('$_errorCount errors occurred'),
      ],
    );
  }

  void _showCompletionDialog() {
    Get.defaultDialog(
      title: 'Upload Complete',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 48),
          SizedBox(height: 16),
          Text('Successfully uploaded $_successCount students'),
          if (_errorCount > 0) Text('$_errorCount errors occurred'),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () {
          Get.back(); // Close dialog
          Get.back(); // Return to users screen
        },
        child: Text('Done'),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk Student Upload'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Progress indicator
                  _buildProgressIndicator(),
                  SizedBox(height: 24),

                  // Step content
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildCurrentStep(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            _buildStepIndicator(0, 'Select File', Icons.file_upload),
            _buildStepConnector(),
            _buildStepIndicator(1, 'Map Fields', Icons.link),
            _buildStepConnector(),
            _buildStepIndicator(2, 'Validate', Icons.check),
            _buildStepConnector(),
            _buildStepIndicator(3, 'Upload', Icons.cloud_upload),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    bool isActive = _currentStep == step;
    bool isCompleted = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green
                  : isActive
                      ? Colors.blue
                      : Colors.grey.shade300,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.blue : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return Container(
      height: 2,
      width: 20,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildFileSelectionStep();
      case 1:
        return _buildFieldMappingStep();
      case 2:
        return _buildValidationStep();
      case 3:
        return _buildUploadStep();
      default:
        return _buildFileSelectionStep();
    }
  }

  Widget _buildFileSelectionStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
                onPressed: _selectFile,
                icon: Icon(Icons.file_upload),
                label: Text('Select CSV File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              if (_selectedFileName != null) ...[
                SizedBox(height: 16),
                Text('Selected: $_selectedFileName'),
              ],
            ],
          ),
        ),
        SizedBox(height: 32),
        _buildHelpSection(),
      ],
    );
  }

  Widget _buildHelpSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CSV Format Requirements',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Your CSV file should include the following columns:'),
            SizedBox(height: 8),
            ..._requiredFields.map(
                (field) => Text('• $field', style: TextStyle(fontSize: 12))),
            SizedBox(height: 16),
            Text(
              'Example CSV Format:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'First Name,Last Name,Email,Phone,Address,Date of Birth,Gender,ID Number\n'
                'John,Doe,john@example.com,1234567890,123 Main St,1995-01-15,Male,ID001',
                style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
