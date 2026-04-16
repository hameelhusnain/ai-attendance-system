import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
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

  Map<String, dynamic> get _selectedClass => SessionStore.selectedClass ?? const {};

  String get _selectedClassId =>
      _stringValue(_selectedClass, ['id', 'class_id', 'classId']);

  String get _selectedClassName => _stringValue(
        _selectedClass,
        ['name', 'class_name', 'title'],
        'Selected Class',
      );

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
    final pieces = [_selectedClassName, _selectedClassCode]..removeWhere((e) => e.isEmpty);
    return pieces.join('  •  ');
  }

  int get _thisSessionPresent {
    if (_historyCards.isNotEmpty) return _historyCards.first.present;
    return _breakdown.where((student) => student.present).length;
  }

  int get _thisSessionAbsent {
    if (_historyCards.isNotEmpty) return _historyCards.first.absent;
    return _breakdown.where((student) => !student.present).length;
  }

  Map<String, dynamic> _reportQueryParameters() {
    final selectedClass = _selectedClass;
    final query = <String, dynamic>{};
    final classId = _stringValue(selectedClass, ['id', 'class_id', 'classId']);
    final className = _stringValue(selectedClass, ['name', 'class_name', 'title']);
    final teacherId = _stringValue(selectedClass, ['teacher_id', 'teacherId', 'tutor_id']);
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

    try {
      sessionsResponse = await api.getSessionsFiltered(queryParameters: query);
    } catch (_) {}
    sessionsResponse ??= await _safeCall(() => api.getSessions());

    final sessionsRaw = _extractResponseList(sessionsResponse, const ['sessions', 'items', 'data']);
    final sessions = _normalizeSessions(sessionsRaw);
    final resolvedSessions = sessions.isNotEmpty ? sessions : sessionsRaw;
    final historyCards = await _buildHistoryCards(resolvedSessions);
    final activeSessionId = SessionStore.currentSessionId;
    final selectedReportSessionId = activeSessionId != null && activeSessionId.isNotEmpty
        ? activeSessionId
        : historyCards.isNotEmpty
            ? historyCards.first.sessionId
            : null;
    final breakdown = await _loadBreakdown(selectedReportSessionId);

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
    List<Map<String, dynamic>> sessions,
  ) async {
    final cards = <_SessionHistoryView>[];

    for (final session in sessions.take(6)) {
      final sessionId = _stringValue(session, ['id', 'session_id']);
      Map<String, dynamic> report = const {};

      if (sessionId.isNotEmpty) {
        final response = await _fetchAttendanceSessionReportWithRetry(sessionId);
        if (response is Map<String, dynamic>) {
          report = response;
        } else if (response is Map) {
          report = Map<String, dynamic>.from(response);
        }
      }

      final present = _intValue(report, ['present', 'present_count'],
          fallback: _intValue(session, ['present', 'marked'], fallback: 0));
      final total = _intValue(report, ['total', 'total_students'],
          fallback: _intValue(session, ['total', 'student_count'], fallback: 0));
      final absent = _intValue(report, ['absent', 'absent_count'],
          fallback: total > 0 ? total - present : 0);
      final percentage = _doubleValue(report, ['attendance_rate', 'percentage'],
          fallback: total > 0 ? (present / total) * 100 : 0);

      cards.add(
        _SessionHistoryView(
          sessionId: sessionId,
          title: _stringValue(
            session,
            ['title', 'label', 'name'],
            _selectedClassName,
          ),
          dateLabel: _stringValue(
            session,
            ['date', 'session_date', 'created_at'],
            'Recent Session',
          ),
          timeLabel: _joinNonEmpty([
            _stringValue(session, ['time', 'start_time']),
            _stringValue(session, ['end_time']),
          ], separator: ' - '),
          present: present,
          absent: absent,
          percentage: percentage,
        ),
      );
    }

    return cards;
  }

  Future<List<_ReportStudent>> _loadBreakdown(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) {
      return const [];
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

    return const [];
  }

  Future<dynamic> _fetchAttendanceSessionReportWithRetry(
    String sessionId, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    dynamic lastResponse;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await ApiService().getAttendanceSessionReport(sessionId);
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
    return _listValue(response, ['students', 'records', 'attendance', 'items'])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
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
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Report',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          AppSpacing.gap8,
          Text(
            _reportSubtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondaryFor(context)),
          ),
          AppSpacing.gap20,
          _ReportTabs(
            currentIndex: _tabIndex,
            onChanged: (value) => setState(() => _tabIndex = value),
          ),
          AppSpacing.gap16,
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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
            onPressed: _historyCards.isEmpty ? null : _exportClassReport,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Generate Class Report'),
          ),
        ),
        AppSpacing.gap12,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Breakdown',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              AppSpacing.gap12,
              if (_breakdown.isEmpty)
                Text(
                  'No student breakdown available for this session.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textSecondaryFor(context)),
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
                        backgroundColor: student.color.withOpacity(0.14),
                        child: Text(student.initials),
                      ),
                      title: Text(student.name),
                      subtitle: student.subtitle.isEmpty ? null : Text(student.subtitle),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusPill(label: student.status, color: student.color),
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
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.textSecondaryFor(context)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _historyCards.isEmpty ? null : _exportClassReport,
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
            return AppCard(
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
                              item.dateLabel,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (item.timeLabel.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.timeLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          _CountPair(
                            label: 'Present',
                            value: item.present.toString(),
                            color: AppTheme.brandGreen,
                          ),
                          const SizedBox(width: 18),
                          _CountPair(
                            label: 'Absent',
                            value: item.absent.toString(),
                            color: AppTheme.accentOrange,
                          ),
                        ],
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
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.brandGreen),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.percentage.toStringAsFixed(0)}% attendance',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildByStudentTab(BuildContext context) {
    final presentCount = _breakdown.where((student) => student.status.toUpperCase() == 'PRESENT').length;
    final absentCount = _breakdown.length - presentCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryStatCard(
                title: 'Present',
                value: presentCount.toString(),
                color: AppTheme.brandGreen,
                backgroundColor: AppTheme.brandGreen.withOpacity(0.14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryStatCard(
                title: 'Absent',
                value: absentCount.toString(),
                color: AppTheme.danger,
                backgroundColor: AppTheme.danger.withOpacity(0.14),
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
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textSecondaryFor(context)),
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
              final statusIsPresent = student.status.toUpperCase() == 'PRESENT';
              final engagementLabel = student.engagement.isEmpty ? 'N/A' : student.engagement;
              final engagementColor = engagementLabel.toUpperCase() == 'ENGAGED'
                  ? AppTheme.brandGreen
                  : engagementLabel.toUpperCase() == 'DISTRACTED'
                      ? AppTheme.accentOrange
                      : engagementLabel.toUpperCase() == 'SLEEPING'
                          ? AppTheme.danger
                          : AppTheme.textSecondary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
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
                                    student.subtitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                                  ),
                                ],
                              ),
                            ),
                            _StatusPill(
                              label: student.status.toUpperCase(),
                              color: statusIsPresent ? AppTheme.brandGreen : AppTheme.danger,
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                          ),
                        ],
                        AppSpacing.gap16,
                        Row(
                          children: [
                            _AttendanceStatChip(
                              icon: '👁',
                              value: student.engagedCount.toString(),
                              label: 'Engaged',
                              color: AppTheme.brandGreen,
                            ),
                            const SizedBox(width: 8),
                            _AttendanceStatChip(
                              icon: '😵',
                              value: student.distractedCount.toString(),
                              label: 'Distracted',
                              color: AppTheme.accentOrange,
                            ),
                            const SizedBox(width: 8),
                            _AttendanceStatChip(
                              icon: '😴',
                              value: student.sleepingCount.toString(),
                              label: 'Sleeping',
                              color: AppTheme.danger,
                            ),
                            const SizedBox(width: 8),
                            _AttendanceStatChip(
                              icon: '📱',
                              value: student.phoneCount.toString(),
                              label: 'Phone',
                              color: AppTheme.textSecondary,
                            ),
                          ],
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

  Future<void> _exportClassReport() async {
    final rows = <List<String>>[
      ['Class', _selectedClassName],
      ['Code', _selectedClassCode],
      ['Present', _thisSessionPresent.toString()],
      ['Absent', _thisSessionAbsent.toString()],
      [],
      ['Session', 'Date', 'Time', 'Present', 'Absent', 'Attendance %'],
      ..._historyCards.map((item) => [
            item.title,
            item.dateLabel,
            item.timeLabel,
            item.present.toString(),
            item.absent.toString(),
            item.percentage.toStringAsFixed(1),
          ]),
      [],
      ['Student', 'Identifier', 'Status', 'Present'],
      ..._breakdown.map((student) => [
            student.name,
            student.subtitle,
            student.status,
            student.present ? 'Yes' : 'No',
          ]),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export CSV: $error')),
      );
    }
  }

  _ReportStudent _reportStudentFromDynamic(dynamic item) {
    final status = _stringValue(
      item,
      ['final_status', 'status', 'attendance_status', 'remark'],
      'ABSENT',
    ).toUpperCase();
    final isPresent = status == 'PRESENT';
    final engagement = _stringValue(
      item,
      ['final_engagement', 'engagement', 'engaged_status'],
      '',
    ).toUpperCase();

    return _ReportStudent(
      id: _stringValue(item, ['student_id', 'id']),
      name: _stringValue(
        item,
        ['full_name', 'student_full_name', 'student_name', 'name'],
        'Student',
      ),
      subtitle: _stringValue(item, ['student_code', 'roll_no', 'registration_no', 'id']),
      status: status,
      present: isPresent,
      color: _statusColor(status, isPresent),
      confidence: _doubleValue(item, ['confidence', 'confidence_score'], fallback: 0),
      engagement: engagement,
      engagedCount: _intValue(item, ['engaged_count', 'engaged'], fallback: 0),
      distractedCount: _intValue(item, ['distracted_count', 'distracted'], fallback: 0),
      sleepingCount: _intValue(item, ['sleeping_count', 'sleeping'], fallback: 0),
      phoneCount: _intValue(item, ['phone_count', 'phone'], fallback: 0),
    );
  }

}

class _ReportTabs extends StatelessWidget {
  const _ReportTabs({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['This Session', 'Class History', 'By Student'];
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderFor(context)),
        ),
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
                      color: selected ? AppTheme.brandGreen : Colors.transparent,
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
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textSecondaryFor(context)),
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

class _CountPair extends StatelessWidget {
  const _CountPair({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppTheme.textSecondaryFor(context)),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
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
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondaryFor(context)),
          ),
        ],
      ),
    );
  }
}

class _AttendanceStatChip extends StatelessWidget {
  const _AttendanceStatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final String icon;
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(icon),
            const SizedBox(width: 8),
            Expanded(
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
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  });

  final String sessionId;
  final String title;
  final String dateLabel;
  final String timeLabel;
  final int present;
  final int absent;
  final double percentage;
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

List<Map<String, dynamic>> _extractResponseList(dynamic response, List<String> keys) {
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
