// lib/services/enhanced_payment_sync_service.dart - Fixed Payment & Invoice Sync
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/auth_controller.dart';
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

  /// Upload unsynced payments to Firebase
  Future<void> _uploadUnsyncedPayments(Database db, String userId) async {
    print('📤 Uploading unsynced payments...');

    final unsyncedPayments = await db.query(
      'payments',
      where: 'firebase_synced IS NULL OR firebase_synced = 0',
    );

    if (unsyncedPayments.isEmpty) {
      print('📭 No unsynced payments to upload');
      return;
    }

    print('📤 Found ${unsyncedPayments.length} unsynced payments');

    final collection = _firestore!.collection('payments');
    int successCount = 0;

    for (final payment in unsyncedPayments) {
      try {
        final docId = payment['id'].toString();
        final firebaseData = _convertPaymentToFirebase(payment, userId);

        await collection.doc(docId).set(firebaseData, SetOptions(merge: true));

        // Mark as synced
        await db.update(
          'payments',
          {
            'firebase_synced': 1,
            'last_modified': DateTime.now().toUtc().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [payment['id']],
        );

        successCount++;
        print(
            '📤 Uploaded payment ${payment['id']} for invoice ${payment['invoiceId']}');
      } catch (e) {
        print('❌ Failed to upload payment ${payment['id']}: $e');
      }
    }

    print('✅ Uploaded $successCount payments successfully');
  }

  /// Download remote payment changes with conflict resolution
  Future<void> _downloadRemotePayments(Database db, String userId) async {
    print('📥 Downloading remote payments...');

    try {
      final query = _firestore!
          .collection('payments')
          .where('user_id', isEqualTo: userId)
          .orderBy('payment_date',
              descending: false); // Order by payment date for proper sequencing

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        print('📭 No remote payments found');
        return;
      }

      print('📥 Found ${snapshot.docs.length} remote payments');

      // Group payments by invoice for better handling
      final Map<int, List<QueryDocumentSnapshot>> paymentsByInvoice = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final invoiceId = data['invoice_id'] as int;

        if (!paymentsByInvoice.containsKey(invoiceId)) {
          paymentsByInvoice[invoiceId] = [];
        }
        paymentsByInvoice[invoiceId]!.add(doc);
      }

      // Process payments by invoice to maintain proper sequence
      for (final invoiceId in paymentsByInvoice.keys) {
        final paymentsForInvoice = paymentsByInvoice[invoiceId]!;
        print(
            '📥 Processing ${paymentsForInvoice.length} payments for invoice $invoiceId');

        for (final doc in paymentsForInvoice) {
          try {
            await _mergeRemotePayment(db, doc);
          } catch (e) {
            print('❌ Failed to merge payment ${doc.id}: $e');
          }
        }
      }

      print('✅ Downloaded payment changes successfully');
    } catch (e) {
      print('❌ Failed to download payments: $e');
      throw e;
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

  /// Convert local payment data to Firebase format
  Map<String, dynamic> _convertPaymentToFirebase(
      Map<String, dynamic> payment, String userId) {
    final data = Map<String, dynamic>.from(payment);

    // Remove local-only fields
    data.remove('firebase_synced');

    // Add Firebase-specific fields
    data['user_id'] = userId;
    data['sync_timestamp'] = FieldValue.serverTimestamp();

    // Rename fields to match Firebase schema
    if (data.containsKey('invoiceId')) {
      data['invoice_id'] = data['invoiceId'];
      data.remove('invoiceId');
    }

    if (data.containsKey('created_at')) {
      data['payment_date'] = data['created_at'];
      data.remove('created_at');
    }

    // Convert timestamps
    if (data['payment_date'] is String) {
      try {
        data['payment_date'] =
            Timestamp.fromDate(DateTime.parse(data['payment_date']));
      } catch (e) {
        data['payment_date'] = FieldValue.serverTimestamp();
      }
    }

    return data;
  }

  /// Convert Firebase payment data to local format
  Map<String, dynamic> _convertFirebaseToPayment(
      Map<String, dynamic> firebase) {
    final data = Map<String, dynamic>.from(firebase);

    // Remove Firebase-specific fields
    data.remove('user_id');
    data.remove('sync_timestamp');

    // Rename fields back to local schema
    if (data.containsKey('invoice_id')) {
      data['invoiceId'] = data['invoice_id'];
      data.remove('invoice_id');
    }

    if (data.containsKey('payment_date')) {
      if (data['payment_date'] is Timestamp) {
        data['created_at'] =
            (data['payment_date'] as Timestamp).toDate().toIso8601String();
      }
      data.remove('payment_date');
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
  Future<void> emergencyPaymentSync() async {
    print('🚨 === EMERGENCY PAYMENT SYNC ===');

    try {
      // Step 1: Validate current state
      await validatePaymentIntegrity();

      // Step 2: Recalculate all invoice balances
      await _recalculateInvoiceBalances();

      // Step 3: Full sync
      await syncInvoicesAndPayments();

      // Step 4: Re-validate
      await validatePaymentIntegrity();

      print('✅ Emergency payment sync completed');
    } catch (e) {
      print('❌ Emergency payment sync failed: $e');
      throw e;
    }
  }
}
