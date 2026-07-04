import 'package:check_shipping/core/local_db/local_db.dart';
import 'package:check_shipping/features/parcels/models/parcel.dart';
import 'package:check_shipping/features/parcels/parcel_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Parcel _parcel({
  String tracking = '123456789012',
  ParcelStatus status = ParcelStatus.registered,
  String? product,
  Set<String> channels = const {SourceChannel.manual},
  DateTime? registeredAt,
}) {
  return Parcel(
    id: '',
    courierCode: 'cj',
    trackingNumber: tracking,
    status: status,
    productName: product,
    sourceChannels: channels,
    registeredAt: registeredAt ?? DateTime(2026, 7, 4),
  );
}

void main() {
  late AppDatabase db;
  late LocalParcelRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalParcelRepository(db);
  });

  tearDown(() async => db.close());

  test('upsert inserts a new parcel and assigns an id', () async {
    await repo.upsert(_parcel(product: '무선 이어폰'));

    final active = await repo.watchActive().first;
    expect(active, hasLength(1));
    expect(active.single.id, isNotEmpty);
    expect(active.single.productName, '무선 이어폰');
  });

  test(
    'same (courier, tracking) from two channels merges into one row',
    () async {
      await repo.upsert(_parcel(channels: {SourceChannel.kakao}));
      await repo.upsert(
        _parcel(
          channels: {SourceChannel.sms},
          product: '텀블러',
          status: ParcelStatus.inTransit,
        ),
      );

      final active = await repo.watchActive().first;
      expect(active, hasLength(1));
      final merged = active.single;
      expect(merged.sourceChannels, {SourceChannel.kakao, SourceChannel.sms});
      expect(merged.productName, '텀블러');
      expect(merged.status, ParcelStatus.inTransit);
    },
  );

  test('status never moves backward on merge', () async {
    await repo.upsert(_parcel(status: ParcelStatus.outForDelivery));
    await repo.upsert(_parcel(status: ParcelStatus.inTransit));

    final active = await repo.watchActive().first;
    expect(active.single.status, ParcelStatus.outForDelivery);
  });

  test('timeline events recorded on registration and status advance', () async {
    await repo.upsert(
      _parcel(
        status: ParcelStatus.registered,
        registeredAt: DateTime(2026, 7, 4, 9),
      ),
      eventNote: 'first capture',
    );
    // Same status again: merged, but no new timeline event.
    await repo.upsert(
      _parcel(
        status: ParcelStatus.registered,
        registeredAt: DateTime(2026, 7, 4, 10),
      ),
    );
    await repo.upsert(
      _parcel(
        status: ParcelStatus.inTransit,
        registeredAt: DateTime(2026, 7, 4, 11),
      ),
      eventNote: 'second capture',
    );

    final parcel = (await repo.watchActive().first).single;
    final events = await repo.watchEvents(parcel.id).first;

    expect(events, hasLength(2));
    expect(events.first.status, ParcelStatus.inTransit);
    expect(events.first.description, 'second capture');
    expect(events.last.status, ParcelStatus.registered);
  });

  test('terminal statuses appear in done list, not active', () async {
    await repo.upsert(_parcel(tracking: '111111111111'));
    await repo.upsert(
      _parcel(tracking: '222222222222', status: ParcelStatus.delivered),
    );

    final active = await repo.watchActive().first;
    final done = await repo.watchDone().first;
    expect(active.single.trackingNumber, '111111111111');
    expect(done.single.trackingNumber, '222222222222');
  });
}
