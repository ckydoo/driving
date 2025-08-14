import 'package:driving/controllers/utils/responsive_utils.dart';
import 'package:driving/widgets/responsive_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/services/text_formatter.dart';

class ResponsiveFormField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final bool enabled;
  final VoidCallback? onTap;
  final Function(String)? onChanged;

  const ResponsiveFormField({
    Key? key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.enabled = true,
    this.onTap,
    this.onChanged,
    required InputDecoration decoration,
    required List<FilteringTextInputFormatter> inputFormatters,
    required TextCapitalization textCapitalization,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      enabled: enabled,
      onTap: onTap,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: context.responsiveFontSize(16),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getValue(
            context,
            mobile: 12.0,
            tablet: 16.0,
            desktop: 16.0,
          ),
          vertical: ResponsiveUtils.getValue(
            context,
            mobile: 12.0,
            tablet: 14.0,
            desktop: 16.0,
          ),
        ),
      ),
    );
  }
}
