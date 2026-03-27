import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacing.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: AppTheme.mutedFor(context)),
          AppSpacing.gap12,
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          AppSpacing.gap8,
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.mutedFor(context)),
          ),
        ],
      ),
    );
  }
}
