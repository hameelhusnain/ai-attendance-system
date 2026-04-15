import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/services/api_service.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchController = TextEditingController();
  String _classFilter = 'All';
  String _statusFilter = 'All';
  bool _loading = true;
  List<Map<String, dynamic>> _students = const [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final response = await ApiService().getStudents();
      final students = _extractStudents(response);
      if (!mounted) return;
      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _students = const [];
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredStudents() {
    final query = _searchController.text.trim().toLowerCase();
    return _students.where((student) {
      final name =
          _readValue(student, const ['full_name', 'student_full_name', 'student_name', 'name'])
              .toLowerCase();
      final id = _readValue(student, const ['id', 'student_id']).toLowerCase();
      final email = _readValue(student, const ['email', 'student_email']).toLowerCase();
      final className = _readValue(
        student,
        const ['class_name', 'name', 'title'],
        nestedKeys: const ['class'],
      );
      final status = _readValue(student, const ['status', 'attendance_status']);

      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          id.contains(query) ||
          email.contains(query);
      final matchesClass = _classFilter == 'All' || className == _classFilter;
      final matchesStatus = _statusFilter == 'All' || status == _statusFilter;
      return matchesQuery && matchesClass && matchesStatus;
    }).toList();
  }

  List<String> _classOptions() {
    final values = _students
        .map((student) => _readValue(student, const ['class_name', 'name', 'title'],
            nestedKeys: const ['class']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<String> _statusOptions() {
    final values = _students
        .map((student) => _readValue(student, const ['status', 'attendance_status']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  @override
  Widget build(BuildContext context) {
    final students = _filteredStudents();
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);
    final classOptions = _classOptions();
    final statusOptions = _statusOptions();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Students',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                AppSpacing.gap16,
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 720;
                    final filters = [
                      DropdownButtonFormField<String>(
                        initialValue: _classFilter,
                        decoration: const InputDecoration(labelText: 'Class'),
                        items: classOptions
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _classFilter = value ?? 'All'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: statusOptions
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _statusFilter = value ?? 'All'),
                      ),
                    ];

                    final searchField = AppTextField(
                      label: 'Search',
                      hintText: 'Search name, ID, or email',
                      controller: _searchController,
                      prefixIcon: const Icon(Icons.search),
                      onChanged: (_) => setState(() {}),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(flex: 2, child: searchField),
                          const SizedBox(width: 12),
                          Expanded(child: filters[0]),
                          const SizedBox(width: 12),
                          Expanded(child: filters[1]),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        searchField,
                        AppSpacing.gap12,
                        filters[0],
                        AppSpacing.gap12,
                        filters[1],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          AppSpacing.gap16,
          Expanded(
            child: AppCard(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : students.isEmpty
                      ? const EmptyState(
                          title: 'No students found',
                          message: 'Try adjusting your filters or search query.',
                        )
                      : ListView.separated(
                          itemCount: students.length,
                          separatorBuilder: (_, _) => const Divider(height: 24),
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final name = _readValue(
                              student,
                              const ['full_name', 'student_full_name', 'student_name', 'name'],
                              fallback: 'Student',
                            );
                            final className = _readValue(
                              student,
                              const ['class_name', 'name', 'title'],
                              nestedKeys: const ['class'],
                            );
                            final email = _readValue(
                              student,
                              const ['email', 'student_email', 'roll_no'],
                            );
                            final status = _readValue(
                              student,
                              const ['status', 'attendance_status'],
                              fallback: 'Active',
                            );
                            final attendanceRate = _readDouble(
                              student,
                              const ['attendance_rate', 'rate'],
                            );
                            final studentId = _readValue(student, const ['id', 'student_id']);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.brandGreen.withOpacity(0.12),
                                child: Text(name.substring(0, 1).toUpperCase()),
                              ),
                              title: Text(name),
                              subtitle: Text(
                                [className, email].where((value) => value.isNotEmpty).join(' • '),
                              ),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _StatusChip(status: status),
                                  const SizedBox(height: 6),
                                  if (attendanceRate > 0)
                                    Text('${attendanceRate.toStringAsFixed(1)}%'),
                                ],
                              ),
                              onTap: studentId.isEmpty ? null : () => context.go('/students/$studentId'),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
      case 'present':
        color = AppTheme.brandGreen;
        break;
      case 'on leave':
      case 'pending':
        color = AppTheme.accentOrange;
        break;
      default:
        color = AppTheme.danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

List<Map<String, dynamic>> _extractStudents(dynamic response) {
  if (response is List) {
    return response.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  if (response is Map) {
    for (final key in const ['students', 'items', 'data']) {
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

double _readDouble(Map<String, dynamic> item, List<String> keys) {
  final value = _readValue(item, keys);
  return double.tryParse(value) ?? 0;
}
