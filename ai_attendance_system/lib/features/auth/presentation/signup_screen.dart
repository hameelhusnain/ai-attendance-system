import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
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
                      'Create Account',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    AppSpacing.gap8,
                    Text(
                      'Join the AI Attendance System.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    AppSpacing.gap24,
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          AppTextField(
                            label: 'Full Name',
                            controller: _nameController,
                          ),
                          AppSpacing.gap16,
                          AppTextField(
                            label: 'Username',
                            controller: _usernameController,
                          ),
                          AppSpacing.gap16,
                          AppTextField(
                            label: 'Email (optional)',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            requiredField: false,
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
                            decoration: const InputDecoration(labelText: 'Role'),
                          ),
                          AppSpacing.gap16,
                          AppTextField(
                            label: 'Password',
                            controller: _passwordController,
                            isPassword: true,
                          ),
                          AppSpacing.gap16,
                          TextFormField(
                            controller: _confirmController,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Confirm Password'),
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
                    AppSpacing.gap16,
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('I already have an account'),
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
