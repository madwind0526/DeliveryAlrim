import 'package:check_shipping/features/parcels/models/parcel.dart';
import 'package:check_shipping/features/tracking/sweettracker_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SweettrackerClient.parseResponse', () {
    test('parses a delivered response with details', () {
      const body = '''
      {
        "result": "Y",
        "invoiceNo": "123456789012",
        "itemName": "무선 이어폰",
        "level": 6,
        "complete": true,
        "completeYN": "Y",
        "trackingDetails": [
          {"time": 1783990800000, "timeString": "2026-07-09 10:00:00",
           "where": "서울강남", "kind": "집화처리", "level": 2},
          {"time": 1784077200000, "timeString": "2026-07-10 12:00:00",
           "where": "역삼동", "kind": "배달완료", "level": 6}
        ]
      }
      ''';
      final result = SweettrackerClient.parseResponse(body);

      expect(result.status, ParcelStatus.delivered);
      expect(result.complete, isTrue);
      expect(result.itemName, '무선 이어폰');
      expect(result.details, hasLength(2));
      expect(result.lastDetail!.kind, '배달완료');
      expect(result.lastDetail!.where, '역삼동');
      expect(
        result.lastDetail!.time,
        DateTime.fromMillisecondsSinceEpoch(1784077200000),
      );
    });

    test('maps in-transit levels', () {
      const body = '{"level": 3, "complete": false, "trackingDetails": []}';
      final result = SweettrackerClient.parseResponse(body);
      expect(result.status, ParcelStatus.inTransit);
      expect(result.complete, isFalse);
      expect(result.lastDetail, isNull);
    });

    test('throws with server message on error payload', () {
      const body = '{"code": "104", "msg": "유효하지 않은 운송장 번호입니다."}';
      expect(
        () => SweettrackerClient.parseResponse(body),
        throwsA(
          isA<SweettrackerException>().having(
            (e) => e.message,
            'message',
            contains('유효하지 않은'),
          ),
        ),
      );
    });

    test('throws on non-JSON body', () {
      expect(
        () => SweettrackerClient.parseResponse('<html>error</html>'),
        throwsA(isA<SweettrackerException>()),
      );
    });
  });
}
