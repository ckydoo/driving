import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/course.dart';
import '../services/database_helper.dart';

class CourseController extends GetxController {
  final courses = <Course>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  @override
  void onReady() {
    fetchCourses();
    super.onReady();
  }

  /// ✅ ENHANCED: fetchCourses with better error handling
  Future<void> fetchCourses() async {
    try {
      isLoading(true);
      error('');
      print('📚 Fetching courses from database...');

      final data = await DatabaseHelper.instance.getCourses();
      print('📚 Retrieved ${data.length} course records from database');

      if (data.isEmpty) {
        print('⚠️ No courses found in database');
        courses.clear();
        return;
      }

      final List<Course> parsedCourses = [];

      for (int i = 0; i < data.length; i++) {
        try {
          final courseJson = data[i];
          print('📚 Parsing course $i: $courseJson');

          final course = Course.fromJson(courseJson);
          parsedCourses.add(course);
          print(
              '✅ Successfully parsed course: ${course.name} (\$${course.price})');
        } catch (e) {
          print('❌ Error parsing course at index $i: $e');
          print('🔍 Raw data: ${data[i]}');

          // Try to create a fallback course to prevent total failure
          try {
            final fallbackCourse = Course(
              id: data[i]['id'],
              name: data[i]['name']?.toString() ?? 'Unknown Course',
              price: 0,
              status: data[i]['status']?.toString() ?? 'Active',
              createdAt: DateTime.now(),
            );
            parsedCourses.add(fallbackCourse);
            print('⚠️ Created fallback course for failed parsing');
          } catch (fallbackError) {
            print('❌ Even fallback parsing failed: $fallbackError');
            // Skip this course entirely
          }
        }
      }

      courses.assignAll(parsedCourses);
      print('✅ Successfully loaded ${parsedCourses.length} courses');
    } catch (e) {
      error('Failed to load courses: ${e.toString()}');
      print('❌ fetchCourses error: $e');

      Get.snackbar(
        'Error',
        'Failed to load courses: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: Duration(seconds: 5),
      );
    } finally {
      isLoading(false);
    }
  }

  /// ✅ ENHANCED: handleCourse with validation
  Future<void> handleCourse(Course course, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      error('');

      // Validate course data
      if (course.name.trim().isEmpty) {
        throw Exception('Course name is required');
      }

      if (course.price < 0) {
        throw Exception('Course price cannot be negative');
      }

      print('📚 ${isUpdate ? 'Updating' : 'Creating'} course: ${course.name}');

      if (isUpdate) {
        await DatabaseHelper.instance.updateCourse(course.toJson());
        print('✅ Course updated successfully');
      } else {
        await DatabaseHelper.instance.insertCourse(course.toJson());
        print('✅ Course created successfully');
      }

      await fetchCourses(); // Refresh the list

      Get.snackbar(
        'Success',
        isUpdate
            ? 'Course "${course.name}" updated successfully'
            : 'Course "${course.name}" created successfully',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
      );
    } catch (e) {
      error('Course operation failed: ${e.toString()}');
      print('❌ handleCourse error: $e');

      Get.snackbar(
        'Error',
        'Course operation failed: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: Duration(seconds: 5),
      );
    } finally {
      isLoading(false);
    }
  }

  /// ✅ ENHANCED: deleteCourse with confirmation
  Future<void> deleteCourse(int id) async {
    try {
      isLoading(true);

      // Find the course to get its name for confirmation
      final course = courses.firstWhere((c) => c.id == id,
          orElse: () => Course(
              id: id,
              name: 'Unknown Course',
              price: 0,
              status: 'Active',
              createdAt: DateTime.now()));

      print('📚 Deleting course: ${course.name} (ID: $id)');

      await DatabaseHelper.instance.deleteCourse(id);
      courses.removeWhere((c) => c.id == id);

      print('✅ Course deleted successfully');

      Get.snackbar(
        'Success',
        'Course "${course.name}" deleted successfully',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
      );
    } catch (e) {
      error('Delete failed: ${e.toString()}');
      print('❌ deleteCourse error: $e');

      Get.snackbar(
        'Error',
        'Failed to delete course: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: Duration(seconds: 5),
      );
    } finally {
      isLoading(false);
    }
  }

  /// Get course by ID
  Course? getCourseById(int id) {
    try {
      return courses.firstWhere((course) => course.id == id);
    } catch (e) {
      print('⚠️ Course not found with ID: $id');
      return null;
    }
  }

  /// Get active courses only
  List<Course> get activeCourses {
    return courses.where((course) => course.isActive).toList();
  }

  /// Get course options for dropdowns
  List<Map<String, dynamic>> get courseOptions {
    return courses
        .map((course) => {
              'value': course.id,
              'label': '${course.name} (${course.formattedPrice})',
            })
        .toList();
  }
}
