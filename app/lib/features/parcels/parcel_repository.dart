import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/couriers.dart';
import '../../core/local_db/local_db.dart';
import 'models/order_placeholder.dart';
import 'models/parcel.dart';
import 'models/tracking_event.dart';

/// Local parcel storage abstraction for the single-user app.
abstract interface class ParcelRepository {
  Stream<List<Parcel>> watchActive();
  Stream<List<Parcel>> watchDone();
  Stream<List<Parcel>> watchAll();
  Stream<Parcel?> watchById(String id);
  Stream<List<TrackingEvent>> watchEvents(String parcelId);

  /// All tracking events across parcels, oldest first. Used to
  /// reconstruct per-day status snapshots for the calendar.
  Stream<List<TrackingEvent>> watchAllEvents();

  /// Insert a newly captured parcel, or merge it into the existing row
  /// with the same (courierCode, trackingNumber) — see [Parcel.merge].
  /// Records a timeline event on first registration and on every
  /// status advance; [eventNote] describes the trigger (e.g. channel).
  /// Returns true when this was a new row or advanced the status —
  /// callers use this to decide whether the change is worth surfacing
  /// (e.g. the new-capture notification badge).
  Future<bool> upsert(Parcel parcel, {String? eventNote});

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
    return query.watch().map((rows) => rows.map(_toEvent).toList());
  }

  @override
  Stream<List<TrackingEvent>> watchAllEvents() {
    final query = _db.select(_db.trackingEventRows)
      ..orderBy([(t) => OrderingTerm.asc(t.eventTime)]);
    return query.watch().map((rows) => rows.map(_toEvent).toList());
  }

  TrackingEvent _toEvent(TrackingEventRow r) => TrackingEvent(
    id: r.id,
    parcelId: r.parcelId,
    eventTime: r.eventTime,
    status: ParcelStatus.fromCode(r.statusCode),
    location: r.location,
    description: r.description,
  );

  @override
  Future<bool> upsert(Parcel parcel, {String? eventNote}) async {
    return await _db.transaction(() async {
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

      if (!isOrderPlaceholder(result)) {
        await _supersedeMatchingPlaceholders(result);
      }
      return statusChanged;
    });
  }

  /// A real (non-placeholder) shipment was just registered — close out any
  /// card/mall order placeholder that looks like the same purchase and is
  /// still pending, so it stops cluttering the active list forever. There
  /// is no shared ID between an order alert and the courier's own
  /// notification, so this only runs one-way (real shipment resolves an
  /// earlier placeholder); it mirrors the calendar's day-index heuristic
  /// (parcel_day_index.dart) but here it actually changes the parcel's
  /// status instead of just adjusting how long the calendar displays it.
  Future<void> _supersedeMatchingPlaceholders(Parcel realShipment) async {
    final placeholderCodes = [Couriers.cardOrder.code, Couriers.mallOrder.code];
    final rows =
        await (_db.select(_db.parcelRows)..where(
              (t) =>
                  t.courierCode.isIn(placeholderCodes) &
                  t.status.equals(ParcelStatus.registered.code),
            ))
            .get();

    for (final row in rows) {
      final placeholder = _toDomain(row);
      if (placeholder.registeredAt.isAfter(realShipment.registeredAt)) {
        continue;
      }
      if (!looksLikeSamePurchase(placeholder, realShipment)) continue;

      final resolved = placeholder.copyWith(status: ParcelStatus.superseded);
      await _db.into(_db.parcelRows).insertOnConflictUpdate(_toRow(resolved));
      await _db
          .into(_db.trackingEventRows)
          .insert(
            TrackingEventRowsCompanion.insert(
              parcelId: resolved.id,
              eventTime: realShipment.registeredAt,
              statusCode: ParcelStatus.superseded.code,
              description: const Value('실제 배송으로 확인되어 종료됨'),
            ),
          );
    }
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
