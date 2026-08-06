import 'dart:io';
import 'package:driving/models/subscription_package.dart';
import 'package:driving/services/api_service.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/subscription_cache.dart';
import 'package:driving/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionController extends GetxController {
  // Observable variables
  final RxList<SubscriptionPackage> availablePackages =
      <SubscriptionPackage>[].obs;
  final Rxn<SubscriptionPackage> currentPackage = Rxn<SubscriptionPackage>();
  final RxString subscriptionStatus = 'trial'.obs;
  final RxInt remainingTrialDays = 7.obs;
  final RxString billingPeriod = 'monthly'.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool canStartTrial = false.obs;
  final RxBool hasUsedTrial = false.obs;
  final Rxn<dynamic> pendingSubscriptionInvoice = Rxn<dynamic>();
  final RxBool hasInternetConnection = true.obs; // ✅ NEW: Track connectivity
  final RxBool isUsingCachedData = false.obs; // ✅ NEW: Track if using cached data

  final SubscriptionService _subscriptionService = SubscriptionService();
  final Rx<DateTime?> subscriptionExpiresAt = Rx<DateTime?>(null);

  String get displayPrice {
    if (currentPackage.value == null) return '\$0.00';

    if (billingPeriod.value == 'yearly') {
      final yearlyPrice = currentPackage.value!.yearlyPrice ??
          (currentPackage.value!.monthlyPrice * 12);
      return '\$${yearlyPrice.toStringAsFixed(2)}/year';
    }

    return '\$${currentPackage.value!.monthlyPrice.toStringAsFixed(2)}/month';
  }

  String get expiryDisplayText {
    if (subscriptionExpiresAt.value == null) return 'No expiry';

    final now = DateTime.now();
    final expiry = subscriptionExpiresAt.value!;

    if (expiry.isBefore(now)) {
      return 'Expired';
    }

    final daysUntilExpiry = expiry.difference(now).inDays;

    if (daysUntilExpiry == 0) {
      return 'Expires today';
    } else if (daysUntilExpiry == 1) {
      return 'Expires tomorrow';
    } else if (daysUntilExpiry <= 7) {
      return 'Expires in $daysUntilExpiry days';
    } else {
      return 'Expires: ${DateFormat('MMM dd, yyyy').format(expiry)}';
    }
  }

  @override
  void onInit() {
    super.onInit();

    // Check authentication before loading data
    _initializeWithAuth();
  }

  // Initialize with authentication check
  Future<void> _initializeWithAuth() async {
    debugPrint('🔐 Initializing subscription controller...');

    // ✅ FIXED: Load cache FIRST (instant, no delay)
    debugPrint('📦 Loading subscription from cache immediately...');
    await _loadFromCache();
    isUsingCachedData.value = true; // Mark as using cached data initially

    // ✅ REMOVED: No delay needed - just refresh in background
    _refreshFromServerInBackground();
  }

  // ✅ NEW: Refresh in background without blocking initialization
  Future<void> _refreshFromServerInBackground() async {
    try {
      bool hasInternet = await _checkInternetConnection();
      hasInternetConnection.value = hasInternet;

      if (!hasInternet) {
        debugPrint('📡 No internet - using cached subscription');
        return;
      }

      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        if (authController.isLoggedIn.value) {
          debugPrint('✅ User is authenticated, refreshing from server in background');
          await loadSubscriptionData(); // Refresh from server
          isUsingCachedData.value = false; // ✅ Now using fresh data
        } else {
          debugPrint('⚠️ User not authenticated via API, using cached data');
        }
      } else {
        debugPrint('⚠️ AuthController not registered, using cached data');
      }
    } catch (e) {
      debugPrint('⚠️ Background refresh failed: $e');
      // Don't throw - cache is already loaded
    }
  }

  // ============================================
  // Upgrade to a subscription package
  // ============================================

  Future<void> upgradeToPackage(SubscriptionPackage package) async {
    // Verify authentication first
    final isAuth = await _subscriptionService.isAuthenticated();
    if (!isAuth) {
      _showAuthRequiredDialog();
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            SizedBox(width: 12),
            Text('Payment Coming Soon'),
          ],
        ),
        content: Text(
          'Online payments will be available shortly. Please contact support to upgrade to ${package.name}.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
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
      debugPrint('❌ Cancel error: $e');
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

      debugPrint('🎫 Trial eligibility checked:');
      debugPrint('   Can start: ${canStartTrial.value}');
      debugPrint('   Has used: ${hasUsedTrial.value}');

      return canStartTrial.value;
    } catch (e) {
      debugPrint('❌ Error checking trial eligibility: $e');
      return false;
    }
  }

  /// ✅ NEW: Force refresh subscription (call when user comes back online)
  Future<void> forceRefreshSubscription() async {
    debugPrint('🔄 Force refreshing subscription...');
    errorMessage.value = '';
    isLoading.value = true;

    try {
      // Check connectivity first
      bool hasInternet = await _checkInternetConnection();
      hasInternetConnection.value = hasInternet;

      if (!hasInternet) {
        Get.snackbar(
          'No Internet',
          'Please check your internet connection and try again.',
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[900],
          icon: Icon(Icons.wifi_off, color: Colors.orange[700]),
          duration: Duration(seconds: 3),
        );
        isLoading.value = false;
        return;
      }

      await loadSubscriptionData();
      debugPrint('✅ Force refresh completed');

      Get.snackbar(
        'Subscription Updated',
        'Your subscription status has been refreshed',
        backgroundColor: Colors.green[100],
        colorText: Colors.green[900],
        icon: Icon(Icons.check_circle, color: Colors.green[700]),
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('❌ Force refresh failed: $e');
      Get.snackbar(
        'Refresh Failed',
        'Could not refresh subscription. Using cached data.',
        backgroundColor: Colors.orange[100],
        colorText: Colors.orange[900],
        icon: Icon(Icons.warning, color: Colors.orange[700]),
        duration: Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Load subscription data with better error handling
  Future<void> loadSubscriptionData() async {
    try {
      isLoading(true);
      errorMessage.value = '';

      debugPrint('\n🔄 === LOADING SUBSCRIPTION DATA ===');
      bool hasInternet = await _checkInternetConnection();
      hasInternetConnection.value = hasInternet; // ✅ Update connectivity status

      if (!hasInternet) {
        debugPrint('📡 No internet - loading from cache directly');
        isUsingCachedData.value = true; // ✅ Mark as using cached data
        await _loadFromCacheWithValidation();
        return;
      }

      // Verify we have auth token before making API calls
      final hasValidToken = await _verifyAuthToken();

      if (!hasValidToken) {
        debugPrint('⚠️ No valid auth token - using cached data');
        await _loadFromCacheWithValidation();
        return;
      }

      // Try loading from server
      try {
        debugPrint('🌐 Loading subscription data from server...');

        debugPrint('📦 Loading available packages...');
        try {
          final packages = await _subscriptionService.getSubscriptionPackages();
          availablePackages.value = packages;
          debugPrint('✅ Loaded ${packages.length} packages');
        } catch (e) {
          debugPrint('⚠️ Failed to load packages: $e');
          // Don't fail completely if packages fail to load
          // User can still see their subscription status
        }

        // Then load subscription status
        final statusData = await _subscriptionService.getSubscriptionStatus();

        if (statusData != null) {
          subscriptionStatus.value =
              statusData['subscription_status'] as String? ?? 'trial';
          remainingTrialDays.value = statusData['remaining_trial_days'] ?? 0;

          billingPeriod.value =
              statusData['billing_period'] as String? ?? 'monthly';
          debugPrint('💳 Billing period: ${billingPeriod.value}');

          // ✅ FIXED: Check both subscription_expires_at and trial_ends_at
          String? expiryDateString;

          if (subscriptionStatus.value == 'trial' &&
              statusData['trial_ends_at'] != null) {
            // For trial users, use trial_ends_at
            expiryDateString = statusData['trial_ends_at'];
            debugPrint('📅 Using trial_ends_at for trial user');
          } else if (statusData['subscription_expires_at'] != null) {
            // For paid users, use subscription_expires_at
            expiryDateString = statusData['subscription_expires_at'];
            debugPrint('📅 Using subscription_expires_at for paid user');
          }

          if (expiryDateString != null) {
            try {
              subscriptionExpiresAt.value = DateTime.parse(expiryDateString);
              debugPrint('✅ Expires at: ${subscriptionExpiresAt.value}');
            } catch (e) {
              debugPrint('⚠️ Failed to parse expiry date: $e');
              subscriptionExpiresAt.value = null;
            }
          } else {
            subscriptionExpiresAt.value = null;
            debugPrint('⚠️ No expiry date found in response');
          }

          // Load trial eligibility
          if (statusData['trial_eligibility'] != null) {
            final trialEligibility =
                statusData['trial_eligibility'] as Map<String, dynamic>;
            canStartTrial.value = trialEligibility['can_start_trial'] ?? false;
            hasUsedTrial.value = trialEligibility['has_used_trial'] ?? false;

            debugPrint('🎫 Trial Eligibility:');
            debugPrint('   Can start trial: ${canStartTrial.value}');
            debugPrint('   Has used trial: ${hasUsedTrial.value}');
          }

          if (statusData['current_package'] != null) {
            final packageData = statusData['current_package'];
            currentPackage.value = SubscriptionPackage(
              id: packageData['id'],
              name: packageData['name'],
              slug: packageData['slug'],
              monthlyPrice: _parsePrice(packageData['monthly_price']), // ✅ Safe
              yearlyPrice: _parsePrice(packageData['yearly_price']), // ✅ Safe
              yearlyDiscount: packageData['yearly_discount'] ?? 0,
              features: List<String>.from(packageData['features'] ?? []),
              limits: Map<String, dynamic>.from(
                  packageData['limits'] ?? <String, dynamic>{}),
              trialDays: packageData['trial_days'] ?? 0,
              isPopular: packageData['is_popular'] ?? false,
            );
            debugPrint('✅ Current package: ${currentPackage.value!.name}');
          } else {
            currentPackage.value = null;
            debugPrint('ℹ️ No current package found');
          }

          // ✅ SAVE TO CACHE for offline access
          await _saveToCache();
          debugPrint('✅ Subscription data cached successfully');
          isUsingCachedData.value = false; // ✅ Successfully loaded fresh data
        }
      } catch (e) {
        // Network error or timeout - use cached data
        debugPrint('⚠️ Failed to load from server: $e');
        debugPrint('📦 Falling back to cached subscription data');
        isUsingCachedData.value = true; // ✅ Mark as using cached data
        await _loadFromCacheWithValidation();
      }
    } catch (e) {
      debugPrint('❌ Error loading subscription data: $e');
      errorMessage.value = 'Failed to load subscription data: ${e.toString()}';
      isUsingCachedData.value = true; // ✅ Mark as using cached data
      // Try cache as last resort
      await _loadFromCacheWithValidation();
    } finally {
      isLoading(false);
    }
  }

// Add at the top of SubscriptionController class
  double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<bool> _checkInternetConnection() async {
    try {
      // Quick connectivity check
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 3));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        debugPrint('✅ Internet connection available');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ No internet connection: $e');
      return false;
    }
  }

  Future<void> _loadFromCacheWithValidation() async {
    try {
      debugPrint('📦 Loading subscription from cache...');

      final cachedData = await SubscriptionCache.getCachedSubscriptionData();

      if (cachedData == null) {
        debugPrint('⚠️ No cached data available');

        // Check if user just logged in
        if (Get.isRegistered<AuthController>()) {
          final authController = Get.find<AuthController>();
          if (authController.isLoggedIn.value) {
            // User is authenticated but no cache - assume trial
            debugPrint('ℹ️ Authenticated user with no cache - defaulting to trial');
            subscriptionStatus.value = 'trial';
            remainingTrialDays.value = 7; // Give benefit of doubt

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
      final cachedBillingPeriod = cachedData['billing_period'] as String? ?? 'monthly';

      debugPrint('✅ Loaded from cache:');
      debugPrint('   - Status: $status');
      debugPrint('   - Trial days: $trialDays');
      debugPrint('   - Billing period: $cachedBillingPeriod');
      debugPrint('   - Days since sync: $daysSinceSync');

      // Set values
      subscriptionStatus.value = status;
      remainingTrialDays.value = trialDays;
      billingPeriod.value = cachedBillingPeriod;

      // Load expiry date if available
      if (cachedData['subscription_expires_at'] != null) {
        try {
          subscriptionExpiresAt.value = DateTime.parse(cachedData['subscription_expires_at'] as String);
          debugPrint('   - Expires at: ${subscriptionExpiresAt.value}');
        } catch (e) {
          debugPrint('⚠️ Failed to parse cached expiry date: $e');
          subscriptionExpiresAt.value = null;
        }
      }

      // Load package info if available
      if (cachedData['current_package'] != null) {
        final pkgData = cachedData['current_package'] as Map<String, dynamic>;
        currentPackage.value = availablePackages
            .firstWhereOrNull((pkg) => pkg.id == pkgData['id']);
      }

      // Show warning if cache is getting old
      if (daysSinceSync > 7) {
        debugPrint('⚠️ Cache is $daysSinceSync days old');
        Get.snackbar(
          'Subscription Check Needed',
          'Last verified $daysSinceSync days ago. Please connect to internet soon.',
          backgroundColor: Colors.orange[700],
          colorText: Colors.white,
          icon: Icon(Icons.warning_amber, color: Colors.white),
          duration: Duration(seconds: 5),
        );
      }

      debugPrint('✅ Successfully loaded from cache');
    } catch (e) {
      debugPrint('❌ Error loading from cache: $e');

      // Final fallback - if authenticated, give trial status
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        if (authController.isLoggedIn.value) {
          subscriptionStatus.value = 'trial';
          remainingTrialDays.value = 7;
          return;
        }
      }

      // Not authenticated - block
      subscriptionStatus.value = 'trial';
      remainingTrialDays.value = 0;
    }
  }

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
            debugPrint('✅ Auth token found: ${token.substring(0, 10)}...');

            // Set it in ApiService if not already set
            if (!ApiService.hasToken) {
              ApiService.setToken(token);
              debugPrint('✅ Token set in ApiService');
            }

            return true;
          } else {
            debugPrint('⚠️ No auth token found for $email');
            return false;
          }
        }
      }

      debugPrint('⚠️ AuthController not available or user not logged in');
      return false;
    } catch (e) {
      debugPrint('❌ Error verifying auth token: $e');
      return false;
    }
  }

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
      debugPrint('❌ Error getting cache age: $e');
      return null;
    }
  }

  /// Public method to load from cache (can be called externally)
  Future<void> loadFromCache() async {
    await _loadFromCache();
  }

  /// Load from cached data
  Future<void> _loadFromCache() async {
    try {
      final cachedData = await SubscriptionCache.getCachedSubscriptionData();

      if (cachedData != null) {
        // ✅ FIXED: Use correct field names
        subscriptionStatus.value = cachedData['subscription_status'] ?? 'trial';
        remainingTrialDays.value = cachedData['remaining_trial_days'] ?? 0;
        billingPeriod.value = cachedData['billing_period'] ?? 'monthly';

        debugPrint('✅ Loaded from cache:');
        debugPrint('   - Status: ${subscriptionStatus.value}');
        debugPrint('   - Trial days: ${remainingTrialDays.value}');
        debugPrint('   - Billing period: ${billingPeriod.value}');

        // Load expiry date if available
        if (cachedData['subscription_expires_at'] != null) {
          try {
            subscriptionExpiresAt.value = DateTime.parse(cachedData['subscription_expires_at']);
            debugPrint('   - Expires at: ${subscriptionExpiresAt.value}');
          } catch (e) {
            debugPrint('⚠️ Failed to parse cached expiry date: $e');
            subscriptionExpiresAt.value = null;
          }
        }

        // Check cache age
        if (cachedData['synced_at'] != null) {
          final syncedAt = DateTime.parse(cachedData['synced_at']);
          final daysSinceSync = DateTime.now().difference(syncedAt).inDays;
          debugPrint('   - Cache age: $daysSinceSync days');
        }
      } else {
        debugPrint('❌ No cached data available');
        // Default to trial with 0 days
        subscriptionStatus.value = 'trial';
        remainingTrialDays.value = 0;
      }
    } catch (e) {
      debugPrint('❌ Error loading from cache: $e');
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
      debugPrint('❌ Error getting stored auth token: $e');
      return null;
    }
  }

  /// Save current subscription data to cache for offline access
  Future<void> _saveToCache() async {
    try {
      debugPrint('💾 Saving subscription data to cache...');

      // Save to database cache
      final db = await DatabaseHelper.instance.database;

      await db.delete('subscription_cache');

      await db.insert('subscription_cache', {
        'id': 1,
        'subscription_status': subscriptionStatus.value,
        'remaining_trial_days': remainingTrialDays.value,
        'subscription_expires_at': subscriptionExpiresAt.value?.toIso8601String(),
        'billing_period': billingPeriod.value,
        'last_synced_at': DateTime.now().toIso8601String(),
        'current_package_id': currentPackage.value?.id,
        'current_package_name': currentPackage.value?.name,
      });

      // Also save to SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription_status', subscriptionStatus.value);
      await prefs.setInt('remaining_trial_days', remainingTrialDays.value);
      await prefs.setString('billing_period', billingPeriod.value);

      if (subscriptionExpiresAt.value != null) {
        await prefs.setString('subscription_expires_at', subscriptionExpiresAt.value!.toIso8601String());
      }

      if (currentPackage.value != null) {
        await prefs.setInt('current_package_id', currentPackage.value!.id);
        await prefs.setString('current_package_name', currentPackage.value!.name);
      }

      await prefs.setString('last_synced_at', DateTime.now().toIso8601String());

      debugPrint('✅ Subscription data saved to cache successfully');
      debugPrint('   - Status: ${subscriptionStatus.value}');
      debugPrint('   - Trial Days: ${remainingTrialDays.value}');
      debugPrint('   - Billing Period: ${billingPeriod.value}');
      debugPrint('   - Expires At: ${subscriptionExpiresAt.value}');
    } catch (e) {
      debugPrint('❌ Error saving to cache: $e');
      // Don't throw - caching failure shouldn't break the app
    }
  }
}
