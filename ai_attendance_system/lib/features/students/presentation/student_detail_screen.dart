import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/api_service.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _student;
  List<Map<String, dynamic>> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final api = ApiService();
    Map<String, dynamic>? student;
    List<Map<String, dynamic>> history = const [];

    try {
      final response = await api.getStudentById(widget.studentId);
      if (response is Map) {
        student = Map<String, dynamic>.from(response);
      }
    } catch (_) {}

    try {
      final response = await api.getStudentAttendanceHistory(widget.studentId);
      history = _extractHistory(response);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _student = student;
      _history = history;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final student = _student;
    if (student == null) {
      return Center(
        child: Text(
          'Student not found.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.textSecondaryFor(context)),
        ),
      );
    }

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
                    Expanded(child: _AttendanceCard(records: _history)),
                  ],
                );
              }
              return Column(
                children: [
                  _ProfileCard(student: student),
                  AppSpacing.gap16,
                  _AttendanceCard(records: _history),
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

  final Map<String, dynamic> student;

  @override
  Widget build(BuildContext context) {
    final name = _readValue(student, const ['name', 'student_name'], fallback: 'Student');
    final email = _readValue(student, const ['email', 'student_email']);
    final className = _readValue(
      student,
      const ['class_name', 'name', 'title'],
      nestedKeys: const ['class'],
    );
    final status = _readValue(student, const ['status', 'attendance_status'], fallback: 'Active');
    final attendanceRate = _readValue(student, const ['attendance_rate', 'rate']);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.brandGreen.withOpacity(0.12),
                child: Text(name.substring(0, 1).toUpperCase()),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (email.isNotEmpty) Text(email),
                  if (className.isNotEmpty) Text('Class: $className'),
                ],
              ),
            ],
          ),
          AppSpacing.gap16,
          Text('Status: $status'),
          if (attendanceRate.isNotEmpty) ...[
            AppSpacing.gap8,
            Text('Attendance: $attendanceRate%'),
          ],
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

  final List<Map<String, dynamic>> records;

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
            const Text('No recent attendance records.')
          else
            for (final record in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_readValue(record, const ['date', 'session_date'], fallback: 'Recent')),
                    Text(_readValue(record, const ['status', 'attendance_status'], fallback: '-')),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _extractHistory(dynamic response) {
  if (response is List) {
    return response.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  if (response is Map) {
    for (final key in const ['history', 'records', 'items', 'data']) {
      final value = response[key];
      if (value is List) {
        return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      }
    }
  }
  return const [];
}

String _readValue(
  Map<String, dynamic> item,
  List<String> keys, {
  List<String> nestedKeys = const ['student', 'class', 'data'],
  String fallback = '',
  int depth = 0,
}) {
  for (final key in keys) {
    final value = item[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  if (depth > 2) return fallback;
  for (final nestedKey in nestedKeys) {
    final nested = item[nestedKey];
    if (nested is Map) {
      final resolved = _readValue(
        Map<String, dynamic>.from(nested),
        keys,
        nestedKeys: nestedKeys,
        fallback: fallback,
        depth: depth + 1,
      );
      if (resolved.isNotEmpty) return resolved;
    }
  }
  return fallback;
}
