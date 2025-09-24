import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class DatabaseIntegrityService {
  static const String _tag = 'DatabaseIntegrityService';

  /// Perform comprehensive database integrity check
  static Future<IntegrityReport> performIntegrityCheck() async {
    print('🔍 Starting database integrity check...');

    final report = IntegrityReport();
    final db = await DatabaseHelper.instance.database;

    try {
      // Check foreign key constraints
      await _checkForeignKeyConstraints(db, report);

      // Check for orphaned records
      await _checkOrphanedRecords(db, report);

      // Check data consistency
      await _checkDataConsistency(db, report);

      // Check for duplicate records
      await _checkDuplicateRecords(db, report);

      // Validate required fields
      await _validateRequiredFields(db, report);

      print('✅ Database integrity check completed');
      print('📊 Issues found: ${report.totalIssues}');
    } catch (e) {
      print('❌ Integrity check failed: $e');
      report.addError('Integrity check failed: $e');
    }

    return report;
  }

  /// Check foreign key constraints
  static Future<void> _checkForeignKeyConstraints(
      Database db, IntegrityReport report) async {
    try {
      print('🔗 Checking foreign key constraints...');

      // Check invoice -> student references
      final invalidInvoiceStudents = await db.rawQuery('''
        SELECT i.id, i.student 
        FROM invoices i 
        LEFT JOIN users u ON i.student = u.id 
        WHERE i.student IS NOT NULL AND u.id IS NULL
      ''');

      for (final row in invalidInvoiceStudents) {
        report.addForeignKeyIssue(
            'Invoice ${row['id']} references non-existent student ${row['student']}');
      }

      // Check invoice -> course references
      final invalidInvoiceCourses = await db.rawQuery('''
        SELECT i.id, i.course 
        FROM invoices i 
        LEFT JOIN courses c ON i.course = c.id 
        WHERE i.course IS NOT NULL AND c.id IS NULL
      ''');

      for (final row in invalidInvoiceCourses) {
        report.addForeignKeyIssue(
            'Invoice ${row['id']} references non-existent course ${row['course']}');
      }

      // Check payment -> invoice references
      final invalidPaymentInvoices = await db.rawQuery('''
        SELECT p.id, p.invoiceId 
        FROM payments p 
        LEFT JOIN invoices i ON p.invoiceId = i.id 
        WHERE p.invoiceId IS NOT NULL AND i.id IS NULL
      ''');

      for (final row in invalidPaymentInvoices) {
        report.addForeignKeyIssue(
            'Payment ${row['id']} references non-existent invoice ${row['invoiceId']}');
      }

      // Check schedule -> student references
      final invalidScheduleStudents = await db.rawQuery('''
        SELECT s.id, s.student 
        FROM schedules s 
        LEFT JOIN users u ON s.student = u.id 
        WHERE s.student IS NOT NULL AND u.id IS NULL
      ''');

      for (final row in invalidScheduleStudents) {
        report.addForeignKeyIssue(
            'Schedule ${row['id']} references non-existent student ${row['student']}');
      }

      // Check schedule -> instructor references
      final invalidScheduleInstructors = await db.rawQuery('''
        SELECT s.id, s.instructor 
        FROM schedules s 
        LEFT JOIN users u ON s.instructor = u.id 
        WHERE s.instructor IS NOT NULL AND u.id IS NULL
      ''');

      for (final row in invalidScheduleInstructors) {
        report.addForeignKeyIssue(
            'Schedule ${row['id']} references non-existent instructor ${row['instructor']}');
      }

      print('✅ Foreign key constraints checked');
    } catch (e) {
      print('❌ Error checking foreign key constraints: $e');
      report.addError('Failed to check foreign key constraints: $e');
    }
  }

  /// Check for orphaned records
  static Future<void> _checkOrphanedRecords(
      Database db, IntegrityReport report) async {
    try {
      print('🔍 Checking for orphaned records...');

      // Find payments without valid invoices
      final orphanedPayments = await db.rawQuery('''
        SELECT p.id 
        FROM payments p 
        LEFT JOIN invoices i ON p.invoiceId = i.id 
        WHERE p.invoiceId IS NOT NULL AND i.id IS NULL
      ''');

      for (final row in orphanedPayments) {
        report.addOrphanedRecord('Payment ${row['id']} has no valid invoice');
      }

      // Find schedules without valid students
      final orphanedSchedules = await db.rawQuery('''
        SELECT s.id 
        FROM schedules s 
        LEFT JOIN users u ON s.student = u.id 
        WHERE s.student IS NOT NULL AND u.id IS NULL
      ''');

      for (final row in orphanedSchedules) {
        report.addOrphanedRecord('Schedule ${row['id']} has no valid student');
      }

      print('✅ Orphaned records checked');
    } catch (e) {
      print('❌ Error checking orphaned records: $e');
      report.addError('Failed to check orphaned records: $e');
    }
  }

  /// Check data consistency
  static Future<void> _checkDataConsistency(
      Database db, IntegrityReport report) async {
    try {
      print('📊 Checking data consistency...');

      // Check invoice amount consistency
      final inconsistentInvoices = await db.rawQuery('''
        SELECT i.id, i.total_amount, i.amountpaid, 
               COALESCE(SUM(p.amount), 0) as actual_paid
        FROM invoices i 
        LEFT JOIN payments p ON i.id = p.invoiceId 
        GROUP BY i.id, i.total_amount, i.amountpaid
        HAVING ABS(i.amountpaid - actual_paid) > 0.01
      ''');

      for (final row in inconsistentInvoices) {
        report.addConsistencyIssue(
            'Invoice ${row['id']}: recorded paid amount (${row['amountpaid']}) '
            'doesn\'t match actual payments (${row['actual_paid']})');
      }

      // Check for negative amounts
      final negativeInvoices = await db.rawQuery('''
        SELECT id FROM invoices WHERE total_amount < 0 OR amountpaid < 0
      ''');

      for (final row in negativeInvoices) {
        report.addConsistencyIssue('Invoice ${row['id']} has negative amounts');
      }

      final negativePayments = await db.rawQuery('''
        SELECT id FROM payments WHERE amount < 0
      ''');

      for (final row in negativePayments) {
        report.addConsistencyIssue('Payment ${row['id']} has negative amount');
      }

      print('✅ Data consistency checked');
    } catch (e) {
      print('❌ Error checking data consistency: $e');
      report.addError('Failed to check data consistency: $e');
    }
  }

  /// Check for duplicate records
  static Future<void> _checkDuplicateRecords(
      Database db, IntegrityReport report) async {
    try {
      print('🔍 Checking for duplicate records...');

      // Check for duplicate users by email
      final duplicateEmails = await db.rawQuery('''
        SELECT email, COUNT(*) as count 
        FROM users 
        WHERE email IS NOT NULL AND email != ''
        GROUP BY email 
        HAVING COUNT(*) > 1
      ''');

      for (final row in duplicateEmails) {
        report.addDuplicateIssue(
            'Duplicate email: ${row['email']} (${row['count']} records)');
      }

      // Check for duplicate vehicle plates
      final duplicatePlates = await db.rawQuery('''
        SELECT carplate, COUNT(*) as count 
        FROM fleet 
        WHERE carplate IS NOT NULL AND carplate != ''
        GROUP BY carplate 
        HAVING COUNT(*) > 1
      ''');

      for (final row in duplicatePlates) {
        report.addDuplicateIssue(
            'Duplicate car plate: ${row['carplate']} (${row['count']} records)');
      }

      // Check for duplicate invoice numbers
      final duplicateInvoices = await db.rawQuery('''
        SELECT invoice_number, COUNT(*) as count 
        FROM invoices 
        WHERE invoice_number IS NOT NULL AND invoice_number != ''
        GROUP BY invoice_number 
        HAVING COUNT(*) > 1
      ''');

      for (final row in duplicateInvoices) {
        report.addDuplicateIssue(
            'Duplicate invoice number: ${row['invoice_number']} (${row['count']} records)');
      }

      print('✅ Duplicate records checked');
    } catch (e) {
      print('❌ Error checking duplicate records: $e');
      report.addError('Failed to check duplicate records: $e');
    }
  }

  /// Validate required fields
  static Future<void> _validateRequiredFields(
      Database db, IntegrityReport report) async {
    try {
      print('✅ Validating required fields...');

      // Check users
      final invalidUsers = await db.rawQuery('''
        SELECT id FROM users 
        WHERE fname IS NULL OR fname = '' OR email IS NULL OR email = ''
      ''');

      for (final row in invalidUsers) {
        report.addValidationIssue('User ${row['id']} missing required fields');
      }

      // Check invoices
      final invalidInvoices = await db.rawQuery('''
        SELECT id FROM invoices 
        WHERE student IS NULL OR total_amount IS NULL OR total_amount <= 0
      ''');

      for (final row in invalidInvoices) {
        report
            .addValidationIssue('Invoice ${row['id']} missing required fields');
      }

      // Check payments
      final invalidPayments = await db.rawQuery('''
        SELECT id FROM payments 
        WHERE amount IS NULL OR amount <= 0
      ''');

      for (final row in invalidPayments) {
        report
            .addValidationIssue('Payment ${row['id']} missing required fields');
      }

      print('✅ Required fields validated');
    } catch (e) {
      print('❌ Error validating required fields: $e');
      report.addError('Failed to validate required fields: $e');
    }
  }

  /// Fix orphaned payments by removing them
  static Future<int> fixOrphanedPayments() async {
    try {
      print('🔧 Fixing orphaned payments...');

      final db = await DatabaseHelper.instance.database;

      // Get orphaned payments before deletion for sync tracking
      final orphanedPayments = await db.rawQuery('''
        SELECT p.* 
        FROM payments p 
        LEFT JOIN invoices i ON p.invoiceId = i.id 
        WHERE p.invoiceId IS NOT NULL AND i.id IS NULL
      ''');

      // Track deletions for sync
      for (final payment in orphanedPayments) {
        await SyncService.trackChange('payments', payment, 'delete');
      }

      // Delete orphaned payments
      final deleteCount = await db.rawDelete('''
        DELETE FROM payments 
        WHERE id IN (
          SELECT p.id 
          FROM payments p 
          LEFT JOIN invoices i ON p.invoiceId = i.id 
          WHERE p.invoiceId IS NOT NULL AND i.id IS NULL
        )
      ''');

      print('✅ Fixed $deleteCount orphaned payments');
      return deleteCount;
    } catch (e) {
      print('❌ Error fixing orphaned payments: $e');
      return 0;
    }
  }

  /// Fix inconsistent invoice amounts
  static Future<int> fixInconsistentInvoiceAmounts() async {
    try {
      print('🔧 Fixing inconsistent invoice amounts...');

      final db = await DatabaseHelper.instance.database;
      int fixedCount = 0;

      // Get invoices with inconsistent amounts
      final inconsistentInvoices = await db.rawQuery('''
        SELECT i.id, i.total_amount, i.amountpaid, 
               COALESCE(SUM(p.amount), 0) as actual_paid
        FROM invoices i 
        LEFT JOIN payments p ON i.id = p.invoiceId 
        GROUP BY i.id, i.total_amount, i.amountpaid
        HAVING ABS(i.amountpaid - actual_paid) > 0.01
      ''');

      for (final row in inconsistentInvoices) {
        final invoiceId = row['id'] as int;
        final actualPaid = row['actual_paid'] as double;
        final totalAmount = row['total_amount'] as double;

        // Determine correct status
        String status;
        if (actualPaid >= totalAmount) {
          status = 'paid';
        } else if (actualPaid > 0) {
          status = 'partial';
        } else {
          status = 'pending';
        }

        // Update invoice
        await db.update(
          'invoices',
          {
            'amountpaid': actualPaid,
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // Track change for sync
        final updatedInvoice =
            await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
        if (updatedInvoice.isNotEmpty) {
          await SyncService.trackChange(
              'invoices', updatedInvoice.first, 'update');
        }

        fixedCount++;
        print('✅ Fixed invoice $invoiceId: $actualPaid paid, status: $status');
      }

      print('✅ Fixed $fixedCount inconsistent invoice amounts');
      return fixedCount;
    } catch (e) {
      print('❌ Error fixing inconsistent invoice amounts: $e');
      return 0;
    }
  }

  /// Remove duplicate records
  static Future<int> removeDuplicateRecords() async {
    try {
      print('🔧 Removing duplicate records...');

      final db = await DatabaseHelper.instance.database;
      int removedCount = 0;

      // Remove duplicate users (keep the first one)
      final duplicateUsers = await db.rawDelete('''
        DELETE FROM users 
        WHERE id NOT IN (
          SELECT MIN(id) 
          FROM users 
          GROUP BY email
        ) AND email IN (
          SELECT email 
          FROM users 
          GROUP BY email 
          HAVING COUNT(*) > 1
        )
      ''');

      removedCount += duplicateUsers;
      print('✅ Removed $duplicateUsers duplicate users');

      // Remove duplicate fleet records
      final duplicateFleet = await db.rawDelete('''
        DELETE FROM fleet 
        WHERE id NOT IN (
          SELECT MIN(id) 
          FROM fleet 
          GROUP BY carplate
        ) AND carplate IN (
          SELECT carplate 
          FROM fleet 
          GROUP BY carplate 
          HAVING COUNT(*) > 1
        )
      ''');

      removedCount += duplicateFleet;
      print('✅ Removed $duplicateFleet duplicate fleet records');

      print('✅ Total removed $removedCount duplicate records');
      return removedCount;
    } catch (e) {
      print('❌ Error removing duplicate records: $e');
      return 0;
    }
  }

  /// Perform automatic fixes for common issues
  static Future<FixResult> performAutomaticFixes() async {
    print('🔧 Performing automatic database fixes...');

    final fixResult = FixResult();

    try {
      // Fix orphaned payments
      fixResult.orphanedPaymentsFixed = await fixOrphanedPayments();

      // Fix inconsistent invoice amounts
      fixResult.inconsistentAmountsFixed =
          await fixInconsistentInvoiceAmounts();

      // Remove duplicate records
      fixResult.duplicatesRemoved = await removeDuplicateRecords();

      print('✅ Automatic fixes completed: ${fixResult.summary}');
    } catch (e) {
      print('❌ Error during automatic fixes: $e');
      fixResult.errors.add(e.toString());
    }

    return fixResult;
  }
}

/// Integrity report class
class IntegrityReport {
  final List<String> foreignKeyIssues = [];
  final List<String> orphanedRecords = [];
  final List<String> consistencyIssues = [];
  final List<String> duplicateIssues = [];
  final List<String> validationIssues = [];
  final List<String> errors = [];
  final DateTime timestamp = DateTime.now();

  void addForeignKeyIssue(String issue) => foreignKeyIssues.add(issue);
  void addOrphanedRecord(String record) => orphanedRecords.add(record);
  void addConsistencyIssue(String issue) => consistencyIssues.add(issue);
  void addDuplicateIssue(String issue) => duplicateIssues.add(issue);
  void addValidationIssue(String issue) => validationIssues.add(issue);
  void addError(String error) => errors.add(error);

  int get totalIssues =>
      foreignKeyIssues.length +
      orphanedRecords.length +
      consistencyIssues.length +
      duplicateIssues.length +
      validationIssues.length +
      errors.length;

  bool get hasIssues => totalIssues > 0;
  bool get isHealthy => !hasIssues;

  String get summary {
    if (isHealthy) return '✅ Database is healthy';

    final parts = <String>[];
    if (foreignKeyIssues.isNotEmpty)
      parts.add('${foreignKeyIssues.length} FK issues');
    if (orphanedRecords.isNotEmpty)
      parts.add('${orphanedRecords.length} orphaned');
    if (consistencyIssues.isNotEmpty)
      parts.add('${consistencyIssues.length} consistency');
    if (duplicateIssues.isNotEmpty)
      parts.add('${duplicateIssues.length} duplicates');
    if (validationIssues.isNotEmpty)
      parts.add('${validationIssues.length} validation');
    if (errors.isNotEmpty) parts.add('${errors.length} errors');

    return '⚠️ Issues found: ${parts.join(', ')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'total_issues': totalIssues,
      'is_healthy': isHealthy,
      'foreign_key_issues': foreignKeyIssues,
      'orphaned_records': orphanedRecords,
      'consistency_issues': consistencyIssues,
      'duplicate_issues': duplicateIssues,
      'validation_issues': validationIssues,
      'errors': errors,
    };
  }
}

/// Fix result class
class FixResult {
  int orphanedPaymentsFixed = 0;
  int inconsistentAmountsFixed = 0;
  int duplicatesRemoved = 0;
  final List<String> errors = [];
  final DateTime timestamp = DateTime.now();

  int get totalFixed =>
      orphanedPaymentsFixed + inconsistentAmountsFixed + duplicatesRemoved;
  bool get hasErrors => errors.isNotEmpty;
  bool get successful => totalFixed > 0 && !hasErrors;

  String get summary {
    if (totalFixed == 0 && errors.isEmpty) {
      return 'No issues found to fix';
    }

    final parts = <String>[];
    if (orphanedPaymentsFixed > 0)
      parts.add('$orphanedPaymentsFixed orphaned payments');
    if (inconsistentAmountsFixed > 0)
      parts.add('$inconsistentAmountsFixed inconsistent amounts');
    if (duplicatesRemoved > 0) parts.add('$duplicatesRemoved duplicates');

    String result =
        parts.isEmpty ? 'No fixes applied' : 'Fixed: ${parts.join(', ')}';

    if (hasErrors) {
      result += ' (${errors.length} errors occurred)';
    }

    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'total_fixed': totalFixed,
      'successful': successful,
      'orphaned_payments_fixed': orphanedPaymentsFixed,
      'inconsistent_amounts_fixed': inconsistentAmountsFixed,
      'duplicates_removed': duplicatesRemoved,
      'errors': errors,
    };
  }
}
