import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/alerts_page.dart';
import 'pages/activity_page.dart';
import 'pages/buckets_page.dart';
import 'pages/home_page.dart';
import 'pages/inbox_page.dart';
import 'pages/query_page.dart';
import 'pages/report_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'pages/stopwatch_page.dart';
import 'pages/sync_page.dart';
import 'pages/trends_page.dart';
import 'theme.dart';

/// 导航项定义。path 与 aw-webui/src/route.js 的路由保持一致，
/// 便于对照迁移进度。
class NavItem {
  const NavItem(this.path, this.label, this.icon, {this.section = 0});

  final String path;
  final String label;
  final IconData icon;

  /// 0 = 主功能，1 = 工具，2 = 底部
  final int section;
}

const navItems = <NavItem>[
  NavItem('/home', '概览', Icons.dashboard_outlined),
  NavItem('/activity', '活动', Icons.bar_chart_outlined),
  NavItem('/inbox', 'Inbox', Icons.notes_outlined),
  NavItem('/buckets', '数据桶', Icons.storage_outlined),

  NavItem('/search', '搜索', Icons.search_outlined, section: 1),
  NavItem('/stopwatch', '计时器', Icons.timer_outlined, section: 1),
  NavItem('/alerts', '提醒', Icons.notifications_outlined, section: 1),
  NavItem('/report', '报告', Icons.description_outlined, section: 1),
  NavItem('/trends', '趋势', Icons.trending_up_outlined, section: 1),
  NavItem('/query', '查询', Icons.terminal_outlined, section: 1),

  NavItem('/sync', '局域网同步', Icons.sync_outlined, section: 2),
  NavItem('/settings', '设置', Icons.settings_outlined, section: 2),
];

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, __) => '/home',
        ),
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/activity', builder: (_, __) => const ActivityPage()),
        GoRoute(path: '/inbox', builder: (_, __) => const InboxPage()),
        GoRoute(path: '/buckets', builder: (_, __) => const BucketsPage()),
        GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
        GoRoute(path: '/stopwatch', builder: (_, __) => const StopwatchPage()),
        GoRoute(path: '/alerts', builder: (_, __) => const AlertsPage()),
        GoRoute(path: '/report', builder: (_, __) => const ReportPage()),
        GoRoute(path: '/trends', builder: (_, __) => const TrendsPage()),
        GoRoute(path: '/query', builder: (_, __) => const QueryPage()),
        GoRoute(path: '/sync', builder: (_, __) => const SyncPage()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        GoRoute(
          path: '/:unknown',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('页面不存在')),
            body: Center(child: Text('未找到路径 ${state.uri}')),
          ),
        ),
      ],
    ),
  ],
);

class AwApp extends StatelessWidget {
  const AwApp({super.key, required this.darkMode});

  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ActivityWatch',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 外壳：宽屏用 NavigationRail，窄屏退回 Drawer。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    for (var i = 0; i < navItems.length; i++) {
      if (loc == navItems[i].path || loc.startsWith('${navItems[i].path}/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    void go(int i) => context.go(navItems[i].path);

    final nav = <NavigationRailDestination>[
      for (var i = 0; i < navItems.length; i++)
        if (navItems[i].section == 0)
          NavigationRailDestination(
            icon: Icon(navItems[i].icon),
            label: Text(navItems[i].label),
          ),
    ];

    final body = Row(
      children: [
        if (isWide)
          SafeArea(
            child: NavigationRail(
              selectedIndex: selected < nav.length ? selected : 0,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              // 主功能之外的项收进底部菜单
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MoreMenu(selected: selected),
                  ),
                ),
              ),
              destinations: nav,
            ),
          ),
        const VerticalDivider(width: 1),
        Expanded(child: child),
      ],
    );

    return Scaffold(
      body: body,
      drawer: isWide ? null : _NavDrawer(selected: selected),
    );
  }
}

/// 工具/设置类页面入口，宽屏挂在 NavigationRail 底部，
/// 窄屏时 Drawer 里按分组全量展示。
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context) {
    final items = navItems.where((n) => n.section != 0).toList();
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_horiz),
      tooltip: '更多',
      itemBuilder: (_) => [
        for (final n in items)
          PopupMenuItem<int>(
            value: navItems.indexOf(n),
            child: Row(
              children: [
                Icon(n.icon, size: 18),
                const SizedBox(width: 10),
                Text(n.label),
              ],
            ),
          ),
      ],
      onSelected: (i) => context.go(navItems[i].path),
    );
  }
}

class _NavDrawer extends StatelessWidget {
  const _NavDrawer({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context) {
    Widget section(String title, int sec) {
      final items = navItems
          .where((n) => n.section == sec)
          .toList(growable: false);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          for (final n in items)
            ListTile(
              leading: Icon(n.icon),
              title: Text(n.label),
              selected: navItems.indexOf(n) == selected,
              onTap: () {
                Navigator.pop(context);
                context.go(n.path);
              },
            ),
        ],
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'ActivityWatch',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            section('主功能', 0),
            section('工具', 1),
            section('', 2),
          ],
        ),
      ),
    );
  }
}
