// // lib/widgets/activity_tracker.dart - Tracks user activity for auto-logout
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../controllers/auth_controller.dart';

// class ActivityTracker extends StatefulWidget {
//   final Widget child;

//   const ActivityTracker({
//     Key? key,
//     required this.child,
//   }) : super(key: key);

//   @override
//   State<ActivityTracker> createState() => _ActivityTrackerState();
// }

// class _ActivityTrackerState extends State<ActivityTracker> {
//   AuthController? _authController;

//   @override
//   void initState() {
//     super.initState();
//     // Get auth controller if available
//     try {
//       _authController = Get.find<AuthController>();
//     } catch (e) {
//       print('ActivityTracker: AuthController not found - $e');
//     }
//   }

//   void _trackActivity() {
//     // Only track if user is logged in
//     if (_authController?.isLoggedIn.value == true) {
//       _authController?.resetInactivityTimer();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: _trackActivity,
//       onPanDown: (_) => _trackActivity(),
//       onScaleStart: (_) => _trackActivity(),
//       behavior: HitTestBehavior.translucent,
//       child: Listener(
//         onPointerDown: (_) => _trackActivity(),
//         onPointerMove: (_) => _trackActivity(),
//         onPointerUp: (_) => _trackActivity(),
//         child: NotificationListener<ScrollNotification>(
//           onNotification: (notification) {
//             _trackActivity();
//             return false;
//           },
//           child: widget.child,
//         ),
//       ),
//     );
//   }
// }
