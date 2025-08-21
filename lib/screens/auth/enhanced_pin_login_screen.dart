// lib/screens/auth/enhanced_pin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/pin_controller.dart';
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:driving/services/multi_tenant_firebase_sync_service.dart';

class EnhancedPinLoginScreen extends StatefulWidget {
  const EnhancedPinLoginScreen({Key? key}) : super(key: key);

  @override
  _EnhancedPinLoginScreenState createState() => _EnhancedPinLoginScreenState();
}

class _EnhancedPinLoginScreenState extends State<EnhancedPinLoginScreen>
    with TickerProviderStateMixin {
  final PinController _pinController = Get.find<PinController>();
  final AuthController _authController = Get.find<AuthController>();
  final SchoolConfigService _schoolConfig = Get.find<SchoolConfigService>();

  late List<TextEditingController> _pinControllers;
  late List<FocusNode> _focusNodes;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  final RxString errorMessage = ''.obs;
  final RxBool isLoading = false.obs;
  final RxInt failedAttempts = 0.obs;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
  }

  void _initializeControllers() {
    _pinControllers = List.generate(4, (index) => TextEditingController());
    _focusNodes = List.generate(4, (index) => FocusNode());

    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _setupAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  String get currentPin =>
      _pinControllers.map((controller) => controller.text).join();

  void _onPinChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (currentPin.length == 4) {
          _validatePin();
        }
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    errorMessage.value = '';
  }

  Future<void> _validatePin() async {
    if (currentPin.length != 4) return;

    isLoading.value = true;
    HapticFeedback.lightImpact();

    try {
      // Use the correct method from AuthController for PIN authentication
      final success = await _authController.authenticateWithPin(currentPin);

      if (success) {
        HapticFeedback.heavyImpact();

        // Success feedback
        Get.snackbar(
          'Welcome Back!',
          'Successfully logged in to ${_schoolConfig.schoolName.value}',
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          duration: const Duration(seconds: 2),
        );

        // Initialize Firebase sync if available
        try {
          final syncService = Get.find<MultiTenantFirebaseSyncService>();
          if (syncService.firebaseAvailable.value) {
            await syncService.initializeUserSync();
          }
        } catch (e) {
          print('⚠️ Firebase sync initialization failed: $e');
        }

        // Navigate to main app
        Get.offAllNamed('/main');
      } else {
        _handleFailedAttempt();
      }
    } catch (e) {
      _handleFailedAttempt('Authentication error: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  void _handleFailedAttempt([String? customMessage]) {
    failedAttempts.value++;

    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) => _shakeController.reverse());

    errorMessage.value = customMessage ??
        'Incorrect PIN. ${3 - failedAttempts.value} attempts remaining.';

    // Clear PIN fields
    for (var controller in _pinControllers) {
      controller.clear();
    }

    // Focus first field again
    _focusNodes[0].requestFocus();

    // Block after 3 failed attempts
    if (failedAttempts.value >= 3) {
      _showTooManyAttemptsDialog();
    }
  }

  void _showTooManyAttemptsDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Too Many Failed Attempts'),
        content: const Text(
          'For security reasons, PIN login has been temporarily disabled. '
          'Please use email and password to login.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed('/login');
            },
            child: const Text('Use Email & Password'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _switchToEmailLogin() {
    Get.offAllNamed('/login');
  }

  void _switchSchool() {
    Get.dialog(
      AlertDialog(
        title: const Text('Switch School'),
        content: const Text(
          'Are you sure you want to switch to a different school? '
          'This will log you out and return to school selection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed('/school-selection');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
            child: const Text('Switch School'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade600,
              Colors.blue.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 600 ? 24.0 : 16.0,
                    vertical: 16.0,
                  ),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth > 600
                            ? 400
                            : constraints.maxWidth - 32,
                      ),
                      padding: EdgeInsets.all(
                        constraints.maxWidth > 600 ? 32.0 : 24.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // School info header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.school,
                                      color: Colors.blue.shade600,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Obx(() => Text(
                                                _schoolConfig.schoolName.value,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade800,
                                                ),
                                              )),
                                          Obx(() => Text(
                                                'ID: ${_schoolConfig.schoolId.value}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue.shade600,
                                                ),
                                              )),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _switchSchool,
                                      icon: Icon(
                                        Icons.swap_horiz,
                                        color: Colors.blue.shade600,
                                      ),
                                      tooltip: 'Switch School',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Welcome back text
                          const Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter your 4-digit PIN to continue',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // PIN input fields
                          Obx(() => AnimatedBuilder(
                                animation: _shakeAnimation,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(_shakeAnimation.value, 0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: List.generate(4, (index) {
                                        return SizedBox(
                                          width: 60,
                                          child: TextField(
                                            controller: _pinControllers[index],
                                            focusNode: _focusNodes[index],
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            obscureText: true,
                                            maxLength: 1,
                                            enabled: !isLoading.value &&
                                                failedAttempts.value < 3,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            decoration: InputDecoration(
                                              counterText: '',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: errorMessage.isNotEmpty
                                                      ? Colors.red
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: errorMessage.isNotEmpty
                                                      ? Colors.red
                                                      : Colors.blue,
                                                  width: 2,
                                                ),
                                              ),
                                              filled: true,
                                              fillColor: isLoading.value ||
                                                      failedAttempts.value >= 3
                                                  ? Colors.grey.shade100
                                                  : Colors.grey.shade50,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                            ),
                                            onChanged: (value) =>
                                                _onPinChanged(index, value),
                                          ),
                                        );
                                      }),
                                    ),
                                  );
                                },
                              )),

                          const SizedBox(height: 24),

                          // Error message
                          Obx(() => errorMessage.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error,
                                          color: Colors.red.shade600, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          errorMessage.value,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink()),

                          // Loading indicator
                          Obx(() => isLoading.value
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(),
                                )
                              : const SizedBox.shrink()),

                          const SizedBox(height: 24),

                          // Alternative login option
                          TextButton.icon(
                            onPressed: failedAttempts.value >= 3
                                ? null
                                : _switchToEmailLogin,
                            icon: const Icon(Icons.email),
                            label: const Text('Use Email & Password Instead'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue.shade600,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Biometric option (if available)
                          TextButton.icon(
                            onPressed: () {
                              // TODO: Implement biometric authentication
                              Get.snackbar(
                                'Coming Soon',
                                'Biometric authentication will be available in future updates',
                                backgroundColor: Colors.orange.shade100,
                                colorText: Colors.orange.shade800,
                              );
                            },
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Use Biometric Authentication'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
