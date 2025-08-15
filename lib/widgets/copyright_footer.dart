import 'package:flutter/material.dart';

class CopyrightFooter extends StatelessWidget {
  final Color? textColor;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final bool showBackground;

  const CopyrightFooter({
    super.key,
    this.textColor,
    this.fontSize = 12,
    this.padding,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTextColor = textColor ?? Colors.grey[600];
    final defaultPadding = padding ?? const EdgeInsets.all(16);

    final copyrightText = Text(
      '© ${DateTime.now().year} Siarhei Staravoitau. All rights reserved.',
      style: TextStyle(
        color: defaultTextColor,
        fontSize: fontSize,
      ),
      textAlign: TextAlign.center,
    );

    if (showBackground) {
      return Container(
        width: double.infinity,
        padding: defaultPadding,
        color: Colors.grey[50],
        child: copyrightText,
      );
    }

    return Padding(
      padding: defaultPadding,
      child: copyrightText,
    );
  }
}