import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:developer' as developer;

/// Centralized error handling service for the application
/// Provides user-friendly error messages and consistent error display
class ErrorHandler {
  /// Show error message to user via snackbar
  static void showError(String message, {String? title, Duration? duration}) {
    Get.snackbar(
      title ?? 'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade600,
      colorText: Colors.white,
      duration: duration ?? const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  /// Show success message to user via snackbar
  static void showSuccess(String message, {String? title, Duration? duration}) {
    Get.snackbar(
      title ?? 'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      duration: duration ?? const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
    );
  }

  /// Show warning message to user via snackbar
  static void showWarning(String message, {String? title, Duration? duration}) {
    Get.snackbar(
      title ?? 'Warning',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange.shade700,
      colorText: Colors.white,
      duration: duration ?? const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.warning_amber_outlined, color: Colors.white),
    );
  }

  /// Show info message to user via snackbar
  static void showInfo(String message, {String? title, Duration? duration}) {
    Get.snackbar(
      title ?? 'Info',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue.shade600,
      colorText: Colors.white,
      duration: duration ?? const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.info_outline, color: Colors.white),
    );
  }

  /// Show error dialog with details
  static Future<void> showErrorDialog({
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) async {
    await Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: () {
                Get.back();
                onAction();
              },
              child: Text(actionText),
            ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Convert technical exception to user-friendly message
  static String getFriendlyMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred';

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'The request took too long. Please try again.';
    }

    if (errorString.contains('connection refused')) {
      return 'Unable to reach the server. Please try again later.';
    }

    // Authentication errors - More specific messages
    if (errorString.contains('email not found') ||
        errorString.contains('user not found') ||
        errorString.contains('no user found')) {
      return 'No account found with this email address. Please check your email or register.';
    }

    if (errorString.contains('wrong password') ||
        errorString.contains('incorrect password') ||
        errorString.contains('password incorrect') ||
        errorString.contains('invalid password')) {
      return 'Incorrect password. Please try again.';
    }

    if (errorString.contains('email already exists') ||
        errorString.contains('email already in use') ||
        errorString.contains('user already exists')) {
      return 'An account with this email already exists. Please log in instead.';
    }

    if (errorString.contains('invalid email') ||
        errorString.contains('email format')) {
      return 'Please enter a valid email address (e.g., name@example.com)';
    }

    if (errorString.contains('unauthorized') || errorString.contains('401')) {
      return 'Your session has expired. Please sign in again.';
    }

    if (errorString.contains('forbidden') || errorString.contains('403')) {
      return 'You do not have permission to perform this action.';
    }

    if (errorString.contains('authentication') ||
        errorString.contains('invalid credentials')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }

    // Database errors
    if (errorString.contains('database') || errorString.contains('sqlite')) {
      return 'A database error occurred. Please restart the app.';
    }

    if (errorString.contains('unique constraint') ||
        errorString.contains('duplicate')) {
      return 'This record already exists.';
    }

    // Validation errors
    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return 'Please check your input and try again.';
    }

    if (errorString.contains('required field') ||
        errorString.contains('cannot be empty')) {
      return 'Please fill in all required fields.';
    }

    // Payment errors
    if (errorString.contains('payment') || errorString.contains('stripe')) {
      return 'Payment processing failed. Please check your payment details.';
    }

    if (errorString.contains('card declined') ||
        errorString.contains('insufficient funds')) {
      return 'Your card was declined. Please use a different payment method.';
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('internal server error')) {
      return 'A server error occurred. Please try again later.';
    }

    if (errorString.contains('503') ||
        errorString.contains('service unavailable')) {
      return 'The service is temporarily unavailable. Please try again later.';
    }

    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'The requested resource was not found.';
    }

    // Sync errors
    if (errorString.contains('sync')) {
      return 'Synchronization failed. Please try again.';
    }

    // Format errors
    if (errorString.contains('formatexception') ||
        errorString.contains('json')) {
      return 'Received invalid data from the server. Please try again.';
    }

    // Printer errors
    if (errorString.contains('printer') || errorString.contains('print')) {
      return 'Printer connection failed. Please check printer settings.';
    }

    // Generic fallback - but don't expose technical details
    return 'An error occurred. Please try again.';
  }

  /// Handle and display error with logging
  static void handle(dynamic error,
      {StackTrace? stackTrace,
      String? context,
      bool showToUser = true,
      String? customMessage}) {
    // Log the actual error for debugging (in development mode)
    developer.log(
      'Error occurred',
      name: 'ErrorHandler',
      error: error,
      stackTrace: stackTrace,
      level: 1000, // Error level
      time: DateTime.now(),
    );

    if (context != null) {
      developer.log('Context: $context', name: 'ErrorHandler');
    }

    // Show user-friendly message
    if (showToUser) {
      final message = customMessage ?? getFriendlyMessage(error);
      showError(message);
    }
  }

  /// Handle async operations with automatic error handling
  static Future<T?> handleAsync<T>(
    Future<T> Function() operation, {
    String? errorContext,
    String? customErrorMessage,
    bool showErrorToUser = true,
    Function(T)? onSuccess,
  }) async {
    try {
      final result = await operation();
      if (onSuccess != null) {
        onSuccess(result);
      }
      return result;
    } catch (error, stackTrace) {
      handle(
        error,
        stackTrace: stackTrace,
        context: errorContext,
        showToUser: showErrorToUser,
        customMessage: customErrorMessage,
      );
      return null;
    }
  }

  /// Validate internet connectivity with user feedback
  static Future<bool> checkConnectivity({bool showErrorMessage = true}) async {
    try {
      // You can replace this with actual connectivity check
      // For now, assuming online if no exception
      return true;
    } catch (e) {
      if (showErrorMessage) {
        ErrorHandler.showError('No internet connection available.');
      }
      return false;
    }
  }
}

/// Extension to make error handling easier on Future
extension ErrorHandlingExtension<T> on Future<T> {
  /// Automatically handle errors with user-friendly messages
  Future<T?> withErrorHandling({
    String? context,
    String? customMessage,
    bool showToUser = true,
  }) {
    return ErrorHandler.handleAsync(
      () => this,
      errorContext: context,
      customErrorMessage: customMessage,
      showErrorToUser: showToUser,
    );
  }
}
