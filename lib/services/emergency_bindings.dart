// lib/services/emergency_bindings.dart
import 'package:get/get.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/database_helper.dart';

class EmergencyBindings {
  /// Initialize missing critical controllers
  static void initializeMissingControllers() {
    print('🚨 === EMERGENCY CONTROLLER INITIALIZATION ===');

    try {
      // Initialize critical controllers if they don't exist

      if (!Get.isRegistered<DatabaseHelper>()) {
        Get.put<DatabaseHelper>(DatabaseHelper.instance, permanent: true);
        print('✅ Emergency: DatabaseHelper initialized');
      }

      if (!Get.isRegistered<PinController>()) {
        Get.put<PinController>(PinController(), permanent: true);
        print('✅ Emergency: PinController initialized');
      }

      if (!Get.isRegistered<SettingsController>()) {
        Get.put<SettingsController>(SettingsController(), permanent: true);
        print('✅ Emergency: SettingsController initialized');
      }

      if (!Get.isRegistered<SchoolConfigService>()) {
        Get.put<SchoolConfigService>(SchoolConfigService(), permanent: true);
        print('✅ Emergency: SchoolConfigService initialized');
      }

      if (!Get.isRegistered<AuthController>()) {
        Get.put<AuthController>(AuthController(), permanent: true);
        print('✅ Emergency: AuthController initialized');
      }

      print('✅ Emergency initialization completed');
    } catch (e) {
      print('❌ Emergency initialization failed: $e');
      print('🚨 App may not function properly');
    }
  }
}
