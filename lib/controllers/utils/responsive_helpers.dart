// Create this as lib/utils/responsive_helpers.dart

import 'package:flutter/material.dart';

class ResponsiveHelpers {
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

  // Safe top bar height that accounts for system UI
  static double getTopBarHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;

    if (isMobile(context)) {
      // Mobile: Base height + safe area
      return 56 + statusBarHeight;
    } else {
      // Desktop/Tablet: Fixed height
      return 64;
    }
  }

  // Get safe content height (screen height minus topbar and system UI)
  static double getContentHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topBarHeight = getTopBarHeight(context);
    final bottomPadding = mediaQuery.padding.bottom;

    return screenHeight - topBarHeight - bottomPadding;
  }

  // Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double mobile = 16,
    double tablet = 24,
    double desktop = 32,
  }) {
    if (isMobile(context)) {
      return EdgeInsets.all(mobile);
    } else if (isTablet(context)) {
      return EdgeInsets.all(tablet);
    } else {
      return EdgeInsets.all(desktop);
    }
  }

  // Get responsive font size
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    if (isMobile(context)) {
      return baseSize * 0.9; // 10% smaller on mobile
    } else {
      return baseSize;
    }
  }

  // Create a safe container that prevents overflow
  static Widget safeContainer({
    required Widget child,
    EdgeInsets? padding,
    Color? color,
    double? height,
    double? width,
  }) {
    return Container(
      padding: padding,
      color: color,
      height: height,
      width: width,
      constraints: BoxConstraints(
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: 0,
        maxHeight: double.infinity,
      ),
      child: child,
    );
  }

  // Create responsive text that automatically handles overflow
  static Widget responsiveText(
      String text, {
        required BuildContext context,
        double fontSize = 14,
        FontWeight? fontWeight,
        Color? color,
        TextAlign? textAlign,
        int? maxLines,
      }) {
    return Text(
      text,
      style: TextStyle(
        fontSize: getResponsiveFontSize(context, fontSize),
        fontWeight: fontWeight,
        color: color,
      ),
      textAlign: textAlign,
      maxLines: maxLines ?? (isMobile(context) ? 2 : 1),
      overflow: TextOverflow.ellipsis,
    );
  }

  // Create responsive row that stacks on mobile if needed
  static Widget responsiveRow({
    required List<Widget> children,
    required BuildContext context,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    bool forceColumn = false,
  }) {
    if (isMobile(context) || forceColumn) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    } else {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }
  }

  // Get responsive icon size
  static double getIconSize(BuildContext context, {double base = 24}) {
    if (isMobile(context)) {
      return base;
    } else {
      return base * 0.9;
    }
  }

  // Create constrained action buttons for topbars
  static Widget constrainedIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    double size = 20,
    Color? color,
  }) {
    return Container(
      width: 44,
      height: 44,
      child: IconButton(
        icon: Icon(icon, size: size, color: color),
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: BoxConstraints.tight(Size(44, 44)),
      ),
    );
  }

  // Get maximum container width for content
  static double getMaxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isMobile(context)) {
      return screenWidth; // Full width on mobile
    } else if (isTablet(context)) {
      return screenWidth * 0.95; // 95% on tablet
    } else {
      return 1200; // Max width on desktop
    }
  }

  // Check if screen is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // Get safe horizontal margins
  static EdgeInsets getHorizontalMargins(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.symmetric(horizontal: 16);
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 32);
    } else {
      return EdgeInsets.symmetric(horizontal: 48);
    }
  }
}