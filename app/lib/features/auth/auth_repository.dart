import 'package:drift/drift.dart';

import '../../core/local_db/local_db.dart';

/// Minimal user identity shared by local and (future) Supabase auth.
class AppUser {
  final String id;
  final String displayName;

  const AppUser({required this.id, required this.displayName});
}

/// Auth abstraction so the app body never knows which backend is active.
/// PC mode (Waves 1-3): [LocalAuthRepository].
/// Wave 4+: SupabaseAuthRepository (email/password, then Google).
abstract interface class AuthRepository {
  Stream<AppUser?> watchUser();
  Future<AppUser> signInLocal(String displayName);
  Future<void> signOut();
}

/// Fake auth backed by a single local profile row.
class LocalAuthRepository implements AuthRepository {
  static const _profileId = 1;
  final AppDatabase _db;

  LocalAuthRepository(this._db);

  @override
  Stream<AppUser?> watchUser() {
    final query = _db.select(_db.localProfileRows)
      ..where((t) => t.id.equals(_profileId));
    return query.watchSingleOrNull().map(
          (row) => row == null
              ? null
              : AppUser(id: 'local-${row.id}', displayName: row.displayName),
        );
  }

  @override
  Future<AppUser> signInLocal(String displayName) async {
    await _db.into(_db.localProfileRows).insertOnConflictUpdate(
          LocalProfileRowsCompanion.insert(
            id: const Value(_profileId),
            displayName: displayName,
            createdAt: DateTime.now(),
          ),
        );
    return AppUser(id: 'local-$_profileId', displayName: displayName);
  }

  @override
  Future<void> signOut() async {
    await (_db.delete(_db.localProfileRows)
          ..where((t) => t.id.equals(_profileId)))
        .go();
  }
}
