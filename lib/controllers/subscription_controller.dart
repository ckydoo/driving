// lib/controllers/subscription_controller.dart - FIXED VERSION
import 'dart:io';

import 'package:driving/models/subscription_package.dart';
import 'package:driving/services/api_service.dart';
import 'package:driving/services/subscription_cache.dart';
import 'package:driving/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionController extends GetxController {
  // Observable variables
  final RxList<SubscriptionPackage> availablePackages =
      <SubscriptionPackage>[].obs;
  final Rxn<SubscriptionPackage> currentPackage = Rxn<SubscriptionPackage>();
  final RxString subscriptionStatus = 'trial'.obs;
  final RxInt remainingTrialDays = 30.obs;
  final RxString billingPeriod = 'monthly'.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool canStartTrial = false.obs;
  final RxBool hasUsedTrial = false.obs;

  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void onInit() {
    super.onInit();

    // Check authentication before loading data
    _initializeWithAuth();
  }

  // Initialize with authentication check
  Future<void> _initializeWithAuth() async {
    print('🔐 Initializing subscription controller...');

    // Wait a bit for AuthController to be ready
    await Future.delayed(Duration(milliseconds: 500));

    // Check if user is authenticated
    if (Get.isRegistered<AuthController>()) {
      final authController = Get.find<AuthController>();
      if (authController.isLoggedIn.value) {
        print('✅ User is authenticated, loading subscription data');
        await loadSubscriptionData();
      } else {
        print('⚠️ User not authenticated, skipping subscription load');
        errorMessage.value = 'Please login to view subscriptions';
      }
    } else {
      print('⚠️ AuthController not registered');
      errorMessage.value = 'Authentication service not available';
    }
  }

  // ============================================
  // Upgrade to a subscription package
  // ============================================

  Future<void> upgradeToPackage(SubscriptionPackage package) async {
    try {
      print('💰 Starting upgrade to: ${package.name}');

      isLoading(true);
      errorMessage.value = '';

      // Verify authentication
      final isAuth = await _subscriptionService.isAuthenticated();
      if (!isAuth) {
        _showAuthRequiredDialog();
        return;
      }

      // Show confirmation dialog
      final confirmed = await _showUpgradeConfirmation(package);
      if (!confirmed) {
        print('❌ User cancelled upgrade');
        isLoading(false);
        return;
      }

      // CHECK PLATFORM AND USE APPROPRIATE METHOD
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop platforms: Use Stripe Checkout (web-based)
        print('🖥️ Desktop platform detected - using Stripe Checkout');
        await _processWithStripeCheckout(package);
      } else {
        // Mobile platforms: Use native Stripe Payment Sheet
        print('📱 Mobile platform detected - using Payment Sheet');
        await _processWithPaymentSheet(package);
      }
    } catch (e) {
      print('❌ Upgrade error: $e');
      Get.snackbar(
        'Error',
        'Failed to complete payment: ${e.toString()}',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        icon: Icon(Icons.error_outline, color: Colors.red[900]),
      );
    } finally {
      isLoading(false);
    }
  }

  /// METHOD 1: Stripe Checkout (for Windows/Desktop)
  Future<void> _processWithStripeCheckout(SubscriptionPackage package) async {
    try {
      print('🔄 Creating Stripe Checkout session...');

      // Call backend to create checkout session
      final checkoutUrl = await _subscriptionService.createCheckoutSession(
        package.id,
        billingPeriod.value,
      );

      print('✅ Checkout session created');
      print('🌐 Opening browser: $checkoutUrl');

      // Open Stripe Checkout in browser
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Opens in default browser
        );

        // Show info dialog
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                Icon(Icons.open_in_browser, color: Colors.blue[700]),
                SizedBox(width: 12),
                Text('Complete Payment'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your browser has been opened to complete the payment.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  'After completing payment, return here and click "Check Payment Status".',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  _checkPaymentStatus(package);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                ),
                child: Text('Check Payment Status'),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      } else {
        throw Exception('Could not open browser');
      }
    } catch (e) {
      print('❌ Stripe Checkout error: $e');
      rethrow;
    }
  }

  /// METHOD 2: Payment Sheet (for Android/iOS)
  Future<void> _processWithPaymentSheet(SubscriptionPackage package) async {
    try {
      print('🔄 Creating payment intent...');

      final clientSecret = await _subscriptionService.createPaymentIntent(
        package.id,
        billingPeriod.value,
      );

      print('✅ Payment intent created');
      print('🔄 Initializing payment sheet...');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Driving School',
          style: ThemeMode.system,
        ),
      );

      print('✅ Payment sheet initialized');
      await Stripe.instance.presentPaymentSheet();
      print('✅ Payment completed');

      // Confirm with backend
      final paymentIntentId = clientSecret.split('_secret').first;
      final success = await _subscriptionService.confirmPayment(
        paymentIntentId,
        package.id,
        billingPeriod.value,
      );

      if (success) {
        print('✅ Payment confirmed');
        await loadSubscriptionData();

        Get.snackbar(
          'Success! 🎉',
          'Successfully upgraded to ${package.name}!',
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          icon: Icon(Icons.check_circle, color: Colors.green[700]),
        );

        Get.back();
      }
    } catch (e) {
      print('❌ Payment sheet error: $e');
      rethrow;
    }
  }

  /// Check payment status after returning from browser
  Future<void> _checkPaymentStatus(SubscriptionPackage package) async {
    try {
      Get.dialog(
        Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Wait a bit for webhook to process
      await Future.delayed(Duration(seconds: 2));

      // Reload subscription data
      await loadSubscriptionData();

      Get.back(); // Close loading dialog

      // Check if subscription was updated
      if (currentPackage.value?.id == package.id) {
        Get.snackbar(
          'Success! 🎉',
          'Payment completed! You are now on ${package.name} plan.',
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
          icon: Icon(Icons.check_circle, color: Colors.green[700]),
          duration: Duration(seconds: 4),
        );
        Get.back(); // Close subscription screen
      } else {
        Get.snackbar(
          'Checking...',
          'Payment may still be processing. Please wait a moment.',
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[900],
          icon: Icon(Icons.info_outline, color: Colors.orange[700]),
        );
      }
    } catch (e) {
      print('❌ Status check error: $e');
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Error',
        'Could not verify payment status. Please check your subscription.',
        backgroundColor: Colors.orange[100],
        colorText: Colors.orange[900],
      );
    }
  }

// Helper method for upgrade confirmation dialog
  Future<bool> _showUpgradeConfirmation(SubscriptionPackage package) async {
    final price = billingPeriod.value == 'yearly'
        ? package.yearlyPrice ?? package.monthlyPrice
        : package.monthlyPrice;

    final period = billingPeriod.value == 'yearly' ? 'year' : 'month';

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Confirm Upgrade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to upgrade to:'),
            SizedBox(height: 12),
            Text(
              package.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              '\$${price.toStringAsFixed(2)} / $period',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (billingPeriod.value == 'yearly' &&
                package.yearlyDiscount > 0) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Save ${package.yearlyDiscount}% with yearly billing',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: Text('Continue to Payment'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

// Auth required dialog
  void _showAuthRequiredDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange[700]),
            SizedBox(width: 12),
            Text('Login Required'),
          ],
        ),
        content: Text(
          'You need to be logged in to upgrade your subscription.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: Text('Login'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // Cancel subscription
  Future<void> cancelSubscription() async {
    try {
      final confirmed = await _showCancelConfirmation();
      if (!confirmed) return;

      isLoading(true);

      final success = await _subscriptionService.cancelSubscription();

      if (success) {
        await loadSubscriptionData();

        Get.snackbar(
          'Subscription Cancelled',
          'Your subscription has been cancelled',
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[900],
          icon: Icon(Icons.info_outline, color: Colors.orange[700]),
        );
      }
    } catch (e) {
      print('❌ Cancel error: $e');
      Get.snackbar(
        'Error',
        'Failed to cancel subscription',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        icon: Icon(Icons.error_outline, color: Colors.red[900]),
      );
    } finally {
      isLoading(false);
    }
  }

  // Show cancel confirmation
  Future<bool> _showCancelConfirmation() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Cancel Subscription?'),
        content: Text(
          'Are you sure you want to cancel your subscription? You\'ll lose access to premium features at the end of your billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Keep Subscription'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Check if user is eligible for trial
  Future<bool> checkTrialEligibility() async {
    try {
      final response = await _subscriptionService.checkTrialEligibility();

      canStartTrial.value = response['can_start_trial'] ?? false;
      hasUsedTrial.value = response['has_used_trial'] ?? false;

      print('🎫 Trial eligibility checked:');
      print('   Can start: ${canStartTrial.value}');
      print('   Has used: ${hasUsedTrial.value}');

      return canStartTrial.value;
    } catch (e) {
      print('❌ Error checking trial eligibility: $e');
      return false;
    }
  }

  /// Load subscription data with better error handling
  Future<void> loadSubscriptionData() async {
    try {
      isLoading(true);
      errorMessage.value = '';

      print('\n🔄 === LOADING SUBSCRIPTION DATA ===');

      // CRITICAL: Check internet connectivity first
      bool hasInternet = await _checkInternetConnection();

      if (!hasInternet) {
        print('📡 No internet - loading from cache directly');
        await _loadFromCacheWithValidation();
        return;
      }

      // Verify we have auth token before making API calls
      final hasValidToken = await _verifyAuthToken();

      if (!hasValidToken) {
        print('⚠️ No valid auth token - using cached data');
        await _loadFromCacheWithValidation();
        return;
      }

      // Try loading from server
      try {
        print('🌐 Loading subscription data from server...');

        final statusData = await _subscriptionService.getSubscriptionStatus();

        if (statusData != null) {
          subscriptionStatus.value =
              statusData['subscription_status'] as String? ?? 'trial';
          remainingTrialDays.value = statusData['remaining_trial_days'] ?? 0;

          // Load trial eligibility
          if (statusData['trial_eligibility'] != null) {
            final trialEligibility =
                statusData['trial_eligibility'] as Map<String, dynamic>;
            canStartTrial.value = trialEligibility['can_start_trial'] ?? false;
            hasUsedTrial.value = trialEligibility['has_used_trial'] ?? false;

            print('🎫 Trial Eligibility:');
            print('   Can start trial: ${canStartTrial.value}');
            print('   Has used trial: ${hasUsedTrial.value}');
          }

          if (statusData['current_package'] != null) {
            currentPackage.value = availablePackages.firstWhereOrNull(
                (pkg) => pkg.id == statusData['current_package']['id']);
          }

          print('✅ Subscription data loaded from server:');
          print('   - Status: ${subscriptionStatus.value}');
          print('   - Trial days: ${remainingTrialDays.value}');

          // IMPORTANT: Cache this data for offline use
          await SubscriptionCache.saveSubscriptionData(
            status: subscriptionStatus.value,
            trialDays: remainingTrialDays.value,
            expiresAt: statusData['subscription_expires_at'],
            packageId: currentPackage.value?.id,
            packageName: currentPackage.value?.name,
          );

          print('✅ Subscription data cached successfully');
        }
      } catch (e) {
        // Network error or timeout - use cached data
        print('⚠️ Failed to load from server: $e');
        print('📦 Falling back to cached subscription data');

        await _loadFromCacheWithValidation();
      }
    } catch (e) {
      print('❌ Error loading subscription data: $e');
      errorMessage.value = 'Failed to load subscription data: ${e.toString()}';

      // Try cache as last resort
      await _loadFromCacheWithValidation();
    } finally {
      isLoading(false);
    }
  }

  /// NEW: Check internet connectivity
  Future<bool> _checkInternetConnection() async {
    try {
      // Quick connectivity check
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 3));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('✅ Internet connection available');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ No internet connection: $e');
      return false;
    }
  }

  /// NEW: Load from cache with smart validation
  Future<void> _loadFromCacheWithValidation() async {
    try {
      print('📦 Loading subscription from cache...');

      final cachedData = await SubscriptionCache.getCachedSubscriptionData();

      if (cachedData == null) {
        print('⚠️ No cached data available');

        // Check if user just logged in
        if (Get.isRegistered<AuthController>()) {
          final authController = Get.find<AuthController>();
          if (authController.isLoggedIn.value) {
            // User is authenticated but no cache - assume trial
            print('ℹ️ Authenticated user with no cache - defaulting to trial');
            subscriptionStatus.value = 'trial';
            remainingTrialDays.value = 30; // Give benefit of doubt

            // Show warning
            Get.snackbar(
              'Offline Mode',
              'Unable to verify subscription. Please connect to internet.',
              backgroundColor: Colors.orange[700],
              colorText: Colors.white,
              icon: Icon(Icons.cloud_off, color: Colors.white),
              duration: Duration(seconds: 5),
            );
            return;
          }
        }

        // Not authenticated - block with trial expired
        subscriptionStatus.value = 'trial';
        remainingTrialDays.value = 0;
        return;
      }

      // Load from cache
      final status = cachedData['subscription_status'] as String;
      final trialDays = cachedData['remaining_trial_days'] as int;
      final daysSinceSync = cachedData['days_since_sync'] as int;

      print('✅ Loaded from cache:');
      print('   - Status: $status');
      print('   - Trial days: $trialDays');
      print('   - Days since sync: $daysSinceSync');

      // Set values
      subscriptionStatus.value = status;
      remainingTrialDays.value = trialDays;

      // Load package info if available
      if (cachedData['current_package'] != null) {
        final pkgData = cachedData['current_package'] as Map<String, dynamic>;
        currentPackage.value = availablePackages
            .firstWhereOrNull((pkg) => pkg.id == pkgData['id']);
      }

      // Show warning if cache is getting old
      if (daysSinceSync > 7) {
        print('⚠️ Cache is $daysSinceSync days old');
        Get.snackbar(
          'Subscription Check Needed',
          'Last verified $daysSinceSync days ago. Please connect to internet soon.',
          backgroundColor: Colors.orange[700],
          colorText: Colors.white,
          icon: Icon(Icons.warning_amber, color: Colors.white),
          duration: Duration(seconds: 5),
        );
      }

      print('✅ Successfully loaded from cache');
    } catch (e) {
      print('❌ Error loading from cache: $e');

      // Final fallback - if authenticated, give trial status
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        if (authController.isLoggedIn.value) {
          subscriptionStatus.value = 'trial';
          remainingTrialDays.value = 30;
          return;
        }
      }

      // Not authenticated - block
      subscriptionStatus.value = 'trial';
      remainingTrialDays.value = 0;
    }
  }

  /// NEW: Verify we have a valid auth token
  Future<bool> _verifyAuthToken() async {
    try {
      // Check if AuthController is available and has a user
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();

        if (authController.isLoggedIn.value &&
            authController.currentUser.value != null) {
          final email = authController.currentUser.value!.email;

          // Try to get the stored token
          final token = await _getStoredAuthToken();

          if (token != null && token.isNotEmpty) {
            print('✅ Auth token found: ${token.substring(0, 10)}...');

            // Set it in ApiService if not already set
            if (!ApiService.hasToken) {
              ApiService.setToken(token);
              print('✅ Token set in ApiService');
            }

            return true;
          } else {
            print('⚠️ No auth token found for $email');
            return false;
          }
        }
      }

      print('⚠️ AuthController not available or user not logged in');
      return false;
    } catch (e) {
      print('❌ Error verifying auth token: $e');
      return false;
    }
  }

  /// NEW: Get cache age in days
  Future<int?> _getCacheAge() async {
    try {
      final cachedData = await SubscriptionCache.getCachedSubscriptionData();

      if (cachedData != null && cachedData['synced_at'] != null) {
        final syncedAt = DateTime.parse(cachedData['synced_at']);
        final now = DateTime.now();
        final difference = now.difference(syncedAt);

        return difference.inDays;
      }

      return null;
    } catch (e) {
      print('❌ Error getting cache age: $e');
      return null;
    }
  }

  /// Load from cached data
  Future<void> _loadFromCache() async {
    try {
      final cachedData = await SubscriptionCache.getCachedSubscriptionData();

      if (cachedData != null) {
        subscriptionStatus.value = cachedData['status'] ?? 'trial';
        remainingTrialDays.value = cachedData['trial_days'] ?? 0;

        print('✅ Loaded from cache:');
        print('   - Status: ${subscriptionStatus.value}');
        print('   - Trial days: ${remainingTrialDays.value}');

        // Check cache age
        if (cachedData['synced_at'] != null) {
          final syncedAt = DateTime.parse(cachedData['synced_at']);
          final daysSinceSync = DateTime.now().difference(syncedAt).inDays;
          print('   - Cache age: $daysSinceSync days');
        }
      } else {
        print('❌ No cached data available');
        // Default to trial with 0 days
        subscriptionStatus.value = 'trial';
        remainingTrialDays.value = 0;
      }
    } catch (e) {
      print('❌ Error loading from cache: $e');
      // Default to trial with 0 days
      subscriptionStatus.value = 'trial';
      remainingTrialDays.value = 0;
    }
  }

  /// Get stored auth token (same method as AuthController)
  Future<String?> _getStoredAuthToken() async {
    try {
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        final user = authController.currentUser.value;

        if (user != null && user.email != null) {
          final prefs = await SharedPreferences.getInstance();
          final key = 'api_token_${user.email}';
          final token = prefs.getString(key);

          return token;
        }
      }

      return null;
    } catch (e) {
      print('❌ Error getting stored auth token: $e');
      return null;
    }
  }
}
