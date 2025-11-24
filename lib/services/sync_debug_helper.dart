import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncDebugHelper {
  static const String _debugLogKey = 'sync_debug_log';
  static const String _lastErrorKey = 'sync_last_error';

  /// Log sync activity with timestamp
  static Future<void> logActivity(String activity,
      {Map<String, dynamic>? details}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();

      final logEntry = {
        'timestamp': timestamp,
        'activity': activity,
        'details': details ?? {},
      };

      // Get existing logs
      final existingLogsJson = prefs.getString(_debugLogKey) ?? '[]';
      final existingLogs =
          List<Map<String, dynamic>>.from(json.decode(existingLogsJson));

      // Add new log entry
      existingLogs.add(logEntry);

      // Keep only last 100 entries
      if (existingLogs.length > 100) {
        existingLogs.removeRange(0, existingLogs.length - 100);
      }

      // Save updated logs
      await prefs.setString(_debugLogKey, json.encode(existingLogs));

      print('🐛 DEBUG: [$timestamp] $activity');
      if (details != null && details.isNotEmpty) {
        print('🐛 Details: ${json.encode(details)}');
      }
    } catch (e) {
      print('❌ Failed to log sync activity: $e');
    }
  }

  /// Log sync error with context
  static Future<void> logError(
    String error, {
    String? context,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();

      final errorEntry = {
        'timestamp': timestamp,
        'error': error,
        'context': context,
        'additional_info': additionalInfo ?? {},
      };

      await prefs.setString(_lastErrorKey, json.encode(errorEntry));
      await logActivity('ERROR: $error', details: errorEntry);

      print('🚨 SYNC ERROR: [$timestamp] $error');
      if (context != null) {
        print('🚨 Context: $context');
      }
    } catch (e) {
      print('❌ Failed to log sync error: $e');
    }
  }

  /// Get sync debug logs
  static Future<List<Map<String, dynamic>>> getDebugLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_debugLogKey) ?? '[]';
      return List<Map<String, dynamic>>.from(json.decode(logsJson));
    } catch (e) {
      print('❌ Failed to get debug logs: $e');
      return [];
    }
  }

  /// Get last sync error
  static Future<Map<String, dynamic>?> getLastError() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final errorJson = prefs.getString(_lastErrorKey);
      if (errorJson != null) {
        return Map<String, dynamic>.from(json.decode(errorJson));
      }
      return null;
    } catch (e) {
      print('❌ Failed to get last error: $e');
      return null;
    }
  }

  /// Check pending changes status
  static Future<Map<String, dynamic>> checkPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const String _pendingChangesKey =
          'sync_pending_changes'; // Define the constant locally
      final pendingChangesJson = prefs.getString(_pendingChangesKey);

      if (pendingChangesJson == null || pendingChangesJson.isEmpty) {
        return {
          'has_pending': false,
          'count': 0,
          'details': 'No pending changes',
        };
      }

      final pendingChanges = json.decode(pendingChangesJson);

      if (pendingChanges.isEmpty) {
        return {
          'has_pending': false,
          'count': 0,
          'details': 'Pending changes empty',
        };
      }

      int totalItems = 0;
      final breakdown = <String, int>{};

      for (final entry in pendingChanges.entries) {
        final dataType = entry.key;
        final items = entry.value as List<dynamic>;
        breakdown[dataType] = items.length;
        totalItems += items.length;
      }

      return {
        'has_pending': true,
        'count': totalItems,
        'breakdown': breakdown,
        'details':
            'Found pending changes across ${breakdown.keys.length} data types',
      };
    } catch (e) {
      return {
        'has_pending': false,
        'count': 0,
        'error': e.toString(),
        'details': 'Error checking pending changes',
      };
    }
  }

  /// Generate diagnostic report
  static Future<Map<String, dynamic>> generateDiagnosticReport() async {
    final lastError = await getLastError();
    final pendingStatus = await checkPendingChanges();
    final recentLogs = await getDebugLogs();

    // Get last 10 logs
    final recentActivity = recentLogs.length > 10
        ? recentLogs.sublist(recentLogs.length - 10)
        : recentLogs;

    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_sync_timestamp');

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'last_sync': lastSync ?? 'Never',
      'last_error': lastError,
      'pending_changes': pendingStatus,
      'recent_activity': recentActivity,
      'total_logs': recentLogs.length,
    };
  }

  /// Clear debug data
  static Future<void> clearDebugData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_debugLogKey);
      await prefs.remove(_lastErrorKey);
      print('🧹 Debug data cleared');
    } catch (e) {
      print('❌ Failed to clear debug data: $e');
    }
  }

  /// Print diagnostic report to console
  static Future<void> printDiagnosticReport() async {
    print('\n' + '=' * 50);
    print('🔍 SYNC DIAGNOSTIC REPORT');
    print('=' * 50);

    final report = await generateDiagnosticReport();

    print('📅 Generated: ${report['timestamp']}');
    print('🔄 Last Sync: ${report['last_sync']}');
    print('📊 Pending Changes: ${report['pending_changes']['details']}');

    if (report['pending_changes']['has_pending']) {
      final breakdown =
          report['pending_changes']['breakdown'] as Map<String, dynamic>;
      for (final entry in breakdown.entries) {
        print('   - ${entry.key}: ${entry.value} items');
      }
    }

    if (report['last_error'] != null) {
      final lastError = report['last_error'] as Map<String, dynamic>;
      print('🚨 Last Error: ${lastError['error']}');
      print('   Context: ${lastError['context'] ?? 'N/A'}');
      print('   Time: ${lastError['timestamp']}');
    }

    print('📝 Recent Activity (${report['recent_activity'].length} items):');
    final recentActivity = report['recent_activity'] as List<dynamic>;
    for (final activity in recentActivity.reversed.take(5)) {
      print('   ${activity['timestamp']}: ${activity['activity']}');
    }

    print('=' * 50 + '\n');
  }
}
