import 'package:driving/widgets/responsive_extensions.dart';
import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool applyPadding;

  const ResponsiveWrapper({
    Key? key,
    required this.child,
    this.padding,
    this.applyPadding = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!applyPadding) return child;

    return Padding(
      padding: padding ?? context.responsivePadding,
      child: child,
    );
  }
}
