import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/local_db/local_db.dart';
import 'models/parcel.dart';
import 'models/tracking_event.dart';

/// Local parcel storage abstraction for the single-user app.
abstract interface class ParcelRepository {
  Stream<List<Parcel>> watchActive();
  Stream<List<Parcel>> watchDone();
  Stream<List<Parcel>> watchAll();
  Stream<Parcel?> watchById(String id);
  Stream<List<TrackingEvent>> watchEvents(String parcelId);

  /// Insert a newly captured parcel, or merge it into the existing row
  /// with the same (courierCode, trackingNumber) — see [Parcel.merge].
  /// Records a timeline event on first registration and on every
  /// status advance; [eventNote] describes the trigger (e.g. channel).
  Future<void> upsert(Parcel parcel, {String? eventNote});

  Future<void> delete(String id);
}

class LocalParcelRepository implements ParcelRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  LocalParcelRepository(this._db);

  @override
  Stream<List<Parcel>> watchActive() => _watchWhere(done: false);

  @override
  Stream<List<Parcel>> watchDone() => _watchWhere(done: true);

  @override
  Stream<List<Parcel>> watchAll() => _watchWhere(done: null);

  Stream<List<Parcel>> _watchWhere({required bool? done}) {
    final terminalCodes = ParcelStatus.values
        .where((s) => s.isTerminal)
        .map((s) => s.code);
    final query = _db.select(_db.parcelRows)
      ..orderBy([(t) => OrderingTerm.desc(t.registeredAt)]);
    if (done != null) {
      query.where(
        (t) => done
            ? t.status.isIn(terminalCodes)
            : t.status.isNotIn(terminalCodes),
      );
    }
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<Parcel?> watchById(String id) {
    final query = _db.select(_db.parcelRows)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  @override
  Stream<List<TrackingEvent>> watchEvents(String parcelId) {
    final query = _db.select(_db.trackingEventRows)
      ..where((t) => t.parcelId.equals(parcelId))
      ..orderBy([(t) => OrderingTerm.desc(t.eventTime)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          TrackingEvent(
            id: r.id,
            parcelId: r.parcelId,
            eventTime: r.eventTime,
            status: ParcelStatus.fromCode(r.statusCode),
            location: r.location,
            description: r.description,
          ),
      ],
    );
  }

  @override
  Future<void> upsert(Parcel parcel, {String? eventNote}) async {
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.parcelRows)..where(
                (t) =>
                    t.courierCode.equals(parcel.courierCode) &
                    t.trackingNumber.equals(parcel.trackingNumber),
              ))
              .getSingleOrNull();

      final Parcel result;
      final bool statusChanged;
      if (existing == null) {
        result = parcel.id.isEmpty ? _withNewId(parcel) : parcel;
        statusChanged = true;
      } else {
        final before = _toDomain(existing);
        result = before.merge(parcel);
        statusChanged = result.status != before.status;
      }

      await _db.into(_db.parcelRows).insertOnConflictUpdate(_toRow(result));

      if (statusChanged) {
        await _db
            .into(_db.trackingEventRows)
            .insert(
              TrackingEventRowsCompanion.insert(
                parcelId: result.id,
                eventTime: parcel.registeredAt,
                statusCode: result.status.code,
                description: Value(eventNote),
              ),
            );
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.trackingEventRows,
      )..where((t) => t.parcelId.equals(id))).go();
      await (_db.delete(_db.parcelRows)..where((t) => t.id.equals(id))).go();
    });
  }

  Parcel _withNewId(Parcel p) => Parcel(
    id: _uuid.v4(),
    courierCode: p.courierCode,
    trackingNumber: p.trackingNumber,
    status: p.status,
    productName: p.productName,
    mallName: p.mallName,
    sourceChannels: p.sourceChannels,
    expectedArrivalDate: p.expectedArrivalDate,
    deliveredAt: p.deliveredAt,
    registeredAt: p.registeredAt,
  );

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
