import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/services/error_handler.dart';
import 'package:driving/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final RxBool showPassword;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    showPassword = false.obs;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuthController());
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient(
              isDark: theme.brightness == Brightness.dark),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  minHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: AppTheme.primary.withOpacity(0.16)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.14),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(cs),
                        const SizedBox(height: 28),
                        _buildWelcomeMessage(cs),
                        const SizedBox(height: 28),
                        _buildEmailField(emailController, cs),
                        const SizedBox(height: 18),
                        Obx(() => _buildPasswordField(
                            passwordController, showPassword, cs)),
                        const SizedBox(height: 10),
                        _buildRememberForgotRow(controller, cs),
                        const SizedBox(height: 24),
                        Obx(() => _buildLoginButton(controller, emailController,
                            passwordController, cs)),
                        const SizedBox(height: 14),
                        Obx(() => _buildErrorMessage(controller, cs)),
                        const SizedBox(height: 28),
                        _buildRegisterLink(cs),
                        const SizedBox(height: 20),
                        _buildOfflineInfo(cs),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Column(
      children: [
        Container(
          width: 94,
          height: 94,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Image.asset('assets/images/logo.png', width: 64, height: 64),
        ),
        const SizedBox(height: 16),
        Text(
          'DriveSync Pro',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Operations control center',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeMessage(ColorScheme cs) {
    return Column(
      children: [
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage students, schedules, billing and reporting from one place',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildEmailField(TextEditingController controller, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: cs.outlineVariant.withOpacity(0.7), width: 1.2),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              prefixIcon:
                  Icon(Icons.email_outlined, color: cs.onSurfaceVariant),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            style: TextStyle(fontSize: 16, color: cs.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
      TextEditingController controller, RxBool showPassword, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: cs.outlineVariant.withOpacity(0.7), width: 1.2),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: !showPassword.value,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              prefixIcon: Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
              suffixIcon: IconButton(
                icon: Icon(
                  showPassword.value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () => showPassword.value = !showPassword.value,
                splashRadius: 20,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            style: TextStyle(fontSize: 16, color: cs.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberForgotRow(AuthController controller, ColorScheme cs) {
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
                  onChanged: (value) =>
                      controller.rememberMe.value = value ?? false,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            Text('Remember me',
                style: TextStyle(fontSize: 14, color: cs.onSurface)),
          ],
        ),
        GestureDetector(
          onTap: () => ErrorHandler.showInfo(
            'Please contact your school administrator for password reset help.',
            title: 'Password help',
          ),
          child: Text(
            'Forgot password?',
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(
    AuthController controller,
    TextEditingController emailController,
    TextEditingController passwordController,
    ColorScheme cs,
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
                  ErrorHandler.showWarning(
                    'Please enter both email and password.',
                    title: 'Missing details',
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
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: controller.isLoading.value
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: cs.onPrimary),
              )
            : const Text('Sign In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildErrorMessage(AuthController controller, ColorScheme cs) {
    if (controller.error.value.isEmpty) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.danger.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.error.value,
                style: TextStyle(color: cs.onSurface, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink(ColorScheme cs) {
    return Center(
      child: RichText(
        text: TextSpan(
          text: "Don't have an account? ",
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          children: [
            WidgetSpan(
              child: GestureDetector(
                onTap: () => Get.toNamed('/school-registration'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    'Register now',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineInfo(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'First login requires internet',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'After setup, use PIN for offline access',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
