// Replace your lib/controllers/utils/responsive_utils.dart with this fixed version

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

  // Get responsive padding - BIGGER for mobile
  static EdgeInsets getPadding(BuildContext context) {
    return EdgeInsets.all(getValue(
      context,
      mobile: 20.0, // Increased from 12.0
      tablet: 16.0,
      desktop: 20.0,
    ));
  }

  // FIXED: Get responsive font size - BIGGER for mobile
  static double getFontSize(BuildContext context, double baseSize) {
    final multiplier = getValue(
      context,
      mobile: 1.22, // CHANGED: Make mobile fonts 15% BIGGER
      tablet: 1.0,
      desktop: 1.0,
    );
    return baseSize * multiplier;
  }

  // Mobile-friendly font sizes for specific use cases
  static double getHeadingSize(BuildContext context) {
    return getValue(
      context,
      mobile: 24.0, // Big headings on mobile
      tablet: 22.0,
      desktop: 20.0,
    );
  }

  static double getSubheadingSize(BuildContext context) {
    return getValue(
      context,
      mobile: 20.0, // Big subheadings on mobile
      tablet: 18.0,
      desktop: 16.0,
    );
  }

  static double getBodyTextSize(BuildContext context) {
    return getValue(
      context,
      mobile: 16.0, // Readable body text on mobile
      tablet: 14.0,
      desktop: 14.0,
    );
  }

  static double getCaptionSize(BuildContext context) {
    return getValue(
      context,
      mobile: 14.0, // Readable captions on mobile
      tablet: 12.0,
      desktop: 12.0,
    );
  }

  // Get responsive card width
  static double getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isMobile(context)) {
      return screenWidth - 32; // Full width minus bigger padding
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

  // Get responsive button height - BIGGER for mobile
  static double getButtonHeight(BuildContext context) {
    return getValue(
      context,
      mobile: 56.0, // Bigger touch targets for mobile
      tablet: 44.0,
      desktop: 40.0,
    );
  }

  // Get responsive icon size - BIGGER for mobile
  static double getIconSize(BuildContext context, double baseSize) {
    return getValue(
      context,
      mobile: baseSize + 4, // Make mobile icons bigger
      tablet: baseSize,
      desktop: baseSize,
    );
  }

  // Get responsive spacing
  static double getSpacing(BuildContext context, {
    double mobile = 16,
    double tablet = 20,
    double desktop = 24,
  }) {
    return getValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  // Get responsive margin
  static EdgeInsets getMargin(BuildContext context) {
    return EdgeInsets.all(getValue(
      context,
      mobile: 16.0,
      tablet: 20.0,
      desktop: 24.0,
    ));
  }

  // Helper method for touch-friendly sizing
  static double getTouchTargetSize(BuildContext context) {
    return getValue(
      context,
      mobile: 56.0, // Large touch targets on mobile
      tablet: 48.0,
      desktop: 44.0,
    );
  }

  // Get responsive container padding
  static EdgeInsets getContainerPadding(BuildContext context) {
    return EdgeInsets.all(getValue(
      context,
      mobile: 20.0, // More padding on mobile
      tablet: 16.0,
      desktop: 16.0,
    ));
  }
}