import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, Ayaan',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Text('Role: Admin'),
                      ],
                    ),
                    IconButton(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.logout),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
                AppSpacing.gap24,
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth < 720 ? 1 : 3;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              physics: const NeverScrollableScrollPhysics(),
                              children: const [
                                _StatCard(title: "Today's Attendance", value: '86%'),
                                _StatCard(title: 'Total Students', value: '1,240'),
                                _StatCard(title: 'Reports', value: '28'),
                              ],
                            );
                          },
                        ),
                        AppSpacing.gap24,
                        AppButton(
                          label: 'Take Attendance',
                          onPressed: () {},
                        ),
                        AppSpacing.gap12,
                        AppButton(
                          label: 'Students',
                          onPressed: () {},
                          isPrimary: false,
                        ),
                        AppSpacing.gap12,
                        AppButton(
                          label: 'Reports',
                          onPressed: () {},
                          isPrimary: false,
                        ),
                        AppSpacing.gap12,
                        AppButton(
                          label: 'Settings',
                          onPressed: () {},
                          isPrimary: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          AppSpacing.gap12,
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
