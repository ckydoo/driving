// lib/services/payment_sync_integration.dart - ENHANCED VERSION WITH SCHOOL STRUCTURE
// Replace your existing payment_sync_integration.dart with this enhanced version

import 'package:driving/services/enhanced_payment_sync_service.dart';
import 'package:driving/services/fixed_local_first_sync_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:get/get.dart';

/// Enhanced service to integrate payment sync with duplicate prevention
/// Works with school-based Firebase structure: schools/{schoolId}/payments
class PaymentSyncIntegration extends GetxService {
  static PaymentSyncIntegration get instance =>
      Get.find<PaymentSyncIntegration>();

  // Dependencies
  EnhancedPaymentSyncService? _enhancedPaymentSync;
  FixedLocalFirstSyncService? _multiTenantSync;
  SchoolConfigService? _schoolConfig;

  @override
  void onInit() {
    super.onInit();
    _initializeServices();
  }

  void _initializeServices() {
    try {
      // Register enhanced payment sync service if not already registered
      if (!Get.isRegistered<EnhancedPaymentSyncService>()) {
        Get.put(EnhancedPaymentSyncService(), permanent: true);
      }
      _enhancedPaymentSync = Get.find<EnhancedPaymentSyncService>();

      // Get existing multi-tenant sync service
      if (Get.isRegistered<FixedLocalFirstSyncService>()) {
        _multiTenantSync = Get.find<FixedLocalFirstSyncService>();
      }

      // Get school config service for proper Firebase paths
      if (Get.isRegistered<SchoolConfigService>()) {
        _schoolConfig = Get.find<SchoolConfigService>();
      }

      print(
          '✅ Enhanced Payment Sync Integration initialized with school structure');
    } catch (e) {
      print('❌ Failed to initialize Payment Sync Integration: $e');
    }
  }

  /// ✨ NEW: Fix duplicate payments immediately (ONLY LOCAL - NO FIREBASE)
  /// This method only works on local SQLite database to avoid creating wrong Firebase collections
  Future<void> fixDuplicatePaymentsNow() async {
    print('🚨 === FIXING PAYMENT DUPLICATES LOCALLY ONLY ===');
    print(
        '⚠️  This will ONLY fix local SQLite database, no Firebase operations');

    final db = await DatabaseHelper.instance.database;

    try {
      // Step 1: Remove duplicate payments by reference
      await _removeDuplicatesByReference(db);

      // Step 2: Remove duplicates by invoice+amount+date
      await _removeDuplicatesByInvoiceAmountDate(db);

      // Step 3: Recalculate all invoice balances to fix negatives
      await _fixInvoiceBalances(db);

      // Step 4: Mark all payments as unsynced to force proper re-sync later
      await _markPaymentsForResync(db);

      print('✅ Payment duplicates fixed successfully in local database!');
      print(
          '📝 Note: Run proper school-based sync later to sync with Firebase');
    } catch (e) {
      print('❌ Error fixing payment duplicates: $e');
      throw e;
    }
  }

  /// Remove duplicate payments based on reference field
  Future<void> _removeDuplicatesByReference(Database db) async {
    print('🔍 Removing duplicates by reference...');

    try {
      // Find all payments with duplicate references (excluding cash and empty references)
      final duplicates = await db.rawQuery('''
        SELECT reference, COUNT(*) as count, GROUP_CONCAT(id) as ids
        FROM payments 
        WHERE reference IS NOT NULL 
        AND reference != '' 
        AND method != 'cash'
        GROUP BY reference 
        HAVING COUNT(*) > 1
      ''');

      int totalRemoved = 0;

      for (final duplicate in duplicates) {
        final reference = duplicate['reference'] as String;
        final idsString = duplicate['ids'] as String;
        final ids = idsString.split(',').map(int.parse).toList();

        // Keep the first ID, delete the rest
        final keepId = ids.first;
        final deleteIds = ids.skip(1).toList();

        for (final deleteId in deleteIds) {
          await db.delete('payments', where: 'id = ?', whereArgs: [deleteId]);
          print(
              '🗑️ Deleted duplicate payment ID $deleteId (reference: $reference)');
          totalRemoved++;
        }

        print('✅ Kept payment ID $keepId for reference: $reference');
      }

      print('📊 Removed $totalRemoved duplicate payments by reference');
    } catch (e) {
      print('❌ Error removing duplicates by reference: $e');
    }
  }

  /// Remove duplicate payments by invoice+amount+date combination
  Future<void> _removeDuplicatesByInvoiceAmountDate(Database db) async {
    print('🔍 Removing duplicates by invoice+amount+date...');

    try {
      // Find payments with same invoice, amount, method on same day
      final duplicates = await db.rawQuery('''
        SELECT 
          invoiceId,
          ROUND(amount, 2) as rounded_amount,
          method,
          DATE(datetime(paymentDate/1000, 'unixepoch')) as payment_date,
          COUNT(*) as count,
          GROUP_CONCAT(id) as ids
        FROM payments 
        GROUP BY 
          invoiceId, 
          ROUND(amount, 2), 
          method,
          DATE(datetime(paymentDate/1000, 'unixepoch'))
        HAVING COUNT(*) > 1
      ''');

      int totalRemoved = 0;

      for (final duplicate in duplicates) {
        final invoiceId = duplicate['invoiceId'];
        final amount = duplicate['rounded_amount'];
        final method = duplicate['method'];
        final paymentDate = duplicate['payment_date'];
        final idsString = duplicate['ids'] as String;
        final ids = idsString.split(',').map(int.parse).toList();

        // Keep the first ID, delete the rest
        final keepId = ids.first;
        final deleteIds = ids.skip(1).toList();

        for (final deleteId in deleteIds) {
          await db.delete('payments', where: 'id = ?', whereArgs: [deleteId]);
          print(
              '🗑️ Deleted duplicate payment ID $deleteId (invoice: $invoiceId, amount: \$amount)');
          totalRemoved++;
        }

        print('✅ Kept payment ID $keepId');
      }

      print('📊 Removed $totalRemoved duplicate payments by details');
    } catch (e) {
      print('❌ Error removing duplicates by details: $e');
    }
  }

  /// Fix invoice balances after removing duplicates
  Future<void> _fixInvoiceBalances(Database db) async {
    print('🔄 Fixing invoice balances...');

    // Get all invoices that have payments
    final invoicesWithPayments = await db.rawQuery('''
      SELECT DISTINCT i.id, i.total_amount, i.lessons, i.price_per_lesson
      FROM invoices i
      INNER JOIN payments p ON i.id = p.invoiceId
    ''');

    int fixed = 0;

    for (final invoice in invoicesWithPayments) {
      final invoiceId = invoice['id'] as int;

      // Calculate actual total payments for this invoice
      final paymentSum = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total_paid
        FROM payments 
        WHERE invoiceId = ?
      ''', [invoiceId]);

      final totalPaid = (paymentSum.first['total_paid'] as num).toDouble();

      // Calculate total invoice amount
      final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ??
          ((invoice['lessons'] as num).toDouble() *
              (invoice['price_per_lesson'] as num).toDouble());

      // Determine correct status
      String status;
      if (totalPaid >= totalAmount) {
        status = 'paid';
      } else if (totalPaid > 0) {
        status = 'partial';
      } else {
        status = 'unpaid';
      }

      // Update the invoice
      await db.update(
        'invoices',
        {
          'amountpaid': totalPaid,
          'status': status,
          'last_modified': DateTime.now().millisecondsSinceEpoch,
          'firebase_synced': 0, // Force re-sync
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      print(
          '✅ Fixed invoice $invoiceId: \$${totalPaid.toStringAsFixed(2)} paid, status: $status');
      fixed++;
    }

    print('📊 Fixed $fixed invoice balances');
  }

  /// Mark payments for re-sync to use enhanced duplicate prevention
  Future<void> _markPaymentsForResync(Database db) async {
    print('🔄 Marking payments for re-sync...');

    final result = await db.update(
      'payments',
      {'firebase_synced': 0},
      where: 'firebase_synced = 1',
    );

    print('📊 Marked $result payments for re-sync');
  }

  /// ✨ ENHANCED: Add duplicate prevention to your existing sync methods
  Future<bool> isPaymentDuplicateBeforeSync(
      Map<String, dynamic> paymentData) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final reference = paymentData['reference'] as String?;
      final invoiceId = paymentData['invoiceId'] as int;
      final amount = (paymentData['amount'] as num).toDouble();
      final method = paymentData['method'] as String;
      final paymentDate = paymentData['paymentDate'] as int; // milliseconds

      // Check 1: Reference-based duplicate (for non-cash payments)
      if (reference != null && reference.isNotEmpty && method != 'cash') {
        final existingByReference = await db.query(
          'payments',
          where: 'reference = ?',
          whereArgs: [reference],
          limit: 1,
        );

        if (existingByReference.isNotEmpty) {
          print('🚫 Duplicate payment detected by reference: $reference');
          return true;
        }
      }

      // Check 2: Invoice + Amount + Date + Method combination
      // Allow some tolerance for date (within 1 hour)
      final tolerance = 60 * 60 * 1000; // 1 hour in milliseconds
      final startTime = paymentDate - tolerance;
      final endTime = paymentDate + tolerance;

      final existingByDetails = await db.query(
        'payments',
        where: '''
          invoiceId = ? 
          AND ABS(amount - ?) < 0.01 
          AND method = ?
          AND paymentDate BETWEEN ? AND ?
        ''',
        whereArgs: [invoiceId, amount, method, startTime, endTime],
        limit: 1,
      );

      if (existingByDetails.isNotEmpty) {
        print('🚫 Duplicate payment detected by invoice+amount+date+method');
        print(
            '   Invoice: $invoiceId, Amount: \$${amount.toStringAsFixed(2)}, Method: $method');
        return true;
      }

      return false;
    } catch (e) {
      print('⚠️ Error checking payment duplicate: $e');
      return false; // If check fails, allow the payment (safer)
    }
  }

  /// Enhanced manual sync with duplicate prevention and proper school structure
  Future<void> triggerEnhancedSync() async {
    print('🚀 === STARTING ENHANCED MANUAL SYNC WITH SCHOOL STRUCTURE ===');

    // Check if school is configured
    if (_schoolConfig == null || !_schoolConfig!.isInitialized.value) {
      print(
          '❌ School not configured - cannot sync to proper Firebase structure');
      throw Exception('School configuration required for proper sync');
    }

    final schoolId = _schoolConfig!.schoolId.value;
    print('🏫 Syncing for school: $schoolId');

    try {
      // Step 0: Clean existing duplicates first (LOCAL ONLY)
      print('🧹 Cleaning existing duplicates locally before sync...');
      await fixDuplicatePaymentsNow();

      // Step 1: Run enhanced payment/invoice sync with school structure
      if (_enhancedPaymentSync != null) {
        print(
            '💰 Running enhanced payment & invoice sync with school structure...');
        // The enhanced payment sync should use school-based paths
        await _enhancedPaymentSync!.syncInvoicesAndPayments();
      } else {
        print('⚠️ Enhanced payment sync not available');
      }

      // Step 2: Run standard multi-tenant sync for other data
      if (_multiTenantSync != null) {
        print('🏫 Running standard multi-tenant sync...');
        await _multiTenantSync!.syncWithFirebase();
      } else {
        print('⚠️ Multi-tenant sync not available');
      }

      // Step 3: Validate payment integrity
      if (_enhancedPaymentSync != null) {
        print('🔍 Validating payment integrity...');
        await _enhancedPaymentSync!.validatePaymentIntegrity();
      }

      print('✅ === ENHANCED MANUAL SYNC WITH SCHOOL STRUCTURE COMPLETED ===');
      print(
          '📝 Data synced to: schools/$schoolId/payments and schools/$schoolId/invoices');
    } catch (e) {
      print('❌ Enhanced manual sync failed: $e');
      throw e;
    }
  }

  /// Emergency sync for payment issues (Enhanced)
  Future<void> emergencyPaymentFix() async {
    print('🚨 === EMERGENCY PAYMENT FIX WITH DUPLICATE CLEANUP ===');

    try {
      // Step 1: Fix duplicates first
      await fixDuplicatePaymentsNow();

      // Step 2: Run existing emergency fix
      if (_enhancedPaymentSync != null) {
        await _enhancedPaymentSync!.emergencyPaymentSync();
        print('✅ Emergency payment fix with duplicate cleanup completed');
      } else {
        throw Exception('Enhanced payment sync service not available');
      }
    } catch (e) {
      print('❌ Emergency payment fix failed: $e');
      throw e;
    }
  }

  /// ✨ NEW: Validate payment before inserting (call this before any payment insert)
  Future<bool> validatePaymentBeforeInsert(
      Map<String, dynamic> paymentData) async {
    return !(await isPaymentDuplicateBeforeSync(paymentData));
  }

  /// Get duplicate report
  Future<Map<String, dynamic>> getDuplicateReport() async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Count reference-based duplicates
      final referenceDuplicates = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM (
          SELECT reference
          FROM payments 
          WHERE reference IS NOT NULL 
          AND reference != '' 
          AND method != 'cash'
          GROUP BY reference 
          HAVING COUNT(*) > 1
        )
      ''');

      // Count detail-based duplicates
      final detailDuplicates = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM (
          SELECT 
            invoiceId,
            ROUND(amount, 2),
            method,
            DATE(datetime(paymentDate/1000, 'unixepoch'))
          FROM payments 
          GROUP BY 
            invoiceId, 
            ROUND(amount, 2), 
            method,
            DATE(datetime(paymentDate/1000, 'unixepoch'))
          HAVING COUNT(*) > 1
        )
      ''');

      // Get total payments count
      final totalPayments =
          await db.rawQuery('SELECT COUNT(*) as count FROM payments');

      return {
        'reference_duplicates': referenceDuplicates.first['count'] ?? 0,
        'detail_duplicates': detailDuplicates.first['count'] ?? 0,
        'total_payments': totalPayments.first['count'] ?? 0,
      };
    } catch (e) {
      print('❌ Error generating duplicate report: $e');
      return {
        'error': e.toString(),
        'reference_duplicates': 0,
        'detail_duplicates': 0,
        'total_payments': 0,
      };
    }
  }

  // Keep your existing methods
  bool get isEnhancedSyncAvailable {
    return _enhancedPaymentSync != null && _multiTenantSync != null;
  }

  bool get isSyncing {
    return _multiTenantSync?.isSyncing.value ?? false;
  }

  DateTime get lastSyncTime {
    return _multiTenantSync?.lastSyncTime.value ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}
