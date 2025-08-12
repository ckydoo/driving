import 'package:driving/controllers/utils/responsive_utils.dart';
import 'package:driving/widgets/responsive_extensions.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:flutter/material.dart';

class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const ResponsiveButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget button;

    if (icon != null) {
      button = ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: context.responsiveIconSize(18)),
        label: ResponsiveText(text, fontSize: 16),
        style: _getButtonStyle(context),
      );
    } else {
      button = ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: _getButtonStyle(context),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ResponsiveText(text, fontSize: 16),
      );
    }

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: Size(0, context.responsiveButtonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getValue(
          context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        ),
        vertical: ResponsiveUtils.getValue(
          context,
          mobile: 12.0,
          tablet: 8.0,
          desktop: 8.0,
        ),
      ),
    );
  }
}
