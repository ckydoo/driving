// lib/screens/auth/pin_login_screen.dart - ULTRA SAFE VERSION
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

      // Initialize animation controller
      _shakeController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      _shakeAnimation = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
      );

      // SAFE CONTROLLER ACCESS
      await _initializeControllers();

      // Auto focus first PIN field after controllers are ready
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pinFocusNodes[0].canRequestFocus) {
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
      // Try to get existing controllers, create if not found
      try {
        _pinController = Get.find<PinController>();
        print('✅ Found existing PinController');
      } catch (e) {
        print('⚠️ PinController not found, creating...');
        _pinController = Get.put(PinController(), permanent: true);
        await Future.delayed(const Duration(milliseconds: 200));
        print('✅ Created PinController');
      }

      try {
        _authController = Get.find<AuthController>();
        print('✅ Found existing AuthController');
      } catch (e) {
        print('⚠️ AuthController not found, creating...');
        _authController = Get.put(AuthController(), permanent: true);
        await Future.delayed(const Duration(milliseconds: 200));
        print('✅ Created AuthController');
      }

      // Mark controllers as ready
      controllersReady.value = true;
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
    _shakeController.dispose();
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get currentPin => _pinControllers.map((c) => c.text).join();

  void _onPinChanged(int index, String value) {
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
      errorMessage.value = 'Verification failed. Please try again.';
      _showError();
      _clearPin();
    } finally {
      isLoading.value = false;
    }
  }

  void _showError() {
    if (mounted) {
      _shakeController.forward().then((_) {
        if (mounted) {
          _shakeController.reset();
        }
      });

      // Haptic feedback
      HapticFeedback.vibrate();
    }
  }

  void _clearPin() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pinFocusNodes[0].canRequestFocus) {
          _pinFocusNodes[0].requestFocus();
        }
      });
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
  }

  Widget _buildPinInput() {
    return Column(
      children: [
        // PIN Dots Display
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) => _buildPinDot(index)),
        ),
        const SizedBox(height: 40),

        // Hidden PIN Input Fields
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 50,
              child: TextField(
                controller: _pinControllers[index],
                focusNode: _pinFocusNodes[index],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 0), // Hide text
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '', // Hide counter
                ),
                maxLength: 1,
                keyboardType: TextInputType.number,
                obscureText: true,
                onChanged: (value) => _onPinChanged(index, value),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
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
          // Show loading screen while controllers are initializing
          if (!controllersReady.value) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing PIN login...'),
                ],
              ),
            );
          }

          // Show main PIN login interface
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Enter Your PIN',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Use your 4-digit PIN to access your account',
                  textAlign: TextAlign.center,
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
                Obx(() {
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
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                const Spacer(),

                // Loading indicator
                Obx(() => isLoading.value
                    ? const CircularProgressIndicator()
                    : const SizedBox.shrink()),

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
