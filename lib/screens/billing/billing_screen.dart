import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/billing/student_invoice.dart';
import 'package:driving/widgets/create_invoice_dialog.dart';
import 'package:driving/widgets/payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({Key? key}) : super(key: key);

  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final BillingController billingController = Get.find();
  final UserController userController = Get.find();
  final TextEditingController _searchController = TextEditingController();
  List<User> _students = [];
  List<User> _searchResults = [];
  List<int> _selectedStudents = []; // Track selected students
  bool _isMultiSelectionActive = false; // Track if multi-selection is active
  bool _isAllSelected = false; // Track if all students are selected

  // Pagination variables
  int _currentPage = 1;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  Future<void> _loadBillingData() async {
    await userController.fetchUsers();
    await billingController.fetchBillingData();

    setState(() {
      _students = userController.users.where((user) {
        if (user.role.toLowerCase() != 'student') {
          return false; // Exclude non-students immediately
        }
        if (user.status.toLowerCase() != 'active') {
          return false; // Exclude inactive students
        }
        // Check if there's an invoice for this student
        return billingController.invoices
            .any((invoice) => invoice.studentId == user.id);
      }).toList();
    });
  }

  void _searchStudents(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    final results = _students
        .where((student) =>
            student.fname.toLowerCase().contains(query.toLowerCase()) ||
            student.lname.toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      _searchResults = results;
    });
  }

  void _toggleStudentSelection(int studentId) {
    setState(() {
      if (_selectedStudents.contains(studentId)) {
        _selectedStudents.remove(studentId);
      } else {
        _selectedStudents.add(studentId);
      }
      _isMultiSelectionActive = _selectedStudents.isNotEmpty;
      _isAllSelected = _selectedStudents.length == _students.length;
    });
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _isAllSelected = value;
      _selectedStudents =
          value ? _students.map((student) => student.id!).toList() : [];
      _isMultiSelectionActive = _selectedStudents.isNotEmpty;
    });
  }

  List<User> _getPaginatedStudents() {
    final students = _searchResults.isNotEmpty ? _searchResults : _students;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= students.length) {
      return [];
    }
    return students.sublist(
        startIndex, endIndex > students.length ? students.length : endIndex);
  }

  int _getTotalPages() {
    final students = _searchResults.isNotEmpty ? _searchResults : _students;
    return (students.length / _rowsPerPage).ceil();
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
    final students = _getPaginatedStudents();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payments & Invoices ',
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
              _loadBillingData();
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
                      hintText: 'Search students...',
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
                    onChanged: _searchStudents,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (billingController.isLoading.value ||
            userController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_students.isEmpty && _searchController.text.isEmpty) {
          return const Center(child: Text('No students found'));
        }

        return _buildStudentList(students);
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
              backgroundColor: Colors.blue.shade800,
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () => Get.dialog(const CreateInvoiceDialog()),
            ),
    );
  }

  Widget _buildStudentList(List<User> students) {
    if (students.isEmpty) {
      return const Center(child: Text('No matching students found'));
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
              child: ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return _buildDataRow(student, index);
                },
              ),
            ),
          ),
          _buildPagination(),
        ],
      );
    }
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
            flex: 3,
            child: Text(
              'Student Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Invoices',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Total Amount',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Paid',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Balance',
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

  Widget _buildDataRow(User student, int index) {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();

    double totalAmount = 0;
    double totalPaid = 0;
    double totalBalance = 0;
    double totalLessons = 0;
    for (var invoice in studentInvoices) {
      totalAmount += invoice.totalAmountCalculated;
      totalPaid += invoice.amountPaid;
      totalBalance = totalAmount - totalPaid;
      totalLessons += invoice.lessons;
    }

    return Container(
      color: index % 2 == 0 ? Colors.grey.shade100 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: InkWell(
          onTap: () {
            Get.to(() => StudentInvoiceScreen(student: student));
          },
          child: Row(
            children: [
              Checkbox(
                value: _selectedStudents.contains(student.id),
                onChanged: (bool? value) {
                  _toggleStudentSelection(student.id!);
                },
              ),
              Expanded(
                flex: 3,
                child: Text('${student.fname} ${student.lname}'),
              ),
              Expanded(
                flex: 2,
                child: Text('${studentInvoices.length}'),
              ),
              Expanded(
                flex: 2,
                child: Text('\$${totalAmount.toStringAsFixed(2)}'),
              ),
              Expanded(
                flex: 2,
                child: Text('\$${totalPaid.toStringAsFixed(2)}'),
              ),
              Expanded(
                flex: 2,
                child: Text('\$${totalBalance.toStringAsFixed(2)}'),
              ),
              if (studentInvoices.any((invoice) => invoice.balance > 0))
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () =>
                        _showPaymentDialog(context, studentInvoices, student),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.blue.shade700, // A prominent background color
                      foregroundColor: Colors.white, // Text color
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12), // Padding
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w500), // Bold text
                      shape: RoundedRectangleBorder(
                        // Rounded corners
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 5, // A subtle shadow
                      shadowColor: Colors.blue.shade900, // Shadow color
                    ),
                    child: const Text('Add Payment'),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog(
      BuildContext context, List<Invoice> studentInvoices, User student) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PaymentDialog(
            invoice: studentInvoices.first,
            studentName:
                '${student.fname} ${student.lname}'); // Assuming we pay the first invoice
      },
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

  void _showMultiDeleteConfirmationDialog() {
    Get.defaultDialog(
      title: 'Confirm Multi-Delete',
      content: Text(
          'Are you sure you want to delete the selected ${_selectedStudents.length} students?'),
      confirm: TextButton(
        onPressed: () {
          _selectedStudents.forEach((id) {
            userController.deleteUser(id);
          });
          _toggleSelectAll(false);
          _loadBillingData();
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
