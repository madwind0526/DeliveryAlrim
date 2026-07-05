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

abstract final class CaptureTestSamples {
  static const gmail = CaptureTestSample(
    id: 'gmail_11st_shipping_started',
    labelKo: 'Gmail',
    channel: CaptureChannel.gmail,
    sender: 'order@11st.co.kr',
    title: '[11번가] 배송이 시작되었습니다',
    body: '''
고객님, 주문하신 상품의 배송이 시작되었습니다.

상품명 : 시원한 여름 이불 세트 Q
택배사 : CJ대한통운
송장번호 : 641234567893

감사합니다.''',
  );

  static const sms = CaptureTestSample(
    id: 'sms_hanjin_out_for_delivery',
    labelKo: 'SMS',
    channel: CaptureChannel.sms,
    sender: '15880011',
    body: '''
[Web발신]
[한진택배] 고객님의 상품이 배송 출발하였습니다.
■ 운송장번호: 512345678901
■ 상품명: 캠핑 접이식 의자 2개 세트
■ 배송기사: 김배송 (010-****-1234)
금일 중 도착합니다.''',
  );
}
