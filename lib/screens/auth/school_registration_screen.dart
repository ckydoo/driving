// lib/screens/auth/school_registration_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/school_registration_controller.dart';

class SchoolRegistrationScreen extends StatelessWidget {
  const SchoolRegistrationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SchoolRegistrationController());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Register New School'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth > 600 ? 24.0 : 16.0,
                  vertical: 16.0,
                ),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth > 600
                          ? 500
                          : constraints.maxWidth - 32,
                    ),
                    padding: EdgeInsets.all(
                      constraints.maxWidth > 600 ? 32.0 : 24.0,
                    ),
                    child: Obx(
                      () => Form(
                        key: controller.formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            const Text(
                              'Create Your School',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Fill in your school information to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 32),

                            // School Information Section
                            const Text(
                              'School Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // School Name
                            TextFormField(
                              controller: controller.schoolNameController,
                              decoration: InputDecoration(
                                labelText: 'School Name',
                                hintText: 'e.g., ABC Driving School',
                                prefixIcon: const Icon(Icons.school),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: controller.validateSchoolName,
                              textCapitalization: TextCapitalization.words,
                            ),

                            const SizedBox(height: 16),

                            // Address
                            TextFormField(
                              controller: controller.addressController,
                              decoration: InputDecoration(
                                labelText: 'Address',
                                hintText: 'School address',
                                prefixIcon: const Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: controller.validateAddress,
                              textCapitalization: TextCapitalization.words,
                              maxLines: 2,
                            ),

                            const SizedBox(height: 16),

                            // Phone
                            TextFormField(
                              controller: controller.phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '0784666891',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: controller.validatePhone,
                              keyboardType: TextInputType.phone,
                            ),

                            const SizedBox(height: 24),

                            // Administrator Account Section
                            const Text(
                              'Administrator Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Admin Name
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        controller.adminFirstNameController,
                                    decoration: InputDecoration(
                                      labelText: 'First Name',
                                      prefixIcon: const Icon(Icons.person),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    validator: controller.validateFirstName,
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        controller.adminLastNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Last Name',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    validator: controller.validateLastName,
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Admin Email
                            TextFormField(
                              controller: controller.adminEmailController,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'admin@yourschool.com',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: controller.validateEmail,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller: controller.passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Minimum 8 characters',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    controller.obscurePassword.value
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed:
                                      controller.togglePasswordVisibility,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: controller.validatePassword,
                              obscureText: controller.obscurePassword.value,
                            ),

                            const SizedBox(height: 16),

                            // Confirm Password
                            TextFormField(
                              controller: controller.confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    controller.obscureConfirmPassword.value
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: controller
                                      .toggleConfirmPasswordVisibility,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: controller.validateConfirmPassword,
                              obscureText:
                                  controller.obscureConfirmPassword.value,
                            ),

                            const SizedBox(height: 24),

                            // Error message
                            if (controller.errorMessage.isNotEmpty)
                              Container(
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
                                        controller.errorMessage.value,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Register Button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: controller.isLoading.value
                                    ? null
                                    : controller.registerSchool,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: controller.isLoading.value
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Create School & Account',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Terms text
                            Text(
                              'By creating an account, you agree to our Terms of Service and Privacy Policy',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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
}
