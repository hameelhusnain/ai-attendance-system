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
    if (!mounted) return;
    setState(() {
      _sessions = _extractList(sessionsResponse, const ['sessions', 'items', 'data']);
      _students = _extractList(studentsResponse, const ['students', 'items', 'data']);
      _loading = false;
    });
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
                  else
                    for (final session in _sessions.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
