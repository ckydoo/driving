// Create this new file to handle offline subscription caching

import 'package:driving/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          billing_period TEXT,
          last_synced_at TEXT NOT NULL,
          current_package_id INTEGER,
          current_package_name TEXT
        )
      ''');

      // Add billing_period column if it doesn't exist (for existing databases)
      try {
        await db.execute('''
          ALTER TABLE $_tableName ADD COLUMN billing_period TEXT
        ''');
        print('✅ Added billing_period column to existing table');
      } catch (e) {
        // Column already exists or table was just created - ignore
        print('ℹ️ billing_period column already exists or table just created');
      }

      print('✅ Subscription cache table initialized');
    } catch (e) {
      print('❌ Error creating subscription cache table: $e');
    }
  }

  static Future<void> saveSubscriptionData({
    required String status,
    required int trialDays,
    String? expiresAt,
    int? packageId,
    String? packageName,
    String? billingPeriod, // ✅ ADD
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('subscription_status', status);
      await prefs.setInt('trial_days', trialDays);
      await prefs.setString(
          'billing_period', billingPeriod ?? 'monthly'); // ✅ ADD

      if (expiresAt != null) {
        await prefs.setString('subscription_expires_at', expiresAt);
      }

      if (packageId != null) {
        await prefs.setInt('current_package_id', packageId);
      }

      if (packageName != null) {
        await prefs.setString('current_package_name', packageName);
      }

      await prefs.setString('synced_at', DateTime.now().toIso8601String());

      print('✅ Subscription data cached locally');
      print('   Status: $status');
      print('   Trial Days: $trialDays');
      print('   Billing Period: ${billingPeriod ?? "monthly"}'); // ✅ ADD
    } catch (e) {
      print('❌ Error caching subscription data: $e');
    }
  }

  static Future<Map<String, dynamic>?> getSubscriptionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final status = prefs.getString('subscription_status');
      if (status == null) return null;

      return {
        'subscription_status': status,
        'trial_days': prefs.getInt('trial_days') ?? 0,
        'billing_period':
            prefs.getString('billing_period') ?? 'monthly', // ✅ ADD
        'subscription_expires_at': prefs.getString('subscription_expires_at'),
        'current_package_id': prefs.getInt('current_package_id'),
        'current_package_name': prefs.getString('current_package_name'),
        'synced_at': prefs.getString('synced_at'),
      };
    } catch (e) {
      print('❌ Error loading cached subscription: $e');
      return null;
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
        'billing_period': cache['billing_period'] ?? 'monthly',
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
