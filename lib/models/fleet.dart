class Fleet {
  final int? id;
  final String carPlate;
  final String make;
  final String model;
  final String modelYear;
  final int instructor;
  final String status;
  DateTime? created_at;
  DateTime? updated_at;

  Fleet({
    this.id,
    required this.carPlate,
    required this.make,
    required this.model,
    required this.modelYear,
    required this.instructor,
    required this.status,
    this.created_at,
    this.updated_at,
  });
  // Convert a Fleet object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'carPlate': carPlate,
      'instructor': instructor,
      'modelYear': modelYear,
      'status': status,
      'created_at': created_at?.toIso8601String(),
      'updated_at': updated_at?.toIso8601String(),
    };
  }

  // Create a Fleet object from a Map
  factory Fleet.fromMap(Map<String, dynamic> map) {
    return Fleet(
      id: map['id'],
      make: map['make'],
      model: map['model'],
      carPlate: map['carPlate'],
      instructor: map['instructor'],
      modelYear: map['modelYear'],
      status: map['status'] ?? 'available',
      created_at: map['created_at'],
      updated_at: map['updated_at'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carPlate': carPlate,
      'make': make,
      'model': model,
      'modelyear': modelYear,
      'status': status,
      'instructor': instructor == 0 ? null : instructor, // Convert 0 to null
      'created_at': created_at?.toIso8601String(),
      'updated_at': updated_at?.toIso8601String(),
    };
  }

// And update the fromJson constructor to handle null instructor
  factory Fleet.fromJson(Map<String, dynamic> json) {
    return Fleet(
      id: json['id'],
      carPlate: json['carPlate'] ?? json['carPlate'] ?? '',
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      modelYear: json['modelyear'] ?? json['modelYear'] ?? '',
      status: json['status'] ?? 'available',
      instructor: json['instructor'] ?? 0, // Default to 0 if null
      created_at: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updated_at: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
  copyWith({
    int? id,
    String? carPlate,
    String? make,
    String? model,
    String? modelYear,
    String? status,
    int? instructor,
  }) {
    return Fleet(
      id: id ?? this.id,
      carPlate: carPlate ?? this.carPlate,
      make: make ?? this.make,
      model: model ?? this.model,
      modelYear: modelYear ?? this.modelYear,
      status: status ?? this.status,
      instructor: instructor ?? this.instructor,
    );
  }

  Fleet to({int? id}) {
    return Fleet(
      id: id ?? this.id,
      carPlate: carPlate,
      make: make,
      model: model,
      modelYear: modelYear,
      status: status,
      instructor: instructor,
    );
  }
}
