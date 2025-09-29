// lib/services/subscription_cache.dart
// Create this new file to handle offline subscription caching

import 'package:driving/services/database_helper.dart';

class SubscriptionCache {
  static const String _tableName = 'subscription_cache';

  /// Initialize subscription cache table
  static Future<void> initializeTable() async {
    try {
      final db = await DatabaseHelper.instance.database;

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          id INTEGER PRIMARY KEY,
          subscription_status TEXT NOT NULL,
          remaining_trial_days INTEGER NOT NULL,
          subscription_expires_at TEXT,
          last_synced_at TEXT NOT NULL,
          current_package_id INTEGER,
          current_package_name TEXT
        )
      ''');

      print('✅ Subscription cache table initialized');
    } catch (e) {
      print('❌ Error creating subscription cache table: $e');
    }
  }

  /// Save subscription data to local cache
  static Future<void> saveSubscriptionData({
    required String status,
    required int trialDays,
    String? expiresAt,
    int? packageId,
    String? packageName,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Delete old cache (we only keep one record)
      await db.delete(_tableName);

      // Insert new cache
      await db.insert(_tableName, {
        'subscription_status': status,
        'remaining_trial_days': trialDays,
        'subscription_expires_at': expiresAt,
        'last_synced_at': DateTime.now().toIso8601String(),
        'current_package_id': packageId,
        'current_package_name': packageName,
      });

      print('✅ Subscription data cached locally');
      print('   Status: $status');
      print('   Trial Days: $trialDays');
    } catch (e) {
      print('❌ Error caching subscription data: $e');
    }
  }

  /// Get cached subscription data (for offline use)
  static Future<Map<String, dynamic>?> getCachedSubscriptionData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final results = await db.query(_tableName, limit: 1);

      if (results.isEmpty) {
        print('⚠️ No cached subscription data found');
        return null;
      }

      final cache = results.first;
      final lastSynced = DateTime.parse(cache['last_synced_at'] as String);
      final daysSinceSync = DateTime.now().difference(lastSynced).inDays;

      print('📦 Retrieved cached subscription data');
      print('   Status: ${cache['subscription_status']}');
      print('   Trial Days: ${cache['remaining_trial_days']}');
      print('   Last Synced: $daysSinceSync days ago');

      // Get cached status
      String cachedStatus = cache['subscription_status'] as String;
      int cachedTrialDays = cache['remaining_trial_days'] as int;

      // CRITICAL: Check if subscription has expired since last sync
      if (cache['subscription_expires_at'] != null) {
        final expiresAt =
            DateTime.parse(cache['subscription_expires_at'] as String);
        final now = DateTime.now();

        if (now.isAfter(expiresAt)) {
          print(
              '⚠️ Subscription expired at $expiresAt (${now.difference(expiresAt).inDays} days ago)');
          cachedStatus = 'expired';
          cachedTrialDays = 0;
        } else {
          print('✅ Subscription valid until $expiresAt');
        }
      }

      // Adjust trial days based on time passed (only for trial status)
      int adjustedTrialDays = cachedTrialDays;
      if (cachedStatus == 'trial') {
        adjustedTrialDays = cachedTrialDays - daysSinceSync;
        if (adjustedTrialDays < 0) {
          adjustedTrialDays = 0;
          cachedStatus = 'expired'; // Trial expired
        }
        print(
            '   Adjusted trial days: $adjustedTrialDays (was $cachedTrialDays)');
      }

      return {
        'subscription_status': cachedStatus,
        'remaining_trial_days': adjustedTrialDays,
        'subscription_expires_at': cache['subscription_expires_at'],
        'last_synced_at': cache['last_synced_at'],
        'current_package': cache['current_package_id'] != null
            ? {
                'id': cache['current_package_id'],
                'name': cache['current_package_name'],
              }
            : null,
        'is_offline_cache': true,
        'days_since_sync': daysSinceSync,
      };
    } catch (e) {
      print('❌ Error getting cached subscription data: $e');
      return null;
    }
  }

  /// Check if cache is still valid (not too old)
  static Future<bool> isCacheValid({int maxDaysOld = 7}) async {
    try {
      final cache = await getCachedSubscriptionData();

      if (cache == null) return false;

      final daysSinceSync = cache['days_since_sync'] as int;

      return daysSinceSync <= maxDaysOld;
    } catch (e) {
      return false;
    }
  }

  /// Clear cached subscription data
  static Future<void> clearCache() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(_tableName);
      print('✅ Subscription cache cleared');
    } catch (e) {
      print('❌ Error clearing subscription cache: $e');
    }
  }
}
