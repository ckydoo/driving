class SyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? details;

  SyncResult(this.success, this.message, {this.details});

  @override
  String toString() {
    return 'SyncResult(success: $success, message: $message, details: $details)';
  }

  // Helper methods
  bool get isSuccess => success;
  bool get isFailure => !success;

  // Get specific detail values safely
  T? getDetail<T>(String key) {
    return details?[key] as T?;
  }

  int get uploadedCount => getDetail<int>('uploaded') ?? 0;
  int get downloadedCount => getDetail<int>('downloaded') ?? 0;
}
