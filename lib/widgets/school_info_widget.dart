// lib/widgets/school_info_widget.dart
import 'package:driving/services/school_config_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Widget to display school information and multi-tenant status
class SchoolInfoWidget extends StatelessWidget {
  final bool showDetails;
  final VoidCallback? onTap;

  const SchoolInfoWidget({
    super.key,
    this.showDetails = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final schoolConfig = Get.find<SchoolConfigService>();

      if (!schoolConfig.isInitialized.value) {
        return _buildLoadingCard();
      }

      if (!schoolConfig.isValidConfiguration()) {
        return _buildConfigurationRequiredCard();
      }

      return _buildSchoolInfoCard(schoolConfig);
    });
  }

  Widget _buildLoadingCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            const Text(
              'Loading school configuration...',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationRequiredCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'School Configuration Required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Please complete your business information in settings to enable multi-tenant features and cloud sync.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade600,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.settings),
                  label: const Text('Configure Now'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolInfoCard(SchoolConfigService schoolConfig) {
    final schoolInfo = schoolConfig.getSchoolInfo();

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.green.shade50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schoolConfig.schoolName.value,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${schoolConfig.schoolId.value}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip('Active', Colors.green),
                ],
              ),

              if (showDetails) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // School Details
                _buildInfoRow(
                  Icons.location_on,
                  'Address',
                  '${schoolInfo['businessAddress']}, ${schoolInfo['businessCity']}, ${schoolInfo['businessCountry']}',
                ),

                if (schoolInfo['businessPhone']?.isNotEmpty == true)
                  _buildInfoRow(
                    Icons.phone,
                    'Phone',
                    schoolInfo['businessPhone']!,
                  ),

                if (schoolInfo['businessEmail']?.isNotEmpty == true)
                  _buildInfoRow(
                    Icons.email,
                    'Email',
                    schoolInfo['businessEmail']!,
                  ),

                const SizedBox(height: 16),

                // Multi-tenant features
                Row(
                  children: [
                    _buildFeatureChip(
                        'Multi-Tenant', Icons.business, Colors.blue),
                    const SizedBox(width: 8),
                    _buildFeatureChip('Cloud Sync', Icons.cloud, Colors.purple),
                  ],
                ),
              ],

              if (onTap != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version for app bars and small spaces
class CompactSchoolInfoWidget extends StatelessWidget {
  final VoidCallback? onTap;

  const CompactSchoolInfoWidget({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final schoolConfig = Get.find<SchoolConfigService>();

        if (!schoolConfig.isInitialized.value ||
            !schoolConfig.isValidConfiguration()) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Setup Required',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school,
                  size: 14,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  schoolConfig.schoolName.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
