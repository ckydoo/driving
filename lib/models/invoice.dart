import 'package:driving/models/billing_record.dart';
import 'package:driving/models/payment.dart';
import 'package:intl/intl.dart';

class Invoice {
  final int? id;
  final String invoiceNumber;
  final int studentId;
  final int courseId;
  final int lessons;
  final double pricePerLesson;
  final double amountPaid;
  final DateTime createdAt;
  final DateTime dueDate;
  final String status;
  final double totalAmount;
  List<BillingRecord> billingRecords;
  List<Payment> payments;

  Invoice({
    this.id,
    required this.invoiceNumber, // Add to constructor
    required this.studentId,
    required this.courseId,
    required this.lessons,
    required this.pricePerLesson,
    required this.amountPaid,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    required this.totalAmount,
    this.billingRecords = const [],
    this.payments = const [],
  });

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      studentId: map['student'] ?? 0,
      courseId: map['course'] ?? 0,
      lessons: map['lessons'] ?? 1,
      pricePerLesson: _parseDouble(map['price_per_lesson']),
      amountPaid: _parseDouble(map['amountpaid']),
      createdAt: DateTime.parse(map['created_at']),
      dueDate: DateTime.parse(map['due_date']),
      status: map['status']?.toString() ?? 'unpaid',
      totalAmount: _parseDouble(map['total_amount']),
    );
  }

// Add these safe parsing methods to your Invoice class
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInteger(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      // Try parsing as double first, then convert to int
      final doubleValue = double.tryParse(value);
      return doubleValue?.toInt() ?? 0;
    }
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'student': studentId,
      'course': courseId,
      'lessons': lessons,
      'price_per_lesson': pricePerLesson,
      'amountpaid': amountPaid,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'total_amount': totalAmount,
    };
  }

  double get totalAmountCalculated => lessons * pricePerLesson;
  double get balance => totalAmountCalculated - amountPaid;
  String get formattedDueDate => DateFormat.yMMMd().format(dueDate);
  String get formattedBalance => '\$${balance.toStringAsFixed(2)}';
  String get formattedTotal => '\$${totalAmountCalculated.toStringAsFixed(2)}';

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    int? studentId,
    int? courseId,
    int? lessons,
    double? pricePerLesson,
    double? amountPaid,
    DateTime? createdAt,
    DateTime? dueDate,
    String? status,
    double? totalAmount,
    String? courseName,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      studentId: studentId ?? this.studentId,
      courseId: courseId ?? this.courseId,
      lessons: lessons ?? this.lessons,
      pricePerLesson: pricePerLesson ?? this.pricePerLesson,
      amountPaid: amountPaid ?? this.amountPaid,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    try {
      print('📄 Parsing invoice from JSON: $json');

      return Invoice(
        id: _parseInt(json['id']),
        invoiceNumber: json['invoice_number']?.toString() ?? '',
        studentId: _parseInt(json['student']) ?? 0,
        courseId: _parseInt(json['course']) ?? 0,
        lessons: _parseInt(json['lessons']) ?? 1,
        pricePerLesson: _parseDouble(json['price_per_lesson']) ?? 0.0,
        amountPaid: _parseDouble(json['amountpaid']) ?? 0.0,
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        // ✅ FIX: Handle due_date as both integer (milliseconds) and string
        dueDate: _parseDateTime(json['due_date']) ?? DateTime.now(),
        status: json['status']?.toString() ?? 'unpaid',
        totalAmount: _parseDouble(json['total_amount']) ?? 0.0,
        payments: [],
      );
    } catch (e) {
      print('❌ Error parsing Invoice from JSON: $e');
      print('🔍 JSON data: $json');
      rethrow;
    }
  }

// ✅ ENHANCED: Safe parsing methods for Invoice that handle your data formats
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    try {
      if (value is DateTime) return value;

      if (value is int) {
        // Handle milliseconds timestamp like: due_date: 1756912744396
        return DateTime.fromMillisecondsSinceEpoch(value);
      }

      if (value is String) {
        // Handle ISO format: "2025-08-29T17:19:53.000"
        if (value.contains('T')) {
          return DateTime.parse(value);
        }
        // Handle other string formats
        if (value.contains('-')) {
          return DateTime.parse(value);
        }
        // Handle numeric string
        final intValue = int.tryParse(value);
        if (intValue != null) {
          return DateTime.fromMillisecondsSinceEpoch(intValue);
        }
      }
    } catch (e) {
      print('⚠️ Error parsing DateTime from $value (${value.runtimeType}): $e');
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'student': studentId,
      'course': courseId,
      'lessons': lessons,
      'price_per_lesson': pricePerLesson,
      'amountpaid': amountPaid,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'total_amount': totalAmount,
    };
  }
}
