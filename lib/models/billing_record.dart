class BillingRecord {
  final int? id;
  final int scheduleId;
  final int invoiceId;
  final int studentId;
  final double amount;
  final DateTime? dueDate;
  final String status; // e.g., "Scheduled", "Completed", "Invoiced", "Paid"
  final DateTime createdAt;
  final String description;

  BillingRecord({
    this.id,
    required this.scheduleId,
    required this.invoiceId,
    required this.studentId,
    required this.amount,
    this.dueDate,
    this.status = "Scheduled",
    required this.createdAt,
    this.description = '',
  });

  factory BillingRecord.fromJson(Map<String, dynamic> json) => BillingRecord(
        id: json['id'],
        scheduleId: json['scheduleId'],
        invoiceId: json['invoiceId'],
        studentId: json['studentId'],
        amount: json['amount'],
        dueDate:
            json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        status: json['status'] ?? "Scheduled",
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scheduleId': scheduleId,
        'invoiceId': invoiceId,
        'studentId': studentId,
        'amount': amount,
        'dueDate': dueDate?.toIso8601String(),
        'status': status,
      };
}
