// lib/screens/subscription/upgrade_required_screen.dart
// Create this file to show when users try to access locked features

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/subscription_controller.dart';
import 'subscription_screen.dart';

class UpgradeRequiredScreen extends StatelessWidget {
  final String featureName;
  final String featureDescription;
  final IconData featureIcon;

  const UpgradeRequiredScreen({
    Key? key,
    this.featureName = 'Premium Feature',
    this.featureDescription = 'This feature requires an active subscription.',
    this.featureIcon = Icons.lock,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subscriptionController = Get.find<SubscriptionController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Upgrade Required'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock Icon
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  featureIcon,
                  size: 80,
                  color: Colors.blue[700],
                ),
              ),

              SizedBox(height: 32),

              // Feature Name
              Text(
                featureName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 16),

              // Description
              Text(
                featureDescription,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 32),

              // Current Status
              Obx(() {
                String statusMessage;
                Color statusColor;

                if (subscriptionController.subscriptionStatus.value ==
                    'trial') {
                  statusMessage =
                      'Trial: ${subscriptionController.remainingTrialDays.value} days remaining';
                  statusColor = Colors.orange;
                } else if (subscriptionController.subscriptionStatus.value ==
                    'expired') {
                  statusMessage = 'Your trial has expired';
                  statusColor = Colors.red;
                } else {
                  statusMessage = 'Subscription required';
                  statusColor = Colors.grey;
                }

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: statusColor, size: 20),
                      SizedBox(width: 8),
                      Text(
                        statusMessage,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              SizedBox(height: 40),

              // Benefits List
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to unlock:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildBenefitItem('Unlimited students and instructors'),
                    _buildBenefitItem('Advanced reporting and analytics'),
                    _buildBenefitItem('Priority customer support'),
                    _buildBenefitItem('Custom branding options'),
                    _buildBenefitItem('Mobile app access'),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.to(() => SubscriptionScreen());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View Subscription Plans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Go Back',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[600],
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// USAGE EXAMPLE
// ============================================

/*
// Use this screen to protect features:

// Example 1: Protect entire screen
class AdvancedReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subscriptionController = Get.find<SubscriptionController>();
    
    if (!subscriptionController.canAccessFeature('advanced_reports')) {
      return UpgradeRequiredScreen(
        featureName: 'Advanced Reports',
        featureDescription: 'Get detailed insights and analytics with advanced reporting.',
        featureIcon: Icons.analytics,
      );
    }
    
    // Normal screen content
    return Scaffold(
      appBar: AppBar(title: Text('Advanced Reports')),
      body: YourReportsContent(),
    );
  }
}

// Example 2: Protect a specific action
void addNewStudent() {
  final subscriptionController = Get.find<SubscriptionController>();
  final userController = Get.find<UserController>();
  
  final currentStudentCount = userController.students.length;
  
  if (subscriptionController.hasReachedLimit('max_students', currentStudentCount)) {
    Get.to(() => UpgradeRequiredScreen(
      featureName: 'Student Limit Reached',
      featureDescription: 'You\'ve reached the maximum number of students for your plan.',
      featureIcon: Icons.group_add,
    ));
    return;
  }
  
  // Proceed with adding student
  showAddStudentDialog();
}
*/
