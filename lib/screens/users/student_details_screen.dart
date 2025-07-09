import 'dart:io';
import 'package:driving/controllers/billing_controller.dart';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/schedule/daily_schedule_screen.dart';
import 'package:driving/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class StudentDetailsScreen extends StatefulWidget {
  final int studentId;

  const StudentDetailsScreen({Key? key, required this.studentId})
      : super(key: key);

  @override
  _StudentDetailsScreenState createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final BillingController billingController = Get.find<BillingController>();
  User? student;
  final TextEditingController _noteController = TextEditingController();
  List<Map<String, dynamic>> _studentNotes = [];
  List<Map<String, dynamic>> _studentAttachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _fetchStudentNotes() async {
    final notes =
        await DatabaseHelper.instance.getNotesForStudent(widget.studentId);
    setState(() {
      _studentNotes = notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Information
                  _buildStudentInfoCard(),
                  SizedBox(height: 16),
                  // Invoices
                  _buildInvoicesSection(),
                  SizedBox(height: 16),
                  // Schedules
                  _buildSchedulesSection(),
                  SizedBox(height: 16),
                  // Attachments
                  _buildAttachmentsSection(),
                  SizedBox(height: 16),
                  // Notes
                  _buildNotesSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            Divider(color: Colors.grey.shade300),
            SizedBox(height: 8),
            _buildInfoRow('Name', '${student!.fname} ${student!.lname}'),
            _buildInfoRow(
                'DOB', DateFormat.yMd().format(student!.date_of_birth)),
            _buildInfoRow('ID Number', student!.idnumber),
            _buildInfoRow('Gender', student!.gender),
            _buildInfoRow('Email', student!.email),
            _buildInfoRow('Phone', student!.phone),
            _buildInfoRow('Address', student!.address),
            _buildInfoRow(
                'Registered on', DateFormat.yMd().format(student!.created_at)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesSection() {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == student!.id)
        .toList();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            Divider(color: Colors.grey.shade300),
            SizedBox(height: 8),
            if (studentInvoices.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'No invoices found for this student.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            if (studentInvoices.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: studentInvoices.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade300),
                itemBuilder: (context, index) {
                  final invoice = studentInvoices[index];
                  return ListTile(
                    title: Text('Invoice #${invoice.id}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total: ${invoice.formattedTotal}'),
                        Text(
                            'Due Date: ${DateFormat.yMd().format(invoice.dueDate)}'),
                        Text('Status: ${invoice.status}'),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey.shade600),
                    onTap: () {
                      // Navigate to invoice details screen
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesSection() {
    final studentSchedules = scheduleController.schedules
        .where((schedule) => schedule.studentId == student!.id)
        .toList();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            Divider(color: Colors.grey.shade300),
            SizedBox(height: 8),
            if (studentSchedules.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'No schedules found for this student.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            if (studentSchedules.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: studentSchedules.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade300),
                itemBuilder: (context, index) {
                  final schedule = studentSchedules[index];
                  final instructor = userController.users.firstWhere(
                    (user) => user.id == schedule.instructorId,
                    orElse: () => User(
                      fname: 'Unknown',
                      lname: 'Instructor',
                      id: 0,
                      email: '',
                      password: '',
                      gender: '',
                      phone: '',
                      address: '',
                      date_of_birth: DateTime.now(),
                      role: '',
                      status: '',
                      idnumber: '',
                      created_at: DateTime.now(),
                    ),
                  );
                  return ListTile(
                    title: Text(
                      '${DateFormat.yMd().add_jm().format(schedule.start)} - ${DateFormat.jm().format(schedule.end)}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Course: ${schedule.classType}'),
                        Text(
                            'Instructor: ${instructor.fname} ${instructor.lname}'),
                        Text('Status: ${schedule.status}'),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey.shade600),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              DailyScheduleScreen(selectedDate: schedule.start),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attachments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            Divider(color: Colors.grey.shade300),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                FilePickerResult? result =
                    await FilePicker.platform.pickFiles();
                if (result != null && result.files.isNotEmpty) {
                  PlatformFile file = result.files.first;
                  String? attachmentPath = await _uploadFile(file);
                  if (attachmentPath != null) {
                    await _saveAttachmentToDatabase(
                        student!.id!, attachmentPath, file.name);
                    await _fetchStudentAttachments();
                    setState(() {});
                  }
                }
              },
              icon: Icon(Icons.upload),
              label: Text('Upload Attachment'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 16),
            if (_studentAttachments.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'No attachments found for this student.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            if (_studentAttachments.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _studentAttachments.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade300),
                itemBuilder: (context, index) {
                  final attachment = _studentAttachments[index];
                  return ListTile(
                    title: Text(attachment['name']),
                    subtitle: Text(
                      'Uploaded on: ${DateFormat.yMd().add_jm().format(DateTime.parse(attachment['created_at']))}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteAttachment(attachment['id']),
                    ),
                    onTap: () => _launchURL(attachment['attachment']),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            Divider(color: Colors.grey.shade300),
            SizedBox(height: 8),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Write a note...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              controller: _noteController,
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                String noteText = _noteController.text;
                if (noteText.isNotEmpty) {
                  await _saveNoteToDatabase(student!.id!, noteText);
                  _noteController.clear();
                  await _fetchStudentNotes();
                }
              },
              icon: Icon(Icons.add),
              label: Text('Add Note'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 16),
            if (_studentNotes.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'No notes found for this student.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            if (_studentNotes.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _studentNotes.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade300),
                itemBuilder: (context, index) {
                  final note = _studentNotes[index];
                  return ListTile(
                    title: Text(note['note']),
                    subtitle: Text(
                      '${DateFormat.yMd().add_jm().format(DateTime.parse(note['created_at']))}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteNote(note['id']),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
    });
    await userController.fetchUsers();
    await courseController.fetchCourses();
    await scheduleController.fetchSchedules();
    await billingController.fetchBillingData();
    await _fetchStudentNotes();
    await _fetchStudentAttachments();
    setState(() {
      student = userController.users
          .firstWhere((user) => user.id == widget.studentId);
      _isLoading = false;
    });
  }

  Future<void> _deleteAttachment(int attachmentId) async {
    await DatabaseHelper.instance.deleteAttachment(attachmentId);

    await _fetchStudentAttachments(); // Refresh attachments
  }

  Future<void> _deleteNote(int noteId) async {
    await DatabaseHelper.instance.deleteNote(noteId);
    await _fetchStudentNotes(); // Refresh notes
  }

  Future<String?> _uploadFile(PlatformFile file) async {
    try {
      // 1. Get the application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = appDir.path;

      // 2. Create a new file in the local directory
      final newFile = File('$localPath/${file.name}');

      // 3. Write the file content
      await newFile.writeAsBytes(file.bytes!); // Use file.bytes!

      // 4. Return the local file path
      return newFile.path;
    } catch (e) {
      print('Error saving file: $e');
      return null;
    }
  }

  Future<void> _saveAttachmentToDatabase(
      int studentId, String attachmentPath, String fileName) async {
    // Implement database insertion for attachments
    await DatabaseHelper.instance.insertAttachment({
      'uploaded_by': 1, //  Replace with the current user ID
      'attachment_for': studentId,
      'name': fileName,
      'attachment': attachmentPath, // Store the local path
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _saveNoteToDatabase(int studentId, String noteText) async {
    // Implement database insertion for notes
    await DatabaseHelper.instance.insertNote({
      'note_by': 1, //  Replace with the current user ID
      'note_for': studentId,
      'note': noteText,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _fetchStudentAttachments() async {
    final attachments = await DatabaseHelper.instance
        .getAttachmentsForStudent(widget.studentId);
    setState(() {
      _studentAttachments = attachments;
    });
  }

  _launchURL(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      print("File path: ${file.path}");
      // For example, if it's an image:
      Navigator.of(context as BuildContext).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text('View Attachment')),
            body: Center(
              child: Image.file(file),
            ),
          ),
        ),
      );
    } else {
      throw Exception('File does not exist at $filePath');
    }
  }
}
