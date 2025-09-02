// lib/services/enhanced_payment_sync_service.dart - Fixed Payment & Invoice Sync
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/payment_sync_integration.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class EnhancedPaymentSyncService extends GetxService {
  static EnhancedPaymentSyncService get instance =>
      Get.find<EnhancedPaymentSyncService>();

  FirebaseFirestore? _firestore;
  AuthController get _authController => Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    _initializeFirestore();
  }

  void _initializeFirestore() {
    try {
      _firestore = FirebaseFirestore.instance;
      print('✅ Enhanced Payment Sync Service initialized');
    } catch (e) {
      print('❌ Firestore initialization failed: $e');
    }
  }

  /// Main sync method for invoices and payments with proper partial payment handling
  Future<void> syncInvoicesAndPayments() async {
    if (_firestore == null) {
      throw Exception('Firestore not available');
    }

    print('🔄 === STARTING ENHANCED INVOICE & PAYMENT SYNC ===');

    try {
      // Step 1: Sync invoices first
      await _syncInvoices();

      // Step 2: Sync payments with proper validation
      await _syncPayments();

      // Step 3: Recalculate and sync invoice balances
      await _recalculateInvoiceBalances();

      print('✅ === ENHANCED SYNC COMPLETED SUCCESSFULLY ===');
    } catch (e) {
      print('❌ Enhanced sync failed: $e');
      throw e;
    }
  }

  /// Sync invoices bidirectionally
  Future<void> _syncInvoices() async {
    print('📄 Syncing invoices...');

    final db = await DatabaseHelper.instance.database;
    final userId = _authController.currentFirebaseUserId;

    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Upload local unsynced invoices
      await _uploadUnsyncedInvoices(db, userId);

      // Download remote invoice changes
      await _downloadRemoteInvoices(db, userId);

      print('✅ Invoice sync completed');
    } catch (e) {
      print('❌ Invoice sync failed: $e');
      throw e;
    }
  }

  /// Upload unsynced invoices to Firebase
  Future<void> _uploadUnsyncedInvoices(Database db, String userId) async {
    print('📤 Uploading unsynced invoices...');

    final unsyncedInvoices = await db.query(
      'invoices',
      where: 'firebase_synced IS NULL OR firebase_synced = 0',
    );

    if (unsyncedInvoices.isEmpty) {
      print('📭 No unsynced invoices to upload');
      return;
    }

    print('📤 Found ${unsyncedInvoices.length} unsynced invoices');

    final collection = _firestore!.collection('invoices');
    int successCount = 0;

    for (final invoice in unsyncedInvoices) {
      try {
        final docId = invoice['id'].toString();
        final firebaseData = _convertInvoiceToFirebase(invoice, userId);

        await collection.doc(docId).set(firebaseData, SetOptions(merge: true));

        // Mark as synced
        await db.update(
          'invoices',
          {
            'firebase_synced': 1,
            'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [invoice['id']],
        );

        successCount++;
        print('📤 Uploaded invoice ${invoice['id']}');
      } catch (e) {
        print('❌ Failed to upload invoice ${invoice['id']}: $e');
      }
    }

    print('✅ Uploaded $successCount invoices successfully');
  }

  /// Download remote invoice changes
  Future<void> _downloadRemoteInvoices(Database db, String userId) async {
    print('📥 Downloading remote invoices...');

    try {
      final query = _firestore!
          .collection('invoices')
          .where('user_id', isEqualTo: userId)
          .orderBy('last_modified', descending: true);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        print('📭 No remote invoices found');
        return;
      }

      print('📥 Found ${snapshot.docs.length} remote invoices');

      for (final doc in snapshot.docs) {
        try {
          await _mergeRemoteInvoice(db, doc);
        } catch (e) {
          print('❌ Failed to merge invoice ${doc.id}: $e');
        }
      }

      print('✅ Downloaded invoice changes successfully');
    } catch (e) {
      print('❌ Failed to download invoices: $e');
      throw e;
    }
  }

  /// Merge remote invoice with local data
  Future<void> _mergeRemoteInvoice(
      Database db, QueryDocumentSnapshot doc) async {
    final remoteData = doc.data() as Map<String, dynamic>;
    final invoiceId = int.parse(doc.id);

    // Check if invoice exists locally
    final existingInvoice = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
    );

    final localData = _convertFirebaseToInvoice(remoteData);
    localData['firebase_synced'] = 1;

    if (existingInvoice.isEmpty) {
      // Insert new invoice
      await db.insert('invoices', localData);
      print('📥 Inserted new invoice $invoiceId');
    } else {
      // Check timestamps and merge if remote is newer
      final localModified = existingInvoice.first['last_modified'] as int? ?? 0;
      final remoteModified =
          (remoteData['last_modified'] as Timestamp?)?.millisecondsSinceEpoch ??
              0;

      if (remoteModified > localModified) {
        await db.update(
          'invoices',
          localData,
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
        print('📥 Updated invoice $invoiceId with newer remote data');
      } else {
        print('⚠️ Local invoice $invoiceId is newer, keeping local version');
      }
    }
  }

  /// Sync payments with enhanced partial payment handling
  Future<void> _syncPayments() async {
    print('💰 Syncing payments with enhanced partial payment handling...');

    final db = await DatabaseHelper.instance.database;
    final userId = _authController.currentFirebaseUserId;

    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Upload local unsynced payments
      await _uploadUnsyncedPayments(db, userId);

      // Download remote payment changes
      await _downloadRemotePayments(db, userId);

      print('✅ Payment sync completed');
    } catch (e) {
      print('❌ Payment sync failed: $e');
      throw e;
    }
  }

  Future<void> _uploadUnsyncedPayments(Database db, String userId) async {
    print(
        '📤 Uploading unsynced payments with reference-based duplicate prevention...');

    final unsyncedPayments = await db.query(
      'payments',
      where: 'firebase_synced IS NULL OR firebase_synced = 0',
      orderBy: 'id ASC', // Process in order
    );

    if (unsyncedPayments.isEmpty) {
      print('📭 No unsynced payments to upload');
      return;
    }

    print('📤 Found ${unsyncedPayments.length} unsynced payments');

    final collection = _firestore!.collection('payments');
    int successCount = 0;
    int duplicateCount = 0;

    for (final payment in unsyncedPayments) {
      try {
        final paymentId = payment['id'] as int;
        final reference = payment['reference'] as String?;

        // ✅ Check 1: Does document already exist in Firebase?
        final existingDoc = await collection.doc(paymentId.toString()).get();

        if (existingDoc.exists) {
          print(
              '⏭️ Payment $paymentId already exists in Firebase, marking as synced');
          await db.update(
            'payments',
            {'firebase_synced': 1},
            where: 'id = ?',
            whereArgs: [paymentId],
          );
          successCount++;
          continue;
        }

        // ✅ Check 2: Reference-based duplicate check (like users email checking)
        if (reference != null &&
            reference.isNotEmpty &&
            payment['method'] != 'cash') {
          final referenceQuery = await collection
              .where('reference', isEqualTo: reference)
              .where('user_id', isEqualTo: userId)
              .limit(1)
              .get();

          if (referenceQuery.docs.isNotEmpty) {
            final existingPayment = referenceQuery.docs.first;
            final existingData = existingPayment.data();

            print('🔍 Found existing payment with reference: $reference');

            // Compare amounts and invoice IDs to determine if it's truly the same payment
            final localAmount = (payment['amount'] as num).toDouble();
            final remoteAmount = (existingData['amount'] as num).toDouble();
            final localInvoiceId = payment['invoiceId'] as int;
            final remoteInvoiceId = existingData['invoice_id'] as int;

            if ((localAmount - remoteAmount).abs() < 0.01 &&
                localInvoiceId == remoteInvoiceId) {
              // Same payment - delete the local duplicate
              print(
                  '🗑️ Deleting local duplicate payment $paymentId (reference: $reference)');

              await db.delete(
                'payments',
                where: 'id = ?',
                whereArgs: [paymentId],
              );

              duplicateCount++;
              continue;
            } else {
              print(
                  '⚠️ Reference collision but different payment details - will upload with modified reference');
              // Generate new reference to avoid collision
              final timestamp =
                  DateTime.now().millisecondsSinceEpoch.toString().substring(8);
              final newReference = '${reference}_$timestamp';

              await db.update(
                'payments',
                {'reference': newReference},
                where: 'id = ?',
                whereArgs: [paymentId],
              );

              print('🔄 Updated local payment reference to: $newReference');
            }
          }
        }

        // ✅ Upload the payment
        final firebaseData = _convertPaymentToFirebase(payment, userId);
        await collection
            .doc(paymentId.toString())
            .set(firebaseData, SetOptions(merge: true));

        // Mark as synced
        await db.update(
          'payments',
          {
            'firebase_synced': 1,
            'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [paymentId],
        );

        successCount++;
        print(
            '📤 Uploaded payment $paymentId for invoice ${payment['invoiceId']}');
      } catch (e) {
        print('❌ Failed to upload payment ${payment['id']}: $e');
      }
    }

    print(
        '✅ Upload complete: $successCount uploaded, $duplicateCount duplicates removed');
  }

  /// ✨ ENHANCED: Download remote payments with duplicate prevention
  /// REPLACE your existing _downloadRemotePayments method with this one:
  Future<void> _downloadRemotePayments(Database db, String userId) async {
    print('📥 Downloading remote payments with duplicate prevention...');

    try {
      final query = _firestore!
          .collection('payments')
          .where('user_id', isEqualTo: userId)
          .orderBy('payment_date', descending: false);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        print('📭 No remote payments found');
        return;
      }

      print('📥 Found ${snapshot.docs.length} remote payments');

      int insertedCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;
      int duplicateCount = 0;

      for (final doc in snapshot.docs) {
        try {
          final remoteData = doc.data() as Map<String, dynamic>;
          final paymentId = int.parse(doc.id);

          // Convert to local format
          final localData = _convertFirebaseToPayment(remoteData);
          localData['firebase_synced'] = 1;

          // ✅ Check if payment exists locally by ID
          final existingById = await db.query(
            'payments',
            where: 'id = ?',
            whereArgs: [paymentId],
            limit: 1,
          );

          if (existingById.isNotEmpty) {
            // Payment exists - check if we need to update
            final existing = existingById.first;
            final localModified = existing['last_modified'] as int? ?? 0;
            final remoteModified = localData['last_modified'] as int? ?? 0;

            if (remoteModified > localModified) {
              await db.update(
                'payments',
                {
                  'firebase_synced': 1,
                  'notes': localData['notes'],
                  'reference': localData['reference'],
                  'last_modified': remoteModified,
                },
                where: 'id = ?',
                whereArgs: [paymentId],
              );
              print('📥 Updated payment $paymentId');
              updatedCount++;
            } else {
              print('⏭️ Skipped payment $paymentId (local is newer)');
              skippedCount++;
            }
            continue;
          }

          // ✅ Check for duplicates by reference (similar to users duplicate checking)
          final reference = localData['reference'] as String?;
          if (reference != null &&
              reference.isNotEmpty &&
              localData['method'] != 'cash') {
            final existingByReference = await db.query(
              'payments',
              where: 'reference = ?',
              whereArgs: [reference],
              limit: 1,
            );

            if (existingByReference.isNotEmpty) {
              final existing = existingByReference.first;
              final existingAmount = (existing['amount'] as num).toDouble();
              final newAmount = (localData['amount'] as num).toDouble();
              final existingInvoice = existing['invoiceId'] as int;
              final newInvoice = localData['invoiceId'] as int;

              if ((existingAmount - newAmount).abs() < 0.01 &&
                  existingInvoice == newInvoice) {
                print('🚫 Duplicate payment detected by reference: $reference');
                duplicateCount++;
                continue;
              }
            }
          }

          // ✅ Check for duplicates by invoice+amount+date (additional safety)
          final invoiceId = localData['invoiceId'] as int;
          final amount = (localData['amount'] as num).toDouble();
          final paymentDate = localData['paymentDate'] as int;
          final method = localData['method'] as String;

          // Check within 1 hour tolerance
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
            print('🚫 Duplicate payment detected by details');
            print(
                '   Invoice: $invoiceId, Amount: \$${amount.toStringAsFixed(2)}, Method: $method');
            duplicateCount++;
            continue;
          }

          // ✅ Safe to insert new payment
          await db.insert('payments', localData);
          print(
              '📥 Inserted new payment $paymentId for invoice ${localData['invoiceId']}');
          insertedCount++;
        } catch (e) {
          print('❌ Failed to merge payment ${doc.id}: $e');
          skippedCount++;
        }
      }

      print(
          '✅ Download complete: $insertedCount inserted, $updatedCount updated, $skippedCount skipped, $duplicateCount duplicates prevented');
    } catch (e) {
      print('❌ Failed to download payments: $e');
      throw e;
    }
  }

  /// ✨ NEW: Helper method to convert Firebase payment data to local format
  Map<String, dynamic> _convertFirebaseToPayment(
      Map<String, dynamic> firebaseData) {
    final localData = Map<String, dynamic>.from(firebaseData);

    // Handle field name conversions
    if (localData.containsKey('invoice_id')) {
      localData['invoiceId'] = localData['invoice_id'];
      localData.remove('invoice_id');
    }

    if (localData.containsKey('payment_date')) {
      if (localData['payment_date'] is Timestamp) {
        localData['paymentDate'] =
            (localData['payment_date'] as Timestamp).millisecondsSinceEpoch;
      } else if (localData['payment_date'] is int) {
        localData['paymentDate'] = localData['payment_date'];
      }
      localData.remove('payment_date');
    }

    if (localData.containsKey('user_id')) {
      localData['userId'] = localData['user_id'];
      localData.remove('user_id');
    }

    // Ensure required fields have default values
    localData['firebase_synced'] = 1;
    localData['last_modified'] ??= DateTime.now().millisecondsSinceEpoch;

    return localData;
  }

  /// ✨ NEW: Helper method to convert local payment data to Firebase format
  Map<String, dynamic> _convertPaymentToFirebase(
      Map<String, dynamic> paymentData, String userId) {
    final firebaseData = Map<String, dynamic>.from(paymentData);

    // Convert field names
    if (firebaseData.containsKey('invoiceId')) {
      firebaseData['invoice_id'] = firebaseData['invoiceId'];
      firebaseData.remove('invoiceId');
    }

    if (firebaseData.containsKey('paymentDate')) {
      final paymentDate = firebaseData['paymentDate'] as int;
      firebaseData['payment_date'] =
          Timestamp.fromMillisecondsSinceEpoch(paymentDate);
      firebaseData.remove('paymentDate');
    }

    if (firebaseData.containsKey('userId')) {
      firebaseData.remove('userId'); // Don't need local user ID in Firebase
    }

    // Add Firebase-specific fields
    firebaseData['user_id'] = userId;
    firebaseData['created_at'] =
        firebaseData['payment_date'] ?? Timestamp.now();
    firebaseData['last_modified'] = Timestamp.fromMillisecondsSinceEpoch(
        firebaseData['last_modified'] ?? DateTime.now().millisecondsSinceEpoch);

    // Remove local-only fields
    firebaseData.remove('firebase_synced');
    firebaseData.remove('id'); // Don't include local ID in document data

    return firebaseData;
  }

  /// ✨ ENHANCED: Emergency payment sync with duplicate cleanup
  /// REPLACE your existing emergencyPaymentSync method with this one:
  Future<void> emergencyPaymentSync() async {
    print('🚨 === EMERGENCY PAYMENT SYNC WITH DUPLICATE CLEANUP ===');

    try {
      // Step 0: Clean existing duplicates first
      await _cleanExistingPaymentDuplicates();

      // Step 1: Validate current state
      await validatePaymentIntegrity();

      // Step 2: Recalculate all invoice balances
      await _recalculateInvoiceBalances();

      // Step 3: Full sync with duplicate prevention
      await syncInvoicesAndPayments();

      // Step 4: Re-validate
      await validatePaymentIntegrity();

      print('✅ Emergency payment sync with duplicate cleanup completed');
    } catch (e) {
      print('❌ Emergency payment sync failed: $e');
      throw e;
    }
  }

  /// ✨ NEW: Clean existing payment duplicates (internal method)
  Future<void> _cleanExistingPaymentDuplicates() async {
    print('🧹 Cleaning existing payment duplicates...');

    final db = await DatabaseHelper.instance.database;

    try {
      // Use the same logic as PaymentSyncIntegration
      final integration = PaymentSyncIntegration.instance;
      await integration.fixDuplicatePaymentsNow();
    } catch (e) {
      print('⚠️ Error during duplicate cleanup: $e');
      // Continue with sync even if cleanup fails
    }
  }

  /// ✨ NEW: Check if payment would be duplicate before inserting
  Future<bool> wouldBePaymentDuplicate(Map<String, dynamic> paymentData) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final reference = paymentData['reference'] as String?;
      final invoiceId = paymentData['invoiceId'] as int;
      final amount = (paymentData['amount'] as num).toDouble();
      final method = paymentData['method'] as String;
      final paymentDate = paymentData['paymentDate'] as int? ??
          DateTime.now().millisecondsSinceEpoch;

      // Check 1: Reference-based duplicate (for non-cash payments)
      if (reference != null && reference.isNotEmpty && method != 'cash') {
        final existingByReference = await db.query(
          'payments',
          where: 'reference = ?',
          whereArgs: [reference],
          limit: 1,
        );

        if (existingByReference.isNotEmpty) {
          print('🚫 Would be duplicate: reference already exists: $reference');
          return true;
        }
      }

      // Check 2: Invoice + Amount + Date + Method combination
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
        print(
            '🚫 Would be duplicate: same invoice+amount+date+method combination exists');
        return true;
      }

      return false;
    } catch (e) {
      print('⚠️ Error checking if payment would be duplicate: $e');
      return false; // If check fails, allow the payment (safer)
    }
  }

  /// ✨ NEW: Get comprehensive payment sync status
  Future<Map<String, dynamic>> getPaymentSyncStatus() async {
    final db = await DatabaseHelper.instance.database;

    try {
      // Count total payments
      final totalPayments = await db.query('payments');

      // Count synced vs unsynced
      final synced = await db.query('payments', where: 'firebase_synced = 1');
      final unsynced = await db.query('payments',
          where: 'firebase_synced = 0 OR firebase_synced IS NULL');

      // Count potential reference duplicates
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

      // Count potential detail duplicates
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

      // Check invoice balance integrity
      final invoiceIntegrityIssues = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM (
          SELECT 
            i.id,
            i.amountpaid as invoice_amount_paid,
            COALESCE(SUM(p.amount), 0) as actual_payments_total
          FROM invoices i
          LEFT JOIN payments p ON i.id = p.invoiceId
          GROUP BY i.id, i.amountpaid
          HAVING ABS(i.amountpaid - COALESCE(SUM(p.amount), 0)) > 0.01
        )
      ''');

      return {
        'total_payments': totalPayments.length,
        'synced_payments': synced.length,
        'unsynced_payments': unsynced.length,
        'sync_percentage': totalPayments.isEmpty
            ? 0
            : (synced.length / totalPayments.length * 100).round(),
        'reference_duplicates': referenceDuplicates.first['count'] ?? 0,
        'detail_duplicates': detailDuplicates.first['count'] ?? 0,
        'invoice_integrity_issues': invoiceIntegrityIssues.first['count'] ?? 0,
        'last_check': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': 'Failed to get sync status: $e',
        'last_check': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Merge remote payment with local data with conflict resolution
  Future<void> _mergeRemotePayment(
      Database db, QueryDocumentSnapshot doc) async {
    final remoteData = doc.data() as Map<String, dynamic>;
    final paymentId = int.parse(doc.id);

    // Check if payment exists locally
    final existingPayment = await db.query(
      'payments',
      where: 'id = ?',
      whereArgs: [paymentId],
    );

    final localData = _convertFirebaseToPayment(remoteData);
    localData['firebase_synced'] = 1;

    if (existingPayment.isEmpty) {
      // Insert new payment
      await db.insert('payments', localData);
      print(
          '📥 Inserted new payment $paymentId for invoice ${localData['invoiceId']}');
    } else {
      // Check for conflicts - payments should be immutable once created
      final existingData = existingPayment.first;

      // Compare key fields
      final amountMatch =
          (existingData['amount'] as double).toStringAsFixed(2) ==
              (localData['amount'] as double).toStringAsFixed(2);
      final invoiceMatch = existingData['invoiceId'] == localData['invoiceId'];
      final methodMatch = existingData['method'] == localData['method'];

      if (!amountMatch || !invoiceMatch || !methodMatch) {
        print('⚠️ PAYMENT CONFLICT DETECTED for payment $paymentId');
        print(
            '   Local: amount=${existingData['amount']}, invoice=${existingData['invoiceId']}, method=${existingData['method']}');
        print(
            '   Remote: amount=${localData['amount']}, invoice=${localData['invoiceId']}, method=${localData['method']}');

        // For now, keep local version but log the conflict
        // In production, you might want to implement a conflict resolution strategy
        print('   → Keeping local version, but this needs manual review');
      } else {
        // Update non-critical fields only
        await db.update(
          'payments',
          {
            'firebase_synced': 1,
            'notes': localData['notes'],
            'reference': localData['reference'],
          },
          where: 'id = ?',
          whereArgs: [paymentId],
        );
        print('📥 Updated payment $paymentId metadata');
      }
    }
  }

  /// Recalculate invoice balances after payment sync
  Future<void> _recalculateInvoiceBalances() async {
    print('🔄 Recalculating invoice balances...');

    final db = await DatabaseHelper.instance.database;

    try {
      // Get all invoices that might have payment changes
      final invoices = await db.rawQuery('''
        SELECT DISTINCT i.id, i.total_amount, i.lessons, i.price_per_lesson, i.amountpaid
        FROM invoices i
        WHERE i.firebase_synced = 1
      ''');

      int updatedCount = 0;

      for (final invoice in invoices) {
        final invoiceId = invoice['id'] as int;

        // Calculate total payments for this invoice
        final paymentResult = await db.rawQuery('''
          SELECT COALESCE(SUM(amount), 0) as total_paid
          FROM payments 
          WHERE invoiceId = ?
        ''', [invoiceId]);

        final totalPaid =
            (paymentResult.first['total_paid'] as num?)?.toDouble() ?? 0.0;

        // Calculate total amount (handle both old and new schema)
        final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ??
            ((invoice['lessons'] as num).toDouble() *
                (invoice['price_per_lesson'] as num).toDouble());

        // Calculate current amount paid from database
        final currentAmountPaid =
            (invoice['amountpaid'] as num?)?.toDouble() ?? 0.0;

        // Check if recalculation is needed
        if ((totalPaid - currentAmountPaid).abs() > 0.01) {
          // Allow for small rounding differences
          print(
              '🔄 Recalculating invoice $invoiceId: DB shows $currentAmountPaid, payments total $totalPaid');

          // Determine status
          String status;
          if (totalPaid >= totalAmount) {
            status = 'paid';
          } else if (totalPaid > 0) {
            status = 'partial';
          } else {
            status = 'unpaid';
          }

          // Update invoice
          await db.update(
            'invoices',
            {
              'amountpaid': totalPaid,
              'status': status,
              'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
              'firebase_synced': 0, // Mark for re-sync since we updated it
            },
            where: 'id = ?',
            whereArgs: [invoiceId],
          );

          updatedCount++;
          print(
              '✅ Updated invoice $invoiceId: amount_paid=$totalPaid, status=$status');
        }
      }

      if (updatedCount > 0) {
        print('✅ Recalculated $updatedCount invoice balances');
        // Re-sync the updated invoices
        await _uploadUnsyncedInvoices(
            db, _authController.currentFirebaseUserId!);
      } else {
        print('✅ All invoice balances are correct');
      }
    } catch (e) {
      print('❌ Failed to recalculate invoice balances: $e');
      throw e;
    }
  }

  /// Convert local invoice data to Firebase format
  Map<String, dynamic> _convertInvoiceToFirebase(
      Map<String, dynamic> invoice, String userId) {
    final data = Map<String, dynamic>.from(invoice);

    // Remove local-only fields
    data.remove('firebase_synced');
    data.remove('firebase_user_id');

    // Add Firebase-specific fields
    data['user_id'] = userId;
    data['sync_timestamp'] = FieldValue.serverTimestamp();

    // Convert timestamps
    if (data['created_at'] is String) {
      try {
        data['created_at'] =
            Timestamp.fromDate(DateTime.parse(data['created_at']));
      } catch (e) {
        data['created_at'] = FieldValue.serverTimestamp();
      }
    }

    if (data['last_modified'] is int) {
      data['last_modified'] =
          Timestamp.fromMillisecondsSinceEpoch(data['last_modified']);
    } else {
      data['last_modified'] = FieldValue.serverTimestamp();
    }

    return data;
  }

  /// Convert Firebase invoice data to local format
  Map<String, dynamic> _convertFirebaseToInvoice(
      Map<String, dynamic> firebase) {
    final data = Map<String, dynamic>.from(firebase);

    // Remove Firebase-specific fields
    data.remove('user_id');
    data.remove('sync_timestamp');

    // Convert timestamps back
    if (data['created_at'] is Timestamp) {
      data['created_at'] =
          (data['created_at'] as Timestamp).toDate().toIso8601String();
    }

    if (data['last_modified'] is Timestamp) {
      data['last_modified'] =
          (data['last_modified'] as Timestamp).millisecondsSinceEpoch;
    }

    return data;
  }

  /// Validate payment data integrity
  Future<void> validatePaymentIntegrity() async {
    print('🔍 Validating payment data integrity...');

    final db = await DatabaseHelper.instance.database;

    try {
      // Check for orphaned payments (payments without corresponding invoices)
      final orphanedPayments = await db.rawQuery('''
        SELECT p.id, p.invoiceId, p.amount 
        FROM payments p
        LEFT JOIN invoices i ON p.invoiceId = i.id
        WHERE i.id IS NULL
      ''');

      if (orphanedPayments.isNotEmpty) {
        print('⚠️ Found ${orphanedPayments.length} orphaned payments:');
        for (final payment in orphanedPayments) {
          print(
              '   Payment ${payment['id']} → Invoice ${payment['invoiceId']} (missing)');
        }
      }

      // Check for invoice/payment amount mismatches
      final mismatches = await db.rawQuery('''
        SELECT 
          i.id,
          i.amountpaid as invoice_amount_paid,
          COALESCE(SUM(p.amount), 0) as actual_payments_total,
          COUNT(p.id) as payment_count
        FROM invoices i
        LEFT JOIN payments p ON i.id = p.invoiceId
        GROUP BY i.id, i.amountpaid
        HAVING ABS(i.amountpaid - COALESCE(SUM(p.amount), 0)) > 0.01
      ''');

      if (mismatches.isNotEmpty) {
        print('⚠️ Found ${mismatches.length} invoice/payment mismatches:');
        for (final mismatch in mismatches) {
          print(
              '   Invoice ${mismatch['id']}: DB shows ${mismatch['invoice_amount_paid']}, payments total ${mismatch['actual_payments_total']}');
        }
      }

      if (orphanedPayments.isEmpty && mismatches.isEmpty) {
        print('✅ Payment data integrity is good');
      } else {
        print(
            '⚠️ Payment data integrity issues detected - consider running recalculation');
      }
    } catch (e) {
      print('❌ Failed to validate payment integrity: $e');
    }
  }

  /// Emergency fix for payment sync issues

  /// Enhanced method to sync payments with cloud receipts
  Future<void> syncPaymentsWithCloudReceipts() async {
    print('🔄 Starting enhanced payment sync with cloud receipts...');

    try {
      final db = await DatabaseHelper.instance.database;
      final userId = _authController.currentFirebaseUserId!;

      // Upload local payments to Firebase
      await _uploadPaymentsWithCloudReceipts(db, userId);

      // Download remote payments
      await _downloadRemotePaymentsWithCloudReceipts(db, userId);

      print('✅ Enhanced payment sync with cloud receipts completed');
    } catch (e) {
      print('❌ Enhanced payment sync failed: $e');
      rethrow;
    }
  }

  /// Upload payments with cloud receipt handling
  Future<void> _uploadPaymentsWithCloudReceipts(
      Database db, String userId) async {
    final unsynced = await db.query(
      'payments',
      where: 'firebase_synced = 0 AND (deleted IS NULL OR deleted = 0)',
    );

    if (unsynced.isEmpty) {
      print('📭 No unsynced payments to upload');
      return;
    }

    print(
        '📤 Uploading ${unsynced.length} payments with cloud receipt handling...');

    int successCount = 0;

    for (final payment in unsynced) {
      try {
        final paymentData = await _convertPaymentToFirebaseWithCloudReceipts(
            payment, userId); // Add await

        await _firestore!
            .collection('payments')
            .doc(payment['id'].toString())
            .set(paymentData, SetOptions(merge: true));

        // Mark as synced locally
        await db.update(
          'payments',
          {'firebase_synced': 1},
          where: 'id = ?',
          whereArgs: [payment['id']],
        );

        successCount++;
        print('📤 Uploaded payment ${payment['id']} with cloud receipt info');
      } catch (e) {
        print('❌ Failed to upload payment ${payment['id']}: $e');
      }
    }

    print('✅ Uploaded $successCount payments with cloud receipt handling');
  }

  /// Convert payment to Firebase format with cloud receipt handling
  Future<Map<String, dynamic>> _convertPaymentToFirebaseWithCloudReceipts(
      Map<String, dynamic> payment, String userId) async {
    final data = Map<String, dynamic>.from(payment);

    // Remove local-only fields
    data.remove('firebase_synced');
    data.remove('firebase_user_id');

    // Handle receipt information for cloud storage
    if (data['receipt_type'] == 'cloud' && data['receipt_path'] != null) {
      // Keep cloud URL - it's universal
      data['receipt_cloud_url'] = data['receipt_path'];
      data['receipt_storage_type'] = 'cloud';

      if (data['cloud_storage_path'] != null) {
        data['receipt_cloud_path'] = data['cloud_storage_path'];
      }

      // Remove device-specific fields
      data.remove(
          'receipt_path'); // Will be regenerated as cloud URL on other devices
    } else if (data['receipt_type'] == 'local' ||
        data['receipt_type'] == null) {
      // Mark that receipt exists but needs cloud generation
      data['receipt_needs_cloud_generation'] = data['receipt_generated'] == 1;
      data['receipt_storage_type'] = 'needs_cloud';
      data.remove('receipt_path'); // Remove local path
    }

    // Add Firebase-specific fields
    data['user_id'] = userId;
    data['sync_timestamp'] = FieldValue.serverTimestamp();
    data['sync_device'] = await DatabaseHelper.getDeviceId();

    // Convert timestamps
    _convertTimestampsToFirestore(data);

    return data;
  }

  /// Download remote payments with cloud receipt handling
  Future<void> _downloadRemotePaymentsWithCloudReceipts(
      Database db, String userId) async {
    print('📥 Downloading remote payments with cloud receipt handling...');

    try {
      final query = _firestore!
          .collection('payments')
          .where('user_id', isEqualTo: userId)
          .orderBy('payment_date', descending: false);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        print('📭 No remote payments found');
        return;
      }

      print('📥 Found ${snapshot.docs.length} remote payments');

      for (final doc in snapshot.docs) {
        try {
          await _mergeRemotePaymentWithCloudReceipts(db, doc);
        } catch (e) {
          print('❌ Failed to merge payment ${doc.id}: $e');
        }
      }

      print('✅ Downloaded payments with cloud receipt handling');
    } catch (e) {
      print('❌ Failed to download payments: $e');
      rethrow;
    }
  }

  /// Merge remote payment with cloud receipt handling
  Future<void> _mergeRemotePaymentWithCloudReceipts(
      Database db, QueryDocumentSnapshot doc) async {
    final remoteData = doc.data() as Map<String, dynamic>;
    final paymentId = int.parse(doc.id);

    // Check if payment exists locally
    final existing = await db.query(
      'payments',
      where: 'id = ?',
      whereArgs: [paymentId],
      limit: 1,
    );

    final localData = _convertFirebaseToPaymentWithCloudReceipts(remoteData);
    localData['firebase_synced'] = 1;

    if (existing.isEmpty) {
      // Insert new payment
      await db.insert('payments', localData);
      print('📥 Inserted new payment $paymentId with cloud receipt info');
    } else {
      // Update existing payment
      await db.update(
        'payments',
        localData,
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      print('📥 Updated payment $paymentId with cloud receipt info');
    }
  }

  /// Convert Firebase payment to local format with cloud receipt handling
  Map<String, dynamic> _convertFirebaseToPaymentWithCloudReceipts(
      Map<String, dynamic> firebase) {
    final data = Map<String, dynamic>.from(firebase);

    // Remove Firebase-specific fields
    data.remove('user_id');
    data.remove('sync_timestamp');
    data.remove('sync_device');

    // Handle cloud receipt information
    if (data['receipt_storage_type'] == 'cloud' &&
        data['receipt_cloud_url'] != null) {
      // Use cloud URL as receipt path
      data['receipt_path'] = data['receipt_cloud_url'];
      data['receipt_type'] = 'cloud';
      data['receipt_generated'] = 1;

      if (data['receipt_cloud_path'] != null) {
        data['cloud_storage_path'] = data['receipt_cloud_path'];
      }

      // Remove Firebase-specific receipt fields
      data.remove('receipt_cloud_url');
      data.remove('receipt_cloud_path');
      data.remove('receipt_storage_type');
      data.remove('receipt_needs_cloud_generation');
    } else if (data['receipt_needs_cloud_generation'] == true) {
      // Receipt exists but needs to be generated in cloud
      data['receipt_generated'] = 1;
      data['receipt_type'] = 'needs_cloud';
      data['receipt_path'] = null; // Will be generated on demand

      data.remove('receipt_needs_cloud_generation');
      data.remove('receipt_storage_type');
    } else {
      // No receipt or unknown state
      data['receipt_type'] = 'local';
      data.remove('receipt_cloud_url');
      data.remove('receipt_cloud_path');
      data.remove('receipt_storage_type');
      data.remove('receipt_needs_cloud_generation');
    }

    // Convert timestamps back
    _convertTimestampsFromFirestore(data);

    return data;
  }

// Add these methods to your EnhancedPaymentSyncService class

  /// Convert timestamps to Firestore format
  void _convertTimestampsToFirestore(Map<String, dynamic> data) {
    if (data['payment_date'] is String) {
      try {
        data['payment_date'] =
            Timestamp.fromDate(DateTime.parse(data['payment_date']));
      } catch (e) {
        data['payment_date'] = FieldValue.serverTimestamp();
      }
    }

    if (data['last_modified'] is int) {
      data['last_modified'] =
          Timestamp.fromMillisecondsSinceEpoch(data['last_modified']);
    } else {
      data['last_modified'] = FieldValue.serverTimestamp();
    }

    if (data['created_at'] is String) {
      try {
        data['created_at'] =
            Timestamp.fromDate(DateTime.parse(data['created_at']));
      } catch (e) {
        data['created_at'] = FieldValue.serverTimestamp();
      }
    }

    if (data['receipt_generated_at'] is String) {
      try {
        data['receipt_generated_at'] =
            Timestamp.fromDate(DateTime.parse(data['receipt_generated_at']));
      } catch (e) {
        data.remove('receipt_generated_at');
      }
    }
  }

  /// Convert timestamps from Firestore format
  void _convertTimestampsFromFirestore(Map<String, dynamic> data) {
    if (data['payment_date'] is Timestamp) {
      data['payment_date'] =
          (data['payment_date'] as Timestamp).toDate().toIso8601String();
    }

    if (data['last_modified'] is Timestamp) {
      data['last_modified'] =
          (data['last_modified'] as Timestamp).millisecondsSinceEpoch;
    } else {
      data['last_modified'] = DateTime.now().millisecondsSinceEpoch;
    }

    if (data['created_at'] is Timestamp) {
      data['created_at'] =
          (data['created_at'] as Timestamp).toDate().toIso8601String();
    }

    if (data['receipt_generated_at'] is Timestamp) {
      data['receipt_generated_at'] = (data['receipt_generated_at'] as Timestamp)
          .toDate()
          .toIso8601String();
    }
  }
}
