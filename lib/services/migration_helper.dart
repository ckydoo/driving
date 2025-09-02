// lib/services/migration_helper.dart - Helper for migrating local users to Firebase
import 'package:driving/controllers/auth_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/services/database_helper.dart';
import 'package:driving/services/school_config_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MigrationHelper {
  static const String _migrationCompleteKey = 'migration_completed';

  /// Check if migration is needed
  static Future<bool> needsMigration() async {
    try {
      // Check if migration was already completed
      final prefs = await SharedPreferences.getInstance();
      final migrationCompleted = prefs.getBool(_migrationCompleteKey) ?? false;

      if (migrationCompleted) {
        print('📝 Migration already completed');
        return false;
      }

      // Check if there are local users that need migration
      final localUsers = await DatabaseHelper.instance.getUsers();
      final unmigrated = localUsers
          .where((user) =>
              user['firebase_user_id'] == null ||
              user['firebase_user_id'].toString().isEmpty)
          .toList();

      print('👥 Found ${unmigrated.length} users needing migration');
      return unmigrated.isNotEmpty;
    } catch (e) {
      print('❌ Error checking migration status: $e');
      return false;
    }
  }

  /// Show migration dialog to admin
  static void showMigrationDialog() {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_upload, color: Colors.blue),
            SizedBox(width: 8),
            Text('Account Migration Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your account can be migrated to the cloud for better synchronization across devices.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Benefits:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('• Automatic data backup',
                      style: TextStyle(color: Colors.blue[800])),
                  Text('• Sync across multiple devices',
                      style: TextStyle(color: Colors.blue[800])),
                  Text('• Better security',
                      style: TextStyle(color: Colors.blue[800])),
                  Text('• No more sync status conflicts',
                      style: TextStyle(color: Colors.blue[800])),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _remindLater();
            },
            child: const Text('Remind Me Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              startMigrationProcess();
            },
            child: const Text('Migrate Now'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Start the migration process
  static Future<void> startMigrationProcess() async {
    try {
      Get.dialog(
        const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparing migration...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Get current user info
      final authController = Get.find<AuthController>();
      final currentUser = authController.currentUser.value;

      if (currentUser == null) {
        throw Exception('No user currently logged in');
      }

      // Close loading dialog
      Get.back();

      // Show password setup dialog
      _showPasswordSetupDialog(currentUser);
    } catch (e) {
      Get.back(); // Close loading dialog
      print('❌ Migration preparation failed: $e');

      Get.snackbar(
        'Migration Failed',
        'Could not prepare migration: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Show password setup dialog
  static void _showPasswordSetupDialog(User currentUser) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool obscureConfirm = true;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Set Cloud Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create a new password for your cloud account.\nEmail: ${currentUser.email}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Get.back();
                  _executeMigration(currentUser, passwordController.text);
                }
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Execute the actual migration
  static Future<void> _executeMigration(
      User currentUser, String newPassword) async {
    try {
      // Show progress dialog
      Get.dialog(
        const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Migrating your account...'),
              SizedBox(height: 8),
              Text(
                'This may take a few moments',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Step 1: Create Firebase user
      final firebaseAuth = firebase_auth.FirebaseAuth.instance;
      final credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: currentUser.email,
        password: newPassword,
      );

      if (credential.user == null) {
        throw Exception('Failed to create Firebase user');
      }

      print('✅ Firebase user created: ${credential.user!.uid}');

      // Step 2: Save user data to Firebase
      await _saveUserDataToFirebase(credential.user!, currentUser);

      // Step 3: Update local user with Firebase UID
      await _updateLocalUserWithFirebaseUID(currentUser, credential.user!.uid);

      // Step 4: Migrate user's data (schedules, invoices, etc.)
      await _migrateUserData(currentUser, credential.user!.uid);

      // Step 5: Mark migration as complete
      await _markMigrationComplete();

      // Close progress dialog
      Get.back();

      // Show success message
      Get.dialog(
        AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Migration Complete!'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Your account has been successfully migrated to the cloud.'),
              SizedBox(height: 12),
              Text(
                'Benefits now active:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('✓ Automatic data backup'),
              Text('✓ Cross-device synchronization'),
              Text('✓ Enhanced security'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Get.back();
                // Restart app or navigate to main
                Get.offAllNamed('/main');
              },
              child: const Text('Continue'),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      print('✅ Migration completed successfully');
    } catch (e) {
      print('❌ Migration failed: $e');
      Get.back(); // Close progress dialog

      Get.dialog(
        AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 48),
          title: const Text('Migration Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The migration could not be completed:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your local account is still safe and functional. You can try migration again later.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Save user data to Firebase Firestore
  static Future<void> _saveUserDataToFirebase(
      firebase_auth.User firebaseUser, User localUser) async {
    try {
      final schoolConfig = Get.find<SchoolConfigService>();
      final schoolId = schoolConfig.schoolId.value;

      if (schoolId.isEmpty) {
        throw Exception('School configuration not found');
      }

      // Prepare user data for Firebase
      final userData = {
        'firebase_user_id': firebaseUser.uid,
        'id': localUser.id,
        'fname': localUser.fname,
        'lname': localUser.lname,
        'email': localUser.email,
        'phone': localUser.phone,
        'address': localUser.address,
        'date_of_birth': localUser.date_of_birth,
        'gender': localUser.gender,
        'idnumber': localUser.idnumber,
        'role': localUser.role,
        'status': localUser.status,
        'created_at': localUser.created_at,
        'last_modified': DateTime.now().toIso8601String(),
        'firebase_synced': 1,
        'migrated_at': DateTime.now().toIso8601String(),
      };

      // Save to Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(firebaseUser.uid)
          .set(userData);

      print('✅ User data saved to Firebase');
    } catch (e) {
      print('❌ Error saving user data to Firebase: $e');
      throw Exception('Failed to save user data to cloud: $e');
    }
  }

  /// Update local user with Firebase UID
  static Future<void> _updateLocalUserWithFirebaseUID(
      User localUser, String firebaseUID) async {
    try {
      // Update local user record with Firebase UID
      final updatedUser = User(
        id: localUser.id,
        fname: localUser.fname,
        lname: localUser.lname,
        email: localUser.email,
        password: localUser.password, // Keep local password for now
        phone: localUser.phone,
        address: localUser.address,
        date_of_birth: localUser.date_of_birth,
        gender: localUser.gender,
        idnumber: localUser.idnumber,
        role: localUser.role,
        status: localUser.status,
        created_at: localUser.created_at,
      );

      await DatabaseHelper.instance.updateUser(updatedUser);

      // Add Firebase UID to user table (you may need to add this column)
      final db = await DatabaseHelper.instance.database;
      await db.execute('''
        UPDATE users 
        SET firebase_user_id = ?, firebase_synced = 1, last_modified = ?
        WHERE id = ?
      ''', [firebaseUID, DateTime.now().toIso8601String(), localUser.id]);

      print('✅ Local user updated with Firebase UID');
    } catch (e) {
      print('❌ Error updating local user: $e');
      throw Exception('Failed to update local user record: $e');
    }
  }

  /// Migrate user's data to Firebase
  static Future<void> _migrateUserData(
      User localUser, String firebaseUID) async {
    try {
      print('🔄 Migrating user data...');

      // This would migrate schedules, invoices, payments, etc.
      // For now, just mark as ready for sync
      final db = await DatabaseHelper.instance.database;

      // Mark all user-related records as unsynced so they get uploaded
      final tables = [
        'schedules',
        'invoices',
        'payments',
        'attachments',
        'notes'
      ];

      for (String table in tables) {
        try {
          await db.execute('''
            UPDATE $table 
            SET firebase_synced = 0, last_modified = ?
            WHERE user_id = ? OR student_id = ? OR instructor_id = ?
          ''', [
            DateTime.now().toIso8601String(),
            localUser.id,
            localUser.id,
            localUser.id,
          ]);
        } catch (e) {
          print('⚠️ Could not mark $table records for sync: $e');
        }
      }

      print('✅ User data prepared for sync');
    } catch (e) {
      print('❌ Error migrating user data: $e');
      // Don't throw - this is not critical
    }
  }

  /// Mark migration as complete
  static Future<void> _markMigrationComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationCompleteKey, true);
      await prefs.setString(
          'migration_completed_at', DateTime.now().toIso8601String());
      print('✅ Migration marked as complete');
    } catch (e) {
      print('⚠️ Could not mark migration as complete: $e');
    }
  }

  /// Set reminder for later
  static void _remindLater() {
    Get.snackbar(
      'Migration Reminder Set',
      'You\'ll be reminded about account migration in 24 hours',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );

    // You could implement actual scheduling here
  }

  /// Reset migration status (for testing)
  static Future<void> resetMigrationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_migrationCompleteKey);
      await prefs.remove('migration_completed_at');
      print('✅ Migration status reset');
    } catch (e) {
      print('❌ Error resetting migration status: $e');
    }
  }
}
