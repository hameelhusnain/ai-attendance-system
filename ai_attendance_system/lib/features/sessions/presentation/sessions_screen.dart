import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/services/mock_data_service.dart';
import '../../../shared/services/session_store.dart';
import 'session_detail_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> with SingleTickerProviderStateMixin {
  bool _running = false;
  int _markedCount = 0;
  bool _stopping = false;
  late final AnimationController _blobController;

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
    super.dispose();
  }

  void _startSession() {
    setState(() {
      _running = true;
      _markedCount = 0;
    });
  }

  Future<void> _stopSession() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _stopping = false;
      _running = false;
    });
    context.go('/reports');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);
    final sessions = MockDataService.sessions;
    final selectedClass = SessionStore.selectedClass;
    final className = _readValue(selectedClass, ['name', 'class_name', 'title'], '');
    final tutor = _readValue(selectedClass, [
      'tutor',
      'teacher',
      'teacher_name',
      'instructor',
      'assigned_teacher',
    ], '');
    final students = className.isEmpty
        ? const <dynamic>[]
        : MockDataService.students.where((s) => s.className == className).toList();

    return Stack(
      children: [
        SingleChildScrollView(
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
          if (className.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Session',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  AppSpacing.gap8,
                  Text(
                    className,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (tutor.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tutor: $tutor',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                    ),
                  ],
                ],
              ),
            ),
          if (className.isNotEmpty) AppSpacing.gap16,
          if (className.isNotEmpty)
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
                  AppSpacing.gap12,
                  if (students.isEmpty)
                    Text(
                      'No students found for this class.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                    )
                  else
                    ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.brandGreen.withOpacity(0.12),
                            child: Text(student.name.substring(0, 1)),
                          ),
                          title: Text(student.name),
                          subtitle: Text(student.email),
                        );
                      },
                    ),
                ],
              ),
            ),
          if (className.isNotEmpty) AppSpacing.gap20,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(
                      'Recent Closed Sessions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    AppSpacing.gap12,
                    if (sessions.isEmpty)
                      const EmptyState(
                        title: 'No recent sessions',
                        message: 'Closed sessions will appear here.',
                      )
                    else
                      ListView.separated(
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
                  ],
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
                      onTap: _stopping
                          ? null
                          : () => _running ? _stopSession() : _startSession(),
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
                      color:
                          _running ? AppTheme.brandGreen : AppTheme.textSecondaryFor(context),
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
        ),
        if (_stopping)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}

String _readValue(dynamic item, List<String> keys, String fallback) {
  if (item is Map<String, dynamic>) {
    for (final key in keys) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value != null) {
        return value.toString();
      }
    }
  }
  return fallback;
}

class _SessionButton extends StatelessWidget {
  const _SessionButton({required this.running, required this.onTap});

  final bool running;
  final VoidCallback? onTap;

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
