import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../shared/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String _role = 'Student';

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await _authService.signup(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return AuthSplitLayout(
      title: 'Create Account',
      subtitle: 'Create your profile to access attendance insights.',
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(
              label: 'Full Name',
              hintText: 'Enter your full name',
              controller: _nameController,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            AppSpacing.gap16,
            AppTextField(
              label: 'Username',
              hintText: 'Choose a username',
              controller: _usernameController,
              prefixIcon: const Icon(Icons.account_circle_outlined),
            ),
            AppSpacing.gap16,
            AppTextField(
              label: 'Email (optional)',
              hintText: 'Enter your email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              requiredField: false,
              prefixIcon: const Icon(Icons.mail_outline),
            ),
            AppSpacing.gap16,
            DropdownButtonFormField<String>(
              initialValue: _role,
              items: const [
                DropdownMenuItem(value: 'Root', child: Text('Root')),
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                DropdownMenuItem(value: 'Student', child: Text('Student')),
              ],
              onChanged: (value) => setState(() => _role = value ?? 'Student'),
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            AppSpacing.gap16,
            AppTextField(
              label: 'Password',
              hintText: 'Create a password',
              controller: _passwordController,
              isPassword: true,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            AppSpacing.gap16,
            AppTextField(
              label: 'Confirm Password',
              hintText: 'Re-enter your password',
              controller: _confirmController,
              isPassword: true,
              prefixIcon: const Icon(Icons.lock_outline),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            AppSpacing.gap24,
            AppButton(
              label: _loading ? 'Creating...' : 'Create Account',
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Already have an account?'),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
