import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_background.dart';
import 'app_reveal.dart';
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
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = ResponsiveLayout.isDesktop(constraints.maxWidth);
              final leftPanel = AppReveal(
                child: _AuthFormPanel(
                  title: title,
                  subtitle: subtitle,
                  form: form,
                  footer: footer,
                ),
              );
              final rightPanel = const AppReveal(
                delay: Duration(milliseconds: 120),
                child: _AuthMarketingPanel(),
              );

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
                    height: 44,
                    width: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltFor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderFor(context)),
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.auto_awesome,
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EDUATTEND',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                      ),
                      Text(
                        'SMART ATTENDANCE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textSecondaryFor(context),
                              letterSpacing: 1.6,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              AppSpacing.gap24,
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryFor(context),
                    ),
              ),
              AppSpacing.gap8,
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textSecondaryFor(context)),
              ),
              AppSpacing.gap24,
              form,
              AppSpacing.gap16,
              footer,
              AppSpacing.gap16,
              Text(
                '© hh',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.mutedFor(context),
                      letterSpacing: 1.2,
                    ),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isCompact ? 20 : 0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF0F1119),
                  Color(0xFF1A1426),
                  Color(0xFF10211E),
                  Color(0xFF23160C),
                ]
              : const [
                  Color(0xFFF6F7FB),
                  Color(0xFFEFF3F9),
                  Color(0xFFF6F7FB),
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
                    color: AppTheme.textPrimaryFor(context),
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
                  ?.copyWith(
                    color: AppTheme.textSecondaryFor(context),
                    height: 1.5,
                  ),
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
        color: AppTheme.surfaceAltFor(context),
        border: Border.all(color: AppTheme.borderFor(context)),
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
