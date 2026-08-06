import 'package:driving/widgets/responsive_extensions.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:flutter/material.dart';

class ResponsiveDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final bool scrollable;

  const ResponsiveDialog({
    Key? key,
    required this.title,
    required this.content,
    this.actions,
    this.scrollable = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      // Full screen dialog for mobile
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: ResponsiveText(
              title,
              fontSize: 18,
              style: TextStyle(),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: actions?.map((action) {
              if (action is TextButton || action is ElevatedButton) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: action,
                );
              }
              return action;
            }).toList(),
          ),
          body: Padding(
            padding: context.responsivePadding,
            child: scrollable ? SingleChildScrollView(child: content) : content,
          ),
        ),
      );
    } else {
      // Regular dialog for tablet/desktop
      return AlertDialog(
        title: ResponsiveText(title,
            fontSize: 18, style: TextStyle(), fontWeight: FontWeight.bold),
        content: Container(
          width: context.responsiveDialogWidth,
          child: scrollable ? SingleChildScrollView(child: content) : content,
        ),
        actions: actions,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }
  }

  // Helper method to show the dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    bool scrollable = false,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => ResponsiveDialog(
        title: title,
        content: content,
        actions: actions,
        scrollable: scrollable,
      ),
    );
  }
}
