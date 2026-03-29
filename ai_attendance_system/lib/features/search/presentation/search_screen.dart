import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/student.dart';
import '../../../shared/services/mock_data_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _classFilter = 'All';
  String _semesterFilter = 'All';
  String _batchFilter = 'All';
  String _groupFilter = 'All';

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
      final matchesSemester = _semesterFilter == 'All' || student.semester == _semesterFilter;
      final matchesBatch = _batchFilter == 'All' || student.batch == _batchFilter;
      final matchesGroup = _groupFilter == 'All' || student.group == _groupFilter;
      return matchesQuery && matchesClass && matchesSemester && matchesBatch && matchesGroup;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);
    final students = _filteredStudents();
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Students',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          AppSpacing.gap16,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Student name, ID, or email',
                  hintText: 'Type a name, ID, or email',
                  controller: _searchController,
                  prefixIcon: const Icon(Icons.search),
                  onChanged: (_) => setState(() {}),
                ),
                AppSpacing.gap16,
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 720;
                    final fields = [
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
                        onChanged: (value) =>
                            setState(() => _classFilter = value ?? 'All'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _semesterFilter,
                        decoration: const InputDecoration(labelText: 'Semester'),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(value: 'Spring', child: Text('Spring')),
                          DropdownMenuItem(value: 'Fall', child: Text('Fall')),
                        ],
                        onChanged: (value) =>
                            setState(() => _semesterFilter = value ?? 'All'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _batchFilter,
                        decoration: const InputDecoration(labelText: 'Batch'),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(value: '2024', child: Text('2024')),
                          DropdownMenuItem(value: '2023', child: Text('2023')),
                          DropdownMenuItem(value: '2022', child: Text('2022')),
                        ],
                        onChanged: (value) =>
                            setState(() => _batchFilter = value ?? 'All'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _groupFilter,
                        decoration: const InputDecoration(labelText: 'Group'),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(value: 'A', child: Text('Group A')),
                          DropdownMenuItem(value: 'B', child: Text('Group B')),
                          DropdownMenuItem(value: 'C', child: Text('Group C')),
                        ],
                        onChanged: (value) =>
                            setState(() => _groupFilter = value ?? 'All'),
                      ),
                    ];

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: fields[0]),
                          const SizedBox(width: 12),
                          Expanded(child: fields[1]),
                          const SizedBox(width: 12),
                          Expanded(child: fields[2]),
                          const SizedBox(width: 12),
                          Expanded(child: fields[3]),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        fields[0],
                        AppSpacing.gap12,
                        fields[1],
                        AppSpacing.gap12,
                        fields[2],
                        AppSpacing.gap12,
                        fields[3],
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
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.brandGreen.withOpacity(0.12),
                            child: Text(student.name.substring(0, 1)),
                          ),
                          title: Text(student.name),
                          subtitle: Text(
                            '${student.className} • ${student.semester} • ${student.batch} • ${student.group}',
                          ),
                          trailing: Text(
                            '${student.attendanceRate.toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryFor(context),
                                ),
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
