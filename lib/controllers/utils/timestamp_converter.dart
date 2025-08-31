// lib/utils/timestamp_converter.dart - New utility file

import 'package:cloud_firestore/cloud_firestore.dart';

class TimestampConverter {
  /// ✅ FIX 2: Convert Firebase Timestamp to SQLite-compatible format
  static int convertTimestampToInt(dynamic timestamp) {
    if (timestamp == null) return DateTime.now().millisecondsSinceEpoch;

    // Handle Firebase Timestamp objects
    if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    }

    // Handle Timestamp string format: "Timestamp(seconds=1756480655, nanoseconds=0)"
    if (timestamp.toString().contains('Timestamp')) {
      final match = RegExp(r'seconds=(\d+)').firstMatch(timestamp.toString());
      if (match != null) {
        final seconds = int.parse(match.group(1)!);
        return seconds * 1000; // Convert to milliseconds
      }
    }

    // Handle integer timestamps
    if (timestamp is int) {
      return timestamp;
    }

    // Handle string dates
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp).millisecondsSinceEpoch;
      } catch (e) {
        print('⚠️ Invalid timestamp string: $timestamp');
        return DateTime.now().millisecondsSinceEpoch;
      }
    }

    // Fallback
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Convert data map with all timestamp fields
  static Map<String, dynamic> convertAllTimestamps(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // List of common timestamp fields in your app
    final timestampFields = [
      'last_modified',
      'created_at',
      'updated_at',
      'payment_date',
      'due_date',
      'date_of_birth',
      'start',
      'end',
      'last_login'
    ];

    for (String field in timestampFields) {
      if (result.containsKey(field)) {
        result[field] = convertTimestampToInt(result[field]);
      }
    }

    return result;
  }

  /// Convert boolean values to integers for SQLite
  static Map<String, dynamic> convertBooleans(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    result.forEach((key, value) {
      if (value is bool) {
        result[key] = value ? 1 : 0;
      }
    });

    return result;
  }

  /// Complete data conversion for SQLite storage
  static Map<String, dynamic> prepareForSQLite(Map<String, dynamic> data) {
    var result = convertAllTimestamps(data);
    result = convertBooleans(result);

    // Remove null values that might cause issues
    result.removeWhere((key, value) => value == null);

    return result;
  }
}
