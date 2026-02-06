import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.requiredField = true,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final bool requiredField;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
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
