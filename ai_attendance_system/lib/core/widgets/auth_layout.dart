import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_spacing.dart';

class AuthSplitLayout extends StatelessWidget {
  const AuthSplitLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FB),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = ResponsiveLayout.isDesktop(constraints.maxWidth);
              final leftPanel = _AuthFormPanel(
                title: title,
                subtitle: subtitle,
                form: form,
                footer: footer,
              );
              final rightPanel = const _AuthMarketingPanel();

              if (isDesktop) {
                return Row(
                  children: [
                    Expanded(flex: 5, child: leftPanel),
                    Expanded(flex: 5, child: rightPanel),
                  ],
                );
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    leftPanel,
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: _MobilePromoPanel(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E5F5C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AI Attendance',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
              AppSpacing.gap24,
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              AppSpacing.gap8,
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: const Color(0xFF5C677A)),
              ),
              AppSpacing.gap24,
              form,
              AppSpacing.gap16,
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthMarketingPanel extends StatelessWidget {
  const _AuthMarketingPanel({this.isCompact = false});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isCompact ? 20 : 0),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B3A3A),
            Color(0xFF0E5F5C),
            Color(0xFF114B57),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20 : 48,
          vertical: isCompact ? 24 : 56,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Smarter Attendance with AI',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
            ),
            AppSpacing.gap16,
            Text(
              '"Our attendance process is now seamless, reliable, and insight-driven."',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFFE1F2F1), height: 1.5),
            ),
            AppSpacing.gap16,
          ],
        ),
      ),
    );

    if (isCompact) {
      return panel;
    }

    return SizedBox.expand(child: panel);
  }
}

class _MobilePromoPanel extends StatelessWidget {
  const _MobilePromoPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFEEF3F2),
        border: Border.all(color: const Color(0xFFE1E6EE)),
      ),
      child: ExpansionTile(
        title: const Text('Why AI Attendance?'),
        childrenPadding: const EdgeInsets.all(16),
        children: const [
          _AuthMarketingPanel(isCompact: true),
        ],
      ),
    );
  }
}
