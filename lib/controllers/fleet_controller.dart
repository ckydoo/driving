import 'package:driving/controllers/user_controller.dart';
import 'package:driving/services/sync_service.dart';
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
      Get.snackbar(
        'Error',
        'Failed to load data: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
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

  Future<void> handleFleet(Fleet vehicle, {bool isUpdate = false}) async {
    try {
      isLoading(true);
      print(
          '🚗 ${isUpdate ? 'Updating' : 'Creating'} vehicle: ${vehicle.make} ${vehicle.model}');

      int? vehicleId;

      if (isUpdate) {
        // Update existing vehicle
        await DatabaseHelper.instance.updateFleet(vehicle.toJson());
        vehicleId = vehicle.id;
        print('✅ Vehicle updated successfully');
      } else {
        // Create new vehicle - ONLY INSERT ONCE
        vehicleId = await DatabaseHelper.instance.insertFleet(vehicle.toJson());
        print('✅ Vehicle created successfully with ID: $vehicleId');
      }

      // Optional operations - don't let these block the main flow
      try {
        if (!isUpdate) {
          // Use the ID we already got from the insert above
          final vehicleWithId = vehicle.copyWith(id: vehicleId);
          await SyncService.trackChange(
              'fleet', vehicleWithId.toJson(), 'create');
        } else {
          await SyncService.trackChange('fleet', vehicle.toJson(), 'update');
        }
        print('📝 Tracked vehicle change for sync');
      } catch (e) {
        print('⚠️ Sync tracking failed (non-critical): $e');
      }

      // Refresh the fleet list
      try {
        await fetchFleet();
      } catch (e) {
        print('⚠️ Fleet refresh failed (non-critical): $e');
      }

      // Show success message
      try {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Success',
          isUpdate
              ? 'Vehicle "${vehicle.make} ${vehicle.model}" updated successfully'
              : 'Vehicle "${vehicle.make} ${vehicle.model}" created successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        print('⚠️ Snackbar failed (non-critical): $e');
      }
    } catch (e) {
      error('Fleet operation failed: ${e.toString()}');
      print('❌ handleFleet error: $e');

      Get.snackbar(
        'Error',
        'Fleet operation failed: ${e.toString()}',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );

      // Only throw on actual save failures
      rethrow; // ✅ Let the dialog handle the error
    } finally {
      isLoading(false);
    }
  }

  /// 🆕 CREATE VEHICLE WITH SYNC TRACKING (alternative method)
  Future<void> createVehicle(Fleet vehicle) async {
    await handleFleet(vehicle, isUpdate: false);
  }

  /// 🔄 UPDATE VEHICLE WITH SYNC TRACKING (alternative method)
  Future<void> updateVehicle(Fleet vehicle) async {
    await handleFleet(vehicle, isUpdate: true);
  }

  /// 🗑️ ENHANCED: deleteFleet with sync tracking
  Future<void> deleteFleet(int id) async {
    try {
      isLoading(true);

      // Find the vehicle to get its details for confirmation
      final vehicle = _fleet.firstWhere((v) => v.id == id,
          orElse: () => Fleet(
              id: id,
              carPlate: 'Unknown',
              make: 'Unknown',
              model: 'Vehicle',
              modelYear: '',
              status: 'available',
              instructor: 1));

      print(
          '🚗 Deleting vehicle: ${vehicle.make} ${vehicle.model} (${vehicle.carPlate})');

      // Delete from database
      await DatabaseHelper.instance.deleteFleet(id);

      // 🔄 TRACK THE CHANGE FOR SYNC
      await SyncService.trackChange('fleet', {'id': id}, 'delete');
      print('📝 Tracked vehicle deletion for sync');

      // Remove from local list
      _fleet.removeWhere((vehicle) => vehicle.id == id);

      print('✅ Vehicle deleted successfully');

      Get.snackbar(
        'Success',
        'Vehicle "${vehicle.make} ${vehicle.model}" deleted successfully',
        backgroundColor: Colors.green,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
    } catch (e) {
      error('Delete failed: ${e.toString()}');
      print('❌ deleteFleet error: $e');

      Get.snackbar(
        'Error',
        'Failed to delete vehicle: ${e.toString()}',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
      throw Exception('Delete failed: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  /// 🔄 ENHANCED: assignVehicleToInstructor with sync tracking
  Future<void> assignVehicleToInstructor(
      int vehicleId, int instructorId) async {
    try {
      print('🚗 Assigning vehicle $vehicleId to instructor $instructorId');

      // Prepare the update data
      final updateData = {
        'id': vehicleId,
        'instructor': instructorId,
      };

      // Update vehicle assignment in database
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'fleet',
        {'instructor': instructorId},
        where: 'id = ?',
        whereArgs: [vehicleId],
      );

      // 🔄 TRACK THE CHANGE FOR SYNC
      await SyncService.trackChange('fleet', updateData, 'update');
      print('📝 Tracked vehicle assignment for sync');

      // Refresh fleet data
      await fetchFleet();

      print('✅ Vehicle assigned successfully');

      Get.snackbar('Success', 'Vehicle assigned to instructor successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      print('❌ Error assigning vehicle: $e');
      Get.snackbar(
        'Error',
        'Failed to assign vehicle: ${e.toString()}',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
    }
  }

  /// 🔄 UPDATE VEHICLE STATUS WITH SYNC TRACKING
  Future<void> updateVehicleStatus(int vehicleId, String status) async {
    try {
      print('🚗 Updating vehicle status: $vehicleId to $status');

      // Prepare the update data
      final updateData = {
        'id': vehicleId,
        'status': status,
      };

      // Update in database
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'fleet',
        {'status': status},
        where: 'id = ?',
        whereArgs: [vehicleId],
      );

      // 🔄 TRACK THE CHANGE FOR SYNC
      await SyncService.trackChange('fleet', updateData, 'update');
      print('📝 Tracked vehicle status update for sync');

      // Refresh fleet data
      await fetchFleet();

      print('✅ Vehicle status updated successfully');
    } catch (e) {
      print('❌ Error updating vehicle status: $e');
      Get.snackbar(
        'Error',
        'Failed to update vehicle status: ${e.toString()}',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
    }
  }

  /// 🔄 BULK UPDATE VEHICLE FIELD WITH SYNC TRACKING
  Future<void> updateVehicleField(
      int vehicleId, String field, dynamic value) async {
    try {
      print('🚗 Updating vehicle field: $field for vehicle ID: $vehicleId');

      // Prepare the update data
      final updateData = {
        'id': vehicleId,
        field: value,
      };

      // Update in database
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'fleet',
        {field: value},
        where: 'id = ?',
        whereArgs: [vehicleId],
      );

      // 🔄 TRACK THE CHANGE FOR SYNC
      await SyncService.trackChange('fleet', updateData, 'update');
      print('📝 Tracked vehicle field update for sync');

      // Refresh fleet
      await fetchFleet();

      print('✅ Vehicle field updated successfully');
    } catch (e) {
      print('❌ Error updating vehicle field: $e');
      Get.snackbar(
        'Error',
        'Failed to update vehicle: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 🔄 BULK OPERATIONS WITH SYNC TRACKING
  Future<void> bulkUpdateVehicleStatus(
      List<int> vehicleIds, String status) async {
    try {
      isLoading(true);
      print(
          '🚗 Bulk updating ${vehicleIds.length} vehicles to status: $status');

      for (int vehicleId in vehicleIds) {
        await updateVehicleStatus(vehicleId, status);
      }

      Get.snackbar(
        'Bulk Update Complete',
        'Updated ${vehicleIds.length} vehicles successfully',
        backgroundColor: Colors.green,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
    } catch (e) {
      print('❌ Error in bulk update: $e');
      Get.snackbar(
        'Bulk Update Failed',
        'Failed to update vehicles: ${e.toString()}',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  /// 🔄 BULK DELETE WITH SYNC TRACKING
  Future<void> bulkDeleteVehicles(List<int> vehicleIds) async {
    try {
      isLoading(true);
      print('🚗 Bulk deleting ${vehicleIds.length} vehicles');

      for (int vehicleId in vehicleIds) {
        await deleteFleet(vehicleId);
      }

      // Clear selections
      selectedFleet.clear();
      isMultiSelectionActive.value = false;

      Get.snackbar(
        'Bulk Delete Complete',
        'Deleted ${vehicleIds.length} vehicles successfully',
        backgroundColor: Colors.green,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
    } catch (e) {
      print('❌ Error in bulk delete: $e');
      Get.snackbar(
        'Bulk Delete Failed',
        'Failed to delete vehicles: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  /// 🔄 SAVE FLEET (for bulk imports) WITH SYNC TRACKING
  Future<void> saveFleet(List<Fleet> newFleet) async {
    try {
      isLoading(true);
      print('🚗 Saving ${newFleet.length} vehicles to database');

      for (final vehicle in newFleet) {
        // Insert and get ID
        final id = await DatabaseHelper.instance.insertFleet(vehicle.toJson());

        // Create vehicle with ID for tracking
        final vehicleWithId = vehicle.copyWith(id: id);

        // 🔄 TRACK THE CHANGE FOR SYNC
        await SyncService.trackChange(
            'fleet', vehicleWithId.toJson(), 'create');
      }

      print('📝 Tracked ${newFleet.length} vehicle creations for sync');

      // Refresh the list after saving
      await fetchFleet();

      Get.snackbar(
        'Import Complete',
        'Successfully imported ${newFleet.length} vehicles',
        backgroundColor: Colors.green,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
    } catch (e) {
      print('❌ Error saving fleet: $e');
      Get.snackbar(
        'Import Failed',
        'Failed to import vehicles: ${e.toString()}',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }
}
