import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_spacing.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final ScrollController _controller = ScrollController();
  final List<bool> _revealed = List<bool>.filled(_sections.length, false);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final offset = _controller.offset;
    for (var i = 0; i < _sections.length; i++) {
      final trigger = i * 180.0 - 120.0;
      if (!_revealed[i] && offset >= trigger) {
        setState(() => _revealed[i] = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(MediaQuery.of(context).size.width);
    final padding = EdgeInsets.all(isDesktop ? 24 : 16);
    return ListView.builder(
      controller: _controller,
      padding: padding,
      itemCount: _sections.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              AppSpacing.gap16,
            ],
          );
        }

        final sectionIndex = index - 1;
        final data = _sections[sectionIndex];
        final isVisible = _revealed[sectionIndex];

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: isVisible ? 1 : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 500),
            offset: isVisible ? Offset.zero : const Offset(0, 0.05),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    AppSpacing.gap8,
                    Text(
                      data.body,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AboutSection {
  const _AboutSection({required this.title, required this.body});

  final String title;
  final String body;
}

const List<_AboutSection> _sections = [
  _AboutSection(
    title: 'Project Summary',
    body:
        'EDUATTEND is a mobile-first attendance platform designed for smart, fast, and reliable class tracking.',
  ),
  _AboutSection(
    title: 'Core Features',
    body:
        'Login, role-based dashboards, attendance capture, student management, reporting, and modern UI workflows.',
  ),
  _AboutSection(
    title: 'AI Vision',
    body:
        'This frontend is built to integrate with AI-based attendance recognition and analytics in future phases.',
  ),
  _AboutSection(
    title: 'Tech Stack',
    body:
        'Flutter for cross-platform delivery with a modular feature-based architecture and reusable components.',
  ),
];
