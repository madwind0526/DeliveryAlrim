import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/debug/debug_insert_screen.dart';
import '../features/parcels/parcel_list_screen.dart';
import 'providers.dart';

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
      GoRoute(path: '/', builder: (_, _) => const ParcelListScreen()),
      GoRoute(
        path: '/debug/insert',
        builder: (_, _) => const DebugInsertScreen(),
      ),
    ],
  );
});
