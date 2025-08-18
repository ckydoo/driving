// lib/services/firebase_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';

class FirebaseSyncService extends GetxController {
  static FirebaseSyncService get instance => Get.find<FirebaseSyncService>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  final RxBool isOnline = false.obs;
  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Offline'.obs;
  final Rx<DateTime> lastSyncTime = DateTime.now().obs;

  bool _preventDuplicateUploads = true;
  bool _preventDuplicateDownloads = true;
  final Set<String> _processingUsers = {}; // Track users being processed

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;

  // Tables to sync - add/remove based on your needs
  final List<String> _syncTables = [
    'users',
    'courses',
    'schedules',
    'invoices',
    'payments',
    'billings',
    'attachments',
    'notes',
    'fleet',
    'notifications',
    'settings',
    'timeline',
    'usermessages'
  ];

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeFirestore();
    await _setupConnectivityListener();
    await _loadLastSyncTime();
    _startPeriodicSync();
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.onClose();
  }

  /// Initialize Firestore settings for offline persistence
  Future<void> _initializeFirestore() async {
    try {
      // Enable offline persistence
      await _firestore.enablePersistence();

      // Configure Firestore settings
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      print('Firestore initialized with offline persistence');
    } catch (e) {
      print('Error initializing Firestore: $e');
    }
  }

  /// Setup connectivity listener to detect online/offline status
  Future<void> _setupConnectivityListener() async {
    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _updateOnlineStatus(connectivityResult);

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateOnlineStatus,
      onError: (error) {
        print('Connectivity error: $error');
      },
    );
  }

  /// Update online status and trigger sync if connected
  void _updateOnlineStatus(ConnectivityResult result) {
    final wasOnline = isOnline.value;
    isOnline.value = result != ConnectivityResult.none;

    if (!wasOnline && isOnline.value) {
      syncStatus.value = 'Connected - Syncing...';
      _triggerSync();
    } else if (!isOnline.value) {
      syncStatus.value = 'Offline';
    }
  }

  /// Start periodic sync when online
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (isOnline.value && !isSyncing.value) {
        _triggerSync();
      }
    });
  }

  /// Trigger manual sync
  Future<void> triggerManualSync() async {
    if (!isOnline.value) {
      Get.snackbar(
        'Sync Error',
        'No internet connection available',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    await _triggerSync();
  }

  /// Main sync method - handles both upload and download
  Future<void> _triggerSync() async {
    if (isSyncing.value) return;

    try {
      isSyncing.value = true;
      syncStatus.value = 'Syncing...';

      // Step 1: Upload pending changes to Firestore
      await _uploadPendingChanges();

      // Step 2: Download changes from Firestore
      await _downloadChanges();

      // Step 3: Update last sync time
      lastSyncTime.value = DateTime.now();
      await _saveLastSyncTime();

      syncStatus.value = 'Synced';

      Get.snackbar(
        'Sync Complete',
        'Data synchronized successfully',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('Sync error: $e');
      syncStatus.value = 'Sync Failed';

      Get.snackbar(
        'Sync Error',
        'Failed to sync data: ${e.toString()}',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// Upload pending changes to Firestore
  Future<void> _uploadPendingChanges() async {
    print('📤 Starting enhanced upload with duplicate prevention...');

    // Step 1: Pre-upload duplicate cleanup
    await _performPreUploadDuplicateCheck();

    final db = await DatabaseHelper.instance.database;

    for (String table in _syncTables) {
      try {
        // Get validated pending records
        final records = await _getValidatedPendingRecords(table);

        if (records.isNotEmpty) {
          print('📦 Uploading ${records.length} validated records from $table');
          await _uploadRecordsWithDuplicatePrevention(table, records);
        }
      } catch (e) {
        print('❌ Error uploading $table: $e');
      }
    }

    print('✅ Enhanced upload complete');
  }

  /// Get validated pending records with duplicate filtering
  Future<List<Map<String, dynamic>>> _getValidatedPendingRecords(
      String table) async {
    final db = await DatabaseHelper.instance.database;

    // Get base pending records
    final hasTrackingColumns = await _hasTrackingColumns(table);
    List<Map<String, dynamic>> records;

    if (hasTrackingColumns) {
      records = await db.query(
        table,
        where:
            '(last_modified > ? OR firebase_synced = 0) AND (deleted IS NULL OR deleted = 0)',
        whereArgs: [lastSyncTime.value.millisecondsSinceEpoch],
        orderBy: 'created_at ASC', // Process older records first
      );
    } else {
      records = await db.query(table,
          where: table == 'users' ? 'deleted IS NULL OR deleted = 0' : '1=1');
    }

    // Special validation for users
    if (table == 'users') {
      return await _validateAndDeduplicateUsers(records);
    }

    return records;
  }

  /// Validate and deduplicate users before upload
  Future<List<Map<String, dynamic>>> _validateAndDeduplicateUsers(
      List<Map<String, dynamic>> users) async {
    print('🔍 Validating ${users.length} users for upload...');

    List<Map<String, dynamic>> validUsers = [];
    Set<String> seenEmails = {};
    Set<String> seenPhones = {};
    Set<String> seenIdNumbers = {};

    for (final user in users) {
      final email = user['email']?.toString().trim().toLowerCase();
      final phone = user['phone']?.toString().trim();
      final idnumber = user['idnumber']?.toString().trim();
      final userId = user['id'];

      // Basic validation
      if (email == null || email.isEmpty) {
        print('⚠️ Skipping user $userId - missing email');
        continue;
      }

      if (!_isValidEmail(email)) {
        print('⚠️ Skipping user $userId - invalid email format');
        continue;
      }

      // Local duplicate checking
      bool isDuplicate = false;
      String duplicateReason = '';

      if (seenEmails.contains(email)) {
        isDuplicate = true;
        duplicateReason = 'Duplicate email in batch';
      } else if (phone != null &&
          phone.isNotEmpty &&
          seenPhones.contains(phone)) {
        isDuplicate = true;
        duplicateReason = 'Duplicate phone in batch';
      } else if (idnumber != null &&
          idnumber.isNotEmpty &&
          seenIdNumbers.contains(idnumber)) {
        isDuplicate = true;
        duplicateReason = 'Duplicate ID number in batch';
      }

      if (isDuplicate) {
        print('⚠️ Skipping user $userId ($email) - $duplicateReason');
        continue;
      }

      // Add to tracking sets
      seenEmails.add(email);
      if (phone != null && phone.isNotEmpty) seenPhones.add(phone);
      if (idnumber != null && idnumber.isNotEmpty) seenIdNumbers.add(idnumber);

      validUsers.add(user);
    }

    print('✅ Validated ${validUsers.length}/${users.length} users for upload');
    return validUsers;
  }

  /// Upload records with enhanced duplicate prevention
  Future<void> _uploadRecordsWithDuplicatePrevention(
      String table, List<Map<String, dynamic>> records) async {
    const batchSize = 50; // Smaller batches for better error handling

    for (int i = 0; i < records.length; i += batchSize) {
      final endIndex =
          (i + batchSize < records.length) ? i + batchSize : records.length;
      final batchRecords = records.sublist(i, endIndex);

      print(
          '📦 Processing batch ${(i ~/ batchSize) + 1}: records ${i + 1}-$endIndex');

      if (table == 'users') {
        await _uploadUserBatchWithComprehensiveDuplicateCheck(batchRecords);
      } else {
        await _uploadRegularRecordBatch(table, batchRecords);
      }

      // Mark successfully uploaded records as synced
      await _markRecordsAsSynced(table, batchRecords);

      // Delay between batches
      if (i + batchSize < records.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  Future<void> _uploadRegularRecordBatch(
      String table, List<Map<String, dynamic>> records) async {
    final batch = _firestore.batch();

    for (final record in records) {
      try {
        final docRef =
            _firestore.collection(table).doc(record['id'].toString());
        final cleanRecord = _cleanRecordForFirebase(record);
        batch.set(docRef, cleanRecord, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ Error preparing record ${record['id']} for batch: $e');
      }
    }

    try {
      await batch.commit();
      print(
          '✅ Successfully uploaded batch of ${records.length} $table records');
    } catch (e) {
      print('❌ Batch upload failed for $table: $e');
      throw e;
    }
  }

  /// Upload user batch with comprehensive duplicate checking
  Future<void> _uploadUserBatchWithComprehensiveDuplicateCheck(
      List<Map<String, dynamic>> users) async {
    for (final user in users) {
      final userEmail = user['email']?.toString().trim();

      // Skip if already processing this user
      if (_processingUsers.contains(userEmail)) {
        print('⏳ Skipping $userEmail - already being processed');
        continue;
      }

      try {
        _processingUsers.add(userEmail!);
        await _uploadUserWithComprehensiveDuplicateCheck(user);
      } catch (e) {
        print('❌ Failed to upload user $userEmail: $e');
      } finally {
        _processingUsers.remove(userEmail);
      }
    }
  }

  Future<void> _uploadUserWithComprehensiveDuplicateCheck(
      Map<String, dynamic> user) async {
    try {
      final localId = user['id'];
      final email = user['email']?.toString().trim().toLowerCase();
      final phone = user['phone']?.toString().trim();
      final idnumber = user['idnumber']?.toString().trim();
      final firebaseUid = user['firebase_uid']?.toString();

      if (email == null || email.isEmpty) {
        print(
            '⚠️ Skipping user upload - no email provided for user ID: $localId');
        return;
      }

      print('🔍 Checking Firebase for duplicates: $email');

      String? documentId;
      Map<String, dynamic> cleanRecord = _cleanRecordForFirebase(user);

      // STEP 1: Check existing Firebase UID
      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        try {
          DocumentSnapshot existingDoc =
              await _firestore.collection('users').doc(firebaseUid).get();

          if (existingDoc.exists) {
            documentId = firebaseUid;
            print('✅ Found existing Firebase document: $email');
          }
        } catch (e) {
          print('⚠️ Error checking Firebase UID: $e');
        }
      }

      // STEP 2: Search by unique identifiers
      if (documentId == null) {
        // Check by email first (strongest identifier)
        final emailMatches = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (emailMatches.docs.isNotEmpty) {
          final existingUser =
              emailMatches.docs.first.data() as Map<String, dynamic>;
          final conflictAnalysis = _analyzeUserConflict(user, existingUser);

          if (conflictAnalysis['canMerge']) {
            documentId = emailMatches.docs.first.id;
            print('📧 Merging with existing user by email: $email');
          } else {
            print(
                '❌ Email conflict detected for $email: ${conflictAnalysis['reason']}');
            return; // Skip this user
          }
        }
      }

      // STEP 3: Check by phone if no email match
      if (documentId == null && phone != null && phone.isNotEmpty) {
        final phoneMatches = await _firestore
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

        if (phoneMatches.docs.isNotEmpty) {
          final existingUser =
              phoneMatches.docs.first.data() as Map<String, dynamic>;
          final conflictAnalysis = _analyzeUserConflict(user, existingUser);

          if (conflictAnalysis['canMerge']) {
            documentId = phoneMatches.docs.first.id;
            print('📱 Merging with existing user by phone: $phone');
          } else {
            print(
                '❌ Phone conflict detected for $phone: ${conflictAnalysis['reason']}');
            return; // Skip this user
          }
        }
      }

      // STEP 4: Check by ID number
      if (documentId == null && idnumber != null && idnumber.isNotEmpty) {
        final idMatches = await _firestore
            .collection('users')
            .where('idnumber', isEqualTo: idnumber)
            .limit(1)
            .get();

        if (idMatches.docs.isNotEmpty) {
          final existingUser =
              idMatches.docs.first.data() as Map<String, dynamic>;
          final conflictAnalysis = _analyzeUserConflict(user, existingUser);

          if (conflictAnalysis['canMerge']) {
            documentId = idMatches.docs.first.id;
            print('🆔 Merging with existing user by ID: $idnumber');
          } else {
            print(
                '❌ ID number conflict detected for $idnumber: ${conflictAnalysis['reason']}');
            return; // Skip this user
          }
        }
      }

      // STEP 5: Perform the upload/update
      cleanRecord['last_modified'] = FieldValue.serverTimestamp();
      cleanRecord['sync_device_id'] =
          await _getDeviceId(); // Track which device uploaded

      if (documentId != null) {
        // Update existing document
        await _firestore.collection('users').doc(documentId).set(
              cleanRecord,
              SetOptions(merge: true),
            );
        print('✅ Updated Firebase user: $email (Doc ID: $documentId)');
      } else {
        // Create new document
        DocumentReference docRef =
            await _firestore.collection('users').add(cleanRecord);
        documentId = docRef.id;
        print('✅ Created new Firebase user: $email (Doc ID: $documentId)');
      }

      // STEP 6: Update local record
      await _updateLocalRecordWithFirebaseId(localId, documentId);
    } catch (e) {
      print('❌ Error uploading user ${user['id']}: $e');
    }
  }

  /// Analyze potential user conflicts for merging decisions
  Map<String, dynamic> _analyzeUserConflict(
      Map<String, dynamic> localUser, Map<String, dynamic> firebaseUser) {
    final localName =
        '${localUser['fname']} ${localUser['lname']}'.toLowerCase().trim();
    final firebaseName = '${firebaseUser['fname']} ${firebaseUser['lname']}'
        .toLowerCase()
        .trim();

    final localEmail = localUser['email']?.toString().toLowerCase().trim();
    final firebaseEmail =
        firebaseUser['email']?.toString().toLowerCase().trim();

    final localPhone = localUser['phone']?.toString().trim();
    final firebasePhone = firebaseUser['phone']?.toString().trim();

    // Calculate similarity score
    int matchScore = 0;
    List<String> conflicts = [];

    // Name similarity
    if (localName == firebaseName) {
      matchScore += 3;
    } else if (_areNamesSimilar(localName, firebaseName)) {
      matchScore += 1;
    } else {
      conflicts.add('Different names: $localName vs $firebaseName');
    }

    // Email match
    if (localEmail == firebaseEmail) {
      matchScore += 3;
    } else if (localEmail != null && firebaseEmail != null) {
      conflicts.add('Different emails: $localEmail vs $firebaseEmail');
    }

    // Phone match
    if (localPhone == firebasePhone) {
      matchScore += 2;
    } else if (localPhone != null && firebasePhone != null) {
      conflicts.add('Different phones: $localPhone vs $firebasePhone');
    }

    // Decision logic
    bool canMerge = false;
    String reason = '';

    if (matchScore >= 3 && conflicts.length <= 1) {
      canMerge = true;
      reason = 'High similarity, safe to merge';
    } else if (conflicts.isEmpty && matchScore >= 1) {
      canMerge = true;
      reason = 'No conflicts detected';
    } else {
      canMerge = false;
      reason = 'Conflicts: ${conflicts.join('; ')}';
    }

    return {
      'canMerge': canMerge,
      'reason': reason,
      'matchScore': matchScore,
      'conflicts': conflicts,
    };
  }

  /// Enhanced download with duplicate prevention
  Future<void> _downloadChanges() async {
    print('📥 Starting enhanced download with duplicate prevention...');

    for (String table in _syncTables) {
      try {
        await _downloadTableChangesWithDuplicatePrevention(table);
      } catch (e) {
        print('❌ Error downloading $table: $e');
      }
    }

    print('✅ Enhanced download complete');
  }

  /// Get records that need to be synced to Firebase
  Future<List<Map<String, dynamic>>> _getPendingRecords(String table) async {
    final db = await DatabaseHelper.instance.database;

    // Check if table has sync tracking columns
    final hasTrackingColumns = await _hasTrackingColumns(table);

    if (hasTrackingColumns) {
      // Get records modified since last sync or never synced
      return await db.query(
        table,
        where: 'last_modified > ? OR firebase_synced = 0',
        whereArgs: [lastSyncTime.value.millisecondsSinceEpoch],
      );
    } else {
      // If no tracking columns, get all records (first-time sync)
      return await db.query(table);
    }
  }

  /// Check if table has sync tracking columns
  Future<bool> _hasTrackingColumns(String table) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final result = await db.rawQuery("PRAGMA table_info($table)");
      final columnNames = result.map((row) => row['name'] as String).toList();

      return columnNames.contains('last_modified') &&
          columnNames.contains('firebase_synced');
    } catch (e) {
      return false;
    }
  }

  /// Mark records as synced in local database
  Future<void> _markRecordsAsSynced(
      String table, List<Map<String, dynamic>> records) async {
    final db = await DatabaseHelper.instance.database;

    for (final record in records) {
      try {
        await db.update(
          table,
          {'firebase_synced': 1},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
      } catch (e) {
        // Table might not have tracking columns - this is OK
        print('Could not mark $table record as synced: $e');
      }
    }
  }

  /// Download table changes with duplicate prevention
  Future<void> _downloadTableChangesWithDuplicatePrevention(
      String table) async {
    try {
      Query query = _firestore.collection(table);

      // Only get changes since last sync
      if (lastSyncTime.value.millisecondsSinceEpoch > 0) {
        query = query.where(
          'last_modified',
          isGreaterThan: Timestamp.fromDate(lastSyncTime.value),
        );
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        print('📥 Downloading ${snapshot.docs.length} records for $table');

        if (table == 'users') {
          await _mergeDownloadedUsersWithDuplicatePrevention(snapshot.docs);
        } else {
          await _mergeDownloadedRecordsWithDuplicatePrevention(
              table, snapshot.docs);
        }
      }
    } catch (e) {
      print('❌ Error downloading $table changes: $e');
    }
  }

  /// Merge downloaded users with comprehensive duplicate prevention
  Future<void> _mergeDownloadedUsersWithDuplicatePrevention(
      List<QueryDocumentSnapshot> docs) async {
    final db = await DatabaseHelper.instance.database;

    for (final doc in docs) {
      try {
        final firebaseData = doc.data() as Map<String, dynamic>;
        final firebaseId = doc.id;
        final email = firebaseData['email']?.toString().trim().toLowerCase();

        if (email == null || email.isEmpty) {
          print('⚠️ Skipping Firebase user - no email');
          continue;
        }

        // Skip if we're already processing this user
        if (_processingUsers.contains(email)) {
          print('⏳ Skipping $email - already being processed');
          continue;
        }

        try {
          _processingUsers.add(email);
          await _mergeFirebaseUserSafely(firebaseData, firebaseId);
        } finally {
          _processingUsers.remove(email);
        }
      } catch (e) {
        print('❌ Error processing downloaded user ${doc.id}: $e');
      }
    }
  }

  /// Safely merge Firebase user with local database
  Future<void> _mergeFirebaseUserSafely(
      Map<String, dynamic> firebaseData, String firebaseId) async {
    final db = await DatabaseHelper.instance.database;
    final email = firebaseData['email']?.toString().trim().toLowerCase();
    final phone = firebaseData['phone']?.toString().trim();
    final idnumber = firebaseData['idnumber']?.toString().trim();

    try {
      // STEP 1: Check for existing local user by Firebase ID
      List<Map<String, dynamic>> existingByFirebaseId = await db.query(
        'users',
        where: 'firebase_uid = ? AND (deleted IS NULL OR deleted = 0)',
        whereArgs: [firebaseId],
        limit: 1,
      );

      if (existingByFirebaseId.isNotEmpty) {
        // Update existing record
        await _updateLocalUserFromFirebase(
            existingByFirebaseId.first['id'], firebaseData, firebaseId);
        return;
      }

      // STEP 2: Check for local user by email
      List<Map<String, dynamic>> existingByEmail = await db.query(
        'users',
        where: 'LOWER(email) = ? AND (deleted IS NULL OR deleted = 0)',
        whereArgs: [email],
        limit: 1,
      );

      if (existingByEmail.isNotEmpty) {
        final localUser = existingByEmail.first;
        final conflictAnalysis = _analyzeUserConflict(localUser, firebaseData);

        if (conflictAnalysis['canMerge']) {
          await _updateLocalUserFromFirebase(
              localUser['id'], firebaseData, firebaseId);
          print('📧 Merged Firebase user with local user by email: $email');
          return;
        } else {
          print(
              '❌ Cannot merge Firebase user by email: ${conflictAnalysis['reason']}');
          return;
        }
      }

      // STEP 3: Check by phone
      if (phone != null && phone.isNotEmpty) {
        List<Map<String, dynamic>> existingByPhone = await db.query(
          'users',
          where: 'phone = ? AND (deleted IS NULL OR deleted = 0)',
          whereArgs: [phone],
          limit: 1,
        );

        if (existingByPhone.isNotEmpty) {
          final localUser = existingByPhone.first;
          final conflictAnalysis =
              _analyzeUserConflict(localUser, firebaseData);

          if (conflictAnalysis['canMerge']) {
            await _updateLocalUserFromFirebase(
                localUser['id'], firebaseData, firebaseId);
            print('📱 Merged Firebase user with local user by phone: $phone');
            return;
          } else {
            print(
                '❌ Cannot merge Firebase user by phone: ${conflictAnalysis['reason']}');
            return;
          }
        }
      }

      // STEP 4: Check by ID number
      if (idnumber != null && idnumber.isNotEmpty) {
        List<Map<String, dynamic>> existingByIdNumber = await db.query(
          'users',
          where: 'idnumber = ? AND (deleted IS NULL OR deleted = 0)',
          whereArgs: [idnumber],
          limit: 1,
        );

        if (existingByIdNumber.isNotEmpty) {
          final localUser = existingByIdNumber.first;
          final conflictAnalysis =
              _analyzeUserConflict(localUser, firebaseData);

          if (conflictAnalysis['canMerge']) {
            await _updateLocalUserFromFirebase(
                localUser['id'], firebaseData, firebaseId);
            print('🆔 Merged Firebase user with local user by ID: $idnumber');
            return;
          } else {
            print(
                '❌ Cannot merge Firebase user by ID: ${conflictAnalysis['reason']}');
            return;
          }
        }
      }

      // STEP 5: Insert as new user if no conflicts
      await _insertNewUserFromFirebase(firebaseData, firebaseId);
      print('✅ Inserted new user from Firebase: $email');
    } catch (e) {
      print('❌ Error merging Firebase user $email: $e');
    }
  }

  /// Update local user from Firebase data
  Future<void> _updateLocalUserFromFirebase(
      int localId, Map<String, dynamic> firebaseData, String firebaseId) async {
    final db = await DatabaseHelper.instance.database;
    final sqliteData = _convertFirestoreToSqlite(firebaseData);

    sqliteData['firebase_uid'] = firebaseId;
    sqliteData['firebase_synced'] = 1;
    sqliteData['last_modified'] = DateTime.now().millisecondsSinceEpoch;
    sqliteData.remove('id'); // Don't overwrite local ID

    await db.update(
      'users',
      sqliteData,
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Insert new user from Firebase
  Future<void> _insertNewUserFromFirebase(
      Map<String, dynamic> firebaseData, String firebaseId) async {
    final db = await DatabaseHelper.instance.database;
    final sqliteData = _convertFirestoreToSqlite(firebaseData);

    sqliteData['firebase_uid'] = firebaseId;
    sqliteData['firebase_synced'] = 1;
    sqliteData['last_modified'] = DateTime.now().millisecondsSinceEpoch;
    sqliteData.remove('id'); // Let SQLite auto-increment

    await db.insert('users', sqliteData);
  }

  /// Merge non-user records with duplicate prevention
  Future<void> _mergeDownloadedRecordsWithDuplicatePrevention(
      String table, List<QueryDocumentSnapshot> docs) async {
    final db = await DatabaseHelper.instance.database;

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final firebaseId = doc.id;
        final sqliteData = _convertFirestoreToSqlite(data);

        // Try to get meaningful ID
        int? localId = int.tryParse(firebaseId);
        if (localId == null && data.containsKey('id')) {
          localId = int.tryParse(data['id'].toString());
        }

        if (localId != null) {
          // Check if exists locally
          final existing = await db.query(
            table,
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );

          sqliteData['firebase_synced'] = 1;
          sqliteData['last_modified'] = DateTime.now().millisecondsSinceEpoch;

          if (existing.isNotEmpty) {
            // Update existing
            sqliteData.remove('id');
            await db.update(table, sqliteData,
                where: 'id = ?', whereArgs: [localId]);
          } else {
            // Insert new
            sqliteData['id'] = localId;
            await db.insert(table, sqliteData);
          }
        } else {
          // Insert with auto-increment
          sqliteData.remove('id');
          sqliteData['firebase_synced'] = 1;
          sqliteData['last_modified'] = DateTime.now().millisecondsSinceEpoch;
          await db.insert(table, sqliteData);
        }
      } catch (e) {
        if (e.toString().contains('UNIQUE constraint failed')) {
          print('⚠️ Skipped duplicate $table record');
        } else {
          print('❌ Error merging $table record: $e');
        }
      }
    }
  }

  /// Pre-upload duplicate check and cleanup
  Future<void> _performPreUploadDuplicateCheck() async {
    print('🔍 Performing pre-upload duplicate check...');

    final db = await DatabaseHelper.instance.database;

    try {
      // Find and resolve email duplicates
      await _resolveLocalDuplicatesByField(db, 'email');

      // Find and resolve phone duplicates
      await _resolveLocalDuplicatesByField(db, 'phone');

      // Find and resolve ID number duplicates
      await _resolveLocalDuplicatesByField(db, 'idnumber');
    } catch (e) {
      print('❌ Pre-upload duplicate check failed: $e');
    }
  }

  /// Resolve local duplicates by specific field
  Future<void> _resolveLocalDuplicatesByField(Database db, String field) async {
    final duplicates = await db.rawQuery('''
      SELECT $field, GROUP_CONCAT(id) as user_ids, COUNT(*) as count
      FROM users 
      WHERE $field IS NOT NULL AND $field != '' 
      AND (deleted IS NULL OR deleted = 0)
      GROUP BY LOWER($field)
      HAVING count > 1
    ''');

    for (final duplicate in duplicates) {
      final fieldValue = duplicate[field] as String;
      final userIds =
          duplicate['user_ids'].toString().split(',').map(int.parse).toList();

      if (userIds.length > 1) {
        // Keep the oldest user, mark others as deleted
        final users = await db.query(
          'users',
          where:
              'id IN (${userIds.map((_) => '?').join(',')}) AND (deleted IS NULL OR deleted = 0)',
          whereArgs: userIds,
          orderBy: 'created_at ASC',
        );

        if (users.length > 1) {
          final keepUserId = users.first['id'];
          final duplicateIds = users.skip(1).map((u) => u['id']).toList();

          // Mark duplicates as deleted
          await db.execute('''
            UPDATE users 
            SET deleted = 1, 
                last_modified = ${DateTime.now().millisecondsSinceEpoch},
                firebase_synced = 0
            WHERE id IN (${duplicateIds.map((_) => '?').join(',')})
          ''', duplicateIds);

          print(
              '🧹 Resolved $field duplicate: kept user $keepUserId, deleted ${duplicateIds.length} duplicates');
        }
      }
    }
  }

  // Helper methods
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _areNamesSimilar(String name1, String name2) {
    final parts1 = name1.split(' ');
    final parts2 = name2.split(' ');

    if (parts1.length != parts2.length) return false;

    for (int i = 0; i < parts1.length; i++) {
      final part1 = parts1[i];
      final part2 = parts2[i];

      // Allow for abbreviations
      if (part1 != part2 &&
          !part1.startsWith(part2.substring(0, 1)) &&
          !part2.startsWith(part1.substring(0, 1))) {
        return false;
      }
    }
    return true;
  }

  Future<String> _getDeviceId() async {
    // You can implement device ID generation here
    // For now, return a simple identifier
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Download changes for a specific table
  Future<void> _downloadTableChanges(String table) async {
    try {
      // Get documents modified since last sync
      Query query = _firestore.collection(table);

      if (lastSyncTime.value.millisecondsSinceEpoch > 0) {
        query = query.where(
          'last_modified',
          isGreaterThan: Timestamp.fromDate(lastSyncTime.value),
        );
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        print('Downloading ${snapshot.docs.length} records for $table');
        await _mergeDownloadedRecords(table, snapshot.docs);
      }
    } catch (e) {
      print('Error downloading $table changes: $e');
    }
  }

  /// Add sync tracking columns to tables
  Future<void> addSyncTrackingToTables() async {
    final db = await DatabaseHelper.instance.database;

    for (String table in _syncTables) {
      try {
        // Add last_modified column
        await db.execute(
            'ALTER TABLE $table ADD COLUMN last_modified INTEGER DEFAULT 0');

        // Add firebase_synced column
        await db.execute(
            'ALTER TABLE $table ADD COLUMN firebase_synced INTEGER DEFAULT 0');

        print('Added sync tracking to $table');
      } catch (e) {
        // Columns might already exist
        print('Sync tracking columns may already exist in $table: $e');
      }
    }
  }

  /// Force full sync (useful for initial setup or data recovery)
  Future<void> forceFullSync() async {
    if (!isOnline.value) {
      Get.snackbar(
        'Sync Error',
        'No internet connection available',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    try {
      isSyncing.value = true;
      syncStatus.value = 'Full Sync in Progress...';

      // Reset last sync time to force full sync
      lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(0);

      await _triggerSync();

      Get.snackbar(
        'Full Sync Complete',
        'All data has been synchronized',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
      );
    } catch (e) {
      print('Full sync error: $e');
      Get.snackbar(
        'Full Sync Error',
        'Failed to perform full sync: ${e.toString()}',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// Save last sync time to SharedPreferences
  Future<void> _saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_sync_time', lastSyncTime.value.millisecondsSinceEpoch);
  }

  /// Load last sync time from SharedPreferences
  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getInt('last_sync_time') ?? 0;
    lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(savedTime);
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'isOnline': isOnline.value,
      'isSyncing': isSyncing.value,
      'syncStatus': syncStatus.value,
      'lastSyncTime': lastSyncTime.value,
      'syncTables': _syncTables,
    };
  }

  /// Clear all local data and re-download from Firebase
  Future<void> resetAndResync() async {
    if (!isOnline.value) {
      Get.snackbar(
        'Reset Error',
        'No internet connection available',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    try {
      isSyncing.value = true;
      syncStatus.value = 'Resetting Data...';

      final db = await DatabaseHelper.instance.database;

      // Clear all synced tables
      for (String table in _syncTables) {
        try {
          await db.delete(table);
          print('Cleared table: $table');
        } catch (e) {
          print('Error clearing $table: $e');
        }
      }

      // Reset sync time and force full download
      lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(0);
      await _downloadChanges();

      lastSyncTime.value = DateTime.now();
      await _saveLastSyncTime();

      syncStatus.value = 'Reset Complete';

      Get.snackbar(
        'Reset Complete',
        'Data has been reset and re-synchronized',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
      );
    } catch (e) {
      print('Reset error: $e');
      syncStatus.value = 'Reset Failed';

      Get.snackbar(
        'Reset Error',
        'Failed to reset data: ${e.toString()}',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// Upload records to Firestore with duplicate prevention
  Future<void> _uploadRecordsInBatches(
      String table, List<Map<String, dynamic>> records) async {
    const batchSize = 500;

    for (int i = 0; i < records.length; i += batchSize) {
      final batch = _firestore.batch();
      final endIndex =
          (i + batchSize < records.length) ? i + batchSize : records.length;
      final batchRecords = records.sublist(i, endIndex);

      for (final record in batchRecords) {
        try {
          if (table == 'users') {
            // Special handling for users to prevent duplicates
            await _uploadUserWithDuplicateCheck(record);
          } else {
            // Use record ID as document ID for other tables
            final docRef =
                _firestore.collection(table).doc(record['id'].toString());
            final cleanRecord = _cleanRecordForFirebase(record);
            batch.set(docRef, cleanRecord, SetOptions(merge: true));
          }
        } catch (e) {
          print('Error preparing record ${record['id']} for upload: $e');
        }
      }

      if (table != 'users') {
        await batch.commit();
      }

      // Mark records as synced
      await _markRecordsAsSynced(table, batchRecords);
    }
  }

  /// Upload user with duplicate checking
  Future<void> _uploadUserWithDuplicateCheck(Map<String, dynamic> user) async {
    try {
      final email = user['email']?.toString().trim();
      final phone = user['phone']?.toString().trim();
      final idnumber = user['idnumber']?.toString().trim();

      if (email == null || email.isEmpty) {
        print('Skipping user upload - no email provided');
        return;
      }

      // Check for existing user by email first
      QuerySnapshot existingByEmail = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      String documentId;
      Map<String, dynamic> cleanRecord = _cleanRecordForFirebase(user);

      if (existingByEmail.docs.isNotEmpty) {
        // User exists - update existing document
        documentId = existingByEmail.docs.first.id;
        print('Updating existing user with email: $email');

        // Merge data, keeping server timestamp
        cleanRecord['last_modified'] = FieldValue.serverTimestamp();
        await _firestore.collection('users').doc(documentId).set(
              cleanRecord,
              SetOptions(merge: true),
            );
      } else {
        // Check by phone as secondary identifier
        if (phone != null && phone.isNotEmpty) {
          QuerySnapshot existingByPhone = await _firestore
              .collection('users')
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();

          if (existingByPhone.docs.isNotEmpty) {
            documentId = existingByPhone.docs.first.id;
            print('Updating existing user with phone: $phone');
            cleanRecord['last_modified'] = FieldValue.serverTimestamp();
            await _firestore.collection('users').doc(documentId).set(
                  cleanRecord,
                  SetOptions(merge: true),
                );
            return;
          }
        }

        // Check by ID number as tertiary identifier
        if (idnumber != null && idnumber.isNotEmpty) {
          QuerySnapshot existingByIdNumber = await _firestore
              .collection('users')
              .where('idnumber', isEqualTo: idnumber)
              .limit(1)
              .get();

          if (existingByIdNumber.docs.isNotEmpty) {
            documentId = existingByIdNumber.docs.first.id;
            print('Updating existing user with ID number: $idnumber');
            cleanRecord['last_modified'] = FieldValue.serverTimestamp();
            await _firestore.collection('users').doc(documentId).set(
                  cleanRecord,
                  SetOptions(merge: true),
                );
            return;
          }
        }

        // Truly new user - create new document
        print('Creating new user with email: $email');
        cleanRecord['last_modified'] = FieldValue.serverTimestamp();
        DocumentReference docRef =
            await _firestore.collection('users').add(cleanRecord);
        documentId = docRef.id;
      }

      // Update local record with Firebase document ID
      await _updateLocalRecordWithFirebaseId(user['id'], documentId);
    } catch (e) {
      print('Error uploading user ${user['id']}: $e');
      // Don't rethrow - continue with other users
    }
  }

  /// Update local record with Firebase document ID
  Future<void> _updateLocalRecordWithFirebaseId(
      int localId, String firebaseId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'users',
        {
          'firebase_uid': firebaseId,
          'firebase_synced': 1,
          'last_modified': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      print('Error updating local record with Firebase ID: $e');
    }
  }

  /// Clean record for Firebase upload
  Map<String, dynamic> _cleanRecordForFirebase(Map<String, dynamic> record) {
    final cleanRecord = Map<String, dynamic>.from(record);

    // Remove SQLite-specific fields
    cleanRecord.remove('firebase_synced');
    cleanRecord.remove('id'); // Don't upload local SQLite ID

    // Convert timestamps
    if (cleanRecord['created_at'] is String) {
      try {
        cleanRecord['created_at'] = DateTime.parse(cleanRecord['created_at']);
      } catch (e) {
        cleanRecord['created_at'] = DateTime.now();
      }
    }

    return cleanRecord;
  }

  /// Convert Firestore data to SQLite format
  Map<String, dynamic> _convertFirestoreToSqlite(Map<String, dynamic> data) {
    final sqliteData = Map<String, dynamic>.from(data);

    // Convert Firestore Timestamps to SQLite format
    data.forEach((key, value) {
      if (value is Timestamp) {
        sqliteData[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        sqliteData[key] = value.toIso8601String();
      }
    });

    return sqliteData;
  }

  /// Quick duplicate check before inserting users
  Future<bool> _checkForExistingUser(Map<String, dynamic> userData) async {
    final db = await DatabaseHelper.instance.database;

    final email = userData['email']?.toString().trim();
    final phone = userData['phone']?.toString().trim();
    final idnumber = userData['idnumber']?.toString().trim();

    if (email != null && email.isNotEmpty) {
      final existing = await db.query(
        'users',
        where: 'email = ? AND (deleted IS NULL OR deleted = 0)',
        whereArgs: [email],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        print('User with email $email already exists locally');
        return true;
      }
    }

    if (phone != null && phone.isNotEmpty) {
      final existing = await db.query(
        'users',
        where: 'phone = ? AND (deleted IS NULL OR deleted = 0)',
        whereArgs: [phone],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        print('User with phone $phone already exists locally');
        return true;
      }
    }

    if (idnumber != null && idnumber.isNotEmpty) {
      final existing = await db.query(
        'users',
        where: 'idnumber = ? AND (deleted IS NULL OR deleted = 0)',
        whereArgs: [idnumber],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        print('User with ID number $idnumber already exists locally');
        return true;
      }
    }

    return false;
  }

  /// Quick fix for your existing _mergeDownloadedRecords method
  /// Replace your current method with this version:
  Future<void> _mergeDownloadedRecords(
      String table, List<QueryDocumentSnapshot> docs) async {
    final db = await DatabaseHelper.instance.database;

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final recordId = doc.id;

        // Special handling for users to prevent duplicates
        if (table == 'users') {
          // Check if user already exists before inserting
          final userExists = await _checkForExistingUser(data);
          if (userExists) {
            print('Skipping duplicate user: ${data['email']}');
            continue; // Skip this user
          }
        }

        // Convert Firestore data to SQLite format
        final sqliteData = _convertFirestoreToSqlite(data);
        sqliteData['id'] = int.tryParse(recordId) ?? recordId;

        // Check if record exists locally
        final existing = await db.query(
          table,
          where: 'id = ?',
          whereArgs: [sqliteData['id']],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          // Update existing record
          sqliteData.remove('id'); // Don't update the ID
          sqliteData['firebase_synced'] = 1;

          await db.update(
            table,
            sqliteData,
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );

          print('Updated existing $table record ${existing.first['id']}');
        } else {
          // Insert new record only if it doesn't exist
          sqliteData['firebase_synced'] = 1;

          try {
            await db.insert(table, sqliteData);
            print('Inserted new $table record from Firebase');
          } catch (e) {
            if (e.toString().contains('UNIQUE constraint failed')) {
              print('Skipped duplicate $table record: ${e.toString()}');
              // Continue with next record instead of failing
            } else {
              print('Error inserting $table record: $e');
            }
          }
        }
      } catch (e) {
        print('Error merging record ${doc.id}: $e');
        // Continue with other records
      }
    }
  }

  /// Emergency method to clean duplicates right now
  Future<void> emergencyDeduplication() async {
    print('🚨 Starting emergency deduplication...');

    final db = await DatabaseHelper.instance.database;

    try {
      // Find and handle email duplicates
      final emailDuplicates = await db.rawQuery('''
      SELECT email, MIN(id) as keep_id, COUNT(*) as count
      FROM users 
      WHERE email IS NOT NULL AND email != '' 
      AND (deleted IS NULL OR deleted = 0)
      GROUP BY email 
      HAVING count > 1
    ''');

      for (final duplicate in emailDuplicates) {
        final email = duplicate['email'] as String;
        final keepId = duplicate['keep_id'] as int;

        // Mark all other users with this email as deleted
        await db.execute('''
        UPDATE users 
        SET deleted = 1, 
            last_modified = ${DateTime.now().millisecondsSinceEpoch},
            firebase_synced = 0
        WHERE email = ? AND id != ? AND (deleted IS NULL OR deleted = 0)
      ''', [email, keepId]);

        print('Kept user $keepId, marked others with email $email as deleted');
      }

      // Repeat for phone numbers
      final phoneDuplicates = await db.rawQuery('''
      SELECT phone, MIN(id) as keep_id, COUNT(*) as count
      FROM users 
      WHERE phone IS NOT NULL AND phone != '' 
      AND (deleted IS NULL OR deleted = 0)
      GROUP BY phone 
      HAVING count > 1
    ''');

      for (final duplicate in phoneDuplicates) {
        final phone = duplicate['phone'] as String;
        final keepId = duplicate['keep_id'] as int;

        await db.execute('''
        UPDATE users 
        SET deleted = 1, 
            last_modified = ${DateTime.now().millisecondsSinceEpoch},
            firebase_synced = 0
        WHERE phone = ? AND id != ? AND (deleted IS NULL OR deleted = 0)
      ''', [phone, keepId]);

        print('Kept user $keepId, marked others with phone $phone as deleted');
      }

      print('✅ Emergency deduplication complete');

      // Trigger sync to update Firebase with deletions
      if (isOnline.value && !isSyncing.value) {
        Timer(const Duration(seconds: 5), () {
          triggerManualSync();
        });
      }
    } catch (e) {
      print('❌ Emergency deduplication failed: $e');
    }
  }
}
