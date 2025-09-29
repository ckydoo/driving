// lib/screens/auth/enhanced_pin_login_screen.dart - Complete Fixed Version
import 'package:driving/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/api_service.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({Key? key}) : super(key: key);

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen>
    with TickerProviderStateMixin {
  // SAFE CONTROLLER ACCESS - No more "Bad state: No element"
  PinController? _pinController;
  AuthController? _authController;

  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  // REACTIVE VARIABLES - These were missing in your code
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool controllersReady = false.obs; // This was missing!

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  /// SAFE INITIALIZATION
  Future<void> _initializeScreen() async {
    try {
      print('🔐 Initializing EnhancedPinLoginScreen...');

      // Initialize animation controller first
      _shakeController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      _shakeAnimation = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
      );

      // Initialize controllers safely
      await _initializeControllers();

      // Auto focus first PIN field after controllers are ready
      if (mounted && controllersReady.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pinFocusNodes.isNotEmpty) {
            _pinFocusNodes[0].requestFocus();
          }
        });
      }

      print('✅ EnhancedPinLoginScreen initialized successfully');
    } catch (e) {
      print('❌ Error initializing PIN login screen: $e');
      _showInitializationError();
    }
  }

  /// SAFE CONTROLLER INITIALIZATION
  Future<void> _initializeControllers() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      // Initialize PinController
      try {
        _pinController = Get.find<PinController>();
        print('✅ Found existing PinController');
      } catch (e) {
        print('⚠️ Creating new PinController: $e');
        _pinController = Get.put(PinController(), permanent: true);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Initialize AuthController
      try {
        _authController = Get.find<AuthController>();
        print('✅ Found existing AuthController');
      } catch (e) {
        print('⚠️ Creating new AuthController: $e');
        _authController = Get.put(AuthController(), permanent: true);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Verify controllers are working
      if (_pinController == null || _authController == null) {
        throw Exception('Failed to initialize controllers');
      }

      // Test controller access
      await _pinController!.getPinInfo();
      final _ = _authController!.isLoggedIn.value;

      controllersReady.value = true;
      print('✅ All controllers ready');
    } catch (e) {
      print('❌ Controller initialization error: $e');
      controllersReady.value = false;
      _showInitializationError();
    }
  }

  /// PIN VERIFICATION WITH ENHANCED ERROR HANDLING
  Future<void> _verifyPin() async {
    if (currentPin.length != 4) return;

    // Check if controllers are ready
    if (!controllersReady.value || _authController == null) {
      errorMessage.value = 'System not ready. Please wait...';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      print('🔐 Starting PIN verification...');

      final success = await _authController!.authenticateWithPin(currentPin);

      if (success) {
        print('✅ PIN verification successful');

        // Check if sync is available
        if (ApiService.hasToken) {
          print('✅ Sync available - proceeding to main app');
          AppRoutes.toMain();
        } else {
          print('⚠️ PIN login successful but sync unavailable');
          // Still go to main app - user will see sync dialogs if needed
          AppRoutes.toMain();
        }
      } else {
        print('❌ PIN verification failed');
        errorMessage.value = 'Invalid PIN. Please try again.';
        _showError();
        _clearPin();
      }
    } catch (e) {
      print('❌ PIN verification error: $e');
      _handleVerificationError(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Handle different types of verification errors
  void _handleVerificationError(dynamic error) {
    String errorString = error.toString();

    if (errorString.contains('Bad state: No element')) {
      errorMessage.value = 'Data error detected. Please use password login.';
      _showPasswordLoginOption();
    } else if (errorString.contains('No authentication token')) {
      errorMessage.value =
          'Sync not available. Continue offline or sign in with password.';
      _showSyncUnavailableOption();
    } else if (errorString.contains('Invalid PIN')) {
      errorMessage.value = 'Invalid PIN. Please try again.';
      _showError();
      _clearPin();
    } else {
      errorMessage.value = 'Login failed. Please try again.';
      _showError();
      _clearPin();
    }
  }

  /// Clear PIN input
  void _clearPin() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    if (_pinFocusNodes.isNotEmpty) {
      _pinFocusNodes[0].requestFocus();
    }
  }

  /// Show error animation
  void _showError() {
    _shakeController.forward().then((_) => _shakeController.reverse());
  }

  /// Handle PIN input changes
  void _onPinChanged(int index, String value) {
    try {
      if (value.isNotEmpty) {
        if (index < 3) {
          _pinFocusNodes[index + 1].requestFocus();
        } else {
          _pinFocusNodes[index].unfocus();
          if (currentPin.length == 4) {
            _verifyPin();
          }
        }
      } else if (value.isEmpty && index > 0) {
        _pinFocusNodes[index - 1].requestFocus();
      }

      errorMessage.value = '';
    } catch (e) {
      print('❌ Error in PIN change: $e');
    }
  }

  /// Get current PIN
  String get currentPin => _pinControllers.map((c) => c.text).join();

  /// Show password login option for data issues
  void _showPasswordLoginOption() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Get.dialog(
          AlertDialog(
            title: const Text('Data Issue Detected'),
            content: const Text(
              'There seems to be a data consistency issue. '
              'Please use password login to resolve this.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back();
                  _clearPin();
                },
                child: const Text('Try Again'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.offAllNamed('/login');
                },
                child: const Text('Use Password'),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      }
    });
  }

  /// Show sync unavailable option
  void _showSyncUnavailableOption() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Get.dialog(
          AlertDialog(
            title: const Text('Sync Unavailable'),
            content: const Text(
              'You can continue using the app offline, or sign in with your password to enable data sync.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back();
                  AppRoutes.toMain();
                },
                child: const Text('Continue Offline'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.offAllNamed('/login');
                },
                child: const Text('Enable Sync'),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      }
    });
  }

  /// Show initialization error
  void _showInitializationError() {
    if (mounted) {
      Get.dialog(
        AlertDialog(
          title: const Text('Initialization Error'),
          content: const Text(
            'Failed to initialize PIN login. Please restart the app.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                Get.offAllNamed('/login');
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    }
  }

  /// Build PIN input field
  Widget _buildPinInput() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * 10, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) {
              return Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _pinControllers[index].text.isNotEmpty
                        ? Colors.blue
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dot indicator for filled fields
                    if (_pinControllers[index].text.isNotEmpty)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    // Hidden text field
                    TextField(
                      controller: _pinControllers[index],
                      focusNode: _pinFocusNodes[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.transparent,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLength: 1,
                      keyboardType: TextInputType.number,
                      obscureText: false,
                      onChanged: (value) => _onPinChanged(index, value),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      cursorColor: Colors.transparent,
                      showCursor: false,
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Obx(() {
          // Show loading while controllers are initializing
          if (!controllersReady.value) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing...'),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // App Icon/Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 32),

                // Welcome Text
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Enter your 4-digit PIN to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 60),

                // PIN Input
                _buildPinInput(),

                const SizedBox(height: 24),

                // Error Message
                if (errorMessage.value.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage.value,
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Loading indicator
                if (isLoading.value)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Verifying PIN...'),
                    ],
                  ),

                const SizedBox(height: 24),

                // Use Password Button
                TextButton(
                  onPressed:
                      isLoading.value ? null : () => Get.offAllNamed('/login'),
                  child: const Text(
                    'Use Password Instead',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    try {
      _shakeController.dispose();
      for (var controller in _pinControllers) {
        controller.dispose();
      }
      for (var node in _pinFocusNodes) {
        node.dispose();
      }
    } catch (e) {
      print('⚠️ Error during dispose: $e');
    }
    super.dispose();
  }
}
