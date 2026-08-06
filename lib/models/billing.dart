// models/billing.dart

class Billing {
  final int? id;
  final int scheduleId;
  final int studentId; // Add studentId
  final double amount;
  final DateTime? dueDate;
  final String? status; // e.g., "Pending", "Paid", "Overdue"

  Billing({
    this.id,
    required this.scheduleId,
    required this.studentId, // Add studentId to constructor
    required this.amount,
    this.dueDate,
    this.status,
  });

  factory Billing.fromJson(Map<String, dynamic> json) => Billing(
        id: json['id'],
        scheduleId: json['scheduleId'],
        studentId: json['studentId'], // Add studentId to fromJson
        amount: json['amount'],
        dueDate:
            json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        status: json['status'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scheduleId': scheduleId,
        'studentId': studentId, // Add studentId to toJson
        'amount': amount,
        'dueDate': dueDate?.toIso8601String(),
        'status': status,
      };
}
