import 'package:flutter/material.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/mock_data_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = MockDataService.reportSummary;
    final reports = MockDataService.reports;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final cards = [
                _SummaryCard(title: 'Present', value: '${summary.attendanceRate.toStringAsFixed(1)}%'),
                _SummaryCard(title: 'Absent', value: '${summary.absentRate.toStringAsFixed(1)}%'),
                _SummaryCard(title: 'Total Students', value: summary.totalStudents.toString()),
              ];

              if (isWide) {
                return Row(
                  children: [
                    for (final card in cards) ...[
                      Expanded(child: card),
                      if (card != cards.last) const SizedBox(width: 16),
                    ],
                  ],
                );
              }

              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    AppSpacing.gap12,
                  ],
                ],
              );
            },
          ),
          AppSpacing.gap16,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Trend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                AppSpacing.gap12,
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E5F5C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1E6EE)),
                  ),
                  child: const Center(child: Text('Chart Placeholder')),
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
                  'Generated Reports',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                AppSpacing.gap12,
                for (final report in reports)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.title,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    )),
                            Text(report.date,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: const Color(0xFF7D8CA1))),
                          ],
                        ),
                        _StatusChip(status: report.status),
                      ],
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});

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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'Ready' ? const Color(0xFF0E5F5C) : const Color(0xFFE0A800);
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
