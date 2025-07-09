import 'package:driving/models/course.dart';
import 'package:driving/screens/course/courses_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/course_controller.dart';
import '../../widgets/course_form_dialog.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class CourseScreen extends StatefulWidget {
  const CourseScreen({Key? key}) : super(key: key);

  @override
  _CourseScreenState createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final CourseController controller = Get.find<CourseController>();
  final TextEditingController _searchController = TextEditingController();
  List<Course> _searchResults = [];
  List<int> _selectedCourses = [];
  bool _isMultiSelectionActive = false;
  bool _isAllSelected = false;

  // Pagination variables
  int _currentPage = 1;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    await controller.fetchCourses();
  }

  void _searchCourses(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    final results = controller.courses
        .where((course) =>
            course.name.toLowerCase().contains(query.toLowerCase()) ||
            course.status.toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      _searchResults = results;
    });
  }

  void _toggleCourseSelection(int courseId) {
    setState(() {
      if (_selectedCourses.contains(courseId)) {
        _selectedCourses.remove(courseId);
      } else {
        _selectedCourses.add(courseId);
      }
      _isMultiSelectionActive = _selectedCourses.isNotEmpty;
      _isAllSelected = controller.courses.isNotEmpty &&
          _selectedCourses.length == controller.courses.length;
    });
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _isAllSelected = value;
      _selectedCourses = value && controller.courses.isNotEmpty
          ? controller.courses.map((course) => course.id!).toList()
          : [];
      _isMultiSelectionActive = _selectedCourses.isNotEmpty;
    });
  }

  List<Course> _getPaginatedCourses() {
    final courses =
        _searchResults.isNotEmpty ? _searchResults : controller.courses;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= courses.length) {
      return [];
    }
    return courses.sublist(
        startIndex, endIndex > courses.length ? courses.length : endIndex);
  }

  int _getTotalPages() {
    final courses =
        _searchResults.isNotEmpty ? _searchResults : controller.courses;
    return (courses.length / _rowsPerPage).ceil();
  }

  void _goToPreviousPage() {
    setState(() {
      if (_currentPage > 1) {
        _currentPage--;
      }
    });
  }

  void _goToNextPage() {
    setState(() {
      if (_currentPage < _getTotalPages()) {
        _currentPage++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = _getPaginatedCourses();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Course Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadCourses();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () {
              _showExportDialog();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search courses...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade600),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onChanged: _searchCourses,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // If no courses are available and no search query is active
        if (controller.courses.isEmpty && _searchController.text.isEmpty) {
          return const Center(child: Text('No courses found'));
        }

        // Otherwise, build the course list
        return _buildCourseList(controller.courses);
      }),
      floatingActionButton: _isMultiSelectionActive
          ? FloatingActionButton.extended(
              onPressed: () {
                _showMultiDeleteConfirmationDialog();
              },
              label: Row(
                children: [
                  Icon(Icons.delete_sweep, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Delete Selected',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
              backgroundColor: Colors.redAccent,
            )
          : FloatingActionButton(
              child: const Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.blue.shade800,
              onPressed: () => Get.dialog(const CourseFormDialog()),
            ),
    );
  }

  Widget _buildCourseList(List<Course> courses) {
    // Check if a search query is active and no results were found
    if (_searchController.text.isNotEmpty && _searchResults.isEmpty) {
      return const Center(child: Text('No matching courses found'));
    }

    // If no courses are available (e.g., no data or no search results)
    if (controller.courses.isEmpty) {
      return const Center(child: Text('No courses found'));
    }

    // Otherwise, display the list of courses
    return Column(
      children: [
        _buildHeaderRow(),
        Expanded(
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.all(16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              itemCount: controller.courses.length,
              itemBuilder: (context, index) {
                final course = controller.courses[index];
                return _buildDataRow(course, index);
              },
            ),
          ),
        ),
        _buildPagination(),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Checkbox(
            value: _isAllSelected,
            onChanged: (bool? value) {
              _toggleSelectAll(value!);
            },
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Course Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Price',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(Course course, int index) {
    return Container(
      color: index % 2 == 0 ? Colors.grey.shade100 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CourseDetailsScreen(courseId: course.id!),
              ),
            );
          },
          child: Row(
            children: [
              Checkbox(
                value: _selectedCourses.contains(course.id),
                onChanged: (bool? value) {
                  _toggleCourseSelection(course.id!);
                },
              ),
              Expanded(flex: 2, child: Text(course.name)),
              Expanded(flex: 2, child: Text('\$${course.price}')),
              Expanded(flex: 2, child: Text(course.status)),
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => Get.dialog(
                        CourseFormDialog(course: course),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteConfirmationDialog(course.id!);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.only(
          left: 16.0, right: 200.0, top: 40.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
            onPressed: () {
              _goToPreviousPage();
            },
          ),
          Text(
            'Page $_currentPage of ${_getTotalPages()}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
            onPressed: () {
              _goToNextPage();
            },
          ),
          DropdownButton<int>(
            value: _rowsPerPage,
            items: [10, 25, 50, 100].map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text(
                  '$value rows',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              );
            }).toList(),
            onChanged: (int? value) {
              setState(() {
                _rowsPerPage = value!;
                _currentPage = 1;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(int id) {
    Get.defaultDialog(
      title: 'Confirm Delete',
      content: const Text('Are you sure you want to delete this course?'),
      confirm: TextButton(
        onPressed: () {
          controller.deleteCourse(id);
          _loadCourses();
          Get.back();
        },
        child: const Text('Delete'),
      ),
      cancel: TextButton(
        onPressed: () {
          Get.back();
        },
        child: const Text('Cancel'),
      ),
    );
  }

  void _showMultiDeleteConfirmationDialog() {
    Get.defaultDialog(
      title: 'Confirm Multi-Delete',
      content: Text(
          'Are you sure you want to delete the selected ${_selectedCourses.length} courses?'),
      confirm: TextButton(
        onPressed: () {
          _selectedCourses.forEach((id) {
            controller.deleteCourse(id);
          });
          _toggleSelectAll(false);
          _loadCourses();
          Get.back();
        },
        child: const Text('Delete All'),
      ),
      cancel: TextButton(
        onPressed: () {
          Get.back();
        },
        child: const Text('Cancel'),
      ),
    );
  }

  void _showExportDialog() {
    Get.defaultDialog(
      title: 'Export Courses',
      content: const Text('Export the current list of courses to a CSV file.'),
      confirm: TextButton(
        onPressed: () async {
          // Convert course data to CSV
          final csvData = const ListToCsvConverter().convert(
            [
              ['Course Name', 'Price', 'Status'], // Header row
              ...controller.courses.map((course) => [
                    course.name,
                    '\$${course.price}',
                    course.status,
                  ]),
            ],
          );
          // Sanitize file name
          final timestamp = DateTime.now()
              .toIso8601String()
              .replaceAll(RegExp(r'[:\.]'), '_');
          final fileName = 'courses_export_$timestamp.csv';
          // Save CSV file
          final String? filePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save CSV File',
            fileName: fileName,
            allowedExtensions: ['csv'],
          );
          if (filePath != null) {
            final file = File(filePath);
            await file.writeAsString(csvData);
            // Show success dialog
            Get.defaultDialog(
              title: 'Export Successful',
              content: Text('Course data exported to $filePath'),
              confirm: TextButton(
                onPressed: () {
                  Get.back(); // Close the success dialog
                  Get.back(); // Go back to the course list
                },
                child: const Text('OK'),
              ),
            );
          } else {
            Get.snackbar(
              'Export Cancelled',
              'No file path selected.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            Get.back(); // Go back to the course list
          }
        },
        child: const Text('Export'),
      ),
      cancel: TextButton(
        onPressed: () {
          Get.back(); // Go back to the course list
        },
        child: const Text('Cancel'),
      ),
    );
  }
}
