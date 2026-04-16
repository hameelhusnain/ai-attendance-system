import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/session_history.dart';
import '../../../shared/services/api_service.dart';
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
  bool _starting = false;
  String? _currentSessionId;
  late final AnimationController _blobController;
  late Future<List<Map<String, dynamic>>> _studentsFuture;
  late Future<List<SessionHistory>> _closedSessionsFuture;

  @override
  void initState() {
    super.initState();
    _blobController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
          ..repeat();
    _studentsFuture = _loadStudents();
    _closedSessionsFuture = _loadSessions();
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_starting || _running) return;
    final selectedClass = SessionStore.selectedClass ?? const <String, dynamic>{};
    final classId = _readValue(selectedClass, ['id', 'class_id', 'classId'], '');
    final className = _readValue(selectedClass, ['name', 'class_name', 'title'], '');
    final teacherId = _readValue(selectedClass, ['teacher_id', 'teacherId', 'tutor_id'], '');

    if (classId.isEmpty && className.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a class before starting a session.')),
      );
      return;
    }

    setState(() => _starting = true);
    try {
      final payload = <String, dynamic>{
        if (classId.isNotEmpty) 'class_id': classId,
        if (classId.isNotEmpty) 'classId': classId,
        if (className.isNotEmpty) 'class_name': className,
        if (className.isNotEmpty) 'name': className,
        if (teacherId.isNotEmpty) 'teacher_id': teacherId,
        if (teacherId.isNotEmpty) 'teacherId': teacherId,
      };
      final response = await ApiService().startSession(payload);
      final session = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      final sessionId = _nestedRead(
        session,
        const ['id', 'session_id'],
        nestedKeys: const ['data', 'session'],
      );

      if (!mounted) return;
      setState(() {
        _running = true;
        _markedCount = 0;
        _currentSessionId = sessionId.isEmpty ? null : sessionId;
        _starting = false;
      });
      SessionStore.currentSessionId = _currentSessionId;
      SessionStore.currentSession = session.isEmpty ? null : session;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session started successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start session: $error')),
      );
    }
  }

  Future<void> _stopSession() async {
    if (_stopping || _starting || !_running) return;
    setState(() => _stopping = true);
    try {
      if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
        await ApiService().endSession(_currentSessionId!);
        SessionStore.currentSessionId = _currentSessionId;
        final ended = await _waitForSessionEnd(_currentSessionId!);
        if (ended) {
          await _submitAttendance(_currentSessionId!);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _stopping = false;
        _running = false;
      });
      _closedSessionsFuture = _loadSessions();
      context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      setState(() => _stopping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not stop session: $error')),
      );
    }
  }

  Future<bool> _waitForSessionEnd(String sessionId) async {
    const maxAttempts = 5;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await ApiService().getSessionById(sessionId);
        if (response is Map) {
          final status = _nestedRead(
            Map<String, dynamic>.from(response),
            const ['status', 'session_status', 'state'],
            nestedKeys: const ['data', 'session'],
          ).toLowerCase();
          if (status.contains('end') || status.contains('closed') || status.contains('finish') || status.contains('complete')) {
            return true;
          }
        }
      } catch (_) {
        // ignore transient errors while polling
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }

  Future<void> _submitAttendance(String sessionId) async {
    try {
      await ApiService().submitAttendance(sessionId, <String, dynamic>{});
    } catch (_) {
      // Optional submission; continue even if backend does not require this call.
    }
  }

  Map<String, dynamic> _classQueryParameters() {
    final selectedClass = SessionStore.selectedClass ?? const <String, dynamic>{};
    final query = <String, dynamic>{};
    final classId = _readValue(selectedClass, ['id', 'class_id', 'classId'], '');
    final className = _readValue(selectedClass, ['name', 'class_name', 'title'], '');
    final teacherId = _readValue(selectedClass, ['teacher_id', 'teacherId', 'tutor_id'], '');
    if (classId.isNotEmpty) {
      query['class_id'] = classId;
      query['classId'] = classId;
    }
    if (className.isNotEmpty) {
      query['class_name'] = className;
      query['name'] = className;
    }
    if (teacherId.isNotEmpty) {
      query['teacher_id'] = teacherId;
      query['teacherId'] = teacherId;
    }
    return query;
  }

  Future<List<Map<String, dynamic>>> _loadStudents() async {
    final api = ApiService();
    final query = _classQueryParameters();
    dynamic response;

    try {
      response = await api.getStudentsFiltered(queryParameters: query);
    } catch (_) {
      try {
        response = await api.getStudents();
      } catch (_) {
        return const [];
      }
    }

    final raw = _extractList(response, const ['students', 'items', 'data']);
    final students = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (students.isEmpty) return const [];

    final selectedClass = SessionStore.selectedClass ?? const <String, dynamic>{};
    final classId = _readValue(selectedClass, ['id', 'class_id', 'classId'], '');
    final className = _readValue(selectedClass, ['name', 'class_name', 'title'], '');

    final filtered = students.where((student) {
      final studentClassId = _nestedRead(
        student,
        const ['class_id', 'classId', 'id'],
        nestedKeys: const ['class'],
      );
      final studentClassName = _nestedRead(
        student,
        const ['class_name', 'name', 'title'],
        nestedKeys: const ['class'],
      );
      if (classId.isNotEmpty && studentClassId == classId) return true;
      if (className.isNotEmpty &&
          studentClassName.toLowerCase() == className.toLowerCase()) {
        return true;
      }
      return query.isEmpty;
    }).toList();

    return filtered.isNotEmpty ? filtered : students;
  }

  Future<List<SessionHistory>> _loadSessions() async {
    final api = ApiService();
    final query = {
      ..._classQueryParameters(),
      'status': 'closed',
      'is_closed': 'true',
    };
    dynamic response;

    try {
      response = await api.getSessionsFiltered(queryParameters: query);
    } catch (_) {
      try {
        response = await api.getSessions();
      } catch (_) {
        return const [];
      }
    }

    final raw = _extractList(response, const ['sessions', 'items', 'data']);
    return raw
        .whereType<Map>()
        .map((item) => _sessionHistoryFromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);
    final selectedClass = SessionStore.selectedClass;
    final className = _readValue(selectedClass, ['name', 'class_name', 'title'], '');
    final tutor = _readValue(selectedClass, [
      'tutor',
      'teacher',
      'teacher_name',
      'instructor',
      'assigned_teacher',
    ], '');

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
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _studentsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final students = snapshot.data ?? const [];
                      if (students.isEmpty) {
                        return Text(
                          'No students found for this class.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                        );
                      }
                      return ListView.separated(
                        itemCount: students.length,
                        separatorBuilder: (_, _) => const Divider(height: 24),
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final name = _nestedRead(
                            student,
                            const ['full_name', 'student_full_name', 'student_name', 'name'],
                            fallback: 'Student',
                          );
                          final email = _nestedRead(
                            student,
                            const ['email', 'student_email', 'roll_no', 'id'],
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.brandGreen.withOpacity(0.12),
                              child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase()),
                            ),
                            title: Text(name),
                            subtitle: email.isEmpty ? null : Text(email),
                          );
                        },
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
                    FutureBuilder<List<SessionHistory>>(
                      future: _closedSessionsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final sessions = snapshot.data ?? const [];
                        if (sessions.isEmpty) {
                          return const EmptyState(
                            title: 'No recent sessions',
                            message: 'Closed sessions will appear here.',
                          );
                        }
                        return ListView.separated(
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
                      onTap: (_stopping || _starting)
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
                                : _starting
                                    ? 'Creating session...'
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
        if (_stopping || _starting)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 12),
                    Text(
                      _starting ? 'Starting session...' : 'Stopping session...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
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

String _nestedRead(
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
      final resolved = _nestedRead(
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

List<dynamic> _extractList(dynamic response, List<String> keys) {
  if (response is List) return response;
  if (response is Map) {
    for (final key in keys) {
      final value = response[key];
      if (value is List) return value;
    }
  }
  return const [];
}

SessionHistory _sessionHistoryFromMap(Map<String, dynamic> item) {
  final marked = int.tryParse(
        _nestedRead(item, const ['marked', 'present', 'present_count'], fallback: '0'),
      ) ??
      0;
  final total = int.tryParse(
        _nestedRead(item, const ['total', 'total_students', 'student_count'], fallback: '0'),
      ) ??
      0;
  return SessionHistory(
    id: _nestedRead(item, const ['id', 'session_id'], fallback: 'session'),
    label: _nestedRead(item, const ['date', 'session_date', 'created_at'], fallback: 'Recent'),
    title: _nestedRead(item, const ['title', 'name', 'label'], fallback: 'Session'),
    className: _nestedRead(item, const ['class_name', 'name', 'title'],
        nestedKeys: const ['class'], fallback: 'Class'),
    department: _nestedRead(item, const ['department', 'department_name'],
        fallback: 'Department'),
    semester: _nestedRead(item, const ['semester'], fallback: '-'),
    batch: _nestedRead(item, const ['batch'], fallback: '-'),
    group: _nestedRead(item, const ['group', 'section'], fallback: '-'),
    marked: marked,
    total: total,
  );
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
