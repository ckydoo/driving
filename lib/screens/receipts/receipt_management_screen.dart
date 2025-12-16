import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/utils/responsive_utils.dart';
import 'package:driving/models/course.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/print_service.dart';
import 'package:driving/widgets/responsive_extensions.dart';
import 'package:driving/widgets/responsive_text.dart';
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
  final AuthController authController = Get.find<AuthController>();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

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
      body: Obx(() {
        if (billingController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = _getFilteredPayments();

        return CustomScrollView(
          slivers: [
            // Sticky Filter Header (search bar + items count)
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyFilterHeaderDelegate(
                child: _buildResponsiveFilterHeader(),
              ),
            ),

            // Content
            if (payments.isEmpty)
              SliverFillRemaining(
                child: _buildResponsiveEmptyState(),
              )
            else
              SliverToBoxAdapter(
                child: context.isMobile
                    ? _buildMobileReceiptList(payments)
                    : _buildDesktopReceiptList(payments),
              ),
          ],
        );
      }),
      floatingActionButton: _hasActiveFilters()
          ? FloatingActionButton.extended(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: Text(
                _searchQuery.isNotEmpty
                    ? 'Clear Search (${_getFilteredPayments().length})'
                    : 'Clear Filters (${_getFilteredPayments().length})',
              ),
              backgroundColor: Colors.orange.shade600,
            )
          : null,
    );
  }

  Widget _buildResponsiveFilterHeader() {
    return Container(
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(18),
        desktop: const EdgeInsets.all(20),
      ),
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
          // Search Bar
          _buildResponsiveSearchField(),
          SizedBox(
              height: ResponsiveUtils.getValue(context,
                  mobile: 12.0, tablet: 14.0, desktop: 16.0)),

          // Items count display
          Row(
            children: [
              Icon(Icons.receipt_long, size: 20, color: Colors.grey[600]),
              SizedBox(width: 8),
              Text(
                '${_getFilteredPayments().length} receipts',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getValue(context,
                      mobile: 14.0, tablet: 15.0, desktop: 16.0),
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              Spacer(),
              if (_searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: Icon(Icons.clear, size: 16, color: Colors.orange[600]),
                  label: Text('Clear Search',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange[600])),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: ResponsiveUtils.getValue(context,
              mobile: 14.0, tablet: 15.0, desktop: 16.0),
        ),
        decoration: InputDecoration(
          hintText: context.isMobile
              ? 'Search receipts...'
              : 'Search by reference, student name, amount...',
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
          contentPadding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getValue(context,
                mobile: 12.0, tablet: 14.0, desktop: 16.0),
            vertical: ResponsiveUtils.getValue(context,
                mobile: 12.0, tablet: 14.0, desktop: 12.0),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }


  Widget _buildResponsiveEmptyState() {
    final hasActiveFilters = _hasActiveFilters();
    final currentUser = authController.currentUser.value;
    final isStudent = currentUser?.role.toLowerCase() == 'student';

    return Center(
      child: Padding(
        padding: ResponsiveUtils.getPadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasActiveFilters ? Icons.search_off : Icons.receipt_long,
              size: ResponsiveUtils.getValue(context,
                  mobile: 48.0, tablet: 56.0, desktop: 64.0),
              color: Colors.grey.shade400,
            ),
            SizedBox(
                height: ResponsiveUtils.getValue(context,
                    mobile: 12.0, tablet: 14.0, desktop: 16.0)),
            ResponsiveText(
              style: TextStyle(),
              hasActiveFilters
                  ? 'No matching receipts'
                  : isStudent
                      ? 'No receipts found'
                      : 'No receipts found',
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 16.0, tablet: 17.0, desktop: 18.0),
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            ResponsiveText(
              style: TextStyle(),
              hasActiveFilters
                  ? 'Try adjusting your search or filters'
                  : isStudent
                      ? 'No payment receipts available yet'
                      : 'No payment receipts have been generated yet',
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 13.0, tablet: 14.0, desktop: 14.0),
              color: Colors.grey.shade500,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileReceiptList(List<Payment> payments) {
    return Padding(
      padding: ResponsiveUtils.getPadding(context),
      child: Column(
        children: payments
            .map((payment) => _buildMobileReceiptCard(payment))
            .toList(),
      ),
    );
  }

  Widget _buildDesktopReceiptList(List<Payment> payments) {
    return Padding(
      padding: ResponsiveUtils.getValue(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(18),
        desktop: const EdgeInsets.all(20),
      ),
      child: Column(
        children: payments
            .map((payment) => _buildDesktopReceiptCard(payment))
            .toList(),
      ),
    );
  }

  Widget _buildMobileReceiptCard(Payment payment) {
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) => inv.id == payment.invoiceId,
    );

    final student = userController.users.firstWhereOrNull(
      (user) => user.id == invoice?.studentId,
    );

    final studentName =
        '${student?.fname ?? 'Unknown'} ${student?.lname ?? 'Student'}';
    final reference = payment.reference ?? 'No Reference';
    final currentUser = authController.currentUser.value;
    final processedByText = currentUser != null
        ? '${currentUser.fname} ${currentUser.lname}'
        : 'System';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
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
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reference,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy - hh:mm a')
                            .format(payment.paymentDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payment.formattedAmount,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Student Info
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildHighlightedText(
                    studentName,
                    _searchQuery,
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Payment Method & Status Row
            Row(
              children: [
                _buildResponsiveInfoChip(
                  payment.method == 'mobile_payment'
                      ? 'Mobile Pay'
                      : payment.method.toUpperCase(),
                  Colors.blue.shade600,
                  payment.method == 'mobile_payment'
                      ? Icons.smartphone
                      : Icons.money,
                ),
                const SizedBox(width: 8),
                _buildResponsiveInfoChip(
                  payment.receiptGenerated
                      ? 'Receipt Generated'
                      : 'Pending Receipt',
                  payment.receiptGenerated
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                  payment.receiptGenerated ? Icons.check_circle : Icons.pending,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Actions Row
            Row(
              children: [
                Expanded(
                  child: _buildResponsiveActionButton(
                    'Print Receipt',
                    Icons.print,
                    Colors.green.shade600,
                    () => _printReceipt(payment),
                  ),
                ),
                if (!payment.receiptGenerated) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildResponsiveActionButton(
                      'Generate',
                      Icons.receipt_long,
                      Colors.green.shade600,
                      () => _generateReceipt(payment),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Processed By Info
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Processed by $processedByText',
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

  Widget _buildDesktopReceiptCard(Payment payment) {
    final invoice = billingController.invoices.firstWhereOrNull(
      (inv) => inv.id == payment.invoiceId,
    );

    final student = userController.users.firstWhereOrNull(
      (user) => user.id == invoice?.studentId,
    );

    final studentName =
        '${student?.fname ?? 'Unknown'} ${student?.lname ?? 'Student'}';
    final reference = payment.reference ?? 'No Reference';
    final currentUser = authController.currentUser.value;
    final processedByText = currentUser != null
        ? '${currentUser.fname} ${currentUser.lname}'
        : 'System';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: payment.receiptGenerated
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    payment.receiptGenerated
                        ? Icons.receipt
                        : Icons.receipt_outlined,
                    color: payment.receiptGenerated
                        ? Colors.green.shade600
                        : Colors.orange.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHighlightedText(
                        reference,
                        _searchQuery,
                        const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM dd, yyyy - hh:mm a')
                            .format(payment.paymentDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    payment.formattedAmount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Details Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildHighlightedText(
                        studentName,
                        _searchQuery,
                        const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildResponsiveInfoChip(
                        payment.method == 'mobile_payment'
                            ? 'Mobile Pay'
                            : payment.method.toUpperCase(),
                        Colors.blue.shade600,
                        payment.method == 'mobile_payment'
                            ? Icons.smartphone
                            : Icons.money,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildResponsiveInfoChip(
                        payment.receiptGenerated ? 'Generated' : 'Pending',
                        payment.receiptGenerated
                            ? Colors.green.shade600
                            : Colors.orange.shade600,
                        payment.receiptGenerated
                            ? Icons.check_circle
                            : Icons.pending,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Processed By',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        processedByText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Actions Row
            Row(
              children: [
                _buildResponsiveActionButton(
                  'View Receipt',
                  Icons.visibility,
                  Colors.blue.shade600,
                  () => _viewReceipt(payment),
                ),
                if (!payment.receiptGenerated) ...[
                  const SizedBox(width: 12),
                  _buildResponsiveActionButton(
                    'Generate Receipt',
                    Icons.receipt_long,
                    Colors.green.shade600,
                    () => _generateReceipt(payment),
                  ),
                ],
                const SizedBox(width: 12),
                _buildResponsiveActionButton(
                  'Download PDF',
                  Icons.download,
                  Colors.purple.shade600,
                  () => _downloadReceiptPDF(payment),
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
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildResponsiveInfoChip(String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getValue(context,
            mobile: 6.0, tablet: 7.0, desktop: 8.0),
        vertical: ResponsiveUtils.getValue(context,
            mobile: 3.0, tablet: 3.5, desktop: 4.0),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: ResponsiveUtils.getValue(context,
                  mobile: 10.0, tablet: 11.0, desktop: 12.0),
              color: color),
          const SizedBox(width: 4),
          Flexible(
            child: ResponsiveText(
              style: TextStyle(),
              label,
              fontSize: ResponsiveUtils.getValue(context,
                  mobile: 9.0, tablet: 9.5, desktop: 10.0),
              fontWeight: FontWeight.bold,
              color: color,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon,
          size: ResponsiveUtils.getValue(context,
              mobile: 14.0, tablet: 15.0, desktop: 16.0)),
      label: ResponsiveText(
        style: TextStyle(),
        label,
        fontSize: ResponsiveUtils.getValue(context,
            mobile: 11.0, tablet: 11.5, desktop: 12.0),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getValue(context,
              mobile: 8.0, tablet: 10.0, desktop: 12.0),
          vertical: ResponsiveUtils.getValue(context,
              mobile: 6.0, tablet: 7.0, desktop: 6.0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(
          fontSize: ResponsiveUtils.getValue(context,
              mobile: 11.0, tablet: 11.5, desktop: 12.0),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Simplified filtering - only search
  List<Payment> _getFilteredPayments() {
    List<Payment> filteredPayments = billingController.payments.toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredPayments = filteredPayments.where((payment) {
        final invoice = billingController.invoices.firstWhereOrNull(
          (inv) => inv.id == payment.invoiceId,
        );
        final student = userController.users.firstWhereOrNull(
          (user) => user.id == invoice?.studentId,
        );

        final studentName =
            '${student?.fname ?? ''} ${student?.lname ?? ''}'.toLowerCase();
        final reference = (payment.reference ?? '').toLowerCase();
        final amount = payment.formattedAmount.toLowerCase();
        final method = payment.method.toLowerCase();

        return studentName.contains(_searchQuery) ||
            reference.contains(_searchQuery) ||
            amount.contains(_searchQuery) ||
            method.contains(_searchQuery);
      }).toList();
    }

    // Sort by date (newest first)
    filteredPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    return filteredPayments;
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty;
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  // Action methods (maintain original functionality)
  void _viewReceipt(Payment payment) async {
    if (payment.receiptPath != null && payment.receiptPath!.isNotEmpty) {
      try {
        await ReceiptService.printReceiptFromCloud(payment.receiptPath!);
      } catch (e) {
        _showErrorSnackbar('Failed to view receipt: ${e.toString()}');
      }
    } else {
      _showErrorSnackbar(
          'Receipt file not found. Please generate receipt first.');
    }
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

      // Find the student
      final student = userController.users.firstWhereOrNull(
        (user) => user.id == invoice.studentId,
      );

      if (student == null) {
        _showErrorSnackbar('Student not found');
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

      // Create receipt items
      final receiptItems = [
        ReceiptItem(
          itemName: course.name,
          quantity: 1,
          unitPrice: payment.amount.toDouble(),
          totalPrice: payment.amount.toDouble(),
        ),
      ];

      // Use PrintService to print
      await PrintService.printReceipt(
        receiptNumber:
            payment.reference ?? payment.receiptNumber ?? 'RCP-${payment.id}',
        student: student,
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

  void _generateReceipt(Payment payment) async {
    try {
      _showLoadingSnackbar('Generating receipt...');

      // Find the invoice for this payment
      final invoice = billingController.invoices.firstWhereOrNull(
        (inv) => inv.id == payment.invoiceId,
      );

      if (invoice == null) {
        _showErrorSnackbar('Invoice not found for this payment');
        return;
      }

      // Find the student for this invoice
      final student = userController.users.firstWhereOrNull(
        (user) => user.id == invoice.studentId,
      );

      if (student == null) {
        _showErrorSnackbar('Student not found for this invoice');
        return;
      }

      // Generate receipt using the correct method signature
      final receiptPath = await ReceiptService.generateAndUploadReceipt(
        payment,
        invoice,
        student,
      );

      // Update payment with receipt info in database
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'payments',
        {
          'receipt_path': receiptPath,
          'receipt_generated': 1,
          'receipt_generated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [payment.id],
      );

      // Refresh billing data
      await billingController.fetchBillingData();

      // Refresh the UI
      setState(() {});

      _showSuccessSnackbar('Receipt generated successfully!');
    } catch (e) {
      _showErrorSnackbar('Failed to generate receipt: ${e.toString()}');
    }
  }

  void _downloadReceiptPDF(Payment payment) async {
    if (payment.receiptPath != null && payment.receiptPath!.isNotEmpty) {
      try {
        await ReceiptService.shareReceiptFromCloud(payment.receiptPath!);
      } catch (e) {
        _showErrorSnackbar('Failed to download receipt: ${e.toString()}');
      }
    } else {
      _showErrorSnackbar(
          'Receipt file not found. Please generate receipt first.');
    }
  }

  // Helper methods for user feedback
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

  void _showLoadingSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
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
}

// Sticky Filter Header Delegate
class _StickyFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyFilterHeaderDelegate({required this.child});

  @override
  double get minExtent => 120.0; // Height for search bar + items count

  @override
  double get maxExtent => 120.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_StickyFilterHeaderDelegate oldDelegate) {
    return false;
  }
}
