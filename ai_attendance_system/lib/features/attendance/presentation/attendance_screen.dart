import 'package:flutter/material.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/mock_data_service.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final records = MockDataService.attendanceRecords;
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(
                      width: 180,
                      child: AppButton(
                        label: 'Take Attendance',
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                AppSpacing.gap12,
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: const [
                    _FilterChip(label: 'Today'),
                    _FilterChip(label: 'This Week'),
                    _FilterChip(label: 'CS-301'),
                    _FilterChip(label: 'CS-302'),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gap16,
          Expanded(
            child: AppCard(
              child: ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, _) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final record = records[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0E5F5C).withOpacity(0.12),
                      child: Text(record.studentName.substring(0, 1)),
                    ),
                    title: Text(record.studentName),
                    subtitle: Text('${record.className} • ${record.date}'),
                    trailing: _StatusBadge(status: record.status),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFF0E5F5C).withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'Present' ? const Color(0xFF0E5F5C) : const Color(0xFFB00020);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
