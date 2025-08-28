import 'package:driving/services/database_migration.dart';
import 'package:driving/services/receipt_service.dart';
import 'package:flutter/material.dart';

class CloudMigrationDashboard extends StatefulWidget {
  const CloudMigrationDashboard({Key? key}) : super(key: key);

  @override
  State<CloudMigrationDashboard> createState() =>
      _CloudMigrationDashboardState();
}

class _CloudMigrationDashboardState extends State<CloudMigrationDashboard> {
  Map<String, dynamic>? _migrationStatus;
  bool _isLoading = false;
  bool _isMigrating = false;

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  Future<void> _checkMigrationStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await CloudReceiptMigrationService.checkMigrationStatus();
      setState(() => _migrationStatus = status);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check migration status: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performMigration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Migrate to Cloud Storage'),
        content: const Text(
            'This will migrate all local receipts to cloud storage. '
            'This process may take several minutes depending on the number of receipts. '
            'Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Migrate'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isMigrating = true);
      try {
        final result =
            await CloudReceiptMigrationService.performAutoMigration();
        await _checkMigrationStatus(); // Refresh status

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Migration completed! ${result['success_count']}/${result['total_processed']} receipts migrated successfully.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isMigrating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Receipt Migration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkMigrationStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _migrationStatus == null
              ? const Center(child: Text('No migration data available'))
              : _buildMigrationDashboard(),
    );
  }

  Widget _buildMigrationDashboard() {
    final status = _migrationStatus!;
    final migrationComplete = status['migration_complete'] as bool;
    final migrationPercentage = status['migration_percentage'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Migration Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Migration Status',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              migrationComplete ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          migrationComplete ? 'Complete' : 'In Progress',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: migrationPercentage / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      migrationComplete ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$migrationPercentage% Migrated'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Statistics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Receipts',
                  '${status['total_receipts']}',
                  Icons.receipt,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Cloud Receipts',
                  '${status['cloud_receipts']}',
                  Icons.cloud_done,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Local Receipts',
                  '${status['local_receipts']}',
                  Icons.storage,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Firebase Storage',
                  ReceiptService.isStorageAvailable
                      ? 'Available'
                      : 'Unavailable',
                  Icons.cloud,
                  ReceiptService.isStorageAvailable ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Benefits Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloud Storage Benefits',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildBenefit('✅ Access receipts from any device'),
                  _buildBenefit('🔄 Automatic sync across devices'),
                  _buildBenefit('☁️ Secure cloud backup'),
                  _buildBenefit('💾 Reduced local storage usage'),
                  _buildBenefit('🚀 Faster app performance'),
                  _buildBenefit('📱 No more "receipt not found" errors'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          if (!migrationComplete) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isMigrating ? null : _performMigration,
                icon: _isMigrating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isMigrating ? 'Migrating...' : 'Start Migration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'All receipts are already migrated to cloud storage!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Migration Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _checkMigrationStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Status'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCleanupDialog(),
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Cleanup Local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showCleanupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cleanup Local Files'),
        content: const Text(
            'This will delete all local receipt files that have been successfully migrated to cloud storage. '
            'This action cannot be undone. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result =
                    await CloudReceiptMigrationService.cleanupLocalReceipts();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Cleanup completed! Deleted ${result['files_deleted']} files, '
                        'saved ${result['space_saved_mb']} MB of storage.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cleanup failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Cleanup'),
          ),
        ],
      ),
    );
  }
}
