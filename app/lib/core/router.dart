import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/debug/debug_insert_screen.dart';
import '../features/debug/replay_screen.dart';
import '../features/parcels/parcel_detail_screen.dart';
import '../features/parcels/parcel_list_screen.dart';
import 'providers.dart';
import 'strings_ko.dart';

/// Bridges a Stream into a Listenable so go_router re-evaluates
/// redirects whenever auth state changes.
class _StreamListenable extends ChangeNotifier {
  late final StreamSubscription<Object?> _sub;

  _StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final listenable = _StreamListenable(authRepo.watchUser());
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final user = ref.read(authStateProvider).value;
      final loggingIn = state.matchedLocation == '/login';
      if (user == null) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const ParcelListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/calendar',
                builder: (_, _) => const CalendarScreen()),
          ]),
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
      GoRoute(
        path: '/debug/replay',
        builder: (_, _) => const ReplayScreen(),
      ),
    ],
  );
});

class _ShellScaffold extends StatelessWidget {
  final StatefulNavigationShell shell;

  const _ShellScaffold({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: StringsKo.navParcels,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: StringsKo.navCalendar,
          ),
        ],
      ),
    );
  }
}
