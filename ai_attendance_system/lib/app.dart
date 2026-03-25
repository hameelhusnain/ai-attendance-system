import 'package:flutter/material.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

class AiAttendanceApp extends StatefulWidget {
  const AiAttendanceApp({super.key});

  @override
  State<AiAttendanceApp> createState() => _AiAttendanceAppState();
}

class _AiAttendanceAppState extends State<AiAttendanceApp> {
  final ThemeController _themeController = ThemeController();

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return ThemeScope(
          controller: _themeController,
          child: MaterialApp.router(
            title: 'AI Attendance System',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _themeController.mode,
            routerConfig: AppRouter.router,
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}
