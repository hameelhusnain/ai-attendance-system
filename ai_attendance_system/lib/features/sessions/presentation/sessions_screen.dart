import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/session_history.dart';
import '../../../shared/services/mock_data_service.dart';
import 'session_detail_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> with SingleTickerProviderStateMixin {
  bool _running = false;
  int _markedCount = 0;
  late final AnimationController _blobController;
  final _searchController = TextEditingController();
  String _classFilter = 'All';
  String _semesterFilter = 'All';
  String _batchFilter = 'All';
  String _groupFilter = 'All';
  String _departmentFilter = 'All';

  @override
  void initState() {
    super.initState();
    _blobController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
          ..repeat();
  }

  @override
  void dispose() {
    _blobController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSession() {
    setState(() {
      _running = !_running;
      if (_running) {
        _markedCount = 0;
      }
    });
  }

  List<SessionHistory> _filteredSessions() {
    final query = _searchController.text.trim().toLowerCase();
    return MockDataService.sessions.where((session) {
      final matchesQuery = query.isEmpty ||
          session.title.toLowerCase().contains(query) ||
          session.className.toLowerCase().contains(query) ||
          session.department.toLowerCase().contains(query) ||
          session.label.toLowerCase().contains(query);
      final matchesClass = _classFilter == 'All' || session.className == _classFilter;
      final matchesSemester =
          _semesterFilter == 'All' || session.semester == _semesterFilter;
      final matchesBatch = _batchFilter == 'All' || session.batch == _batchFilter;
      final matchesGroup = _groupFilter == 'All' || session.group == _groupFilter;
      final matchesDepartment =
          _departmentFilter == 'All' || session.department == _departmentFilter;
      return matchesQuery &&
          matchesClass &&
          matchesSemester &&
          matchesBatch &&
          matchesGroup &&
          matchesDepartment;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);
    final sessions = _filteredSessions();

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sessions',
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
                  'Search Sessions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                AppSpacing.gap16,
                AppTextField(
                  label: 'Search by class, title, or department',
                  hintText: 'Type a session label or class',
                  controller: _searchController,
                  prefixIcon: const Icon(Icons.search),
                  onChanged: (_) => setState(() {}),
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
                      DropdownButtonFormField<String>(
                        initialValue: _departmentFilter,
                        decoration: const InputDecoration(labelText: 'Department'),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(
                              value: 'Computer Science', child: Text('Computer Science')),
                          DropdownMenuItem(value: 'IT', child: Text('IT')),
                          DropdownMenuItem(value: 'SE', child: Text('Software Eng')),
                        ],
                        onChanged: (value) =>
                            setState(() => _departmentFilter = value ?? 'All'),
                      ),
                    ];

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: filters[0]),
                          const SizedBox(width: 12),
                          Expanded(child: filters[1]),
                          const SizedBox(width: 12),
                          Expanded(child: filters[2]),
                          const SizedBox(width: 12),
                          Expanded(child: filters[3]),
                          const SizedBox(width: 12),
                          Expanded(child: filters[4]),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        filters[0],
                        AppSpacing.gap12,
                        filters[1],
                        AppSpacing.gap12,
                        filters[2],
                        AppSpacing.gap12,
                        filters[3],
                        AppSpacing.gap12,
                        filters[4],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          AppSpacing.gap16,
          AppCard(
            child: sessions.isEmpty
                ? const EmptyState(
                    title: 'No sessions found',
                    message: 'Try adjusting your filters or search query.',
                  )
                : ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const Divider(height: 24),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(session.title),
                        subtitle: Text(
                          '${session.className} • ${session.semester} • ${session.batch} • ${session.group}',
                        ),
                        trailing: Text(
                          '${session.percentage.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryFor(context),
                              ),
                        ),
                        onTap: () => context.go(
                          '/sessions/${session.id}',
                          extra: SessionDetailArgs(session: session),
                        ),
                      );
                    },
                  ),
          ),
          AppSpacing.gap20,
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _AnimatedBlob(controller: _blobController),
                _SessionButton(
                  running: _running,
                  onTap: _toggleSession,
                ),
              ],
            ),
          ),
          AppSpacing.gap16,
          AppCard(
            child: Row(
              children: [
                Icon(
                  _running ? Icons.videocam : Icons.videocam_off,
                  color: _running ? AppTheme.brandGreen : AppTheme.textSecondaryFor(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _running ? 'Session running' : 'Session stopped',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        _running
                            ? 'Camera active • Attendance counting in progress'
                            : 'Press start to begin marking attendance',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (_running ? AppTheme.brandGreen : AppTheme.accentOrange)
                        .withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _markedCount.toString(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Marked',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                      ),
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

class _SessionButton extends StatelessWidget {
  const _SessionButton({required this.running, required this.onTap});

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = running ? AppTheme.accentOrange : AppTheme.brandGreen;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        height: 140,
        width: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            running ? 'Stop' : 'Start',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBlob extends StatelessWidget {
  const _AnimatedBlob({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value * 2 * pi;
        final dx = sin(t) * 18;
        final dy = cos(t * 0.8) * 16;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glowGreen = AppTheme.brandGreen.withOpacity(isDark ? 0.28 : 0.18);
        final glowOrange = AppTheme.accentOrange.withOpacity(isDark ? 0.22 : 0.14);
        return Transform.translate(
          offset: Offset(dx, dy),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: isDark ? 22 : 16, sigmaY: isDark ? 22 : 16),
              child: Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: isDark
                        ? [
                            glowGreen,
                            glowOrange,
                            Colors.transparent,
                          ]
                        : [
                            glowGreen,
                            glowOrange,
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
