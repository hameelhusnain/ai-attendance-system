import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/models/session_history.dart';
import '../../../shared/models/student.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/mock_data_service.dart';
import '../../../shared/services/session_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _studentSearchController;

  bool _loading = true;
  bool _loadingStudentHistory = false;
  bool _studentSearchExpanded = true;
  int _tabIndex = 0;
  String _studentQuery = '';

  List<Map<String, dynamic>> _students = const [];
  List<_SessionHistoryView> _historyCards = const [];
  List<_ReportStudent> _breakdown = _reportStudents;
  Map<String, dynamic>? _selectedStudent;
  List<_StudentHistoryEntry> _studentHistory = const [];

  @override
  void initState() {
    super.initState();
    _studentSearchController = TextEditingController();
    _loadReportData();
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
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

  Future<void> _loadReportData() async {
    final api = ApiService();
    List<dynamic> sessionsRaw = const [];
    List<dynamic> studentsRaw = const [];

    try {
      final response = await api.getSessions();
      if (response is List) sessionsRaw = response;
    } catch (_) {}

    try {
      final response = await api.getStudents();
      if (response is List) studentsRaw = response;
    } catch (_) {}

    final students = _normalizeStudents(studentsRaw);
    final sessions = _normalizeSessions(sessionsRaw);

    final resolvedStudents = students.isNotEmpty ? students : _mockStudentsForSelectedClass();
    final resolvedSessions = sessions.isNotEmpty ? sessions : _mockSessionsForSelectedClass();
    final historyCards = await _buildHistoryCards(resolvedSessions);
    final breakdown = await _loadBreakdown(
      historyCards.isNotEmpty ? historyCards.first.sessionId : null,
    );
    final selectedStudent = resolvedStudents.isNotEmpty ? resolvedStudents.first : null;
    final studentHistory = selectedStudent != null
        ? await _fetchStudentHistoryFor(selectedStudent)
        : const <_StudentHistoryEntry>[];

    if (!mounted) return;
    setState(() {
      _students = resolvedStudents;
      _historyCards = historyCards;
      _breakdown = breakdown;
      _selectedStudent = selectedStudent;
      _studentHistory = studentHistory;
      _loading = false;
    });
  }

  Future<List<_SessionHistoryView>> _buildHistoryCards(
    List<Map<String, dynamic>> sessions,
  ) async {
    final api = ApiService();
    final cards = <_SessionHistoryView>[];

    for (final session in sessions.take(6)) {
      final sessionId = _stringValue(session, ['id', 'session_id']);
      Map<String, dynamic> report = const {};

      if (sessionId.isNotEmpty) {
        try {
          final response = await api.getAttendanceSessionReport(sessionId);
          if (response is Map<String, dynamic>) {
            report = response;
          } else if (response is Map) {
            report = Map<String, dynamic>.from(response);
          }
        } catch (_) {}
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
    if (sessionId == null || sessionId.isEmpty) return _reportStudents;

    try {
      final response = await ApiService().getAttendanceSessionReport(sessionId);
      final records = _listValue(response, ['students', 'records', 'attendance', 'items']);
      if (records.isNotEmpty) {
        return records.map(_reportStudentFromDynamic).toList();
      }
    } catch (_) {}

    return _reportStudents;
  }

  Future<void> _selectStudent(Map<String, dynamic> student) async {
    setState(() {
      _selectedStudent = student;
      _loadingStudentHistory = true;
    });

    final history = await _fetchStudentHistoryFor(student);
    if (!mounted) return;

    setState(() {
      _studentHistory = history;
      _loadingStudentHistory = false;
      _studentSearchExpanded = false;
    });
  }

  Future<List<_StudentHistoryEntry>> _fetchStudentHistoryFor(
    Map<String, dynamic> student,
  ) async {
    final studentId = _stringValue(student, ['id', 'student_id']);
    if (studentId.isNotEmpty) {
      try {
        final response = await ApiService().getStudentAttendanceHistory(studentId);
        final records = _listValue(response, ['history', 'records', 'sessions', 'items']);
        if (records.isNotEmpty) {
          return records.map(_studentHistoryFromDynamic).toList();
        }
      } catch (_) {}
    }

    return _mockStudentHistory(student);
  }

  List<Map<String, dynamic>> _normalizeStudents(List<dynamic> students) {
    final normalized = <Map<String, dynamic>>[];
    for (final student in students) {
      if (student is! Map) continue;
      final map = Map<String, dynamic>.from(student as Map);
      if (_matchesSelectedClass(map)) normalized.add(map);
    }
    return normalized;
  }

  List<Map<String, dynamic>> _normalizeSessions(List<dynamic> sessions) {
    final normalized = <Map<String, dynamic>>[];
    for (final session in sessions) {
      if (session is! Map) continue;
      final map = Map<String, dynamic>.from(session as Map);
      if (_matchesSelectedClass(map)) normalized.add(map);
    }
    return normalized;
  }

  List<Map<String, dynamic>> _mockStudentsForSelectedClass() {
    return MockDataService.students
        .where((student) {
          if (_selectedClassName == 'Selected Class') return true;
          return student.className.toLowerCase() == _selectedClassName.toLowerCase();
        })
        .map(_studentToMap)
        .toList();
  }

  List<Map<String, dynamic>> _mockSessionsForSelectedClass() {
    return MockDataService.sessions
        .where((session) {
          if (_selectedClassName == 'Selected Class') return true;
          return session.className.toLowerCase() == _selectedClassName.toLowerCase();
        })
        .map(_sessionToMap)
        .toList();
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
    final filteredStudents = _students.where((student) {
      if (_studentQuery.trim().isEmpty) return true;
      final query = _studentQuery.toLowerCase();
      final name = _stringValue(student, ['name', 'student_name']).toLowerCase();
      final id = _stringValue(student, ['id', 'student_id']).toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();

    final selectedStudent = _selectedStudent;
    final studentSummary = _summarizeStudentHistory(selectedStudent, _studentHistory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _studentSearchExpanded = !_studentSearchExpanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select A Student',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Icon(
                        _studentSearchExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondaryFor(context),
                      ),
                    ],
                  ),
                ),
              ),
              if (_studentSearchExpanded) ...[
                AppSpacing.gap12,
                AppTextField(
                  label: 'Search Student',
                  hintText: 'Search by name or ID',
                  controller: _studentSearchController,
                  requiredField: false,
                  prefixIcon: const Icon(Icons.search),
                  onChanged: (value) => setState(() => _studentQuery = value),
                ),
                AppSpacing.gap12,
                if (filteredStudents.isEmpty)
                  Text(
                    'No students found.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                  )
                else
                  ListView.separated(
                    itemCount: filteredStudents.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      final selectedId = _stringValue(_selectedStudent, ['id', 'student_id']);
                      final studentId = _stringValue(student, ['id', 'student_id']);
                      final isSelected = selectedId.isNotEmpty && selectedId == studentId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: (isSelected
                                  ? AppTheme.brandGreen
                                  : AppTheme.accentPurple)
                              .withOpacity(0.14),
                          child: Text(_initials(_stringValue(student, ['name', 'student_name']))),
                        ),
                        title: Text(_stringValue(student, ['name', 'student_name'], 'Student')),
                        subtitle: Text(_stringValue(student, ['id', 'student_id'], '')),
                        trailing: Icon(
                          isSelected ? Icons.check_circle : Icons.chevron_right,
                          color: isSelected
                              ? AppTheme.brandGreen
                              : AppTheme.textSecondaryFor(context),
                        ),
                        onTap: () => _selectStudent(student),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
        AppSpacing.gap16,
        if (selectedStudent == null)
          AppCard(
            child: Text(
              'Select a student to see attendance details.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondaryFor(context)),
            ),
          )
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.accentPurple.withOpacity(0.14),
                      child: Text(
                        _initials(_stringValue(selectedStudent, ['name', 'student_name'])),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.accentPurple,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stringValue(selectedStudent, ['name', 'student_name'], 'Student'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _stringValue(selectedStudent, ['id', 'student_id'], ''),
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
                AppSpacing.gap16,
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatCard(
                        title: 'Present',
                        value: studentSummary.present.toString(),
                        color: AppTheme.brandGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatCard(
                        title: 'Absent',
                        value: studentSummary.absent.toString(),
                        color: AppTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatCard(
                        title: 'Rate',
                        value: '${studentSummary.rate.toStringAsFixed(0)}%',
                        color: AppTheme.accentPurple,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gap16,
                if (_loadingStudentHistory)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2))
                else
                  ListView.separated(
                    itemCount: _studentHistory.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, _) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final entry = _studentHistory[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                height: 10,
                                width: 10,
                                decoration: BoxDecoration(
                                  color: entry.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                height: 46,
                                width: 2,
                                color: AppTheme.borderFor(context),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.dateLabel} — ${entry.title}',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.note,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondaryFor(context),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  _StudentSummary _summarizeStudentHistory(
    Map<String, dynamic>? student,
    List<_StudentHistoryEntry> history,
  ) {
    final present = history.where((entry) => entry.present).length;
    final absent = history.where((entry) => !entry.present).length;
    final total = present + absent;
    final rate = total == 0
        ? _doubleValue(student, ['attendance_rate', 'rate'], fallback: 0)
        : (present / total) * 100;
    return _StudentSummary(
      present: present,
      absent: absent,
      rate: rate,
    );
  }

  _ReportStudent _reportStudentFromDynamic(dynamic item) {
    final status = _stringValue(
      item,
      ['status', 'attendance_status', 'remark'],
      'Present',
    );
    final isPresent = _boolValue(item, ['present', 'is_present'],
        fallback: !status.toLowerCase().contains('absent'));
    return _ReportStudent(
      id: _stringValue(item, ['id', 'student_id']),
      name: _stringValue(item, ['name', 'student_name'], 'Student'),
      subtitle: _stringValue(item, ['roll_no', 'registration_no', 'id']),
      status: status,
      present: isPresent,
      color: _statusColor(status, isPresent),
    );
  }

  _StudentHistoryEntry _studentHistoryFromDynamic(dynamic item) {
    final status = _stringValue(
      item,
      ['status', 'attendance_status'],
      _boolValue(item, ['present', 'is_present'], fallback: true) ? 'Present' : 'Absent',
    );
    final isPresent = _boolValue(item, ['present', 'is_present'],
        fallback: !status.toLowerCase().contains('absent'));
    return _StudentHistoryEntry(
      dateLabel: _stringValue(item, ['date', 'session_date', 'created_at'], 'Recent'),
      title: status,
      note: _stringValue(item, ['note', 'remark', 'details'], 'Attendance recorded'),
      present: isPresent,
      color: _statusColor(status, isPresent),
    );
  }

  List<_StudentHistoryEntry> _mockStudentHistory(Map<String, dynamic> student) {
    final name = _stringValue(student, ['name', 'student_name'], 'Student');
    final records = MockDataService.attendanceRecords
        .where((record) => record.studentName.toLowerCase() == name.toLowerCase())
        .toList();

    if (records.isEmpty) {
      return const [
        _StudentHistoryEntry(
          dateLabel: 'March 28',
          title: 'Present',
          note: 'Engaged throughout session',
          present: true,
          color: AppTheme.brandGreen,
        ),
        _StudentHistoryEntry(
          dateLabel: 'March 27',
          title: 'Present',
          note: 'Distracted — 3 warnings',
          present: true,
          color: AppTheme.brandGreen,
        ),
        _StudentHistoryEntry(
          dateLabel: 'March 25',
          title: 'Absent',
          note: 'No attendance recorded',
          present: false,
          color: AppTheme.accentOrange,
        ),
      ];
    }

    return records.map((record) {
      final present = record.status.toLowerCase() == 'present';
      return _StudentHistoryEntry(
        dateLabel: record.date,
        title: present ? 'Present' : 'Absent',
        note: present ? 'Attendance recorded successfully' : 'No attendance recorded',
        present: present,
        color: present ? AppTheme.brandGreen : AppTheme.accentOrange,
      );
    }).toList();
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

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltFor(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textSecondaryFor(context)),
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
  });

  final String id;
  final String name;
  final String subtitle;
  final String status;
  final bool present;
  final Color color;

  String get initials => _initials(name);
}

class _StudentHistoryEntry {
  const _StudentHistoryEntry({
    required this.dateLabel,
    required this.title,
    required this.note,
    required this.present,
    required this.color,
  });

  final String dateLabel;
  final String title;
  final String note;
  final bool present;
  final Color color;
}

class _StudentSummary {
  const _StudentSummary({
    required this.present,
    required this.absent,
    required this.rate,
  });

  final int present;
  final int absent;
  final double rate;
}

Map<String, dynamic> _studentToMap(Student student) {
  return {
    'id': student.id,
    'name': student.name,
    'student_name': student.name,
    'email': student.email,
    'class_name': student.className,
    'semester': student.semester,
    'batch': student.batch,
    'group': student.group,
    'status': student.status,
    'attendance_rate': student.attendanceRate,
  };
}

Map<String, dynamic> _sessionToMap(SessionHistory session) {
  return {
    'id': session.id,
    'title': session.title,
    'date': session.label,
    'class_name': session.className,
    'department': session.department,
    'semester': session.semester,
    'batch': session.batch,
    'group': session.group,
    'present': session.marked,
    'total': session.total,
    'percentage': session.percentage,
  };
}

String _joinNonEmpty(List<String> values, {String separator = ' • '}) {
  final filtered = values.where((value) => value.trim().isNotEmpty).toList();
  return filtered.join(separator);
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

bool _boolValue(dynamic item, List<String> keys, {bool fallback = false}) {
  final value = _findValue(
    item,
    keys,
    nestedKeys: const ['class', 'teacher', 'student', 'session', 'data'],
  );
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return fallback;
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

const List<_ReportStudent> _reportStudents = [
  _ReportStudent(
    id: 'BSCS-F21-001',
    name: 'Ahmed Khan',
    subtitle: 'BSCS-F21-001',
    status: 'Engaged',
    present: true,
    color: AppTheme.brandGreen,
  ),
  _ReportStudent(
    id: 'BSCS-F21-002',
    name: 'Sara Riaz',
    subtitle: 'BSCS-F21-002',
    status: 'Using Phone',
    present: true,
    color: AppTheme.accentOrange,
  ),
  _ReportStudent(
    id: 'BSCS-F21-003',
    name: 'Usman Malik',
    subtitle: 'BSCS-F21-003',
    status: 'Sleeping',
    present: true,
    color: AppTheme.accentPurple,
  ),
  _ReportStudent(
    id: 'BSCS-F21-004',
    name: 'Fatima Ali',
    subtitle: 'BSCS-F21-004',
    status: 'Absent',
    present: false,
    color: AppTheme.danger,
  ),
];
