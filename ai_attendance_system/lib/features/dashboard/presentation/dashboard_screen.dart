import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_reveal.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/mock_data_service.dart';

class DashboardOverviewScreen extends StatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  State<DashboardOverviewScreen> createState() => _DashboardOverviewScreenState();
}

class _DashboardOverviewScreenState extends State<DashboardOverviewScreen> {
  final List<String> _filters = const ['Daily', 'Weekly', 'Monthly'];
  String _activeFilter = 'Weekly';

  @override
  Widget build(BuildContext context) {
    final summary = MockDataService.reportSummary;
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppReveal(
            child: Text(
              'Welcome back admin',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          AppSpacing.gap8,
          AppReveal(
            delay: const Duration(milliseconds: 80),
            child: Text(
              'Here is a quick look at today’s attendance activity.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondaryFor(context)),
            ),
          ),
          AppSpacing.gap16,
          AppReveal(
            delay: const Duration(milliseconds: 140),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  AppSpacing.gap12,
                  Wrap(
                    spacing: 10,
                    children: _filters.map((filter) {
                      final isSelected = _activeFilter == filter;
                      return ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _activeFilter = filter),
                        selectedColor: AppTheme.brandGreen.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.textPrimaryFor(context)
                              : AppTheme.textSecondaryFor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                  AppSpacing.gap16,
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderFor(context)),
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.brandGreen.withOpacity(0.18),
                          AppTheme.accentPurple.withOpacity(0.14),
                          AppTheme.accentOrange.withOpacity(0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Chart Placeholder ($_activeFilter)',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gap16,
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
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
          _RecentActivityCard(),
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
              color: AppTheme.brandGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.brandGreen),
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
                      color: AppTheme.brandGreen,
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
                              ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.time,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
