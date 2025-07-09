import 'package:intl/intl.dart';

class Payment {
  final int? id;
  final int invoiceId;
  final double amount;
  final String method;
  final DateTime paymentDate;

  Payment({
    this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.paymentDate,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'],
        invoiceId: json['invoice'],
        amount: json['amount'].toDouble(),
        method: json['method'],
        paymentDate: DateTime.parse(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice': invoiceId,
        'amount': amount,
        'method': method,
        'created_at': paymentDate.toIso8601String(),
      };

  String get formattedDate => DateFormat.yMMMd().format(paymentDate);
  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';
}
