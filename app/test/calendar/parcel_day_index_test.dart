import 'package:check_shipping/features/calendar/parcel_day_index.dart';
import 'package:check_shipping/features/parcels/models/parcel.dart';
import 'package:check_shipping/features/parcels/models/tracking_event.dart';
import 'package:flutter_test/flutter_test.dart';

Parcel _parcel({
  String id = 'p1',
  ParcelStatus status = ParcelStatus.inTransit,
  DateTime? registeredAt,
  DateTime? expectedArrivalDate,
  DateTime? deliveredAt,
  String courierCode = 'kr.cjlogistics',
  String trackingNumber = '1234567890',
  String? productName,
  String? mallName,
}) {
  return Parcel(
    id: id,
    courierCode: courierCode,
    trackingNumber: trackingNumber,
    status: status,
    productName: productName,
    mallName: mallName,
    registeredAt: registeredAt ?? DateTime(2026, 7, 7, 9),
    expectedArrivalDate: expectedArrivalDate,
    deliveredAt: deliveredAt,
  );
}

TrackingEvent _event(String parcelId, DateTime time, ParcelStatus status) {
  return TrackingEvent(parcelId: parcelId, eventTime: time, status: status);
}

void main() {
  final day7 = DateTime(2026, 7, 7);
  final day8 = DateTime(2026, 7, 8);
  final day9 = DateTime(2026, 7, 9);
  final day10 = DateTime(2026, 7, 10);

  group('buildParcelDayIndex', () {
    test('active parcel carries forward from registration to today', () {
      final parcel = _parcel(status: ParcelStatus.preparing);
      final index = buildParcelDayIndex(
        parcels: [parcel],
        events: [_event('p1', DateTime(2026, 7, 7, 9), ParcelStatus.preparing)],
        today: DateTime(2026, 7, 10, 22),
      );

      for (final day in [day7, day8, day9, day10]) {
        expect(index[day], hasLength(1), reason: 'missing on $day');
        expect(index[day]!.single.statusOnDay, ParcelStatus.preparing);
      }
      expect(index[DateTime(2026, 7, 11)], isNull);
    });

    test('past days keep the status they had back then', () {
      final parcel = _parcel(
        status: ParcelStatus.delivered,
        deliveredAt: DateTime(2026, 7, 9, 14),
      );
      final index = buildParcelDayIndex(
        parcels: [parcel],
        events: [
          _event('p1', DateTime(2026, 7, 7, 9), ParcelStatus.preparing),
          _event('p1', DateTime(2026, 7, 8, 11), ParcelStatus.inTransit),
          _event('p1', DateTime(2026, 7, 9, 14), ParcelStatus.delivered),
        ],
        today: DateTime(2026, 7, 10, 22),
      );

      expect(index[day7]!.single.statusOnDay, ParcelStatus.preparing);
      expect(index[day8]!.single.statusOnDay, ParcelStatus.inTransit);
      expect(index[day9]!.single.statusOnDay, ParcelStatus.delivered);
      // Finished parcels stop occupying days after their terminal day.
      expect(index[day10], isNull);
    });

    test('multiple events on one day resolve to the latest of that day', () {
      final parcel = _parcel(status: ParcelStatus.inTransit);
      final index = buildParcelDayIndex(
        parcels: [parcel],
        events: [
          _event('p1', DateTime(2026, 7, 7, 9), ParcelStatus.preparing),
          _event('p1', DateTime(2026, 7, 7, 18), ParcelStatus.pickedUp),
        ],
        today: DateTime(2026, 7, 8, 12),
      );

      expect(index[day7]!.single.statusOnDay, ParcelStatus.pickedUp);
      expect(index[day8]!.single.statusOnDay, ParcelStatus.pickedUp);
    });

    test('future expected arrival appears only as a preview entry', () {
      final parcel = _parcel(
        status: ParcelStatus.inTransit,
        expectedArrivalDate: DateTime(2026, 7, 12),
      );
      final index = buildParcelDayIndex(
        parcels: [parcel],
        events: [_event('p1', DateTime(2026, 7, 7, 9), ParcelStatus.inTransit)],
        today: DateTime(2026, 7, 10, 22),
      );

      expect(index[DateTime(2026, 7, 11)], isNull);
      final preview = index[DateTime(2026, 7, 12)]!.single;
      expect(preview.isExpectedPreview, isTrue);
      expect(preview.statusOnDay, ParcelStatus.inTransit);
      // Carried-forward entries are not previews.
      expect(index[day10]!.single.isExpectedPreview, isFalse);
    });

    test('expected arrival within the carried range adds no extra entry', () {
      final parcel = _parcel(
        status: ParcelStatus.inTransit,
        expectedArrivalDate: DateTime(2026, 7, 9),
      );
      final index = buildParcelDayIndex(
        parcels: [parcel],
        events: [_event('p1', DateTime(2026, 7, 7, 9), ParcelStatus.inTransit)],
        today: DateTime(2026, 7, 10, 22),
      );

      expect(index[day9], hasLength(1));
    });

    test('parcel without events falls back to its current status', () {
      final parcel = _parcel(status: ParcelStatus.inTransit);
      final index = buildParcelDayIndex(
        parcels: [parcel],
        events: const [],
        today: DateTime(2026, 7, 8, 12),
      );

      expect(index[day7]!.single.statusOnDay, ParcelStatus.inTransit);
      expect(index[day8]!.single.statusOnDay, ParcelStatus.inTransit);
    });

    test('terminal parcel without deliveredAt ends on its last event day', () {
      final parcel = _parcel(status: ParcelStatus.expired);
      final index = buildParcelDayIndex(
        parcels: [parcel],
        events: [
          _event('p1', DateTime(2026, 7, 7, 9), ParcelStatus.inTransit),
          _event('p1', DateTime(2026, 7, 8, 10), ParcelStatus.expired),
        ],
        today: DateTime(2026, 7, 10, 22),
      );

      expect(index[day7]!.single.statusOnDay, ParcelStatus.inTransit);
      expect(index[day8]!.single.statusOnDay, ParcelStatus.expired);
      expect(index[day9], isNull);
    });

    test(
      'mall order placeholder stops carrying forward once a matching real shipment registers',
      () {
        final order = _parcel(
          id: 'order1',
          courierCode: 'mall_order',
          trackingNumber: 'mall:abc',
          status: ParcelStatus.registered,
          registeredAt: DateTime(2026, 7, 7, 9),
          mallName: '복지포탈',
          productName: '옥향미 특등급 10kg',
        );
        final shipment = _parcel(
          id: 'shipment1',
          courierCode: 'cj',
          trackingNumber: '999888777',
          status: ParcelStatus.pickedUp,
          registeredAt: DateTime(2026, 7, 9, 10),
          mallName: '복지포탈',
          productName: '옥향미 특등급 10kg 세트',
        );
        final index = buildParcelDayIndex(
          parcels: [order, shipment],
          events: const [],
          today: DateTime(2026, 7, 11, 22),
        );

        // Registered before the shipment: still shows the order.
        expect(
          index[day7]!.any((e) => e.parcel.id == 'order1'),
          isTrue,
        );
        expect(
          index[day8]!.any((e) => e.parcel.id == 'order1'),
          isTrue,
        );
        // On/after the shipment's day, the placeholder stops appearing.
        final day9 = DateTime(2026, 7, 9);
        final day11 = DateTime(2026, 7, 11);
        expect(
          index[day9]!.any((e) => e.parcel.id == 'order1'),
          isFalse,
        );
        expect(
          index[day11]?.any((e) => e.parcel.id == 'order1') ?? false,
          isFalse,
        );
      },
    );

    test(
      'unrelated real shipment does not resolve a different order placeholder',
      () {
        final order = _parcel(
          id: 'order1',
          courierCode: 'card_order',
          trackingNumber: 'card:abc',
          status: ParcelStatus.registered,
          registeredAt: DateTime(2026, 7, 7, 9),
          mallName: '삼성카드',
          productName: '9,831원 결제 · TeslaMotors',
        );
        final unrelatedShipment = _parcel(
          id: 'shipment1',
          courierCode: 'hanjin',
          trackingNumber: '111222333',
          status: ParcelStatus.pickedUp,
          registeredAt: DateTime(2026, 7, 9, 10),
          mallName: '지마켓',
          productName: '무선 이어폰',
        );
        final index = buildParcelDayIndex(
          parcels: [order, unrelatedShipment],
          events: const [],
          today: DateTime(2026, 7, 11, 22),
        );

        final day11 = DateTime(2026, 7, 11);
        expect(index[day11]!.any((e) => e.parcel.id == 'order1'), isTrue);
      },
    );

    test(
      'order and shipment registered the same day both show today; only the shipment survives tomorrow',
      () {
        final order = _parcel(
          id: 'order1',
          courierCode: 'card_order',
          trackingNumber: 'card:abc',
          status: ParcelStatus.registered,
          registeredAt: DateTime(2026, 7, 7, 9), // ordered this morning
          mallName: '삼성카드',
          productName: '9,831원 결제 · TeslaMotors',
        );
        final shipment = _parcel(
          id: 'shipment1',
          courierCode: 'cj',
          trackingNumber: '999888777',
          status: ParcelStatus.outForDelivery,
          registeredAt: DateTime(2026, 7, 7, 14), // ships out same afternoon
          mallName: 'TeslaMotors',
          productName: 'TeslaMotors 액세서리',
        );

        // Same-day snapshot: both the order and the shipment are visible.
        final today = buildParcelDayIndex(
          parcels: [order, shipment],
          events: const [],
          today: DateTime(2026, 7, 7, 20),
        );
        expect(today[day7]!.any((e) => e.parcel.id == 'order1'), isTrue);
        expect(today[day7]!.any((e) => e.parcel.id == 'shipment1'), isTrue);

        // A day later: the order placeholder is gone, the shipment carries
        // forward on its own as usual.
        final tomorrow = buildParcelDayIndex(
          parcels: [order, shipment],
          events: const [],
          today: DateTime(2026, 7, 8, 9),
        );
        expect(tomorrow[day8]!.any((e) => e.parcel.id == 'order1'), isFalse);
        expect(tomorrow[day8]!.any((e) => e.parcel.id == 'shipment1'), isTrue);
        // Yesterday's snapshot is untouched either way.
        expect(tomorrow[day7]!.any((e) => e.parcel.id == 'order1'), isTrue);
      },
    );
  });
}
