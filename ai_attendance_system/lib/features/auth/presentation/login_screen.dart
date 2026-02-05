import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
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
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Attendance System',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    AppSpacing.gap8,
                    Text(
                      'Welcome back. Sign in to continue.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    AppSpacing.gap24,
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          AppTextField(
                            label: 'Email or Username',
                            controller: _emailController,
                            keyboardType: TextInputType.text,
                          ),
                          AppSpacing.gap16,
                          AppTextField(
                            label: 'Password',
                            controller: _passwordController,
                            isPassword: true,
                          ),
                          AppSpacing.gap24,
                          AppButton(
                            label: _loading ? 'Signing in...' : 'Login',
                            onPressed: _loading ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gap16,
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
