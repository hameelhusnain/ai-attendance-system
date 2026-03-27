import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'app_background.dart';
import 'app_spacing.dart';
import '../utils/responsive.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = ResponsiveLayout.isDesktop(constraints.maxWidth);
        final title = _titleForLocation(location);

        if (isDesktop) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: AppBackground(
              child: Row(
                children: [
                  AppSidebar(location: location, isDrawer: false),
                  Expanded(
                    child: _MainContent(
                      title: title,
                      showMenu: false,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _MobileAppBar(title: title),
          endDrawer: const _AppEndDrawer(),
          body: AppBackground(
            child: SafeArea(
              child: child,
            ),
          ),
          bottomNavigationBar: _BottomNav(location: location),
        );
      },
    );
  }

  String _titleForLocation(String location) {
    if (location.startsWith('/students/')) {
      return 'Student Details';
    }
    if (location.startsWith('/sessions/')) {
      return 'Session Details';
    }
    switch (location) {
      case '/dashboard':
        return 'Dashboard';
      case '/attendance':
        return 'Attendance';
      case '/students':
        return 'Students';
      case '/reports':
        return 'Reports';
      case '/settings':
        return 'Settings';
      case '/sessions':
        return 'Sessions';
      case '/search':
        return 'Search';
      case '/profile':
        return 'Profile';
      case '/about':
        return 'About';
      default:
        return 'Dashboard';
    }
  }
}

class _MainContent extends StatelessWidget {
  const _MainContent({
    required this.title,
    required this.child,
    required this.showMenu,
  });

  final String title;
  final Widget child;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(
          title: title,
          showMenu: showMenu,
        ),
        Expanded(
          child: Container(
            color: Colors.transparent,
            child: child,
          ),
        ),
      ],
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.showMenu,
  });

  final String title;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSearch = constraints.maxWidth > 760;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCardFor(context),
            border: Border(
              bottom: BorderSide(color: AppTheme.borderFor(context)),
            ),
          ),
          child: Row(
            children: [
              if (showMenu)
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 24),
              if (showSearch)
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search students...',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        filled: true,
                        fillColor: AppTheme.surfaceAltFor(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.borderFor(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.borderFor(context)),
                        ),
                      ),
                    ),
                  ),
                ),
              if (showSearch) const SizedBox(width: 16),
              const Spacer(),
              SizedBox(
                height: 32,
                width: 120,
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.auto_awesome,
                    color: AppTheme.textPrimaryFor(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MobileAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.surfaceCardFor(context),
      foregroundColor: AppTheme.textPrimaryFor(context),
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.auto_awesome,
            color: AppTheme.textPrimaryFor(context),
          ),
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.location,
    required this.isDrawer,
  });

  final String location;
  final bool isDrawer;

  final List<_NavItem> items = const [
    _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
    _NavItem(label: 'Sessions', icon: Icons.timer_outlined, route: '/sessions'),
    _NavItem(label: 'Search', icon: Icons.search_outlined, route: '/search'),
    _NavItem(label: 'Profile', icon: Icons.person_outline, route: '/profile'),
    _NavItem(label: 'About', icon: Icons.info_outline, route: '/about'),
  ];

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [
                  Color(0xFF0D0F16),
                  Color(0xFF1B1430),
                  Color(0xFF0F2A22),
                ]
              : const [
                  Color(0xFFF4F6FA),
                  Color(0xFFE7ECF5),
                  Color(0xFFF4F6FA),
                ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.12)
                          : AppTheme.lightSurfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.textPrimaryFor(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI Attendance',
                    style: TextStyle(
                      color: AppTheme.textPrimaryFor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              AppSpacing.gap24,
              for (final item in items)
                _SidebarItem(
                  item: item,
                  isActive: location.startsWith(item.route),
                  onTap: () {
                    if (isDrawer) {
                      Navigator.of(context).pop();
                    }
                    context.go(item.route);
                  },
                ),
              const Spacer(),
              Text(
                'AI Attendance System',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppTheme.textSecondaryFor(context)),
              ),
            ],
          ),
        ),
      ),
    );

    if (isDrawer) {
      return Drawer(child: content);
    }

    return content;
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : AppTheme.textSecondaryFor(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.location});

  final String location;

  int _indexForLocation(String location) {
    if (location.startsWith('/sessions')) return 1;
    if (location.startsWith('/search')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexForLocation(location);
    return BottomNavigationBar(
      currentIndex: index,
      backgroundColor: AppTheme.surfaceCardFor(context),
      selectedItemColor: AppTheme.brandGreen,
      unselectedItemColor: AppTheme.textSecondaryFor(context),
      selectedIconTheme: const IconThemeData(color: AppTheme.brandGreen),
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      onTap: (value) {
        switch (value) {
          case 0:
            context.go('/dashboard');
            break;
          case 1:
            context.go('/sessions');
            break;
          case 2:
            context.go('/search');
            break;
          case 3:
            context.go('/profile');
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.timer_outlined), label: 'Sessions'),
        BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: 'Search'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon, required this.route});

  final String label;
  final IconData icon;
  final String route;
}

class _AppEndDrawer extends StatelessWidget {
  const _AppEndDrawer();

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Dark Theme'),
              trailing: Switch(
                value: themeController.isDark,
                onChanged: (_) => themeController.toggle(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/about');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop();
                await AuthService().logout();
                if (context.mounted) {
                  context.go('/');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
