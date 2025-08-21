// lib/services/school_management_service.dart
import 'package:get/get.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolManagementService extends GetxService {
  static SchoolManagementService get instance =>
      Get.find<SchoolManagementService>();

  // Firebase instance
  FirebaseFirestore? _firestore;

  // Known schools cache
  final RxList<Map<String, dynamic>> knownSchools =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> recentSchools =
      <Map<String, dynamic>>[].obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeFirebase();
    await _loadKnownSchools();
  }

  /// Initialize Firebase
  Future<void> _initializeFirebase() async {
    try {
      _firestore = FirebaseFirestore.instance;
      print('✅ School Management Service: Firebase initialized');
    } catch (e) {
      print('⚠️ School Management Service: Firebase not available');
    }
  }

  /// Load known schools from local storage
  Future<void> _loadKnownSchools() async {
    try {
      // Load from local database - schools the user has accessed before
      final schools = await DatabaseHelper.instance.getKnownSchools();
      knownSchools.value = schools;

      // Sort by last accessed
      recentSchools.value = schools
          .where((school) => school['last_accessed'] != null)
          .toList()
        ..sort((a, b) => DateTime.parse(b['last_accessed'])
            .compareTo(DateTime.parse(a['last_accessed'])));

      print('📚 Loaded ${knownSchools.length} known schools');
    } catch (e) {
      print('⚠️ Error loading known schools: $e');
    }
  }

  /// Search for schools by name or ID
  Future<List<Map<String, dynamic>>> searchSchools(String query) async {
    final results = <Map<String, dynamic>>[];

    try {
      // Search local known schools first
      final localResults = knownSchools.where((school) {
        final name = school['name']?.toString().toLowerCase() ?? '';
        final id = school['id']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();

        return name.contains(searchQuery) || id.contains(searchQuery);
      }).toList();

      results.addAll(localResults);

      // Search Firebase for public schools (if available)
      if (_firestore != null && query.length >= 3) {
        try {
          final firebaseResults = await _searchFirebaseSchools(query);

          // Add Firebase results that aren't already in local results
          for (final firebaseSchool in firebaseResults) {
            final existsLocally =
                results.any((local) => local['id'] == firebaseSchool['id']);

            if (!existsLocally) {
              results.add(firebaseSchool);
            }
          }
        } catch (e) {
          print('⚠️ Firebase school search failed: $e');
        }
      }

      return results;
    } catch (e) {
      print('❌ Error searching schools: $e');
      return [];
    }
  }

  /// Search Firebase for schools
  Future<List<Map<String, dynamic>>> _searchFirebaseSchools(
      String query) async {
    if (_firestore == null) return [];

    try {
      // Search schools collection
      final querySnapshot = await _firestore!
          .collection('school_directory')
          .where('searchTerms', arrayContainsAny: _generateSearchTerms(query))
          .limit(10)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'address': data['address'] ?? '',
          'phone': data['phone'] ?? '',
          'city': data['city'] ?? '',
          'country': data['country'] ?? '',
          'isPublic': data['isPublic'] ?? false,
          'status': data['status'] ?? 'active',
        };
      }).toList();
    } catch (e) {
      print('❌ Firebase school search error: $e');
      return [];
    }
  }

  /// Generate search terms for Firebase queries
  List<String> _generateSearchTerms(String input) {
    final terms = <String>[];
    final words = input.toLowerCase().split(' ');

    for (final word in words) {
      if (word.length >= 3) {
        terms.add(word);
        // Add partial matches
        for (int i = 3; i <= word.length; i++) {
          terms.add(word.substring(0, i));
        }
      }
    }

    return terms.take(10).toList(); // Limit to prevent errors
  }

  /// Switch to a different school
  Future<bool> switchToSchool(Map<String, dynamic> schoolData) async {
    try {
      print('🔄 Switching to school: ${schoolData['name']}');

      // Step 1: Logout current user
      final authController = Get.find<AuthController>();
      await authController.logout();

      // Step 2: Update settings with new school data
      await _updateSchoolSettings(schoolData);

      // Step 3: Reset and reinitialize school configuration
      final schoolConfig = Get.find<SchoolConfigService>();
      await schoolConfig.resetSchoolConfig();

      // Step 4: Save this school as known/recent
      await _saveSchoolAsKnown(schoolData);

      // Step 5: Reload known schools
      await _loadKnownSchools();

      print('✅ Successfully switched to ${schoolData['name']}');
      return true;
    } catch (e) {
      print('❌ Error switching school: $e');
      return false;
    }
  }

  /// Update settings with school data
  Future<void> _updateSchoolSettings(Map<String, dynamic> schoolData) async {
    final settingsController = Get.find<SettingsController>();

    settingsController.businessName.value = schoolData['name'] ?? '';
    settingsController.businessAddress.value = schoolData['address'] ?? '';
    settingsController.businessPhone.value = schoolData['phone'] ?? '';
    settingsController.businessEmail.value = schoolData['email'] ?? '';
    settingsController.businessCity.value = schoolData['city'] ?? '';
    settingsController.businessCountry.value = schoolData['country'] ?? '';

    await settingsController.saveAllBusinessSettings();
  }

  /// Save school as known for future access
  Future<void> _saveSchoolAsKnown(Map<String, dynamic> schoolData) async {
    try {
      final schoolRecord = {
        'id': schoolData['id'],
        'name': schoolData['name'],
        'address': schoolData['address'] ?? '',
        'phone': schoolData['phone'] ?? '',
        'city': schoolData['city'] ?? '',
        'country': schoolData['country'] ?? '',
        'last_accessed': DateTime.now().toIso8601String(),
        'access_count': 1,
      };

      await DatabaseHelper.instance.saveKnownSchool(schoolRecord);
    } catch (e) {
      print('⚠️ Error saving known school: $e');
    }
  }

  /// Get school information by ID
  Future<Map<String, dynamic>?> getSchoolById(String schoolId) async {
    try {
      // Check local known schools first
      final localSchool =
          knownSchools.firstWhereOrNull((school) => school['id'] == schoolId);

      if (localSchool != null) {
        return localSchool;
      }

      // Check Firebase if available
      if (_firestore != null) {
        final docSnapshot = await _firestore!
            .collection('school_directory')
            .doc(schoolId)
            .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          return {
            'id': docSnapshot.id,
            'name': data['name'],
            'address': data['address'] ?? '',
            'phone': data['phone'] ?? '',
            'city': data['city'] ?? '',
            'country': data['country'] ?? '',
            'status': data['status'] ?? 'active',
          };
        }
      }

      return null;
    } catch (e) {
      print('❌ Error getting school by ID: $e');
      return null;
    }
  }

  /// Register a new school in the directory
  Future<bool> registerSchoolInDirectory(
      Map<String, dynamic> schoolData) async {
    if (_firestore == null) {
      print('⚠️ Firebase not available, skipping directory registration');
      return true; // Don't fail the registration, just skip directory
    }

    try {
      final schoolRecord = {
        'name': schoolData['name'],
        'address': schoolData['address'] ?? '',
        'phone': schoolData['phone'] ?? '',
        'email': schoolData['email'] ?? '',
        'city': schoolData['city'] ?? '',
        'country': schoolData['country'] ?? '',
        'isPublic': schoolData['isPublic'] ?? false,
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
        'searchTerms': _generateSearchTerms(schoolData['name']),
      };

      await _firestore!
          .collection('school_directory')
          .doc(schoolData['id'])
          .set(schoolRecord);

      print('✅ School registered in directory');
      return true;
    } catch (e) {
      print('❌ Error registering school in directory: $e');
      return false; // Don't fail the whole registration for this
    }
  }

  /// Generate a QR code data for school sharing
  String generateSchoolQRCode(Map<String, dynamic> schoolData) {
    return '${schoolData['id']}|${schoolData['name']}|${schoolData['city'] ?? ''}';
  }

  /// Parse QR code data
  Map<String, String>? parseSchoolQRCode(String qrData) {
    try {
      final parts = qrData.split('|');
      if (parts.length >= 2) {
        return {
          'id': parts[0],
          'name': parts[1],
          'city': parts.length > 2 ? parts[2] : '',
        };
      }
      return null;
    } catch (e) {
      print('❌ Error parsing QR code: $e');
      return null;
    }
  }

  /// Clear all known schools (for testing/reset)
  Future<void> clearKnownSchools() async {
    try {
      await DatabaseHelper.instance.clearKnownSchools();
      knownSchools.clear();
      recentSchools.clear();
      print('✅ Cleared all known schools');
    } catch (e) {
      print('❌ Error clearing known schools: $e');
    }
  }
}
