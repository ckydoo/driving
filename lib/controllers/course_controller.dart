import 'package:get/get.dart';
import '../models/course.dart';
import '../services/database_helper.dart';

class CourseController extends GetxController {
  final courses = <Course>[].obs; // Add .obs
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  @override
  void onReady() {
    fetchCourses();
    super.onReady();
  }

  Future<void> fetchCourses() async {
    try {
      isLoading(true);
      error('');
      final data = await DatabaseHelper.instance.getCourses();
      courses.assignAll(data.map((json) => Course.fromJson(json)));
    } catch (e) {
      error(e.toString());
      Get.snackbar('Error', 'Failed to load courses: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  Future<void> handleCourse(Course course, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      isUpdate
          ? await DatabaseHelper.instance.updateCourse(course.toJson())
          : await DatabaseHelper.instance.insertCourse(course.toJson());
      await fetchCourses();
    } catch (e) {
      error(e.toString());
      Get.snackbar('Error', 'Course operation failed: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  Future<void> deleteCourse(int id) async {
    try {
      isLoading(true);
      await DatabaseHelper.instance.deleteCourse(id);
      courses.removeWhere((course) => course.id == id);
    } catch (e) {
      error(e.toString());
      Get.snackbar('Error', 'Delete failed: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }
}
