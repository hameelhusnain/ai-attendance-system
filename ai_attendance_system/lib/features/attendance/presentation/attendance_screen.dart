import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final response = await ApiService().getSessions();
      final sessions = _extractSessions(response);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessions = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(
                      width: 180,
                      child: AppButton(
                        label: 'Refresh',
                        onPressed: _loadSessions,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gap12,
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: const [
                    _FilterChip(label: 'Recent Sessions'),
                    _FilterChip(label: 'Backend Data'),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gap16,
          Expanded(
            child: AppCard(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : ListView.separated(
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final title = _readValue(session, const ['title', 'name', 'label'],
                            fallback: 'Session');
                        final className = _readValue(session, const ['class_name', 'name', 'title'],
                            nestedKeys: const ['class']);
                        final date = _readValue(session, const ['date', 'session_date', 'created_at']);
                        final present =
                            _readValue(session, const ['present', 'present_count', 'marked']);
                        final total = _readValue(session, const ['total', 'total_students']);
                        final absent = _readValue(session, const ['absent', 'absent_count']);
                        final presentValue = int.tryParse(present) ?? 0;
                        final totalValue = int.tryParse(total) ?? 0;
                        final inferredAbsent = absent.isNotEmpty
                            ? absent
                            : totalValue > 0
                                ? (totalValue - presentValue).toString()
                                : '';
                        final status = _readValue(
                          session,
                          const ['status', 'session_status'],
                          fallback: 'Recorded',
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.brandGreen.withOpacity(0.12),
                            child: Text(title.substring(0, 1).toUpperCase()),
                          ),
                          title: Text(title),
                          subtitle: Text(
                            [className, date].where((value) => value.isNotEmpty).join(' • '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _StatusBadge(status: status),
                              if (present.isNotEmpty || inferredAbsent.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                if (present.isNotEmpty)
                                  Text('Present: $present'),
                                if (inferredAbsent.isNotEmpty)
                                  Text('Absent: $inferredAbsent'),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppTheme.brandGreen.withOpacity(0.16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status.toLowerCase().contains('closed')
        ? AppTheme.accentOrange
        : AppTheme.brandGreen;
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

List<Map<String, dynamic>> _extractSessions(dynamic response) {
  if (response is List) {
    return response.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  if (response is Map) {
    for (final key in const ['sessions', 'items', 'data']) {
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
