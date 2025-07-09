class Notification {
  final int? id;
  final int userId;
  final String type; // e.g., 'lesson_reminder', 'payment_due'
  final String message;
  final DateTime createdAt;
  final bool isRead;

  Notification({
    this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory Notification.fromJson(Map<String, dynamic> json) => Notification(
        id: json['id'],
        userId: json['user'],
        type: json['type'],
        message: json['message'],
        createdAt: DateTime.parse(json['created_at']),
        isRead: json['is_read'] == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': userId,
        'type': type,
        'message': message,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead ? 1 : 0,
      };
}
