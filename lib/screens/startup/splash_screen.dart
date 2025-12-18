import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/services/app_bindings.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/settings_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final RxString loadingStatus = 'Initializing...'.obs;
  final RxDouble progress = 0.0.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeApp() async {
    try {
      // Update progress as each step completes
      loadingStatus.value = 'Loading wait...';
      progress.value = 0.1;
      await Future.delayed(const Duration(milliseconds: 100)); // Let UI update

      await DatabaseHelper.instance.database;
      progress.value = 0.3;

      loadingStatus.value = 'Almost there...';
      await Future.delayed(const Duration(milliseconds: 100)); // Let UI update

      await AppBindings().dependencies();
      progress.value = 0.8;

      loadingStatus.value = 'Almost ready...';
      await Future.delayed(const Duration(milliseconds: 100)); // Let UI update

      progress.value = 1.0;
      loadingStatus.value = 'Ready!';

      await Future.delayed(const Duration(milliseconds: 500));
      _navigateToInitialRoute();
    } catch (e) {
      print('❌ Splash screen initialization error: $e');
      hasError.value = true;
      errorMessage.value = 'Failed to initialize app: ${e.toString()}';
      loadingStatus.value = 'Initialization failed';
    }
  }

  Future<void> _navigateToInitialRoute() async {
    try {
      final settingsController = Get.find<SettingsController>();
      final pinController = Get.find<PinController>();
      final authController = Get.find<AuthController>();

      await settingsController.loadSettingsFromDatabase();
      pinController.isPinEnabled();

      String initialRoute;

      // Check if users exist FIRST
      final usersExist = await _checkIfUsersExist();

      // Only use PIN login if:
      // 1. Users exist in database (not first run)
      // 2. PIN is set and enabled
      // 3. User was previously verified
      if (usersExist &&
          pinController.isPinSet.value &&
          pinController.isPinEnabled.value &&
          await pinController.isUserVerified()) {
        if (pinController.isLocked.value) {
          initialRoute = '/login';
        } else {
          initialRoute = '/pin-login';
        }
      }
      // User logged in but PIN not set (optional setup)
      else if (authController.isLoggedIn.value &&
          !pinController.isPinSet.value) {
        initialRoute = '/main';
      }
      // Users exist locally - show login
      else if (usersExist) {
        initialRoute = '/login';
      }
      // First time - show login
      else {
        initialRoute = '/login';
      }

      Get.offAllNamed(initialRoute);
    } catch (e) {
      print('Error determining route: $e');
      Get.offAllNamed('/login');
    }
  }

  /// Check if any users exist in database
  Future<bool> _checkIfUsersExist() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final users = await db.query('users', limit: 1);
      return users.isNotEmpty;
    } catch (e) {
      print('Error checking users: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue,
              Colors.blue.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Obx(() => hasError.value
              ? _buildErrorView(context)
              : _buildLoadingView(context)),
        ),
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        // Animated Logo
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: 80,
              height: 80,
            ),
          ),
        ),

        const SizedBox(height: 40),

        // App Name
        Text(
          'DriveSync Pro',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 8),

        // Tagline
        Text(
          'Drive Smarter, Manage Easier',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0.5,
          ),
        ),

        const Spacer(flex: 1),

        // Progress Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60.0),
          child: Column(
            children: [
              // Progress Bar
              Obx(() => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.value,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )),

              const SizedBox(height: 16),

              // Status Text
              Obx(() => Text(
                    loadingStatus.value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  )),
            ],
          ),
        ),

        const Spacer(flex: 2),

        // Version Info
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'Initialization Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => Text(
                  errorMessage.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                )),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Reset and retry
                hasError.value = false;
                errorMessage.value = '';
                progress.value = 0.0;
                loadingStatus.value = 'Initializing...';
                _initializeApp();
              },
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
