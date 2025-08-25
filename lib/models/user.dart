// lib/models/user.dart - Enhanced User model with better null safety

class User {
  final int? id;
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

  // Enhanced factory constructor with better null safety
  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'] as int?,
        fname: (json['fname'] as String? ?? '').trim(),
        lname: (json['lname'] as String? ?? '').trim(),
        email: (json['email'] as String? ?? '').trim().toLowerCase(),
        password: json['password'] as String? ?? '',
        gender: json['gender'] as String? ?? 'Male',
        phone: (json['phone'] as String? ?? '').trim(),
        address: (json['address'] as String? ?? '').trim(),
        date_of_birth: _parseDate(json['date_of_birth'])!,
        role: (json['role'] as String? ?? 'student').toLowerCase(),
        status: json['status'] as String? ?? 'Active',
        idnumber: (json['idnumber'] as String? ?? '').trim(),
        created_at: _parseDate(json['created_at']) ?? DateTime.now(),
      );
    } catch (e) {
      print('❌ Error parsing User from JSON: $e');
      print('🔍 Problematic JSON: $json');
      rethrow;
    }
  }

  // Enhanced toJson method
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'fname': fname.trim(),
      'lname': lname.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'gender': gender,
      'phone': phone.trim(),
      'address': address.trim(),
      'date_of_birth':
          date_of_birth.toIso8601String().split('T')[0], // Just the date part
      'role': role.toLowerCase(),
      'status': status,
      'idnumber': idnumber.trim(),
      'created_at': created_at.toIso8601String(),
    };
  }

  // Helper method to safely parse dates
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
      }
    } catch (e) {
      print('⚠️ Failed to parse date: $dateValue, error: $e');
    }

    return null;
  }

  // Enhanced copyWith method
  User copyWith({
    int? id,
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
  }) {
    return User(
      id: id ?? this.id,
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
