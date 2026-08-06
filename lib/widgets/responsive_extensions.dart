import 'package:driving/controllers/utils/responsive_utils.dart';
import 'package:flutter/material.dart';

extension ResponsiveContext on BuildContext {
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);

  EdgeInsets get responsivePadding => ResponsiveUtils.getPadding(this);

  double responsiveFontSize(double baseSize) =>
      ResponsiveUtils.getFontSize(this, baseSize);

  double get responsiveCardWidth => ResponsiveUtils.getCardWidth(this);
  int get responsiveGridColumns => ResponsiveUtils.getGridColumns(this);
  double get responsiveDialogWidth => ResponsiveUtils.getDialogWidth(this);
  double get responsiveButtonHeight => ResponsiveUtils.getButtonHeight(this);

  double responsiveIconSize(double baseSize) =>
      ResponsiveUtils.getIconSize(this, baseSize);
}
