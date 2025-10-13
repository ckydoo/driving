import 'package:csv/csv.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/models/course.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/user.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/services/print_service.dart';
import 'package:driving/widgets/payment_dialog.dart';
import 'package:driving/services/receipt_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:printing/printing.dart';

class StudentInvoiceScreen extends StatefulWidget {
  final User student;

  const StudentInvoiceScreen({Key? key, required this.student})
      : super(key: key);

  @override
  _StudentInvoiceScreenState createState() => _StudentInvoiceScreenState();
}

class _StudentInvoiceScreenState extends State<StudentInvoiceScreen>
    with SingleTickerProviderStateMixin {
  final BillingController billingController = Get.find();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _dbHelper = DatabaseHelper.instance;

  String _selectedFilter = 'all';
  String _sortBy = 'date';
  bool _sortAscending = false;
  bool _isLoading = true;

  List<Invoice> _filteredInvoices = [];

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
    _initializeData();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await billingController.fetchBillingData();
      _applyFiltersAndSort();
      setState(() => _isLoading = false);
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Failed to load invoice data');
    }
  }

  void _applyFiltersAndSort() {
    List<Invoice> invoices = billingController.invoices
        .where((invoice) => invoice.studentId == widget.student.id)
        .toList();

    // Apply filters
    switch (_selectedFilter) {
      case 'outstanding':
        invoices = invoices.where((invoice) => invoice.balance > 0).toList();
        break;
      case 'paid':
        invoices = invoices.where((invoice) => invoice.balance <= 0).toList();
        break;
      case 'overdue':
        invoices = invoices
            .where((invoice) =>
                invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now()))
            .toList();
        break;
    }

    // Apply sorting
    invoices.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'date':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'amount':
          comparison =
              a.totalAmountCalculated.compareTo(b.totalAmountCalculated);
          break;
        case 'balance':
          comparison = a.balance.compareTo(b.balance);
          break;
        case 'dueDate':
          comparison = a.dueDate.compareTo(b.dueDate);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredInvoices = invoices;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading ? _buildLoadingState() : _buildMainContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading invoices...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildStudentSummary()),
          SliverToBoxAdapter(child: _buildFiltersAndSort()),
          _filteredInvoices.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyState())
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildInvoiceCard(_filteredInvoices[index], index);
                    },
                    childCount: _filteredInvoices.length,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          '${widget.student.fname} ${widget.student.lname}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade600,
                Colors.blue.shade800,
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'export':
                _exportAllInvoices();
                break;
              case 'statement':
                _generateStatement();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.file_download),
                  SizedBox(width: 8),
                  Text('Export All'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'statement',
              child: Row(
                children: [
                  Icon(Icons.description),
                  SizedBox(width: 8),
                  Text('Generate Statement'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentSummary() {
    double totalAmount = 0;
    double totalPaid = 0;
    double totalBalance = 0;
    int overdueCount = 0;

    for (var invoice in _filteredInvoices) {
      totalAmount += invoice.totalAmountCalculated;
      totalPaid += invoice.amountPaid;
      totalBalance += invoice.balance;
      if (invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now())) {
        overdueCount++;
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with student info
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                // Mobile layout - stack vertically
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            '${widget.student.fname[0]}${widget.student.lname[0]}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.student.fname} ${widget.student.lname}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.student.email,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (totalBalance > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: overdueCount > 0
                              ? Colors.red.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: overdueCount > 0
                                ? Colors.red.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          overdueCount > 0 ? 'OVERDUE' : 'OUTSTANDING',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: overdueCount > 0
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              } else {
                // Desktop layout - side by side
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        '${widget.student.fname[0]}${widget.student.lname[0]}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.student.fname} ${widget.student.lname}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.student.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (totalBalance > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: overdueCount > 0
                              ? Colors.red.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: overdueCount > 0
                                ? Colors.red.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          overdueCount > 0 ? 'OVERDUE' : 'OUTSTANDING',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: overdueCount > 0
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),
          // Summary items - responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                // Mobile: 2x2 grid
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryItem(
                            'Total Invoiced',
                            '\$${totalAmount.toStringAsFixed(2)}',
                            Icons.receipt,
                            Colors.blue.shade600,
                          ),
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Total Paid',
                            '\$${totalPaid.toStringAsFixed(2)}',
                            Icons.check_circle,
                            Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryItem(
                            'Outstanding',
                            '\$${totalBalance.toStringAsFixed(2)}',
                            Icons.pending,
                            totalBalance > 0
                                ? Colors.red.shade600
                                : Colors.green.shade600,
                          ),
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Total Invoices',
                            '${_filteredInvoices.length}',
                            Icons.description,
                            Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Desktop: single row
                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        'Total Invoiced',
                        '\$${totalAmount.toStringAsFixed(2)}',
                        Icons.receipt,
                        Colors.blue.shade600,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        'Total Paid',
                        '\$${totalPaid.toStringAsFixed(2)}',
                        Icons.check_circle,
                        Colors.green.shade600,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        'Outstanding',
                        '\$${totalBalance.toStringAsFixed(2)}',
                        Icons.pending,
                        totalBalance > 0
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        'Total Invoices',
                        '${_filteredInvoices.length}',
                        Icons.description,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildFiltersAndSort() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            // Mobile layout - stack vertically
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilterChips(),
                const SizedBox(height: 12),
                _buildSortDropdown(),
              ],
            );
          } else {
            // Desktop layout - side by side
            return Row(
              children: [
                Expanded(child: _buildFilterChips()),
                const SizedBox(width: 16),
                _buildSortDropdown(),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All', 'icon': Icons.list},
      {'key': 'outstanding', 'label': 'Outstanding', 'icon': Icons.pending},
      {'key': 'paid', 'label': 'Paid', 'icon': Icons.check_circle},
      {'key': 'overdue', 'label': 'Overdue', 'icon': Icons.warning},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(filter['label'] as String),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['key'] as String;
                  _applyFiltersAndSort();
                });
              },
              selectedColor: Colors.blue.shade600,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
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
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortBy,
              onChanged: (String? newValue) {
                setState(() {
                  _sortBy = newValue!;
                  _applyFiltersAndSort();
                });
              },
              items: const [
                DropdownMenuItem(value: 'date', child: Text('Date')),
                DropdownMenuItem(value: 'amount', child: Text('Amount')),
                DropdownMenuItem(value: 'balance', child: Text('Balance')),
                DropdownMenuItem(value: 'dueDate', child: Text('Due Date')),
              ],
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No invoices found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or create a new invoice',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, int index) {
    final isOverdue =
        invoice.dueDate.isBefore(DateTime.now()) && invoice.balance > 0;
    final isPaid = invoice.balance <= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? Colors.red.shade200
              : isPaid
                  ? Colors.green.shade200
                  : Colors.grey.shade200,
          width: 1,
        ),
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
          _buildInvoiceHeader(invoice, isOverdue, isPaid),
          _buildInvoiceDetails(invoice),
          _buildInvoiceActions(invoice),
        ],
      ),
    );
  }

  Widget _buildInvoiceHeader(Invoice invoice, bool isOverdue, bool isPaid) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.shade50
            : isPaid
                ? Colors.green.shade50
                : Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOverdue
                  ? Colors.red.shade100
                  : isPaid
                      ? Colors.green.shade100
                      : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOverdue
                  ? Icons.warning
                  : isPaid
                      ? Icons.check_circle
                      : Icons.receipt,
              color: isOverdue
                  ? Colors.red.shade600
                  : isPaid
                      ? Colors.green.shade600
                      : Colors.blue.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice #${invoice.invoiceNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Created: ${DateFormat('MMM dd, yyyy').format(invoice.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOverdue
                  ? Colors.red.shade600
                  : isPaid
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isOverdue
                  ? 'OVERDUE'
                  : isPaid
                      ? 'PAID'
                      : 'PENDING',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetails(Invoice invoice) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FutureBuilder<String>(
            future: billingController.getCourseName(invoice.courseId),
            builder: (context, snapshot) {
              final courseName = snapshot.data ?? 'Course ${invoice.courseId}';
              return Row(
                children: [
                  Icon(Icons.school, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      courseName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                // Mobile: 2x2 grid
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Lessons',
                            '${invoice.lessons}',
                            Icons.assignment,
                          ),
                        ),
                        Expanded(
                          child: _buildDetailItem(
                            'Total Amount',
                            '\$${invoice.totalAmountCalculated.toStringAsFixed(2)}',
                            Icons.attach_money,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Paid',
                            '\$${invoice.amountPaid.toStringAsFixed(2)}',
                            Icons.payment,
                          ),
                        ),
                        Expanded(
                          child: _buildDetailItem(
                            'Balance',
                            '\$${invoice.balance.toStringAsFixed(2)}',
                            Icons.account_balance,
                            valueColor: invoice.balance > 0
                                ? Colors.red.shade600
                                : Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Desktop: single row
                return Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        'Lessons',
                        '${invoice.lessons}',
                        Icons.assignment,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        'Total Amount',
                        '\$${invoice.totalAmountCalculated.toStringAsFixed(2)}',
                        Icons.attach_money,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        'Paid',
                        '\$${invoice.amountPaid.toStringAsFixed(2)}',
                        Icons.payment,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        'Balance',
                        '\$${invoice.balance.toStringAsFixed(2)}',
                        Icons.account_balance,
                        valueColor: invoice.balance > 0
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Due: ${DateFormat('MMM dd, yyyy').format(invoice.dueDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: invoice.dueDate.isBefore(DateTime.now()) &&
                            invoice.balance > 0
                        ? Colors.red.shade600
                        : Colors.grey.shade600,
                    fontWeight: invoice.dueDate.isBefore(DateTime.now()) &&
                            invoice.balance > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

// Add this method to force fresh data loading
  Future<void> _initializeData() async {
    // Force refresh billing data when screen loads
    await billingController.fetchBillingData();
    await _loadData();
  }

// Also add this to your _buildInvoiceActions method to ensure fresh data
  Widget _buildInvoiceActions(Invoice invoice) {
    return FutureBuilder(
      future: _ensureFreshInvoiceData(invoice.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final freshInvoice = snapshot.data as Invoice? ?? invoice;

        // Get payments for this invoice
        final invoicePayments = billingController.payments
            .where((payment) => payment.invoiceId == freshInvoice.id)
            .toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive layout based on available width
              if (constraints.maxWidth < 400) {
                // Mobile layout - stack buttons vertically
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (freshInvoice.balance > 0.01) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showPaymentDialog(freshInvoice, widget.student),
                          icon: const Icon(Icons.payment, size: 16),
                          label: const Text('Record Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: invoicePayments.isNotEmpty
                            ? () => _showInvoiceReceipts(
                                freshInvoice, invoicePayments)
                            : null,
                        icon: Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: invoicePayments.isEmpty ? Colors.grey : null,
                        ),
                        label: Text(
                          invoicePayments.isEmpty
                              ? 'No Receipts'
                              : 'Receipts (${invoicePayments.length})',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          foregroundColor:
                              invoicePayments.isEmpty ? Colors.grey : null,
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Desktop/tablet layout - buttons side by side
                return Row(
                  children: [
                    if (freshInvoice.balance > 0.01) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showPaymentDialog(freshInvoice, widget.student),
                          icon: const Icon(Icons.payment, size: 16),
                          label: const Text(
                            'Record Payment',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: invoicePayments.isNotEmpty
                            ? () => _showInvoiceReceipts(
                                freshInvoice, invoicePayments)
                            : null,
                        icon: Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: invoicePayments.isEmpty ? Colors.grey : null,
                        ),
                        label: Text(
                          invoicePayments.isEmpty
                              ? 'No Receipts'
                              : 'View Receipts (${invoicePayments.length})',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          foregroundColor:
                              invoicePayments.isEmpty ? Colors.grey : null,
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        );
      },
    );
  }

// Add this method to get fresh invoice data from database
  Future<Invoice> _ensureFreshInvoiceData(int invoiceId) async {
    // Force refresh billing data
    await billingController.fetchBillingData();

    // Find the invoice with fresh data
    final freshInvoice = billingController.invoices.firstWhere(
      (inv) => inv.id == invoiceId,
      orElse: () => throw Exception('Invoice not found'),
    );

    return freshInvoice;
  }

  void _showInvoiceReceipts(Invoice invoice, List<Payment> payments) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = MediaQuery.of(context).size.height;
            final maxHeight = screenHeight * 0.85; // Use 85% of screen height

            return Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice #${invoice.invoiceNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${payments.length} payment${payments.length != 1 ? 's' : ''} made',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Invoice Summary - Mobile Optimized
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 400) {
                          // Mobile: 2x2 grid layout
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryColumn(
                                      'Total',
                                      '\$${invoice.totalAmountCalculated.toStringAsFixed(2)}',
                                      Colors.blue.shade600,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildSummaryColumn(
                                      'Paid',
                                      '\$${invoice.amountPaid.toStringAsFixed(2)}',
                                      Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryColumn(
                                      'Balance',
                                      '\$${invoice.balance.toStringAsFixed(2)}',
                                      invoice.balance > 0
                                          ? Colors.red.shade600
                                          : Colors.green.shade600,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildSummaryColumn(
                                      'Payments',
                                      '${payments.length}',
                                      Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        } else {
                          // Desktop: single row
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryColumn(
                                'Total Amount',
                                '\$${invoice.totalAmountCalculated.toStringAsFixed(2)}',
                                Colors.blue.shade600,
                              ),
                              _buildSummaryColumn(
                                'Amount Paid',
                                '\$${invoice.amountPaid.toStringAsFixed(2)}',
                                Colors.green.shade600,
                              ),
                              _buildSummaryColumn(
                                'Balance',
                                '\$${invoice.balance.toStringAsFixed(2)}',
                                invoice.balance > 0
                                    ? Colors.red.shade600
                                    : Colors.green.shade600,
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),

                  // Payments List - Optimized for mobile scrolling
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        return _buildMobilePaymentCard(payments[index], index);
                      },
                    ),
                  ),

                  // Footer with total payments - Mobile optimized
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 350) {
                          // Very small screens - stack vertically
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Total Payments: ${payments.length}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total Paid: \$${payments.fold<double>(0, (sum, p) => sum + p.amount).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Regular mobile - side by side
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Payments: ${payments.length}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Total: \$${payments.fold<double>(0, (sum, p) => sum + p.amount).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobilePaymentCard(Payment payment, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Header - Mobile optimized
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: payment.receiptGenerated
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    payment.receiptGenerated
                        ? Icons.receipt
                        : Icons.receipt_outlined,
                    color: payment.receiptGenerated
                        ? Colors.green.shade600
                        : Colors.orange.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.reference ?? 'Payment #${payment.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy • HH:mm')
                            .format(payment.paymentDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      payment.formattedAmount,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: payment.receiptGenerated
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        payment.receiptGenerated ? 'Receipt' : 'No Receipt',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: payment.receiptGenerated
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Payment Details - Mobile chips
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildPaymentDetailChip(
                  payment.method.toUpperCase(),
                  Icons.payment,
                  Colors.blue.shade600,
                ),
                if (payment.notes != null && payment.notes!.isNotEmpty)
                  _buildPaymentDetailChip(
                    'Has Notes',
                    Icons.note,
                    Colors.purple.shade600,
                  ),
              ],
            ),

            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  payment.notes!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Payment Actions - Mobile optimized buttons
            if (payment.receiptGenerated && payment.receiptPath != null) ...[
              // Two buttons side by side for existing receipts
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _viewReceipt(payment),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _printReceipt(payment),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Single button for generating receipt
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generateReceiptForPayment(payment),
                  icon: const Icon(Icons.receipt, size: 16),
                  label: const Text('Generate Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryColumn(String label, String value, Color color) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPaymentDetailChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _viewReceipt(Payment payment) async {
    if (payment.receiptPath == null) {
      _showErrorSnackbar('Receipt file path not found');
      return;
    }

    // Check if file exists
    final file = File(payment.receiptPath!);
    if (!await file.exists()) {
      // Try to regenerate the receipt if file doesn't exist
      final shouldRegenerate = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Receipt Not Found'),
              content: const Text(
                'The receipt file could not be found. Would you like to regenerate it?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Regenerate'),
                ),
              ],
            ),
          ) ??
          false;

      if (shouldRegenerate) {
        _generateReceiptForPayment(payment);
        return;
      } else {
        return;
      }
    }

    // Show the PDF viewer dialog or simple viewer
    try {
      // You can use either the full PDF viewer or simple viewer here
      // For now, I'll show the simple receipt viewer
      showDialog(
        context: context,
        builder: (context) => _buildReceiptViewerDialog(payment),
        barrierDismissible: true,
      );
    } catch (e) {
      _showErrorSnackbar('Failed to open receipt: ${e.toString()}');
    }
  }

  Widget _buildReceiptViewerDialog(Payment payment) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Receipt ${payment.reference ?? payment.id.toString()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        size: 50,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 20),
                      ResponsiveText(
                        'Receipt Generated',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ResponsiveText(
                        'Reference: ${payment.reference ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ResponsiveText(
                        'Amount: ${payment.formattedAmount}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade600,
                        ),
                      ),
                      ResponsiveText(
                        'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(payment.paymentDate)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      ResponsiveText(
                        payment.receiptPath!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _printReceipt(payment),
                      icon: const Icon(Icons.print, size: 20),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
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
                    child: ElevatedButton.icon(
                      onPressed: () => _shareReceipt(payment),
                      icon: const Icon(Icons.share, size: 20),
                      label: const Text('Open/Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
// Add these methods to your _StudentInvoiceScreenState class

  void _showLoadingSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 2),
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

  void _printReceipt(Payment payment) async {
    try {
      _showLoadingSnackbar('Preparing receipt for printing...');

      // Find the invoice for this payment
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) => inv.id == payment.invoiceId,
      );

      if (invoice == null) {
        _showErrorSnackbar('Invoice not found for this payment');
        return;
      }

      // Try to get course from billingController first
      var course = billingController.courses.firstWhereOrNull(
        (c) => c.id == invoice.courseId,
      );

      // If not found, load from database directly
      if (course == null) {
        print('⚠️ Course not in controller, loading from database...');
        final db = await DatabaseHelper.instance.database;
        final results = await db.query(
          'courses',
          where: 'id = ?',
          whereArgs: [invoice.courseId],
        );

        if (results.isEmpty) {
          _showErrorSnackbar('Course not found for this invoice');
          return;
        }

        course = Course.fromJson(results.first);
      }

      // Create receipt items from the invoice/payment
      final receiptItems = [
        ReceiptItem(
          itemName: course.name,
          quantity: 1,
          unitPrice: payment.amount.toDouble(),
          totalPrice: payment.amount.toDouble(),
        ),
      ];

      // Use PrintService to print (same as POS screen)
      await PrintService.printReceipt(
        receiptNumber:
            payment.reference ?? payment.receiptNumber ?? 'RCP-${payment.id}',
        student: widget.student,
        items: receiptItems,
        total: payment.amount.toDouble(),
        paymentMethod: payment.method,
        notes: payment.notes,
      );

      _showSuccessSnackbar('Receipt sent to printer successfully!');
    } catch (e) {
      print('❌ Print error: $e');
      _showErrorSnackbar('Failed to print receipt: ${e.toString()}');
    }
  }

  void _shareReceipt(Payment payment) async {
    try {
      _showLoadingSnackbar('Preparing receipt for sharing...');

      if (payment.receiptPath != null && payment.receiptPath!.isNotEmpty) {
        if (payment.receiptPath!.startsWith('https://')) {
          // Cloud receipt - share directly from URL
          await ReceiptService.shareReceiptFromCloud(payment.receiptPath!);
        } else {
          // Legacy local receipt - still supported
          final file = File(payment.receiptPath!);
          if (await file.exists()) {
            await Printing.sharePdf(
              bytes: await file.readAsBytes(),
              filename: 'receipt_${payment.id}.pdf',
            );
          } else {
            throw Exception('Local receipt file not found');
          }
        }
      } else {
        // Generate new cloud receipt
        final downloadUrl = await ReceiptService.generateReceiptSmart(payment);

        // Update payment record
        await _updatePaymentWithCloudReceipt(payment, downloadUrl);

        // Share the new receipt
        await ReceiptService.shareReceiptFromCloud(downloadUrl);
      }

      _showSuccessSnackbar('Receipt shared successfully');
    } catch (e) {
      _showErrorSnackbar('Failed to share receipt: ${e.toString()}');
    }
  }

  void _generateReceiptForPayment(Payment payment) async {
    try {
      _showLoadingSnackbar('Generating cloud receipt...');

      // Generate cloud receipt
      final downloadUrl = await ReceiptService.generateReceiptSmart(payment);

      // Update payment with cloud receipt URL
      await _updatePaymentWithCloudReceipt(payment, downloadUrl);

      // Refresh the data
      if (mounted) {
        await _loadData(); // For student_invoice.dart
        // OR
        // await billingController.fetchBillingData(); // For receipt_management_screen.dart
        // setState(() {});
      }

      _showSuccessSnackbar('Cloud receipt generated successfully!');
    } catch (e) {
      _showErrorSnackbar('Failed to generate receipt: ${e.toString()}');
    }
  }

// Helper method to update payment with cloud receipt
  Future<void> _updatePaymentWithCloudReceipt(
      Payment payment, String downloadUrl) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'payments',
      {
        'receipt_path': downloadUrl,
        'receipt_generated': 1,
        'receipt_type': 'cloud',
        'receipt_generated_at': DateTime.now().toIso8601String(),
        'last_modified': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

// For billing_controller.dart - Enhanced methods
  Future<void> printReceipt(Payment payment) async {
    try {
      setState(() => _isLoading = true);

      if (payment.receiptPath != null &&
          payment.receiptPath!.isNotEmpty &&
          payment.receiptPath!.startsWith('https://')) {
        // Print existing cloud receipt
        await ReceiptService.printReceiptFromCloud(payment.receiptPath!);
      } else {
        // Generate new cloud receipt
        final downloadUrl = await ReceiptService.generateReceiptSmart(payment);

        // Update payment record
        await _dbHelper.updatePayment({
          'id': payment.id,
          'receipt_path': downloadUrl,
          'receipt_generated': 1,
          'receipt_type': 'cloud',
          'receipt_generated_at': DateTime.now().toIso8601String(),
          'last_modified': DateTime.now().millisecondsSinceEpoch,
        });

        // Print the receipt
        await ReceiptService.printReceiptFromCloud(downloadUrl);
      }

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Receipt Sent to Printer',
        'Receipt for ${payment.reference ?? payment.id} has been sent to printer',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
      );
    } catch (e) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Print Failed',
        'Failed to print receipt: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> shareReceipt(Payment payment) async {
    try {
      setState(() => _isLoading = true);

      if (payment.receiptPath != null &&
          payment.receiptPath!.isNotEmpty &&
          payment.receiptPath!.startsWith('https://')) {
        // Share existing cloud receipt
        await ReceiptService.shareReceiptFromCloud(payment.receiptPath!);
      } else {
        // Generate new cloud receipt
        final downloadUrl = await ReceiptService.generateReceiptSmart(payment);

        // Update payment record
        await _dbHelper.updatePayment({
          'id': payment.id,
          'receipt_path': downloadUrl,
          'receipt_generated': 1,
          'receipt_type': 'cloud',
          'receipt_generated_at': DateTime.now().toIso8601String(),
          'last_modified': DateTime.now().millisecondsSinceEpoch,
        });

        // Share the receipt
        await ReceiptService.shareReceiptFromCloud(downloadUrl);
      }

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Receipt Shared',
        'Receipt for ${payment.reference ?? payment.id} has been shared successfully',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
      );
    } catch (e) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Share Failed',
        'Failed to share receipt: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Enhanced receipt generation with cloud storage
  Future<String?> generateReceiptWithValidation(Payment payment) async {
    // Check if business settings are complete
    final billingController = Get.find<BillingController>();
    if (!await billingController.validateBusinessSettingsForReceipts()) {
      return null;
    }

    try {
      // Use cloud generation method
      return await ReceiptService.generateReceiptSmart(payment);
    } catch (e) {
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Receipt Generation Failed',
        'Failed to generate receipt: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
      return null;
    }
  }

// Enhanced method for recording payment with cloud receipt generation
  Future<void> recordPaymentWithReceipt(
      Payment payment, Invoice invoice, User student) async {
    print('=== STARTING recordPaymentWithReceipt (Cloud) ===');

    try {
      setState(() => _isLoading = true);

      // Generate reference if not provided
      final reference = payment.reference ?? ReceiptService.generateReference();

      // Create payment with reference
      final paymentWithReference = payment.copyWith(reference: reference);

      // Insert payment
      final paymentId =
          await _dbHelper.insertPayment(paymentWithReference.toJson());
      print('✓ Payment inserted with ID: $paymentId');

      // Update invoice status
      final billingController = Get.find<BillingController>();
      await billingController.recordPaymentWithReceipt(
          payment, invoice, student);
      print('✓ Invoice status updated');

      // Generate cloud receipt
      try {
        final updatedPayment = paymentWithReference.copyWith(id: paymentId);
        final downloadUrl = await ReceiptService.generateAndUploadReceipt(
          updatedPayment,
          invoice,
          student,
        );

        // Update payment with cloud receipt URL
        await _dbHelper.updatePayment({
          'id': paymentId,
          'receipt_path': downloadUrl,
          'receipt_generated': 1,
          'receipt_type': 'cloud',
          'receipt_generated_at': DateTime.now().toIso8601String(),
          'last_modified': DateTime.now().millisecondsSinceEpoch,
        });

        print('✅ Cloud receipt generated: $downloadUrl');

        // Refresh billing data
        await billingController.fetchBillingData();

        // Show success with receipt options
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Payment Recorded',
          'Payment recorded and cloud receipt generated successfully',
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () => ReceiptService.printReceiptFromCloud(downloadUrl),
            child: const Text('Print Receipt',
                style: TextStyle(color: Colors.white)),
          ),
        );
      } catch (receiptError) {
        print('⚠️ Cloud receipt generation failed: $receiptError');

        // Payment was recorded successfully, just receipt failed
        await billingController.fetchBillingData();

        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Payment Recorded',
          'Payment recorded successfully, but receipt generation failed. You can generate it later.',
          backgroundColor: Colors.orange.shade600,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }

      print('=== recordPaymentWithReceipt (Cloud) COMPLETED ===');
    } catch (e) {
      print('=== ERROR in recordPaymentWithReceipt (Cloud) ===');
      print('Error: $e');

      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Payment Failed',
        'Failed to record payment: ${e.toString()}',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      rethrow;
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Batch operations for migration
  Future<Map<String, dynamic>> migrateReceiptsToCloud() async {
    try {
      setState(() => _isLoading = true);

      final billingController = Get.find<BillingController>();
      final paymentsNeedingMigration = billingController.payments
          .where((payment) =>
              payment.receiptGenerated &&
              (payment.receiptPath == null ||
                  payment.receiptPath!.isEmpty ||
                  !payment.receiptPath!.startsWith('https://')))
          .toList();
      if (paymentsNeedingMigration.isEmpty) {
        Get.snackbar(
          snackPosition: SnackPosition.BOTTOM,
          'Migration Complete',
          'All receipts are already in the cloud',
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
        );
        return {'message': 'No migration needed'};
      }

      // Show progress dialog
      Get.dialog(
        AlertDialog(
          title: const Text('Migrating Receipts'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                  'Migrating ${paymentsNeedingMigration.length} receipts to cloud storage...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Perform batch upload
      final result = await ReceiptService.batchUploadReceipts(
        paymentsNeedingMigration,
        onProgress: (current, total) {
          // Update progress if needed
          print('Migration progress: $current/$total');
        },
      );

      // Close progress dialog
      Get.back();

      // Refresh data
      await billingController.fetchBillingData();

      // Show result
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Migration Complete',
        'Successfully migrated ${result['success_count']} receipts to cloud storage',
        backgroundColor: result['success_count'] == result['total_processed']
            ? Colors.green.shade100
            : Colors.orange.shade100,
        colorText: result['success_count'] == result['total_processed']
            ? Colors.green.shade800
            : Colors.orange.shade800,
        duration: const Duration(seconds: 5),
      );

      return result;
    } catch (e) {
      Get.back(); // Close progress dialog
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'Migration Failed',
        'Failed to migrate receipts: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
      rethrow;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPaymentDialog(Invoice invoice, User student) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PaymentDialog(
          invoice: invoice,
          studentName: '${widget.student.fname} ${widget.student.lname}',
          studentId: student.id!,
        );
      },
    ).then((_) {
      _loadData(); // Refresh data after payment
    });
  }

  void _showInvoiceOptions(Invoice invoice) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Invoice'),
                onTap: () {
                  Navigator.pop(context);
                  _editInvoice(invoice);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Duplicate Invoice'),
                onTap: () {
                  Navigator.pop(context);
                  _duplicateInvoice(invoice);
                },
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Send Email'),
                onTap: () {
                  Navigator.pop(context);
                  _sendInvoiceEmail(invoice);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade600),
                title: Text(
                  'Delete Invoice',
                  style: TextStyle(color: Colors.red.shade600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteInvoice(invoice);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editInvoice(Invoice invoice) {
    _showSuccessSnackbar('Edit invoice feature coming soon!');
  }

  void _duplicateInvoice(Invoice invoice) {
    _showSuccessSnackbar('Invoice duplicated successfully!');
  }

  void _sendInvoiceEmail(Invoice invoice) {
    _showSuccessSnackbar('Invoice email sent!');
  }

  void _confirmDeleteInvoice(Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Invoice'),
          content: const Text(
              'Are you sure you want to delete this invoice? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteInvoice(invoice);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteInvoice(Invoice invoice) {
    if (invoice.id != null) {
      billingController.deleteInvoice(invoice.id!).then((_) {
        _showSuccessSnackbar('Invoice deleted successfully');
        _loadData();
      }).catchError((error) {
        _showErrorSnackbar('Failed to delete invoice');
      });
    }
  }

// Enhanced _exportAllInvoices method with CSV and PDF options
  void _exportAllInvoices() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Options'),
          content: const Text('Choose the export format for all invoices.'),
          actions: [
            TextButton(
              child: const Text('CSV'),
              onPressed: () {
                Navigator.of(context).pop();
                _exportInvoicesCSV();
              },
            ),
            TextButton(
              child: const Text('PDF'),
              onPressed: () {
                Navigator.of(context).pop();
                _exportInvoicesPDF();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

// Export invoices to CSV
  Future<void> _exportInvoicesCSV() async {
    try {
      if (_filteredInvoices.isEmpty) {
        _showErrorSnackbar('No invoices to export');
        return;
      }

      // Prepare CSV data
      List<List<dynamic>> csvData = [
        [
          'Invoice Number',
          'Date Created',
          'Due Date',
          'Course',
          'Lessons',
          'Price Per Lesson',
          'Total Amount',
          'Amount Paid',
          'Balance',
          'Status',
          'Student Name'
        ],
      ];

      // Add invoice data
      for (var invoice in _filteredInvoices) {
        String courseName =
            await billingController.getCourseName(invoice.courseId);

        csvData.add([
          invoice.invoiceNumber,
          DateFormat('yyyy-MM-dd').format(invoice.createdAt),
          DateFormat('yyyy-MM-dd').format(invoice.dueDate),
          courseName,
          invoice.lessons,
          invoice.pricePerLesson.toStringAsFixed(2),
          invoice.totalAmountCalculated.toStringAsFixed(2),
          invoice.amountPaid.toStringAsFixed(2),
          invoice.balance.toStringAsFixed(2),
          invoice.status,
          '${widget.student.fname} ${widget.student.lname}'
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Generate filename with timestamp
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.]'), '_');
      final fileName =
          'invoices_${widget.student.fname}_${widget.student.lname}_$timestamp.csv';

      // Save file using file picker
      final String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Invoice Export',
        fileName: fileName,
        allowedExtensions: ['csv'],
      );

      if (filePath != null) {
        final file = File(filePath);
        await file.writeAsString(csvString);

        _showSuccessSnackbar('Invoices exported successfully to $filePath');
      } else {
        _showErrorSnackbar('Export cancelled');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to export invoices: ${e.toString()}');
    }
  }

// Export invoices to PDF
  Future<void> _exportInvoicesPDF() async {
    try {
      if (_filteredInvoices.isEmpty) {
        _showErrorSnackbar('No invoices to export');
        return;
      }

      final pdf = pw.Document();

      // Calculate summary
      double totalAmount = 0;
      double totalPaid = 0;
      double totalBalance = 0;
      int overdueCount = 0;

      for (var invoice in _filteredInvoices) {
        totalAmount += invoice.totalAmountCalculated;
        totalPaid += invoice.amountPaid;
        totalBalance += invoice.balance;
        if (invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now())) {
          overdueCount++;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Text(
                      'INVOICE EXPORT REPORT',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Student: ${widget.student.fname} ${widget.student.lname}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Summary Section
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SUMMARY',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                                'Total Invoices: ${_filteredInvoices.length}'),
                            pw.Text('Overdue Invoices: $overdueCount'),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                                'Total Amount: \$${totalAmount.toStringAsFixed(2)}'),
                            pw.Text(
                                'Total Paid: \$${totalPaid.toStringAsFixed(2)}'),
                            pw.Text(
                              'Outstanding Balance: \$${totalBalance.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: totalBalance > 0
                                    ? PdfColors.red
                                    : PdfColors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Invoice Table
              pw.Text(
                'INVOICE DETAILS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),

              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FixedColumnWidth(60),
                  1: const pw.FixedColumnWidth(60),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(80),
                  4: const pw.FixedColumnWidth(60),
                  5: const pw.FixedColumnWidth(60),
                  6: const pw.FixedColumnWidth(60),
                  7: const pw.FixedColumnWidth(50),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildTableCell('Invoice #', isHeader: true),
                      _buildTableCell('Date', isHeader: true),
                      _buildTableCell('Due Date', isHeader: true),
                      _buildTableCell('Course', isHeader: true),
                      _buildTableCell('Lessons', isHeader: true),
                      _buildTableCell('Total', isHeader: true),
                      _buildTableCell('Paid', isHeader: true),
                      _buildTableCell('Balance', isHeader: true),
                    ],
                  ),
                  // Data rows
                  ..._filteredInvoices
                      .map(
                        (invoice) => pw.TableRow(
                          children: [
                            _buildTableCell(invoice.invoiceNumber),
                            _buildTableCell(DateFormat('MM/dd/yy')
                                .format(invoice.createdAt)),
                            _buildTableCell(
                                DateFormat('MM/dd/yy').format(invoice.dueDate)),
                            _buildTableCell(invoice.courseId
                                .toString()), // You might want to get course name
                            _buildTableCell(invoice.lessons.toString()),
                            _buildTableCell(
                                '\$${invoice.totalAmountCalculated.toStringAsFixed(2)}'),
                            _buildTableCell(
                                '\$${invoice.amountPaid.toStringAsFixed(2)}'),
                            _buildTableCell(
                              '\$${invoice.balance.toStringAsFixed(2)}',
                              textColor: invoice.balance > 0
                                  ? PdfColors.red
                                  : PdfColors.green,
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ],
              ),
            ];
          },
        ),
      );

      // Generate filename with timestamp
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.]'), '_');
      final fileName =
          'invoices_${widget.student.fname}_${widget.student.lname}_$timestamp.pdf';

      // Save file using file picker
      final String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Invoice Export',
        fileName: fileName,
        allowedExtensions: ['pdf'],
      );

      if (filePath != null) {
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());

        _showSuccessSnackbar(
            'Invoice report exported successfully to $filePath');
      } else {
        _showErrorSnackbar('Export cancelled');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to export PDF: ${e.toString()}');
    }
  }

// Enhanced _generateStatement method
  void _generateStatement() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Generate Statement'),
          content: const Text(
              'Generate a detailed account statement for this student.'),
          actions: [
            TextButton(
              child: const Text('PDF Statement'),
              onPressed: () {
                Navigator.of(context).pop();
                _generateStatementPDF();
              },
            ),
            TextButton(
              child: const Text('Email Statement'),
              onPressed: () {
                Navigator.of(context).pop();
                _generateAndEmailStatement();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

// Generate comprehensive PDF statement
  Future<void> _generateStatementPDF() async {
    try {
      if (_filteredInvoices.isEmpty) {
        _showErrorSnackbar('No invoices found for statement generation');
        return;
      }

      final pdf = pw.Document();

      // Calculate comprehensive summary
      double totalAmount = 0;
      double totalPaid = 0;
      double totalBalance = 0;
      int totalLessons = 0;
      int overdueCount = 0;
      DateTime? oldestInvoice;
      DateTime? newestInvoice;

      for (var invoice in _filteredInvoices) {
        totalAmount += invoice.totalAmountCalculated;
        totalPaid += invoice.amountPaid;
        totalBalance += invoice.balance;
        totalLessons += invoice.lessons;

        if (invoice.balance > 0 && invoice.dueDate.isBefore(DateTime.now())) {
          overdueCount++;
        }

        if (oldestInvoice == null ||
            invoice.createdAt.isBefore(oldestInvoice)) {
          oldestInvoice = invoice.createdAt;
        }
        if (newestInvoice == null || invoice.createdAt.isAfter(newestInvoice)) {
          newestInvoice = invoice.createdAt;
        }
      }

      // Get payment history
      List<Payment> allPayments = [];
      for (var invoice in _filteredInvoices) {
        final payments =
            await billingController.getPaymentsForInvoice(invoice.id!);
        allPayments.addAll(payments);
      }
      allPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Text(
                      'STUDENT ACCOUNT STATEMENT',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Student Information',
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                      'Name: ${widget.student.fname} ${widget.student.lname}'),
                                  pw.Text('Email: ${widget.student.email}'),
                                  pw.Text(
                                      'Phone: ${widget.student.phone ?? "N/A"}'),
                                ],
                              ),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text(
                                    'Statement Period',
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                      'From: ${oldestInvoice != null ? DateFormat('MMM dd, yyyy').format(oldestInvoice) : "N/A"}'),
                                  pw.Text(
                                      'To: ${newestInvoice != null ? DateFormat('MMM dd, yyyy').format(newestInvoice) : "N/A"}'),
                                  pw.Text(
                                      'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Account Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ACCOUNT SUMMARY',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                                'Total Invoices: ${_filteredInvoices.length}'),
                            pw.Text('Total Lessons: $totalLessons'),
                            pw.Text('Overdue Invoices: $overdueCount'),
                            pw.Text('Total Payments: ${allPayments.length}'),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                                'Total Charges: \$${totalAmount.toStringAsFixed(2)}'),
                            pw.Text(
                                'Total Payments: \$${totalPaid.toStringAsFixed(2)}'),
                            pw.Divider(),
                            pw.Text(
                              'Current Balance: \$${totalBalance.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: totalBalance > 0
                                    ? PdfColors.red
                                    : PdfColors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Invoice Summary Table
              pw.Text(
                'INVOICE SUMMARY',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),

              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Invoice #', isHeader: true),
                      _buildTableCell('Date', isHeader: true),
                      _buildTableCell('Due Date', isHeader: true),
                      _buildTableCell('Amount', isHeader: true),
                      _buildTableCell('Paid', isHeader: true),
                      _buildTableCell('Balance', isHeader: true),
                      _buildTableCell('Status', isHeader: true),
                    ],
                  ),
                  // Data rows
                  ..._filteredInvoices
                      .map(
                        (invoice) => pw.TableRow(
                          children: [
                            _buildTableCell(invoice.invoiceNumber),
                            _buildTableCell(DateFormat('MM/dd/yy')
                                .format(invoice.createdAt)),
                            _buildTableCell(
                                DateFormat('MM/dd/yy').format(invoice.dueDate)),
                            _buildTableCell(
                                '\$${invoice.totalAmountCalculated.toStringAsFixed(2)}'),
                            _buildTableCell(
                                '\$${invoice.amountPaid.toStringAsFixed(2)}'),
                            _buildTableCell(
                              '\$${invoice.balance.toStringAsFixed(2)}',
                              textColor: invoice.balance > 0
                                  ? PdfColors.red
                                  : PdfColors.green,
                            ),
                            _buildTableCell(
                              invoice.status.toUpperCase(),
                              textColor: invoice.status == 'paid'
                                  ? PdfColors.green
                                  : invoice.balance > 0 &&
                                          invoice.dueDate
                                              .isBefore(DateTime.now())
                                      ? PdfColors.red
                                      : PdfColors.blue,
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ],
              ),

              pw.SizedBox(height: 20),

              // Payment History
              if (allPayments.isNotEmpty) ...[
                pw.Text(
                  'RECENT PAYMENT HISTORY',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('Date', isHeader: true),
                        _buildTableCell('Invoice #', isHeader: true),
                        _buildTableCell('Amount', isHeader: true),
                        _buildTableCell('Method', isHeader: true),
                        _buildTableCell('Reference', isHeader: true),
                      ],
                    ),
                    // Payment data (show last 10)
                    ...allPayments.take(10).map((payment) {
                      final invoice = _filteredInvoices.firstWhere(
                        (inv) => inv.id == payment.invoiceId,
                        orElse: () => Invoice(
                          invoiceNumber: 'N/A',
                          studentId: 0,
                          courseId: 0,
                          lessons: 0,
                          pricePerLesson: 0,
                          amountPaid: 0,
                          createdAt: DateTime.now(),
                          dueDate: DateTime.now(),
                          status: '',
                          totalAmount: 0,
                        ),
                      );
                      return pw.TableRow(
                        children: [
                          _buildTableCell(DateFormat('MM/dd/yy')
                              .format(payment.paymentDate)),
                          _buildTableCell(invoice.invoiceNumber),
                          _buildTableCell(
                              '\$${payment.amount.toStringAsFixed(2)}',
                              textColor: PdfColors.green),
                          _buildTableCell(payment.method),
                          _buildTableCell(payment.reference ?? ''),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],

              pw.SizedBox(height: 30),

              // Footer
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Divider(),
                    pw.Text(
                      'Thank you for choosing our driving school!',
                      style: pw.TextStyle(
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'For questions about this statement, please contact us.',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Generate filename
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.]'), '_');
      final fileName =
          'statement_${widget.student.fname}_${widget.student.lname}_$timestamp.pdf';

      // Save file
      final String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Account Statement',
        fileName: fileName,
        allowedExtensions: ['pdf'],
      );

      if (filePath != null) {
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());

        _showSuccessSnackbar(
            'Account statement generated successfully: $filePath');
      } else {
        _showErrorSnackbar('Statement generation cancelled');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to generate statement: ${e.toString()}');
    }
  }

// Generate and email statement (placeholder for email functionality)
  Future<void> _generateAndEmailStatement() async {
    try {
      // First generate the PDF in memory
      final pdf = pw.Document();
      // ... (use the same PDF generation code as above)

      // For now, save to app directory and show location
      final directory = await getApplicationDocumentsDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.]'), '_');
      final fileName =
          'statement_${widget.student.fname}_${widget.student.lname}_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

      // Save temporarily
      await file.writeAsBytes(await pdf.save());

      _showSuccessSnackbar(
          'Statement prepared for email. Feature integration pending: ${file.path}');

      // TODO: Integrate with email service
      // EmailService.sendStatement(widget.student.email, file.path);
    } catch (e) {
      _showErrorSnackbar(
          'Failed to prepare statement for email: ${e.toString()}');
    }
  }

// Helper method for table cells
  pw.Widget _buildTableCell(String text,
      {bool isHeader = false, PdfColor? textColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? (isHeader ? PdfColors.black : PdfColors.grey800),
        ),
      ),
    );
  }
}
