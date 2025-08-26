// lib/services/payment_sync_integration.dart - Integration with existing sync service
import 'package:driving/services/enhanced_payment_sync_service.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';
import 'package:get/get.dart';

/// Service to integrate enhanced payment sync with existing sync infrastructure
class PaymentSyncIntegration extends GetxService {
  static PaymentSyncIntegration get instance =>
      Get.find<PaymentSyncIntegration>();

  // Dependencies
  EnhancedPaymentSyncService? _enhancedPaymentSync;
  MultiTenantFirebaseSyncService? _multiTenantSync;

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
      if (Get.isRegistered<MultiTenantFirebaseSyncService>()) {
        _multiTenantSync = Get.find<MultiTenantFirebaseSyncService>();
      }

      print('✅ Payment Sync Integration initialized');
    } catch (e) {
      print('❌ Failed to initialize Payment Sync Integration: $e');
    }
  }

  /// Enhanced manual sync that includes payment-specific logic
  Future<void> triggerEnhancedSync() async {
    print('🚀 === STARTING ENHANCED MANUAL SYNC ===');

    try {
      // Step 1: Run enhanced payment/invoice sync first
      if (_enhancedPaymentSync != null) {
        print('💰 Running enhanced payment & invoice sync...');
        await _enhancedPaymentSync!.syncInvoicesAndPayments();
      } else {
        print('⚠️ Enhanced payment sync not available');
      }

      // Step 2: Run standard multi-tenant sync for other data
      if (_multiTenantSync != null) {
        print('🏫 Running standard multi-tenant sync...');
        await _multiTenantSync!.triggerManualSync();
      } else {
        print('⚠️ Multi-tenant sync not available');
      }

      // Step 3: Validate payment integrity
      if (_enhancedPaymentSync != null) {
        print('🔍 Validating payment integrity...');
        await _enhancedPaymentSync!.validatePaymentIntegrity();
      }

      print('✅ === ENHANCED MANUAL SYNC COMPLETED ===');
    } catch (e) {
      print('❌ Enhanced manual sync failed: $e');
      throw e;
    }
  }

  /// Emergency sync for payment issues
  Future<void> emergencyPaymentFix() async {
    print('🚨 === EMERGENCY PAYMENT FIX ===');

    try {
      if (_enhancedPaymentSync != null) {
        await _enhancedPaymentSync!.emergencyPaymentSync();
        print('✅ Emergency payment fix completed');
      } else {
        throw Exception('Enhanced payment sync service not available');
      }
    } catch (e) {
      print('❌ Emergency payment fix failed: $e');
      throw e;
    }
  }

  /// Get sync status
  bool get isEnhancedSyncAvailable {
    return _enhancedPaymentSync != null && _multiTenantSync != null;
  }

  /// Check if sync is currently running
  bool get isSyncing {
    return _multiTenantSync?.isSyncing.value ?? false;
  }

  /// Get last sync time
  DateTime get lastSyncTime {
    return _multiTenantSync?.lastSyncTime.value ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}
