// lib/widgets/loading_dialog.dart
// Reusable loading dialog component

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoadingDialog {
  /// Show a loading dialog with custom message
  static void show({
    String? message,
    bool barrierDismissible = false,
  }) {
    Get.dialog(
      _LoadingDialogWidget(message: message),
      barrierDismissible: barrierDismissible,
    );
  }

  /// Hide the currently showing loading dialog
  static void hide() {
    if (Get.isDialogOpen == true) {
      Get.back();
    }
  }

  /// Show loading with a future and auto-hide when complete
  static Future<T> showWithFuture<T>({
    required Future<T> future,
    String? message,
  }) async {
    show(message: message);
    try {
      final result = await future;
      hide();
      return result;
    } catch (e) {
      hide();
      rethrow;
    }
  }
}

class _LoadingDialogWidget extends StatelessWidget {
  final String? message;

  const _LoadingDialogWidget({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loading spinner
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),

            SizedBox(height: 20),

            // Loading message
            Text(
              message ?? 'Please wait...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),

            SizedBox(height: 12),

            // Subtitle
            Text(
              'This may take a moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced loading states widget for forms
class LoadingStateWidget extends StatelessWidget {
  final bool isLoading;
  final String loadingMessage;
  final String? errorMessage;
  final Widget child;
  final VoidCallback? onRetry;

  const LoadingStateWidget({
    Key? key,
    required this.isLoading,
    this.loadingMessage = 'Loading...',
    this.errorMessage,
    required this.child,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              loadingMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh),
                label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return child;
  }
}
