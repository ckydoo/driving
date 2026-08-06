// import 'package:driving/services/database_helper.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import '../models/notification.dart'
//     as MyNotification; // Alias to avoid name clash

// class NotificationService extends GetxService {
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//   final DatabaseHelper _dbHelper = Get.find();
//   final BehaviorSubject<String?> selectNotificationSubject =
//       BehaviorSubject<String?>();

//   @override
//   void onInit() {
//     super.onInit();
//     _configureLocalNotifications();
//   }

//   Future<void> _configureLocalNotifications() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const InitializationSettings initializationSettings =
//         InitializationSettings(android: initializationSettingsAndroid);
//     await flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: (NotificationResponse details) {
//         if (details.payload != null) {
//           selectNotificationSubject.add(details.payload!);
//         }
//       },
//     );
//   }

//   Future<void> showLessonReminder(int userId, DateTime lessonTime,
//       String studentName, String instructorName) async {
//     final formattedTime = DateFormat('MMM dd, yyyy h:mm a').format(lessonTime);
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//         AndroidNotificationDetails(
//       'lesson_reminder_channel',
//       'Lesson Reminders',
//       channelDescription: 'Reminders for upcoming lessons',
//       importance: Importance.max,
//       priority: Priority.high,
//       showWhen: true,
//     );
//     const NotificationDetails platformChannelSpecifics =
//         NotificationDetails(android: androidPlatformChannelSpecifics);
//     await flutterLocalNotificationsPlugin.show(
//       0,
//       'Lesson Reminder',
//       'Lesson with $studentName and $instructorName at $formattedTime',
//       platformChannelSpecifics,
//       payload: 'lesson_reminder',
//     );

//     // Save to database
//     await _dbHelper.insertNotification({
//       'user': userId,
//       'type': 'lesson_reminder',
//       'message':
//           'Lesson with $studentName and $instructorName at $formattedTime',
//       'created_at': DateTime.now().toIso8601String(),
//     });
//   }

//   Future<void> showPaymentReminder(
//       int userId, double amountDue, DateTime dueDate) async {
//     final formattedDueDate = DateFormat('MMM dd, yyyy').format(dueDate);
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//         AndroidNotificationDetails(
//       'payment_reminder_channel',
//       'Payment Reminders',
//       channelDescription: 'Reminders for upcoming payments',
//       importance: Importance.max,
//       priority: Priority.high,
//       showWhen: true,
//     );
//     const NotificationDetails platformChannelSpecifics =
//         NotificationDetails(android: androidPlatformChannelSpecifics);
//     await flutterLocalNotificationsPlugin.show(
//       1,
//       'Payment Reminder',
//       'Payment of \$$amountDue due on $formattedDueDate',
//       platformChannelSpecifics,
//       payload: 'payment_reminder',
//     );

//     // Save to database
//     await _dbHelper.insertNotification({
//       'user': userId,
//       'type': 'payment_reminder',
//       'message': 'Payment of \$$amountDue due on $formattedDueDate',
//       'created_at': DateTime.now().toIso8601String(),
//     });
//   }

//   // ... other notification methods ...

//   Future<List<MyNotification.Notification>> getNotificationsForUser(
//       int userId) async {
//     final data = await _dbHelper.getNotificationsForUser(userId);
//     return data
//         .map((json) => MyNotification.Notification.fromJson(json))
//         .toList();
//   }

//   @override
//   void onClose() {
//     selectNotificationSubject.close();
//     super.onClose();
//   }
// }
