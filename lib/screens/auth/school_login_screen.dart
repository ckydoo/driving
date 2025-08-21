// lib/screens/auth/school_login_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/school_login_controller.dart';

class SchoolLoginScreen extends StatelessWidget {
  const SchoolLoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SchoolLoginController());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Join Existing School'),
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
                          ? 450
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
                              'Join Your School',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter your school details and login credentials',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 32),

                            // School ID or Name
                            TextFormField(
                              controller: controller.schoolIdentifierController,
                              decoration: InputDecoration(
                                labelText: 'School Name or ID',
                                hintText:
                                    'e.g., ABC Driving School or school_abc123',
                                prefixIcon: const Icon(Icons.school),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.search),
                                  onPressed: controller.searchSchools,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                helperText:
                                    'Ask your administrator for school details',
                                helperMaxLines: 2,
                              ),
                              validator: controller.validateSchoolIdentifier,
                              onChanged: controller.onSchoolIdentifierChanged,
                            ),

                            const SizedBox(height: 8),

                            // School search results
                            if (controller.searchResults.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        'Found Schools:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                    ...controller.searchResults.map(
                                      (school) => ListTile(
                                        dense: true,
                                        leading:
                                            const Icon(Icons.school, size: 20),
                                        title: Text(school['name'] ?? ''),
                                        subtitle: Text(school['id'] ?? ''),
                                        onTap: () =>
                                            controller.selectSchool(school),
                                        tileColor:
                                            controller.selectedSchool['id'] ==
                                                    school['id']
                                                ? Colors.blue.shade100
                                                : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Selected school info
                            if (controller.selectedSchool.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Selected: ${controller.selectedSchool['name']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                          Text(
                                            'ID: ${controller.selectedSchool['id']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: controller.clearSelectedSchool,
                                      iconSize: 20,
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                    child:
                                        Divider(color: Colors.grey.shade300)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'Your Account',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child:
                                        Divider(color: Colors.grey.shade300)),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Email
                            TextFormField(
                              controller: controller.emailController,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'your.email@domain.com',
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

                            // Login Button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: controller.isLoading.value
                                    ? null
                                    : controller.loginToSchool,
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
                                        'Login to School',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Help text
                            Text(
                              'Don\'t have an account? Contact your school administrator to create one for you.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 8),

                            // QR Code option
                            TextButton.icon(
                              onPressed: controller.showQRScanner,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan School QR Code'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue.shade600,
                              ),
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
