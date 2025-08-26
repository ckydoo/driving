// lib/services/firebase_school_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

/// Service to manage Firebase school data structure and operations
class FirebaseSchoolService extends GetxService {
  static FirebaseSchoolService get instance =>
      Get.find<FirebaseSchoolService>();

  FirebaseFirestore? _firestore;

  @override
  void onInit() {
    super.onInit();
    _initializeFirebase();
  }

  void _initializeFirebase() {
    try {
      _firestore = FirebaseFirestore.instance;
      print('✅ FirebaseSchoolService initialized');
    } catch (e) {
      print('❌ FirebaseSchoolService initialization failed: $e');
    }
  }

  /// Search for schools by name or ID
  Future<List<Map<String, dynamic>>> searchSchools(String query) async {
    if (_firestore == null) return [];

    try {
      final searchTerm = query.toLowerCase().trim();
      final results = <Map<String, dynamic>>[];

      // Search by school ID
      final idQuery = await _firestore!
          .collection('schools')
          .where('schoolId', isGreaterThanOrEqualTo: searchTerm)
          .where('schoolId', isLessThan: searchTerm + 'z')
          .where('isActive', isEqualTo: true)
          .limit(10)
          .get();

      for (var doc in idQuery.docs) {
        results.add({
          'firebaseId': doc.id,
          ...doc.data(),
        });
      }

      // Search by school name
      final nameQuery = await _firestore!
          .collection('schools')
          .where('schoolName_lower', isGreaterThanOrEqualTo: searchTerm)
          .where('schoolName_lower', isLessThan: searchTerm + 'z')
          .where('isActive', isEqualTo: true)
          .limit(10)
          .get();

      for (var doc in nameQuery.docs) {
        // Avoid duplicates
        if (!results.any((school) => school['firebaseId'] == doc.id)) {
          results.add({
            'firebaseId': doc.id,
            ...doc.data(),
          });
        }
      }

      return results;
    } catch (e) {
      print('❌ Error searching schools: $e');
      return [];
    }
  }

  /// Get school by exact ID
  Future<Map<String, dynamic>?> getSchoolById(String schoolId) async {
    if (_firestore == null) return null;

    try {
      final query = await _firestore!
          .collection('schools')
          .where('schoolId', isEqualTo: schoolId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return {
          'firebaseId': doc.id,
          ...doc.data(),
        };
      }

      return null;
    } catch (e) {
      print('❌ Error getting school by ID: $e');
      return null;
    }
  }

  /// Get all data for a school (for offline sync)
  Future<Map<String, List<Map<String, dynamic>>>> getSchoolData(
      String firebaseSchoolId) async {
    if (_firestore == null) throw Exception('Firebase not initialized');

    try {
      final schoolRef = _firestore!.collection('schools').doc(firebaseSchoolId);
      final data = <String, List<Map<String, dynamic>>>{};

      // Collections to sync
      final collections = [
        'users',
        'courses',
        'fleet',
        'schedules',
        'invoices',
        'payments',
        'billing_records',
        'notes',
        'notifications',
        'attachments',
        'currencies',
        //'settings',
      ];

      for (String collection in collections) {
        try {
          final snapshot = await schoolRef.collection(collection).get();
          data[collection] = snapshot.docs
              .map((doc) => {
                    'firebase_doc_id': doc.id,
                    ...doc.data(),
                  })
              .toList();
        } catch (e) {
          print('⚠️ Error fetching $collection: $e');
          data[collection] = []; // Empty list for failed collections
        }
      }

      return data;
    } catch (e) {
      print('❌ Error getting school data: $e');
      throw Exception('Failed to fetch school data');
    }
  }

  /// Verify user credentials for a school
  Future<Map<String, dynamic>?> verifyUserCredentials({
    required String firebaseSchoolId,
    required String email,
    required String password,
  }) async {
    if (_firestore == null) return null;

    try {
      final usersSnapshot = await _firestore!
          .collection('schools')
          .doc(firebaseSchoolId)
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        return null; // User not found
      }

      final userDoc = usersSnapshot.docs.first;
      final userData = userDoc.data();

      // Verify password (in production, use proper password hashing)
      if (userData['password'] != password) {
        return null; // Invalid password
      }

      // Update last login time
      await userDoc.reference.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      return {
        'firebase_doc_id': userDoc.id,
        'schoolId': firebaseSchoolId,
        ...userData,
      };
    } catch (e) {
      print('❌ Error verifying user credentials: $e');
      return null;
    }
  }

  /// Update school information
  Future<void> updateSchool({
    required String firebaseSchoolId,
    required Map<String, dynamic> updates,
  }) async {
    if (_firestore == null) throw Exception('Firebase not initialized');

    try {
      await _firestore!.collection('schools').doc(firebaseSchoolId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ School updated successfully');
    } catch (e) {
      print('❌ Error updating school: $e');
      throw Exception('Failed to update school');
    }
  }

  /// Add user to school
  Future<String> addUserToSchool({
    required String firebaseSchoolId,
    required Map<String, dynamic> userData,
  }) async {
    if (_firestore == null) throw Exception('Firebase not initialized');

    try {
      final userRef = await _firestore!
          .collection('schools')
          .doc(firebaseSchoolId)
          .collection('users')
          .add({
        ...userData,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      print('✅ User added to school: ${userRef.id}');
      return userRef.id;
    } catch (e) {
      print('❌ Error adding user to school: $e');
      throw Exception('Failed to add user to school');
    }
  }

  /// Sync local changes to Firebase
  Future<void> syncLocalChangesToFirebase({
    required String firebaseSchoolId,
    required String collection,
    required List<Map<String, dynamic>> localData,
  }) async {
    if (_firestore == null) throw Exception('Firebase not initialized');

    try {
      final schoolRef = _firestore!.collection('schools').doc(firebaseSchoolId);
      final batch = _firestore!.batch();

      for (var item in localData) {
        if (item.containsKey('firebase_doc_id') &&
            item['firebase_doc_id'] != null) {
          // Update existing document
          final docRef =
              schoolRef.collection(collection).doc(item['firebase_doc_id']);
          final updateData = Map<String, dynamic>.from(item);
          updateData.remove('firebase_doc_id'); // Remove this meta field
          updateData['updatedAt'] = FieldValue.serverTimestamp();
          batch.update(docRef, updateData);
        } else {
          // Create new document
          final docRef = schoolRef.collection(collection).doc();
          final createData = Map<String, dynamic>.from(item);
          createData.remove('firebase_doc_id'); // Remove this meta field
          createData['createdAt'] = FieldValue.serverTimestamp();
          batch.set(docRef, createData);
        }
      }

      await batch.commit();
      print('✅ Local changes synced to Firebase for $collection');
    } catch (e) {
      print('❌ Error syncing local changes to Firebase: $e');
      throw Exception('Failed to sync local changes');
    }
  }

  /// Get school statistics
  Future<Map<String, int>> getSchoolStatistics(String firebaseSchoolId) async {
    if (_firestore == null) return {};

    try {
      final schoolRef = _firestore!.collection('schools').doc(firebaseSchoolId);
      final stats = <String, int>{};

      // Get counts for different collections
      final collections = ['users', 'courses', 'fleet', 'schedules'];

      for (String collection in collections) {
        try {
          final snapshot = await schoolRef.collection(collection).count().get();
          stats[collection] = snapshot.count!;
        } catch (e) {
          print('⚠️ Error getting count for $collection: $e');
          stats[collection] = 0;
        }
      }

      return stats;
    } catch (e) {
      print('❌ Error getting school statistics: $e');
      return {};
    }
  }

  /// Check if school is active and accessible
  Future<bool> isSchoolAccessible(String firebaseSchoolId) async {
    if (_firestore == null) return false;

    try {
      final doc =
          await _firestore!.collection('schools').doc(firebaseSchoolId).get();

      if (!doc.exists) return false;

      final data = doc.data();
      return data?['isActive'] == true &&
          data?['subscriptionStatus'] == 'active';
    } catch (e) {
      print('❌ Error checking school accessibility: $e');
      return false;
    }
  }

  /// Delete user from school
  Future<void> deleteUserFromSchool({
    required String firebaseSchoolId,
    required String userFirebaseId,
  }) async {
    if (_firestore == null) throw Exception('Firebase not initialized');

    try {
      await _firestore!
          .collection('schools')
          .doc(firebaseSchoolId)
          .collection('users')
          .doc(userFirebaseId)
          .delete();

      print('✅ User deleted from school');
    } catch (e) {
      print('❌ Error deleting user from school: $e');
      throw Exception('Failed to delete user');
    }
  }

  /// Deactivate school
  Future<void> deactivateSchool(String firebaseSchoolId) async {
    if (_firestore == null) throw Exception('Firebase not initialized');

    try {
      await _firestore!.collection('schools').doc(firebaseSchoolId).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ School deactivated');
    } catch (e) {
      print('❌ Error deactivating school: $e');
      throw Exception('Failed to deactivate school');
    }
  }
}
