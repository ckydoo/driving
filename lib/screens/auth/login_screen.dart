// lib/screens/auth/login_screen.dart - Updated for Firebase-First with backward compatibility
import 'package:driving/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 600;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWideScreen ? 80 : 24,
                  vertical: 24,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Logo/Header
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: isWideScreen ? 120 : 100,
                                height: isWideScreen ? 120 : 100,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.school,
                                  color: Colors.white,
                                  size: isWideScreen ? 60 : 50,
                                ),
                              ),
                              SizedBox(height: isWideScreen ? 32 : 24),
                              Text(
                                'Welcome Back',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isWideScreen ? 32 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: isWideScreen ? 12 : 8),
                              Text(
                                'Sign in to access your school management system',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isWideScreen ? 16 : 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isWideScreen ? 48 : 32),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'Enter your email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.blue.shade600),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isWideScreen ? 16 : 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!GetUtils.isEmail(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: isWideScreen ? 20 : 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.blue.shade600),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isWideScreen ? 16 : 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: isWideScreen ? 32 : 24),

                        // Error Message
                        Obx(() {
                          if (_authController.error.value.isNotEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                border: Border.all(color: Colors.red[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _authController.error.value,
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),

                        // Firebase Connection Status
                        Obx(() {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              border: Border.all(color: Colors.orange[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cloud_off,
                                    color: Colors.orange[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Limited connectivity',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'You can still sign in with existing accounts',
                                        style: TextStyle(
                                          color: Colors.orange[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Login Button
                        Obx(() => ElevatedButton(
                              onPressed: _authController.isLoading.value
                                  ? null
                                  : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isWideScreen ? 18 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                              ),
                              child: _authController.isLoading.value
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: isWideScreen ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            )),

                        SizedBox(height: isWideScreen ? 32 : 24),

                        // Register Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isWideScreen ? 16 : 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Get.toNamed('/school-selection'),
                              child: Text(
                                'Create Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isWideScreen ? 16 : 14,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _authController.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success) {
      print('✅ Login successful, navigating to main app');
      print('🔍 Auth Status:');
      print('   Local: ${_authController.isLoggedIn.value}');

      // Force a small delay to ensure auth state is fully updated
      await Future.delayed(const Duration(milliseconds: 100));

      // Check if user has PIN setup for future convenience
      if (_authController.hasPinSetup) {
        // Go to main app
        Get.offAllNamed('/main');
      } else {
        // Offer to setup PIN for future logins
        _showPinSetupDialog();
      }
    } else {
      print('❌ Login failed');
    }
  }

  void _showPinSetupDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Setup PIN'),
        content: const Text(
          'Would you like to set up a PIN for faster login next time?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              print('📱 Navigating to main app (PIN setup skipped)');
              Get.offAllNamed('/main');
            },
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              print('📱 Navigating to PIN setup');
              Get.offAllNamed('/pin-setup');
            },
            child: const Text('Setup PIN'),
          ),
        ],
      ),
    );
  }
}
