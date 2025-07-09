import 'package:driving/models/billing_record.dart';
import 'package:driving/models/payment.dart';
import 'package:intl/intl.dart';

class Invoice {
  late final int? id;
  final int studentId;
  final int courseId;
  final int lessons;
  final double pricePerLesson;
  late final double amountPaid;
  final DateTime createdDate;
  final DateTime dueDate;
  late final String status;
  double? totalAmount;
  String? courseName;
  List<BillingRecord> billingRecords;
  List<Payment> payments;

  Invoice({
    this.id,
    required this.studentId,
    required this.courseId,
    required this.lessons,
    required this.pricePerLesson,
    this.amountPaid = 0,
    required this.createdDate,
    required this.dueDate,
    this.status = 'unpaid',
    this.totalAmount,
    this.courseName,
    this.billingRecords = const [],
    this.payments = const [],
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'courseId': courseId,
      'lessons': lessons,
      'pricePerLesson': pricePerLesson,
      'totalAmount': totalAmount,
      'createdDate': createdDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'amountPaid': amountPaid,
      'status': status,
    };
  }

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'],
        studentId: json['student'],
        courseId: json['course'],
        lessons: json['lessons'],
        pricePerLesson: json['price_per_lesson'].toDouble(),
        amountPaid: json['amountpaid'].toDouble(),
        createdDate: DateTime.parse(json['created_at']),
        dueDate: DateTime.parse(json['due_date']),
        status: json['status'],
        totalAmount: json['total_amount'] != null
            ? json['total_amount'].toDouble()
            : null,
        courseName: json['courseName'],
        billingRecords: [], // Initialize from DB later
        payments: [], // Initialize from DB later
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'student': studentId,
        'course': courseId,
        'lessons': lessons,
        'price_per_lesson': pricePerLesson,
        'amountpaid': amountPaid,
        'created_at': createdDate.toIso8601String(),
        'due_date': dueDate.toIso8601String(),
        'status': status,
        'total_amount': totalAmount,
        'courseName': courseName,
      };
  double get totalAmountCalculated => pricePerLesson * lessons;
  double get balance => totalAmountCalculated - amountPaid;
  String get formattedDueDate => DateFormat.yMMMd().format(dueDate);
  String get formattedBalance => '\$${balance.toStringAsFixed(2)}';
  String get formattedTotal => '\$${totalAmountCalculated.toStringAsFixed(2)}';

  Invoice copyWith({
    int? id,
    int? studentId,
    int? courseId,
    int? lessons,
    double? pricePerLesson,
    double? amountPaid,
    DateTime? createdDate,
    DateTime? dueDate,
    String? status,
    double? totalAmount,
    String? courseName,
  }) {
    return Invoice(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      courseId: courseId ?? this.courseId,
      lessons: lessons ?? this.lessons,
      pricePerLesson: pricePerLesson ?? this.pricePerLesson,
      amountPaid: amountPaid ?? this.amountPaid,
      createdDate: createdDate ?? this.createdDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      courseName: courseName ?? this.courseName,
    );
  }
}
