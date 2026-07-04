import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/debug/debug_insert_screen.dart';
import '../features/debug/replay_screen.dart';
import '../features/preferences/filter_screen.dart';
import '../features/preferences/settings_screen.dart';
import '../features/preferences/user_sources_screen.dart';
import '../features/parcels/parcel_detail_screen.dart';
import '../features/parcels/parcel_list_screen.dart';
import 'strings_ko.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const ParcelListScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/daily',
                builder: (_, _) => const CalendarScreen.daily(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/monthly',
                builder: (_, _) => const CalendarScreen.monthly(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/filter', builder: (_, _) => const FilterScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/user',
                builder: (_, _) => const UserSourcesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/parcel/:id',
        builder: (_, state) =>
            ParcelDetailScreen(parcelId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/debug/insert',
        builder: (_, _) => const DebugInsertScreen(),
      ),
      GoRoute(path: '/debug/replay', builder: (_, _) => const ReplayScreen()),
    ],
  );
});

class _ShellScaffold extends StatelessWidget {
  final StatefulNavigationShell shell;

  const _ShellScaffold({required this.shell});

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      _NavItem(
        Icons.storefront_outlined,
        Icons.storefront,
        StringsKo.navCompany,
      ),
      _NavItem(Icons.today_outlined, Icons.today, StringsKo.navDaily),
      _NavItem(
        Icons.calendar_month_outlined,
        Icons.calendar_month,
        StringsKo.navMonthly,
      ),
      _NavItem(
        Icons.filter_alt_outlined,
        Icons.filter_alt,
        StringsKo.navFilter,
      ),
      _NavItem(Icons.settings_outlined, Icons.settings, StringsKo.navSetting),
      _NavItem(Icons.person_outline, Icons.person, StringsKo.navUser),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      body: wide
          ? Row(
              children: [
                _SideMenu(shell: shell, destinations: destinations),
                const VerticalDivider(width: 1),
                Expanded(child: shell),
              ],
            )
          : shell,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem(this.icon, this.selectedIcon, this.label);
}

class _SideMenu extends StatelessWidget {
  final StatefulNavigationShell shell;
  final List<_NavItem> destinations;

  const _SideMenu({required this.shell, required this.destinations});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            const SizedBox(height: 12),
            for (var i = 0; i < 3; i++)
              _SideMenuButton(
                item: destinations[i],
                selected: shell.currentIndex == i,
                onPressed: () =>
                    shell.goBranch(i, initialLocation: i == shell.currentIndex),
              ),
            const Spacer(),
            for (var i = 3; i < destinations.length; i++)
              _SideMenuButton(
                item: destinations[i],
                selected: shell.currentIndex == i,
                onPressed: () =>
                    shell.goBranch(i, initialLocation: i == shell.currentIndex),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SideMenuButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onPressed;

  const _SideMenuButton({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          width: 80,
          height: 64,
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                color: selected ? colors.onPrimaryContainer : null,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? colors.onPrimaryContainer : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
