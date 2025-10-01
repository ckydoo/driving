// lib/controllers/pin_controller.dart - Enhanced version with user association
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

class PinController extends GetxController {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _userVerifiedKey = 'user_verified';

  // Observable variables
  final RxBool isPinSet = false.obs;
  final RxBool isPinEnabled = false.obs;
  final RxInt pinAttempts = 0.obs;
  final RxBool isLocked = false.obs;
  final RxString lockoutEndTime = ''.obs;

  // Constants
  static const int maxAttempts = 5;
  static const int lockoutDuration = 300; // 5 minutes in seconds

  // Storage keys
  static const String _pinHashKey = 'user_pin_hash';
  static const String _pinEnabledKey = 'pin_enabled';
  static const String _pinAttemptsKey = 'pin_attempts';
  static const String _lockoutTimeKey = 'lockout_time';
  static const String _pinUserEmailKey =
      'pin_user_email'; // NEW: Store which user the PIN belongs to

  @override
  void onInit() {
    super.onInit();
    _initializePinState();
  }

  Future<void> _initializePinState() async {
    try {
      // Check if PIN is enabled
      final pinEnabledStr = await _secureStorage.read(key: _pinEnabledKey);
      isPinEnabled.value = pinEnabledStr == 'true';

      // Check if PIN exists
      final pinHash = await _secureStorage.read(key: _pinHashKey);
      isPinSet.value = pinHash != null && pinHash.isNotEmpty;

      // Check lockout status
      await _checkLockoutStatus();

      // Reset attempts if not locked
      if (!isLocked.value) {
        pinAttempts.value = 0;
        await _secureStorage.delete(key: _pinAttemptsKey);
      }
    } catch (e) {
      debugPrint('Error initializing PIN state: $e');
    }
  }

  Future<void> setUserVerified(bool verified) async {
    if (verified) {
      await _secureStorage.write(key: _userVerifiedKey, value: 'true');
    } else {
      await _secureStorage.delete(key: _userVerifiedKey);
    }
  }

  // NEW: Get the email of the user associated with the PIN
  Future<String?> getPinUserEmail() async {
    return await _secureStorage.read(key: _pinUserEmailKey);
  }

  // NEW: Set the user email for the PIN
  Future<void> setPinUserEmail(String email) async {
    await _secureStorage.write(key: _pinUserEmailKey, value: email);
  }

  // ENHANCED: Setup PIN with optional user email association
  Future<bool> setupPin(String pin, {String? userEmail}) async {
    try {
      if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
        Get.snackbar(
          'Invalid PIN',
          'PIN must be exactly 4 digits',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final hashedPin = _hashPin(pin);
      await _secureStorage.write(key: _pinHashKey, value: hashedPin);
      await _secureStorage.write(key: _pinEnabledKey, value: 'true');

      // NEW: Store which user this PIN belongs to
      if (userEmail != null) {
        await _secureStorage.write(key: _pinUserEmailKey, value: userEmail);
        debugPrint('PIN associated with user: $userEmail');
      }

      isPinSet.value = true;
      isPinEnabled.value = true;
      pinAttempts.value = 0;

      Get.snackbar(
        'PIN Setup Complete',
        'Your PIN has been set successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      return true;
    } catch (e) {
      debugPrint('Error setting up PIN: $e');
      Get.snackbar(
        'Error',
        'Failed to setup PIN. Please try again.',
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      // Check if locked out
      if (isLocked.value) {
        final remaining = await _getRemainingLockoutTime();
        Get.snackbar(
          'Account Locked',
          'Too many failed attempts. Try again in ${_formatDuration(remaining)}',
          backgroundColor: Colors.red,
          snackPosition: SnackPosition.BOTTOM,
          colorText: Colors.white,
        );
        return false;
      }

      final storedHash = await _secureStorage.read(key: _pinHashKey);
      if (storedHash == null) {
        return false;
      }

      final inputHash = _hashPin(pin);
      final isValid = storedHash == inputHash;

      if (isValid) {
        // Reset attempts on successful verification
        pinAttempts.value = 0;
        await _secureStorage.delete(key: _pinAttemptsKey);
        await _secureStorage.delete(key: _lockoutTimeKey);
        isLocked.value = false;

        // Log successful PIN verification
        final userEmail = await getPinUserEmail();
        debugPrint(
            'PIN verification successful for user: ${userEmail ?? "unknown"}');

        return true;
      } else {
        // Increment failed attempts
        pinAttempts.value++;
        await _secureStorage.write(
            key: _pinAttemptsKey, value: pinAttempts.value.toString());

        if (pinAttempts.value >= maxAttempts) {
          await _lockAccount();
          Get.snackbar(
            'Account Locked',
            'Too many failed PIN attempts. Account locked for ${_formatDuration(lockoutDuration)}',
            backgroundColor: Colors.red,
            snackPosition: SnackPosition.BOTTOM,
            colorText: Colors.white,
          );
        } else {
          final remaining = maxAttempts - pinAttempts.value;
          Get.snackbar(
            'Incorrect PIN',
            '$remaining attempts remaining before lockout',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  Future<void> _lockAccount() async {
    final lockoutTime = DateTime.now().add(Duration(seconds: lockoutDuration));
    await _secureStorage.write(
        key: _lockoutTimeKey, value: lockoutTime.toIso8601String());
    isLocked.value = true;
    lockoutEndTime.value = lockoutTime.toIso8601String();
  }

  Future<void> _checkLockoutStatus() async {
    try {
      final lockoutTimeStr = await _secureStorage.read(key: _lockoutTimeKey);
      if (lockoutTimeStr != null) {
        final lockoutTime = DateTime.parse(lockoutTimeStr);
        if (DateTime.now().isBefore(lockoutTime)) {
          isLocked.value = true;
          lockoutEndTime.value = lockoutTimeStr;

          // Get stored attempts
          final attemptsStr = await _secureStorage.read(key: _pinAttemptsKey);
          pinAttempts.value = int.tryParse(attemptsStr ?? '0') ?? 0;
        } else {
          // Lockout expired, clear it
          await _secureStorage.delete(key: _lockoutTimeKey);
          await _secureStorage.delete(key: _pinAttemptsKey);
          isLocked.value = false;
          pinAttempts.value = 0;
        }
      }
    } catch (e) {
      debugPrint('Error checking lockout status: $e');
    }
  }

  Future<int> _getRemainingLockoutTime() async {
    final lockoutTimeStr = await _secureStorage.read(key: _lockoutTimeKey);
    if (lockoutTimeStr != null) {
      final lockoutTime = DateTime.parse(lockoutTimeStr);
      final remaining = lockoutTime.difference(DateTime.now()).inSeconds;
      return remaining > 0 ? remaining : 0;
    }
    return 0;
  }

  Future<bool> changePin(String currentPin, String newPin) async {
    try {
      // Verify current PIN first (without triggering lockout increment)
      final storedHash = await _secureStorage.read(key: _pinHashKey);
      if (storedHash == null) {
        Get.snackbar(
          'Error',
          'No PIN found to change',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final currentPinHash = _hashPin(currentPin);
      if (storedHash != currentPinHash) {
        Get.snackbar(
          'Error',
          'Current PIN is incorrect',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      // Get current user email to maintain association
      final userEmail = await getPinUserEmail();

      // Set new PIN with same user association
      return await setupPin(newPin, userEmail: userEmail);
    } catch (e) {
      debugPrint('Error changing PIN: $e');
      return false;
    }
  }

  Future<void> disablePin() async {
    try {
      await _secureStorage.delete(key: _pinHashKey);
      await _secureStorage.write(key: _pinEnabledKey, value: 'false');
      await _secureStorage.delete(key: _pinAttemptsKey);
      await _secureStorage.delete(key: _lockoutTimeKey);
      // Keep user email association for potential re-enabling

      isPinSet.value = false;
      isPinEnabled.value = false;
      pinAttempts.value = 0;
      isLocked.value = false;

      Get.snackbar(
        'PIN Disabled',
        'PIN authentication has been disabled',
        backgroundColor: Colors.blue,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Error disabling PIN: $e');
    }
  }

  Future<void> resetPin() async {
    try {
      await _secureStorage.delete(key: _pinHashKey);
      await _secureStorage.delete(key: _pinAttemptsKey);
      await _secureStorage.delete(key: _lockoutTimeKey);
      // Keep user email association and verification status

      isPinSet.value = false;
      pinAttempts.value = 0;
      isLocked.value = false;

      // Keep PIN enabled so user can set a new one
      isPinEnabled.value = true;
    } catch (e) {
      debugPrint('Error resetting PIN: $e');
    }
  }

  Future<void> clearAllPinData() async {
    try {
      await _secureStorage.delete(key: _pinHashKey);
      await _secureStorage.delete(key: _pinEnabledKey);
      await _secureStorage.delete(key: _pinAttemptsKey);
      await _secureStorage.delete(key: _lockoutTimeKey);
      await _secureStorage.delete(key: _userVerifiedKey);
      await _secureStorage.delete(
          key: _pinUserEmailKey); // NEW: Clear user association

      isPinSet.value = false;
      isPinEnabled.value = false;
      pinAttempts.value = 0;
      isLocked.value = false;
    } catch (e) {
      debugPrint('Error clearing PIN data: $e');
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + 'driving_school_salt'); // Add salt
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = seconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  // Check if PIN authentication should be used
  bool shouldUsePinAuth() {
    return isPinEnabled.value && isPinSet.value && !isLocked.value;
  }

  // Get PIN setup status for UI
  String getPinStatus() {
    if (isLocked.value) return 'Locked';
    if (!isPinEnabled.value) return 'Disabled';
    if (!isPinSet.value) return 'Not Set';
    return 'Active';
  }

  /// Mark user as verified after successful PIN login
  Future<void> markUserAsVerified() async {
    try {
      await _secureStorage.write(key: _userVerifiedKey, value: 'true');
      debugPrint('✅ User marked as verified');
    } catch (e) {
      debugPrint('❌ Error marking user as verified: $e');
    }
  }

  /// Check if user has been verified via PIN
  Future<bool> isUserVerified() async {
    try {
      final verified = await _secureStorage.read(key: _userVerifiedKey);
      final isVerified = verified == 'true';
      debugPrint('🔍 User verification status: $isVerified');
      return isVerified;
    } catch (e) {
      debugPrint('❌ Error checking user verification: $e');
      return false;
    }
  }

  /// Clear user verification (call on logout)
  Future<void> clearUserVerification() async {
    try {
      await _secureStorage.delete(key: _userVerifiedKey);
      debugPrint('🧹 User verification cleared');
    } catch (e) {
      debugPrint('❌ Error clearing verification: $e');
    }
  }

  // NEW: Get detailed PIN info for debugging
  Future<Map<String, dynamic>> getPinInfo() async {
    return {
      'isPinSet': isPinSet.value,
      'isPinEnabled': isPinEnabled.value,
      'isLocked': isLocked.value,
      'pinAttempts': pinAttempts.value,
      'userEmail': await getPinUserEmail(),
      'isUserVerified': await isUserVerified(),
      'status': getPinStatus(),
    };
  }
}
