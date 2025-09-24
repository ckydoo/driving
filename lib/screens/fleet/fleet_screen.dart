// lib/screens/fleet/enhanced_vehicle_screen.dart
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/screens/fleet/fleet_details_screen.dart';
import 'package:driving/widgets/fleet_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/fleet_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/fleet.dart';

class FleetScreen extends StatefulWidget {
  const FleetScreen({Key? key}) : super(key: key);

  @override
  _FleetScreenState createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen>
    with SingleTickerProviderStateMixin {
  final FleetController fleetController = Get.find<FleetController>();
  final UserController userController = Get.find<UserController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();

  final TextEditingController _searchController = TextEditingController();
  List<Fleet> _vehicles = [];
  List<Fleet> _searchResults = [];
  List<int> _selectedVehicles = [];
  bool _isMultiSelectionActive = false;
  bool _isAllSelected = false;
  String _sortBy = 'make';
  bool _sortAscending = true;
  String _filterStatus = 'all';
  bool _isLoading = true;

  // Pagination variables
  int _currentPage = 1;
  int _rowsPerPage = 12;

  // Tab controller for different views
  late TabController _tabController;

  // Smart recommendations
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _quickStats = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVehicles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await fleetController.fetchFleet();
      await userController.fetchUsers();
      await scheduleController.fetchSchedules();

      setState(() {
        _vehicles = fleetController.fleet;
        _searchResults = List.from(_vehicles);
        _sortVehicles();
        _filterVehicles();
        _generateQuickStats();
        _generateRecommendations();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Failed to load vehicles: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _searchVehicles(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = List.from(_vehicles);
      } else {
        _searchResults = _vehicles
            .where((vehicle) =>
                vehicle.make.toLowerCase().contains(query.toLowerCase()) ||
                vehicle.model.toLowerCase().contains(query.toLowerCase()) ||
                vehicle.carPlate.toLowerCase().contains(query.toLowerCase()) ||
                _getInstructorName(vehicle.instructor)
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
      _filterVehicles();
      _sortVehicles();
      _currentPage = 1;
    });
  }

  void _sortVehicles() {
    setState(() {
      _searchResults.sort((a, b) {
        dynamic aValue, bValue;
        switch (_sortBy) {
          case 'make':
            aValue = '${a.make} ${a.model}'.toLowerCase();
            bValue = '${b.make} ${b.model}'.toLowerCase();
            break;
          case 'year':
            aValue = int.parse(a.modelYear);
            bValue = int.parse(b.modelYear);
            break;
          case 'plate':
            aValue = a.carPlate.toLowerCase();
            bValue = b.carPlate.toLowerCase();
            break;
          case 'instructor':
            aValue = _getInstructorName(a.instructor).toLowerCase();
            bValue = _getInstructorName(b.instructor).toLowerCase();
            break;
          default:
            aValue = '${a.make} ${a.model}'.toLowerCase();
            bValue = '${b.make} ${b.model}'.toLowerCase();
        }
        return _sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      });
    });
  }

  void _filterVehicles() {
    setState(() {
      if (_filterStatus == 'assigned') {
        _searchResults =
            _searchResults.where((vehicle) => vehicle.instructor != 0).toList();
      } else if (_filterStatus == 'unassigned') {
        _searchResults =
            _searchResults.where((vehicle) => vehicle.instructor == 0).toList();
      }
    });
  }

  void _generateQuickStats() {
    final totalVehicles = _vehicles.length;
    final assignedVehicles = _vehicles.where((v) => v.instructor != 0).length;
    final unassignedVehicles = totalVehicles - assignedVehicles;

    // Calculate average vehicle age

    // Get unique makes
    final uniqueMakes = _vehicles.map((v) => v.make).toSet().length;

    _quickStats = [
      {
        'title': 'Total Vehicles',
        'value': totalVehicles.toString(),
        'icon': Icons.directions_car,
        'color': Colors.blue,
        'subtitle': '$uniqueMakes different makes',
      },
      {
        'title': 'Assigned',
        'value': assignedVehicles.toString(),
        'icon': Icons.person_pin,
        'color': Colors.green,
        'subtitle':
            '${((assignedVehicles / totalVehicles) * 100).toStringAsFixed(1)}% utilization',
      },
      {
        'title': 'Available',
        'value': unassignedVehicles.toString(),
        'icon': Icons.car_rental,
        'color': Colors.orange,
        'subtitle': 'Ready for assignment',
      },
    ];
  }

  void _generateRecommendations() {
    _recommendations.clear();

    // Unassigned vehicles
    final unassignedVehicles = _vehicles.where((v) => v.instructor == 0).length;
    if (unassignedVehicles > 0) {
      _recommendations.add({
        'type': 'warning',
        'title': 'Unassigned Vehicles',
        'description':
            '$unassignedVehicles vehicles are not assigned to instructors.',
        'action': 'Assign Instructors',
        'icon': Icons.assignment_ind,
        'color': Colors.orange,
        'priority': 'high',
        'onTap': () => _showUnassignedVehicles(),
      });
    }

    // Old vehicles that might need replacement
    final currentYear = DateTime.now().year;
    final oldVehicles = _vehicles
        .where((v) => currentYear - int.parse(v.modelYear) > 10)
        .length;
    if (oldVehicles > 0) {
      _recommendations.add({
        'type': 'info',
        'title': 'Vehicle Replacement',
        'description': '$oldVehicles vehicles are over 10 years old.',
        'action': 'Review Fleet',
        'icon': Icons.update,
        'color': Colors.blue,
        'priority': 'medium',
        'onTap': () => _showOldVehicles(),
      });
    }

    // Instructors without vehicles
    final instructors = userController.users
        .where((u) => u.role.toLowerCase() == 'instructor')
        .toList();
    final assignedInstructorIds = _vehicles.map((v) => v.instructor).toSet();
    final unassignedInstructors =
        instructors.where((i) => !assignedInstructorIds.contains(i.id)).length;

    if (unassignedInstructors > 0) {
      _recommendations.add({
        'type': 'warning',
        'title': 'Instructors Need Vehicles',
        'description':
            '$unassignedInstructors instructors don\'t have assigned vehicles.',
        'action': 'Add Vehicles',
        'icon': Icons.add_circle,
        'color': Colors.red,
        'priority': 'high',
        'onTap': () => _showUnassignedInstructors(),
      });
    }

    // Fleet utilization analysis
    final utilizationRate = _vehicles.isNotEmpty
        ? (_vehicles.where((v) => v.instructor != 0).length /
                _vehicles.length) *
            100
        : 0.0;

    if (utilizationRate > 95) {
      _recommendations.add({
        'type': 'success',
        'title': 'Excellent Utilization',
        'description':
            'Fleet utilization is at ${utilizationRate.toStringAsFixed(1)}%.',
        'action': 'View Details',
        'icon': Icons.trending_up,
        'color': Colors.green,
        'priority': 'info',
        'onTap': () => _showUtilizationDetails(),
      });
    } else if (utilizationRate < 70) {
      _recommendations.add({
        'type': 'suggestion',
        'title': 'Low Utilization',
        'description':
            'Fleet utilization is only ${utilizationRate.toStringAsFixed(1)}%.',
        'action': 'Optimize Fleet',
        'icon': Icons.trending_down,
        'color': Colors.blue,
        'priority': 'medium',
        'onTap': () => _showOptimizationSuggestions(),
      });
    }

    // Maintenance recommendations based on age
    final maintenanceNeeded =
        _vehicles.where((v) => currentYear - int.parse(v.modelYear) > 5).length;
    if (maintenanceNeeded > 0) {
      _recommendations.add({
        'type': 'info',
        'title': 'Maintenance Planning',
        'description':
            '$maintenanceNeeded vehicles may need increased maintenance.',
        'action': 'Plan Maintenance',
        'icon': Icons.build,
        'color': Colors.grey,
        'priority': 'low',
        'onTap': () => _showMaintenanceSchedule(),
      });
    }
  }

  String _getInstructorName(int instructorId) {
    if (instructorId == 0) return 'Unassigned';

    final instructor = userController.users.firstWhereOrNull(
      (user) =>
          user.id == instructorId && user.role.toLowerCase() == 'instructor',
    );

    return instructor != null
        ? '${instructor.fname} ${instructor.lname}'
        : 'Unknown Instructor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header with stats and controls
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Quick stats cards
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickStats.length,
                    itemBuilder: (context, index) {
                      final stat = _quickStats[index];
                      return Container(
                        width: MediaQuery.of(context).size.width > 1200
                            ? 200
                            : MediaQuery.of(context).size.width > 800
                                ? 180
                                : 160,
                        margin: EdgeInsets.only(right: 16),
                        child: _buildStatCard(stat),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),

                // Search and filters - Make responsive
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 1200) {
                      return _buildWideScreenFilters();
                    } else if (constraints.maxWidth > 800) {
                      return _buildMediumScreenFilters();
                    } else {
                      return _buildNarrowScreenFilters();
                    }
                  },
                ),
              ],
            ),
          ),

          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[600],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue[600],
              isScrollable: MediaQuery.of(context).size.width < 600,
              tabs: [
                Tab(icon: Icon(Icons.list), text: 'List View'),
                Tab(icon: Icon(Icons.lightbulb), text: 'Recommendations'),
              ],
            ),
          ),

          // Multi-selection bar
          if (_isMultiSelectionActive)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue[50],
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _isAllSelected,
                      onChanged: _toggleSelectAll,
                    ),
                    Text('${_selectedVehicles.length} selected'),
                    SizedBox(width: 16),
                    TextButton.icon(
                      icon: Icon(Icons.assignment_ind, color: Colors.blue),
                      label: Text('Assign Instructors',
                          style: TextStyle(color: Colors.blue)),
                      onPressed: _selectedVehicles.isNotEmpty
                          ? () => _bulkAssignInstructors()
                          : null,
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.delete, color: Colors.red),
                      label: Text('Delete Selected',
                          style: TextStyle(color: Colors.red)),
                      onPressed: _selectedVehicles.isNotEmpty
                          ? () => _deleteSelectedVehicles()
                          : null,
                    ),
                  ],
                ),
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListView(),
                      _buildRecommendationsView(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Get.dialog<bool>(
            FleetFormDialog(),
          );
          if (result == true) {
            _loadVehicles();
          }
        },
        label: MediaQuery.of(context).size.width > 600
            ? Text('Add Vehicle')
            : Text('Add Vehicle'),
        icon: Icon(Icons.add),
        backgroundColor: Colors.blue[600],
      ),
    );
  }

  // Wide screen filters (desktop)
  Widget _buildWideScreenFilters() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search vehicles, plates, instructors...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _searchVehicles,
          ),
        ),
        SizedBox(width: 16),
        _buildFilterDropdown(),
        SizedBox(width: 16),
        _buildSortDropdown(),
        SizedBox(width: 8),
        IconButton(
          icon:
              Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
          onPressed: () {
            setState(() {
              _sortAscending = !_sortAscending;
              _sortVehicles();
            });
          },
        ),
        Spacer(),
        Flexible(
          child: Text(
            '${_searchResults.length} vehicles found',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Medium screen filters (tablet)
  Widget _buildMediumScreenFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search vehicles, plates, instructors...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: _searchVehicles,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            _buildFilterDropdown(),
            SizedBox(width: 16),
            _buildSortDropdown(),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
              onPressed: () {
                setState(() {
                  _sortAscending = !_sortAscending;
                  _sortVehicles();
                });
              },
            ),
            Spacer(),
            Flexible(
              child: Text(
                '${_searchResults.length} found',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Narrow screen filters (mobile)
  Widget _buildNarrowScreenFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search vehicles...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: _searchVehicles,
        ),
        SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterDropdown(),
              SizedBox(width: 16),
              _buildSortDropdown(),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                    _sortVehicles();
                  });
                },
              ),
              SizedBox(width: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('${_searchResults.length} found'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return SizedBox(
      width: 150, // Fixed width to prevent overflow
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: _filterStatus,
          underline: Container(),
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 'all', child: Text('All Vehicles')),
            DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
            DropdownMenuItem(value: 'unassigned', child: Text('Available')),
          ],
          onChanged: (value) {
            setState(() {
              _filterStatus = value!;
              _filterVehicles();
              _currentPage = 1;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return SizedBox(
      width: 160, // Fixed width to prevent overflow
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: _sortBy,
          underline: Container(),
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 'make', child: Text('Sort by Make')),
            DropdownMenuItem(value: 'year', child: Text('Sort by Year')),
            DropdownMenuItem(value: 'plate', child: Text('Sort by Plate')),
            DropdownMenuItem(
                value: 'instructor', child: Text('Sort by Instructor')),
          ],
          onChanged: (value) {
            setState(() {
              _sortBy = value!;
              _sortVehicles();
            });
          },
        ),
      ),
    );
  }

  Widget _buildListView() {
    final vehicles = _getPaginatedVehicles();

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ListView.separated(
              itemCount: vehicles.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return _buildVehicleListTile(vehicle);
              },
            ),
          ),
        ),
        _buildPagination(),
      ],
    );
  }

  Widget _buildVehicleListTile(Fleet vehicle) {
    final isSelected = _selectedVehicles.contains(vehicle.id);
    final instructorName = _getInstructorName(vehicle.instructor);
    final isAssigned = vehicle.instructor != 0;
    final currentYear = DateTime.now().year;
    final vehicleAge = currentYear - int.parse(vehicle.modelYear);

    return ListTile(
      leading: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isMultiSelectionActive)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleVehicleSelection(vehicle.id!),
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isAssigned ? Colors.blue[100] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: isAssigned ? Colors.blue[600] : Colors.grey[600],
                ),
              ),
            ],
          );
        },
      ),
      title: Text(
        '${vehicle.make} ${vehicle.model}',
        style: TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plate: ${vehicle.carPlate} • Year: ${vehicle.modelYear}',
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAssigned ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAssigned ? 'Assigned' : 'Available',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          isAssigned ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                ),
                if (vehicleAge > 10) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Old',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.red[800],
                      ),
                    ),
                  ),
                ] else if (vehicleAge > 5) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Aging',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
                SizedBox(width: 8),
                Text(
                  'Instructor: $instructorName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'edit':
              final result = await Get.dialog<bool>(
                FleetFormDialog(vehicle: vehicle),
              );
              if (result == true) {
                _loadVehicles();
              }
              break;
            case 'assign':
              _assignInstructor(vehicle);
              break;
            case 'delete':
              _deleteVehicle(vehicle);
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'assign',
            child: Row(
              children: [
                Icon(Icons.assignment_ind, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isAssigned ? 'Reassign' : 'Assign Instructor',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FleetDetailsScreen(fleetId: vehicle.id!),
          ),
        );
      },
      onLongPress: () => _toggleVehicleSelection(vehicle.id!),
    );
  }

  Widget _buildRecommendationsView() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Recommendations',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            'AI-powered insights to optimize your vehicle fleet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: MediaQuery.of(context).size.width > 600 ? 14 : 12,
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: _recommendations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No recommendations at this time',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Your fleet management is optimized!',
                          style: TextStyle(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _recommendations.length,
                    itemBuilder: (context, index) {
                      final recommendation = _recommendations[index];
                      return _buildRecommendationCard(recommendation);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    Color cardColor;
    switch (recommendation['type']) {
      case 'warning':
        cardColor = Colors.orange[50]!;
        break;
      case 'success':
        cardColor = Colors.green[50]!;
        break;
      case 'info':
        cardColor = Colors.blue[50]!;
        break;
      default:
        cardColor = Colors.grey[50]!;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: recommendation['onTap'],
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: recommendation['color'].withOpacity(0.3)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  children: [
                    Icon(
                      recommendation['icon'],
                      size: 32,
                      color: recommendation['color'],
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recommendation['title'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            recommendation['description'],
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: recommendation['onTap'],
                      style: ElevatedButton.styleFrom(
                        backgroundColor: recommendation['color'],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(recommendation['action']),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          recommendation['icon'],
                          size: 32,
                          color: recommendation['color'],
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            recommendation['title'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      recommendation['description'],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: recommendation['onTap'],
                        style: ElevatedButton.styleFrom(
                          backgroundColor: recommendation['color'],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(recommendation['action']),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_searchResults.length / _rowsPerPage).ceil();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return Row(
              children: [
                Flexible(
                  child: Text(
                    'Showing ${((_currentPage - 1) * _rowsPerPage) + 1}-${(_currentPage * _rowsPerPage).clamp(0, _searchResults.length)} of ${_searchResults.length}',
                    style: TextStyle(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                ),
                Text('$_currentPage of $totalPages'),
                IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages ? _goToNextPage : null,
                ),
                SizedBox(width: 16),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: [6, 12, 24, 48].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value per page'),
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
            );
          } else {
            return Column(
              children: [
                Text(
                  'Page $_currentPage of $totalPages',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left),
                      onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                    ),
                    Text('$_currentPage of $totalPages'),
                    IconButton(
                      icon: Icon(Icons.chevron_right),
                      onPressed:
                          _currentPage < totalPages ? _goToNextPage : null,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: [6, 12, 24, 48].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value per page'),
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
            );
          }
        },
      ),
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(stat['icon'], color: stat['color'], size: 24),
                  Spacer(),
                  Text(
                    stat['value'],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                stat['title'],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                stat['subtitle'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Fleet> _getPaginatedVehicles() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= _searchResults.length) {
      return [];
    }
    return _searchResults.sublist(startIndex,
        endIndex > _searchResults.length ? _searchResults.length : endIndex);
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _selectedVehicles.clear();
        _isMultiSelectionActive = false;
        _isAllSelected = false;
      });
    }
  }

  void _goToNextPage() {
    final totalPages = (_searchResults.length / _rowsPerPage).ceil();
    if (_currentPage < totalPages) {
      setState(() {
        _currentPage++;
        _selectedVehicles.clear();
        _isMultiSelectionActive = false;
        _isAllSelected = false;
      });
    }
  }

  void _toggleVehicleSelection(int fleetId) {
    setState(() {
      if (_selectedVehicles.contains(fleetId)) {
        _selectedVehicles.remove(fleetId);
      } else {
        _selectedVehicles.add(fleetId);
      }
      _isMultiSelectionActive = _selectedVehicles.isNotEmpty;
      _isAllSelected =
          _selectedVehicles.length == _getPaginatedVehicles().length;
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isAllSelected = value ?? false;
      if (_isAllSelected) {
        _selectedVehicles =
            _getPaginatedVehicles().map((vehicle) => vehicle.id!).toList();
      } else {
        _selectedVehicles.clear();
      }
      _isMultiSelectionActive = _selectedVehicles.isNotEmpty;
    });
  }

  void _deleteVehicle(Fleet vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Vehicle'),
        content: Text(
            'Are you sure you want to delete "${vehicle.make} ${vehicle.model}" (${vehicle.carPlate})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await fleetController.deleteFleet(vehicle.id!);
        _loadVehicles();
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Success',
          'Vehicle deleted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to delete vehicle: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  void _deleteSelectedVehicles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Selected Vehicles'),
        content: Text(
            'Are you sure you want to delete ${_selectedVehicles.length} selected vehicles?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (int fleetId in _selectedVehicles) {
          await fleetController.deleteFleet(fleetId);
        }
        setState(() {
          _selectedVehicles.clear();
          _isMultiSelectionActive = false;
          _isAllSelected = false;
        });
        _loadVehicles();
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Success',
          'Selected vehicles deleted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Error',
          'Failed to delete vehicles: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  void _assignInstructor(Fleet vehicle) {
    final availableInstructors = userController.users
        .where((u) => u.role.toLowerCase() == 'instructor')
        .where((instructor) => !_vehicles
            .any((v) => v.instructor == instructor.id && v.id != vehicle.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Instructor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select an instructor for ${vehicle.make} ${vehicle.model}:'),
            SizedBox(height: 16),
            Container(
              width: double.maxFinite,
              child: availableInstructors.isEmpty
                  ? Text('No available instructors')
                  : Column(
                      children: availableInstructors
                          .map(
                            (instructor) => ListTile(
                              title: Text(
                                  '${instructor.fname} ${instructor.lname}'),
                              subtitle: Text(instructor.email),
                              onTap: () async {
                                Navigator.pop(context);
                                await _updateVehicleInstructor(
                                    vehicle, instructor.id!);
                              },
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateVehicleInstructor(Fleet vehicle, int instructorId) async {
    try {
      final updatedVehicle = Fleet(
        id: vehicle.id,
        carPlate: vehicle.carPlate,
        make: vehicle.make,
        model: vehicle.model,
        modelYear: vehicle.modelYear,
        instructor: instructorId,
        status: vehicle.status,
        created_at: vehicle.created_at,
        updated_at: DateTime.now(),
      );

      await fleetController.handleFleet(updatedVehicle, isUpdate: true);
      _loadVehicles();

      final instructor =
          userController.users.firstWhere((u) => u.id == instructorId);
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Success',
        'Vehicle assigned to ${instructor.fname} ${instructor.lname}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Error',
        'Failed to assign instructor: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _bulkAssignInstructors() {
    Get.snackbar(
      snackPosition: SnackPosition.BOTTOM,
      'Feature Coming Soon',
      'Bulk instructor assignment will be available in the next update',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  // Recommendation action methods
  void _showUnassignedVehicles() {
    final unassignedVehicles =
        _vehicles.where((v) => v.instructor == 0).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unassigned Vehicles'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('These vehicles need instructor assignment:'),
              SizedBox(height: 16),
              ...unassignedVehicles.map((vehicle) => ListTile(
                    leading: Icon(Icons.directions_car, color: Colors.orange),
                    title: Text('${vehicle.make} ${vehicle.model}'),
                    subtitle: Text(vehicle.carPlate),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _assignInstructor(vehicle);
                      },
                      child: Text('Assign'),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showOldVehicles() {
    final currentYear = DateTime.now().year;
    final oldVehicles = _vehicles
        .where((v) => currentYear - int.parse(v.modelYear) > 10)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Aging Fleet'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('These vehicles are over 10 years old:'),
              SizedBox(height: 16),
              ...oldVehicles.map((vehicle) => ListTile(
                    leading: Icon(Icons.warning, color: Colors.red),
                    title: Text('${vehicle.make} ${vehicle.model}'),
                    subtitle: Text(
                        '${vehicle.modelYear} (${currentYear - int.parse(vehicle.modelYear)} years old)'),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.dialog(FleetFormDialog(vehicle: vehicle));
                      },
                      child: Text('Update'),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUnassignedInstructors() {
    final instructors = userController.users
        .where((u) => u.role.toLowerCase() == 'instructor')
        .toList();
    final assignedInstructorIds = _vehicles.map((v) => v.instructor).toSet();
    final unassignedInstructors = instructors
        .where((i) => !assignedInstructorIds.contains(i.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Instructors Without Vehicles'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('These instructors need vehicle assignments:'),
              SizedBox(height: 16),
              ...unassignedInstructors.map((instructor) => ListTile(
                    leading: Icon(Icons.person, color: Colors.red),
                    title: Text('${instructor.fname} ${instructor.lname}'),
                    subtitle: Text(instructor.email),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.dialog(FleetFormDialog());
                      },
                      child: Text('Add Vehicle'),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUtilizationDetails() {
    final utilizationRate = _vehicles.isNotEmpty
        ? (_vehicles.where((v) => v.instructor != 0).length /
                _vehicles.length) *
            100
        : 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fleet Utilization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: utilizationRate / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 16),
            Text(
              '${utilizationRate.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text('Fleet Utilization'),
            SizedBox(height: 16),
            Text('Excellent! Your fleet is highly utilized.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Great!'),
          ),
        ],
      ),
    );
  }

  void _showOptimizationSuggestions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fleet Optimization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggestions to improve fleet utilization:'),
            SizedBox(height: 16),
            Text('• Assign unassigned vehicles to instructors'),
            Text('• Consider selling older, unused vehicles'),
            Text('• Hire more instructors if demand is high'),
            Text('• Review vehicle maintenance schedules'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Thanks'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceSchedule() {
    final currentYear = DateTime.now().year;
    final maintenanceVehicles = _vehicles
        .where((v) => currentYear - int.parse(v.modelYear) > 5)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Maintenance Planning'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Vehicles that may need increased maintenance:'),
              SizedBox(height: 16),
              ...maintenanceVehicles.map((vehicle) => ListTile(
                    leading: Icon(Icons.build, color: Colors.grey),
                    title: Text('${vehicle.make} ${vehicle.model}'),
                    subtitle: Text(
                        '${currentYear - int.parse(vehicle.modelYear)} years old'),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
