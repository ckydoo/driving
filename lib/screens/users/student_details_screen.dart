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
    // Use post frame callback to avoid build phase issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentData();
    });
  }

  Future<void> _fetchStudentNotes() async {
    final notes =
        await DatabaseHelper.instance.getNotesForStudent(widget.studentId);
    setState(() {
      _studentNotes = notes;
    });
  }

  Future<void> _fetchStudentAttachments() async {
    final attachments = await DatabaseHelper.instance
        .getAttachmentsForStudent(widget.studentId);
    setState(() {
      _studentAttachments = attachments;
    });
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if we already have the student data
      User? existingStudent = userController.users
          .firstWhereOrNull((user) => user.id == widget.studentId);

      // Only fetch users if we don't have the student data or users list is empty
      if (existingStudent == null || userController.users.isEmpty) {
        await userController.fetchUsers();
      }

      // Load other data
      await Future.wait([
        courseController.fetchCourses(),
        scheduleController.fetchSchedules(),
        billingController.fetchBillingData(),
        _fetchStudentNotes(),
        _fetchStudentAttachments(),
      ]);

      // Get the student after all data is loaded
      setState(() {
        student = userController.users
            .firstWhereOrNull((user) => user.id == widget.studentId);
        _isLoading = false;
      });

      if (student == null) {
        Get.snackbar(
          'Error',
          'Student not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Navigator.of(context as BuildContext).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load student data: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
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
          : student == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Student not found',
                        style: TextStyle(fontSize: 18, color: Colors.red),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildStudentInfoCard(),
                      SizedBox(height: 16),
                      _buildSchedulesCard(),
                      SizedBox(height: 16),
                      _buildBillingCard(),
                      SizedBox(height: 16),
                      _buildNotesCard(),
                      SizedBox(height: 16),
                      _buildAttachmentsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    '${student!.fname[0]}${student!.lname[0]}'.toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student!.fname} ${student!.lname}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        'ID: ${student!.idnumber}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: student!.status.toLowerCase() == 'active'
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          student!.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: student!.status.toLowerCase() == 'active'
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            _buildInfoRow('Email', student!.email, Icons.email),
            _buildInfoRow('Phone', student!.phone, Icons.phone),
            _buildInfoRow('Address', student!.address, Icons.location_on),
            _buildInfoRow(
                'Date of Birth',
                DateFormat('yyyy-MM-dd').format(student!.date_of_birth),
                Icons.calendar_today),
            _buildInfoRow('Gender', student!.gender, Icons.person),
            _buildInfoRow(
                'Joined',
                DateFormat('yyyy-MM-dd').format(student!.created_at),
                Icons.date_range),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
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

  Widget _buildSchedulesCard() {
    final studentSchedules = scheduleController.schedules
        .where((schedule) => schedule.studentId == widget.studentId)
        .toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue.shade800),
                SizedBox(width: 8),
                Text(
                  'Schedule (${studentSchedules.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                Spacer(),
                ElevatedButton.icon(
                  icon: Icon(Icons.add, size: 16),
                  label: Text('Add Lesson'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Navigate to add schedule
                  },
                ),
              ],
            ),
            Divider(height: 16),
            studentSchedules.isEmpty
                ? Text(
                    'No scheduled lessons',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: studentSchedules.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final schedule = studentSchedules[index];
                      final instructor = userController.users.firstWhereOrNull(
                        (user) => user.id == schedule.instructorId,
                      );

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${DateFormat.yMd().add_jm().format(schedule.start)} - ${DateFormat.jm().format(schedule.end)}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Course: ${schedule.classType}'),
                            Text(
                                'Instructor: ${instructor?.fname ?? 'Unknown'} ${instructor?.lname ?? 'Instructor'}'),
                            Text('Status: ${schedule.status}'),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey.shade600),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => DailyScheduleScreen(
                                selectedDate: schedule.start,
                              ),
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

  Widget _buildBillingCard() {
    final studentInvoices = billingController.invoices
        .where((invoice) => invoice.studentId == widget.studentId)
        .toList();

    final totalBalance = studentInvoices.fold<double>(
        0.0, (sum, invoice) => sum + invoice.balance);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.blue.shade800),
                SizedBox(width: 8),
                Text(
                  'Billing Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Outstanding Balance:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${totalBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: totalBalance > 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Invoices: ${studentInvoices.length}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: Colors.blue.shade800),
                SizedBox(width: 8),
                Text(
                  'Notes (${_studentNotes.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            Divider(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add a note...',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _addNote,
                ),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),
            _studentNotes.isEmpty
                ? Text(
                    'No notes available',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _studentNotes.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final note = _studentNotes[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
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

  Widget _buildAttachmentsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, color: Colors.blue.shade800),
                SizedBox(width: 8),
                Text(
                  'Attachments (${_studentAttachments.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                Spacer(),
                ElevatedButton.icon(
                  icon: Icon(Icons.upload_file, size: 16),
                  label: Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _uploadFile,
                ),
              ],
            ),
            Divider(height: 16),
            _studentAttachments.isEmpty
                ? Text(
                    'No attachments',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _studentAttachments.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final attachment = _studentAttachments[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.file_present),
                        title: Text(attachment['name']),
                        subtitle: Text(
                          DateFormat.yMd()
                              .add_jm()
                              .format(DateTime.parse(attachment['created_at'])),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.visibility),
                              onPressed: () =>
                                  _viewAttachment(attachment['attachment']),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteAttachment(attachment['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _addNote() async {
    if (_noteController.text.trim().isNotEmpty) {
      await _saveNoteToDatabase(widget.studentId, _noteController.text.trim());
      _noteController.clear();
      await _fetchStudentNotes();
    }
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      PlatformFile file = result.files.first;
      String? filePath = await _saveFileLocally(file);
      if (filePath != null) {
        await _saveAttachmentToDatabase(widget.studentId, filePath, file.name);
        await _fetchStudentAttachments();
      }
    }
  }

  Future<String?> _saveFileLocally(PlatformFile file) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = appDir.path;
      final newFile = File('$localPath/${file.name}');
      await newFile.writeAsBytes(file.bytes!);
      return newFile.path;
    } catch (e) {
      print('Error saving file: $e');
      return null;
    }
  }

  Future<void> _saveAttachmentToDatabase(
      int studentId, String attachmentPath, String fileName) async {
    await DatabaseHelper.instance.insertAttachment({
      'uploaded_by': 1,
      'attachment_for': studentId,
      'name': fileName,
      'attachment': attachmentPath,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _saveNoteToDatabase(int studentId, String noteText) async {
    await DatabaseHelper.instance.insertNote({
      'note_by': 1,
      'note_for': studentId,
      'note': noteText,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _deleteAttachment(int attachmentId) async {
    await DatabaseHelper.instance.deleteAttachment(attachmentId);
    await _fetchStudentAttachments();
  }

  Future<void> _deleteNote(int noteId) async {
    await DatabaseHelper.instance.deleteNote(noteId);
    await _fetchStudentNotes();
  }

  void _viewAttachment(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
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
      Get.snackbar(
        'Error',
        'File does not exist',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
