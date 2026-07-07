import 'dart:math';

import '../capture/capture_models.dart';

class CaptureTestSample {
  final String id;
  final String labelKo;
  final CaptureChannel channel;
  final String? packageName;
  final String? sender;
  final String? title;
  final String body;

  const CaptureTestSample({
    required this.id,
    required this.labelKo,
    required this.channel,
    this.packageName,
    this.sender,
    this.title,
    required this.body,
  });

  RawCapture toCapture(DateTime capturedAt) {
    return RawCapture(
      channel: channel,
      packageName: packageName,
      sender: sender,
      title: title,
      body: body,
      capturedAt: capturedAt,
    );
  }
}

/// Generates a fresh, randomized Gmail/SMS sample on every access so
/// repeated test sends exercise RuleEngine against varied courier/status/
/// product combinations instead of always merging into the same parcel.
abstract final class CaptureTestSamples {
  static final _random = Random();

  // (display name, min tracking digits, max tracking digits)
  static const _couriers = [
    ('CJ대한통운', 10, 12),
    ('한진택배', 10, 14),
    ('롯데택배', 10, 13),
    ('우체국택배', 13, 13),
    ('로젠택배', 11, 11),
  ];

  static const _statusPhrases = [
    '주문이 접수되었습니다',
    '상품 준비 중입니다',
    '택배 상품을 집화하였습니다',
    '상품이 배송 중입니다',
    '상품이 배송 출발하였습니다. 금일 중 도착 예정입니다',
    '상품이 배송 완료되었습니다',
  ];

  static const _products = [
    '여름 이불 세트 Q',
    '캠핑 접이식 의자 2개 세트',
    '무선 이어폰',
    '런닝화 270',
    '커피 원두 1kg',
    '전기 주전자',
    '블루투스 스피커',
    '겨울 패딩 점퍼',
    '핸드크림 3종 세트',
    '노트북 파우치',
  ];

  static const _malls = ['11번가', '지마켓', '네이버쇼핑', '카카오톡선물하기', '옥션'];

  static const _invoiceLabels = ['운송장번호', '송장번호', '등기번호'];

  static T _pick<T>(List<T> options) => options[_random.nextInt(options.length)];

  static String _trackingNumber(int minLen, int maxLen) {
    final length = minLen + _random.nextInt(maxLen - minLen + 1);
    return List.generate(length, (_) => _random.nextInt(10)).join();
  }

  static CaptureTestSample get gmail {
    final (courierName, minLen, maxLen) = _pick(_couriers);
    final status = _pick(_statusPhrases);
    final product = _pick(_products);
    final mall = _pick(_malls);
    final invoiceLabel = _pick(_invoiceLabels);
    final tracking = _trackingNumber(minLen, maxLen);
    return CaptureTestSample(
      id: 'gmail_test_sample',
      labelKo: 'Gmail',
      channel: CaptureChannel.gmail,
      sender: 'order@example.com',
      title: '[$mall] $status',
      body:
          '''
고객님, 주문하신 상품의 배송 안내입니다.

상품명 : $product
택배사 : $courierName
$invoiceLabel : $tracking
현재 상태 : $status

감사합니다.''',
    );
  }

  static CaptureTestSample get sms {
    final (courierName, minLen, maxLen) = _pick(_couriers);
    final status = _pick(_statusPhrases);
    final product = _pick(_products);
    final invoiceLabel = _pick(_invoiceLabels);
    final tracking = _trackingNumber(minLen, maxLen);
    return CaptureTestSample(
      id: 'sms_test_sample',
      labelKo: 'SMS',
      channel: CaptureChannel.sms,
      sender: '15880011',
      body:
          '''
[Web발신]
[$courierName] 고객님의 $status
■ $invoiceLabel: $tracking
■ 상품명: $product''',
    );
  }
}
