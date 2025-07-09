class Fleet {
  final int? id;
  final String carPlate;
  final String make;
  final String model;
  final String modelYear;
  final int instructor;

  Fleet({
    this.id,
    required this.carPlate,
    required this.make,
    required this.model,
    required this.modelYear,
    required this.instructor,
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
    );
  }
  factory Fleet.fromJson(Map<String, dynamic> json) => Fleet(
        id: json['id'],
        carPlate: json['carplate'],
        make: json['make'],
        model: json['model'],
        modelYear: json['modelyear'],
        instructor: json['instructor'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'carplate': carPlate,
        'make': make,
        'model': model,
        'modelyear': modelYear,
        'instructor': instructor,
      };
}
