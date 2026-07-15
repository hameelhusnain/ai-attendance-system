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
  bool _historyLoading = true;
  String? _expandedHistorySessionId;
  String? _preferredReportSessionId;
  DateTimeRange? _selectedDateRange;

  List<_SessionHistoryView> _historyCards = const [];
  List<_ReportStudent> _breakdown = const [];

  @override
  void initState() {
    super.initState();
    _initializeReport();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeReport() async {
    _preferredReportSessionId = await SessionStore.consumeReportSessionId();
    await _loadReportData();
  }

  Map<String, dynamic> get _selectedClass => SessionStore.selectedClass ?? const {};

  String get _selectedClassId =>
      _stringValue(_selectedClass, ['id', 'class_id', 'classId']);

  String get _selectedClassName => _stringValue(_selectedClass, [
    'name',
    'class_name',
    'title',
  ], 'Selected Class');

  bool get _canExportReport => _historyCards.isNotEmpty || _breakdown.isNotEmpty;

  Map<String, dynamic> _classQueryParameters() {
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

  Map<String, dynamic> _reportQueryParameters() {
    final query = <String, dynamic>{..._classQueryParameters()};
    final range = _selectedDateRange;
    if (range == null) {
      return query;
    }

    final from = _formatDate(range.start);
    final to = _formatDate(range.end);
    query['date_from'] = from;
    query['from_date'] = from;
    query['start_date'] = from;
    query['date_to'] = to;
    query['to_date'] = to;
    query['end_date'] = to;
    return query;
  }

  Future<void> _loadReportData() async {
    if (mounted) {
      setState(() {
        _historyLoading = true;
        _expandedHistorySessionId = null;
      });
    }

    final api = ApiService();
    dynamic sessionsResponse;
    final query = _reportQueryParameters();
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
    final filteredSessions = _applyDateFilter(resolvedSessions, _selectedDateRange);
    final activeSessionId = SessionStore.currentSessionId;
    final activeClassId = _stringValue(SessionStore.selectedClass, [
      'id',
      'class_id',
      'classId',
    ]);
    final latestSessionId = _mostRecentSessionId(filteredSessions);
    final selectedReportSessionId =
        _preferredReportSessionId != null &&
            _preferredReportSessionId!.isNotEmpty
        ? _preferredReportSessionId
        : activeSessionId != null &&
              activeSessionId.isNotEmpty &&
              activeClassId.isNotEmpty &&
              activeClassId == _selectedClassId
        ? activeSessionId
        : latestSessionId;
    final historyCards = await _buildHistoryCards(
      filteredSessions,
      classStudents: classStudents,
      fallbackStudentCount: classStudents.length,
      prioritizedSessionId: selectedReportSessionId,
    );

    if (!mounted) return;
    setState(() {
      _historyCards = historyCards;
      _historyLoading = false;
      _preferredReportSessionId = null;
    });

    final breakdown = await _loadBreakdown(
      selectedReportSessionId,
      classStudents,
    );

    if (!mounted) return;
    setState(() {
      _breakdown = breakdown;
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
    final orderedSessions = [...sessions]
      ..sort((a, b) {
        final aDate = _sessionSortDate(a);
        final bDate = _sessionSortDate(b);
        if (aDate != null && bDate != null) {
          final comparison = bDate.compareTo(aDate);
          if (comparison != 0) {
            return comparison;
          }
        } else if (aDate != null) {
          return -1;
        } else if (bDate != null) {
          return 1;
        }

        final aTime = _sessionSortTime(a);
        final bTime = _sessionSortTime(b);
        if (aTime != null && bTime != null) {
          final timeComparison = bTime.compareTo(aTime);
          if (timeComparison != 0) {
            return timeComparison;
          }
        }

        final aId = _stringValue(a, ['id', 'session_id']);
        final bId = _stringValue(b, ['id', 'session_id']);
        if (prioritizedSessionId != null && prioritizedSessionId.isNotEmpty) {
          if (aId == prioritizedSessionId && bId != prioritizedSessionId) {
            return -1;
          }
          if (aId != prioritizedSessionId && bId == prioritizedSessionId) {
            return 1;
          }
        }
        return bId.compareTo(aId);
      });

    for (final session in orderedSessions.take(6)) {
      final sessionId = _stringValue(session, ['id', 'session_id']);
      Map<String, dynamic> report = const {};
      List<Map<String, dynamic>> reportRecords = [];

      // First fetch the report to get attendance data
      if (sessionId.isNotEmpty) {
        final response = await _fetchAttendanceSessionReportWithRetry(
          sessionId,
        );
        if (response != null) {
          if (response is Map<String, dynamic>) {
            report = response;
          } else if (response is Map) {
            report = Map<String, dynamic>.from(response);
          }
          // Extract records from the report
          reportRecords = _extractReportItems(response);
        }
      }

      // Use report records if available, otherwise fall back to class students
      final students = reportRecords.isNotEmpty
          ? reportRecords.map(_reportStudentFromDynamic).toList()
          : classStudents.map(_reportStudentFromClassStudent).toList();

      final presentFromStudents = students
          .where((student) => student.present)
          .length;
      final totalFromStudents = students.length;

      // Try to get present/absent from report response first
      final present = _intValue(
        report,
        ['present', 'present_count', 'marked'],
        fallback: totalFromStudents > 0
            ? presentFromStudents
            : _intValue(session, ['present', 'marked'], fallback: 0),
      );
      final total = _intValue(
        report,
        ['total', 'total_students', 'student_count'],
        fallback: totalFromStudents > 0
            ? totalFromStudents
            : _intValue(session, [
                'total',
                'student_count',
                'total_students',
              ], fallback: fallbackStudentCount),
      );
      final absent = _intValue(
        report,
        ['absent', 'absent_count'],
        fallback: total > 0
            ? max(total - present, 0)
            : max(totalFromStudents - presentFromStudents, 0),
      );
      final percentage = _doubleValue(report, [
        'attendance_rate',
        'percentage',
      ], fallback: total > 0 ? (present / total) * 100 : 0);

      cards.add(
        _SessionHistoryView(
          sessionId: sessionId,
          title: _stringValue(session, [
            'title',
            'label',
            'name',
          ], _selectedClassName),
          dateLabel: _resolveSessionDateLabel(session),
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
      if (response != null) {
        final records = _extractReportItems(response);
        if (records.isNotEmpty) {
          return records.map(_reportStudentFromDynamic).toList();
        }
        // If response is a Map with present/absent counts but no student records,
        // still return class students but mark them based on the report
        if (response is Map && response.isNotEmpty) {
          final presentCount = _intValue(response, ['present', 'present_count'], fallback: -1);
          final absentCount = _intValue(response, ['absent', 'absent_count'], fallback: -1);
          if (presentCount >= 0 || absentCount >= 0) {
            // Report has summary data but no individual records
            // Return class students as all present (fallback behavior)
            return classStudents.map(_reportStudentFromClassStudent).toList();
          }
        }
      }
    } catch (_) {
      // ignore attendance load errors for UI fallback
    }

    return classStudents.map(_reportStudentFromClassStudent).toList();
  }

  Future<List<Map<String, dynamic>>> _loadClassStudents() async {
    final api = ApiService();
    final query = _classQueryParameters();
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
    if (response == null) return const [];
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (response is Map) {
      // Try multiple keys that the API might return
      final listKeys = [
        'students',
        'records',
        'attendance',
        'items',
        'data',
        'report',
        'results',
        'attendance_records',
      ];
      for (final key in listKeys) {
        final value = response[key];
        if (value is List && value.isNotEmpty) {
          return value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
      // If no list found, check nested structures
      final nestedKeys = ['data', 'report', 'session', 'response'];
      for (final nestedKey in nestedKeys) {
        final nested = response[nestedKey];
        if (nested is Map) {
          for (final key in listKeys) {
            final value = nested[key];
            if (value is List && value.isNotEmpty) {
              return value
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
            }
          }
        }
        if (nested is List && nested.isNotEmpty) {
          return nested
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }
    return const [];
  }

  List<Map<String, dynamic>> _normalizeSessions(List<dynamic> sessions) {
    final normalized = <Map<String, dynamic>>[];
    for (final session in sessions) {
      if (session is! Map) continue;
      final map = Map<String, dynamic>.from(session);
      if (_matchesSelectedClass(map) && _isCompletedSession(map)) {
        normalized.add(map);
      }
    }
    return normalized;
  }

  bool _isCompletedSession(Map<String, dynamic> item) {
    final status = _stringValue(item, [
      'status',
      'session_status',
      'state',
    ]).toLowerCase();
    if (status.contains('active') ||
        status.contains('running') ||
        status.contains('open') ||
        status.contains('start') ||
        status.contains('progress')) {
      return false;
    }
    if (status.contains('end') ||
        status.contains('closed') ||
        status.contains('finish') ||
        status.contains('complete') ||
        status.contains('stop')) {
      return true;
    }

    final isClosed = _stringValue(item, ['is_closed', 'closed']).toLowerCase();
    if (isClosed == 'true' || isClosed == '1' || isClosed == 'yes') {
      return true;
    }

    final isActive = _stringValue(item, ['is_active', 'active']).toLowerCase();
    if (isActive == 'true' || isActive == '1' || isActive == 'yes') {
      return false;
    }

    return true;
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
          AppSpacing.gap20,
          _buildClassHistoryTab(context),
        ],
      ),
    );
  }

  Widget _buildClassHistoryTab(BuildContext context) {
    if (_historyLoading && _historyCards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

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
        _buildFilters(context),
        AppSpacing.gap16,
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
          'Previous Sessions (${_historyCards.length})',
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

  Future<void> _exportReportCsv() async {
    final rows = <List<String>>[
      [
        'Date',
        'Student ID',
        'Student Name',
        'Present/Absent',
        'Active %',
        'Sleeping %',
        'Talking %',
        'Engagement %',
      ],
    ];

    final orderedCards = [..._historyCards]
      ..sort((a, b) {
        final aDate = _parseExportDate(a.dateLabel);
        final bDate = _parseExportDate(b.dateLabel);
        final dateComparison = (aDate ?? DateTime(0)).compareTo(
          bDate ?? DateTime(0),
        );
        if (dateComparison != 0) {
          return dateComparison;
        }
        return a.title.compareTo(b.title);
      });

    for (final card in orderedCards) {
      final sortedStudents = [...card.students]
        ..sort((a, b) {
          final nameComparison = a.name.compareTo(b.name);
          if (nameComparison != 0) {
            return nameComparison;
          }
          return a.id.compareTo(b.id);
        });

      for (final student in sortedStudents) {
        final totalBehavior = _behaviorTotal(student);
        final activePercent = _percentValue(student.engagedCount, totalBehavior);
        final sleepingPercent = _percentValue(student.sleepingCount, totalBehavior);
        final talkingPercent = _percentValue(student.talkingCount, totalBehavior);
        final engagementPercent = _percentValue(
          student.confidence > 0 ? (student.confidence * 100).round() : 0,
          100,
        );

        rows.add([
          _exportDateLabel(card.dateLabel),
          student.id.isNotEmpty ? student.id : student.subtitle,
          student.name,
          student.present ? 'Present' : 'Absent',
          '${activePercent.toStringAsFixed(1)}%',
          '${sleepingPercent.toStringAsFixed(1)}%',
          '${talkingPercent.toStringAsFixed(1)}%',
          '${engagementPercent.toStringAsFixed(1)}%',
        ]);
      }
    }

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
      // Use SharePlus.instance.share with ShareParams to match new API.
      await SharePlus.instance.share(ShareParams(text: csv, subject: fileName, files: [file]));
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
      talkingCount: _intValue(item, [
        'talking_count',
        'talking',
        'speaking_count',
        'speaking',
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
      talkingCount: 0,
      phoneCount: 0,
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange =
        _selectedDateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
    );
    if (picked == null) {
      return;
    }
    setState(() => _selectedDateRange = picked);
    await _loadReportData();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedDateRange = null;
    });
    await _loadReportData();
  }

  Widget _buildFilters(BuildContext context) {
    final range = _selectedDateRange;
    final rangeLabel = range == null
        ? 'Any date'
        : '${_formatDate(range.start)} - ${_formatDate(range.end)}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date filter',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          AppSpacing.gap12,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(rangeLabel, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _selectedDateRange == null ? null : _clearFilters,
                child: const Text('Reset'),
              ),
            ],
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
      ],
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
    required this.talkingCount,
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
  final int talkingCount;
  final int phoneCount;

  String get initials => _initials(name);
}

String _joinNonEmpty(List<String> values, {String separator = ' • '}) {
  final filtered = values.where((value) => value.trim().isNotEmpty).toList();
  return filtered.join(separator);
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

List<Map<String, dynamic>> _applyDateFilter(
  List<Map<String, dynamic>> sessions,
  DateTimeRange? range,
) {
  if (range == null) {
    return sessions;
  }

  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(
    range.end.year,
    range.end.month,
    range.end.day,
    23,
    59,
    59,
    999,
  );

  return sessions.where((session) {
    final parsed = _tryParseSessionDate(
      _stringValue(session, [
        'date',
        'session_date',
        'created_at',
        'createdAt',
        'start_date',
        'started_at',
        'timestamp',
      ]),
    );
    return parsed != null && !parsed.isBefore(start) && !parsed.isAfter(end);
  }).toList();
}

DateTime? _tryParseSessionDate(String value) {
  if (value.isEmpty) return null;
  final trimmed = value.trim();

  final numeric = int.tryParse(trimmed);
  if (numeric != null) {
    if (numeric.abs() > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(numeric);
    }
    return DateTime.fromMillisecondsSinceEpoch(numeric * 1000);
  }

  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    final parts = trimmed.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  return DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
}

String _resolveSessionDateLabel(Map<String, dynamic> session) {
  final direct = _stringValue(session, [
    'date',
    'session_date',
    'created_at',
    'createdAt',
    'start_date',
    'started_at',
    'timestamp',
    'created',
  ]);
  final parsed = _tryParseSessionDate(direct);
  if (parsed != null) {
    return _formatDate(parsed);
  }

  final timeValue = _stringValue(session, ['time', 'start_time', 'end_time']);
  final parsedTime = _tryParseSessionDate(timeValue);
  if (parsedTime != null) {
    return _formatDate(parsedTime);
  }

  return '';
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

String? _mostRecentSessionId(List<Map<String, dynamic>> sessions) {
  if (sessions.isEmpty) {
    return null;
  }

  final sorted = [...sessions]
    ..sort((a, b) {
      final aDate = _sessionSortDate(a);
      final bDate = _sessionSortDate(b);
      if (aDate != null && bDate != null) {
        final comparison = bDate.compareTo(aDate);
        if (comparison != 0) {
          return comparison;
        }
      } else if (aDate != null) {
        return -1;
      } else if (bDate != null) {
        return 1;
      }

      final aTime = _sessionSortTime(a);
      final bTime = _sessionSortTime(b);
      if (aTime != null && bTime != null) {
        final timeComparison = bTime.compareTo(aTime);
        if (timeComparison != 0) {
          return timeComparison;
        }
      }

      final aId = _stringValue(a, ['id', 'session_id']);
      final bId = _stringValue(b, ['id', 'session_id']);
      return bId.compareTo(aId);
    });

  return _stringValue(sorted.first, ['id', 'session_id']);
}

DateTime? _sessionSortDate(Map<String, dynamic> session) {
  return _tryParseSessionDate(
    _stringValue(session, [
      'date',
      'session_date',
      'created_at',
      'createdAt',
      'start_date',
      'started_at',
      'timestamp',
      'created',
    ]),
  );
}

String? _sessionSortTime(Map<String, dynamic> session) {
  final direct = _stringValue(session, ['time', 'start_time', 'end_time']);
  if (direct.isEmpty) {
    return null;
  }
  return direct;
}

double _percentValue(int count, int total) {
  if (total <= 0) {
    return 0;
  }
  return (count / total) * 100;
}

int _behaviorTotal(_ReportStudent student) {
  return student.engagedCount +
      student.distractedCount +
      student.sleepingCount +
      student.talkingCount +
      student.phoneCount;
}

String _exportDateLabel(String value) {
  final parsed = _parseExportDate(value);
  if (parsed == null) {
    return value;
  }
  return '${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.year}';
}

DateTime? _parseExportDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final parsed = DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
  if (parsed != null) return parsed;

  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    final parts = trimmed.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  return null;
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
