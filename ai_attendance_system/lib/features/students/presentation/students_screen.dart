import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/student.dart';
import '../../../shared/services/mock_data_service.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchController = TextEditingController();
  String _classFilter = 'All';
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Student> _filteredStudents() {
    final query = _searchController.text.trim().toLowerCase();
    return MockDataService.students.where((student) {
      final matchesQuery = query.isEmpty ||
          student.name.toLowerCase().contains(query) ||
          student.id.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query);
      final matchesClass = _classFilter == 'All' || student.className == _classFilter;
      final matchesStatus = _statusFilter == 'All' || student.status == _statusFilter;
      return matchesQuery && matchesClass && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final students = _filteredStudents();
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
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(value: 'CS-301', child: Text('CS-301')),
                          DropdownMenuItem(value: 'CS-302', child: Text('CS-302')),
                          DropdownMenuItem(value: 'CS-303', child: Text('CS-303')),
                          DropdownMenuItem(value: 'CS-304', child: Text('CS-304')),
                          DropdownMenuItem(value: 'CS-305', child: Text('CS-305')),
                        ],
                        onChanged: (value) => setState(() => _classFilter = value ?? 'All'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(value: 'Active', child: Text('Active')),
                          DropdownMenuItem(value: 'On Leave', child: Text('On Leave')),
                          DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                        ],
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
              child: students.isEmpty
                  ? const EmptyState(
                      title: 'No students found',
                      message: 'Try adjusting your filters or search query.',
                    )
                  : ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0E5F5C).withOpacity(0.12),
                            child: Text(student.name.substring(0, 1)),
                          ),
                          title: Text(student.name),
                          subtitle: Text('${student.className} • ${student.email}'),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StatusChip(status: student.status),
                              const SizedBox(height: 6),
                              Text('${student.attendanceRate.toStringAsFixed(1)}%'),
                            ],
                          ),
                          onTap: () => context.go('/students/${student.id}'),
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
    switch (status) {
      case 'Active':
        color = const Color(0xFF0E5F5C);
        break;
      case 'On Leave':
        color = const Color(0xFFE0A800);
        break;
      default:
        color = const Color(0xFFB00020);
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
