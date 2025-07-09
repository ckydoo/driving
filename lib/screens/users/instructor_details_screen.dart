import 'dart:io';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/user.dart';
import 'package:driving/screens/schedule/daily_schedule_screen.dart';
import 'package:driving/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class InstructorDetailsScreen extends StatefulWidget {
  final int instructorId;

  const InstructorDetailsScreen({Key? key, required this.instructorId})
      : super(key: key);

  @override
  _InstructorDetailsScreenState createState() =>
      _InstructorDetailsScreenState();
}

class _InstructorDetailsScreenState extends State<InstructorDetailsScreen> {
  final UserController userController = Get.find<UserController>();
  final CourseController courseController = Get.find<CourseController>();
  final ScheduleController scheduleController = Get.find<ScheduleController>();
  final FleetController fleetController = Get.find<FleetController>();
  User? instructor;
  final TextEditingController _noteController = TextEditingController();
  List<Map<String, dynamic>> _instructorNotes = [];
  List<Map<String, dynamic>> _instructorAttachments = [];

  @override
  void initState() {
    super.initState();
    _loadInstructorData();
  }

  Future<void> _fetchInstructorNotes() async {
    final notes =
        await DatabaseHelper.instance.getNotesForStudent(widget.instructorId);
    setState(() {
      _instructorNotes = notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (instructor == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Instructor Details'),
          backgroundColor: Colors.blueAccent,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Instructor Details'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Instructor Information
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${instructor!.fname} ${instructor!.lname}',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    _buildInfoRow('DOB',
                        DateFormat.yMd().format(instructor!.date_of_birth)),
                    _buildInfoRow('ID Number', instructor!.idnumber),
                    _buildInfoRow('Gender', instructor!.gender),
                    _buildInfoRow('Email', instructor!.email),
                    _buildInfoRow('Phone', instructor!.phone),
                    _buildInfoRow('Address', instructor!.address),
                    _buildInfoRow('Registered on',
                        DateFormat.yMd().format(instructor!.created_at)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Assigned Vehicles
            _buildAssignedVehiclesSection(),
            SizedBox(height: 20),

            // Schedules
            _buildSchedulesSection(),
            SizedBox(height: 20),

            // Attachments
            _buildAttachmentsSection(),
            SizedBox(height: 20),

            // Notes
            _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedVehiclesSection() {
    final assignedVehicles = fleetController.fleet
        .where((vehicle) => vehicle.instructor == instructor!.id)
        .toList();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigned Vehicles',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            if (assignedVehicles.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'No vehicles assigned to this instructor.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            if (assignedVehicles.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assignedVehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = assignedVehicles[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        '${vehicle.make} ${vehicle.model}',
                        style: TextStyle(fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('License Plate: ${vehicle.carPlate}'),
                          Text('Model Year: ${vehicle.modelYear}'),
                        ],
                      ),
                      // Add onTap to view vehicle details if needed
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesSection() {
    final instructorSchedules = scheduleController.schedules
        .where((schedule) => schedule.instructorId == instructor!.id)
        .toList();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedules',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            if (instructorSchedules.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'No schedules found for this instructor.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            if (instructorSchedules.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: instructorSchedules.length,
                itemBuilder: (context, index) {
                  final schedule = instructorSchedules[index];

                  // Get student name from UserController
                  final student = userController.users.firstWhere(
                    (user) => user.id == schedule.studentId,
                    orElse: () => User(
                      fname: 'Unknown',
                      lname: 'Student',
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

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        '${DateFormat.yMd().add_jm().format(schedule.start)} - ${DateFormat.jm().format(schedule.end)}',
                        style: TextStyle(fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Course: ${schedule.classType}'),
                          Text('Student: ${student.fname} ${student.lname}'),
                          Text('Status: ${schedule.status}'),
                        ],
                      ),
                      onTap: () {
                        // Navigate to schedule details screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => DailyScheduleScreen(
                                selectedDate: schedule.start),
                          ),
                        );
                      },
                    ),
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attachments',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                FilePickerResult? result =
                    await FilePicker.platform.pickFiles();

                if (result != null && result.files.isNotEmpty) {
                  PlatformFile file = result.files.first;
                  String? attachmentPath = await _uploadFile(file);
                  if (attachmentPath != null) {
                    await _saveAttachmentToDatabase(
                        instructor!.id!, attachmentPath, file.name);
                    await _fetchInstructorAttachments();
                    setState(() {});
                  }
                } else {
                  // User canceled the picker
                }
              },
              child: Text('Upload Attachment'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 16),
            if (_instructorAttachments.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'No attachments found for this instructor.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            if (_instructorAttachments.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _instructorAttachments.length,
                itemBuilder: (context, index) {
                  final attachment = _instructorAttachments[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        attachment['name'],
                        style: TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        'Uploaded on: ${DateFormat.yMd().add_jm().format(DateTime.parse(attachment['created_at']))}',
                      ),
                      onTap: () => _launchURL(attachment['attachment']),
                      trailing: PopupMenuButton<String>(
                        onSelected: (String choice) {
                          if (choice == 'edit') {
                            _editAttachment(attachment);
                          } else if (choice == 'delete') {
                            _deleteAttachment(attachment['id']);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ];
                        },
                      ),
                    ),
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Write a note...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              controller: _noteController,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                String noteText = _noteController.text;
                if (noteText.isNotEmpty) {
                  await _saveNoteToDatabase(instructor!.id!, noteText);
                  _noteController.clear();
                  await _fetchInstructorNotes();
                }
              },
              child: Text('Add Note'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 16),
            if (_instructorNotes.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'No notes found for this instructor.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            if (_instructorNotes.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _instructorNotes.length,
                itemBuilder: (context, index) {
                  final note = _instructorNotes[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        note['note'],
                        style: TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        '${DateFormat.yMd().add_jm().format(DateTime.parse(note['created_at']))}',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteNote(note['id']),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNote(int noteId) async {
    await DatabaseHelper.instance.deleteNote(noteId);
    await _fetchInstructorNotes(); // Refresh notes
  }

  Future<void> _deleteAttachment(int attachmentId) async {
    await DatabaseHelper.instance.deleteAttachment(attachmentId);
    await _fetchInstructorAttachments(); // Refresh attachments
  }

  Future<void> _editAttachment(Map<String, dynamic> attachment) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;
        String? newAttachmentPath = await _uploadFile(file);
        if (newAttachmentPath != null) {
          await _updateAttachmentInDatabase(
              attachment['id'], newAttachmentPath, file.name);
          await _fetchInstructorAttachments();
          setState(() {});
        }
      } else {
        // User canceled the picker
      }
    });
  }

  Future<void> _updateAttachmentInDatabase(
      int attachmentId, String newAttachmentPath, String newFileName) async {
    await DatabaseHelper.instance.updateAttachment({
      'id': attachmentId,
      'attachment': newAttachmentPath,
      'name': newFileName,
    });
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
      int instructorId, String attachmentPath, String fileName) async {
    // Implement database insertion for attachments
    await DatabaseHelper.instance.insertAttachment({
      'uploaded_by': 1, //  Replace with the current user ID
      'attachment_for': instructorId,
      'name': fileName,
      'attachment': attachmentPath, // Store the local path
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _saveNoteToDatabase(int instructorId, String noteText) async {
    // Implement database insertion for notes
    await DatabaseHelper.instance.insertNote({
      'note_by': 1, //  Replace with the current user ID
      'note_for': instructorId,
      'note': noteText,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _loadInstructorData() async {
    await userController.fetchUsers();
    setState(() {
      instructor = userController.users
          .firstWhere((user) => user.id == widget.instructorId);
    });
    await fleetController.fetchFleet();
    await scheduleController.fetchSchedules();
    await _fetchInstructorNotes();
    await _fetchInstructorAttachments();
  }

  Future<void> _fetchInstructorAttachments() async {
    final attachments = await DatabaseHelper.instance
        .getAttachmentsForStudent(widget.instructorId);
    setState(() {
      _instructorAttachments = attachments;
    });
  }

  _launchURL(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      print("File path: ${file.path}");
      // For example, if it's an image:
      Navigator.of(context).push(
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
