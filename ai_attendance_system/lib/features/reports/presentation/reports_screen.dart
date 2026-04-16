import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _sessions = const [];
  List<Map<String, dynamic>> _students = const [];
  String? _selectedSessionId;
  List<Map<String, dynamic>> _reportRows = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    dynamic sessionsResponse;
    dynamic studentsResponse;
    try {
      sessionsResponse = await ApiService().getSessions();
    } catch (_) {}
    try {
      studentsResponse = await ApiService().getStudents();
    } catch (_) {}

    final sessions = _extractList(sessionsResponse, const ['sessions', 'items', 'data']);
    final students = _extractList(studentsResponse, const ['students', 'items', 'data']);
    final selectedSessionId = _findSessionId(sessions.isNotEmpty ? sessions.first : null);

    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _students = students;
      _selectedSessionId = selectedSessionId;
      _loading = false;
    });

    if (selectedSessionId != null) {
      await _loadAttendanceReport(selectedSessionId);
    }
  }

  String? _findSessionId(Map<String, dynamic>? session) {
    if (session == null) return null;
    final id = _readValue(session, const ['id', 'session_id', 'sessionId']);
    return id.isNotEmpty ? id : null;
  }

  Future<void> _loadAttendanceReport(String sessionId) async {
    dynamic reportResponse;
    try {
      reportResponse = await ApiService().getAttendanceSessionReport(sessionId);
    } catch (_) {
      reportResponse = null;
    }
    if (!mounted) return;
    setState(() {
      _selectedSessionId = sessionId;
      _reportRows = _extractReportRows(reportResponse);
    });
  }

  List<Map<String, dynamic>> _extractReportRows(dynamic response) {
    if (response is List) {
      return response.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (response is Map) {
      return _extractList(response, const ['students', 'records', 'attendance', 'items']);
    }
    return const [];
  }

  int get _presentCount {
    return _reportRows.where((row) {
      final status = _readValue(row, const ['final_status', 'status', 'attendance_status']).toLowerCase();
      return status.contains('present');
    }).length;
  }

  int get _absentCount {
    return _reportRows.length - _presentCount;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);

    final totalStudents = _students.length;
    final totalSessions = _sessions.length;
    final closedSessions = _sessions
        .where((session) =>
            _readValue(session, const ['status', 'session_status']).toLowerCase().contains('closed'))
        .length;
    final openSessions = totalSessions - closedSessions;

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final cards = [
                  _SummaryCard(title: 'Total Students', value: totalStudents.toString()),
                  _SummaryCard(title: 'Total Sessions', value: totalSessions.toString()),
                  _SummaryCard(title: 'Closed Sessions', value: closedSessions.toString()),
                  _SummaryCard(title: 'Open Sessions', value: openSessions.toString()),
                ];

                if (isWide) {
                  return Row(
                    children: [
                      for (final card in cards) ...[
                        Expanded(child: card),
                        if (card != cards.last) const SizedBox(width: 16),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    for (final card in cards) ...[
                      card,
                      AppSpacing.gap12,
                    ],
                  ],
                );
              },
            ),
            AppSpacing.gap16,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Reports',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  AppSpacing.gap12,
                  if (_sessions.isEmpty)
                    Text(
                      'No reportable sessions available.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                    )
                  else ...[
                    for (final session in _sessions.take(8))
                      InkWell(
                        onTap: () {
                          final sessionId = _findSessionId(session);
                          if (sessionId != null) {
                            _loadAttendanceReport(sessionId);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedSessionId != null && _selectedSessionId == _findSessionId(session)
                                ? AppTheme.surfaceCard.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _readValue(session, const ['title', 'name', 'label'],
                                        fallback: 'Session'),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  Text(
                                    _readValue(session, const ['date', 'session_date', 'created_at'],
                                        fallback: 'Recent'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                                  ),
                                ],
                              ),
                              _StatusChip(
                                status: _readValue(
                                  session,
                                  const ['status', 'session_status'],
                                  fallback: 'Recorded',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    AppSpacing.gap16,
                    if (_selectedSessionId != null)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Session Attendance',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            AppSpacing.gap12,
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryCard(
                                    title: 'Present',
                                    value: _presentCount.toString(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryCard(
                                    title: 'Absent',
                                    value: _absentCount.toString(),
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.gap16,
                            Text(
                              'Students',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            AppSpacing.gap12,
                            if (_reportRows.isEmpty)
                              Text(
                                'No attendance rows available for this session.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                              )
                            else
                              Column(
                                children: [
                                  for (final row in _reportRows.take(12))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _readValue(row, const ['full_name', 'student_name', 'name'],
                                                  fallback: 'Student'),
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                          ),
                                          Text(
                                            _readValue(row, const ['final_status', 'status', 'attendance_status'],
                                                fallback: 'ABSENT'),
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          AppSpacing.gap12,
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
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
    final color = status.toLowerCase().contains('closed')
        ? AppTheme.brandGreen
        : AppTheme.accentOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

List<Map<String, dynamic>> _extractList(dynamic response, List<String> keys) {
  if (response is List) {
    return response.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  if (response is Map) {
    for (final key in keys) {
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
  List<String> nestedKeys = const ['class', 'session', 'data'],
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
