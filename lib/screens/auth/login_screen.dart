// lib/screens/auth/login_screen.dart - Fixed with Force Reset
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

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        // Navigate to main layout instead of specific dashboard
        Get.offAllNamed('/main');
      }
    }
  }

  // Debug function to check database
  Future<void> _debugDatabase() async {
    await _authController.debugDatabase();

    Get.dialog(
      AlertDialog(
        title: const Text('Debug Info'),
        content: const Text('Database debug info printed to console.\n\n'
            'Default credentials:\n'
            'Email: admin@drivingschool.com\n'
            'Password: admin123\n\n'
            'Check the console for detailed information.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Force reset users with correct password hash
  Future<void> _forceResetUsers() async {
    await _authController.forceCreateTestUsers();

    Get.dialog(
      AlertDialog(
        title: const Text('Users Reset'),
        content: const Text(
            'All users have been recreated with correct password hashing.\n\n'
            'You can now login with:\n'
            'Email: admin@drivingschool.com\n'
            'Password: admin123'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
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
                        minHeight: constraints.maxHeight < 600
                            ? constraints.maxHeight - 100
                            : 0,
                      ),
                      padding: EdgeInsets.all(
                        constraints.maxWidth > 600 ? 32.0 : 20.0,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo/Header - Responsive sizing
                            Container(
                              padding: EdgeInsets.all(
                                constraints.maxWidth > 600 ? 16 : 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.school,
                                size: constraints.maxWidth > 600 ? 48 : 36,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            SizedBox(
                                height: constraints.maxWidth > 600 ? 24 : 16),

                            // Title - Responsive typography
                            Text(
                              'DRIVING SCHOOL',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: constraints.maxWidth > 600 ? 24 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            SizedBox(
                                height: constraints.maxWidth > 600 ? 8 : 4),
                            Text(
                              'Management System',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: constraints.maxWidth > 600 ? 16 : 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(
                                height: constraints.maxWidth > 600 ? 32 : 20),

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
                                  vertical:
                                      constraints.maxWidth > 600 ? 16 : 12,
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
                            SizedBox(
                                height: constraints.maxWidth > 600 ? 16 : 12),

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
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
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
                                  vertical:
                                      constraints.maxWidth > 600 ? 16 : 12,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _handleLogin(),
                            ),
                            SizedBox(
                                height: constraints.maxWidth > 600 ? 16 : 12),

                            // Remember Me Checkbox - Responsive
                            Obx(() => CheckboxListTile(
                                  title: Text(
                                    'Remember me',
                                    style: TextStyle(
                                      fontSize:
                                          constraints.maxWidth > 600 ? 16 : 14,
                                    ),
                                  ),
                                  value: _authController.rememberMe.value,
                                  onChanged: (value) {
                                    _authController.rememberMe.value =
                                        value ?? false;
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  dense: constraints.maxWidth <= 600,
                                )),
                            SizedBox(
                                height: constraints.maxWidth > 600 ? 24 : 16),

                            // Error Message
                            Obx(() {
                              if (_authController.error.isNotEmpty) {
                                return Container(
                                  padding: EdgeInsets.all(
                                    constraints.maxWidth > 600 ? 12 : 10,
                                  ),
                                  margin: EdgeInsets.only(
                                    bottom:
                                        constraints.maxWidth > 600 ? 16 : 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.red.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _authController.error.value,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: constraints.maxWidth > 600
                                                ? 14
                                                : 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }),

                            // Login Button
                            Obx(() => SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _authController.isLoading.value
                                        ? null
                                        : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade800,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        vertical: constraints.maxWidth > 600
                                            ? 16
                                            : 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _authController.isLoading.value
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Text(
                                            'LOGIN',
                                            style: TextStyle(
                                              fontSize:
                                                  constraints.maxWidth > 600
                                                      ? 16
                                                      : 14,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                  ),
                                )),
                            SizedBox(
                                height: constraints.maxWidth > 600 ? 16 : 12),

                            // Debug Buttons Row - Responsive layout
                            constraints.maxWidth > 600
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: _debugDatabase,
                                          icon: const Icon(Icons.bug_report),
                                          label: const Text('Debug'),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _forceResetUsers,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Fix Users'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.orange.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextButton.icon(
                                          onPressed: _debugDatabase,
                                          icon: const Icon(Icons.bug_report),
                                          label: const Text('Debug Database'),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _forceResetUsers,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Fix Users'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.orange.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            SizedBox(
                                height: constraints.maxWidth > 600 ? 16 : 12),

                            // Demo Credentials - Responsive
                            Container(
                              padding: EdgeInsets.all(
                                constraints.maxWidth > 600 ? 16 : 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: constraints.maxWidth > 600
                                              ? 16
                                              : 14,
                                          color: Colors.blue.shade600),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Demo Credentials (Tap to fill)',
                                          style: TextStyle(
                                            fontSize: constraints.maxWidth > 600
                                                ? 14
                                                : 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                      height:
                                          constraints.maxWidth > 600 ? 8 : 6),
                                  _buildDemoCredential(
                                      'Admin',
                                      'admin@drivingschool.com',
                                      'admin123',
                                      constraints),
                                  _buildDemoCredential(
                                      'Instructor',
                                      'instructor@drivingschool.com',
                                      'admin123',
                                      constraints),
                                  _buildDemoCredential(
                                      'Student',
                                      'student@drivingschool.com',
                                      'admin123',
                                      constraints),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildDemoCredential(
      String role, String email, String password, BoxConstraints constraints) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: constraints.maxWidth > 600 ? 2 : 1,
      ),
      child: InkWell(
        onTap: () {
          _emailController.text = email;
          _passwordController.text = password;
          setState(() {}); // Refresh UI
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(constraints.maxWidth > 600 ? 8 : 6),
          child: Row(
            children: [
              Icon(Icons.person_outline,
                  size: constraints.maxWidth > 600 ? 16 : 14,
                  color: Colors.grey.shade600),
              SizedBox(width: constraints.maxWidth > 600 ? 8 : 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: constraints.maxWidth > 600 ? 12 : 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: constraints.maxWidth > 600 ? 11 : 9,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth > 600 ? 6 : 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'TAP',
                  style: TextStyle(
                    fontSize: constraints.maxWidth > 600 ? 10 : 8,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
