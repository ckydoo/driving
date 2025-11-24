
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
      'id': id,
      'school_id': schoolId, // ✅ Add this line
      'fname': fname,
      'lname': lname,
      'email': email.toLowerCase(),
      'password': password,
      'gender': gender,
      'phone': phone,
      'address': address,
      'date_of_birth': date_of_birth.toIso8601String(),
      'role': role.toLowerCase(),
      'status': status,
      'idnumber': idnumber,
      'created_at': created_at.toIso8601String(),
    };
  }

  // Enhanced copyWith method
  User copyWith({
    int? id,
    String? schoolId, // ✅ Add this
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
    int? deleted,
  }) {
    return User(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId, // ✅ Add this
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
