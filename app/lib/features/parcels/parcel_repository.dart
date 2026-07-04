import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/local_db/local_db.dart';
import 'models/parcel.dart';

/// Storage abstraction for parcels.
/// PC mode (Waves 1-3): [LocalParcelRepository] (drift/SQLite).
/// Wave 4+: SupabaseParcelRepository; the local one stays as offline cache.
abstract interface class ParcelRepository {
  Stream<List<Parcel>> watchActive();
  Stream<List<Parcel>> watchDone();

  /// Insert a newly captured parcel, or merge it into the existing row
  /// with the same (courierCode, trackingNumber) — see [Parcel.merge].
  Future<void> upsert(Parcel parcel);

  Future<void> delete(String id);
}

class LocalParcelRepository implements ParcelRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  LocalParcelRepository(this._db);

  @override
  Stream<List<Parcel>> watchActive() => _watch(done: false);

  @override
  Stream<List<Parcel>> watchDone() => _watch(done: true);

  Stream<List<Parcel>> _watch({required bool done}) {
    final terminalCodes =
        ParcelStatus.values.where((s) => s.isTerminal).map((s) => s.code);
    final query = _db.select(_db.parcelRows)
      ..where((t) => done
          ? t.status.isIn(terminalCodes)
          : t.status.isNotIn(terminalCodes))
      ..orderBy([(t) => OrderingTerm.desc(t.registeredAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<void> upsert(Parcel parcel) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.parcelRows)
            ..where((t) =>
                t.courierCode.equals(parcel.courierCode) &
                t.trackingNumber.equals(parcel.trackingNumber)))
          .getSingleOrNull();

      final row = existing == null
          ? _toRow(parcel.id.isEmpty
              ? Parcel(
                  id: _uuid.v4(),
                  courierCode: parcel.courierCode,
                  trackingNumber: parcel.trackingNumber,
                  status: parcel.status,
                  productName: parcel.productName,
                  mallName: parcel.mallName,
                  sourceChannels: parcel.sourceChannels,
                  expectedArrivalDate: parcel.expectedArrivalDate,
                  deliveredAt: parcel.deliveredAt,
                  registeredAt: parcel.registeredAt,
                )
              : parcel)
          : _toRow(_toDomain(existing).merge(parcel));

      await _db.into(_db.parcelRows).insertOnConflictUpdate(row);
    });
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.parcelRows)..where((t) => t.id.equals(id))).go();
  }

  Parcel _toDomain(ParcelRow row) {
    return Parcel(
      id: row.id,
      courierCode: row.courierCode,
      trackingNumber: row.trackingNumber,
      status: ParcelStatus.fromCode(row.status),
      productName: row.productName,
      mallName: row.mallName,
      sourceChannels: row.sourceChannels.isEmpty
          ? const {}
          : row.sourceChannels.split(',').toSet(),
      expectedArrivalDate: row.expectedArrivalDate,
      deliveredAt: row.deliveredAt,
      registeredAt: row.registeredAt,
    );
  }

  ParcelRowsCompanion _toRow(Parcel p) {
    return ParcelRowsCompanion.insert(
      id: p.id,
      courierCode: p.courierCode,
      trackingNumber: p.trackingNumber,
      status: p.status.code,
      productName: Value(p.productName),
      mallName: Value(p.mallName),
      sourceChannels: Value(p.sourceChannels.join(',')),
      expectedArrivalDate: Value(p.expectedArrivalDate),
      deliveredAt: Value(p.deliveredAt),
      registeredAt: p.registeredAt,
    );
  }
}
