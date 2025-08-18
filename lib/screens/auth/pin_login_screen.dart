// lib/screens/auth/pin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/auth_controller.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({Key? key}) : super(key: key);

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen>
    with TickerProviderStateMixin {
  final PinController _pinController = Get.find<PinController>();
  final AuthController _authController = Get.find<AuthController>();

  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Auto focus first PIN field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNodes[0].requestFocus();
    });
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

  Future<void> _verifyPin() async {
    if (currentPin.length != 4) return;

    isLoading.value = true;

    try {
      final authController = Get.find<AuthController>();
      final success = await authController.authenticateWithPin(currentPin);

      if (success) {
        // PIN verified, navigate to main app
        Get.offAllNamed('/main');
      } else {
        _showError();
        _clearPin();
      }
    } catch (e) {
      errorMessage.value = 'Verification failed. Please try again.';
      _showError();
      _clearPin();
      debugPrint('PIN verification error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _showError() {
    _shakeController.forward().then((_) {
      _shakeController.reset();
    });

    // Haptic feedback
    HapticFeedback.vibrate();
  }

  void _clearPin() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNodes[0].requestFocus();
    });
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
              // Reset PIN and clear verification
              await _pinController.resetPin();
              await _pinController.setUserVerified(false);
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

    return Obx(() => AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final shake = _shakeAnimation.value;
            return Transform.translate(
              offset: Offset(shake * 10 * (index % 2 == 0 ? 1 : -1), 0),
              child: Container(
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
              ),
            );
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Obx(() => Padding(
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

                  // PIN Dots Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildPinDot(index),
                      );
                    }),
                  ),
                  const SizedBox(height: 40),

                  // Hidden PIN Input Fields
                  Opacity(
                    opacity: 0.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (index) {
                        return SizedBox(
                          width: 1,
                          child: TextField(
                            controller: _pinControllers[index],
                            focusNode: _pinFocusNodes[index],
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            onChanged: (value) => _onPinChanged(index, value),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Error Message
                  if (errorMessage.value.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
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

                  // Lockout Warning
                  if (_pinController.isLocked.value)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_outlined,
                              color: Colors.orange.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Account temporarily locked due to too many failed attempts.',
                              style: TextStyle(color: Colors.orange.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // Loading Indicator
                  if (isLoading.value) const CircularProgressIndicator(),

                  const SizedBox(height: 40),

                  // Action Buttons
                  if (!_pinController.isLocked.value) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _forgotPin,
                        icon: const Icon(Icons.help_outline),
                        label: const Text('Forgot PIN?'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _usePasswordLogin,
                        icon: const Icon(Icons.login),
                        label: const Text('Use Email & Password'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _usePasswordLogin,
                        icon: const Icon(Icons.login),
                        label: const Text('Use Email & Password'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Security Note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security,
                            color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your PIN is stored securely on this device only.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ),
    );
  }
}
