import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/mock_data_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);
    final students = MockDataService.students;
    final total = students.length;
    final present = students.where((s) => s.status == 'Active').length;
    final absent = total - present;
    final missing = students.where((s) => s.status != 'Active').toList();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Report',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          AppSpacing.gap16,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today’s Attendance Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                AppSpacing.gap12,
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _ReportChip(label: 'Total', value: total.toString()),
                    _ReportChip(label: 'Present', value: present.toString()),
                    _ReportChip(label: 'Absent', value: absent.toString()),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gap16,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missing Students',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                AppSpacing.gap12,
                if (missing.isEmpty)
                  Text(
                    'No missing students in this session.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                  )
                else
                  ListView.separated(
                    itemCount: missing.length,
                    separatorBuilder: (_, _) => const Divider(height: 24),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final student = missing[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accentOrange.withOpacity(0.14),
                          child: Text(student.name.substring(0, 1)),
                        ),
                        title: Text(student.name),
                        subtitle: Text(student.className),
                        trailing: Text(
                          student.status,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryFor(context),
                              ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.brandGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textSecondaryFor(context)),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
