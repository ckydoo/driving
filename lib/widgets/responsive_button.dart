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
  final bool outlined;
  final bool compact;

  const ResponsiveButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.outlined = false,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget button;

    if (icon != null) {
      button = outlined
          ? OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          foregroundColor ??
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : Icon(icon, size: context.responsiveIconSize(18)),
              label: ResponsiveText(text,
                  fontSize: compact ? 14 : 16, style: TextStyle()),
              style: _getButtonStyle(context),
            )
          : ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          foregroundColor ??
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Icon(icon, size: context.responsiveIconSize(18)),
              label: ResponsiveText(text,
                  fontSize: compact ? 14 : 16, style: TextStyle()),
              style: _getButtonStyle(context),
            );
    } else {
      button = outlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: _getButtonStyle(context),
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          foregroundColor ??
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : ResponsiveText(text,
                      fontSize: compact ? 14 : 16, style: TextStyle()),
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: _getButtonStyle(context),
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          foregroundColor ??
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : ResponsiveText(text,
                      fontSize: compact ? 14 : 16, style: TextStyle()),
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
    final horizontalPadding = compact ? 12.0 : 16.0;
    final verticalPadding = compact ? 8.0 : 12.0;
    return (outlined ? OutlinedButton.styleFrom : ElevatedButton.styleFrom)(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: Size(0, compact ? 38 : context.responsiveButtonHeight),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getValue(
          context,
          mobile: horizontalPadding,
          tablet: horizontalPadding + 4,
          desktop: horizontalPadding + 6,
        ),
        vertical: ResponsiveUtils.getValue(
          context,
          mobile: verticalPadding,
          tablet: verticalPadding,
          desktop: verticalPadding - 1,
        ),
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 10 : 12)),
    );
  }
}
