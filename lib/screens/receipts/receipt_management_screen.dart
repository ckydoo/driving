// lib/screens/receipts/receipt_management_screen.dart
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/billing_controller.dart';
import '../../controllers/user_controller.dart';
import '../../services/receipt_service.dart';
import '../../models/payment.dart';

class ReceiptManagementScreen extends StatefulWidget {
  const ReceiptManagementScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptManagementScreen> createState() =>
      _ReceiptManagementScreenState();
}

class _ReceiptManagementScreenState extends State<ReceiptManagementScreen> {
  final BillingController billingController = Get.find<BillingController>();
  final UserController userController = Get.find<UserController>();
  final AuthController authController = Get.find<AuthController>(); // Add this
  final TextEditingController _searchController = TextEditingController();

  String _sortBy = 'date';
  bool _sortAscending = false;
  String _filterStatus = 'all';
  String _searchQuery = '';
  bool _isSearchActive = false;

  // Date filtering variables
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateFilter =
      'all'; // 'all', 'today', 'this_week', 'this_month', 'custom'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (!_isSearchActive) _buildFilterHeader(),
          if (_isSearchActive) _buildSearchSummary(),
          if (_hasActiveDateFilter()) _buildDateFilterSummary(),
          Expanded(
            child: Obx(() {
              if (billingController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final payments = _getFilteredPayments();

              if (payments.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payments.length,
                itemBuilder: (context, index) =>
                    _buildReceiptCard(payments[index]),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: _hasActiveFilters()
          ? FloatingActionButton.extended(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: Text(
                  _searchQuery.isNotEmpty ? 'Clear Search' : 'Clear Filters'),
              backgroundColor: Colors.orange.shade600,
            )
          : null,
    );
  }

  Widget _buildDateFilterSummary() {
    if (!_hasActiveDateFilter()) return const SizedBox.shrink();

    String dateText = '';
    switch (_dateFilter) {
      case 'today':
        dateText = 'Today';
        break;
      case 'this_week':
        dateText = 'This Week';
        break;
      case 'this_month':
        dateText = 'This Month';
        break;
      case 'custom':
        if (_startDate != null && _endDate != null) {
          dateText =
              '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
        } else if (_startDate != null) {
          dateText = 'From ${DateFormat('MMM dd, yyyy').format(_startDate!)}';
        } else if (_endDate != null) {
          dateText = 'Until ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered by: $dateText',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_getFilteredPayments().length} found',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _clearDateFilter,
            child: Icon(
              Icons.close,
              color: Colors.green.shade600,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Type to search receipts...'
                  : 'Searching for "${_searchQuery}"',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_getFilteredPayments().length} found',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Quick Search Bar
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by reference, student name, amount...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: Icon(Icons.clear, color: Colors.grey.shade500),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Date Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateFilterChip('All Time', 'all'),
                const SizedBox(width: 8),
                _buildDateFilterChip('Today', 'today'),
                const SizedBox(width: 8),
                _buildDateFilterChip('This Week', 'this_week'),
                const SizedBox(width: 8),
                _buildDateFilterChip('This Month', 'this_month'),
                const SizedBox(width: 8),
                _buildDateFilterChip('Custom Range', 'custom'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Status Filter Chips
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  'All Receipts',
                  'all',
                  _filterStatus,
                  (value) => setState(() => _filterStatus = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  'Generated',
                  'generated',
                  _filterStatus,
                  (value) => setState(() => _filterStatus = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  'Not Generated',
                  'not_generated',
                  _filterStatus,
                  (value) => setState(() => _filterStatus = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sort Options
          Row(
            children: [
              const Text('Sort by:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _buildSortButton('Date', 'date', Icons.calendar_today),
              const SizedBox(width: 8),
              _buildSortButton('Amount', 'amount', Icons.attach_money),
              const SizedBox(width: 8),
              _buildSortButton('Method', 'method', Icons.payment),
              const Spacer(),
              if (_hasActiveFilters()) ...[
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label:
                      const Text('Clear All', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip(String label, String value) {
    final isSelected = _dateFilter == value;
    return GestureDetector(
      onTap: () => _handleDateFilterTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value == 'custom' ? Icons.date_range : Icons.calendar_today,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue,
      Function(String) onChanged) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSortButton(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = false;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color:
                    isSelected ? Colors.blue.shade600 : Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 2),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: Colors.blue.shade600,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard(Payment payment) {
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) => inv.id == payment.invoiceId,
    );

    final student = userController.users.firstWhereOrNull(
      (user) => user.id == invoice?.studentId,
    );

    // Highlight search terms
    final studentName =
        '${student?.fname ?? 'Unknown'} ${student?.lname ?? 'Student'}';
    final reference = payment.reference ?? 'No Reference';

    // Get the currently logged in user who processed this payment
    final currentUser = authController.currentUser.value;

    // Create processed by display text using current logged in user
    final processedByText = currentUser != null
        ? '${currentUser.fname} ${currentUser.lname} (${currentUser.role})'
        : 'Unknown User';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment Info
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            payment.receiptGenerated
                                ? Icons.receipt
                                : Icons.receipt_outlined,
                            color: payment.receiptGenerated
                                ? Colors.green.shade600
                                : Colors.orange.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHighlightedText(
                              reference,
                              _searchQuery,
                              const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildHighlightedText(
                        studentName,
                        _searchQuery,
                        TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip(
                            payment.formattedAmount,
                            Colors.green.shade600,
                            Icons.attach_money,
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            payment.method.toUpperCase(),
                            Colors.blue.shade600,
                            Icons.payment,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Date and Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(payment.paymentDate),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(payment.paymentDate),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: payment.receiptGenerated
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payment.receiptGenerated
                            ? 'Receipt Generated'
                            : 'No Receipt',
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

            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildHighlightedText(
                  payment.notes!,
                  _searchQuery,
                  TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Processed by info and invoice number row
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Processed by: $processedByText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Invoice #${invoice?.invoiceNumber ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                if (payment.receiptGenerated &&
                    payment.receiptPath != null) ...[
                  _buildActionButton(
                    'View Receipt',
                    Icons.visibility,
                    Colors.blue.shade600,
                    () => _shareReceipt(payment),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    'Print',
                    Icons.print,
                    Colors.green.shade600,
                    () => _printReceipt(payment),
                  ),
                ] else ...[
                  _buildActionButton(
                    'Generate Receipt',
                    Icons.receipt,
                    Colors.blue.shade600,
                    () => _generateReceipt(payment),
                  ),
                ],
                const Spacer(),
                // Show creation timestamp if available
                if (payment.paymentDate != null)
                  Text(
                    'Created: ${DateFormat('MMM dd, HH:mm').format(payment.paymentDate)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle baseStyle) {
    if (query.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle.copyWith(
          backgroundColor: Colors.yellow.shade200,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  Widget _buildInfoChip(String label, Color color, IconData icon) {
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

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasActiveFilters = _hasActiveFilters();
    final currentUser = authController.currentUser.value; // Use authController
    final isStudent = currentUser?.role.toLowerCase() == 'student';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasActiveFilters ? Icons.search_off : Icons.receipt_long,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            hasActiveFilters
                ? 'No matching receipts'
                : isStudent
                    ? 'No receipts found'
                    : 'No receipts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveFilters
                ? 'Try adjusting your search or filters'
                : isStudent
                    ? 'Your payment receipts will appear here'
                    : 'Receipts will appear here when payments are recorded',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Date filtering methods
  void _handleDateFilterTap(String value) {
    if (value == 'custom') {
      _showDateRangePicker();
    } else {
      setState(() {
        _dateFilter = value;
        _setDateRange(value);
      });
    }
  }

  void _setDateRange(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'all':
        _startDate = null;
        _endDate = null;
        break;
      case 'today':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'this_week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'this_month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
    }
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.green.shade600,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFilter = 'custom';
        _startDate = picked.start;
        _endDate = DateTime(
            picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  List<Payment> _getFilteredPayments() {
    var payments = billingController.payments.toList();

    // Filter by current user if they are a student
    final currentUser = authController.currentUser.value;
    if (currentUser != null && currentUser.role.toLowerCase() == 'student') {
      payments = payments.where((payment) {
        final invoice = billingController.invoices.firstWhereOrNull(
          (inv) => inv.id == payment.invoiceId,
        );
        return invoice?.studentId == currentUser.id;
      }).toList();
    }

    // Apply date filter
    if (_hasActiveDateFilter()) {
      payments = payments.where((payment) {
        if (_startDate != null && payment.paymentDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && payment.paymentDate.isAfter(_endDate!)) {
          return false;
        }
        return true;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      payments = payments.where((payment) {
        final invoice = billingController.invoices.firstWhereOrNull(
          (inv) => inv.id == payment.invoiceId,
        );
        final student = userController.users.firstWhereOrNull(
          (user) => user.id == invoice?.studentId,
        );
        final processedBy = userController.users.firstWhereOrNull(
          (user) => user.id == payment.userId,
        );

        final searchableText = [
          payment.reference ?? '',
          '${student?.fname ?? ''} ${student?.lname ?? ''}',
          payment.formattedAmount,
          payment.method,
          payment.notes ?? '',
          invoice?.id?.toString() ?? '',
          // Include processed by information in search
          '${processedBy?.fname ?? ''} ${processedBy?.lname ?? ''}',
          processedBy?.role ?? '',
        ].join(' ').toLowerCase();

        return searchableText.contains(_searchQuery);
      }).toList();
    }

    // Apply status filter
    switch (_filterStatus) {
      case 'generated':
        payments = payments.where((p) => p.receiptGenerated).toList();
        break;
      case 'not_generated':
        payments = payments.where((p) => !p.receiptGenerated).toList();
        break;
    }

    // Apply sorting
    switch (_sortBy) {
      case 'date':
        payments.sort((a, b) => _sortAscending
            ? a.paymentDate.compareTo(b.paymentDate)
            : b.paymentDate.compareTo(a.paymentDate));
        break;
      case 'amount':
        payments.sort((a, b) => _sortAscending
            ? a.amount.compareTo(b.amount)
            : b.amount.compareTo(a.amount));
        break;
      case 'method':
        payments.sort((a, b) => _sortAscending
            ? a.method.compareTo(b.method)
            : b.method.compareTo(a.method));
        break;
    }

    return payments;
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _filterStatus != 'all' ||
        _hasActiveDateFilter();
  }

  bool _hasActiveDateFilter() {
    return _dateFilter != 'all';
  }

  void _clearDateFilter() {
    setState(() {
      _dateFilter = 'all';
      _startDate = null;
      _endDate = null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _filterStatus = 'all';
      _sortBy = 'date';
      _sortAscending = false;
      _isSearchActive = false;
      _dateFilter = 'all';
      _startDate = null;
      _endDate = null;
    });
  }

  void _printReceipt(Payment payment) async {
    if (payment.receiptPath != null) {
      try {
        await ReceiptService.printReceipt(payment.receiptPath!);
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to print receipt: ${e.toString()}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
      }
    }
  }

  void _shareReceipt(Payment payment) async {
    if (payment.receiptPath != null) {
      try {
        await ReceiptService.shareReceipt(payment.receiptPath!);
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to share receipt: ${e.toString()}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
      }
    }
  }

  void _generateReceipt(Payment payment) async {
    try {
      final invoice = billingController.invoices.firstWhere(
        (inv) => inv.id == payment.invoiceId,
      );

      final student = userController.users.firstWhere(
        (user) => user.id == invoice.studentId,
      );

      // Generate receipt
      final receiptPath = await ReceiptService.generateReceipt(
        payment,
        invoice,
        student,
        'Your Driving School', // Replace with your school name
      );

      // Update payment with receipt info
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'payments',
        {
          'receipt_path': receiptPath,
          'receipt_generated': 1,
        },
        where: 'id = ?',
        whereArgs: [payment.id],
      );

      // Refresh data
      await billingController.fetchBillingData();

      Get.snackbar(
        'Success',
        'Receipt generated successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        mainButton: TextButton(
          onPressed: () => ReceiptService.printReceipt(receiptPath),
          child: const Text('Print', style: TextStyle(color: Colors.white)),
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to generate receipt: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }
}
