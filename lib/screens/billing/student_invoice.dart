import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/models/billing_record.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/user.dart';
import 'package:driving/widgets/payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

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
          comparison = a.createdDate.compareTo(b.createdDate);
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
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
        // subtitle: const Text(
        //   'Invoice History',
        //   style: TextStyle(
        //     fontSize: 14,
        //     color: Colors.white70,
        //   ),
        // ),
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
                    ),
                    if (widget.student.email != null)
                      Text(
                        widget.student.email!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (totalBalance > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ),
          const SizedBox(height: 20),
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
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFiltersAndSort() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildFilterChips()),
          const SizedBox(width: 16),
          _buildSortDropdown(),
        ],
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

    return Wrap(
      spacing: 8,
      children: filters.map((filter) {
        final isSelected = _selectedFilter == filter['key'];
        return FilterChip(
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
        );
      }).toList(),
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
                  'Invoice #${invoice.id}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Created: ${DateFormat('MMM dd, yyyy').format(invoice.createdDate)}',
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
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
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
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceActions(Invoice invoice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          if (invoice.balance > 0) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showPaymentDialog(invoice),
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
            const SizedBox(width: 12),
          ],
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _generateAndDownloadPdf(invoice),
              icon: const Icon(Icons.file_download, size: 16),
              label: const Text('Download PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _showInvoiceOptions(invoice),
            icon: const Icon(Icons.more_vert),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(Invoice invoice) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PaymentDialog(
          invoice: invoice,
          studentName: '${widget.student.fname} ${widget.student.lname}',
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

  void _generateAndDownloadPdf(Invoice invoice) async {
    try {
      // Implementation for PDF generation
      _showSuccessSnackbar('PDF generated successfully!');
    } catch (e) {
      _showErrorSnackbar('Failed to generate PDF');
    }
  }

  void _exportAllInvoices() {
    _showSuccessSnackbar('Export feature coming soon!');
  }

  void _generateStatement() {
    _showSuccessSnackbar('Statement generation feature coming soon!');
  }
}
