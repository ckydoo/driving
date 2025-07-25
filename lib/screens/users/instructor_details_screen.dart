import 'dart:io';
import 'package:driving/controllers/course_controller.dart';
import 'package:driving/controllers/fleet_controller.dart';
import 'package:driving/controllers/schedule_controller.dart';
import 'package:driving/controllers/user_controller.dart';
import 'package:driving/models/user.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use post frame callback to avoid build phase issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstructorData();
    });
  }

  Future<void> _fetchInstructorNotes() async {
    final notes =
        await DatabaseHelper.instance.getNotesForStudent(widget.instructorId);
    setState(() {
      _instructorNotes = notes;
    });
  }

  Future<void> _fetchInstructorAttachments() async {
    final attachments = await DatabaseHelper.instance
        .getAttachmentsForStudent(widget.instructorId);
    setState(() {
      _instructorAttachments = attachments;
    });
  }

  Future<void> _loadInstructorData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if we already have the instructor data
      User? existingInstructor = userController.users
          .firstWhereOrNull((user) => user.id == widget.instructorId);

      // Only fetch users if we don't have the instructor data or users list is empty
      if (existingInstructor == null || userController.users.isEmpty) {
        await userController.fetchUsers();
      }

      // Load other data
      await Future.wait([
        fleetController.fetchFleet(),
        scheduleController.fetchSchedules(),
        _fetchInstructorNotes(),
        _fetchInstructorAttachments(),
      ]);

      // Get the instructor after all data is loaded
      setState(() {
        instructor = userController.users
            .firstWhereOrNull((user) => user.id == widget.instructorId);
        _isLoading = false;
      });

      if (instructor == null) {
        Get.snackbar(
          'Error',
          'Instructor not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load instructor data: ${e.toString()}',
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
          'Instructor Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : instructor == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Instructor not found',
                        style: TextStyle(fontSize: 18, color: Colors.red),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInstructorInfoCard(),
                      SizedBox(height: 16),
                      _buildVehicleCard(),
                      SizedBox(height: 16),
                      _buildSchedulesCard(),
                      SizedBox(height: 16),
                      _buildNotesCard(),
                      SizedBox(height: 16),
                      _buildAttachmentsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInstructorInfoCard() {
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
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    '${instructor!.fname[0]}${instructor!.lname[0]}'
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${instructor!.fname} ${instructor!.lname}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        'ID: ${instructor!.idnumber}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: instructor!.status.toLowerCase() == 'active'
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          instructor!.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: instructor!.status.toLowerCase() == 'active'
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
            _buildInfoRow('Email', instructor!.email, Icons.email),
            _buildInfoRow('Phone', instructor!.phone, Icons.phone),
            _buildInfoRow('Address', instructor!.address, Icons.location_on),
            _buildInfoRow(
                'Date of Birth',
                DateFormat('yyyy-MM-dd').format(instructor!.date_of_birth),
                Icons.calendar_today),
            _buildInfoRow('Gender', instructor!.gender, Icons.person),
            _buildInfoRow(
                'Joined',
                DateFormat('yyyy-MM-dd').format(instructor!.created_at),
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

  Widget _buildVehicleCard() {
    final assignedVehicle = fleetController.fleet.firstWhereOrNull(
        (vehicle) => vehicle.instructor == widget.instructorId);

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
                Icon(Icons.directions_car, color: Colors.green.shade800),
                SizedBox(width: 8),
                Text(
                  'Assigned Vehicle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            Divider(height: 16),
            assignedVehicle == null
                ? Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade800),
                        SizedBox(width: 8),
                        Text(
                          'No vehicle assigned',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${assignedVehicle.make} ${assignedVehicle.model}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Plate: ${assignedVehicle.carPlate}',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                        Text(
                          'Year: ${assignedVehicle.modelYear}',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesCard() {
    final instructorSchedules = scheduleController.schedules
        .where((schedule) => schedule.instructorId == widget.instructorId)
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
                Icon(Icons.schedule, color: Colors.green.shade800),
                SizedBox(width: 8),
                Text(
                  'Schedule (${instructorSchedules.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                Spacer(),
                ElevatedButton.icon(
                  icon: Icon(Icons.add, size: 16),
                  label: Text('Add Lesson'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Navigate to add schedule
                  },
                ),
              ],
            ),
            Divider(height: 16),
            instructorSchedules.isEmpty
                ? Text(
                    'No scheduled lessons',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: instructorSchedules.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final schedule = instructorSchedules[index];
                      final student = userController.users.firstWhereOrNull(
                        (user) => user.id == schedule.studentId,
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
                                'Student: ${student?.fname ?? 'Unknown'} ${student?.lname ?? 'Student'}'),
                            Text('Status: ${schedule.status}'),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey.shade600),
                        onTap: () {
                          // Navigator.of(context).push(
                          //   MaterialPageRoute(
                          //     builder: (context) => DailyScheduleScreen(
                          //       selectedDate: schedule.start,
                          //     ),
                          //   ),
                          // );
                        },
                      );
                    },
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
                Icon(Icons.note, color: Colors.green.shade800),
                SizedBox(width: 8),
                Text(
                  'Notes (${_instructorNotes.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
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
            _instructorNotes.isEmpty
                ? Text(
                    'No notes available',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _instructorNotes.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final note = _instructorNotes[index];
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
                Icon(Icons.attach_file, color: Colors.green.shade800),
                SizedBox(width: 8),
                Text(
                  'Attachments (${_instructorAttachments.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                Spacer(),
                ElevatedButton.icon(
                  icon: Icon(Icons.upload_file, size: 16),
                  label: Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _uploadFile,
                ),
              ],
            ),
            Divider(height: 16),
            _instructorAttachments.isEmpty
                ? Text(
                    'No attachments',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _instructorAttachments.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final attachment = _instructorAttachments[index];
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
      await _saveNoteToDatabase(
          widget.instructorId, _noteController.text.trim());
      _noteController.clear();
      await _fetchInstructorNotes();
    }
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      PlatformFile file = result.files.first;
      String? filePath = await _saveFileLocally(file);
      if (filePath != null) {
        await _saveAttachmentToDatabase(
            widget.instructorId, filePath, file.name);
        await _fetchInstructorAttachments();
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
      int instructorId, String attachmentPath, String fileName) async {
    await DatabaseHelper.instance.insertAttachment({
      'uploaded_by': 1,
      'attachment_for': instructorId,
      'name': fileName,
      'attachment': attachmentPath,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _saveNoteToDatabase(int instructorId, String noteText) async {
    await DatabaseHelper.instance.insertNote({
      'note_by': 1,
      'note_for': instructorId,
      'note': noteText,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _deleteAttachment(int attachmentId) async {
    await DatabaseHelper.instance.deleteAttachment(attachmentId);
    await _fetchInstructorAttachments();
  }

  Future<void> _deleteNote(int noteId) async {
    await DatabaseHelper.instance.deleteNote(noteId);
    await _fetchInstructorNotes();
  }

  void _viewAttachment(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
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
      Get.snackbar(
        'Error',
        'File does not exist',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
