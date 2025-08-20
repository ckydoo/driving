// lib/screens/users/graduation_screen.dart
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/models/schedule.dart';
import 'package:driving/models/invoice.dart';
import 'package:driving/models/payment.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class GraduationScreen extends StatefulWidget {
  final User student;

  const GraduationScreen({Key? key, required this.student}) : super(key: key);

  @override
  _GraduationScreenState createState() => _GraduationScreenState();
}

class _GraduationScreenState extends State<GraduationScreen> {
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final BillingController billingController = Get.find<BillingController>();
  final AuthController authController = Get.find<AuthController>();
  bool _isLoading = false;
  bool _isProcessing = false;
  List<Schedule> _remainingSchedules = [];
  List<Invoice> _outstandingInvoices = [];
  double _totalOutstandingBalance = 0.0;
  bool _canGraduate = false;
  String _graduationStatus = '';

  @override
  void initState() {
    super.initState();
    _checkGraduationEligibility();
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 768 && width < 1024;
  }

// Add these variables to track lesson completion
  int _totalLessonsCompleted = 0;
  int _minimumRequiredLessons = 1; // Default minimum - should be configurable
  List<String> _completedCourses = [];
  bool _hasCompletedRequiredLessons = false;

  Future<void> _checkGraduationEligibility() async {
    setState(() {
      _isLoading = true;
      _graduationStatus = 'Checking eligibility...';
    });

    try {
      // Refresh all data
      await billingController.fetchBillingData();
      await scheduleController.fetchSchedules();
      await courseController.fetchCourses();

      // 1. CHECK COMPLETED LESSONS (Most Important!)
      final completedSchedules = scheduleController.schedules
          .where((schedule) =>
              schedule.studentId == widget.student.id &&
              schedule.status == 'Completed' &&
              schedule.attended == true)
          .toList();

      _totalLessonsCompleted = completedSchedules.fold<int>(
          0, (sum, schedule) => sum + schedule.lessonsDeducted);

      _hasCompletedRequiredLessons =
          _totalLessonsCompleted >= _minimumRequiredLessons;

      // 2. CHECK REMAINING SCHEDULED LESSONS
      _remainingSchedules = scheduleController.schedules
          .where((schedule) =>
              schedule.studentId == widget.student.id &&
              schedule.status != 'Completed' &&
              schedule.status != 'Cancelled' &&
              schedule.start.isAfter(DateTime.now()))
          .toList();

      // 3. CHECK OUTSTANDING INVOICES/PAYMENTS
      _outstandingInvoices = billingController.invoices
          .where((invoice) =>
              invoice.studentId == widget.student.id && invoice.balance > 0)
          .toList();

      _totalOutstandingBalance = _outstandingInvoices.fold(
          0.0, (sum, invoice) => sum + invoice.balance);

      // 4. DETERMINE GRADUATION ELIGIBILITY (SIMPLIFIED)
      _canGraduate = _hasCompletedRequiredLessons &&
          _remainingSchedules.isEmpty &&
          _totalOutstandingBalance <= 0;

      // 5. SET STATUS MESSAGE
      if (_canGraduate) {
        _graduationStatus = 'Student is eligible for graduation!';
      } else {
        List<String> missing = [];

        if (!_hasCompletedRequiredLessons) {
          missing.add(
              'Needs ${_minimumRequiredLessons - _totalLessonsCompleted} more lessons');
        }

        if (_remainingSchedules.isNotEmpty) {
          missing.add('${_remainingSchedules.length} pending lessons');
        }

        if (_totalOutstandingBalance > 0) {
          missing.add(
              '\$${_totalOutstandingBalance.toStringAsFixed(2)} outstanding');
        }

        _graduationStatus = 'Missing requirements: ${missing.join(', ')}';
      }
    } catch (e) {
      _graduationStatus = 'Error checking eligibility: ${e.toString()}';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGraduation() async {
    // Show confirmation dialog
    final confirmed = await _showGraduationConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Update student status to 'Graduated' or move to alumni
      final updatedStudent = User(
        id: widget.student.id,
        fname: widget.student.fname,
        lname: widget.student.lname,
        email: widget.student.email,
        password: widget.student.password,
        phone: widget.student.phone,
        address: widget.student.address,
        date_of_birth: widget.student.date_of_birth,
        gender: widget.student.gender,
        idnumber: widget.student.idnumber,
        role: 'alumni', // Change role to alumni
        status: 'Graduated', // Update status
        created_at: widget.student.created_at,
      );

      // Update in database
      await DatabaseHelper.instance.updateUser(updatedStudent);

      // Add graduation record to timeline/history
      await _addGraduationRecord();

      // Refresh user data
      await userController.fetchUsers();

      setState(() {
        _isProcessing = false;
      });

      // Show success dialog
      await _showSuccessDialog();

      // Navigation is now handled in the success dialog
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      Get.snackbar(
        'Graduation Failed',
        'Failed to process graduation: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    }
  }

  Future<void> _showSuccessDialog() async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: 64,
                ),
              ),
              SizedBox(height: 24),

              // Success Title
              Text(
                'Graduation Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),

              // Success Message
              Text(
                '${widget.student.fname} ${widget.student.lname} has been successfully graduated and moved to alumni.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              // Celebration emoji
              Text(
                '🎓✨',
                style: TextStyle(fontSize: 32),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Close the success dialog

                  // Refresh students list
                  await userController.fetchUsers();

                  // Navigate back to students screen and clear navigation stack
                  Get.offAllNamed('/students');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Back to Students',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addGraduationRecord() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('timeline', {
        'studentId': widget.student.id,
        'event_type': 'graduation',
        'title': 'Student Graduated',
        'description':
            'Student ${widget.student.fname} ${widget.student.lname} successfully completed all requirements and graduated.',
        'created_at': DateTime.now().toIso8601String(),
        'created_by': authController.currentUser.value?.id ?? 0,
      });
    } catch (e) {
      print('Error adding graduation record: $e');
    }
  }

  Future<bool> _showGraduationConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.school, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Confirm Graduation'),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Are you sure you want to graduate ${widget.student.fname} ${widget.student.lname}?',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'This action will:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    _buildActionItem('• Move student to alumni status'),
                    _buildActionItem('• Mark student as graduated'),
                    _buildActionItem('• Add graduation record to timeline'),
                    _buildActionItem(
                        '• Student will be searchable in alumni section'),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[600]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This action cannot be easily undone.',
                              style: TextStyle(color: Colors.orange[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Confirm Graduation'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _buildActionItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(text),
    );
  }

  Future<void> _closeAllSchedules() async {
    if (_remainingSchedules.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Close All Schedules'),
              content: Text(
                  'This will cancel ${_remainingSchedules.length} remaining scheduled lessons. Are you sure?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('Close All'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      for (var schedule in _remainingSchedules) {
        await scheduleController.updateSchedule(
          schedule.copyWith(status: 'Cancelled'),
          silent: true,
        );
      }

      await _checkGraduationEligibility();

      Get.snackbar(
        'Schedules Closed',
        'All remaining schedules have been cancelled.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to close schedules: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _payRemainingBalance() async {
    if (_totalOutstandingBalance <= 0) return;

    // Navigate to payment screen or show payment dialog
    _showPaymentDialog();
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController amountController = TextEditingController(
            text: _totalOutstandingBalance.toStringAsFixed(2));
        String selectedMethod = 'Cash';

        return AlertDialog(
          title: Text('Pay Outstanding Balance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Cash', 'Mobile Money']
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedMethod = value!;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _processPayment(
                  double.tryParse(amountController.text) ?? 0.0,
                  selectedMethod,
                );
              },
              child: Text('Process Payment'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processPayment(double amount, String method) async {
    if (amount <= 0) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Process payment for each outstanding invoice proportionally
      double remainingAmount = amount;

      for (var invoice in _outstandingInvoices) {
        if (remainingAmount <= 0) break;

        final paymentAmount = remainingAmount >= invoice.balance
            ? invoice.balance
            : remainingAmount;

        // Create payment record
        final payment = Payment(
          invoiceId: invoice.id!,
          amount: paymentAmount,
          paymentDate: DateTime.now(),
          method: method,
          reference: 'GRAD-${DateTime.now().toUtc().millisecondsSinceEpoch}',
          notes: 'Graduation payment - remaining balance',
        );

        await billingController.recordPayment(payment, silent: true);
      }

      await _checkGraduationEligibility();

      Get.snackbar(
        'Payment Processed',
        'Payment of \$${amount.toStringAsFixed(2)} has been processed.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Payment Failed',
        'Failed to process payment: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);
    final isTablet = _isTablet(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: ResponsiveText(
          'Graduate Student',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(_graduationStatus),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStudentHeader(isMobile),
                  SizedBox(height: isMobile ? 16 : 24),
                  _buildStatusOverview(isMobile),
                  SizedBox(height: isMobile ? 16 : 24),
                  if (_remainingSchedules.isNotEmpty) ...[
                    _buildSchedulesSection(isMobile),
                    SizedBox(height: isMobile ? 16 : 24),
                  ],
                  if (_outstandingInvoices.isNotEmpty) ...[
                    _buildPaymentsSection(isMobile),
                    SizedBox(height: isMobile ? 16 : 24),
                  ],
                  _buildActionButtons(isMobile),
                ],
              ),
            ),
    );
  }

  Widget _buildStudentHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isMobile ? 30 : 40,
                backgroundColor: Colors.blue[100],
                child: Text(
                  '${widget.student.fname[0]}${widget.student.lname[0]}',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveText(
                      '${widget.student.fname} ${widget.student.lname}',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.student.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    Text(
                      'Student ID: ${widget.student.idnumber ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesSection(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Remaining Schedules (${_remainingSchedules.length})',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isProcessing ? null : _closeAllSchedules,
                icon: Icon(Icons.close_fullscreen, size: 16),
                label: Text('Close All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            constraints: BoxConstraints(
              maxHeight: isMobile ? 200 : 300,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _remainingSchedules.length,
              itemBuilder: (context, index) {
                final schedule = _remainingSchedules[index];
                final course = courseController.courses.firstWhereOrNull(
                  (c) => c.id == schedule.courseId,
                );

                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange[100],
                      child: Icon(Icons.schedule, color: Colors.orange[700]),
                    ),
                    title: Text(course?.name ?? 'Unknown Course'),
                    subtitle: Text(
                      '${DateFormat('MMM dd, yyyy - hh:mm a').format(schedule.start)}\nStatus: ${schedule.status}',
                    ),
                    isThreeLine: true,
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Outstanding Invoices',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isProcessing ? null : _payRemainingBalance,
                icon: Icon(Icons.payment, size: 16),
                label: Text('Pay All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            constraints: BoxConstraints(
              maxHeight: isMobile ? 200 : 300,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _outstandingInvoices.length,
              itemBuilder: (context, index) {
                final invoice = _outstandingInvoices[index];
                final course = courseController.courses.firstWhereOrNull(
                  (c) => c.id == invoice.courseId,
                );

                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: Icon(Icons.receipt_long, color: Colors.red[700]),
                    ),
                    title: Text('Invoice #${invoice.invoiceNumber}'),
                    subtitle: Text(
                      '${course?.name ?? 'Unknown Course'}\nDue: ${DateFormat('MMM dd, yyyy').format(invoice.dueDate)}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '\$${invoice.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Outstanding:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                Text(
                  '\$${_totalOutstandingBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Graduation Actions',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          if (isMobile)
            Column(
              children: [
                if (!_canGraduate && _remainingSchedules.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _closeAllSchedules,
                      icon: Icon(Icons.close_fullscreen),
                      label: Text('Close All Schedules'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (!_canGraduate && _totalOutstandingBalance > 0) ...[
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _payRemainingBalance,
                      icon: Icon(Icons.payment),
                      label: Text('Pay Outstanding Balance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_canGraduate && !_isProcessing)
                        ? _handleGraduation
                        : null,
                    icon: _isProcessing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.school),
                    label: Text(
                        _isProcessing ? 'Processing...' : 'Graduate Student'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _canGraduate ? Colors.blue[700] : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      textStyle:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                if (!_canGraduate && _remainingSchedules.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _closeAllSchedules,
                      icon: Icon(Icons.close_fullscreen),
                      label: Text('Close All Schedules'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (!_canGraduate &&
                    _remainingSchedules.isNotEmpty &&
                    _totalOutstandingBalance > 0)
                  SizedBox(width: 12),
                if (!_canGraduate && _totalOutstandingBalance > 0)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _payRemainingBalance,
                      icon: Icon(Icons.payment),
                      label: Text('Pay Outstanding Balance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (!_canGraduate &&
                    (_remainingSchedules.isNotEmpty ||
                        _totalOutstandingBalance > 0))
                  SizedBox(width: 12),
                Expanded(
                  flex: _canGraduate ? 1 : 0,
                  child: ElevatedButton.icon(
                    onPressed: (_canGraduate && !_isProcessing)
                        ? _handleGraduation
                        : null,
                    icon: _isProcessing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.school),
                    label: Text(
                        _isProcessing ? 'Processing...' : 'Graduate Student'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _canGraduate ? Colors.blue[700] : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      textStyle:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          if (!_canGraduate) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete all requirements above before graduation is available.',
                      style: TextStyle(color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusOverview(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: _canGraduate ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _canGraduate ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _canGraduate ? Icons.check_circle : Icons.warning_amber,
                color: _canGraduate ? Colors.green[600] : Colors.orange[600],
                size: isMobile ? 24 : 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Graduation Status',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color:
                        _canGraduate ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            _graduationStatus,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: _canGraduate ? Colors.green[700] : Colors.orange[700],
            ),
          ),
          SizedBox(height: 16),

          // SIMPLIFIED GRADUATION REQUIREMENTS CHECKLIST
          Text(
            'Graduation Requirements:',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),

          // Lessons Completed Requirement
          _buildRequirementItem(
            'Minimum Lessons Completed',
            '$_totalLessonsCompleted / $_minimumRequiredLessons lessons completed',
            _hasCompletedRequiredLessons,
            Icons.school,
          ),

          // No Remaining Schedules
          _buildRequirementItem(
            'No Pending Lessons',
            _remainingSchedules.isEmpty
                ? 'All lessons completed'
                : '${_remainingSchedules.length} lessons pending',
            _remainingSchedules.isEmpty,
            Icons.schedule,
          ),

          // No Outstanding Balance
          _buildRequirementItem(
            'No Outstanding Balance',
            _totalOutstandingBalance <= 0
                ? 'All payments completed'
                : '\$${_totalOutstandingBalance.toStringAsFixed(2)} outstanding',
            _totalOutstandingBalance <= 0,
            Icons.payment,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(
      String title, String subtitle, bool completed, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? Colors.green[600] : Colors.grey[400],
            size: 20,
          ),
          SizedBox(width: 8),
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: completed ? Colors.green[800] : Colors.grey[700],
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: completed ? Colors.green[600] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
