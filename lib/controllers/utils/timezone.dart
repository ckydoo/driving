import 'package:cloud_firestore/cloud_firestore.dart';

class SafeTimestamp {
  /// Get current UTC timestamp in milliseconds
  static int now() {
    return DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  /// Convert any DateTime to UTC milliseconds
  static int fromDateTime(DateTime dateTime) {
    return dateTime.toUtc().millisecondsSinceEpoch;
  }

  /// Convert milliseconds to UTC DateTime
  static DateTime toDateTime(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  /// Convert Firestore Timestamp to UTC milliseconds
  static int fromFirestoreTimestamp(Timestamp timestamp) {
    return timestamp.toDate().toUtc().millisecondsSinceEpoch;
  }

  /// Get UTC timestamp for logging/debugging
  static String nowFormatted() {
    return DateTime.now().toUtc().toIso8601String();
  }

  /// Compare two timestamps safely
  static int compare(int timestamp1, int timestamp2) {
    return timestamp1.compareTo(timestamp2);
  }
}
