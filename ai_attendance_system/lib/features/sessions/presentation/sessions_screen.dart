import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    with TickerProviderStateMixin {
  bool _running = false;
  bool _starting = false;
  bool _stopping = false;
  bool _preparingReport = false;
  bool _syncingSession = true;
  bool _studentsExpanded = false;
  bool _reportLoading = false;
  int _markedCount = 0;
  int _activeTabIndex = 0;
  String? _currentSessionId;
  Timer? _attendancePoller;
  late final AnimationController _blobController;
  late final TabController _tabController;
  late Future<List<Map<String, dynamic>>> _studentsFuture;
  List<_SessionStudentBreakdown> _studentBreakdown = const [];
  final Set<int> _expandedStudents = {};

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
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
    _stopAttendancePolling();
    _tabController.dispose();
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
        _startAttendancePolling(sessionId);
        await _loadStudentBreakdown(sessionId);
        await SessionStore.saveCurrentSession(
          sessionId: sessionId,
          session: activeSession,
        );
      } else {
        setState(() {
          _running = false;
          _currentSessionId = null;
          _markedCount = 0;
          _studentBreakdown = const [];
        });
        _stopAttendancePolling();
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
      _startAttendancePolling(sessionId);
      await _loadStudentBreakdown(sessionId);

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

    setState(() {
      _stopping = true;
      _preparingReport = false;
    });

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

      _stopAttendancePolling();
      await ApiService().endSession(sessionId);
      final ended = await _waitForSessionEnd(sessionId);

      if (!ended) {
        throw StateError('Backend did not confirm that the session stopped.');
      }

      await _submitAttendance(sessionId);
      if (mounted) {
        setState(() => _preparingReport = true);
      }
      await SessionStore.saveReportSessionId(sessionId);
      await _warmUpReport(sessionId);
      await SessionStore.clearCurrentSession();

      if (!mounted) return;

      setState(() {
        _stopping = false;
        _preparingReport = false;
        _running = false;
        _currentSessionId = null;
        _markedCount = 0;
        _activeTabIndex = 1;
      });
      _tabController.animateTo(1);
      await _loadStudentBreakdown(sessionId);
      if (mounted) {
        context.go('/sessions');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _stopping = false;
          _preparingReport = false;
        });
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

  Future<void> _warmUpReport(String sessionId) async {
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await ApiService().getAttendanceSessionReport(sessionId);
        return;
      } catch (_) {
        // Report generation can take a moment after stop. Redirect anyway and
        // let the report page fall back to class roster data if needed.
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _submitAttendance(String sessionId) async {
    try {
      await ApiService().submitAttendance(sessionId, <String, dynamic>{});
    } catch (_) {
      // Optional on some backends; do not block stop confirmation on this call.
    }
  }

  void _startAttendancePolling(String sessionId) {
    _attendancePoller?.cancel();
    _pollAttendanceCount(sessionId);
    _attendancePoller = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollAttendanceCount(sessionId);
    });
  }

  void _stopAttendancePolling() {
    _attendancePoller?.cancel();
    _attendancePoller = null;
  }

  Future<void> _pollAttendanceCount(String sessionId) async {
    if (!mounted || sessionId.isEmpty) {
      return;
    }
    if (_currentSessionId != sessionId || !_running) {
      _stopAttendancePolling();
      return;
    }

    try {
      final report = await ApiService().getAttendanceSessionReport(sessionId);
      final reportCount = _extractPresentCountFromReport(report);
      if (reportCount != null) {
        if (mounted && reportCount != _markedCount) {
          setState(() => _markedCount = reportCount);
        }
        return;
      }
    } catch (_) {
      // Fall back to session polling below.
    }

    try {
      final session = await ApiService().getSessionById(sessionId);
      final count = _extractMarkedCount(_extractSessionMap(session));
      if (mounted && count != _markedCount) {
        setState(() => _markedCount = count);
      }
    } catch (_) {
      // Ignore transient polling failures.
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

  Future<void> _loadStudentBreakdown(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) {
      if (mounted) {
        setState(() {
          _studentBreakdown = const [];
          _reportLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _reportLoading = true);
    }

    try {
      final response = await ApiService().getAttendanceSessionReport(sessionId);
      final breakdown = _extractStudentBreakdown(response);
      if (!mounted) return;
      setState(() {
        _studentBreakdown = breakdown;
        _reportLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _studentBreakdown = const [];
        _reportLoading = false;
      });
    }
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

  void _toggleStudentsExpanded([bool? open]) {
    setState(() => _studentsExpanded = open ?? !_studentsExpanded);
  }

  Widget _buildByStudentTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        AppSpacing.gap8,
        Text(
          'Attendance activity and engagement for the current session.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryFor(context),
          ),
        ),
        AppSpacing.gap16,
        if (_reportLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_studentBreakdown.isEmpty)
          AppCard(
            child: Text(
              'No student activity is available yet for this session.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryFor(context),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _studentBreakdown.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final student = _studentBreakdown[index];
              final expanded = _expandedStudents.contains(index);
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (expanded) {
                            _expandedStudents.remove(index);
                          } else {
                            _expandedStudents.add(index);
                          }
                        });
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.brandGreen.withValues(alpha: 0.12),
                            child: Text(student.initials),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (student.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    student.subtitle,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondaryFor(context),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: student.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              student.status,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: student.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            color: AppTheme.textSecondaryFor(context),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gap12,
                    if (_expandedStudents.contains(index)) ...[
                      _ActivityStat(
                        label: 'Active',
                        value: student.activeCount,
                        total: student.totalCount,
                        color: AppTheme.brandGreen,
                      ),
                      AppSpacing.gap12,
                      _ActivityStat(
                        label: 'Distracted',
                        value: student.distractedCount,
                        total: student.totalCount,
                        color: AppTheme.accentOrange,
                      ),
                      AppSpacing.gap12,
                      _ActivityStat(
                        label: 'Sleeping',
                        value: student.sleepingCount,
                        total: student.totalCount,
                        color: AppTheme.danger,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
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
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceCardFor(context),
            border: Border(
              bottom: BorderSide(color: AppTheme.borderFor(context)),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.brandGreen,
            labelColor: AppTheme.textPrimaryFor(context),
            unselectedLabelColor: AppTheme.textSecondaryFor(context),
            tabs: const [
              Tab(text: 'Session Overview'),
              Tab(text: 'By Student'),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_activeTabIndex == 0) ...[
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
                      AppSpacing.gap16,
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _SessionSummaryStatCard(
                                    title: 'Present',
                                    value: _currentPresentCount.toString(),
                                    color: AppTheme.brandGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SessionSummaryStatCard(
                                    title: 'Absent',
                                    value: _currentAbsentCount.toString(),
                                    color: AppTheme.accentOrange,
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.gap12,
                            Text(
                              'Attendance rate: ${_currentAttendanceRate.toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryFor(context),
                                  ),
                            ),
                          ],
                        ),
                      ),
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
                                    : () => _toggleStudentsExpanded(),
                                borderRadius: BorderRadius.circular(18),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                          color:
                                                              AppTheme.textSecondaryFor(
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
                                                          color:
                                                              AppTheme.textSecondaryFor(
                                                                context,
                                                              ),
                                                        ),
                                                  )
                                                else
                                                  Text(
                                                    _studentsExpanded
                                                        ? 'Tap again to close the student list.'
                                                        : previewNames.join(' • '),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color:
                                                              AppTheme.textSecondaryFor(
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
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              ),
                                              Text(
                                                _studentsExpanded ? 'Hide' : 'Show all',
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
                                          AnimatedRotation(
                                            turns: _studentsExpanded ? 0.5 : 0,
                                            duration: const Duration(milliseconds: 220),
                                            child: const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                            ),
                                          ),
                                        ],
                                      ),
                                      AnimatedSize(
                                        duration: const Duration(milliseconds: 220),
                                        curve: Curves.easeInOut,
                                        child: !_studentsExpanded
                                            ? const SizedBox.shrink()
                                            : Padding(
                                                padding: const EdgeInsets.only(top: 16),
                                                child:
                                                    snapshot.connectionState ==
                                                        ConnectionState.waiting
                                                    ? const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : students.isEmpty
                                                    ? Text(
                                                        'No students found for this class.',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              color:
                                                                  AppTheme.textSecondaryFor(
                                                                    context,
                                                                  ),
                                                            ),
                                                      )
                                                    : Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Class roster',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .titleSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight.w700,
                                                                ),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            'Students available for attendance in this session.',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color:
                                                                      AppTheme.textSecondaryFor(
                                                                        context,
                                                                      ),
                                                                ),
                                                          ),
                                                          const SizedBox(height: 12),
                                                          ListView.separated(
                                                            itemCount: students.length,
                                                            separatorBuilder: (_, _) =>
                                                                const Divider(
                                                                  height: 20,
                                                                ),
                                                            physics:
                                                                const NeverScrollableScrollPhysics(),
                                                            shrinkWrap: true,
                                                            itemBuilder: (context, index) {
                                                              final student =
                                                                  students[index];
                                                              final name =
                                                                  _resolveStudentName(
                                                                    student,
                                                                  );
                                                              final studentCode =
                                                                  _nestedRead(
                                                                    student,
                                                                    const [
                                                                      'student_code',
                                                                      'code',
                                                                      'roll_no',
                                                                      'registration_no',
                                                                      'student_id',
                                                                      'id',
                                                                    ],
                                                                  );

                                                              return ListTile(
                                                                contentPadding:
                                                                    EdgeInsets.zero,
                                                                leading: CircleAvatar(
                                                                  backgroundColor:
                                                                      AppTheme
                                                                          .brandGreen
                                                                          .withValues(
                                                                            alpha: 0.12,
                                                                          ),
                                                                  child: Text(
                                                                    name.isEmpty
                                                                        ? '?'
                                                                        : name
                                                                              .substring(
                                                                                0,
                                                                                1,
                                                                              )
                                                                              .toUpperCase(),
                                                                  ),
                                                                ),
                                                                title: Text(name),
                                                                subtitle:
                                                                    studentCode.isEmpty
                                                                    ? null
                                                                    : Text(studentCode),
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ] else
                      _buildByStudentTab(),
                  ],
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
                                : _preparingReport
                                ? 'Preparing report...'
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
          ),
        ),
      ],
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

class _SessionSummaryStatCard extends StatelessWidget {
  const _SessionSummaryStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          AppSpacing.gap12,
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  const _ActivityStat({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total <= 0 ? 0.0 : value / total;
    final percentText = '${(percent * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryFor(context),
              ),
            ),
            Text(
              percentText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: AppTheme.surfaceAltFor(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
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

List<_SessionStudentBreakdown> _extractStudentBreakdown(dynamic response) {
  final items = _extractList(response, const ['students', 'records', 'attendance', 'items', 'data']);
  if (items.isEmpty) {
    return const [];
  }

  return items.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    final status = _nestedRead(
      map,
      const ['final_status', 'status', 'attendance_status', 'remark'],
      fallback: 'ABSENT',
    ).toUpperCase();
    final present = status == 'PRESENT';
    final engagement = _nestedRead(
      map,
      const ['final_engagement', 'engagement', 'engaged_status'],
      fallback: '',
    ).toUpperCase();
    final active = _intValue(map, const ['engaged_count', 'engaged'], fallback: 0);
    final distracted = _intValue(map, const ['distracted_count', 'distracted'], fallback: 0);
    final sleeping = _intValue(map, const ['sleeping_count', 'sleeping'], fallback: 0);
    final phone = _intValue(map, const ['phone_count', 'phone'], fallback: 0);
    final total = [active, distracted, sleeping, phone].fold(0, (sum, value) => sum + value);
    final marked = present ? total : 0;
    final pending = total > 0 ? total - marked : 0;
    final totalCount = total > 0 ? total : 1;

    return _SessionStudentBreakdown(
      name: _nestedRead(
        map,
        const ['full_name', 'student_full_name', 'student_name', 'name'],
        fallback: 'Student',
      ),
      subtitle: _nestedRead(
        map,
        const ['student_code', 'code', 'roll_no', 'registration_no', 'student_id', 'id'],
        fallback: '',
      ),
      status: present ? 'Present' : 'Absent',
      color: present ? AppTheme.brandGreen : AppTheme.danger,
      engagement: engagement.isEmpty ? 'N/A' : engagement,
      activeCount: active,
      distractedCount: distracted,
      sleepingCount: sleeping,
      phoneCount: phone,
      totalActivity: total,
      markedCount: marked,
      pendingCount: pending,
      totalCount: totalCount,
    );
  }).toList();
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

int? _extractPresentCountFromReport(dynamic response) {
  if (response is List) {
    final items = response.whereType<Map>().map(
      (item) => Map<String, dynamic>.from(item),
    );
    if (items.isEmpty) {
      return null;
    }
    var presentCount = 0;
    for (final item in items) {
      final status = _nestedRead(
        item,
        const ['final_status', 'status', 'attendance_status', 'remark'],
        nestedKeys: const ['student', 'attendance', 'data'],
      ).toLowerCase();
      if (status.isEmpty || status.contains('present')) {
        presentCount++;
      }
    }
    return presentCount;
  }

  if (response is Map) {
    final report =
        _extractSessionMap(response) ?? Map<String, dynamic>.from(response);
    final directCount = _nestedRead(
      report,
      const ['present', 'present_count', 'marked', 'total_present'],
      nestedKeys: const ['report', 'attendance', 'data'],
    );
    final parsed = int.tryParse(directCount);
    if (parsed != null) {
      return parsed;
    }

    final records = _extractList(report, const [
      'students',
      'records',
      'attendance',
      'items',
      'data',
    ]);
    if (records.isNotEmpty) {
      return _extractPresentCountFromReport(records);
    }
  }

  return null;
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

int _intValue(Map<String, dynamic> item, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = item[key];
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value) ?? fallback;
    }
  }
  return fallback;
}

class _SessionStudentBreakdown {
  const _SessionStudentBreakdown({
    required this.name,
    required this.subtitle,
    required this.status,
    required this.color,
    required this.engagement,
    required this.activeCount,
    required this.distractedCount,
    required this.sleepingCount,
    required this.phoneCount,
    required this.totalActivity,
    required this.markedCount,
    required this.pendingCount,
    required this.totalCount,
  });

  final String name;
  final String subtitle;
  final String status;
  final Color color;
  final String engagement;
  final int activeCount;
  final int distractedCount;
  final int sleepingCount;
  final int phoneCount;
  final int totalActivity;
  final int markedCount;
  final int pendingCount;
  final int totalCount;

  String get initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return parts.take(2).map((part) => part.substring(0, 1).toUpperCase()).join();
  }
}
