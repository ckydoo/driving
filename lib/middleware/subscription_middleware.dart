import 'package:driving/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SubscriptionMiddleware extends GetMiddleware {
  final SubscriptionService _subscriptionService =
      Get.find<SubscriptionService>();

  @override
  RouteSettings? redirect(String? route) {
    // Allow access to subscription screen and auth screens
    final allowedRoutes = ['/subscription', '/login', '/register', '/'];

    if (allowedRoutes.contains(route)) {
      return null; // Allow access
    }

    // Check if user has valid subscription
    if (!_subscriptionService.canUseApp) {
      return RouteSettings(name: '/subscription');
    }

    return null; // Allow access
  }
}
