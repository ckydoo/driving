class Course {
  final int? id;
  final String name;
  final int price;
  final String status;
  final DateTime createdAt;

  Course({
    this.id,
    required this.name,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'],
        name: json['name'],
        price: json['price'],
        status: json['status'],
        createdAt: DateTime.parse(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}
