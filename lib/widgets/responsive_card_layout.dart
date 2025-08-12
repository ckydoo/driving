import 'package:driving/widgets/responsive_extensions.dart';
import 'package:flutter/material.dart';

class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double? elevation;
  final VoidCallback? onTap;
  final bool fullWidth;

  const ResponsiveCard({
    Key? key,
    required this.child,
    this.padding,
    this.color,
    this.elevation,
    this.onTap,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget card = Card(
      elevation: elevation ?? 2,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: padding ?? context.responsivePadding,
        child: child,
      ),
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: card,
      );
    }

    return card;
  }
}
