import 'package:driving/widgets/responsive_extensions.dart';
import 'package:flutter/material.dart';

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final EdgeInsets? padding;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? context.responsivePadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = context.responsiveGridColumns;
          final itemWidth =
              (constraints.maxWidth - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: children.map((child) {
              return SizedBox(
                width: columns == 1 ? constraints.maxWidth : itemWidth,
                child: child,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
