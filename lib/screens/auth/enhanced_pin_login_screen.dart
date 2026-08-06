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
      debugPrint('🔐 Initializing EnhancedPinLoginScreen...');

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

      debugPrint('✅ EnhancedPinLoginScreen initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing PIN login screen: $e');
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
        debugPrint('✅ Found existing PinController');

        // Verify controller is actually working
        await _pinController!.getPinInfo();
        debugPrint('✅ PinController verification passed');
      } catch (e) {
        debugPrint('⚠️ PinController not found or invalid, creating...: $e');
        _pinController = Get.put(PinController(), permanent: true);
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('✅ Created new PinController');
      }

      try {
        _authController = Get.find<AuthController>();
        debugPrint('✅ Found existing AuthController');

        // Verify controller is working
        final _ = _authController!.isLoggedIn.value;
        debugPrint('✅ AuthController verification passed');
      } catch (e) {
        debugPrint('⚠️ AuthController not found or invalid, creating...: $e');
        _authController = Get.put(AuthController(), permanent: true);
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('✅ Created new AuthController');
      }

      // Additional safety check
      if (_pinController == null || _authController == null) {
        throw Exception('Failed to initialize required controllers');
      }

      // Mark controllers as ready
      controllersReady.value = true;
      debugPrint('✅ All controllers ready');
    } catch (e) {
      debugPrint('❌ Critical error initializing controllers: $e');
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
      debugPrint('⚠️ Error during dispose: $e');
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
      debugPrint('❌ Error in _onPinChanged: $e');
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
      debugPrint('🔐 Starting PIN verification...');

      // Additional safety check
      if (_authController == null) {
        throw Exception('AuthController is null');
      }

      final success = await _authController!.authenticateWithPin(currentPin);

      if (success) {
        debugPrint('✅ PIN verification successful');
        // PIN verified, navigate to main app
        Get.offAllNamed('/main');
      } else {
        debugPrint('❌ PIN verification failed');
        errorMessage.value = 'Invalid PIN. Please try again.';
        _showError();
        _clearPin();
      }
    } catch (e) {
      debugPrint('❌ PIN verification error: $e');

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
        debugPrint('⚠️ Error showing error animation: $e');
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
      debugPrint('⚠️ Error clearing PIN: $e');
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
                  debugPrint('⚠️ Error resetting PIN: $e');
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

  Widget _buildPinDot(int index, ColorScheme cs) {
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
                    color: hasValue ? cs.primary : Colors.transparent,
                    border: Border.all(
                      color: errorMessage.value.isNotEmpty
                          ? cs.error
                          : hasValue
                              ? cs.primary
                              : cs.outline,
                      width: 2,
                    ),
                  ),
                )),
          );
        },
      );
    } catch (e) {
      debugPrint('❌ Error building PIN dot: $e');
      return const SizedBox();
    }
  }

  Widget _buildPinInput(ColorScheme cs) {
    return Column(
      children: [
        const SizedBox(height: 40),
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
                obscureText: true,
                maxLength: 1,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.error, width: 2),
                  ),
                  filled: true,
                  fillColor: cs.surfaceVariant,
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Obx(() {
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

          try {
            final _ = isLoading.value;
            final __ = errorMessage.value;
          } catch (e) {
            debugPrint('❌ Reactive access error: $e');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: cs.error, size: 48),
                  const SizedBox(height: 16),
                  const Text('Error initializing PIN screen'),
                  const SizedBox(height: 8),
                  const Text('Please restart the app'),
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

                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.lock, color: cs.onPrimary, size: 40),
                ),

                const SizedBox(height: 32),

                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Enter your 4-digit PIN to continue',
                  style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
                ),

                const SizedBox(height: 60),

                _buildPinInput(cs),

                const SizedBox(height: 24),

                Builder(
                  builder: (context) {
                    try {
                      return Obx(() {
                        if (errorMessage.value.isNotEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: cs.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage.value,
                                    style: TextStyle(color: cs.onErrorContainer),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      });
                    } catch (e) {
                      debugPrint('❌ Error in error message widget: $e');
                      return const SizedBox.shrink();
                    }
                  },
                ),

                const Spacer(),

                Builder(
                  builder: (context) {
                    try {
                      return Obx(() => isLoading.value
                          ? const CircularProgressIndicator()
                          : const SizedBox.shrink());
                    } catch (e) {
                      debugPrint('❌ Error in loading widget: $e');
                      return const SizedBox.shrink();
                    }
                  },
                ),

                const SizedBox(height: 24),

                Column(
                  children: [
                    TextButton(
                      onPressed: _usePasswordLogin,
                      child: const Text('Use Password Instead'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _forgotPin,
                      child: const Text('Forgot PIN?'),
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
