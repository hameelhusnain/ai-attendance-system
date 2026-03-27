import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/students/presentation/student_detail_screen.dart';
import '../../features/students/presentation/students_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sessions/presentation/sessions_screen.dart';
import '../../features/sessions/presentation/session_detail_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/about/presentation/about_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'login',
        pageBuilder: (context, state) => _fade(const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) => _fade(const SignupScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.uri.toString(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            pageBuilder: (context, state) => _fade(const DashboardOverviewScreen()),
          ),
          GoRoute(
            path: '/sessions',
            name: 'sessions',
            pageBuilder: (context, state) => _fade(const SessionsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'session-detail',
                pageBuilder: (context, state) {
                  final session = state.extra;
                  if (session is! SessionDetailArgs) {
                    return _fade(const SessionsScreen());
                  }
                  return _fade(SessionDetailScreen(session: session.session));
                },
              ),
            ],
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) => _fade(const SearchScreen()),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) => _fade(const ProfileScreen()),
          ),
          GoRoute(
            path: '/about',
            name: 'about',
            pageBuilder: (context, state) => _fade(const AboutScreen()),
          ),
          GoRoute(
            path: '/attendance',
            name: 'attendance',
            pageBuilder: (context, state) => _fade(const AttendanceScreen()),
          ),
          GoRoute(
            path: '/students',
            name: 'students',
            pageBuilder: (context, state) => _fade(const StudentsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'student-detail',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return _fade(StudentDetailScreen(studentId: id));
                },
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            pageBuilder: (context, state) => _fade(const ReportsScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => _fade(const SettingsScreen()),
          ),
        ],
      ),
    ],
  );

  static CustomTransitionPage<void> _fade(Widget child) {
    return CustomTransitionPage<void>(
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final offset = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
            .animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }
}
