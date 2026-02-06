import 'package:flutter/material.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF0E5F5C),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin User',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Text('admin@campus.edu'),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gap16,
          AppCard(
            child: Column(
              children: const [
                _SettingsTile(
                  title: 'Profile',
                  subtitle: 'Update personal information',
                ),
                Divider(height: 24),
                _SettingsTile(
                  title: 'Notifications',
                  subtitle: 'Manage notification preferences',
                ),
                Divider(height: 24),
                _SettingsTile(
                  title: 'Theme',
                  subtitle: 'Light mode (coming soon)',
                ),
                Divider(height: 24),
                _SettingsTile(
                  title: 'Security',
                  subtitle: 'Change password and security options',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
