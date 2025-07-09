import 'package:driving/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/fleet.dart';
import '../services/database_helper.dart';

class FleetController extends GetxController {
  final RxList<Fleet> _fleet = <Fleet>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  RxList<Fleet> searchedFleet = <Fleet>[].obs;
  RxList<int> selectedFleet = <int>[].obs;
  final searchQuery = ''.obs; // Observable search query
  RxBool isAllSelected = false.obs;
  List<Fleet> get fleet => _fleet;
  // Pagination variables
  final int _rowsPerPage = 10;
  final RxInt _currentPage = 1.obs;
  int get currentPage => _currentPage.value;
  int get totalPages => (_fleet.length / _rowsPerPage).ceil();
  // Add this ValueNotifier
  final ValueNotifier<bool> isMultiSelectionActive = ValueNotifier<bool>(false);

  @override
  void onReady() {
    fetchInitialData();
    super.onReady();
  }

  // Method to get fleet for the current page
  List<Fleet> get fleetForCurrentPage {
    final startIndex = (_currentPage.value - 1) * _rowsPerPage;
    var endIndex = startIndex + _rowsPerPage;
    if (endIndex > _fleet.length) {
      endIndex = _fleet.length;
    }
    return _fleet.sublist(startIndex, endIndex);
  }

  void goToPreviousPage() {
    if (_currentPage.value > 1) {
      _currentPage.value--;
    }
  }

  void goToNextPage() {
    if (_currentPage.value < totalPages) {
      _currentPage.value++;
    }
  }

  void toggleFleetSelection(int id) {
    if (selectedFleet.contains(id)) {
      selectedFleet.remove(id);
    } else {
      selectedFleet.add(id);
    }
    isMultiSelectionActive.value = selectedFleet.isNotEmpty;
  }

  void toggleSelectAll(bool value) {
    isAllSelected.value = value;
    if (value) {
      selectedFleet.assignAll(_fleet.map((vehicle) => vehicle.id!));
    } else {
      selectedFleet.clear();
    }
    isMultiSelectionActive.value = selectedFleet.isNotEmpty;
  }

  void searchFleet(String query) {
    searchQuery.value = query; // Update the search query
    if (query.isEmpty) {
      searchedFleet.clear(); // Clear search results if query is empty
    } else {
      // Filter the fleet list based on the query
      searchedFleet.assignAll(
        fleet.where((vehicle) =>
            vehicle.make.toLowerCase().contains(query.toLowerCase()) ||
            vehicle.model.toLowerCase().contains(query.toLowerCase()) ||
            vehicle.carPlate.toLowerCase().contains(query.toLowerCase())),
      );
    }
  }

  Future<void> fetchInitialData() async {
    try {
      isLoading(true);
      error('');
      await Get.find<UserController>().fetchUsers();
      await fetchFleet();
    } catch (e) {
      error(e.toString());
      Get.snackbar('Error', 'Failed to load data: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchFleet() async {
    try {
      final data = await DatabaseHelper.instance.getFleet();
      _fleet.assignAll(data.map((json) => Fleet.fromJson(json)));
    } catch (e) {
      throw Exception('Failed to load fleet: ${e.toString()}');
    }
  }

  Future<void> saveFleet(List<Fleet> newFleet) async {
    for (final vehicle in newFleet) {
      await DatabaseHelper.instance.insertFleet(
        Fleet.fromJson(vehicle.toJson()).toJson(),
      );
    }
    await fetchFleet(); // Refresh the list after saving
  }

  Future<void> handleFleet(Fleet vehicle, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      if (isUpdate) {
        await DatabaseHelper.instance.updateFleet(vehicle.toJson());
      } else {
        await DatabaseHelper.instance.insertFleet(vehicle.toJson());
      }
      await fetchFleet();
    } catch (e) {
      throw Exception('Fleet operation failed: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  Future<void> deleteFleet(int id) async {
    try {
      isLoading(true);
      await DatabaseHelper.instance.deleteFleet(id);
      _fleet.removeWhere((vehicle) => vehicle.id == id);
    } catch (e) {
      throw Exception('Delete failed: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }
}
