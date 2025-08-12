// lib/utils/responsive_utils.dart
import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Screen breakpoints
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;

  // Check device types
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  // Get responsive values
  static T getValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }

  // Get responsive padding
  static EdgeInsets getPadding(BuildContext context) {
    return EdgeInsets.all(getValue(
      context,
      mobile: 12.0,
      tablet: 16.0,
      desktop: 20.0,
    ));
  }

  // Get responsive font size
  static double getFontSize(BuildContext context, double baseSize) {
    final multiplier = getValue(
      context,
      mobile: 0.9,
      tablet: 1.0,
      desktop: 1.0,
    );
    return baseSize * multiplier;
  }

  // Get responsive card width
  static double getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isMobile(context)) {
      return screenWidth - 24; // Full width minus padding
    } else if (isTablet(context)) {
      return (screenWidth - 48) / 2; // Two columns
    } else {
      return (screenWidth - 72) / 3; // Three columns
    }
  }

  // Get responsive grid columns
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  // Get responsive dialog width
  static double getDialogWidth(BuildContext context) {
    return getValue(
      context,
      mobile: MediaQuery.of(context).size.width * 0.95,
      tablet: 500.0,
      desktop: 600.0,
    );
  }

  // Get responsive button height
  static double getButtonHeight(BuildContext context) {
    return getValue(
      context,
      mobile: 48.0, // Touch-friendly height
      tablet: 44.0,
      desktop: 40.0,
    );
  }

  // Get responsive icon size
  static double getIconSize(BuildContext context, double baseSize) {
    return getValue(
      context,
      mobile: baseSize + 2,
      tablet: baseSize,
      desktop: baseSize,
    );
  }
}
