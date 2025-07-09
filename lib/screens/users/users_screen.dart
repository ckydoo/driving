import 'dart:io';
import 'package:csv/csv.dart';
import 'package:driving/screens/users/student_details_screen.dart';
import 'package:driving/screens/users/user_form_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/user_controller.dart';
import '../../models/user.dart';
import 'package:driving/screens/users/instructor_details_screen.dart';

class UsersScreen extends StatefulWidget {
  final String role;

  const UsersScreen({Key? key, required this.role}) : super(key: key);

  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UserController controller = Get.find<UserController>();
  late Future<List<User>> _usersFuture;
  final TextEditingController _searchController = TextEditingController();
  List<User> _users = [];
  List<User> _searchResults = [];
  List<int> _selectedUsers = [];
  bool _isMultiSelectionActive = false;
  bool _isAllSelected = false;

  // Pagination variables
  int _currentPage = 1;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    _usersFuture = controller.fetchUsers(role: widget.role);
    final users = await _usersFuture;
    setState(() {
      _users = users;
    });
  }

  void _searchUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    final results = _users
        .where((user) =>
            user.fname.toLowerCase().contains(query.toLowerCase()) ||
            user.lname.toLowerCase().contains(query.toLowerCase()) ||
            user.email.toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      _searchResults = results;
    });
  }

  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUsers.contains(userId)) {
        _selectedUsers.remove(userId);
      } else {
        _selectedUsers.add(userId);
      }
      _isMultiSelectionActive = _selectedUsers.isNotEmpty;
      _isAllSelected = _selectedUsers.length == _users.length;
    });
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _isAllSelected = value;
      _selectedUsers = value ? _users.map((user) => user.id!).toList() : [];
      _isMultiSelectionActive = _selectedUsers.isNotEmpty;
    });
  }

  // Calculate the list of users to display on the current page
  List<User> _getPaginatedUsers() {
    final users = _searchResults.isNotEmpty ? _searchResults : _users;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= users.length) {
      return [];
    }
    return users.sublist(
        startIndex, endIndex > users.length ? users.length : endIndex);
  }

  int _getTotalPages() {
    final users = _searchResults.isNotEmpty ? _searchResults : _users;
    return (users.length / _rowsPerPage).ceil();
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
    final users = _getPaginatedUsers();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.role.capitalize!} Management',
          style: const TextStyle(
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
              _loadUsers();
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
                      hintText: 'Search ${widget.role.capitalize!}...',
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
                    onChanged: _searchUsers,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No ${widget.role} found'));
          } else {
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
                    child: _searchController.text.isNotEmpty &&
                            _searchResults.isEmpty
                        ? Center(child: Text('No ${widget.role} found'))
                        : ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return _buildDataRow(user, index);
                            },
                          ),
                  ),
                ),
                _buildPagination(),
              ],
            );
          }
        },
      ),
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
              onPressed: () => Get.dialog(UserFormDialog(role: widget.role)),
            ),
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
              'Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800, // Updated header color
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Phone',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800, // Updated header color
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800, // Updated header color
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800, // Updated header color
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(User user, int index) {
    return Container(
      color: index % 2 == 0 ? Colors.grey.shade100 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: InkWell(
          onTap: () {
            if (widget.role == 'student') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      StudentDetailsScreen(studentId: user.id!),
                ),
              );
            } else if (widget.role == 'instructor') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      InstructorDetailsScreen(instructorId: user.id!),
                ),
              );
            }
          },
          child: Row(
            children: [
              Checkbox(
                value: _selectedUsers.contains(user.id),
                onChanged: (bool? value) {
                  _toggleUserSelection(user.id!);
                },
              ),
              Expanded(flex: 2, child: Text('${user.fname} ${user.lname}')),
              Expanded(flex: 2, child: Text(user.phone)),
              Expanded(flex: 1, child: Text(user.status)),
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => Get.dialog(
                        UserFormDialog(user: user, role: widget.role),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteConfirmationDialog(user.id!);
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
                _currentPage = 1; // Reset to the first page
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
      content: const Text('Are you sure you want to delete this user?'),
      confirm: TextButton(
        onPressed: () {
          controller.deleteUser(id);
          _loadUsers();
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
          'Are you sure you want to delete the selected ${_selectedUsers.length} users?'),
      confirm: TextButton(
        onPressed: () {
          _selectedUsers.forEach((id) {
            controller.deleteUser(id);
          });
          _toggleSelectAll(false);
          _loadUsers();
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
      title: 'Export Users',
      content: const Text('Export the current list of users to a CSV file.'),
      confirm: TextButton(
        onPressed: () async {
          // Convert user data to CSV
          final csvData = const ListToCsvConverter().convert(
            [
              ['Name', 'Email', 'Status'], // Header row
              ..._users.map((user) => [
                    '${user.fname} ${user.lname}',
                    user.email,
                    user.status,
                  ]),
            ],
          );
          // Sanitize file name
          final timestamp = DateTime.now()
              .toIso8601String()
              .replaceAll(RegExp(r'[:\.]'), '_');
          final fileName = 'users_export_$timestamp.csv';
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
              content: Text('User data exported to $filePath'),
              confirm: TextButton(
                onPressed: () {
                  Get.back(); // Close the success dialog
                  Get.back(); // Go back to the user list
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
            Get.back(); // Go back to the user list
          }
        },
        child: const Text('Export'),
      ),
      cancel: TextButton(
        onPressed: () {
          Get.back(); // Go back to the user list
        },
        child: const Text('Cancel'),
      ),
    );
  }
}
