import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/auth_service.dart';
import 'app_spacing.dart';

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
        final isDesktop = constraints.maxWidth >= 1100;
        final showBottomNav = constraints.maxWidth < 720;
        final title = _titleForLocation(location);

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                AppSidebar(location: location, isDrawer: false),
                Expanded(
                  child: _MainContent(
                    title: title,
                    child: child,
                    showMenu: false,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          drawer: AppSidebar(location: location, isDrawer: true),
          body: _MainContent(
            title: title,
            child: child,
            showMenu: true,
          ),
          bottomNavigationBar: showBottomNav
              ? _BottomNav(location: location)
              : null,
        );
      },
    );
  }

  String _titleForLocation(String location) {
    if (location.startsWith('/students/')) {
      return 'Student Details';
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
            color: const Color(0xFFF5F7FA),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE3E8F0)),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE1E6EE)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE1E6EE)),
                        ),
                      ),
                    ),
                  ),
                ),
              if (showSearch) const SizedBox(width: 16),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0E5F5C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await AuthService().logout();
                    if (context.mounted) {
                      context.go('/');
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'profile', child: Text('Profile')),
                  PopupMenuItem(value: 'logout', child: Text('Logout')),
                ],
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF0E5F5C),
                      child: Icon(Icons.person, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text('Admin'),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AppSidebar extends StatelessWidget {
  AppSidebar({
    super.key,
    required this.location,
    required this.isDrawer,
  });

  final String location;
  final bool isDrawer;

  final List<_NavItem> items = const [
    _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
    _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined, route: '/attendance'),
    _NavItem(label: 'Students', icon: Icons.people_alt_outlined, route: '/students'),
    _NavItem(label: 'Reports', icon: Icons.bar_chart_outlined, route: '/reports'),
    _NavItem(label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B3A3A),
            Color(0xFF0E5F5C),
            Color(0xFF0C3D42),
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
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AI Attendance',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
                    ?.copyWith(color: const Color(0xFFBFE3E1)),
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
    final color = isActive ? Colors.white : const Color(0xFFBFE3E1);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.14) : Colors.transparent,
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
    if (location.startsWith('/attendance')) return 1;
    if (location.startsWith('/students')) return 2;
    if (location.startsWith('/reports')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexForLocation(location);
    return BottomNavigationBar(
      currentIndex: index,
      onTap: (value) {
        switch (value) {
          case 0:
            context.go('/dashboard');
            break;
          case 1:
            context.go('/attendance');
            break;
          case 2:
            context.go('/students');
            break;
          case 3:
            context.go('/reports');
            break;
          case 4:
            context.go('/settings');
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), label: 'Attendance'),
        BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Students'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
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
