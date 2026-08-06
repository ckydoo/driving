import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/settings_controller.dart';
import 'package:driving/services/app_bindings.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      loadingStatus.value = 'Loading wait...';
      progress.value = 0.1;
      await Future.delayed(const Duration(milliseconds: 100));

      await DatabaseHelper.instance.database;
      progress.value = 0.3;

      loadingStatus.value = 'Almost there...';
      await Future.delayed(const Duration(milliseconds: 100));

      await AppBindings().dependencies();
      progress.value = 0.8;

      loadingStatus.value = 'Almost ready...';
      await Future.delayed(const Duration(milliseconds: 100));

      progress.value = 1.0;
      loadingStatus.value = 'Ready!';

      await Future.delayed(const Duration(milliseconds: 500));
      _navigateToInitialRoute();
    } catch (e) {
      debugPrint('❌ Splash screen initialization error: $e');
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
      final usersExist = await _checkIfUsersExist();

      if (usersExist &&
          pinController.isPinSet.value &&
          pinController.isPinEnabled.value &&
          await pinController.isUserVerified()) {
        initialRoute = pinController.isLocked.value ? '/login' : '/pin-login';
      } else if (authController.isLoggedIn.value &&
          !pinController.isPinSet.value) {
        initialRoute = '/main';
      } else {
        initialRoute = '/login';
      }

      Get.offAllNamed(initialRoute);
    } catch (e) {
      debugPrint('Error determining route: $e');
      Get.offAllNamed('/login');
    }
  }

  Future<bool> _checkIfUsersExist() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final users = await db.query('users', limit: 1);
      return users.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking users: $e');
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
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient(
              isDark: theme.brightness == Brightness.dark),
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
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.18),
                  blurRadius: 24,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Image.asset('assets/images/logo.png', width: 80, height: 80),
          ),
        ),
        const SizedBox(height: 36),
        Text(
          'DriveSync Pro',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Drive smarter, manage easier',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(flex: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60.0),
          child: Column(
            children: [
              Obx(() => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress.value,
                      minHeight: 7,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )),
              const SizedBox(height: 16),
              Obx(() => Text(
                    loadingStatus.value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  )),
            ],
          ),
        ),
        const Spacer(flex: 2),
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Text(
            'Version 1.0.0',
            style:
                TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
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
            Icon(Icons.error_outline, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            Text(
              'Initialization Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
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
                hasError.value = false;
                errorMessage.value = '';
                progress.value = 0.0;
                loadingStatus.value = 'Initializing...';
                _initializeApp();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
