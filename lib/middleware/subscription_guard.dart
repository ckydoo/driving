// This version ensures subscription data is loaded BEFORE checking

import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/subscription_controller.dart';
import 'package:driving/services/subscription_cache.dart';
import 'package:driving/settings/subscription_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SubscriptionGuard extends GetMiddleware {
  // Smart caching to avoid unnecessary API calls
  static DateTime? _lastCheck;
  static const Duration CACHE_DURATION = Duration(minutes: 15);
  static bool _isCurrentlyChecking = false;

  @override
  int? get priority => 2;

  @override
  GetPage? onPageCalled(GetPage? page) {
    try {
      final route = page?.name;

      // Skip check for these routes
      if (route == '/subscription' ||
          route?.contains('subscription') == true ||
          route == '/login' ||
          route == '/school-selection' ||
          route == '/school-registration' ||
          route == '/pin-setup' ||
          route == '/pin-login') {
        print(
            '✅ Allowing access to: $route (excluded from subscription check)');
        return page;
      }

      final authController = Get.find<AuthController>();

      // Only check if user is logged in
      if (!authController.isLoggedIn.value) {
        return page;
      }

      final subscriptionController = Get.find<SubscriptionController>();
      final now = DateTime.now();

      // ✅ FIX: More lenient data check - allow any valid status
      final hasLoadedData = subscriptionController.subscriptionStatus.value.isNotEmpty &&
          subscriptionController.subscriptionStatus.value != '' &&
          subscriptionController.subscriptionStatus.value != 'loading';

      // ✅ FIX: If data exists, trust it and allow navigation immediately
      if (hasLoadedData) {
        final status = subscriptionController.subscriptionStatus.value;

        // Only block if definitely invalid
        if (status == 'suspended' || status == 'expired') {
          print('🚫 BLOCKED: Status is $status');
          return GetPage(
            name: route ?? '/checking',
            page: () => _SubscriptionCheckingScreen(
              targetRoute: route ?? '/main',
              targetPage: page?.page,
            ),
          );
        }

        // ✅ Allow immediate access
        print('✅ Subscription OK ($status) - allowing access to: $route');

        // Refresh in background if cache is old
        _refreshInBackgroundIfNeeded(subscriptionController, now);

        return page;
      }

      // ✅ No data - need to check (but try to be fast)
      print('⚠️ No subscription data - checking...');
      return GetPage(
        name: route ?? '/checking',
        page: () => _SubscriptionCheckingScreen(
          targetRoute: route ?? '/main',
          targetPage: page?.page,
        ),
      );
    } catch (e) {
      print('❌ Subscription Guard Error: $e');
      // Fail open - allow access
      return page;
    }
  }

  /// Refresh in background if cache is old
  void _refreshInBackgroundIfNeeded(SubscriptionController controller, DateTime now) {
    // Don't block navigation - refresh in background
    if (_lastCheck == null || now.difference(_lastCheck!) > CACHE_DURATION) {
      Future.delayed(Duration(milliseconds: 500), () async {
        try {
          print('🔄 Refreshing subscription in background...');
          await controller.loadSubscriptionData();
          _lastCheck = DateTime.now();
        } catch (e) {
          print('⚠️ Background refresh failed: $e');
        }
      });
    }
  }

  /// Mark that subscription check completed
  static void markCheckCompleted() {
    _lastCheck = DateTime.now();
    _isCurrentlyChecking = false;
    print('✅ Subscription check completed - cache valid for ${CACHE_DURATION.inMinutes} minutes');
  }

  /// Force refresh on next navigation
  static void invalidateCache() {
    _lastCheck = null;
    print('🔄 Subscription cache invalidated');
  }
}

/// Screen that checks subscription status before allowing access
class _SubscriptionCheckingScreen extends StatefulWidget {
  final String targetRoute;
  final GetPageBuilder? targetPage;

  const _SubscriptionCheckingScreen({
    Key? key,
    required this.targetRoute,
    this.targetPage,
  }) : super(key: key);

  @override
  State<_SubscriptionCheckingScreen> createState() =>
      _SubscriptionCheckingScreenState();
}

class _SubscriptionCheckingScreenState
    extends State<_SubscriptionCheckingScreen> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionAndProceed();
  }

  Future<void> _checkSubscriptionAndProceed() async {
    try {
      print('🔄 Checking subscription status...');
      SubscriptionGuard._isCurrentlyChecking = true;

      final subscriptionController = Get.find<SubscriptionController>();

      // ✅ FIX: Check if data exists first
      final hasExistingData = subscriptionController.subscriptionStatus.value.isNotEmpty &&
          subscriptionController.subscriptionStatus.value != '' &&
          subscriptionController.subscriptionStatus.value != 'loading';

      if (!hasExistingData) {
        print('📡 No data - loading...');

        // ✅ Try cache first (instant)
        try {
          await subscriptionController.loadFromCache();
        } catch (e) {
          print('⚠️ Cache load failed: $e');
        }

        // ✅ If still empty, try server (but timeout fast)
        if (subscriptionController.subscriptionStatus.value.isEmpty ||
            subscriptionController.subscriptionStatus.value == '') {
          try {
            await subscriptionController.loadSubscriptionData()
                .timeout(Duration(seconds: 3)); // ✅ Fast timeout
          } catch (e) {
            print('⚠️ Server load failed/timeout: $e');
            // Continue with whatever we have
          }
        }
      } else {
        print('✅ Using existing subscription data');
      }

      final status = subscriptionController.subscriptionStatus.value;
      final trialDays = subscriptionController.remainingTrialDays.value;

      print('📊 Status: $status, Trial: $trialDays');

      SubscriptionGuard.markCheckCompleted();

      // ✅ Only block for definite invalid states
      if (status == 'suspended' || status == 'expired') {
        print('🚫 BLOCKED: $status');
        _showBlockedScreen(status);
        return;
      }

      if (status == 'trial' && trialDays <= 0) {
        print('🚫 BLOCKED: Trial expired');
        _showBlockedScreen('trial_expired');
        return;
      }

      // ✅ Allow access
      print('✅ ALLOWED: Proceeding to ${widget.targetRoute}');

      if (!mounted) return;

      // Navigate immediately
      Future.microtask(() {
        if (widget.targetPage != null) {
          Get.off(() => widget.targetPage!());
        } else {
          Get.offAllNamed(widget.targetRoute);
        }
      });
    } catch (e) {
      print('❌ Error: $e');
      SubscriptionGuard._isCurrentlyChecking = false;

      // ✅ On error, allow access with warning
      if (!mounted) return;

      Get.snackbar(
        'Offline Mode',
        'Using cached subscription',
        backgroundColor: Colors.orange[100],
        duration: Duration(seconds: 2),
      );

      Future.delayed(Duration(milliseconds: 300), () {
        if (!mounted) return;
        if (widget.targetPage != null) {
          Get.off(() => widget.targetPage!());
        } else {
          Get.offAllNamed(widget.targetRoute);
        }
      });
    } finally {
      SubscriptionGuard._isCurrentlyChecking = false;
    }
  }

  void _showBlockedScreen(String reason) {
    if (!mounted) return;

    setState(() {
      _isChecking = false;
    });
  }

  void _showNoCacheError() {
    if (!mounted) return;

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.red[700]),
            SizedBox(width: 12),
            Text('Internet Required'),
          ],
        ),
        content: Text(
          'Cannot verify your subscription without internet connection.\n\n'
          'Please connect to the internet and try again.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed('/login');
            },
            child: Text('Exit'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              setState(() {
                _isChecking = true;
              });
              _checkSubscriptionAndProceed();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: Text('Retry'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showStaleCacheError(int daysSinceSync) {
    if (!mounted) return;

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700]),
            SizedBox(width: 12),
            Text('Subscription Verification Required'),
          ],
        ),
        content: Text(
          'Your subscription data is $daysSinceSync days old.\n\n'
          'Please connect to the internet to verify your subscription status.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed('/login');
            },
            child: Text('Logout'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              setState(() {
                _isChecking = true;
              });
              _checkSubscriptionAndProceed();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: Text('Retry'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Show loading while checking
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    // Show blocking screen
    final subscriptionController = Get.find<SubscriptionController>();
    final status = subscriptionController.subscriptionStatus.value;

    String reason;
    String title;
    String message;
    String? contactEmail;
    bool showUpgradeButton;
    Color primaryColor;
    IconData icon;

    if (status == 'suspended') {
      reason = 'suspended';
      title = 'Account Suspended';
      message =
          'Your subscription has been suspended. Please update your payment method or contact support.';
      contactEmail = 'support@drivesync.com';
      showUpgradeButton = true;
      primaryColor = Colors.red;
      icon = Icons.block;
    } else if (status == 'expired') {
      reason = 'expired';
      title = 'Subscription Expired';
      message =
          'Your subscription has expired. Please renew to continue using all features.';
      contactEmail = null;
      showUpgradeButton = true;
      primaryColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
    } else {
      reason = 'trial_expired';
      title = 'Free Trial Ended';
      message =
          'Your free trial has ended. Subscribe now to continue using the service.';
      contactEmail = null;
      showUpgradeButton = true;
      primaryColor = Colors.blue;
      icon = Icons.access_time_filled;
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor!, primaryColor!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 80,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 32),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 16),

                // Message
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),

                // Contact email (for suspended accounts)
                if (contactEmail != null) ...[
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Contact Support',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          contactEmail,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 48),

                // Action buttons
                if (showUpgradeButton) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.to(() => SubscriptionScreen());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, size: 24),
                          SizedBox(width: 8),
                          Text(
                            reason == 'suspended'
                                ? 'Update Payment Method'
                                : 'View Subscription Plans',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final authController = Get.find<AuthController>();
                      await authController.signOut();
                      Get.offAllNamed('/login');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white, width: 2),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to check subscription status from anywhere in the app
class SubscriptionHelper {
  static bool get isSubscriptionActive {
    try {
      if (!Get.isRegistered<SubscriptionController>()) {
        return true;
      }

      final controller = Get.find<SubscriptionController>();
      final status = controller.subscriptionStatus.value;

      return status == 'active' ||
          (status == 'trial' && controller.remainingTrialDays.value > 0);
    } catch (e) {
      print('Error checking subscription: $e');
      return true;
    }
  }

  static Future<bool> checkIsActive() async {
    try {
      if (!Get.isRegistered<SubscriptionController>()) {
        return true;
      }

      final controller = Get.find<SubscriptionController>();

      try {
        await controller.loadSubscriptionData();
      } catch (e) {
        print('⚠️ Could not refresh subscription status: $e');
      }

      return isSubscriptionActive;
    } catch (e) {
      print('Error checking subscription: $e');
      return true;
    }
  }

  static bool get isTrialExpired {
    try {
      if (!Get.isRegistered<SubscriptionController>()) return false;

      final controller = Get.find<SubscriptionController>();
      return controller.subscriptionStatus.value == 'trial' &&
          controller.remainingTrialDays.value <= 0;
    } catch (e) {
      return false;
    }
  }

  static bool get isSuspended {
    try {
      if (!Get.isRegistered<SubscriptionController>()) return false;

      final controller = Get.find<SubscriptionController>();
      return controller.subscriptionStatus.value == 'suspended';
    } catch (e) {
      return false;
    }
  }

  static bool get isExpired {
    try {
      if (!Get.isRegistered<SubscriptionController>()) return false;

      final controller = Get.find<SubscriptionController>();
      return controller.subscriptionStatus.value == 'expired';
    } catch (e) {
      return false;
    }
  }
}
