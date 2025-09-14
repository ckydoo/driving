// lib/widgets/seed_data_widget.dart
import 'package:driving/controllers/utils/seed_data_runner.dart';
import 'package:flutter/material.dart';
import 'package:driving/services/test_data_seeder.dart';

class SeedDataWidget extends StatefulWidget {
  const SeedDataWidget({Key? key}) : super(key: key);

  @override
  State<SeedDataWidget> createState() => _SeedDataWidgetState();
}

class _SeedDataWidgetState extends State<SeedDataWidget> {
  Map<String, bool> _existingData = {};
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkExistingData();
  }

  Future<void> _checkExistingData() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final data = await TestDataSeeder.instance.checkTestDataExists();
      setState(() {
        _existingData = data;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _isChecking = false;
      });
      print('Error checking existing data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Data Seed Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: BackButton(),
      ),
      body: Card(
        elevation: 4,
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.invert_colors_on_sharp,
                      color: Colors.blue, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Test Data Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Status indicators
              if (_isChecking) ...[
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Checking existing data...'),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  'Current Status:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),

                // Status rows
                _buildStatusRow(
                  'Test Users',
                  _existingData['users'] ?? false,
                  'Admin, Instructor, and Student accounts',
                ),
                _buildStatusRow(
                  'Test Courses',
                  _existingData['courses'] ?? false,
                  'Basic to Advanced driving courses',
                ),
                _buildStatusRow(
                  'Test Fleet',
                  _existingData['fleet'] ?? false,
                  'Sample vehicles for training',
                ),

                SizedBox(height: 20),

                // Action buttons
                Text(
                  'Actions:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 12),

                // Create test data button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        SeedDataRunner.runSeedDataWithConfirmation(context),
                    icon: Icon(Icons.add_circle_outline),
                    label: Text('Create Complete Test Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                SizedBox(height: 8),

                // Quick actions row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => SeedDataRunner.seedUsersOnly(),
                        icon: Icon(Icons.person_add, size: 18),
                        label: Text('Users Only'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _refreshStatus(),
                        icon: Icon(Icons.refresh, size: 18),
                        label: Text('Refresh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // Danger zone
                Container(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => SeedDataRunner.clearTestData(),
                    icon: Icon(Icons.delete_forever, size: 18),
                    label: Text('Clear All Test Data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Help text
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Test Login Credentials',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      _buildCredentialText(
                          'Admin', 'admin@test.com', 'admin123'),
                      _buildCredentialText('Instructor', 'instructor1@test.com',
                          'instructor123'),
                      _buildCredentialText(
                          'Student', 'student1@test.com', 'student123'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String title, bool exists, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: exists ? Colors.green : Colors.grey.shade400,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color:
                        exists ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            exists ? 'EXISTS' : 'NOT FOUND',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: exists ? Colors.green : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialText(String role, String email, String password) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Text(
        '$role: $email | $password',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  Future<void> _refreshStatus() async {
    await _checkExistingData();
  }
}
