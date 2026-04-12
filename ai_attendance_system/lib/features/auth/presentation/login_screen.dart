import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
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
    try {
      final rawInput = _emailController.text.trim();
      final token = await _apiService.login(
        rawInput,
        _passwordController.text,
      );
      if (!mounted) return;
      if (token.isNotEmpty) {
        SessionStore.token = token;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        SessionStore.displayName =
            rawInput.contains('@') ? rawInput.split('@').first : rawInput;
        context.go('/dashboard');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthSplitLayout(
      title: 'Welcome Back!',
      subtitle: 'Welcome to AI Attendance System, please login/sign in to continue.',
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
            if (_loading) ...[
              AppSpacing.gap12,
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Admin creates your account."),
        ],
      ),
    );
  }
}
