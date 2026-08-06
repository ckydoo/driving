import 'package:flutter/material.dart';

class UIHelper {
  static Color getProgressColor(double progress) {
    if (progress >= 80) {
      return Colors.green;
    } else if (progress >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
