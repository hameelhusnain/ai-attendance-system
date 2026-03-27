import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? const [
            Color(0xFF0B0B10),
            Color(0xFF12141C),
            Color(0xFF0D0F16),
          ]
        : const [
            Color(0xFFF7F8FB),
            Color(0xFFEFF2F7),
            Color(0xFFF7F8FB),
          ];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}
