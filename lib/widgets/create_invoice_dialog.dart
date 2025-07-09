import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/billing_controller.dart';
import '../controllers/course_controller.dart';
import '../controllers/user_controller.dart';
import '../models/course.dart';
import '../models/user.dart';

class CreateInvoiceDialog extends StatefulWidget {
  const CreateInvoiceDialog({Key? key}) : super(key: key);

  @override
  State<CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends State<CreateInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedStudentId;
  int? _selectedCourseId;
  int _numberOfLessons = 1;
  double _pricePerLesson = 0;
  bool _isLoading = true;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    try {
      final userController = Get.find<UserController>();
      final courseController = Get.find<CourseController>();

      await userController.fetchUsers();
      await courseController.fetchCourses();

      if (userController.users.isEmpty || courseController.courses.isEmpty) {
        throw Exception('Required data not available');
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _pricePerLesson = courseController.courses
            .firstWhere((course) => course.status.toLowerCase() == 'active')
            .price
            .toDouble();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load required data: ${e.toString()}';
      });
    }
  }

  Widget _buildStudentAutocomplete() {
    final userController = Get.find<UserController>();
    final students = userController.users
        .where((u) =>
            u.role.toLowerCase() == 'student' &&
            u.status.toLowerCase() == 'active')
        .toList();

    return Autocomplete<User>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return students;
        }
        return students.where((student) => "${student.fname} ${student.lname}"
            .toLowerCase()
            .contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (User student) =>
          "${student.fname} ${student.lname}",
      fieldViewBuilder: (BuildContext context,
          TextEditingController fieldTextEditingController,
          FocusNode fieldFocusNode,
          VoidCallback onFieldSubmitted) {
        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            labelText: 'Student',
            hintText: 'Search student',
            prefixIcon: const Icon(Icons.person, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
          validator: (value) {
            if (_selectedStudentId == null) {
              return 'Please select a student';
            }
            return null;
          },
        );
      },
      onSelected: (User student) {
        setState(() {
          _selectedStudentId = student.id;
        });
      },
    );
  }

  Widget _buildCourseAutocomplete() {
    final courseController = Get.find<CourseController>();
    final courses = courseController.courses
        .where((course) => course.status.toLowerCase() == 'active')
        .toList();

    return Autocomplete<Course>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return courses;
        }
        return courses.where((course) => course.name
            .toLowerCase()
            .contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (Course course) => course.name,
      fieldViewBuilder: (BuildContext context,
          TextEditingController fieldTextEditingController,
          FocusNode fieldFocusNode,
          VoidCallback onFieldSubmitted) {
        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            labelText: 'Course',
            hintText: 'Search course',
            prefixIcon: const Icon(Icons.school, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
          validator: (value) {
            if (_selectedCourseId == null) {
              return 'Please select a course';
            }
            return null;
          },
        );
      },
      onSelected: (Course course) {
        setState(() {
          _selectedCourseId = course.id;
          _pricePerLesson = course.price.toDouble();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(_errorMessage!),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text(
        'Create New Invoice',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStudentAutocomplete(),
                    const SizedBox(height: 16),
                    _buildCourseAutocomplete(),
                    const SizedBox(height: 16),
                    TextFormField(
                      keyboardType: TextInputType.number,
                      initialValue: '1',
                      decoration: InputDecoration(
                        labelText: 'Number of Lessons',
                        hintText: 'Enter number of lessons',
                        prefixIcon: const Icon(Icons.format_list_numbered,
                            color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final lessons = int.tryParse(value);
                        if (lessons == null || lessons < 1)
                          return 'Invalid number';
                        return null;
                      },
                      onChanged: (value) => setState(
                        () => _numberOfLessons = int.tryParse(value) ?? 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price per Lesson: \$${_pricePerLesson.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total Amount: \$${(_pricePerLesson * _numberOfLessons).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _isCreating
              ? null
              : () async {
                  if (_formKey.currentState!.validate() &&
                      _selectedStudentId != null &&
                      _selectedCourseId != null) {
                    _showConfirmationDialog(); // Show confirmation dialog
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Create Invoice'),
        ),
      ],
    );
  }

  // Confirmation dialog
  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Invoice Creation'),
          content: const Text('Are you sure you want to create this invoice?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _createInvoice(); // Proceed with invoice creation
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  // Invoice creation logic
  Future<void> _createInvoice() async {
    setState(() => _isCreating = true);
    await Get.find<BillingController>().generateInvoice(
      studentId: _selectedStudentId!,
      courseId: _selectedCourseId!,
      lessons: _numberOfLessons,
      pricePerLesson: _pricePerLesson,
    );
    setState(() => _isCreating = false);
    Get.back();
  }
}
