import 'package:driving/services/sync_service.dart';
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
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 5),
      );
    } finally {
      isLoading(false);
    }
  }

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
        // Update existing course
        await DatabaseHelper.instance.updateCourse(course.toJson());

        // 🔄 TRACK THE CHANGE FOR SYNC
        await SyncService.trackChange('courses', course.toJson(), 'update');
        print('📝 Tracked course update for sync');

        print('✅ Course updated successfully');
      } else {
        // Create new course
        final id = await DatabaseHelper.instance.insertCourse(course.toJson());

        // Create course with ID for tracking
        final courseWithId = course.copyWith(id: id);

        // 🔄 TRACK THE CHANGE FOR SYNC
        await SyncService.trackChange(
            'courses', courseWithId.toJson(), 'create');
        print('📝 Tracked course creation for sync');

        print('✅ Course created successfully');
      }

      await fetchCourses(); // Refresh the list

      Get.snackbar(
        'Success',
        isUpdate
            ? 'Course "${course.name}" updated successfully'
            : 'Course "${course.name}" created successfully',
        snackPosition: SnackPosition.BOTTOM,
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
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 5),
      );
    } finally {
      isLoading(false);
    }
  }

  /// 🆕 CREATE COURSE WITH SYNC TRACKING (alternative method)
  Future<void> createCourse(Course course) async {
    await handleCourse(course, isUpdate: false);
  }

  /// 🔄 UPDATE COURSE WITH SYNC TRACKING (alternative method)
  Future<void> updateCourse(Course course) async {
    await handleCourse(course, isUpdate: true);
  }

  /// 🗑️ ENHANCED: deleteCourse with sync tracking
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

      // Delete from database
      await DatabaseHelper.instance.deleteCourse(id);

      // 🔄 TRACK THE CHANGE FOR SYNC
      await SyncService.trackChange('courses', {'id': id}, 'delete');
      print('📝 Tracked course deletion for sync');

      // Remove from local list
      courses.removeWhere((c) => c.id == id);

      print('✅ Course deleted successfully');

      Get.snackbar(
        'Success',
        'Course "${course.name}" deleted successfully',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      error('Delete failed: ${e.toString()}');
      print('❌ deleteCourse error: $e');

      Get.snackbar(
        'Error',
        'Failed to delete course: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 5),
      );
    } finally {
      isLoading(false);
    }
  }

  /// 🔄 BULK UPDATE COURSE WITH SYNC TRACKING
  Future<void> updateCourseField(
      int courseId, String field, dynamic value) async {
    try {
      print('📚 Updating course field: $field for course ID: $courseId');

      // Prepare the update data
      final updateData = {
        'id': courseId,
        field: value,
      };

      // Update in database
      await DatabaseHelper.instance.updateCourse(updateData);

      // 🔄 TRACK THE CHANGE FOR SYNC
      await SyncService.trackChange('courses', updateData, 'update');
      print('📝 Tracked course field update for sync');

      // Refresh courses
      await fetchCourses();

      print('✅ Course field updated successfully');
    } catch (e) {
      print('❌ Error updating course field: $e');
      Get.snackbar(
        'Error',
        'Failed to update course: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red.shade800,
      );
    }
  }

  /// 🔄 BULK OPERATIONS WITH SYNC TRACKING
  Future<void> updateCourseStatus(int courseId, String status) async {
    await updateCourseField(courseId, 'status', status);
  }

  Future<void> updateCoursePrice(int courseId, double price) async {
    await updateCourseField(courseId, 'price', price);
  }

  /// Get course by ID (unchanged)
  Course? getCourseById(int id) {
    try {
      return courses.firstWhere((course) => course.id == id);
    } catch (e) {
      print('⚠️ Course not found with ID: $id');
      return null;
    }
  }

  /// Get active courses only (unchanged)
  List<Course> get activeCourses {
    return courses.where((course) => course.isActive).toList();
  }

  /// Get course options for dropdowns (unchanged)
  List<Map<String, dynamic>> get courseOptions {
    return courses
        .map((course) => {
              'value': course.id,
              'label': '${course.name} (${course.formattedPrice})',
            })
        .toList();
  }
}
