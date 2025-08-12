import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/billing_controller.dart';
import '../controllers/course_controller.dart';
import '../controllers/user_controller.dart';
import '../models/course.dart';
import '../models/user.dart';
import '../widgets/responsive_text.dart';

class CreateInvoiceDialog extends StatefulWidget {
  const CreateInvoiceDialog({Key? key}) : super(key: key);

  @override
  State<CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends State<CreateInvoiceDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  int? _selectedStudentId;
  int? _selectedCourseId;
  int _numberOfLessons = 1;
  double _pricePerLesson = 0;
  bool _isLoading = true;
  bool _isCreating = false;
  String? _errorMessage;

  // Animation controllers for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Controllers for better UX
  final TextEditingController _studentController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _lessonsController =
      TextEditingController(text: '1');

  // Focus nodes for better navigation
  final FocusNode _studentFocusNode = FocusNode();
  final FocusNode _courseFocusNode = FocusNode();
  final FocusNode _lessonsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _studentController.dispose();
    _courseController.dispose();
    _lessonsController.dispose();
    _studentFocusNode.dispose();
    _courseFocusNode.dispose();
    _lessonsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final userController = Get.find<UserController>();
      final courseController = Get.find<CourseController>();

      await userController.fetchUsers();
      await courseController.fetchCourses();

      if (userController.users.isEmpty || courseController.courses.isEmpty) {
        throw Exception('Required data not available');
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _pricePerLesson = courseController.courses
            .firstWhere((course) => course.status.toLowerCase() == 'active')
            .price
            .toDouble();
      });

      // Start animation after data loads
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load required data: ${e.toString()}';
      });
    }
  }

  Widget _buildLoadingState() {
    return Container(
      width: 400,
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
          SizedBox(height: 20),
          Text(
            'Loading students and courses...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadData();
                },
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade600,
                ),
              ),
              TextButton.icon(
                onPressed: Get.back,
                icon: Icon(Icons.close),
                label: Text('Close'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAutocomplete() {
    final userController = Get.find<UserController>();
    final students = userController.users
        .where((u) =>
            u.role.toLowerCase() == 'student' &&
            u.status.toLowerCase() == 'active')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        Autocomplete<User>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return students.take(10); // Limit initial suggestions
            }
            return students
                .where((student) => "${student.fname} ${student.lname}"
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()))
                .take(10);
          },
          displayStringForOption: (User student) =>
              "${student.fname} ${student.lname}",
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 300,
                  constraints: BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index == options.length - 1
                                    ? Colors.transparent
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  "${option.fname[0]}${option.lname[0]}",
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${option.fname} ${option.lname}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      option.email,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (BuildContext context,
              TextEditingController fieldTextEditingController,
              FocusNode fieldFocusNode,
              VoidCallback onFieldSubmitted) {
            return TextFormField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              decoration: InputDecoration(
                hintText: 'Search for a student...',
                prefixIcon:
                    Icon(Icons.person_search, color: Colors.blue.shade600),
                suffixIcon: _selectedStudentId != null
                    ? Icon(Icons.check_circle, color: Colors.green.shade600)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (_selectedStudentId == null) {
                  return 'Please select a student';
                }
                return null;
              },
              onTap: () {
                if (fieldTextEditingController.text.isEmpty) {
                  fieldTextEditingController.clear();
                }
              },
            );
          },
          onSelected: (User student) {
            setState(() {
              _selectedStudentId = student.id;
            });
            // Auto-focus next field
            FocusScope.of(context).requestFocus(_courseFocusNode);
          },
        ),
      ],
    );
  }

  Widget _buildCourseAutocomplete() {
    final courseController = Get.find<CourseController>();
    final courses = courseController.courses
        .where((course) => course.status.toLowerCase() == 'active')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Course *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        Autocomplete<Course>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return courses;
            }
            return courses.where((course) => course.name
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase()));
          },
          displayStringForOption: (Course course) => course.name,
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 300,
                  constraints: BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index == options.length - 1
                                    ? Colors.transparent
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.school,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '\$${option.price.toStringAsFixed(2)} per lesson',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (BuildContext context,
              TextEditingController fieldTextEditingController,
              FocusNode fieldFocusNode,
              VoidCallback onFieldSubmitted) {
            return TextFormField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              decoration: InputDecoration(
                hintText: 'Search for a course...',
                prefixIcon: Icon(Icons.school, color: Colors.green.shade600),
                suffixIcon: _selectedCourseId != null
                    ? Icon(Icons.check_circle, color: Colors.green.shade600)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.green.shade600, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (_selectedCourseId == null) {
                  return 'Please select a course';
                }
                return null;
              },
            );
          },
          onSelected: (Course course) {
            setState(() {
              _selectedCourseId = course.id;
              _pricePerLesson = course.price.toDouble();
            });
            // Auto-focus next field
            FocusScope.of(context).requestFocus(_lessonsFocusNode);
          },
        ),
      ],
    );
  }

  Widget _buildLessonsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Number of Lessons *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            // Decrease button
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: IconButton(
                onPressed: _numberOfLessons > 1
                    ? () {
                        setState(() {
                          _numberOfLessons--;
                          _lessonsController.text = _numberOfLessons.toString();
                        });
                      }
                    : null,
                icon: Icon(Icons.remove),
                color: _numberOfLessons > 1
                    ? Colors.blue.shade600
                    : Colors.grey.shade400,
              ),
            ),
            // Text field
            Expanded(
              child: TextFormField(
                controller: _lessonsController,
                focusNode: _lessonsFocusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide:
                        BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final lessons = int.tryParse(value);
                  if (lessons == null || lessons < 1) return 'Invalid number';
                  return null;
                },
                onChanged: (value) {
                  final lessons = int.tryParse(value);
                  if (lessons != null && lessons > 0) {
                    setState(() => _numberOfLessons = lessons);
                  }
                },
              ),
            ),
            // Increase button
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _numberOfLessons++;
                    _lessonsController.text = _numberOfLessons.toString();
                  });
                },
                icon: Icon(Icons.add),
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingSummary() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blue.shade700),
              SizedBox(width: 8),
              Text(
                'Pricing Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price per Lesson:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '\$${_pricePerLesson.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Number of Lessons:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '$_numberOfLessons',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: Colors.blue.shade300),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              Text(
                '\$${(_pricePerLesson * _numberOfLessons).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isMobile = screenSize.width < 480;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : (isSmallScreen ? 450 : 500),
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.9,
          maxWidth: screenSize.width * 0.95,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - responsive padding
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMobile ? 16 : 20),
                  topRight: Radius.circular(isMobile ? 16 : 20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Invoice',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (!isMobile)
                          Text(
                            'Generate invoice for student lessons',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content - improved scrolling and responsiveness
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    physics: BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.minHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            if (_errorMessage != null)
                              Padding(
                                padding: EdgeInsets.all(isMobile ? 16 : 24),
                                child: _buildErrorState(),
                              )
                            else if (_isLoading)
                              Padding(
                                padding: EdgeInsets.all(isMobile ? 16 : 24),
                                child: _buildLoadingState(),
                              )
                            else
                              AnimatedBuilder(
                                animation: _fadeAnimation,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _fadeAnimation.value,
                                    child: Transform.translate(
                                      offset: Offset(
                                          0, 20 * (1 - _slideAnimation.value)),
                                      child: Padding(
                                        padding:
                                            EdgeInsets.all(isMobile ? 16 : 24),
                                        child: Form(
                                          key: _formKey,
                                          child: Column(
                                            children: [
                                              _buildStudentAutocomplete(),
                                              SizedBox(
                                                  height: isMobile ? 16 : 20),
                                              _buildCourseAutocomplete(),
                                              SizedBox(
                                                  height: isMobile ? 16 : 20),
                                              _buildLessonsField(),
                                              SizedBox(
                                                  height: isMobile ? 20 : 24),
                                              _buildPricingSummary(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Actions - responsive layout
            if (!_isLoading && _errorMessage == null)
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(isMobile ? 16 : 20),
                    bottomRight: Radius.circular(isMobile ? 16 : 20),
                  ),
                ),
                child: isMobile
                    ? Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isCreating
                                  ? null
                                  : () async {
                                      if (_formKey.currentState!.validate() &&
                                          _selectedStudentId != null &&
                                          _selectedCourseId != null) {
                                        _showConfirmationDialog();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isCreating
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Creating...'),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_circle_outline,
                                            size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Create Invoice',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: Get.back,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: Get.back,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isCreating
                                  ? null
                                  : () async {
                                      if (_formKey.currentState!.validate() &&
                                          _selectedStudentId != null &&
                                          _selectedCourseId != null) {
                                        _showConfirmationDialog();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isCreating
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Creating...'),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_circle_outline,
                                            size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Create Invoice',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }

  // Confirmation dialog - keeping original logic
  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange.shade600),
              SizedBox(width: 12),
              ResponsiveText('Confirm', style: TextStyle()),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to create this invoice?'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Lessons: $_numberOfLessons'),
                    Text(
                        'Total: \$${(_pricePerLesson * _numberOfLessons).toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _createInvoice();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  // Invoice creation logic - keeping original logic
  Future<void> _createInvoice() async {
    setState(() => _isCreating = true);
    await Get.find<BillingController>().generateInvoice(
      studentId: _selectedStudentId!,
      courseId: _selectedCourseId!,
      lessons: _numberOfLessons,
      pricePerLesson: _pricePerLesson,
    );
    setState(() => _isCreating = false);
    Get.back();
  }
}
