import 'package:flutter/material.dart';
import 'package:driving/models/user.dart';

class EligibilityDialog extends StatelessWidget {
  final List<Map<String, dynamic>> eligible;
  final List<Map<String, dynamic>> ineligible;

  const EligibilityDialog({
    super.key,
    required this.eligible,
    required this.ineligible,
  });

  static Future<bool> show(
    BuildContext context,
    List<Map<String, dynamic>> eligible,
    List<Map<String, dynamic>> ineligible,
  ) async {
    if (eligible.isEmpty && ineligible.isEmpty) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return EligibilityDialog(
              eligible: eligible,
              ineligible: ineligible,
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.school, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Graduation Eligibility Check')),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eligible.isNotEmpty) ...[
                  Text(
                    '✅ Eligible Students (${eligible.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...eligible.map((result) {
                    final student = result['student'] as User;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${student.fname} ${student.lname} (${result['completedLessons']} lessons, ${result['completedCourses'].length} courses)',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                if (eligible.isNotEmpty && ineligible.isNotEmpty)
                  SizedBox(height: 16),
                if (ineligible.isNotEmpty) ...[
                  Text(
                    '❌ Ineligible Students (${ineligible.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...ineligible.map((result) {
                    final student = result['student'] as User;
                    final missing = result['missingRequirements'] as List<String>;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${student.fname} ${student.lname}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsets.only(left: 24),
                            child: Text(
                              'Missing: ${missing.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                if (eligible.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.green[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only eligible students will be graduated. Ineligible students will be skipped.',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No students meet graduation requirements. Please ensure students complete their training before graduation.',
                            style: TextStyle(
                              color: Colors.red[800],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          if (eligible.isNotEmpty)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                  'Graduate ${eligible.length} Student${eligible.length > 1 ? 's' : ''}'),
            ),
        ],
      ),
    );
  }
}
