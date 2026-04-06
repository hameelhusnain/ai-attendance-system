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

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width > 1100
                        ? 3
                        : width > 720
                            ? 2
                            : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: classes.length,
                      itemBuilder: (context, index) {
                        final item = classes[index];
                        final name = _readValue(item, ['name', 'class_name', 'title'], 'Class');
                        final time = _readValue(item, ['time', 'start_time'], '');
                        final room = _readValue(item, ['room', 'location'], '');
                        return _ClassCard(name: name, time: time, room: room);
                      },
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
  const _ClassCard({required this.name, required this.time, required this.room});

  final String name;
  final String time;
  final String room;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppTheme.brandGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.class_outlined, color: AppTheme.brandGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (time.isNotEmpty || room.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [time, room].where((value) => value.trim().isNotEmpty).join(' • '),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondaryFor(context)),
                  ),
                ],
              ],
            ),
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
