import 'package:driving/controllers/utils/responsive_utils.dart';
import 'package:driving/widgets/responsive_extensions.dart';
import 'package:flutter/material.dart';

class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? customShadows;

  const ResponsiveCard({
    Key? key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.customShadows,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          ResponsiveUtils.getValue(
            context,
            mobile: const EdgeInsets.all(12),
            tablet: const EdgeInsets.all(16),
            desktop: const EdgeInsets.all(20),
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        boxShadow: customShadows ??
            [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: child,
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double? spacing;
  final double? runSpacing;
  final double? childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing,
    this.runSpacing,
    this.childAspectRatio,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveUtils.getValue(
      context,
      mobile: mobileColumns ?? 1,
      tablet: tabletColumns ?? 2,
      desktop: desktopColumns ?? 3,
    );

    final aspectRatio = ResponsiveUtils.getValue(
      context,
      mobile: childAspectRatio ?? 1.2,
      tablet: childAspectRatio ?? 1.5,
      desktop: childAspectRatio ?? 1.8,
    );

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing ??
            ResponsiveUtils.getValue(
              context,
              mobile: 8.0,
              tablet: 12.0,
              desktop: 16.0,
            ),
        mainAxisSpacing: runSpacing ??
            ResponsiveUtils.getValue(
              context,
              mobile: 8.0,
              tablet: 12.0,
              desktop: 16.0,
            ),
        childAspectRatio: aspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

class ResponsiveFlexLayout extends StatelessWidget {
  final List<Widget> children;
  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final bool wrapOnMobile;
  final double spacing;

  const ResponsiveFlexLayout({
    Key? key,
    required this.children,
    this.direction = Axis.horizontal,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.wrapOnMobile = true,
    this.spacing = 16.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (context.isMobile && wrapOnMobile && direction == Axis.horizontal) {
      // On mobile, wrap horizontal layouts to vertical
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < children.length - 1 ? spacing : 0,
            ),
            child: child,
          );
        }).toList(),
      );
    }

    // Default flex layout
    return Flex(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        return Expanded(
          child: Padding(
            padding: direction == Axis.horizontal
                ? EdgeInsets.only(
                    right: index < children.length - 1 ? spacing : 0,
                  )
                : EdgeInsets.only(
                    bottom: index < children.length - 1 ? spacing : 0,
                  ),
            child: child,
          ),
        );
      }).toList(),
    );
  }
}

class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? mobile;
  final EdgeInsets? tablet;
  final EdgeInsets? desktop;

  const ResponsivePadding({
    Key? key,
    required this.child,
    this.mobile,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ResponsiveUtils.getValue(
        context,
        mobile: mobile ?? const EdgeInsets.all(12),
        tablet: tablet ?? const EdgeInsets.all(16),
        desktop: desktop ?? const EdgeInsets.all(20),
      ),
      child: child,
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Decoration? decoration;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final containerMaxWidth = maxWidth ??
        ResponsiveUtils.getValue(
          context,
          mobile: double.infinity,
          tablet: 800.0,
          desktop: 1200.0,
        );

    return Container(
      constraints: BoxConstraints(maxWidth: containerMaxWidth!),
      padding: padding ?? ResponsiveUtils.getPadding(context),
      margin: margin,
      decoration: decoration,
      child: child,
    );
  }
}

class ResponsiveWrap extends StatelessWidget {
  final List<Widget> children;
  final Axis direction;
  final WrapAlignment alignment;
  final double spacing;
  final double runSpacing;
  final WrapCrossAlignment crossAxisAlignment;

  const ResponsiveWrap({
    Key? key,
    required this.children,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.crossAxisAlignment = WrapCrossAlignment.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      direction: direction,
      alignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      spacing: ResponsiveUtils.getValue(
        context,
        mobile: spacing * 0.8,
        tablet: spacing,
        desktop: spacing * 1.2,
      ),
      runSpacing: ResponsiveUtils.getValue(
        context,
        mobile: runSpacing * 0.8,
        tablet: runSpacing,
        desktop: runSpacing * 1.2,
      ),
      children: children,
    );
  }
}

// Helper widget for responsive sections with consistent styling
class ResponsiveSection extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final bool showDivider;

  const ResponsiveSection({
    Key? key,
    this.title,
    required this.child,
    this.padding,
    this.margin,
    this.showDivider = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ??
          EdgeInsets.only(
            bottom: ResponsiveUtils.getValue(
              context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: padding ?? ResponsiveUtils.getPadding(context),
              child: Text(
                title!,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getValue(
                    context,
                    mobile: 18.0,
                    tablet: 20.0,
                    desktop: 22.0,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            SizedBox(
                height: ResponsiveUtils.getValue(
              context,
              mobile: 12.0,
              tablet: 16.0,
              desktop: 20.0,
            )),
          ],
          child,
          if (showDivider) ...[
            SizedBox(
                height: ResponsiveUtils.getValue(
              context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            )),
            Divider(
              color: Colors.grey[300],
              thickness: 1,
            ),
          ],
        ],
      ),
    );
  }
}
