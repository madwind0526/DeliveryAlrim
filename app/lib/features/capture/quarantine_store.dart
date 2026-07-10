import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local_db/local_db.dart';
import '../../core/providers.dart';
import 'capture_models.dart';

final quarantineStoreProvider = Provider<QuarantineStore>(
  (ref) => QuarantineStore(ref.watch(databaseProvider)),
);

final quarantineListProvider = StreamProvider<List<QuarantineRow>>(
  (ref) => ref.watch(quarantineStoreProvider).watchAll(),
);

final quarantineCountProvider = StreamProvider<int>(
  (ref) => ref.watch(quarantineStoreProvider).watchCount(),
);

/// Suspected-phishing holding area. Messages land here instead of the
/// parcel list and stay until the user reviews and deletes them.
class QuarantineStore {
  final AppDatabase _db;

  QuarantineStore(this._db);

  Stream<List<QuarantineRow>> watchAll() {
    final query = _db.select(_db.quarantineRows)
      ..orderBy([(t) => OrderingTerm.desc(t.capturedAt)]);
    return query.watch();
  }

  Stream<int> watchCount() {
    final count = _db.quarantineRows.id.count();
    final query = _db.selectOnly(_db.quarantineRows)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<void> add(RawCapture capture, {required String reason}) async {
    // Dedupe: notification rescans replay the same message; one quarantine
    // entry per (channel, body) is enough.
    final existing =
        await (_db.select(_db.quarantineRows)..where(
              (t) =>
                  t.channel.equals(capture.channel.code) &
                  t.body.equals(capture.body),
            ))
            .get();
    if (existing.isNotEmpty) return;

    await _db
        .into(_db.quarantineRows)
        .insert(
          QuarantineRowsCompanion.insert(
            channel: capture.channel.code,
            sender: Value(capture.sender),
            title: Value(capture.title),
            body: capture.body,
            reason: reason,
            capturedAt: capture.capturedAt,
          ),
        );
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.quarantineRows)..where((t) => t.id.equals(id))).go();
  }
}
