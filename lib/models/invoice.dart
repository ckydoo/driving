import 'package:driving/models/billing_record.dart';
import 'package:driving/models/payment.dart';
import 'package:intl/intl.dart';

class Invoice {
  final int? id;
  final String invoiceNumber; // Add this field
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
      invoiceNumber: map['invoice_number'] ?? '', // Add this line
      studentId: map['student'],
      courseId: map['course'],
      lessons: map['lessons'],
      pricePerLesson: map['price_per_lesson']?.toDouble() ?? 0.0,
      amountPaid: map['amountpaid']?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at']),
      dueDate: DateTime.parse(map['due_date']),
      status: map['status'] ?? 'unpaid',
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber, // Add this line
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
    return Invoice(
      id: json['id'],
      invoiceNumber: json['invoice_number'],
      studentId: json['student'],
      courseId: json['course'],
      lessons: json['lessons'],
      pricePerLesson: (json['price_per_lesson'] as num).toDouble(),
      amountPaid: (json['amountpaid'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at']),
      dueDate: DateTime.parse(json['due_date']),
      status: json['status'] ?? 'unpaid',
      totalAmount: (json['total_amount'] as num?)!.toDouble(),
      payments: [],
    );
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
