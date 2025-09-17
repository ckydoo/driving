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

                const SizedBox(height: 60),

                // Welcome Text
                Text(
                  'Welcome to Driving School Manager',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  'Choose how you want to get started',
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
        const SizedBox(height: 16),
        Text(
          'Multi-School Management',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
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
          title: 'Join Existing School',
          subtitle: 'Sign in with your school credentials',
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
    icon: const Icon(Icons.add_business, size: 20),
    label: const Text('Register New School'),
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
          color: Colors.grey[600],
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          'Multi-school management allows you to manage multiple driving schools from one app. Each school maintains its own data and settings.',
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
      title: const Text('Join School'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller.schoolNameController,
            decoration: const InputDecoration(
              labelText: 'School Name or Code',
              hintText: 'Enter school name or invitation code',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.school),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
          ),
          const SizedBox(height: 16),
          Obx(() => TextField(
                controller: controller.passwordController,
                obscureText: controller.obscurePassword.value,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.obscurePassword.value
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => controller.togglePasswordVisibility(),
                  ),
                ),
              )),
          const SizedBox(height: 12),
          const Text(
            'Contact your school administrator if you don\'t have login credentials.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        Obx(() => ElevatedButton(
              onPressed: controller.isLoading.value
                  ? null
                  : () {
                      controller.joinSchool();
                      Get.back();
                    },
              child: controller.isLoading.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join School'),
            )),
      ],
    ),
  );
}
