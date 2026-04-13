import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_reveal.dart';
import '../../../core/widgets/app_spacing.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/session_store.dart';

class DashboardOverviewScreen extends StatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  State<DashboardOverviewScreen> createState() => _DashboardOverviewScreenState();
}

class _DashboardOverviewScreenState extends State<DashboardOverviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nameController;
  late final Animation<Color?> _nameColor;
  late Future<List<dynamic>> _classesFuture;

  @override
  void initState() {
    super.initState();
    _nameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _nameColor = ColorTween(
      begin: AppTheme.brandGreen,
      end: AppTheme.accentOrange,
    ).animate(CurvedAnimation(parent: _nameController, curve: Curves.easeInOut));
    _classesFuture = _loadClasses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _loadClasses() async {
    try {
      final data = await ApiService().getClasses();
      if (data is List) {
        return data;
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  String _displayName() {
    final name = SessionStore.displayName;
    if (name == null || name.trim().isEmpty) return 'there';
    return name.trim();
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
          AppReveal(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryFor(context),
                    ),
                children: [
                  const TextSpan(text: 'Welcome '),
                  WidgetSpan(
                    child: AnimatedBuilder(
                      animation: _nameColor,
                      builder: (context, _) => Text(
                        _displayName(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _nameColor.value,
                            ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ','),
                ],
              ),
            ),
          ),
          AppSpacing.gap8,
          AppReveal(
            delay: const Duration(milliseconds: 80),
            child: Text(
              'Here are your classes for today.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondaryFor(context)),
            ),
          ),
          AppSpacing.gap16,
          AppReveal(
            delay: const Duration(milliseconds: 140),
            child: FutureBuilder<List<dynamic>>(
              future: _classesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                final classes = snapshot.data ?? [];
                if (classes.isEmpty) {
                  return AppCard(
                    child: Text(
                      'No classes available right now.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => AppSpacing.gap12,
                  itemBuilder: (context, index) {
                    final item = classes[index];
                    final name = _readValue(item, ['name', 'class_name', 'title'], 'Class');
                    final tutor = _readValue(item, [
                      'tutor',
                      'teacher',
                      'teacher_name',
                      'instructor',
                      'assigned_teacher',
                    ], 'Tutor');
                    final time = _readValue(item, ['time', 'start_time'], '');
                    final room = _readValue(item, ['room', 'location'], '');
                    return _ClassCard(
                      name: name,
                      tutor: tutor,
                      time: time,
                      room: room,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.name,
    required this.tutor,
    required this.time,
    required this.room,
  });

  final String name;
  final String tutor;
  final String time;
  final String room;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppTheme.brandGreen.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.class_outlined, color: AppTheme.brandGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tutor: $tutor',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                ),
              ],
            ),
          ),
          if (time.isNotEmpty || room.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                if (room.isNotEmpty)
                  Text(
                    room,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

String _readValue(dynamic item, List<String> keys, String fallback) {
  if (item is Map<String, dynamic>) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
  }
  return fallback;
}
