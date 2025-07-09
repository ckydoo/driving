import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/user.dart';
import 'package:driving/widgets/payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final BillingController billingController = Get.find<BillingController>();
  final UserController userController = Get.find<UserController>();
  final TextEditingController _searchController = TextEditingController();
  List<User> _studentsWithBalance = [];
  List<User> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadUnpaidStudents();
  }

  Future<void> _loadUnpaidStudents() async {
    await userController.fetchUsers();
    await billingController.fetchBillingData();
    _filterStudentsWithBalance();
  }

  void _filterStudentsWithBalance() {
    setState(() {
      _studentsWithBalance = userController.users.where((student) {
        if (student.role.toLowerCase() != 'student') {
          return false; // Only students
        }
        final studentInvoices = billingController.invoices
            .where((invoice) => invoice.studentId == student.id)
            .toList();
        double totalBalance = 0;
        for (var invoice in studentInvoices) {
          totalBalance += invoice.balance;
        }
        return totalBalance > 0; // Only students with a balance
      }).toList();
      _searchResults =
          List.from(_studentsWithBalance); // Initialize search results
    });
  }

  void _searchStudents(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = List.from(_studentsWithBalance);
      });
      return;
    }
    final results = _studentsWithBalance
        .where((student) => "${student.fname} ${student.lname}"
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payments',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _searchStudents,
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (billingController.isLoading.value ||
            userController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final studentsToDisplay =
            _searchResults.isNotEmpty ? _searchResults : _studentsWithBalance;

        if (studentsToDisplay.isEmpty) {
          return const Center(child: Text('No students with unpaid invoices.'));
        }

        return ListView.builder(
          itemCount: studentsToDisplay.length,
          itemBuilder: (context, index) {
            final student = studentsToDisplay[index];
            return _buildStudentPaymentCard(student);
          },
        );
      }),
    );
  }

  Widget _buildStudentPaymentCard(User student) {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();
    double totalDue = 0;
    for (var invoice in studentInvoices) {
      totalDue += invoice.balance;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        title: Text(
          '${student.fname} ${student.lname}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Total Due: \$${totalDue.toStringAsFixed(2)}'),
        trailing: ElevatedButton(
          onPressed: () => _showPaymentDialog(context, studentInvoices),
          child: const Text('Pay'),
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, List<Invoice> studentInvoices) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PaymentDialog(
            invoice:
                studentInvoices.first); // Assuming we pay the first invoice
      },
    );
  }
}
