// This screen checks subscription before showing the main app

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/subscription_controller.dart';
import 'package:driving/controllers/auth_controller.dart';

class SubscriptionCheckScreen extends StatefulWidget {
  final String nextRoute;

  const SubscriptionCheckScreen({
    Key? key,
    required this.nextRoute,
  }) : super(key: key);

  @override
  State<SubscriptionCheckScreen> createState() =>
      _SubscriptionCheckScreenState();
}

class _SubscriptionCheckScreenState extends State<SubscriptionCheckScreen> {
  final subscriptionController = Get.find<SubscriptionController>();
  final authController = Get.find<AuthController>();

  bool _isChecking = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkSubscriptionAndNavigate();
  }

  Future<void> _checkSubscriptionAndNavigate() async {
    try {
      setState(() {
        _isChecking = true;
        _errorMessage = '';
      });

      print('🔐 === APP STARTUP SUBSCRIPTION CHECK ===');
      print('Target route: ${widget.nextRoute}');

      // Check if user is authenticated
      if (!authController.isLoggedIn.value) {
        print('❌ User not authenticated, redirecting to login');
        Get.offAllNamed('/login');
        return;
      }

      // Load fresh subscription data from server
      print('🔄 Loading subscription status from server...');
      await subscriptionController.loadSubscriptionData();

      final status = subscriptionController.subscriptionStatus.value;
      final trialDays = subscriptionController.remainingTrialDays.value;

      print('📊 Subscription Status: $status');
      print('📊 Trial Days Remaining: $trialDays');

      // Check if subscription allows access
      if (status == 'suspended') {
        print('🚫 BLOCKED: Subscription is suspended');
        _showBlockedScreen('suspended');
        return;
      }

      if (status == 'expired') {
        print('🚫 BLOCKED: Subscription is expired');
        _showBlockedScreen('expired');
        return;
      }

      if (status == 'trial' && trialDays <= 0) {
        print('🚫 BLOCKED: Trial has expired');
        _showBlockedScreen('trial_expired');
        return;
      }

      // All checks passed - allow access
      print('✅ ALLOWED: Subscription is valid ($status, $trialDays days)');
      print('✅ Navigating to: ${widget.nextRoute}');

      // Navigate to the intended route
      Get.offAllNamed(widget.nextRoute);
    } catch (e) {
      print('❌ Error checking subscription: $e');
      setState(() {
        _isChecking = false;
        _errorMessage =
            'Failed to verify subscription status. Please check your internet connection.';
      });
    }
  }

  void _showBlockedScreen(String reason) {
    setState(() {
      _isChecking = false;
    });

    // Don't navigate - stay on this screen and show blocking UI
    // This prevents user from accessing the dashboard
  }

  @override
  Widget build(BuildContext context) {
    final status = subscriptionController.subscriptionStatus.value;
    final trialDays = subscriptionController.remainingTrialDays.value;

    // Show loading while checking
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text(
                'Verifying subscription...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error if check failed
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 24),
                Text(
                  'Connection Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _checkSubscriptionAndNavigate,
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show blocked screen based on status
    if (status == 'suspended') {
      return _buildSuspendedScreen();
    }

    if (status == 'expired') {
      return _buildExpiredScreen();
    }

    if (status == 'trial' && trialDays <= 0) {
      return _buildTrialExpiredScreen();
    }

    // This shouldn't happen, but just in case
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildSuspendedScreen() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red[700]!, Colors.red[900]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block,
                  size: 100,
                  color: Colors.white,
                ),
                SizedBox(height: 32),
                Text(
                  'Subscription Suspended',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Your subscription has been suspended. Please contact support to resolve this issue.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.support_agent, color: Colors.white, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Need Help?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Contact our support team:',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'support@drivesync.com',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await authController.logout();
                          Get.offAllNamed('/login');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white, width: 2),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('Logout'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _checkSubscriptionAndNavigate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red[700],
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('Check Again'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredScreen() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange[600]!, Colors.orange[800]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 100,
                  color: Colors.white,
                ),
                SizedBox(height: 32),
                Text(
                  'Subscription Expired',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Your subscription has expired. Renew now to continue using all features.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.star, color: Colors.orange[700], size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Renew Your Subscription',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Get back to managing your driving school with full access to all features.',
                        style: TextStyle(color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.offAllNamed('/subscription');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange[700],
                      padding: EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'View Subscription Plans',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await authController.logout();
                    Get.offAllNamed('/login');
                  },
                  child: Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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

  Widget _buildTrialExpiredScreen() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[900]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time_filled,
                  size: 100,
                  color: Colors.white,
                ),
                SizedBox(height: 32),
                Text(
                  'Free Trial Ended',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Your free trial has ended. Subscribe now to continue using all the amazing features!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[600]),
                          SizedBox(width: 8),
                          Text('Student Management'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[600]),
                          SizedBox(width: 8),
                          Text('Schedule Management'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[600]),
                          SizedBox(width: 8),
                          Text('Fleet Management'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[600]),
                          SizedBox(width: 8),
                          Text('Billing & Invoicing'),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        '...and much more!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.offAllNamed('/subscription');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue[700],
                      padding: EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star),
                        SizedBox(width: 8),
                        Text(
                          'Subscribe Now',
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
                TextButton(
                  onPressed: () async {
                    await authController.logout();
                    Get.offAllNamed('/login');
                  },
                  child: Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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
