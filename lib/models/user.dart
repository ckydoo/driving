class User {
  int? id;
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

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse DateTime
    DateTime parseDateTime(dynamic dateData, DateTime fallback) {
      if (dateData == null) return fallback;

      if (dateData is String) {
        try {
          return DateTime.parse(dateData);
        } catch (e) {
          print('Failed to parse date: $dateData, error: $e');
          return fallback;
        }
      }

      return fallback;
    }

    return User(
      id: json['id'],
      fname: json['fname']?.toString() ?? '',
      lname: json['lname']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      date_of_birth: parseDateTime(json['date_of_birth'], DateTime.now()),
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      idnumber: json['idnumber']?.toString() ?? '',
      created_at: parseDateTime(json['created_at'], DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fname': fname,
        'lname': lname,
        'email': email,
        'password': password,
        'gender': gender,
        'phone': phone,
        'address': address,
        'date_of_birth': date_of_birth.toIso8601String(),
        'role': role,
        'idnumber': idnumber,
        'status': status,
        'created_at': created_at.toIso8601String(),
      };
}
