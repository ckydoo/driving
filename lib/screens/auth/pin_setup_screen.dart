// lib/screens/auth/pin_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/auth_controller.dart';

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
      bool success;
      if (widget.isInitialSetup) {
        // For initial setup, use AuthController method to associate with current user
        final authController = Get.find<AuthController>();
        success = await authController.setupPinFromSettings(currentPin);
      } else {
        // For settings setup, also use AuthController method
        final authController = Get.find<AuthController>();
        success = await authController.setupPinFromSettings(currentPin);
      }

      if (success) {
        // Mark user as verified for PIN login
        await _pinController.setUserVerified(true);

        if (widget.isInitialSetup) {
          // Navigate to main app
          Get.offAllNamed('/main');
        } else {
          // Just go back
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
                Get.offAllNamed('/main');
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
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
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.isInitialSetup ? 'Setup PIN' : 'Change PIN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
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
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.security,
                      size: 48,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    isConfirmStep.value
                        ? 'Confirm Your PIN'
                        : 'Create Your PIN',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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
                      color: Colors.grey.shade600,
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
                    ),

                  if (isConfirmStep.value)
                    _buildPinInput(
                      controllers: _confirmPinControllers,
                      focusNodes: _confirmPinFocusNodes,
                      label: 'Confirm PIN',
                      isConfirm: true,
                    ),

                  const SizedBox(height: 16),

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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your PIN is stored securely and encrypted on this device only.',
                            style: TextStyle(
                              color: Colors.blue.shade600,
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
