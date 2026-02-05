import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.requiredField = true,
    this.validator,
  });

  final String label;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final bool requiredField;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
      ),
      validator: validator ??
          (value) {
            if (requiredField && (value == null || value.trim().isEmpty)) {
              return 'Required';
            }
            if ((value ?? '').isNotEmpty &&
                keyboardType == TextInputType.emailAddress &&
                !value!.contains('@')) {
              return 'Enter a valid email';
            }
            return null;
          },
    );
  }
}
