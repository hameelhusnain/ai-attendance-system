import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../shared/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await _authService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return AuthSplitLayout(
      title: 'Welcome Back!',
      subtitle: 'Sign in to access your dashboard and manage attendance.',
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(
              label: 'Email or Username',
              hintText: 'Enter your email',
              controller: _emailController,
              keyboardType: TextInputType.text,
              prefixIcon: const Icon(Icons.mail_outline),
            ),
            AppSpacing.gap16,
            AppTextField(
              label: 'Password',
              hintText: 'Enter your password',
              controller: _passwordController,
              isPassword: true,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: const Icon(Icons.visibility_off_outlined),
            ),
            AppSpacing.gap12,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text('Forgot password?'),
              ),
            ),
            AppSpacing.gap8,
            AppButton(
              label: _loading ? 'Signing in...' : 'Sign In',
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Don't have an account?"),
          TextButton(
            onPressed: () => context.go('/signup'),
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }
}
