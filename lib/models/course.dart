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

  /// ✅ ENHANCED: fromJson with safe type conversion
  factory Course.fromJson(Map<String, dynamic> json) {
    try {
      print('📚 Parsing course from JSON: $json');

      return Course(
        id: _parseInt(json['id']),
        name: _parseString(json['name']) ?? '',
        price: _parseInt(json['price']) ?? 0, // ✅ SAFE CONVERSION
        status: _parseString(json['status']) ?? 'Active',
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      );
    } catch (e) {
      print('❌ Error parsing Course from JSON: $e');
      print('🔍 JSON data: $json');
      rethrow;
    }
  }

  // ✅ SAFE PARSING METHODS
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      // Handle string prices like "150.0" -> 150
      final doubleValue = double.tryParse(value);
      return doubleValue?.toInt();
    }
    print('⚠️ Could not parse int from: $value (${value.runtimeType})');
    return null;
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    try {
      if (value is DateTime) return value;

      if (value is String) {
        // Handle ISO format: "2025-08-30T00:35:59.000"
        if (value.contains('T')) {
          return DateTime.parse(value);
        }
        // Handle other formats: "2025-08-29 15:22:08"
        if (value.contains(' ') && value.contains(':')) {
          return DateTime.parse(value.replaceFirst(' ', 'T'));
        }
        return DateTime.parse(value);
      }

      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    } catch (e) {
      print('⚠️ Error parsing DateTime from $value: $e');
    }

    return null;
  }

  /// ✅ ENHANCED: toJson ensuring correct types
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price, // Always int
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() {
    return 'Course{id: $id, name: $name, price: $price, status: $status, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Course &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          price == other.price &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ price.hashCode ^ status.hashCode;

  /// Create a copy with updated fields
  Course copyWith({
    int? id,
    String? name,
    int? price,
    String? status,
    DateTime? createdAt,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get formatted price
  String get formattedPrice => '\$${price.toString()}';

  /// Check if course is active
  bool get isActive => status.toLowerCase() == 'active';
}
