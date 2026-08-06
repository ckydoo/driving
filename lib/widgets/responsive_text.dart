import 'package:driving/widgets/responsive_extensions.dart';
import 'package:flutter/material.dart';

class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    Key? key,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.style = const TextStyle(),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return Text(
      text,
      style: themeStyle.copyWith(
        fontSize: fontSize != null
            ? context.responsiveFontSize(fontSize!)
            : style.fontSize,
        fontWeight: fontWeight ?? style.fontWeight,
        color: color ?? style.color,
        letterSpacing: style.letterSpacing,
        height: style.height,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
