import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/session_store.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen>
    with SingleTickerProviderStateMixin {
  bool _running = false;
  bool _starting = false;
  bool _stopping = false;
  bool _syncingSession = true;
  bool _studentsPanelOpen = false;
  int _markedCount = 0;
  String? _currentSessionId;
  late final AnimationController _blobController;
  late Future<List<Map<String, dynamic>>> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _studentsFuture = _loadStudents();

    final cachedSessionId = SessionStore.currentSessionId;
    if (cachedSessionId != null && cachedSessionId.isNotEmpty) {
      _running = true;
      _currentSessionId = cachedSessionId;
      _markedCount = _extractMarkedCount(SessionStore.currentSession);
    }

    _syncSessionState();
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  Future<void> _syncSessionState() async {
    if (mounted) {
      setState(() => _syncingSession = true);
    }

    try {
      final activeSession = await _findActiveSession(
        preferredSessionId: _currentSessionId ?? SessionStore.currentSessionId,
      );

      if (!mounted) return;

      if (activeSession != null) {
        final sessionId = _sessionIdOf(activeSession);
        setState(() {
          _running = true;
          _currentSessionId = sessionId;
          _markedCount = _extractMarkedCount(activeSession);
        });
        await SessionStore.saveCurrentSession(
          sessionId: sessionId,
          session: activeSession,
        );
      } else {
        setState(() {
          _running = false;
          _currentSessionId = null;
          _markedCount = 0;
        });
        await SessionStore.clearCurrentSession();
      }
    } finally {
      if (mounted) {
        setState(() => _syncingSession = false);
      }
    }
  }

  Future<void> _startSession() async {
    if (_starting || _stopping || _syncingSession || _running) return;

    final selectedClass =
        SessionStore.selectedClass ?? const <String, dynamic>{};
    final classId = _readValue(selectedClass, [
      'id',
      'class_id',
      'classId',
    ], '');
    final className = _readValue(selectedClass, [
      'name',
      'class_name',
      'title',
    ], '');
    final teacherId = _readValue(selectedClass, [
      'teacher_id',
      'teacherId',
      'tutor_id',
    ], '');

    if (classId.isEmpty && className.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a class before starting a session.'),
        ),
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
      final resolvedSession = _extractSessionMap(response);
      var sessionId = _sessionIdOf(resolvedSession);

      if (sessionId.isEmpty) {
        final activeSession = await _findActiveSession();
        if (activeSession != null) {
          sessionId = _sessionIdOf(activeSession);
        }
      }

      if (sessionId.isEmpty) {
        throw StateError('Session started but no session id was returned.');
      }

      await SessionStore.saveCurrentSession(
        sessionId: sessionId,
        session: resolvedSession ?? SessionStore.currentSession,
      );

      if (!mounted) return;

      setState(() {
        _running = true;
        _starting = false;
        _currentSessionId = sessionId;
        _markedCount = _extractMarkedCount(
          resolvedSession ?? SessionStore.currentSession,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session started successfully.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _starting = false);
      }

      if (_looksLikeAlreadyRunning(error)) {
        await _syncSessionState();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _running
                  ? 'A session was already running. Restored it on this screen.'
                  : 'A session is already running on the backend.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start session: $error')),
      );
    }
  }

  Future<void> _stopSession() async {
    if (_stopping || _starting || _syncingSession) return;

    setState(() => _stopping = true);

    try {
      var sessionId = _currentSessionId;
      if (sessionId == null || sessionId.isEmpty) {
        final activeSession = await _findActiveSession(
          preferredSessionId: SessionStore.currentSessionId,
        );
        sessionId = _sessionIdOf(activeSession);
      }

      if (sessionId.isEmpty) {
        throw StateError('No active session was found to stop.');
      }

      await ApiService().endSession(sessionId);
      final ended = await _waitForSessionEnd(sessionId);

      if (!ended) {
        throw StateError('Backend did not confirm that the session stopped.');
      }

      await _submitAttendance(sessionId);
      await SessionStore.clearCurrentSession();

      if (!mounted) return;

      setState(() {
        _stopping = false;
        _running = false;
        _currentSessionId = null;
        _markedCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session stopped successfully.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _stopping = false);
      }
      await _syncSessionState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not stop session: $error')));
    }
  }

  Future<bool> _waitForSessionEnd(String sessionId) async {
    const maxAttempts = 6;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await ApiService().getSessionById(sessionId);
        final session = _extractSessionMap(response);
        if (session != null && _isSessionClosed(session)) {
          return true;
        }
      } catch (_) {
        // Ignore transient polling failures and retry.
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
      // Optional on some backends; do not block stop confirmation on this call.
    }
  }

  Map<String, dynamic> _classQueryParameters() {
    final selectedClass =
        SessionStore.selectedClass ?? const <String, dynamic>{};
    final query = <String, dynamic>{};
    final classId = _readValue(selectedClass, [
      'id',
      'class_id',
      'classId',
    ], '');
    final className = _readValue(selectedClass, [
      'name',
      'class_name',
      'title',
    ], '');
    final teacherId = _readValue(selectedClass, [
      'teacher_id',
      'teacherId',
      'tutor_id',
    ], '');

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

  Future<Map<String, dynamic>?> _findActiveSession({
    String? preferredSessionId,
  }) async {
    final api = ApiService();

    if (preferredSessionId != null && preferredSessionId.trim().isNotEmpty) {
      try {
        final response = await api.getSessionById(preferredSessionId);
        final preferredSession = _extractSessionMap(response);
        if (preferredSession != null && _isSessionActive(preferredSession)) {
          return preferredSession;
        }
      } catch (_) {
        // Fall through to broader session discovery.
      }
    }

    final baseQuery = _classQueryParameters();
    final queryVariants = <Map<String, dynamic>>[
      {...baseQuery, 'status': 'active'},
      {...baseQuery, 'status': 'running'},
      {...baseQuery, 'state': 'running'},
      {...baseQuery, 'is_active': 'true'},
      {...baseQuery, 'is_closed': 'false'},
    ];

    for (final query in queryVariants) {
      try {
        final response = await api.getSessionsFiltered(queryParameters: query);
        final session = _pickActiveSession(response);
        if (session != null) {
          return session;
        }
      } catch (_) {
        // Try the next shape the backend might accept.
      }
    }

    try {
      final response = await api.getSessions();
      return _pickActiveSession(response);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _pickActiveSession(dynamic response) {
    final sessions = _extractSessionMaps(response);

    for (final session in sessions) {
      if (_matchesSelectedClass(session) && _isSessionActive(session)) {
        return session;
      }
    }

    for (final session in sessions) {
      if (_isSessionActive(session)) {
        return session;
      }
    }

    return null;
  }

  bool _matchesSelectedClass(Map<String, dynamic> session) {
    final selectedClass =
        SessionStore.selectedClass ?? const <String, dynamic>{};
    final selectedClassId = _readValue(selectedClass, [
      'id',
      'class_id',
      'classId',
    ], '');
    final selectedClassName = _readValue(selectedClass, [
      'name',
      'class_name',
      'title',
    ], '');

    if (selectedClassId.isEmpty && selectedClassName.isEmpty) {
      return true;
    }

    final sessionClassId = _nestedRead(
      session,
      const ['class_id', 'classId', 'id'],
      nestedKeys: const ['class', 'course', 'session', 'data'],
    );
    if (selectedClassId.isNotEmpty && sessionClassId == selectedClassId) {
      return true;
    }

    final sessionClassName = _nestedRead(
      session,
      const ['class_name', 'name', 'title', 'course_name', 'subject_name'],
      nestedKeys: const ['class', 'course', 'session', 'data'],
    );
    return selectedClassName.isNotEmpty &&
        sessionClassName.toLowerCase() == selectedClassName.toLowerCase();
  }

  bool _isSessionActive(Map<String, dynamic> session) {
    final status = _nestedRead(
      session,
      const ['status', 'session_status', 'state'],
      nestedKeys: const ['session', 'data'],
    ).toLowerCase();

    if (status.isNotEmpty) {
      if (_isClosedStatus(status)) return false;
      if (_isRunningStatus(status)) return true;
    }

    final isClosed = _boolLikeValue(
      _nestedRead(
        session,
        const ['is_closed', 'closed'],
        nestedKeys: const ['session', 'data'],
      ),
    );
    if (isClosed == true) return false;

    final isActive = _boolLikeValue(
      _nestedRead(
        session,
        const ['is_active', 'active'],
        nestedKeys: const ['session', 'data'],
      ),
    );
    if (isActive == true) return true;

    return false;
  }

  bool _isSessionClosed(Map<String, dynamic> session) {
    final status = _nestedRead(
      session,
      const ['status', 'session_status', 'state'],
      nestedKeys: const ['session', 'data'],
    ).toLowerCase();

    if (status.isNotEmpty) {
      if (_isClosedStatus(status)) return true;
      if (_isRunningStatus(status)) return false;
    }

    final isClosed = _boolLikeValue(
      _nestedRead(
        session,
        const ['is_closed', 'closed'],
        nestedKeys: const ['session', 'data'],
      ),
    );
    if (isClosed != null) return isClosed;

    final endedAt = _nestedRead(
      session,
      const ['ended_at', 'closed_at', 'end_time'],
      nestedKeys: const ['session', 'data'],
    );
    return endedAt.isNotEmpty;
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

    final selectedClass =
        SessionStore.selectedClass ?? const <String, dynamic>{};
    final classId = _readValue(selectedClass, [
      'id',
      'class_id',
      'classId',
    ], '');
    final className = _readValue(selectedClass, [
      'name',
      'class_name',
      'title',
    ], '');

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

  void _toggleStudentsPanel([bool? open]) {
    setState(() => _studentsPanelOpen = open ?? !_studentsPanelOpen);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(
      MediaQuery.of(context).size.width,
    );
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);
    final selectedClass = SessionStore.selectedClass;
    final className = _readValue(selectedClass, [
      'name',
      'class_name',
      'title',
    ], '');
    final tutor = _readValue(selectedClass, [
      'tutor',
      'teacher',
      'teacher_name',
      'instructor',
      'assigned_teacher',
    ], '');
    final panelWidth = min(
      isDesktop ? 420.0 : MediaQuery.of(context).size.width * 0.92,
      MediaQuery.of(context).size.width,
    );

    return Stack(
      children: [
        SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sessions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              AppSpacing.gap16,
              if (className.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class Session',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondaryFor(context),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (className.isNotEmpty) AppSpacing.gap16,
              if (className.isNotEmpty)
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _studentsFuture,
                  builder: (context, snapshot) {
                    final students =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    final previewNames = students
                        .take(3)
                        .map(_resolveStudentName)
                        .where((name) => name.isNotEmpty)
                        .toList();

                    return AppCard(
                      child: InkWell(
                        onTap:
                            snapshot.connectionState == ConnectionState.waiting
                            ? null
                            : () => _toggleStudentsPanel(true),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Container(
                                height: 52,
                                width: 52,
                                decoration: BoxDecoration(
                                  color: AppTheme.brandGreen.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.groups_2_outlined,
                                  color: AppTheme.brandGreen,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Students',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting)
                                      Text(
                                        'Loading roster...',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textSecondaryFor(
                                                context,
                                              ),
                                            ),
                                      )
                                    else if (students.isEmpty)
                                      Text(
                                        'No students found for this class.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textSecondaryFor(
                                                context,
                                              ),
                                            ),
                                      )
                                    else
                                      Text(
                                        previewNames.join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textSecondaryFor(
                                                context,
                                              ),
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${students.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'View all',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: AppTheme.textSecondaryFor(
                                            context,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (className.isNotEmpty) AppSpacing.gap20,
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _AnimatedBlob(controller: _blobController),
                    _SessionButton(
                      running: _running,
                      label: _syncingSession ? 'Wait' : null,
                      onTap: (_stopping || _starting || _syncingSession)
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
                      color: _running
                          ? AppTheme.brandGreen
                          : AppTheme.textSecondaryFor(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _running ? 'Session running' : 'Session stopped',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _running
                                ? 'Backend session is active and ready to be stopped here.'
                                : _syncingSession
                                ? 'Checking current session status...'
                                : _starting
                                ? 'Creating session on the backend...'
                                : 'Press start to begin marking attendance',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryFor(context),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (_running
                                    ? AppTheme.brandGreen
                                    : AppTheme.accentOrange)
                                .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _markedCount.toString(),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Marked',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryFor(context),
                                ),
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
        if (_studentsPanelOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _toggleStudentsPanel(false),
              child: Container(color: Colors.black.withValues(alpha: 0.28)),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: _studentsPanelOpen ? 0 : -(panelWidth + 24),
          width: panelWidth,
          child: IgnorePointer(
            ignoring: !_studentsPanelOpen,
            child: _StudentsPanel(
              studentsFuture: _studentsFuture,
              onClose: () => _toggleStudentsPanel(false),
            ),
          ),
        ),
        if (_stopping || _starting || _syncingSession)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 12),
                    Text(
                      _starting
                          ? 'Starting session...'
                          : _stopping
                          ? 'Stopping session...'
                          : 'Checking session status...',
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

class _StudentsPanel extends StatelessWidget {
  const _StudentsPanel({required this.studentsFuture, required this.onClose});

  final Future<List<Map<String, dynamic>>> studentsFuture;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCardFor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderFor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(-4, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Students',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Full class roster',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryFor(context),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.arrow_forward_ios_rounded),
                      tooltip: 'Close students',
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.borderFor(context)),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: studentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    final students =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    if (students.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No students found for this class.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textSecondaryFor(context),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: students.length,
                      separatorBuilder: (_, _) => const Divider(height: 20),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        final name = _resolveStudentName(student);
                        final studentCode = _nestedRead(student, const [
                          'student_code',
                          'code',
                          'roll_no',
                          'registration_no',
                          'student_id',
                          'id',
                        ]);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.brandGreen.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              name.isEmpty
                                  ? '?'
                                  : name.substring(0, 1).toUpperCase(),
                            ),
                          ),
                          title: Text(name),
                          subtitle: studentCode.isEmpty
                              ? null
                              : Text(studentCode),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionButton extends StatelessWidget {
  const _SessionButton({
    required this.running,
    required this.onTap,
    this.label,
  });

  final bool running;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = running ? AppTheme.accentOrange : AppTheme.brandGreen;
    final effectiveLabel = label ?? (running ? 'Stop' : 'Start');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: onTap == null ? 0.72 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          height: 140,
          width: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              effectiveLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
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
        final glowGreen = AppTheme.brandGreen.withValues(
          alpha: isDark ? 0.28 : 0.18,
        );
        final glowOrange = AppTheme.accentOrange.withValues(
          alpha: isDark ? 0.22 : 0.14,
        );

        return Transform.translate(
          offset: Offset(dx, dy),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: isDark ? 22 : 16,
                sigmaY: isDark ? 22 : 16,
              ),
              child: Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glowGreen, glowOrange, Colors.transparent],
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

String _resolveStudentName(Map<String, dynamic> student) {
  final name = _nestedRead(student, const [
    'full_name',
    'student_full_name',
    'student_name',
    'name',
  ], fallback: '');
  if (name.isNotEmpty) return name;

  final firstName = _nestedRead(student, const [
    'first_name',
    'firstName',
  ], fallback: '');
  final lastName = _nestedRead(student, const [
    'last_name',
    'lastName',
  ], fallback: '');
  final combined = [
    firstName,
    lastName,
  ].where((part) => part.isNotEmpty).join(' ').trim();
  if (combined.isNotEmpty) return combined;

  return _nestedRead(student, const [
    'email',
    'student_email',
    'roll_no',
    'id',
    'student_id',
  ], fallback: 'Student');
}

String _nestedRead(
  Map<String, dynamic> item,
  List<String> keys, {
  List<String> nestedKeys = const ['student', 'class', 'data'],
  String fallback = '',
  int depth = 0,
}) {
  if (depth > 4) return fallback;

  for (final key in keys) {
    final value = item[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }

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
    if (nested is List) {
      for (final element in nested) {
        if (element is Map<String, dynamic>) {
          final resolved = _nestedRead(
            Map<String, dynamic>.from(element),
            keys,
            nestedKeys: nestedKeys,
            fallback: fallback,
            depth: depth + 1,
          );
          if (resolved.isNotEmpty) return resolved;
        }
      }
    }
  }

  for (final value in item.values) {
    if (value is Map<String, dynamic>) {
      final resolved = _nestedRead(
        value,
        keys,
        nestedKeys: nestedKeys,
        fallback: fallback,
        depth: depth + 1,
      );
      if (resolved.isNotEmpty) return resolved;
    }
    if (value is List) {
      for (final element in value) {
        if (element is Map<String, dynamic>) {
          final resolved = _nestedRead(
            Map<String, dynamic>.from(element),
            keys,
            nestedKeys: nestedKeys,
            fallback: fallback,
            depth: depth + 1,
          );
          if (resolved.isNotEmpty) return resolved;
        }
      }
    }
  }

  return fallback;
}

List<dynamic> _extractList(
  dynamic response,
  List<String> keys, {
  int depth = 0,
}) {
  if (response is List) return response;
  if (response is Map) {
    for (final key in keys) {
      final value = response[key];
      if (value is List) return value;
      if (value is Map && depth < 2) {
        final nested = _extractList(value, keys, depth: depth + 1);
        if (nested.isNotEmpty) return nested;
      }
    }
  }
  return const [];
}

List<Map<String, dynamic>> _extractSessionMaps(dynamic response) {
  if (response is List) {
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  if (response is! Map) return const [];

  final list = _extractList(response, const ['sessions', 'items', 'data']);
  if (list.isNotEmpty) {
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  final single = _extractSessionMap(response);
  return single == null ? const [] : [single];
}

Map<String, dynamic>? _extractSessionMap(dynamic response) {
  if (response is! Map) return null;

  final map = Map<String, dynamic>.from(response);
  final nestedSession = map['session'];
  if (nestedSession is Map) {
    return Map<String, dynamic>.from(nestedSession);
  }

  final nestedData = map['data'];
  if (nestedData is Map) {
    final dataMap = Map<String, dynamic>.from(nestedData);
    final dataSession = dataMap['session'];
    if (dataSession is Map) {
      return Map<String, dynamic>.from(dataSession);
    }
    return dataMap;
  }

  return map;
}

String _sessionIdOf(Map<String, dynamic>? session) {
  if (session == null) return '';
  return _nestedRead(
    session,
    const ['id', 'session_id'],
    nestedKeys: const ['session', 'data'],
  );
}

int _extractMarkedCount(Map<String, dynamic>? session) {
  if (session == null) return 0;
  return int.tryParse(
        _nestedRead(
          session,
          const [
            'marked',
            'present',
            'present_count',
            'attendance_marked',
            'attended',
          ],
          nestedKeys: const ['attendance', 'session', 'data'],
          fallback: '0',
        ),
      ) ??
      0;
}

bool _isRunningStatus(String status) {
  return status.contains('active') ||
      status.contains('running') ||
      status.contains('open') ||
      status.contains('start') ||
      status.contains('progress');
}

bool _isClosedStatus(String status) {
  return status.contains('end') ||
      status.contains('closed') ||
      status.contains('finish') ||
      status.contains('complete') ||
      status.contains('stop');
}

bool? _boolLikeValue(String value) {
  if (value.isEmpty) {
    return null;
  }
  final normalized = value.toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return null;
}

bool _looksLikeAlreadyRunning(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('already running') ||
      message.contains('already started') ||
      message.contains('session is already') ||
      message.contains('409');
}
