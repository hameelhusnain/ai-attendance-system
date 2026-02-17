import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/models/attendance_record.dart';
import '../../../shared/models/student.dart';
import '../../../shared/services/mock_data_service.dart';

class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    final student = MockDataService.students.firstWhere(
      (item) => item.id == studentId,
      orElse: () => MockDataService.students.first,
    );
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);

    final records = MockDataService.attendanceRecords
        .where((record) => record.studentName == student.name)
        .toList();

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/students'),
                icon: const Icon(Icons.arrow_back),
              ),
              Text(
                'Student Profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          AppSpacing.gap16,
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _ProfileCard(student: student)),
                    const SizedBox(width: 16),
                    Expanded(child: _AttendanceCard(records: records)),
                  ],
                );
              }
              return Column(
                children: [
                  _ProfileCard(student: student),
                  AppSpacing.gap16,
                  _AttendanceCard(records: records),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF0E5F5C).withOpacity(0.12),
                child: Text(student.name.substring(0, 1)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(student.email),
                  Text('Class: ${student.className}'),
                ],
              ),
            ],
          ),
          AppSpacing.gap16,
          Text('Status: ${student.status}'),
          AppSpacing.gap8,
          Text('Attendance: ${student.attendanceRate.toStringAsFixed(1)}%'),
          AppSpacing.gap24,
          AppButton(
            label: 'Message Student',
            onPressed: () {},
            isPrimary: false,
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.records});

  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Attendance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          AppSpacing.gap12,
          if (records.isEmpty)
            const Text('No recent attendance records.'),
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(record.date),
                  Text(record.status),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
