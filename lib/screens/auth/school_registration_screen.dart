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
        title: const Text('Register New School'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),

                const SizedBox(height: 32),

                // School Information Section
                _buildSectionHeader('School Information'),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: controller.schoolNameController,
                  label: 'School Name',
                  hint: 'e.g., Metro Driving School',
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
                        hint: 'e.g., Harare',
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
                            onTap: () => controller.selectStartTime(context),
                          )),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Obx(() => _buildTimeField(
                            label: 'End Time',
                            time: controller.endTime.value,
                            onTap: () => controller.selectEndTime(context),
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
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Register School',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    )),

                const SizedBox(height: 16),

                // Info card
                _buildInfoCard(),
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Icon(
            Icons.add_business,
            size: 40,
            color: Colors.blue.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Create Your School',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Set up your driving school to start managing students and lessons',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue.shade600),
        ),
      ),
    );
  }

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
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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

  Widget _buildDaySelector(SchoolRegistrationController controller) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Wrap(
      spacing: 8,
      children: days.map((day) {
        final isSelected = controller.operatingDays.contains(day);
        return FilterChip(
          label: Text(day),
          selected: isSelected,
          onSelected: (selected) => controller.toggleOperatingDay(day),
          selectedColor: Colors.blue.shade100,
          checkmarkColor: Colors.blue.shade600,
        );
      }).toList(),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            'After registration, you\'ll receive a unique school code that staff and instructors can use to join your school.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
