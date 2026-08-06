import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/database_helper.dart';

class EmergencyBindings {
  /// Initialize missing critical controllers
  static void initializeMissingControllers() {
    debugPrint('🚨 === EMERGENCY CONTROLLER INITIALIZATION ===');

    try {
      // Initialize critical controllers if they don't exist

      if (!Get.isRegistered<DatabaseHelper>()) {
        Get.put<DatabaseHelper>(DatabaseHelper.instance, permanent: true);
        debugPrint('✅ Emergency: DatabaseHelper initialized');
      }

      if (!Get.isRegistered<PinController>()) {
        Get.put<PinController>(PinController(), permanent: true);
        debugPrint('✅ Emergency: PinController initialized');
      }

      if (!Get.isRegistered<SettingsController>()) {
        Get.put<SettingsController>(SettingsController(), permanent: true);
        debugPrint('✅ Emergency: SettingsController initialized');
      }

      if (!Get.isRegistered<SchoolConfigService>()) {
        Get.put<SchoolConfigService>(SchoolConfigService(), permanent: true);
        debugPrint('✅ Emergency: SchoolConfigService initialized');
      }

      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
        debugPrint('✅ Emergency: AuthController initialized');
      }

      debugPrint('✅ Emergency initialization completed');
    } catch (e) {
      debugPrint('❌ Emergency initialization failed: $e');
      debugPrint('🚨 App may not function properly');
    }
  }
}
