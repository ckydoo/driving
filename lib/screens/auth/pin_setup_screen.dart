import 'package:driving/routes/app_routes.dart';
import 'package:driving/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinSetupScreen extends StatefulWidget {
  final bool isInitialSetup;

  const PinSetupScreen({
    Key? key,
    this.isInitialSetup = true,
  }) : super(key: key);

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final PinController _pinController = Get.find<PinController>();
  final AuthController _authController = Get.find<AuthController>();

  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  final List<TextEditingController> _confirmPinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _confirmPinFocusNodes =
      List.generate(4, (_) => FocusNode());

  final RxBool isConfirmStep = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void initState() {
    super.initState();
    // Auto focus first PIN field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var controller in _confirmPinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    for (var node in _confirmPinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get currentPin => _pinControllers.map((c) => c.text).join();
  String get confirmPin => _confirmPinControllers.map((c) => c.text).join();

  void _onPinChanged(int index, String value, {bool isConfirm = false}) {
    final controllers = isConfirm ? _confirmPinControllers : _pinControllers;
    final focusNodes = isConfirm ? _confirmPinFocusNodes : _pinFocusNodes;

    if (value.isNotEmpty) {
      if (index < 3) {
        focusNodes[index + 1].requestFocus();
      } else {
        focusNodes[index].unfocus();
        if (!isConfirm && currentPin.length == 4) {
          _proceedToConfirmation();
        } else if (isConfirm && confirmPin.length == 4) {
          _validateAndSetupPin();
        }
      }
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    errorMessage.value = '';
  }

  void _proceedToConfirmation() {
    if (currentPin.length == 4) {
      isConfirmStep.value = true;
      // Clear confirm PIN fields
      for (var controller in _confirmPinControllers) {
        controller.clear();
      }
      // Focus first confirm field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confirmPinFocusNodes[0].requestFocus();
      });
    }
  }

  Future<void> _validateAndSetupPin() async {
    if (currentPin != confirmPin) {
      errorMessage.value = 'PINs do not match. Please try again.';
      _resetToFirstStep();
      return;
    }

    isLoading.value = true;

    try {
      // Setup the PIN
      bool success;
      if (widget.isInitialSetup) {
        final authController = Get.find<AuthController>();
        success = await authController.setupPinFromSettings(currentPin);
      } else {
        final authController = Get.find<AuthController>();
        success = await authController.setupPinFromSettings(currentPin);
      }

      if (success) {
        // Mark user as verified for PIN login
        await _pinController.setUserVerified(true);

        // CRITICAL FIX: Ensure API token is set before navigating
        if (widget.isInitialSetup) {
          debugPrint('🔑 Ensuring API token is set before navigation...');

          final authController = Get.find<AuthController>();
          final user = authController.currentUser.value;

          if (user != null && user.email != null) {
            // Get the stored token
            final prefs = await SharedPreferences.getInstance();
            final tokenKey = 'api_token_${user.email}';
            final storedToken = prefs.getString(tokenKey);

            if (storedToken != null && storedToken.isNotEmpty) {
              debugPrint('✅ Token found: ${storedToken.substring(0, 10)}...');

              // Set it in ApiService BEFORE navigating
              ApiService.setToken(storedToken);
              debugPrint('✅ Token set in ApiService');

              // Verify it was set
              if (ApiService.hasToken && ApiService.currentToken != null) {
                debugPrint('✅ Token verified in ApiService');
                debugPrint('   hasToken: true');
                debugPrint(
                    '   token: ${ApiService.currentToken!.substring(0, 10)}...');
              } else {
                debugPrint('⚠️ Token not properly set in ApiService');
              }
            } else {
              debugPrint('⚠️ No stored token found for ${user.email}');
              debugPrint('💡 User can still proceed - will work offline');
            }
          }

          // Small delay to ensure token is fully set
          await Future.delayed(Duration(milliseconds: 100));

          // NOW navigate to main app
          debugPrint('🏠 Navigating to main app...');
          AppRoutes.toMain();
        } else {
          // Just go back for settings setup
          Get.back();
        }
      }
    } catch (e) {
      errorMessage.value = 'Failed to setup PIN. Please try again.';
      debugPrint('PIN setup error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _resetToFirstStep() {
    isConfirmStep.value = false;
    for (var controller in _pinControllers) {
      controller.clear();
    }
    for (var controller in _confirmPinControllers) {
      controller.clear();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNodes[0].requestFocus();
    });
  }

  void _skipPinSetup() {
    if (widget.isInitialSetup) {
      Get.dialog(
        AlertDialog(
          title: const Text('Skip PIN Setup?'),
          content: const Text(
              'You can setup a PIN later in settings for faster login. '
              'You\'ll continue using email and password for now.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                // ✅ FIXED: Check if user is logged in before navigating
                final authController = Get.find<AuthController>();
                if (authController.isLoggedIn.value && authController.currentUser.value != null) {
                  AppRoutes.toMain(); // Use proper navigation method
                } else {
                  // User not logged in - show error
                  Get.snackbar(
                    'Error',
                    'User not logged in. Please login first.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.shade100,
                  );
                  // Navigate to login instead
                  Get.offAllNamed('/login');
                }
              },
              child: const Text('Skip'),
            ),
          ],
        ),
      );
    } else {
      Get.back();
    }
  }

  Widget _buildPinInput({
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required String label,
    required bool isConfirm,
    required ColorScheme cs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 60,
              child: TextField(
                controller: controllers[index],
                focusNode: focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 1,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
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
                  filled: true,
                  fillColor: cs.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (value) =>
                    _onPinChanged(index, value, isConfirm: isConfirm),
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
      appBar: AppBar(
        title: Text(widget.isInitialSetup ? 'Setup PIN' : 'Change PIN'),
        leading: widget.isInitialSetup ? null : const BackButton(),
      ),
      body: SafeArea(
        child: Obx(() => Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.security,
                      size: 48,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    isConfirmStep.value
                        ? 'Confirm Your PIN'
                        : 'Create Your PIN',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    isConfirmStep.value
                        ? 'Re-enter your PIN to confirm'
                        : 'Create a 4-digit PIN for quick and secure access',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // PIN Input
                  if (!isConfirmStep.value)
                    _buildPinInput(
                      controllers: _pinControllers,
                      focusNodes: _pinFocusNodes,
                      label: 'Enter PIN',
                      isConfirm: false,
                      cs: cs,
                    ),

                  if (isConfirmStep.value)
                    _buildPinInput(
                      controllers: _confirmPinControllers,
                      focusNodes: _confirmPinFocusNodes,
                      label: 'Confirm PIN',
                      isConfirm: true,
                      cs: cs,
                    ),

                  const SizedBox(height: 16),

                  // Error Message
                  if (errorMessage.value.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
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
                    ),

                  const Spacer(),

                  // Action Buttons
                  if (isConfirmStep.value)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isLoading.value ? null : _resetToFirstStep,
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading.value || confirmPin.length != 4
                                ? null
                                : _validateAndSetupPin,
                            child: isLoading.value
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Confirm'),
                          ),
                        ),
                      ],
                    )
                  else if (widget.isInitialSetup)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isLoading.value ? null : _skipPinSetup,
                            child: const Text('Skip for now'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: currentPin.length != 4
                                ? null
                                : _proceedToConfirmation,
                            child: const Text('Next'),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Security Note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: cs.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: cs.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your PIN is stored securely and encrypted on this device only.',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
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
