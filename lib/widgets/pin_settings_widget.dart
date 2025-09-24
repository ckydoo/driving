// lib/widgets/pin_settings_widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driving/controllers/pin_controller.dart';

class PinSettingsWidget extends StatelessWidget {
  const PinSettingsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final PinController pinController = Get.find<PinController>();

    return Obx(() => Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'PIN Security',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // PIN Status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(pinController).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(pinController).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(pinController),
                        color: _getStatusColor(pinController),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PIN Status: ${pinController.getPinStatus()}',
                        style: TextStyle(
                          color: _getStatusColor(pinController),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // PIN Options
                if (!pinController.isPinSet.value) ...[
                  // Setup PIN
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Setup PIN'),
                    subtitle:
                        const Text('Create a 4-digit PIN for quick login'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _setupPin(),
                  ),
                ] else ...[
                  // Change PIN
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Change PIN'),
                    subtitle: const Text('Update your current PIN'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _changePin(pinController),
                  ),

                  const Divider(),

                  // Enable/Disable PIN
                  SwitchListTile(
                    secondary: const Icon(Icons.toggle_on),
                    title: const Text('Enable PIN Login'),
                    subtitle: Text(
                      pinController.isPinEnabled.value
                          ? 'Use PIN for quick login'
                          : 'PIN login is disabled',
                    ),
                    value: pinController.isPinEnabled.value,
                    onChanged: (value) => _togglePin(pinController, value),
                  ),

                  const Divider(),

                  // Remove PIN
                  ListTile(
                    leading:
                        Icon(Icons.delete_outline, color: Colors.red.shade600),
                    title: Text(
                      'Remove PIN',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                    subtitle: const Text('Disable and remove PIN completely'),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.red.shade600,
                    ),
                    onTap: () => _removePin(pinController),
                  ),
                ],

                if (pinController.isPinSet.value) ...[
                  const SizedBox(height: 16),

                  // Security Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Failed attempts: ${pinController.pinAttempts.value}/5',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ));
  }

  Color _getStatusColor(PinController controller) {
    if (controller.isLocked.value) return Colors.red;
    if (!controller.isPinEnabled.value) return Colors.grey;
    if (!controller.isPinSet.value) return Colors.orange;
    return Colors.green;
  }

  IconData _getStatusIcon(PinController controller) {
    if (controller.isLocked.value) return Icons.lock;
    if (!controller.isPinEnabled.value) return Icons.toggle_off;
    if (!controller.isPinSet.value) return Icons.warning;
    return Icons.check_circle;
  }

  void _setupPin() {
    Get.toNamed('/pin-setup-settings');
  }

  void _changePin(PinController controller) {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Change PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'New PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Confirm New PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPinController.text != confirmPinController.text) {
                Get.snackbar(
                  snackPosition: SnackPosition.BOTTOM,
                  'Error',
                  'New PINs do not match',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              if (newPinController.text.length != 4) {
                Get.snackbar(
                  snackPosition: SnackPosition.BOTTOM,
                  'Error',
                  'PIN must be 4 digits',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              final success = await controller.changePin(
                currentPinController.text,
                newPinController.text,
              );

              if (success) {
                Get.back();
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _togglePin(PinController controller, bool enabled) {
    if (!enabled) {
      Get.dialog(
        AlertDialog(
          title: const Text('Disable PIN Login?'),
          content:
              const Text('You will need to use email and password for login. '
                  'Your PIN will be kept and can be re-enabled later.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                controller.isPinEnabled.value = false;
                Get.back();
                Get.snackbar(
                  snackPosition: SnackPosition.BOTTOM,
                  'PIN Disabled',
                  'PIN login has been disabled',
                  backgroundColor: Colors.blue,
                  colorText: Colors.white,
                );
              },
              child: const Text('Disable'),
            ),
          ],
        ),
      );
    } else {
      controller.isPinEnabled.value = true;
      Get.snackbar(
        snackPosition: SnackPosition.BOTTOM,
        'PIN Enabled',
        'PIN login has been enabled',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  void _removePin(PinController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('Remove PIN?'),
        content: const Text('This will permanently delete your PIN. '
            'You will need to use email and password for login.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await controller.disablePin();
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
