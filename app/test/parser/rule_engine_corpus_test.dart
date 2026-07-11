import 'dart:convert';
import 'dart:io';

import 'package:check_shipping/features/capture/capture_models.dart';
import 'package:check_shipping/features/capture/parser/parse_rule.dart';
import 'package:check_shipping/features/capture/parser/rule_engine.dart';
import 'package:check_shipping/features/parcels/models/parcel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Corpus-driven regression tests: every rule change must keep this green.
/// Fixtures live in test/fixtures/captures/*.json; real captured messages
/// are added there as they are collected (Wave 5).
void main() {
  late RuleEngine engine;

  setUpAll(() {
    final rulesJson = File(
      'assets/parse_rules_fallback.json',
    ).readAsStringSync();
    engine = RuleEngine(RuleSet.fromJsonString(rulesJson));
  });

  RawCapture captureFromJson(Map<String, dynamic> item) {
    return RawCapture(
      channel: CaptureChannel.fromCode(item['channel'] as String),
      packageName: item['packageName'] as String?,
      sender: item['sender'] as String?,
      title: item['title'] as String?,
      body: item['body'] as String,
      capturedAt: DateTime.parse(item['capturedAt'] as String),
    );
  }

  final fixtureDir = Directory('test/fixtures/captures');
  final fixtureFiles =
      fixtureDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in fixtureFiles) {
    final items = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    group(file.uri.pathSegments.last, () {
      for (final item in items) {
        final expected = item['expected'] as Map<String, dynamic>;

        test(item['id'] as String, () {
          final result = engine.parse(captureFromJson(item));

          expect(
            result.matched,
            expected['matched'],
            reason: result.matched
                ? 'matched rule ${result.parcel!.matchedRuleId}'
                : 'rejected: ${result.reason!.code}',
          );

          if (expected['matched'] == false) {
            expect(result.reason!.code, expected['reason']);
            return;
          }

          final parcel = result.parcel!;
          expect(parcel.courierCode, expected['courierCode']);
          if (expected.containsKey('trackingNumber')) {
            expect(parcel.trackingNumber, expected['trackingNumber']);
          }
          if (expected.containsKey('trackingNumberPrefix')) {
            expect(
              parcel.trackingNumber,
              startsWith(expected['trackingNumberPrefix'] as String),
            );
          }
          expect(parcel.status.code, expected['status']);
          if (expected.containsKey('productName')) {
            expect(parcel.productName, expected['productName']);
          }
          if (expected.containsKey('mallName')) {
            expect(parcel.mallName, expected['mallName']);
          }
          if (expected.containsKey('arrivalOffsetDays')) {
            final offset = expected['arrivalOffsetDays'] as int?;
            if (offset == null) {
              expect(parcel.expectedArrivalDate, isNull);
            } else {
              final captured = DateTime.parse(item['capturedAt'] as String);
              final day = DateTime(
                captured.year,
                captured.month,
                captured.day,
              ).add(Duration(days: offset));
              expect(parcel.expectedArrivalDate, day);
            }
          }
        });
      }
    });
  }

  test('coupang: same order number from two notifications → same key', () {
    final delivered = engine.parse(
      RawCapture(
        channel: CaptureChannel.mallApp,
        packageName: 'com.coupang.mobile',
        title: '배송 완료',
        body: '[쿠팡] 1박스 문 앞(으)로 배송했습니다.\n주문번호: 3100174954680',
        capturedAt: DateTime(2026, 7, 3, 19, 44),
      ),
    );
    final started = engine.parse(
      RawCapture(
        channel: CaptureChannel.mallApp,
        packageName: 'com.coupang.mobile',
        title: '배송 시작',
        body: '[쿠팡] 주문하신 상품의 배송 시작! 오늘 도착 예정입니다.\n주문번호: 3100174954680',
        capturedAt: DateTime(2026, 7, 3, 9, 12),
      ),
    );

    expect(delivered.matched, isTrue);
    expect(started.matched, isTrue);
    expect(delivered.parcel!.trackingNumber, started.parcel!.trackingNumber);
    expect(delivered.parcel!.status, ParcelStatus.delivered);
    expect(started.parcel!.status, ParcelStatus.outForDelivery);
  });

  test(
    'card order: same purchase via SMS and Kakao (different wording) → same key',
    () {
      final sms = engine.parse(
        RawCapture(
          channel: CaptureChannel.sms,
          sender: '신한카드',
          title: '신한카드',
          body: '신한카드 승인 정*민(1234)\n23,500원 일시불\n07/12 18:20 이마트24',
          capturedAt: DateTime(2026, 7, 12, 18, 20),
        ),
      );
      final kakao = engine.parse(
        RawCapture(
          channel: CaptureChannel.kakao,
          packageName: 'com.kakao.talk',
          body:
              '[신한카드]\n신한1234승인 정*민\n23,500원 일시불\n07/12 18:20\n이마트24\n\n결제 안내 문자입니다.',
          capturedAt: DateTime(2026, 7, 12, 18, 21),
        ),
      );
      final differentPurchase = engine.parse(
        RawCapture(
          channel: CaptureChannel.kakao,
          packageName: 'com.kakao.talk',
          body: '[신한카드]\n신한1234승인 정*민\n5,000원 일시불\n07/12 19:00\n스타벅스',
          capturedAt: DateTime(2026, 7, 12, 19, 0),
        ),
      );

      expect(sms.matched, isTrue);
      expect(kakao.matched, isTrue);
      expect(differentPurchase.matched, isTrue);
      expect(sms.parcel!.trackingNumber, kakao.parcel!.trackingNumber);
      expect(
        sms.parcel!.trackingNumber,
        isNot(differentPurchase.parcel!.trackingNumber),
      );
    },
  );

  test(
    'a real courier invoice always wins over the card-order title match',
    () {
      // Title ends in "카드" (matches card_order_generic) *and* the body
      // has a real, courier-tagged invoice number — labeled_invoice_generic
      // must win so the shipment stays trackable instead of collapsing
      // into a bare card-payment placeholder.
      final result = engine.parse(
        RawCapture(
          channel: CaptureChannel.sms,
          sender: '신한카드',
          title: '신한카드',
          body:
              '[한진택배] 고객님의 상품이 배송 출발하였습니다.\n'
              '운송장번호: 512345678901\n'
              '결제금액: 23,500원',
          capturedAt: DateTime(2026, 7, 12, 18, 20),
        ),
      );

      expect(result.matched, isTrue);
      expect(result.parcel!.courierCode, 'hanjin');
      expect(result.parcel!.trackingNumber, '512345678901');
    },
  );

  test(
    'card order: same issuer/amount/time-of-day in a different year is a '
    'different purchase, not a dedupe collision',
    () {
      final thisYear = engine.parse(
        RawCapture(
          channel: CaptureChannel.sms,
          sender: '신한카드',
          title: '신한카드',
          body: '신한카드 승인 정*민(1234)\n23,500원 일시불\n07/12 18:20 이마트24',
          capturedAt: DateTime(2026, 7, 12, 18, 20),
        ),
      );
      final nextYear = engine.parse(
        RawCapture(
          channel: CaptureChannel.sms,
          sender: '신한카드',
          title: '신한카드',
          body: '신한카드 승인 정*민(1234)\n23,500원 일시불\n07/12 18:20 이마트24',
          capturedAt: DateTime(2027, 7, 12, 18, 20),
        ),
      );

      expect(thisYear.matched, isTrue);
      expect(nextYear.matched, isTrue);
      expect(
        thisYear.parcel!.trackingNumber,
        isNot(nextYear.parcel!.trackingNumber),
      );
    },
  );
}
