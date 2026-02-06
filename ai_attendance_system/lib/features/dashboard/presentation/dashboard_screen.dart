import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/mock_data_service.dart';

class DashboardOverviewScreen extends StatelessWidget {
  const DashboardOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = MockDataService.reportSummary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          AppSpacing.gap16,
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width > 1200
                  ? 4
                  : width > 900
                      ? 3
                      : width > 600
                          ? 2
                          : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.4,
                children: [
                  _KpiCard(
                    label: "Today's Attendance",
                    value: '${summary.attendanceRate.toStringAsFixed(1)}%',
                    icon: Icons.check_circle_outline,
                  ),
                  _KpiCard(
                    label: 'Total Students',
                    value: summary.totalStudents.toString(),
                    icon: Icons.people_alt_outlined,
                  ),
                  _KpiCard(
                    label: 'Reports Generated',
                    value: summary.reportsGenerated.toString(),
                    icon: Icons.bar_chart_outlined,
                  ),
                  const _KpiCard(
                    label: 'Active Classes',
                    value: '18',
                    icon: Icons.class_outlined,
                  ),
                ],
              );
            },
          ),
          AppSpacing.gap24,
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _RecentActivityCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _QuickActionsCard()),
                  ],
                );
              }
              return Column(
                children: [
                  _RecentActivityCard(),
                  AppSpacing.gap16,
                  _QuickActionsCard(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0E5F5C).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0E5F5C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          AppSpacing.gap12,
          for (final item in MockDataService.recentActivity)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 10,
                    width: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0E5F5C),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                )),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: const Color(0xFF7D8CA1)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.time,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFF7D8CA1)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          AppSpacing.gap16,
          AppButton(
            label: 'Take Attendance',
            onPressed: () => context.go('/attendance'),
          ),
          AppSpacing.gap12,
          AppButton(
            label: 'View Students',
            onPressed: () => context.go('/students'),
            isPrimary: false,
          ),
          AppSpacing.gap12,
          AppButton(
            label: 'View Reports',
            onPressed: () => context.go('/reports'),
            isPrimary: false,
          ),
        ],
      ),
    );
  }
}
