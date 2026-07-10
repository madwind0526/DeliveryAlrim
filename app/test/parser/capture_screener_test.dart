import 'package:check_shipping/features/capture/capture_models.dart';
import 'package:check_shipping/features/capture/parser/capture_screener.dart';
import 'package:flutter_test/flutter_test.dart';

RawCapture _sms(String body, {String? sender}) => RawCapture(
  channel: CaptureChannel.sms,
  sender: sender,
  body: body,
  capturedAt: DateTime(2026, 7, 10, 10),
);

void main() {
  const screener = CaptureScreener();

  group('ad filtering (hard markers only)', () {
    test('(광고) tag rejects even with delivery-looking content', () {
      final verdict = screener.screen(
        _sms('(광고) CJ대한통운 사칭 특가! 오늘만 무료배송 www.shop.example'),
      );
      expect(verdict?.reason, ParseRejectReason.adFiltered);
    });

    test('무료수신거부 marker rejects', () {
      final verdict = screener.screen(
        _sms('여름 특가 배송비 0원 이벤트\n무료수신거부 0801234567'),
      );
      expect(verdict?.reason, ParseRejectReason.adFiltered);
    });

    test('수신거부 + 080 number rejects', () {
      final verdict = screener.screen(
        _sms('쿠폰 도착! 지금 확인하세요. 수신거부 080-123-4567'),
      );
      expect(verdict?.reason, ParseRejectReason.adFiltered);
    });

    test('promo words alone do NOT reject', () {
      final verdict = screener.screen(
        _sms('[CJ대한통운] 고객님의 상품이 배송 출발했습니다. 운송장 123456789012'),
      );
      expect(verdict, isNull);
    });
  });

  group('phishing screening', () {
    test('lure phrase + link is quarantined', () {
      final verdict = screener.screen(
        _sms('[CJ대한통운] 주소 불일치로 배송 불가. 주소 확인: http://bit.ly/abc123'),
      );
      expect(verdict?.reason, ParseRejectReason.suspectedPhishing);
    });

    test('customs lure + link is quarantined', () {
      final verdict = screener.screen(
        _sms('해외 물품 통관 보류. 관세 미납 확인 https://ep0st-kr.example/pay'),
      );
      expect(verdict?.reason, ParseRejectReason.suspectedPhishing);
    });

    test('delivery wording + shortener URL is quarantined', () {
      final verdict = screener.screen(
        _sms('택배 배송조회 me2.do/xYz12'),
      );
      expect(verdict?.reason, ParseRejectReason.suspectedPhishing);
    });

    test('delivery wording + raw IP link is quarantined', () {
      final verdict = screener.screen(
        _sms('운송장 조회하기 http://211.34.56.78/track'),
      );
      expect(verdict?.reason, ParseRejectReason.suspectedPhishing);
    });

    test('overseas sender + delivery wording + link is quarantined', () {
      final verdict = screener.screen(
        _sms(
          '[국제발신] 택배가 도착했습니다 확인 https://track-kr.example.com',
        ),
      );
      expect(verdict?.reason, ParseRejectReason.suspectedPhishing);
    });

    test('phishing wins over ad markers', () {
      final verdict = screener.screen(
        _sms('(광고) 택배 주소 오류 확인 http://bit.ly/scam 수신거부 0801112222'),
      );
      expect(verdict?.reason, ParseRejectReason.suspectedPhishing);
    });

    test('legit courier notification with official link passes', () {
      final verdict = screener.screen(
        _sms(
          '[CJ대한통운] 홍*동님의 상품이 배송 출발했습니다.\n'
          '운송장번호: 123456789012\n'
          '배송조회 https://www.cjlogistics.com/ko/tool/parcel/tracking',
        ),
      );
      expect(verdict, isNull);
    });

    test('legit delivered notification without link passes', () {
      final verdict = screener.screen(
        _sms('[롯데택배] 상품이 배달 완료되었습니다. 운송장 4001234567890'),
      );
      expect(verdict, isNull);
    });
  });
}
