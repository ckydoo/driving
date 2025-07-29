import 'package:intl/intl.dart';

class Payment {
  final int? id;
  final int invoiceId;
  final double amount;
  final String method;
  final DateTime paymentDate;
  final String? notes;
  final String? reference; // For transaction reference, check number, etc.
  final String? receiptPath; // Path to generated receipt PDF
  final bool receiptGenerated;

  Payment({
    this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.paymentDate,
    this.notes,
    this.reference,
    this.receiptPath,
    this.receiptGenerated = false,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'],
        invoiceId: json['invoice'],
        amount: json['amount'].toDouble(),
        method: json['method'],
        paymentDate: DateTime.parse(json['created_at']),
        notes: json['notes'],
        reference: json['reference'],
        receiptPath: json['receipt_path'],
        receiptGenerated: json['receipt_generated'] == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice': invoiceId,
        'amount': amount,
        'method': method,
        'created_at': paymentDate.toIso8601String(),
        'notes': notes,
        'reference': reference,
        'receipt_path': receiptPath,
        'receipt_generated': receiptGenerated ? 1 : 0,
      };

  // Create a copy with updated fields
  Payment copyWith({
    int? id,
    int? invoiceId,
    double? amount,
    String? method,
    DateTime? paymentDate,
    String? notes,
    String? reference,
    String? receiptPath,
    bool? receiptGenerated,
  }) {
    return Payment(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      reference: reference ?? this.reference,
      receiptPath: receiptPath ?? this.receiptPath,
      receiptGenerated: receiptGenerated ?? this.receiptGenerated,
    );
  }

  // Getters for formatted display
  String get formattedDate => DateFormat.yMMMd().format(paymentDate);
  String get formattedTime => DateFormat.jm().format(paymentDate);
  String get formattedDateTime =>
      DateFormat('MMM dd, yyyy - hh:mm a').format(paymentDate);
  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';

  String get displayMethod {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'credit_card':
        return 'Credit Card';
      case 'debit_card':
        return 'Debit Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'check':
        return 'Check';
      case 'mobile_payment':
        return 'Mobile Payment';
      default:
        return method
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  // Generate receipt number
  String get receiptNumber {
    if (id == null) return 'RCP-PENDING';
    final year = paymentDate.year.toString().substring(2);
    final month = paymentDate.month.toString().padLeft(2, '0');
    final day = paymentDate.day.toString().padLeft(2, '0');
    final receiptId = id.toString().padLeft(4, '0');
    return 'RCP-$year$month$day-$receiptId';
  }

  // Check if payment needs reference (non-cash payments)
  bool get requiresReference {
    return method != 'cash';
  }

  // Check if payment is recent (within last 24 hours)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(paymentDate);
    return difference.inHours < 24;
  }

  // Convert to original Payment model for backward compatibility
  Payment toPayment() {
    return Payment(
      id: id,
      invoiceId: invoiceId,
      amount: amount,
      method: method,
      paymentDate: paymentDate,
      notes: notes,
    );
  }

  @override
  String toString() {
    return 'Payment{id: $id, invoiceId: $invoiceId, amount: $amount, method: $method, paymentDate: $paymentDate, notes: $notes, reference: $reference, receiptGenerated: $receiptGenerated}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          invoiceId == other.invoiceId &&
          amount == other.amount &&
          method == other.method &&
          paymentDate == other.paymentDate;

  @override
  int get hashCode =>
      id.hashCode ^
      invoiceId.hashCode ^
      amount.hashCode ^
      method.hashCode ^
      paymentDate.hashCode;
}

// Extension to add additional functionality to original Payment model
extension PaymentExtensions on Payment {
  // Convert to  payment
  Payment toEnhanced({
    String? reference,
    String? receiptPath,
    bool receiptGenerated = false,
  }) {
    return Payment(
      id: id,
      invoiceId: invoiceId,
      amount: amount,
      method: method,
      paymentDate: paymentDate,
      notes: notes,
      reference: reference,
      receiptPath: receiptPath,
      receiptGenerated: receiptGenerated,
    );
  }

  String get displayMethod {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'credit_card':
        return 'Credit Card';
      case 'debit_card':
        return 'Debit Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'check':
        return 'Check';
      case 'mobile_payment':
        return 'Mobile Payment';
      default:
        return method
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  String get receiptNumber {
    if (id == null) return 'RCP-PENDING';
    final year = paymentDate.year.toString().substring(2);
    final month = paymentDate.month.toString().padLeft(2, '0');
    final day = paymentDate.day.toString().padLeft(2, '0');
    final receiptId = id.toString().padLeft(4, '0');
    return 'RCP-$year$month$day-$receiptId';
  }

  Payment copyWith({
    int? id,
    int? invoiceId,
    double? amount,
    String? method,
    DateTime? paymentDate,
    String? notes,
  }) {
    return Payment(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
    );
  }
}

// Payment method helper class
class PaymentMethods {
  static const String cash = 'cash';
  static const String creditCard = 'credit_card';
  static const String debitCard = 'debit_card';
  static const String bankTransfer = 'bank_transfer';
  static const String check = 'check';
  static const String mobilePayment = 'mobile_payment';

  static const List<Map<String, dynamic>> all = [
    {
      'value': cash,
      'label': 'Cash',
      'icon': 'money',
      'color': 'green',
      'requiresReference': false,
    },
    {
      'value': creditCard,
      'label': 'Credit Card',
      'icon': 'credit_card',
      'color': 'blue',
      'requiresReference': true,
    },
    {
      'value': debitCard,
      'label': 'Debit Card',
      'icon': 'payment',
      'color': 'purple',
      'requiresReference': true,
    },
    {
      'value': bankTransfer,
      'label': 'Bank Transfer',
      'icon': 'account_balance',
      'color': 'orange',
      'requiresReference': true,
    },
    {
      'value': check,
      'label': 'Check',
      'icon': 'receipt_long',
      'color': 'brown',
      'requiresReference': true,
    },
    {
      'value': mobilePayment,
      'label': 'Mobile Pay',
      'icon': 'smartphone',
      'color': 'indigo',
      'requiresReference': true,
    }
  ];
}
