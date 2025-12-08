import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/auth_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuthController());
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final showPassword = false.obs;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 400,
                minHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Header
                  _buildHeader(),
                  const SizedBox(height: 32),

                  // Welcome Message
                  _buildWelcomeMessage(),
                  const SizedBox(height: 32),

                  // Email Field
                  _buildEmailField(emailController),
                  const SizedBox(height: 20),

                  // Password Field
                  Obx(() => _buildPasswordField(
                        passwordController,
                        showPassword,
                      )),
                  const SizedBox(height: 12),

                  // Remember Me / Forgot Password
                  _buildRememberForgotRow(controller),
                  const SizedBox(height: 28),

                  // Login Button
                  Obx(() => _buildLoginButton(
                        controller,
                        emailController,
                        passwordController,
                      )),
                  const SizedBox(height: 16),

                  // Error Message
                  Obx(() => _buildErrorMessage(controller)),

                  const SizedBox(height: 32),

                  // Register Link
                  _buildRegisterLink(),

                  const SizedBox(height: 24),

                  // Offline Mode Info
                  _buildOfflineInfo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade700,
                Colors.purple.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.school,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'DriveSync Pro',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeMessage() {
    return Column(
      children: [
        Text(
          'Welcome!',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to your account to continue',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: Colors.grey.shade600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[900],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    RxBool showPassword,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: !showPassword.value,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
              ),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: Colors.grey.shade600,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  showPassword.value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade600,
                ),
                onPressed: () => showPassword.value = !showPassword.value,
                splashRadius: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[900],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberForgotRow(AuthController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Obx(
              () => Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: controller.rememberMe.value,
                  onChanged: (value) {
                    controller.rememberMe.value = value ?? false;
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  activeColor: Colors.blue.shade700,
                ),
              ),
            ),
            Text(
              'Remember me',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Get.snackbar(
              'Forgot Password',
              'Please contact your school administrator',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.blue.shade50,
              colorText: Colors.blue.shade900,
              icon: Icon(Icons.help_outline, color: Colors.blue.shade700),
            );
          },
          child: Text(
            'Forgot password?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(
    AuthController controller,
    TextEditingController emailController,
    TextEditingController passwordController,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: controller.isLoading.value
            ? null
            : () async {
                final email = emailController.text.trim();
                final password = passwordController.text;

                if (email.isEmpty || password.isEmpty) {
                  Get.snackbar(
                    'Missing Information',
                    'Please enter both email and password',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.orange.shade50,
                    colorText: Colors.orange.shade900,
                    icon: Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700),
                  );
                  return;
                }

                final success =
                    await controller.loginWithEmail(email, password);

                if (success) {
                  if (!controller.hasPinSetup) {
                    Get.offAllNamed('/pin-setup');
                  } else {
                    Get.offAllNamed('/main');
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: Colors.blue.shade200,
          disabledBackgroundColor: Colors.blue.shade400,
        ),
        child: controller.isLoading.value
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorMessage(AuthController controller) {
    if (controller.error.value.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade700,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.error.value,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          text: "Don't have an account? ",
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          children: [
            WidgetSpan(
              child: GestureDetector(
                onTap: () => Get.toNamed('/school-registration'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    'Register now',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'First login requires internet',
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'After setup, use PIN for offline access',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
