import 'package:crypto/crypto.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:get/get.dart';
import 'dart:convert';

class SchoolConfigService extends GetxService {
  static SchoolConfigService get instance => Get.find<SchoolConfigService>();

  // School identification
  final RxString schoolId = ''.obs;
  final RxString schoolName = ''.obs;
  final RxBool isInitialized = false.obs;

  // Get settings controller
  SettingsController get _settingsController => Get.find<SettingsController>();

  @override
  Future<void> onInit() async {
    super.onInit();
    await initializeSchoolConfig();
  }

  /// Initialize school configuration from business settings
  Future<void> initializeSchoolConfig() async {
    try {
      print('🏫 Initializing school configuration...');

      // Wait for settings to load if not already loaded
      await _ensureSettingsLoaded();

      // Generate school ID from business information
      await _generateSchoolId();

      // Set school name from business settings
      schoolName.value = _settingsController.businessName.value;

      // Mark as initialized
      isInitialized.value = true;

      print('✅ School configuration initialized:');
      print('   School ID: ${schoolId.value}');
      print('   School Name: ${schoolName.value}');
    } catch (e) {
      print('❌ Failed to initialize school configuration: $e');
      // Set fallback values
      schoolId.value = 'default_school';
      schoolName.value = 'Default School';
      isInitialized.value = true;
    }
  }

  /// Ensure settings are loaded before proceeding
  Future<void> _ensureSettingsLoaded() async {
    // Load settings if business name is empty
    if (_settingsController.businessName.value.isEmpty) {
      print('📋 Loading business settings...');
      await _settingsController.loadSettingsFromDatabase();
    }
  }

  /// Generate a unique school ID based on business information
  Future<void> _generateSchoolId() async {
    final businessName = _settingsController.businessName.value;
    final businessAddress = _settingsController.businessAddress.value;
    final businessPhone = _settingsController.businessPhone.value;
    final businessEmail = _settingsController.businessEmail.value;

    // Create a unique identifier from business information
    String identifier = '';

    if (businessName.isNotEmpty) {
      identifier +=
          businessName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    if (businessAddress.isNotEmpty) {
      identifier +=
          '_${businessAddress.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    }

    if (businessPhone.isNotEmpty) {
      identifier += '_${businessPhone.replaceAll(RegExp(r'[^0-9]'), '')}';
    }

    // If we have enough information, create a hash-based ID
    if (identifier.isNotEmpty) {
      final combinedInfo =
          '$businessName|$businessAddress|$businessPhone|$businessEmail';
      final bytes = utf8.encode(combinedInfo);
      final digest = sha256.convert(bytes);

      // Use first 12 characters of hash + sanitized business name
      final hashPrefix = digest.toString().substring(0, 12);
      final sanitizedName = businessName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '')
          .substring(0, businessName.length > 8 ? 8 : businessName.length);

      schoolId.value = '${sanitizedName}_$hashPrefix';
    } else {
      // Fallback: generate based on timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      schoolId.value = 'school_$timestamp';
    }
  }

  /// Get Firebase collection path for a given collection with school isolation
  String getCollectionPath(String collection) {
    if (!isInitialized.value || schoolId.value.isEmpty) {
      print('⚠️ School not initialized, using default path for $collection');
      return collection; // Fallback to non-tenant path
    }

    return 'schools/${schoolId.value}/$collection';
  }

  /// Get Firebase document path for a school-specific document
  String getDocumentPath(String collection, String documentId) {
    return '${getCollectionPath(collection)}/$documentId';
  }

  /// Update school configuration when business settings change
  Future<void> updateSchoolConfig() async {
    print('🔄 Updating school configuration...');

    final oldSchoolId = schoolId.value;
    final oldSchoolName = schoolName.value;

    // Regenerate school ID and name
    await _generateSchoolId();
    schoolName.value = _settingsController.businessName.value;

    // Check if school identity changed
    if (oldSchoolId != schoolId.value) {
      print('⚠️ School ID changed from $oldSchoolId to ${schoolId.value}');
      print('   This may require data migration in Firebase');

      // Trigger re-sync if needed
      _handleSchoolIdentityChange(oldSchoolId, schoolId.value);
    }

    if (oldSchoolName != schoolName.value) {
      print(
          '📝 School name updated from "$oldSchoolName" to "${schoolName.value}"');
    }
  }

  /// Handle school identity change (for future data migration)
  void _handleSchoolIdentityChange(String oldSchoolId, String newSchoolId) {
    // This is where you could implement data migration logic
    // For now, we'll just log the change
    print('🚨 SCHOOL IDENTITY CHANGE DETECTED:');
    print('   Old School ID: $oldSchoolId');
    print('   New School ID: $newSchoolId');
    print('   Consider data migration if needed');
  }

  /// Validate school configuration
  bool isValidConfiguration() {
    return isInitialized.value &&
        schoolId.value.isNotEmpty &&
        schoolName.value.isNotEmpty;
  }

  /// Get school display information
  Map<String, String> getSchoolInfo() {
    return {
      'schoolId': schoolId.value,
      'schoolName': schoolName.value,
      'businessAddress': _settingsController.businessAddress.value,
      'businessCity': _settingsController.businessCity.value,
      'businessCountry': _settingsController.businessCountry.value,
      'businessPhone': _settingsController.businessPhone.value,
      'businessEmail': _settingsController.businessEmail.value,
    };
  }

  /// Reset school configuration (for testing/development)
  Future<void> resetSchoolConfig() async {
    schoolId.value = '';
    schoolName.value = '';
    isInitialized.value = false;
    await initializeSchoolConfig();
  }

  /// Export school configuration for debugging
  Map<String, dynamic> exportConfig() {
    return {
      'schoolId': schoolId.value,
      'schoolName': schoolName.value,
      'isInitialized': isInitialized.value,
      'businessSettings': {
        'businessName': _settingsController.businessName.value,
        'businessAddress': _settingsController.businessAddress.value,
        'businessCity': _settingsController.businessCity.value,
        'businessCountry': _settingsController.businessCountry.value,
        'businessPhone': _settingsController.businessPhone.value,
        'businessEmail': _settingsController.businessEmail.value,
      },
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }
}
