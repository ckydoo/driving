// lib/screens/auth/enhanced_pin_login_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/auth_controller.dart';

class EnhancedPinLoginScreen extends StatefulWidget {
  const EnhancedPinLoginScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedPinLoginScreen> createState() => _EnhancedPinLoginScreenState();
}

class _EnhancedPinLoginScreenState extends State<EnhancedPinLoginScreen>
    with TickerProviderStateMixin {
  // SAFE CONTROLLER ACCESS - No more "Bad state: No element"
  PinController? _pinController;
  AuthController? _authController;

  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool controllersReady = false.obs;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  /// SAFE INITIALIZATION - No more crashes
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

      // SAFE CONTROLLER ACCESS - with additional delays
      await _initializeControllers();

      // Auto focus first PIN field after controllers are ready
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _pinFocusNodes.isNotEmpty &&
              _pinFocusNodes[0].canRequestFocus) {
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

  /// SAFE CONTROLLER INITIALIZATION - ENHANCED
  Future<void> _initializeControllers() async {
    try {
      // Wait a bit for any pending operations
      await Future.delayed(const Duration(milliseconds: 100));

      // Try to get existing controllers, create if not found
      try {
        _pinController = Get.find<PinController>();
        print('✅ Found existing PinController');

        // Verify controller is actually working
        await _pinController!.getPinInfo();
        print('✅ PinController verification passed');
      } catch (e) {
        print('⚠️ PinController not found or invalid, creating...: $e');
        _pinController = Get.put(PinController(), permanent: true);
        await Future.delayed(const Duration(milliseconds: 300));
        print('✅ Created new PinController');
      }

      try {
        _authController = Get.find<AuthController>();
        print('✅ Found existing AuthController');

        // Verify controller is working
        final _ = _authController!.isLoggedIn.value;
        print('✅ AuthController verification passed');
      } catch (e) {
        print('⚠️ AuthController not found or invalid, creating...: $e');
        _authController = Get.put(AuthController(), permanent: true);
        await Future.delayed(const Duration(milliseconds: 300));
        print('✅ Created new AuthController');
      }

      // Additional safety check
      if (_pinController == null || _authController == null) {
        throw Exception('Failed to initialize required controllers');
      }

      // Mark controllers as ready
      controllersReady.value = true;
      print('✅ All controllers ready');
    } catch (e) {
      print('❌ Critical error initializing controllers: $e');
      _showInitializationError();
    }
  }

  /// Show error if initialization fails
  void _showInitializationError() {
    if (mounted) {
      Get.dialog(
        AlertDialog(
          title: const Text('Initialization Error'),
          content: const Text(
              'Failed to initialize PIN login. Please restart the app.'),
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
      );
    }
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

  String get currentPin => _pinControllers.map((c) => c.text).join();

  void _onPinChanged(int index, String value) {
    try {
      if (value.isNotEmpty) {
        if (index < 3 && index < _pinFocusNodes.length - 1) {
          _pinFocusNodes[index + 1].requestFocus();
        } else {
          if (index < _pinFocusNodes.length) {
            _pinFocusNodes[index].unfocus();
          }
          if (currentPin.length == 4) {
            _verifyPin();
          }
        }
      } else if (value.isEmpty && index > 0) {
        _pinFocusNodes[index - 1].requestFocus();
      }

      errorMessage.value = '';
    } catch (e) {
      print('❌ Error in _onPinChanged: $e');
    }
  }

  /// ULTRA SAFE PIN VERIFICATION
  Future<void> _verifyPin() async {
    if (currentPin.length != 4) return;

    // Check if controllers are ready
    if (!controllersReady.value || _authController == null) {
      errorMessage.value = 'System not ready. Please wait...';
      return;
    }

    isLoading.value = true;

    try {
      print('🔐 Starting PIN verification...');

      // Additional safety check
      if (_authController == null) {
        throw Exception('AuthController is null');
      }

      final success = await _authController!.authenticateWithPin(currentPin);

      if (success) {
        print('✅ PIN verification successful');
        // PIN verified, navigate to main app
        Get.offAllNamed('/main');
      } else {
        print('❌ PIN verification failed');
        errorMessage.value = 'Invalid PIN. Please try again.';
        _showError();
        _clearPin();
      }
    } catch (e) {
      print('❌ PIN verification error: $e');

      // Handle specific "Bad state: No element" error
      if (e.toString().contains('Bad state: No element')) {
        errorMessage.value =
            'Data inconsistency detected. Please use password login.';

        // Show option to use password login
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _usePasswordLogin();
          }
        });
      } else {
        errorMessage.value = 'Verification failed. Please try again.';
      }

      _showError();
      _clearPin();
    } finally {
      isLoading.value = false;
    }
  }

  void _showError() {
    if (mounted) {
      try {
        _shakeController.forward().then((_) {
          if (mounted) {
            _shakeController.reset();
          }
        });

        // Haptic feedback
        HapticFeedback.vibrate();
      } catch (e) {
        print('⚠️ Error showing error animation: $e');
      }
    }
  }

  void _clearPin() {
    try {
      for (var controller in _pinControllers) {
        controller.clear();
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _pinFocusNodes.isNotEmpty &&
              _pinFocusNodes[0].canRequestFocus) {
            _pinFocusNodes[0].requestFocus();
          }
        });
      }
    } catch (e) {
      print('⚠️ Error clearing PIN: $e');
    }
  }

  void _usePasswordLogin() {
    Get.dialog(
      AlertDialog(
        title: const Text('Use Password Login'),
        content:
            const Text('This will take you back to email and password login. '
                'Your PIN will remain active for future logins.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed('/login');
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _forgotPin() {
    Get.dialog(
      AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text(
            'To reset your PIN, you\'ll need to log in with your email and password. '
            'You can then set up a new PIN in the settings.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();

              // Safe PIN reset
              if (_pinController != null) {
                try {
                  await _pinController!.resetPin();
                  await _pinController!.setUserVerified(false);
                } catch (e) {
                  print('⚠️ Error resetting PIN: $e');
                }
              }

              Get.offAllNamed('/login');
            },
            child: const Text('Reset PIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildPinDot(int index) {
    try {
      if (index >= _pinControllers.length) return const SizedBox();

      final controller = _pinControllers[index];
      final hasValue = controller.text.isNotEmpty;

      return AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final shake = _shakeAnimation.value;
          return Transform.translate(
            offset: Offset(shake * 10 * (index % 2 == 0 ? 1 : -1), 0),
            child: Obx(() => Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasValue ? Colors.blue.shade600 : Colors.transparent,
                    border: Border.all(
                      color: errorMessage.value.isNotEmpty
                          ? Colors.red
                          : hasValue
                              ? Colors.blue.shade600
                              : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                )),
          );
        },
      );
    } catch (e) {
      print('❌ Error building PIN dot: $e');
      return const SizedBox();
    }
  }

  Widget _buildPinInput() {
    return Column(
      children: [
        const SizedBox(height: 40),

        // PIN Input Fields (showing obscured numbers like PIN setup)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 60,
              child: TextField(
                controller: index < _pinControllers.length
                    ? _pinControllers[index]
                    : TextEditingController(),
                focusNode: index < _pinFocusNodes.length
                    ? _pinFocusNodes[index]
                    : FocusNode(),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                obscureText: true, // Shows bullets/dots instead of numbers
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (value) => _onPinChanged(index, value),
              ),
            );
          }),
        ),
      ],
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

          // Additional safety check for reactive access
          try {
            // Test reactive access to make sure all observables are accessible
            final _ = isLoading.value;
            final __ = errorMessage.value;
          } catch (e) {
            print('❌ Reactive access error: $e');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text('Error initializing PIN screen'),
                  SizedBox(height: 8),
                  Text('Please restart the app'),
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
                Builder(
                  builder: (context) {
                    try {
                      return Obx(() {
                        if (errorMessage.value.isNotEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
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
                                    style:
                                        TextStyle(color: Colors.red.shade600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      });
                    } catch (e) {
                      print('❌ Error in error message widget: $e');
                      return const SizedBox.shrink();
                    }
                  },
                ),

                const Spacer(),

                // Loading indicator
                Builder(
                  builder: (context) {
                    try {
                      return Obx(() => isLoading.value
                          ? const CircularProgressIndicator()
                          : const SizedBox.shrink());
                    } catch (e) {
                      print('❌ Error in loading widget: $e');
                      return const SizedBox.shrink();
                    }
                  },
                ),

                const SizedBox(height: 24),

                // Alternative login options
                Column(
                  children: [
                    TextButton(
                      onPressed: _usePasswordLogin,
                      child: const Text('Use Password Instead'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _forgotPin,
                      child: Text(
                        'Forgot PIN?',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        }),
      ),
    );
  }
}
