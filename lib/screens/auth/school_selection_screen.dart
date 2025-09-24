// lib/screens/school_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/school_selection_controller.dart';
import '../../controllers/auth_controller.dart';

class SchoolSelectionScreen extends StatelessWidget {
  const SchoolSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SchoolSelectionController());
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // App Logo/Header
                _buildHeader(),

                const SizedBox(height: 10),

                // Welcome Text
                Text(
                  'DriveSync Pro',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'How do you want to get started?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // School Selection Options
                _buildSelectionOptions(controller, authController),

                const SizedBox(height: 32),

                // Or divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 32),

                // Register New School Button
                _buildRegisterNewSchoolButton(controller),

                const SizedBox(height: 24),

                // Footer info
                _buildFooterInfo(),
              ],
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
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(
            Icons.school,
            size: 50,
            color: Colors.blue.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionOptions(
      SchoolSelectionController controller, AuthController authController) {
    return Column(
      children: [
        // Join Existing School Card
        _buildOptionCard(
          title: 'Sign In',
          subtitle: 'Enter driving school credentials',
          icon: Icons.login,
          color: Colors.green,
          onTap: () => _showJoinSchoolDialog(controller),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildRegisterNewSchoolButton(SchoolSelectionController controller) {
  return ElevatedButton.icon(
    onPressed: () => controller.navigateToSchoolRegistration(),
    label: const Text('Registration'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue.shade600,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

Widget _buildFooterInfo() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Icon(
          Icons.info_outline,
          color: Colors.blue[600],
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          'DriveSync Pro allows you to manage multiple driving schools from one app.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

void _showJoinSchoolDialog(SchoolSelectionController controller) {
  Get.dialog(
    AlertDialog(
      title: Row(
        children: [
          Icon(Icons.school, color: Colors.blue.shade600),
          SizedBox(width: 8),
          Text('Sign In'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // School name field
            TextField(
              controller: controller.schoolNameController,
              decoration: InputDecoration(
                labelText: 'School Name or Code',
                hintText: 'Enter driving school name or invitation code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.school),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            SizedBox(height: 16),

            // Email field
            TextField(
              controller: controller.emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.email),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            SizedBox(height: 16),

            // Password field with visibility toggle
            Obx(() => TextField(
                  controller: controller.passwordController,
                  obscureText: controller.obscurePassword.value,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.lock),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.obscurePassword.value
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: controller.togglePasswordVisibility,
                    ),
                  ),
                )),

            SizedBox(height: 12),

            // Help text
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact your administrator if you don\'t have login credentials.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: () => Get.back(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
          ),
          child: Text('Cancel'),
        ),

        // Enhanced join button with loading state
        Obx(() => ElevatedButton(
              onPressed: controller.isLoading.value
                  ? null
                  : () async {
                      // Start the join process
                      await controller.joinSchool();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: controller.isLoading.value
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Connecting...'),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 8),
                        Text('Sign In'),
                      ],
                    ),
            )),
      ],
    ),
    barrierDismissible: false, // Prevent dismissing during loading
  );
}

// Enhanced responsive button component for school selection
Widget _buildActionButton({
  required String text,
  required VoidCallback onPressed,
  required IconData icon,
  Color? backgroundColor,
  Color? foregroundColor,
  bool isLoading = false,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foregroundColor ?? Colors.white,
                ),
              ),
            )
          : Icon(icon, size: 20),
      label: Text(
        isLoading ? 'Loading...' : text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.blue.shade600,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    ),
  );
}
