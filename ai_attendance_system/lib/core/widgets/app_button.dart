import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return SizedBox(
        height: 48,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
