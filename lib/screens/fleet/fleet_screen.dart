import 'dart:io';

import 'package:csv/csv.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/fleet/fleet_details_screen.dart';
import 'package:driving/widgets/fleet_form_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/fleet_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/fleet.dart';

class FleetScreen extends GetView<FleetController> {
  const FleetScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final fleetController = Get.find<FleetController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vehicle Management',
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
            onPressed: () async {
              await userController.fetchUsers();
              await fleetController.fetchFleet();
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
                // Search Bar
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search vehicles...',
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
                    onChanged: (value) {
                      fleetController.searchFleet(value); // Update search query
                    },
                  ),
                ),
                const SizedBox(
                    width: 8), // Spacing between search bar and buttons
                // Import Button
                IconButton(
                  icon: const Icon(Icons.upload, color: Colors.white),
                  onPressed: () {
                    _showImportDialog();
                  },
                ),
                // Export Button
                IconButton(
                  icon: const Icon(
                    Icons.download,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _showExportDialog();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (fleetController.isLoading.value || userController.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.blue,
            ),
          );
        }

        // Check if a search has been performed and no results were found
        if (fleetController.searchQuery.isNotEmpty &&
            fleetController.searchedFleet.isEmpty) {
          return const Center(
            child: Text(
              'No vehicles found',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
            ),
          );
        }

        // Determine which list to use
        final List<Fleet> fleetList = fleetController.searchedFleet.isNotEmpty
            ? fleetController.searchedFleet
            : fleetController.fleet;

        if (fleetList.isEmpty) {
          return const Center(
            child: Text(
              'No vehicles found',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
            ),
          );
        }

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
                  itemCount: fleetList.length,
                  itemBuilder: (context, index) {
                    final vehicle = fleetList[index];
                    return _buildDataRow(vehicle, index);
                  },
                ),
              ),
            ),
            _buildPagination(),
          ],
        );
      }),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: fleetController.isMultiSelectionActive,
        builder: (context, value, child) {
          return FloatingActionButton.extended(
            onPressed: value
                ? () {
                    _showMultiDeleteConfirmationDialog();
                  }
                : () {
                    Get.dialog(const FleetFormDialog());
                  },
            label: value
                ? Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Delete Selected',
                          style: TextStyle(color: Colors.white)),
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Add Vehicle',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
            backgroundColor: value ? Colors.redAccent : Colors.blue.shade800,
          );
        },
      ),
    );
  }

  // Method to show Import Dialog
  void _showImportDialog() {
    final fleetController = Get.find<FleetController>();

    Get.defaultDialog(
      title: 'Import Vehicles',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Instructions
          ExpansionTile(
            title: const Text('Import Instructions'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Download the sample CSV template below.\n'
                      '2. Fill in the template with your vehicle data.\n'
                      '3. Ensure the CSV file has the following columns:\n'
                      '   - Car No\n'
                      '   - Make\n'
                      '   - Model\n'
                      '   - Car Plate\n'
                      '   - Instructor ID\n'
                      '   - Model Year\n'
                      '4. Upload the CSV file using the "Import" button.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        // Generate and download the sample CSV template
                        final csvData = const ListToCsvConverter().convert(
                          [
                            [
                              'Car No',
                              'Make',
                              'Model',
                              'Car Plate',
                              'Instructor ID',
                              'Model Year'
                            ], // Header row
                            [
                              '1',
                              'Toyota',
                              'Corolla',
                              'ABC123',
                              '1',
                              '2020'
                            ], // Example row
                          ],
                        );

                        // Save the CSV file
                        final String? filePath =
                            await FilePicker.platform.saveFile(
                          dialogTitle: 'Save Sample CSV Template',
                          fileName: 'fleet_template.csv',
                          allowedExtensions: ['csv'],
                        );

                        if (filePath != null) {
                          final file = File(filePath);
                          await file.writeAsString(csvData);
                          Get.snackbar(
                            'Template Downloaded',
                            'Sample CSV template saved to $filePath',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                          );
                        } else {
                          Get.snackbar(
                            'Download Cancelled',
                            'No file path selected.',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      },
                      child: const Text('Download Sample CSV Template'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Upload a CSV file to import vehicles.'),
        ],
      ),
      confirm: TextButton(
        onPressed: () async {
          // Pick CSV file
          final FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['csv'],
          );

          if (result != null && result.files.single.path != null) {
            final file = File(result.files.single.path!);
            final csvString = await file.readAsString();

            // Parse CSV data
            final csvData = const CsvToListConverter().convert(csvString);

            // Validate CSV format
            if (csvData.isNotEmpty) {
              // Check if the header row matches the expected format
              final expectedHeaders = [
                'Car No',
                'Make',
                'Model',
                'Car Plate',
                'Instructor ID',
                'Model Year'
              ];
              final actualHeaders =
                  csvData[0].map((header) => header.toString()).toList();

              if (actualHeaders.length == expectedHeaders.length &&
                  actualHeaders
                      .every((header) => expectedHeaders.contains(header))) {
                // Process the CSV data
                final newFleet = <Fleet>[];
                final errors = <String>[];

                for (var i = 1; i < csvData.length; i++) {
                  final row = csvData[i];

                  // Validate row length
                  if (row.length != 6) {
                    errors.add('Row ${i + 1}: Invalid number of columns.');
                    continue;
                  }

                  // Validate Car No
                  final carNo = row[0].toString();
                  if (carNo.isEmpty || int.tryParse(carNo) == null) {
                    errors.add('Row ${i + 1}: Invalid Car No.');
                    continue;
                  }

                  // Validate Car Plate
                  final carPlate = row[3].toString();
                  if (carPlate.isEmpty) {
                    errors.add('Row ${i + 1}: Car Plate is required.');
                    continue;
                  }

                  // Check for duplicates
                  if (fleetController.fleet
                      .any((vehicle) => vehicle.carPlate == carPlate)) {
                    errors.add(
                        'Row ${i + 1}: Car Plate $carPlate already exists.');
                    continue;
                  }
                  if (fleetController.fleet
                      .any((vehicle) => vehicle.carPlate == carPlate)) {
                    errors.add(
                        'Row ${i + 1}: Car Plate $carPlate already exists.');
                    continue;
                  }

                  // Validate Instructor ID
                  final instructorId = int.tryParse(row[4].toString());
                  if (instructorId == null) {
                    errors.add('Row ${i + 1}: Invalid Instructor ID.');
                    continue;
                  }

                  // Validate Model Year
                  final modelYear = row[5].toString();
                  if (modelYear.isEmpty || int.tryParse(modelYear) == null) {
                    errors.add('Row ${i + 1}: Invalid Model Year.');
                    continue;
                  }

                  // Add valid vehicle to the new fleet list
                  newFleet.add(Fleet(
                    id: null, // Auto-generated by the backend
                    make: row[1].toString(),
                    model: row[2].toString(),
                    carPlate: carPlate,
                    instructor: instructorId,
                    modelYear: modelYear,
                  ));
                }

                if (errors.isNotEmpty) {
                  // Show errors
                  Get.defaultDialog(
                    title: 'Import Errors',
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: errors.map((error) => Text(error)).toList(),
                      ),
                    ),
                    confirm: TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: const Text('OK'),
                    ),
                  );
                } else {
                  // Save the new fleet data to the database
                  await fleetController.saveFleet(newFleet);
                  Get.snackbar(
                    'Import Successful',
                    '${newFleet.length} vehicles imported.',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                }
              } else {
                Get.snackbar(
                  'Invalid CSV Format',
                  'The CSV file must have the following columns: Car No, Make, Model, Car Plate, Instructor ID, Model Year.',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            } else {
              Get.snackbar(
                'Invalid CSV File',
                'The CSV file is empty or improperly formatted.',
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
            }
          } else {
            Get.snackbar(
              'Import Cancelled',
              'No file selected.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }

          Get.back();
        },
        child: const Text('Import'),
      ),
      cancel: TextButton(
        onPressed: () {
          Get.back();
        },
        child: const Text('Cancel'),
      ),
    );
  }

  // Method to show Export Dialog
  void _showExportDialog() {
    final fleetController = Get.find<FleetController>();

    Get.defaultDialog(
      title: 'Export Vehicles',
      content: const Text('Export the current list of vehicles to a CSV file.'),
      confirm: TextButton(
        onPressed: () async {
          // Convert fleet data to CSV
          final csvData = const ListToCsvConverter().convert(
            [
              [
                'Make',
                'Model',
                'Car Plate',
                'Instructor',
                'Year'
              ], // Header row
              ...fleetController.fleet.map((vehicle) => [
                    vehicle.make,
                    vehicle.model,
                    vehicle.carPlate,
                    vehicle.instructor.toString(),
                    vehicle.modelYear,
                  ]),
            ],
          );

          // Sanitize file name
          final timestamp = DateTime.now()
              .toIso8601String()
              .replaceAll(RegExp(r'[:\.]'), '_');
          final fileName = 'fleet_export_$timestamp.csv';

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
              content: Text('Fleet data exported to $filePath'),
              confirm: TextButton(
                onPressed: () {
                  Get.back(); // Close the success dialog
                  Get.back(); // Go back to the fleet list
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
            Get.back(); // Go back to the fleet list
          }
        },
        child: const Text('Export'),
      ),
      cancel: TextButton(
        onPressed: () {
          Get.back(); // Go back to the fleet list
        },
        child: const Text('Cancel'),
      ),
    );
  }

  Widget _buildHeaderRow() {
    final fleetController = Get.find<FleetController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Checkbox(
            value: fleetController.isAllSelected.value,
            onChanged: (bool? value) {
              fleetController.toggleSelectAll(value!);
            },
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Make/Model',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Plate',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Instructor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Year',
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

  Widget _buildDataRow(Fleet vehicle, int index) {
    final fleetController = Get.find<FleetController>();

    String _getInstructorName(int instructorId) {
      final userController = Get.find<UserController>();

      if (userController.isLoading.value) return 'Loading...';

      if (userController.users.isEmpty) {
        return 'Loading...';
      }

      final instructor = userController.users.firstWhere(
        (user) =>
            user.id == instructorId && user.role.toLowerCase() == 'instructor',
        orElse: () => User(
          id: -1,
          fname: 'Unknown',
          lname: 'Instructor',
          email: '',
          date_of_birth: DateTime.now(),
          password: '',
          role: '',
          status: '',
          created_at: DateTime.now(),
          gender: '',
          phone: '',
          address: '',
          idnumber: '',
        ),
      );

      return instructor.id == -1
          ? 'Unknown Instructor'
          : '${instructor.fname} ${instructor.lname}';
    }

    return Container(
      color: index % 2 == 0 ? Colors.grey.shade100 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: InkWell(
          onTap: () {
            Navigator.of(Get.context!).push(
              MaterialPageRoute(
                builder: (context) => FleetDetailsScreen(
                  fleetId: vehicle.id!,
                ),
              ),
            );
          },
          child: Row(
            children: [
              Checkbox(
                value: fleetController.selectedFleet.contains(vehicle.id),
                onChanged: (bool? value) {
                  fleetController.toggleFleetSelection(vehicle.id!);
                  if (fleetController.isAllSelected.value && value == false) {
                    fleetController.isAllSelected(false);
                  }
                },
              ),
              Expanded(
                  flex: 2, child: Text('${vehicle.make} ${vehicle.model}')),
              Expanded(flex: 1, child: Text(vehicle.carPlate)),
              Expanded(
                  flex: 2, child: Text(_getInstructorName(vehicle.instructor))),
              Expanded(flex: 1, child: Text(vehicle.modelYear)),
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Get.dialog(FleetFormDialog(vehicle: vehicle));
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteConfirmationDialog(vehicle.id!);
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
    final fleetController = Get.find<FleetController>();

    return Padding(
      padding: const EdgeInsets.only(
          left: 16.0, right: 200.0, top: 40.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
            onPressed: () {
              fleetController.goToPreviousPage();
            },
          ),
          Obx(() => Text(
                'Page ${fleetController.currentPage} of ${fleetController.totalPages}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              )),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
            onPressed: () {
              fleetController.goToNextPage();
            },
          ),
          DropdownButton<int>(
            value: 10,
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
              // Implement rows per page change
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(int id) {
    final fleetController = Get.find<FleetController>();

    Get.defaultDialog(
      title: 'Confirm Delete',
      content: const Text('Are you sure you want to delete this vehicle?'),
      confirm: TextButton(
        onPressed: () {
          fleetController.deleteFleet(id);
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
    final fleetController = Get.find<FleetController>();
    Get.defaultDialog(
      title: 'Confirm Multi-Delete',
      content: Text(
          'Are you sure you want to delete the selected ${fleetController.selectedFleet.length} vehicles?'),
      confirm: TextButton(
        onPressed: () {
          fleetController.selectedFleet.forEach((id) {
            fleetController.deleteFleet(id);
          });
          fleetController.toggleSelectAll(false);
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
}
