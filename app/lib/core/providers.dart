import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_repository.dart';
import '../features/parcels/models/parcel.dart';
import '../features/parcels/parcel_repository.dart';
import 'local_db/local_db.dart';

/// Overridden in tests with AppDatabase.forTesting.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => LocalAuthRepository(ref.watch(databaseProvider)),
);

final parcelRepositoryProvider = Provider<ParcelRepository>(
  (ref) => LocalParcelRepository(ref.watch(databaseProvider)),
);

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
);

final activeParcelsProvider = StreamProvider<List<Parcel>>(
  (ref) => ref.watch(parcelRepositoryProvider).watchActive(),
);

final doneParcelsProvider = StreamProvider<List<Parcel>>(
  (ref) => ref.watch(parcelRepositoryProvider).watchDone(),
);
