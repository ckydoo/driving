// lib/screens/auth/school_registration_screen.dart - WITH INTERNET STATUS

import 'package:driving/controllers/school_registration_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SchoolRegistrationScreen extends StatelessWidget {
  const SchoolRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SchoolRegistrationController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Obx(() {
          // Show different content based on registration mode
          if (controller.registrationMode.value == 'checking') {
            return _buildLoadingState();
          } else if (controller.registrationMode.value == 'online_required') {
            return _buildNoInternetState(controller);
          } else {
            return _buildRegistrationForm(controller);
          }
        }),
      ),
    );
  }

  /// Loading state while checking internet
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Checking internet connection...'),
        ],
      ),
    );
  }

  /// No internet state
  Widget _buildNoInternetState(SchoolRegistrationController controller) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 80,
            color: Colors.orange.shade600,
          ),
          const SizedBox(height: 24),
          const Text(
            'Internet Connection Required',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'School registration requires an internet connection to:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_upload, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Create your school account online'),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings,
                        size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Setup administrator access'),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.download, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Download school configuration'),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.sync, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Enable cloud sync features'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: controller.retryConnection,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  /// Registration form (when internet is available)
  Widget _buildRegistrationForm(SchoolRegistrationController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with internet status
            _buildHeaderWithStatus(controller),

            const SizedBox(height: 32),

            // School Information Section
            _buildSectionHeader('School Information'),
            const SizedBox(height: 16),

            _buildTextField(
              controller: controller.schoolNameController,
              label: 'School Name',
              hint: 'e.g., Moyo Driving School',
              icon: Icons.school,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'School name is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: controller.schoolAddressController,
              label: 'Address',
              hint: 'Street address',
              icon: Icons.location_on,
              maxLines: 2,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Address is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: controller.cityController,
                    label: 'City',
                    hint: 'e.g., Mutare',
                    icon: Icons.location_city,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: controller.countryController,
                    label: 'Country',
                    hint: 'e.g., Zimbabwe',
                    icon: Icons.flag,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Contact Information Section
            _buildSectionHeader('Contact Information'),
            const SizedBox(height: 16),

            _buildTextField(
              controller: controller.phoneController,
              label: 'Phone Number',
              hint: '+263 77 123 4567',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: controller.emailController,
              label: 'Email',
              hint: 'info@yourschool.com',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Email is required';
                }
                if (!GetUtils.isEmail(value!)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: controller.websiteController,
              label: 'Website (Optional)',
              hint: 'www.yourschool.com',
              icon: Icons.language,
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 32),

            // Administrator Account Section
            _buildSectionHeader('Administrator Account'),
            const SizedBox(height: 8),
            Text(
              'Create an administrator account for managing the school',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: controller.adminFirstNameController,
                    label: 'Admin First Name',
                    hint: 'John',
                    icon: Icons.person,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Admin first name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: controller.adminLastNameController,
                    label: 'Admin Last Name',
                    hint: 'Smith',
                    icon: Icons.person,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Admin last name is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: controller.adminEmailController,
              label: 'Admin Email',
              hint: 'admin@yourschool.com',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Admin email is required';
                }
                if (!GetUtils.isEmail(value!)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: controller.adminPhoneController,
              label: 'Admin Phone Number',
              hint: '+263 77 123 4567',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Admin phone number is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            Obx(() => _buildTextField(
                  controller: controller.adminPasswordController,
                  label: 'Admin Password',
                  hint: 'At least 8 characters',
                  icon: Icons.lock,
                  obscureText: controller.obscurePassword.value,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.obscurePassword.value
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: controller.togglePasswordVisibility,
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Admin password is required';
                    }
                    if (value!.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                )),

            const SizedBox(height: 24),

            // Operating Hours Section
            _buildSectionHeader('Operating Hours'),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Obx(() => _buildTimeField(
                        label: 'Start Time',
                        time: controller.startTime.value,
                        onTap: () => controller.selectStartTime,
                      )),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Obx(() => _buildTimeField(
                        label: 'End Time',
                        time: controller.endTime.value,
                        onTap: () => controller.selectEndTime,
                      )),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Operating Days
            Text(
              'Operating Days',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),

            Obx(() => _buildDaySelector(controller)),

            const SizedBox(height: 32),

            // Register Button
            Obx(() => ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.registerSchool,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: controller.isLoading.value
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Registering School...'),
                          ],
                        )
                      : const Text(
                          'Register School Online',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                )),

            const SizedBox(height: 16),

            // Internet Status Indicator (Dynamic)
            Obx(() => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: controller.isOnline.value
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: controller.isOnline.value
                            ? Colors.green.shade200
                            : Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        controller.isOnline.value
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        size: 20,
                        color: controller.isOnline.value
                            ? Colors.green.shade600
                            : Colors.orange.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.isOnline.value
                                  ? 'Internet Connection Active'
                                  : 'Connection Lost',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: controller.isOnline.value
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                            Text(
                              controller.isOnline.value
                                  ? 'Your school will be registered online and data downloaded for offline access.'
                                  : 'Internet connection is required for registration. Please check your connection.',
                              style: TextStyle(
                                fontSize: 12,
                                color: controller.isOnline.value
                                    ? Colors.green.shade600
                                    : Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Header with connection status
  Widget _buildHeaderWithStatus(SchoolRegistrationController controller) {
    return Column(
      children: [
        Icon(
          Icons.school,
          size: 64,
          color: Colors.blue.shade600,
        ),
        const SizedBox(height: 16),
        const Text(
          'Register Your Driving School',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Create your school account and download configuration',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build section header
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Build text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade600),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  /// Build time field
  Widget _buildTimeField({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  time.format(Get.context!),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build day selector
  Widget _buildDaySelector(SchoolRegistrationController controller) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.map((day) {
        final isSelected = controller.operatingDays.contains(day);
        return FilterChip(
          label: Text(day),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              controller.operatingDays.add(day);
            } else {
              controller.operatingDays.remove(day);
            }
          },
          selectedColor: Colors.blue.shade100,
          checkmarkColor: Colors.blue.shade600,
        );
      }).toList(),
    );
  }
}
