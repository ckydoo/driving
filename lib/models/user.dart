// lib/models/user.dart - Fixed User model with proper type handling

class User {
  final int? id;
  final String? schoolId;
  final String? firebaseUserId;
  final String fname;
  final String lname;
  final String email;
  final String password;
  final String gender;
  final String phone;
  final String address;
  final DateTime date_of_birth;
  final String role;
  final String status;
  final String idnumber;
  final DateTime created_at;
  final DateTime? last_modified;
  final String? last_modified_device;
  final int? deleted;
  final int? sync_version;

  User({
    this.id,
    this.schoolId,
    this.firebaseUserId,
    required this.fname,
    required this.lname,
    required this.email,
    required this.password,
    required this.gender,
    required this.phone,
    required this.address,
    required this.date_of_birth,
    required this.role,
    required this.status,
    required this.idnumber,
    required this.created_at,
    this.last_modified,
    this.last_modified_device,
    this.deleted,
    this.sync_version,
  });

  // Enhanced factory constructor with better null safety and type conversion
  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        // Handle id conversion - could be int or string
        id: _parseInt(json['id']),
        schoolId: json['schoolId']?.toString(),
        firebaseUserId: json['firebase_user_id']?.toString(),
        fname: (json['fname']?.toString() ?? '').trim(),
        lname: (json['lname']?.toString() ?? '').trim(),
        email: (json['email']?.toString() ?? '').trim().toLowerCase(),
        password: json['password']?.toString() ?? '',
        gender: json['gender']?.toString() ?? 'Male',
        phone: (json['phone']?.toString() ?? '').trim(),
        address: (json['address']?.toString() ?? '').trim(),
        date_of_birth: _parseDate(json['date_of_birth']) ?? DateTime.now(),
        role: (json['role']?.toString() ?? 'student').toLowerCase(),
        status: json['status']?.toString() ?? 'Active',
        idnumber: (json['idnumber']?.toString() ?? '').trim(),
        created_at: _parseDate(json['created_at']) ?? DateTime.now(),
        last_modified: _parseDate(json['last_modified']),
        last_modified_device: json['last_modified_device']?.toString(),
        deleted: _parseInt(json['deleted']),
        sync_version: _parseInt(json['sync_version']),
      );
    } catch (e) {
      print('❌ Error parsing User from JSON: $e');
      print('🔍 Problematic JSON: $json');
      rethrow;
    }
  }

  // Helper method to safely parse integers from dynamic values
  static int? _parseInt(dynamic value) {
    if (value == null) return null;

    try {
      if (value is int) {
        return value;
      } else if (value is String) {
        if (value.trim().isEmpty) return null;
        return int.parse(value);
      } else if (value is double) {
        return value.toInt();
      }
    } catch (e) {
      print('⚠️ Failed to parse int: $value, error: $e');
    }

    return null;
  }

  // Helper method to safely parse dates from various formats
  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    try {
      if (dateValue is String) {
        if (dateValue.trim().isEmpty) return null;
        return DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        return dateValue;
      } else if (dateValue is int) {
        // Handle milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else if (dateValue is Map) {
        // Handle Firestore Timestamp format
        if (dateValue.containsKey('seconds')) {
          int seconds = dateValue['seconds'] is int
              ? dateValue['seconds']
              : int.parse(dateValue['seconds'].toString());
          int nanoseconds = dateValue['nanoseconds'] is int
              ? dateValue['nanoseconds']
              : int.parse(dateValue['nanoseconds'].toString());
          return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + (nanoseconds / 1000000).round());
        }
      }
    } catch (e) {
      print('⚠️ Failed to parse date: $dateValue, error: $e');
    }

    return null;
  }

  // Enhanced toJson method
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (schoolId != null) 'schoolId': schoolId,
      if (firebaseUserId != null) 'firebase_user_id': firebaseUserId,
      'fname': fname.trim(),
      'lname': lname.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'gender': gender,
      'phone': phone.trim(),
      'address': address.trim(),
      'date_of_birth': date_of_birth.toIso8601String().split('T')[0],
      'role': role.toLowerCase(),
      'status': status,
      'idnumber': idnumber.trim(),
      'created_at': created_at.toIso8601String(),
      if (last_modified != null)
        'last_modified': last_modified!.toIso8601String(),
      if (last_modified_device != null)
        'last_modified_device': last_modified_device,
      if (deleted != null) 'deleted': deleted,
      if (sync_version != null) 'sync_version': sync_version,
    };
  }

  // Enhanced copyWith method
  User copyWith({
    int? id,
    String? schoolId,
    String? firebaseUserId,
    String? fname,
    String? lname,
    String? email,
    String? password,
    String? gender,
    String? phone,
    String? address,
    DateTime? date_of_birth,
    String? role,
    String? status,
    String? idnumber,
    DateTime? created_at,
    DateTime? last_modified,
    String? last_modified_device,
    int? deleted,
    int? sync_version,
  }) {
    return User(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      firebaseUserId: firebaseUserId ?? this.firebaseUserId,
      fname: fname ?? this.fname,
      lname: lname ?? this.lname,
      email: email ?? this.email,
      password: password ?? this.password,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      date_of_birth: date_of_birth ?? this.date_of_birth,
      role: role ?? this.role,
      status: status ?? this.status,
      idnumber: idnumber ?? this.idnumber,
      created_at: created_at ?? this.created_at,
      last_modified: last_modified ?? this.last_modified,
      last_modified_device: last_modified_device ?? this.last_modified_device,
      deleted: deleted ?? this.deleted,
      sync_version: sync_version ?? this.sync_version,
    );
  }

  // Validation methods
  bool get isValidEmail {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  bool get hasRequiredFields {
    return fname.trim().isNotEmpty &&
        lname.trim().isNotEmpty &&
        email.trim().isNotEmpty &&
        isValidEmail;
  }

  String get fullName => '$fname $lname'.trim();

  bool get isActive => deleted == null || deleted == 0;

  @override
  String toString() {
    return 'User(id: $id, name: $fullName, email: $email, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id && other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
