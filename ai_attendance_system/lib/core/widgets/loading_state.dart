import 'package:flutter/material.dart';
import 'app_spacing.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label = 'Loading...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          AppSpacing.gap12,
          Text(label),
        ],
      ),
    );
  }
}
