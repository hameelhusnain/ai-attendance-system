import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/session_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  int _tabIndex = 0;
  String? _expandedStudentId;
  String? _expandedHistorySessionId;

  List<_SessionHistoryView> _historyCards = const [];
  List<_ReportStudent> _breakdown = const [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Map<String, dynamic> get _selectedClass =>
      SessionStore.selectedClass ?? const {};

  String get _selectedClassId =>
      _stringValue(_selectedClass, ['id', 'class_id', 'classId']);

  String get _selectedClassName => _stringValue(_selectedClass, [
    'name',
    'class_name',
    'title',
  ], 'Selected Class');

  String get _selectedClassCode {
    final code = _joinNonEmpty([
      _stringValue(_selectedClass, ['code', 'section']),
      _stringValue(_selectedClass, ['group']),
    ]);
    if (code.isNotEmpty) return code;
    final fallback = _joinNonEmpty([
      _stringValue(_selectedClass, ['semester']),
      _stringValue(_selectedClass, ['batch']),
    ]);
    return fallback;
  }

  String get _reportSubtitle {
    final pieces = [_selectedClassName, _selectedClassCode]
      ..removeWhere((e) => e.isEmpty);
    return pieces.join('  •  ');
  }

  int get _thisSessionPresent {
    if (_breakdown.isNotEmpty) {
      return _breakdown.where((student) => student.present).length;
    }
    if (_historyCards.isNotEmpty) return _historyCards.first.present;
    return 0;
  }

  int get _thisSessionAbsent {
    if (_breakdown.isNotEmpty) {
      return _breakdown.where((student) => !student.present).length;
    }
    if (_historyCards.isNotEmpty) return _historyCards.first.absent;
    return 0;
  }

  bool get _canExportReport =>
      _historyCards.isNotEmpty || _breakdown.isNotEmpty;

  Map<String, dynamic> _reportQueryParameters() {
    final selectedClass = _selectedClass;
    final query = <String, dynamic>{};
    final classId = _stringValue(selectedClass, ['id', 'class_id', 'classId']);
    final className = _stringValue(selectedClass, [
      'name',
      'class_name',
      'title',
    ]);
    final teacherId = _stringValue(selectedClass, [
      'teacher_id',
      'teacherId',
      'tutor_id',
    ]);
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

  Future<void> _loadReportData() async {
    final api = ApiService();
    dynamic sessionsResponse;
    final query = _reportQueryParameters();
    final reportSessionId = await SessionStore.consumeReportSessionId();
    final classStudents = await _loadClassStudents();

    try {
      sessionsResponse = await api.getSessionsFiltered(queryParameters: query);
    } catch (_) {}
    sessionsResponse ??= await _safeCall(() => api.getSessions());

    final sessionsRaw = _extractResponseList(sessionsResponse, const [
      'sessions',
      'items',
      'data',
    ]);
    final sessions = _normalizeSessions(sessionsRaw);
    final resolvedSessions = sessions.isNotEmpty ? sessions : sessionsRaw;
    final activeSessionId = SessionStore.currentSessionId;
    final selectedReportSessionId =
        reportSessionId != null && reportSessionId.isNotEmpty
        ? reportSessionId
        : activeSessionId != null && activeSessionId.isNotEmpty
        ? activeSessionId
        : resolvedSessions.isNotEmpty
        ? _stringValue(resolvedSessions.first, ['id', 'session_id'])
        : null;
    final historyCards = await _buildHistoryCards(
      resolvedSessions,
      classStudents: classStudents,
      fallbackStudentCount: classStudents.length,
      prioritizedSessionId: selectedReportSessionId,
    );
    final breakdown = await _loadBreakdown(
      selectedReportSessionId,
      classStudents,
    );

    if (!mounted) return;
    setState(() {
      _historyCards = historyCards;
      _breakdown = breakdown;
      _loading = false;
    });
  }

  Future<dynamic> _safeCall(Future<dynamic> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }

  Future<List<_SessionHistoryView>> _buildHistoryCards(
    List<Map<String, dynamic>> sessions, {
    required List<Map<String, dynamic>> classStudents,
    required int fallbackStudentCount,
    String? prioritizedSessionId,
  }) async {
    final cards = <_SessionHistoryView>[];
    final orderedSessions = [...sessions];

    if (prioritizedSessionId != null && prioritizedSessionId.isNotEmpty) {
      orderedSessions.sort((a, b) {
        final aId = _stringValue(a, ['id', 'session_id']);
        final bId = _stringValue(b, ['id', 'session_id']);
        if (aId == prioritizedSessionId && bId != prioritizedSessionId) {
          return -1;
        }
        if (aId != prioritizedSessionId && bId == prioritizedSessionId) {
          return 1;
        }
        return 0;
      });
    }

    for (final session in orderedSessions.take(6)) {
      final sessionId = _stringValue(session, ['id', 'session_id']);
      Map<String, dynamic> report = const {};

      if (sessionId.isNotEmpty) {
        final response = await _fetchAttendanceSessionReportWithRetry(
          sessionId,
        );
        if (response is Map<String, dynamic>) {
          report = response;
        } else if (response is Map) {
          report = Map<String, dynamic>.from(response);
        }
      }

      final present = _intValue(report, [
        'present',
        'present_count',
      ], fallback: _intValue(session, ['present', 'marked'], fallback: 0));
      final total = _intValue(
        report,
        ['total', 'total_students'],
        fallback: _intValue(session, [
          'total',
          'student_count',
          'total_students',
        ], fallback: fallbackStudentCount),
      );
      final absent = _intValue(report, [
        'absent',
        'absent_count',
      ], fallback: total > 0 ? max(total - present, 0) : fallbackStudentCount);
      final percentage = _doubleValue(report, [
        'attendance_rate',
        'percentage',
      ], fallback: total > 0 ? (present / total) * 100 : 0);
      final students = await _loadBreakdown(sessionId, classStudents);

      cards.add(
        _SessionHistoryView(
          sessionId: sessionId,
          title: _stringValue(session, [
            'title',
            'label',
            'name',
          ], _selectedClassName),
          dateLabel: _stringValue(session, [
            'date',
            'session_date',
            'created_at',
          ], 'Recent Session'),
          timeLabel: _joinNonEmpty([
            _stringValue(session, ['time', 'start_time']),
            _stringValue(session, ['end_time']),
          ], separator: ' - '),
          present: present,
          absent: absent,
          percentage: percentage,
          students: students,
        ),
      );
    }

    return cards;
  }

  Future<List<_ReportStudent>> _loadBreakdown(
    String? sessionId,
    List<Map<String, dynamic>> classStudents,
  ) async {
    if (sessionId == null || sessionId.isEmpty) {
      return classStudents.map(_reportStudentFromClassStudent).toList();
    }

    try {
      final response = await _fetchAttendanceSessionReportWithRetry(sessionId);
      final records = _extractReportItems(response);
      if (records.isNotEmpty) {
        return records.map(_reportStudentFromDynamic).toList();
      }
    } catch (_) {
      // ignore attendance load errors for UI fallback
    }

    return classStudents.map(_reportStudentFromClassStudent).toList();
  }

  Future<List<Map<String, dynamic>>> _loadClassStudents() async {
    final api = ApiService();
    final query = _reportQueryParameters();
    dynamic response;

    try {
      response = await api.getStudentsFiltered(queryParameters: query);
    } catch (_) {
      response = await _safeCall(() => api.getStudents());
    }

    final students = _extractResponseList(response, const [
      'students',
      'items',
      'data',
    ]);
    if (students.isEmpty) {
      return const [];
    }

    return students.where(_matchesStudentClass).toList();
  }

  bool _matchesStudentClass(Map<String, dynamic> student) {
    if (_selectedClassId.isEmpty && _selectedClassName == 'Selected Class') {
      return true;
    }

    final studentClassId = _classValue(student, ['id', 'class_id', 'classId']);
    if (_selectedClassId.isNotEmpty && studentClassId == _selectedClassId) {
      return true;
    }

    final studentClassName = _classValue(student, [
      'name',
      'class_name',
      'title',
    ]);
    if (_selectedClassName != 'Selected Class' &&
        studentClassName.toLowerCase() == _selectedClassName.toLowerCase()) {
      return true;
    }

    return false;
  }

  Future<dynamic> _fetchAttendanceSessionReportWithRetry(
    String sessionId, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    dynamic lastResponse;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await ApiService().getAttendanceSessionReport(
          sessionId,
        );
        lastResponse = response;
        if (response != null) {
          return response;
        }
      } catch (error) {
        lastResponse = 'Request error: ${error.toString()}';
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(delay);
      }
    }
    return lastResponse;
  }

  List<Map<String, dynamic>> _extractReportItems(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return _listValue(response, [
      'students',
      'records',
      'attendance',
      'items',
    ]).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  List<Map<String, dynamic>> _normalizeSessions(List<dynamic> sessions) {
    final normalized = <Map<String, dynamic>>[];
    for (final session in sessions) {
      if (session is! Map) continue;
      final map = Map<String, dynamic>.from(session);
      if (_matchesSelectedClass(map)) normalized.add(map);
    }
    return normalized;
  }

  bool _matchesSelectedClass(Map<String, dynamic> item) {
    if (_selectedClassId.isEmpty && _selectedClassName == 'Selected Class') {
      return true;
    }

    final classId = _classValue(item, ['id', 'class_id', 'classId']);
    if (_selectedClassId.isNotEmpty && classId == _selectedClassId) {
      return true;
    }

    final className = _classValue(item, ['name', 'class_name', 'title']);
    if (_selectedClassName != 'Selected Class' &&
        className.toLowerCase() == _selectedClassName.toLowerCase()) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(
      MediaQuery.of(context).size.width,
    );
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Report',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          AppSpacing.gap8,
          Text(
            _reportSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
          AppSpacing.gap20,
          _ReportTabs(
            currentIndex: _tabIndex,
            onChanged: (value) => setState(() => _tabIndex = value),
          ),
          AppSpacing.gap16,
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            if (_tabIndex == 0) _buildThisSessionTab(context),
            if (_tabIndex == 1) _buildClassHistoryTab(context),
            if (_tabIndex == 2) _buildByStudentTab(context),
          ],
        ],
      ),
    );
  }

  Widget _buildThisSessionTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Session',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        AppSpacing.gap12,
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Present',
                value: _thisSessionPresent.toString(),
                color: AppTheme.brandGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Absent',
                value: _thisSessionAbsent.toString(),
                color: AppTheme.accentOrange,
              ),
            ),
          ],
        ),
        AppSpacing.gap16,
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _canExportReport ? _exportReportCsv : null,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export CSV'),
          ),
        ),
        AppSpacing.gap12,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Breakdown',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              AppSpacing.gap12,
              if (_breakdown.isEmpty)
                Text(
                  'No student breakdown available for this session.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryFor(context),
                  ),
                )
              else
                ListView.separated(
                  itemCount: _breakdown.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final student = _breakdown[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: student.color.withValues(alpha: 0.14),
                        child: Text(student.initials),
                      ),
                      title: Text(student.name),
                      subtitle: student.subtitle.isEmpty
                          ? null
                          : Text(student.subtitle),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusPill(
                            label: student.status,
                            color: student.color,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            student.present ? Icons.check_circle : Icons.cancel,
                            color: student.present
                                ? AppTheme.brandGreen
                                : AppTheme.accentOrange,
                            size: 18,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClassHistoryTab(BuildContext context) {
    if (_historyCards.isEmpty) {
      return AppCard(
        child: Text(
          'No class history available right now.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryFor(context),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _canExportReport ? _exportReportCsv : null,
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Export CSV'),
          ),
        ),
        AppSpacing.gap12,
        Text(
          'Previous Sessions',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        AppSpacing.gap12,
        ListView.separated(
          itemCount: _historyCards.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _historyCards[index];
            final expanded = _expandedHistorySessionId == item.sessionId;
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                setState(() {
                  _expandedHistorySessionId = expanded ? null : item.sessionId;
                });
              },
              child: AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 16,
                                      color: AppTheme.textSecondaryFor(context),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.dateLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.timeLabel.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.timeLabel,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondaryFor(
                                            context,
                                          ),
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  'Present: ${item.present}   Absent: ${item.absent}   •   ${item.percentage.toStringAsFixed(0)}%',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.textSecondaryFor(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: (item.percentage / 100).clamp(0.0, 1.0),
                          backgroundColor: AppTheme.surfaceAltFor(context),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.brandGreen,
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: !expanded
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: item.students.isEmpty
                                    ? Text(
                                        'No student breakdown available for this session.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppTheme.textSecondaryFor(
                                                context,
                                              ),
                                            ),
                                      )
                                    : Column(
                                        children: [
                                          for (
                                            var i = 0;
                                            i < item.students.length;
                                            i++
                                          ) ...[
                                            _HistoryStudentRow(
                                              student: item.students[i],
                                            ),
                                            if (i != item.students.length - 1)
                                              const Divider(height: 18),
                                          ],
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
      ],
    );
  }

  Widget _buildByStudentTab(BuildContext context) {
    final presentCount = _breakdown
        .where((student) => student.status.toUpperCase() == 'PRESENT')
        .length;
    final absentCount = _breakdown.length - presentCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _canExportReport ? _exportReportCsv : null,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export CSV'),
          ),
        ),
        AppSpacing.gap12,
        Row(
          children: [
            Expanded(
              child: _SummaryStatCard(
                title: 'Present',
                value: presentCount.toString(),
                color: AppTheme.brandGreen,
                backgroundColor: AppTheme.brandGreen.withValues(alpha: 0.14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryStatCard(
                title: 'Absent',
                value: absentCount.toString(),
                color: AppTheme.danger,
                backgroundColor: AppTheme.danger.withValues(alpha: 0.14),
              ),
            ),
          ],
        ),
        AppSpacing.gap16,
        if (_breakdown.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No student attendance data available for this session.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryFor(context),
                ),
              ),
            ),
          )
        else
          ListView.builder(
            itemCount: _breakdown.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final student = _breakdown[index];
              final expanded = _expandedStudentId == student.id;
              final statusIsPresent = student.status.toUpperCase() == 'PRESENT';
              final engagementLabel = student.engagement.isEmpty
                  ? 'N/A'
                  : student.engagement;
              final engagementColor = engagementLabel.toUpperCase() == 'ENGAGED'
                  ? AppTheme.brandGreen
                  : engagementLabel.toUpperCase() == 'DISTRACTED'
                  ? AppTheme.accentOrange
                  : engagementLabel.toUpperCase() == 'SLEEPING'
                  ? AppTheme.danger
                  : AppTheme.textSecondary;

              final totalBehavior =
                  student.engagedCount +
                  student.distractedCount +
                  student.sleepingCount +
                  student.phoneCount;
              final engagedPercent = totalBehavior > 0
                  ? student.engagedCount / totalBehavior
                  : 0.0;
              final distractedPercent = totalBehavior > 0
                  ? student.distractedCount / totalBehavior
                  : 0.0;
              final sleepingPercent = totalBehavior > 0
                  ? student.sleepingCount / totalBehavior
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    setState(() {
                      _expandedStudentId = expanded ? null : student.id;
                    });
                  },
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      student.subtitle.isNotEmpty
                                          ? student.subtitle
                                          : 'Student code unavailable',
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
                              Row(
                                children: [
                                  _StatusPill(
                                    label: student.status.toUpperCase(),
                                    color: statusIsPresent
                                        ? AppTheme.brandGreen
                                        : AppTheme.danger,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    expanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 20,
                                    color: AppTheme.textSecondaryFor(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          AppSpacing.gap12,
                          _StatusPill(
                            label: engagementLabel,
                            color: engagementColor,
                          ),
                          if (statusIsPresent && student.confidence > 0) ...[
                            AppSpacing.gap12,
                            Text(
                              'Confidence: ${(student.confidence * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryFor(context),
                                  ),
                            ),
                          ],
                          AppSpacing.gap16,
                          Row(
                            children: [
                              _AttendanceStatChip(
                                value: student.engagedCount.toString(),
                                label: 'Engaged',
                                color: AppTheme.brandGreen,
                              ),
                              const SizedBox(width: 8),
                              _AttendanceStatChip(
                                value: student.distractedCount.toString(),
                                label: 'Distracted',
                                color: AppTheme.accentOrange,
                              ),
                              const SizedBox(width: 8),
                              _AttendanceStatChip(
                                value: student.sleepingCount.toString(),
                                label: 'Sleeping',
                                color: AppTheme.danger,
                              ),
                            ],
                          ),
                          if (expanded) ...[
                            AppSpacing.gap16,
                            Text(
                              'Engagement Breakdown',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            AppSpacing.gap12,
                            _buildPercentageRow(
                              context,
                              label: 'Engaged',
                              percent: engagedPercent,
                              color: AppTheme.brandGreen,
                            ),
                            AppSpacing.gap8,
                            _buildPercentageRow(
                              context,
                              label: 'Distracted',
                              percent: distractedPercent,
                              color: AppTheme.accentOrange,
                            ),
                            AppSpacing.gap8,
                            _buildPercentageRow(
                              context,
                              label: 'Sleeping',
                              percent: sleepingPercent,
                              color: AppTheme.danger,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _exportReportCsv() async {
    final rows = <List<String>>[
      ['Class', _selectedClassName],
      ['Code', _selectedClassCode],
      ['Present', _thisSessionPresent.toString()],
      ['Absent', _thisSessionAbsent.toString()],
      [],
      ['Session', 'Date', 'Time', 'Present', 'Absent', 'Attendance %'],
      ..._historyCards.map(
        (item) => [
          item.title,
          item.dateLabel,
          item.timeLabel,
          item.present.toString(),
          item.absent.toString(),
          item.percentage.toStringAsFixed(1),
        ],
      ),
      [],
      [
        'Student',
        'Identifier',
        'Status',
        'Present',
        'Confidence %',
        'Current Engagement',
        'Engaged Count',
        'Distracted Count',
        'Sleeping Count',
        'Phone Count',
        'Engaged %',
        'Distracted %',
        'Sleeping %',
        'Phone %',
      ],
      ..._breakdown.map((student) {
        final totalBehavior = _behaviorTotal(student);
        return [
          student.name,
          student.subtitle,
          student.status,
          student.present ? 'Yes' : 'No',
          (student.confidence * 100).toStringAsFixed(1),
          student.engagement,
          student.engagedCount.toString(),
          student.distractedCount.toString(),
          student.sleepingCount.toString(),
          student.phoneCount.toString(),
          _behaviorPercent(
            student.engagedCount,
            totalBehavior,
          ).toStringAsFixed(1),
          _behaviorPercent(
            student.distractedCount,
            totalBehavior,
          ).toStringAsFixed(1),
          _behaviorPercent(
            student.sleepingCount,
            totalBehavior,
          ).toStringAsFixed(1),
          _behaviorPercent(
            student.phoneCount,
            totalBehavior,
          ).toStringAsFixed(1),
        ];
      }),
    ];
    await _shareCsv(
      fileName: '${_safeFileName(_selectedClassName)}_class_report.csv',
      rows: rows,
    );
  }

  Future<void> _shareCsv({
    required String fileName,
    required List<List<String>> rows,
  }) async {
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\n');
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(csv)),
      mimeType: 'text/csv',
      name: fileName,
    );

    try {
      await Share.shareXFiles(
        [file],
        text: 'Attendance report export',
        subject: fileName,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export CSV: $error')));
    }
  }

  _ReportStudent _reportStudentFromDynamic(dynamic item) {
    final status = _stringValue(item, [
      'final_status',
      'status',
      'attendance_status',
      'remark',
    ], 'ABSENT').toUpperCase();
    final isPresent = status == 'PRESENT';
    final engagement = _stringValue(item, [
      'final_engagement',
      'engagement',
      'engaged_status',
    ], '').toUpperCase();

    return _ReportStudent(
      id: _stringValue(item, ['student_id', 'id']),
      name: _stringValue(item, [
        'full_name',
        'student_full_name',
        'student_name',
        'name',
      ], 'Student'),
      subtitle: _stringValue(item, [
        'student_code',
        'code',
        'roll_no',
        'registration_no',
        'student_id',
        'id',
      ]),
      status: status,
      present: isPresent,
      color: _statusColor(status, isPresent),
      confidence: _doubleValue(item, [
        'confidence',
        'confidence_score',
      ], fallback: 0),
      engagement: engagement,
      engagedCount: _intValue(item, ['engaged_count', 'engaged'], fallback: 0),
      distractedCount: _intValue(item, [
        'distracted_count',
        'distracted',
      ], fallback: 0),
      sleepingCount: _intValue(item, [
        'sleeping_count',
        'sleeping',
      ], fallback: 0),
      phoneCount: _intValue(item, ['phone_count', 'phone'], fallback: 0),
    );
  }

  _ReportStudent _reportStudentFromClassStudent(Map<String, dynamic> item) {
    return _ReportStudent(
      id: _stringValue(item, ['student_id', 'id']),
      name: _stringValue(item, [
        'full_name',
        'student_full_name',
        'student_name',
        'name',
      ], 'Student'),
      subtitle: _stringValue(item, [
        'student_code',
        'code',
        'roll_no',
        'registration_no',
        'student_id',
        'id',
      ]),
      status: 'ABSENT',
      present: false,
      color: AppTheme.accentOrange,
      confidence: 0,
      engagement: 'N/A',
      engagedCount: 0,
      distractedCount: 0,
      sleepingCount: 0,
      phoneCount: 0,
    );
  }

  int _behaviorTotal(_ReportStudent student) {
    return student.engagedCount +
        student.distractedCount +
        student.sleepingCount +
        student.phoneCount;
  }

  double _behaviorPercent(int count, int total) {
    if (total <= 0) {
      return 0;
    }
    return (count / total) * 100;
  }
}

class _ReportTabs extends StatelessWidget {
  const _ReportTabs({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['This Session', 'Class History', 'By Student'];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderFor(context))),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == currentIndex;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? AppTheme.brandGreen
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? AppTheme.textPrimaryFor(context)
                        : AppTheme.textSecondaryFor(context),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
          AppSpacing.gap8,
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

class _HistoryStudentRow extends StatelessWidget {
  const _HistoryStudentRow({required this.student});

  final _ReportStudent student;

  @override
  Widget build(BuildContext context) {
    final icon = student.present ? Icons.check_box : Icons.close;
    final iconColor = student.present
        ? AppTheme.brandGreen
        : AppTheme.accentOrange;
    final engagementLabel = student.present
        ? (student.engagement.isEmpty ? 'N/A' : student.engagement)
        : '—';

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            student.name,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 56,
          child: Text(
            student.subtitle.isEmpty ? '-' : student.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryFor(context),
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: Text(
            engagementLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryFor(context),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final String title;
  final String value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceStatChip extends StatelessWidget {
  const _AttendanceStatChip({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltFor(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryFor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildPercentageRow(
  BuildContext context, {
  required String label,
  required double percent,
  required Color color,
}) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(percent * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryFor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: percent.clamp(0.0, 1.0),
                backgroundColor: AppTheme.surfaceAltFor(context),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SessionHistoryView {
  const _SessionHistoryView({
    required this.sessionId,
    required this.title,
    required this.dateLabel,
    required this.timeLabel,
    required this.present,
    required this.absent,
    required this.percentage,
    required this.students,
  });

  final String sessionId;
  final String title;
  final String dateLabel;
  final String timeLabel;
  final int present;
  final int absent;
  final double percentage;
  final List<_ReportStudent> students;
}

class _ReportStudent {
  const _ReportStudent({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.present,
    required this.color,
    required this.confidence,
    required this.engagement,
    required this.engagedCount,
    required this.distractedCount,
    required this.sleepingCount,
    required this.phoneCount,
  });

  final String id;
  final String name;
  final String subtitle;
  final String status;
  final bool present;
  final Color color;
  final double confidence;
  final String engagement;
  final int engagedCount;
  final int distractedCount;
  final int sleepingCount;
  final int phoneCount;

  String get initials => _initials(name);
}

String _joinNonEmpty(List<String> values, {String separator = ' • '}) {
  final filtered = values.where((value) => value.trim().isNotEmpty).toList();
  return filtered.join(separator);
}

List<Map<String, dynamic>> _extractResponseList(
  dynamic response,
  List<String> keys,
) {
  if (response is List) {
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  final values = _listValue(response, keys);
  return values
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _classValue(dynamic item, List<String> keys) {
  final direct = _stringValue(item, keys);
  if (direct.isNotEmpty) return direct;
  final nested = _findValue(item, keys, nestedKeys: const ['class']);
  if (nested == null) return '';
  return nested.toString().trim();
}

String _stringValue(dynamic item, List<String> keys, [String fallback = '']) {
  final value = _findValue(
    item,
    keys,
    nestedKeys: const ['class', 'teacher', 'student', 'session', 'data'],
  );
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _intValue(dynamic item, List<String> keys, {int fallback = 0}) {
  final value = _findValue(
    item,
    keys,
    nestedKeys: const ['class', 'teacher', 'student', 'session', 'data'],
  );
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _doubleValue(dynamic item, List<String> keys, {double fallback = 0}) {
  final value = _findValue(
    item,
    keys,
    nestedKeys: const ['class', 'teacher', 'student', 'session', 'data'],
  );
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

List<dynamic> _listValue(dynamic item, List<String> keys) {
  final value = _findValue(
    item,
    keys,
    nestedKeys: const ['data', 'report', 'session'],
  );
  if (value is List) return value;
  return const [];
}

dynamic _findValue(
  dynamic item,
  List<String> keys, {
  required List<String> nestedKeys,
  int depth = 0,
}) {
  if (item is! Map || depth > 3) return null;
  for (final key in keys) {
    if (item.containsKey(key) && item[key] != null) {
      return item[key];
    }
  }
  for (final nestedKey in nestedKeys) {
    final nestedValue = item[nestedKey];
    final resolved = _findValue(
      nestedValue,
      keys,
      nestedKeys: nestedKeys,
      depth: depth + 1,
    );
    if (resolved != null) return resolved;
  }
  return null;
}

Color _statusColor(String status, bool present) {
  final normalized = status.toLowerCase();
  if (normalized.contains('phone')) return AppTheme.accentOrange;
  if (normalized.contains('sleep')) return AppTheme.accentPurple;
  if (normalized.contains('absent')) return AppTheme.danger;
  return present ? AppTheme.brandGreen : AppTheme.accentOrange;
}

String _initials(String name) {
  if (name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return parts.take(2).map((part) => part.substring(0, 1).toUpperCase()).join();
}

String _safeFileName(String value) {
  final sanitized = value
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return sanitized.isEmpty ? 'report' : sanitized.toLowerCase();
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
