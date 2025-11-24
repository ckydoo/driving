import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/billing/student_invoice.dart';
import 'package:driving/screens/payments/bulk_payments.dart';
import 'package:driving/widgets/create_invoice_dialog.dart';
import 'package:driving/widgets/payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({Key? key}) : super(key: key);

  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with SingleTickerProviderStateMixin {
  final BillingController billingController = Get.find();
  final UserController userController = Get.find();
  final TextEditingController _searchController = TextEditingController();

  List<User> _students = [];
  List<User> _searchResults = [];
  List<int> _selectedStudents = [];
  bool _isMultiSelectionActive = false;
  bool _isAllSelected = false;
  bool _isLoading = true;

  // Filter states
  String _selectedFilter = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;

  // Pagination
  int _currentPage = 1;
  int _rowsPerPage = 10;

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadBillingData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBillingData() async {
    setState(() => _isLoading = true);

    try {
      await userController.fetchUsers();
      await billingController.fetchBillingData();

      setState(() {
        _students = userController.users.where((user) {
          return user.role.toLowerCase() == 'student' &&
              user.status.toLowerCase() == 'active' &&
              billingController.invoices
                  .any((invoice) => invoice.studentId == user.id);
        }).toList();

        _applyFiltersAndSort();
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Failed to load billing data');
    }
  }

  void _applyFiltersAndSort() {
    List<User> filteredStudents = List.from(_students);

    // Apply filters
    if (_selectedFilter != 'all') {
      filteredStudents = filteredStudents.where((student) {
        final balance = _getStudentBalance(student);
        switch (_selectedFilter) {
          case 'outstanding':
            return balance > 0;
          case 'paid':
            return balance <= 0;
          default:
            return true;
        }
      }).toList();
    }

    // Apply sorting
    filteredStudents.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison =
              '${a.fname} ${a.lname}'.compareTo('${b.fname} ${b.lname}');
          break;
        case 'balance':
          comparison = _getStudentBalance(a).compareTo(_getStudentBalance(b));
          break;
        case 'invoices':
          comparison =
              _getStudentInvoiceCount(a).compareTo(_getStudentInvoiceCount(b));
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _searchResults = filteredStudents;
      _currentPage = 1; // Reset to first page when filters change
    });
  }

  void _searchStudents(String query) {
    if (query.isEmpty) {
      _applyFiltersAndSort();
      return;
    }

    final results = _students
        .where((student) =>
            student.fname.toLowerCase().contains(query.toLowerCase()) ||
            student.lname.toLowerCase().contains(query.toLowerCase()))
        .toList();

    setState(() {
      _searchResults = results;
      _currentPage = 1;
    });
  }

  double _getStudentBalance(User student) {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();

    double totalAmount = 0;
    double totalPaid = 0;

    for (var invoice in studentInvoices) {
      totalAmount += invoice.totalAmountCalculated;
      totalPaid += invoice.amountPaid;
    }

    return totalAmount - totalPaid;
  }

  int _getStudentInvoiceCount(User student) {
    return billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .length;
  }

  void _toggleStudentSelection(int studentId) {
    setState(() {
      if (_selectedStudents.contains(studentId)) {
        _selectedStudents.remove(studentId);
      } else {
        _selectedStudents.add(studentId);
      }
      _isMultiSelectionActive = _selectedStudents.isNotEmpty;
      _isAllSelected =
          _selectedStudents.length == _getPaginatedStudents().length;
    });
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _isAllSelected = value;
      final paginatedStudents = _getPaginatedStudents();
      if (value) {
        for (var student in paginatedStudents) {
          if (!_selectedStudents.contains(student.id)) {
            _selectedStudents.add(student.id!);
          }
        }
      } else {
        for (var student in paginatedStudents) {
          _selectedStudents.remove(student.id);
        }
      }
      _isMultiSelectionActive = _selectedStudents.isNotEmpty;
    });
  }

  List<User> _getPaginatedStudents() {
    final students = _searchResults.isNotEmpty ? _searchResults : _students;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= students.length) return [];
    return students.sublist(
        startIndex, endIndex > students.length ? students.length : endIndex);
  }

  int _getTotalPages() {
    final students = _searchResults.isNotEmpty ? _searchResults : _students;
    return (students.length / _rowsPerPage).ceil();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 768;
          final isMobile = constraints.maxWidth < 600;

          return _isLoading
              ? _buildLoadingState()
              : _buildMainContent(constraints, isTablet, isMobile);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading billing data...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMainContent(
      BoxConstraints constraints, bool isTablet, bool isMobile) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(isMobile),
            _buildSummaryCards(isTablet, isMobile),
            _buildFiltersAndSearch(isMobile),
            // Replace Expanded with a Container with calculated height
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight -
                    400, // Adjust based on header + cards height
              ),
              child: isMobile
                  ? _buildMobileView()
                  : _buildDataTableAlternative(constraints),
            ),
            if (_isMultiSelectionActive) _buildBulkActions(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long,
                        size: 24, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Billing Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildHeaderActions(isMobile),
              ],
            )
          : Row(
              children: [
                Icon(Icons.receipt_long, size: 32, color: Colors.blue.shade700),
                const SizedBox(width: 16),
                const Text(
                  'Billing Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                _buildHeaderActions(isMobile),
              ],
            ),
    );
  }

  Widget _buildHeaderActions(bool isMobile) {
    if (isMobile) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _loadBillingData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.grey.shade700,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showCreateInvoiceDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _loadBillingData,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: Colors.grey.shade700,
            elevation: 0,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _showCreateInvoiceDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Create Invoice'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(bool isTablet, bool isMobile) {
    double totalOutstanding = 0;
    double totalPaid = 0;
    int studentsWithBalance = 0;

    for (var student in _students) {
      final balance = _getStudentBalance(student);
      if (balance > 0) {
        totalOutstanding += balance;
        studentsWithBalance++;
      }

      final studentInvoices = billingController.invoices
          .where((invoice) => invoice.studentId == student.id);
      for (var invoice in studentInvoices) {
        totalPaid += invoice.amountPaid;
      }
    }

    final cards = [
      _buildSummaryCard(
        'Total Outstanding',
        '\$${totalOutstanding.toStringAsFixed(2)}',
        Icons.trending_up,
        Colors.red.shade600,
        isMobile,
      ),
      _buildSummaryCard(
        'Total Collected',
        '\$${totalPaid.toStringAsFixed(2)}',
        Icons.attach_money,
        Colors.green.shade600,
        isMobile,
      ),
      _buildSummaryCard(
        'Students with Balance',
        '$studentsWithBalance',
        Icons.people,
        Colors.orange.shade600,
        isMobile,
      ),
      _buildSummaryCard(
        'Total Students',
        '${_students.length}',
        Icons.school,
        Colors.blue.shade600,
        isMobile,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: isMobile
          ? Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 8),
                      Expanded(child: cards[1]),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: 8),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ),
              ],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...cards
                      .map((card) => [
                            Expanded(child: card),
                            if (card != cards.last) const SizedBox(width: 16),
                          ])
                      .expand((x) => x),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isMobile ? 20 : 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isMobile ? 12 : 16),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 11 : 14,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 16,
      ),
      child: isMobile
          ? Column(
              children: [
                // Search bar takes full width on mobile
                _buildSearchBar(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildFilterDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSortDropdown()),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                // Constrain search bar width on larger screens
                Expanded(flex: 3, child: _buildSearchBar()),
                const SizedBox(width: 16),
                // Fixed width for dropdowns
                SizedBox(width: 180, child: _buildFilterDropdown()),
                const SizedBox(width: 16),
                SizedBox(width: 180, child: _buildSortDropdown()),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _searchStudents,
        decoration: InputDecoration(
          hintText: 'Search students...',
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchStudents('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          onChanged: (String? newValue) {
            setState(() {
              _selectedFilter = newValue!;
              _applyFiltersAndSort();
            });
          },
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Students')),
            DropdownMenuItem(
                value: 'outstanding', child: Text('Outstanding Balance')),
            DropdownMenuItem(value: 'paid', child: Text('Paid Up')),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                onChanged: (String? newValue) {
                  setState(() {
                    _sortBy = newValue!;
                    _applyFiltersAndSort();
                  });
                },
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('Name')),
                  DropdownMenuItem(value: 'balance', child: Text('Balance')),
                  DropdownMenuItem(value: 'invoices', child: Text('Invoices')),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
            ),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _applyFiltersAndSort();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    final paginatedStudents = _getPaginatedStudents();

    if (paginatedStudents.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ...paginatedStudents
              .map((student) => _buildMobileStudentCard(student)),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildMobileStudentCard(User student) {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();

    double totalAmount = 0;
    double totalPaid = 0;

    for (var invoice in studentInvoices) {
      totalAmount += invoice.totalAmountCalculated;
      totalPaid += invoice.amountPaid;
    }

    final totalBalance = totalAmount - totalPaid;
    final isSelected = _selectedStudents.contains(student.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Get.to(() => StudentInvoiceScreen(student: student)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) =>
                        _toggleStudentSelection(student.id!),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '${student.fname[0]}${student.lname[0]}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${student.fname} ${student.lname}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          student.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildMobileInfoItem(
                        'Invoices',
                        '${studentInvoices.length}',
                        Colors.blue.shade600,
                      ),
                    ),
                    Expanded(
                      child: _buildMobileInfoItem(
                        'Total',
                        '\$${totalAmount.toStringAsFixed(2)}',
                        Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildMobileInfoItem(
                        'Paid',
                        '\$${totalPaid.toStringAsFixed(2)}',
                        Colors.green.shade600,
                      ),
                    ),
                    Expanded(
                      child: _buildMobileInfoItem(
                        'Balance',
                        '\$${totalBalance.toStringAsFixed(2)}',
                        totalBalance > 0
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (totalBalance > 0) {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showPaymentDialog(
                                context, studentInvoices, student),
                            icon: const Icon(Icons.payment, size: 18),
                            label: const Text('Pay'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Get.to(
                                () => StudentInvoiceScreen(student: student)),
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Get.to(
                            () => StudentInvoiceScreen(student: student)),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('View Details'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(BoxConstraints constraints) {
    final paginatedStudents = _getPaginatedStudents();

    if (paginatedStudents.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildTableHeader(constraints),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minWidth: constraints.maxWidth - 48),
                child: ListView.builder(
                  itemCount: paginatedStudents.length,
                  itemBuilder: (context, index) {
                    return _buildDataRow(
                        paginatedStudents[index], index, constraints);
                  },
                ),
              ),
            ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BoxConstraints constraints) {
    final minWidth =
        constraints.maxWidth > 1200 ? constraints.maxWidth - 48 : 1200.0;

    return Container(
      width: minWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Checkbox(
              value: _isAllSelected,
              onChanged: (bool? value) => _toggleSelectAll(value!),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'Student Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Invoices',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Total Amount',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Paid',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Balance',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(User student, int index, BoxConstraints constraints) {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == student.id)
        .toList();

    double totalAmount = 0;
    double totalPaid = 0;

    for (var invoice in studentInvoices) {
      totalAmount += invoice.totalAmountCalculated;
      totalPaid += invoice.amountPaid;
    }

    final totalBalance = totalAmount - totalPaid;
    final isSelected = _selectedStudents.contains(student.id);
    final minWidth =
        constraints.maxWidth > 1200 ? constraints.maxWidth - 48 : 1200.0;

    return Container(
      width: minWidth,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.shade50
            : (index % 2 == 0 ? Colors.grey.shade50 : Colors.white),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: InkWell(
        onTap: () => Get.to(() => StudentInvoiceScreen(student: student)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) =>
                      _toggleStudentSelection(student.id!),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        '${student.fname[0]}${student.lname[0]}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${student.fname} ${student.lname}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            student.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${studentInvoices.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    if (studentInvoices.isNotEmpty)
                      Text(
                        'Latest: ${studentInvoices.last.invoiceNumber}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '\$${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '\$${totalPaid.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: totalBalance > 0
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\$${totalBalance.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: totalBalance > 0
                          ? Colors.red.shade600
                          : Colors.green.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: LayoutBuilder(
                  builder: (context, actionConstraints) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (totalBalance > 0)
                          Flexible(
                            child: SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: () => _showPaymentDialog(
                                    context, studentInvoices, student),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  elevation: 0,
                                  minimumSize: const Size(50, 32),
                                ),
                                child: const Text(
                                  'Pay',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ),
                        if (totalBalance > 0) const SizedBox(width: 4),
                        SizedBox(
                          width: 36,
                          height: 32,
                          child: IconButton(
                            onPressed: () => Get.to(
                                () => StudentInvoiceScreen(student: student)),
                            icon: const Icon(Icons.visibility, size: 16),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActions(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedStudents.length} students selected',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _selectedStudents.clear();
                              _isMultiSelectionActive = false;
                              _isAllSelected = false;
                            }),
                            child: const Text('Clear Selection'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _handleBulkPayment(),
                            icon: const Icon(Icons.payment, size: 18),
                            label: const Text('Bulk Payment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Text(
                    '${_selectedStudents.length} students selected',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedStudents.clear();
                      _isMultiSelectionActive = false;
                      _isAllSelected = false;
                    }),
                    child: const Text('Clear Selection'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _handleBulkPayment(),
                    icon: const Icon(Icons.payment),
                    label: const Text('Bulk Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showPaymentDialog(
      BuildContext context, List<Invoice> studentInvoices, User student) {
    // Calculate total outstanding balance for all unpaid invoices
    List<Invoice> unpaidInvoices = studentInvoices.where((invoice) {
      double invoiceBalance =
          invoice.totalAmountCalculated - invoice.amountPaid;
      return invoiceBalance > 0;
    }).toList();

    if (unpaidInvoices.isEmpty) {
      _showErrorSnackbar('No outstanding balance for this student');
      return;
    }

    // Sort unpaid invoices by date (oldest first) to prioritize payment order
    unpaidInvoices.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PaymentDialog(
          availableInvoices: unpaidInvoices, // Lets user choose
          studentName: '${student.fname} ${student.lname}',
          studentId: student.id!,
          // If PaymentDialog supports additional parameters, add them here
        );
      },
    ).then((_) {
      // Refresh data after payment dialog closes
      _loadBillingData();
    });
  }

  void _showCreateInvoiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const CreateInvoiceDialog();
      },
    ).then((_) {
      // Refresh data after invoice creation
      _loadBillingData();
    });
  }

  void _handleBulkPayment() {
    if (_selectedStudents.isEmpty) {
      _showErrorSnackbar('No students selected for bulk payment');
      return;
    }

    // Get all selected students with their outstanding invoices
    List<Map<String, dynamic>> selectedStudentsData = [];
    double totalBulkAmount = 0;

    for (int studentId in _selectedStudents) {
      final student = _students.firstWhere((s) => s.id == studentId);
      final studentInvoices = billingController.invoices
          .where((invoice) => invoice.studentId == studentId)
          .toList();

      double studentBalance = _getStudentBalance(student);

      if (studentBalance > 0) {
        selectedStudentsData.add({
          'student': student,
          'invoices': studentInvoices,
          'balance': studentBalance,
        });
        totalBulkAmount += studentBalance;
      }
    }

    if (selectedStudentsData.isEmpty) {
      _showErrorSnackbar('Selected students have no outstanding balance');
      return;
    }

    _showBulkPaymentDialog(selectedStudentsData, totalBulkAmount);
  }

  void _showBulkPaymentDialog(
      List<Map<String, dynamic>> studentsData, double totalAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BulkPaymentDialog(
          studentsData: studentsData,
          totalAmount: totalAmount,
          onPaymentComplete: () {
            _loadBillingData();
            setState(() {
              _selectedStudents.clear();
              _isMultiSelectionActive = false;
              _isAllSelected = false;
            });
          },
        );
      },
    );
  }

  Widget _buildPagination() {
    final totalPages = _getTotalPages();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed:
                _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Page $_currentPage of $totalPages',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Students Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no students with billing records to display.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadBillingData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTableAlternative(BoxConstraints constraints) {
    final paginatedStudents = _getPaginatedStudents();

    if (paginatedStudents.isEmpty) {
      return _buildEmptyState();
    }

    final tableWidth =
        constraints.maxWidth > 1200 ? constraints.maxWidth - 48 : 1200.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildTableHeader(constraints),
          // Remove Expanded and ListView, use Column directly
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: tableWidth,
              child: Column(
                children: paginatedStudents.asMap().entries.map((entry) {
                  return _buildDataRow(entry.value, entry.key, constraints);
                }).toList(),
              ),
            ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }
}
