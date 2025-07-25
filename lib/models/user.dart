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
  final List<String>? courseIds; // Add this line

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
    this.courseIds, // Initialize it in the constructor
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        fname: json['fname'],
        lname: json['lname'],
        email: json['email'],
        password: json['password'],
        gender: json['gender'],
        phone: json['phone'],
        address: json['address'],
        date_of_birth: DateTime.parse(json['date_of_birth']),
        role: json['role'],
        status: json['status'],
        idnumber: json['idnumber'],
        created_at: DateTime.parse(json['created_at']),
        courseIds: json['courseIds'] != null
            ? List<String>.from(json['courseIds'])
            : null, // Handle null from JSON
      );

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
        'courseIds': courseIds,
      };
}
