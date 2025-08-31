// lib/services/subscription_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crypto/crypto.dart';

class SubscriptionService extends GetxService {
  static SubscriptionService get instance => Get.find<SubscriptionService>();

  // Firebase instances
  FirebaseFirestore? _firestore;
  FirebaseAuth? _firebaseAuth;

  // Subscription state
  final RxBool isSubscriptionActive = false.obs;
  final RxBool isInFreeTrial = false.obs;
  final RxInt daysRemainingInTrial = 0.obs;
  final RxInt daysRemainingInSubscription = 0.obs;
  final RxString subscriptionStatus = 'inactive'.obs; // active, expired, trial
  final RxString subscriptionPlan = 'monthly'.obs; // only monthly now
  final RxDouble subscriptionPrice = 5.0.obs; // $5 per month as shown
  final RxString voucherCode = ''.obs;

  // Loading states
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  // Subscription document
  final Rx<Map<String, dynamic>?> subscriptionData =
      Rx<Map<String, dynamic>?>(null);

  // Timer for checking subscription status
  Timer? _statusCheckTimer;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeFirebase();
    await _checkSubscriptionStatus();
    _startStatusMonitoring();
  }

  @override
  void onClose() {
    _statusCheckTimer?.cancel();
    super.onClose();
  }

  /// Initialize Firebase services
  Future<void> _initializeFirebase() async {
    try {
      _firestore = FirebaseFirestore.instance;
      _firebaseAuth = FirebaseAuth.instance;
      print('✅ Subscription Service: Firebase initialized');
    } catch (e) {
      print('❌ Subscription Service: Firebase initialization failed: $e');
    }
  }

  /// Check if user can use the app (either in trial or active subscription)
  bool get canUseApp => isInFreeTrial.value || isSubscriptionActive.value;

  /// Get current user's school ID (implement based on your school config)
  String get _currentSchoolId {
    try {
      // Get from your school config service
      final schoolConfig = Get.find<SchoolConfigService>();
      return schoolConfig.schoolId.value;
    } catch (e) {
      // Fallback to Firebase Auth user ID
      return _firebaseAuth?.currentUser?.uid ?? 'unknown';
    }
  }

  /// Start 1-week free trial for new users
  Future<bool> startFreeTrial() async {
    if (_firestore == null || _firebaseAuth?.currentUser == null) {
      error.value = 'Please login first';
      return false;
    }

    try {
      isLoading.value = true;
      error.value = '';

      final user = _firebaseAuth!.currentUser!;
      final now = DateTime.now();
      final trialEndDate = now.add(const Duration(days: 7));

      // Generate voucher code for trial
      final trialVoucherCode = _generateVoucherCode();

      final subscriptionDoc = {
        'user_id': user.uid,
        'school_id': _currentSchoolId,
        'status': 'trial',
        'plan': 'trial',
        'price': 0.0,
        'trial_start_date': now.toIso8601String(),
        'trial_end_date': trialEndDate.toIso8601String(),
        'subscription_start_date': null,
        'subscription_end_date': null,
        'voucher_code': trialVoucherCode,
        'created_at': now.toIso8601String(),
        'last_updated': now.toIso8601String(),
        'payment_method': null,
        'payment_status': 'trial',
        'auto_renew': false,
      };

      await _firestore!
          .collection('subscriptions')
          .doc(_currentSchoolId)
          .set(subscriptionDoc);

      // Update local state
      subscriptionData.value = subscriptionDoc;
      isInFreeTrial.value = true;
      isSubscriptionActive.value = false;
      subscriptionStatus.value = 'trial';
      voucherCode.value = trialVoucherCode;
      daysRemainingInTrial.value = 7;

      print('✅ Free trial started for school: $_currentSchoolId');
      return true;
    } catch (e) {
      error.value = 'Failed to start free trial: ${e.toString()}';
      print('❌ Error starting free trial: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Subscribe to monthly plan ($5/month only)
  Future<bool> subscribeToMonthlyPlan({
    required String paymentMethod,
    String? paymentReference,
  }) async {
    if (_firestore == null || _firebaseAuth?.currentUser == null) {
      error.value = 'Please login first';
      return false;
    }

    try {
      isLoading.value = true;
      error.value = '';

      final user = _firebaseAuth!.currentUser!;
      final now = DateTime.now();
      final subscriptionEndDate = now.add(const Duration(days: 30)); // 1 month

      // Generate voucher code for subscription
      final subscriptionVoucherCode = _generateVoucherCode();

      final subscriptionDoc = {
        'user_id': user.uid,
        'school_id': _currentSchoolId,
        'status': 'active',
        'plan': 'monthly',
        'price': 5.0, // $5 per month as shown in image
        'trial_start_date': subscriptionData.value?['trial_start_date'],
        'trial_end_date': subscriptionData.value?['trial_end_date'],
        'subscription_start_date': now.toIso8601String(),
        'subscription_end_date': subscriptionEndDate.toIso8601String(),
        'voucher_code': subscriptionVoucherCode,
        'payment_method': paymentMethod,
        'payment_reference': paymentReference,
        'payment_status':
            'pending', // Will be updated after payment verification
        'auto_renew': true,
        'last_updated': now.toIso8601String(),
        'created_at':
            subscriptionData.value?['created_at'] ?? now.toIso8601String(),
      };

      await _firestore!
          .collection('subscriptions')
          .doc(_currentSchoolId)
          .set(subscriptionDoc, SetOptions(merge: true));

      // Update local state
      subscriptionData.value = subscriptionDoc;
      isInFreeTrial.value = false;
      isSubscriptionActive.value =
          false; // Will be true after payment verification
      subscriptionStatus.value = 'pending';
      voucherCode.value = subscriptionVoucherCode;
      subscriptionPlan.value = 'monthly';
      subscriptionPrice.value = 5.0;

      print('✅ Monthly subscription initiated for school: $_currentSchoolId');
      return true;
    } catch (e) {
      error.value = 'Failed to subscribe: ${e.toString()}';
      print('❌ Error subscribing: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Verify payment and activate subscription
  Future<bool> verifyPaymentAndActivate({
    required String paymentProof,
    required String voucherCode,
  }) async {
    if (_firestore == null) {
      error.value = 'Firebase not available';
      return false;
    }

    try {
      isLoading.value = true;
      error.value = '';

      // Get current subscription
      final subscriptionRef =
          _firestore!.collection('subscriptions').doc(_currentSchoolId);

      final subscriptionSnapshot = await subscriptionRef.get();
      if (!subscriptionSnapshot.exists) {
        error.value = 'Subscription not found';
        return false;
      }

      final data = subscriptionSnapshot.data()!;

      // Verify voucher code matches
      if (data['voucher_code'] != voucherCode) {
        error.value = 'Invalid voucher code';
        return false;
      }

      // Update subscription with payment proof
      final now = DateTime.now();
      await subscriptionRef.update({
        'payment_proof': paymentProof,
        'payment_status': 'verified',
        'status': 'active',
        'verified_at': now.toIso8601String(),
        'last_updated': now.toIso8601String(),
      });

      // Update local state
      subscriptionData.value = {
        ...data,
        'payment_proof': paymentProof,
        'payment_status': 'verified',
        'status': 'active',
        'verified_at': now.toIso8601String(),
        'last_updated': now.toIso8601String(),
      };

      isSubscriptionActive.value = true;
      isInFreeTrial.value = false;
      subscriptionStatus.value = 'active';

      await _calculateRemainingDays();

      print('✅ Payment verified and subscription activated');
      return true;
    } catch (e) {
      error.value = 'Failed to verify payment: ${e.toString()}';
      print('❌ Error verifying payment: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Check current subscription status
  Future<void> _checkSubscriptionStatus() async {
    if (_firestore == null) return;

    try {
      final subscriptionSnapshot = await _firestore!
          .collection('subscriptions')
          .doc(_currentSchoolId)
          .get();

      if (!subscriptionSnapshot.exists) {
        // No subscription found - user needs to start trial or subscribe
        _resetSubscriptionState();
        return;
      }

      final data = subscriptionSnapshot.data()!;
      subscriptionData.value = data;

      final now = DateTime.now();
      final status = data['status'] as String;

      switch (status) {
        case 'trial':
          await _handleTrialStatus(data, now);
          break;
        case 'active':
          await _handleActiveSubscription(data, now);
          break;
        case 'expired':
          await _handleExpiredSubscription(data);
          break;
        default:
          _resetSubscriptionState();
      }

      await _calculateRemainingDays();
    } catch (e) {
      print('❌ Error checking subscription status: $e');
      error.value = 'Failed to check subscription status';
    }
  }

  /// Handle trial status
  Future<void> _handleTrialStatus(
      Map<String, dynamic> data, DateTime now) async {
    final trialEndDate = DateTime.parse(data['trial_end_date']);

    if (now.isBefore(trialEndDate)) {
      // Still in trial
      isInFreeTrial.value = true;
      isSubscriptionActive.value = false;
      subscriptionStatus.value = 'trial';
    } else {
      // Trial expired
      await _expireSubscription();
    }
  }

  /// Handle active subscription
  Future<void> _handleActiveSubscription(
      Map<String, dynamic> data, DateTime now) async {
    final subscriptionEndDate = DateTime.parse(data['subscription_end_date']);

    if (now.isBefore(subscriptionEndDate)) {
      // Subscription still active
      isInFreeTrial.value = false;
      isSubscriptionActive.value = true;
      subscriptionStatus.value = 'active';
      subscriptionPlan.value = data['plan'] ?? 'monthly';
      subscriptionPrice.value = (data['price'] ?? 5.0).toDouble();
      voucherCode.value = data['voucher_code'] ?? '';
    } else {
      // Subscription expired
      await _expireSubscription();
    }
  }

  /// Handle expired subscription
  Future<void> _handleExpiredSubscription(Map<String, dynamic> data) async {
    isInFreeTrial.value = false;
    isSubscriptionActive.value = false;
    subscriptionStatus.value = 'expired';
  }

  /// Expire subscription
  Future<void> _expireSubscription() async {
    try {
      await _firestore!
          .collection('subscriptions')
          .doc(_currentSchoolId)
          .update({
        'status': 'expired',
        'last_updated': DateTime.now().toIso8601String(),
      });

      isInFreeTrial.value = false;
      isSubscriptionActive.value = false;
      subscriptionStatus.value = 'expired';
      daysRemainingInTrial.value = 0;
      daysRemainingInSubscription.value = 0;

      print('⏰ Subscription expired for school: $_currentSchoolId');
    } catch (e) {
      print('❌ Error expiring subscription: $e');
    }
  }

  /// Calculate remaining days
  Future<void> _calculateRemainingDays() async {
    final data = subscriptionData.value;
    if (data == null) return;

    final now = DateTime.now();

    // Calculate trial days remaining
    if (data['trial_end_date'] != null) {
      final trialEndDate = DateTime.parse(data['trial_end_date']);
      final trialDaysLeft = trialEndDate.difference(now).inDays;
      daysRemainingInTrial.value = trialDaysLeft > 0 ? trialDaysLeft : 0;
    }

    // Calculate subscription days remaining
    if (data['subscription_end_date'] != null) {
      final subscriptionEndDate = DateTime.parse(data['subscription_end_date']);
      final subscriptionDaysLeft = subscriptionEndDate.difference(now).inDays;
      daysRemainingInSubscription.value =
          subscriptionDaysLeft > 0 ? subscriptionDaysLeft : 0;
    }
  }

  /// Reset subscription state
  void _resetSubscriptionState() {
    subscriptionData.value = null;
    isInFreeTrial.value = false;
    isSubscriptionActive.value = false;
    subscriptionStatus.value = 'inactive';
    daysRemainingInTrial.value = 0;
    daysRemainingInSubscription.value = 0;
    voucherCode.value = '';
  }

  /// Start periodic status monitoring
  void _startStatusMonitoring() {
    _statusCheckTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _checkSubscriptionStatus();
    });
  }

  /// Generate unique voucher code
  String _generateVoucherCode() {
    final now = DateTime.now();
    final random = Random();
    final timestamp = now.millisecondsSinceEpoch.toString();
    final randomPart = random.nextInt(999999).toString().padLeft(6, '0');
    return timestamp.substring(timestamp.length - 7) + randomPart;
  }

  /// Block app usage if subscription is not valid
  bool checkAppAccess() {
    if (!canUseApp) {
      _showSubscriptionBlockedDialog();
      return false;
    }
    return true;
  }

  /// Show subscription blocked dialog
  void _showSubscriptionBlockedDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Subscription Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              subscriptionStatus.value == 'expired'
                  ? 'Your subscription has expired. Please renew to continue using the app.'
                  : 'You need an active subscription to use this app.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed('/subscription'); // Navigate to subscription screen
            },
            child: Text(
                subscriptionStatus.value == 'expired' ? 'Renew' : 'Subscribe'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Get subscription info for settings screen
  Map<String, dynamic> getSubscriptionInfo() {
    return {
      'status': subscriptionStatus.value,
      'is_trial': isInFreeTrial.value,
      'is_active': isSubscriptionActive.value,
      'plan': subscriptionPlan.value,
      'price': subscriptionPrice.value,
      'days_remaining_trial': daysRemainingInTrial.value,
      'days_remaining_subscription': daysRemainingInSubscription.value,
      'voucher_code': voucherCode.value,
      'can_use_app': canUseApp,
    };
  }

  /// Renew subscription (same as subscribing to monthly)
  Future<bool> renewSubscription({
    required String paymentMethod,
    String? paymentReference,
  }) async {
    return await subscribeToMonthlyPlan(
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
    );
  }
}
