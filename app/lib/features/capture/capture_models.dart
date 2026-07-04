import '../parcels/models/parcel.dart';

/// Where a raw capture came from. Codes match parse_rules sourceTypes
/// and the parcels sourceChannels values.
enum CaptureChannel {
  kakao('kakao'),
  sms('sms'),
  mallApp('mall_app'),
  gmail('gmail');

  final String code;
  const CaptureChannel(this.code);

  static CaptureChannel fromCode(String code) =>
      values.firstWhere((c) => c.code == code);

  String get labelKo => switch (this) {
        kakao => '카카오 알림톡',
        sms => 'SMS',
        mallApp => '쇼핑몰 앱',
        gmail => '이메일',
      };
}

/// One raw notification/SMS/email as captured, before parsing.
class RawCapture {
  final CaptureChannel channel;
  final String? packageName;
  final String? sender;
  final String? title;
  final String body;
  final DateTime capturedAt;

  const RawCapture({
    required this.channel,
    this.packageName,
    this.sender,
    this.title,
    required this.body,
    required this.capturedAt,
  });

  /// Text the rule engine matches against.
  String get fullText =>
      [if (title != null && title!.isNotEmpty) title!, body].join('\n');
}

/// Successful extraction from one capture.
class ExtractedParcel {
  final String courierCode;
  final String trackingNumber;
  final ParcelStatus status;
  final String? productName;
  final String? mallName;
  final DateTime? expectedArrivalDate;
  final String matchedRuleId;

  const ExtractedParcel({
    required this.courierCode,
    required this.trackingNumber,
    required this.status,
    this.productName,
    this.mallName,
    this.expectedArrivalDate,
    required this.matchedRuleId,
  });

  /// Convert to a domain parcel ready for repository upsert.
  Parcel toParcel(RawCapture capture) {
    final delivered = status == ParcelStatus.delivered;
    return Parcel(
      id: '',
      courierCode: courierCode,
      trackingNumber: trackingNumber,
      status: status,
      productName: productName,
      mallName: mallName,
      sourceChannels: {capture.channel.code},
      expectedArrivalDate: expectedArrivalDate,
      deliveredAt: delivered ? capture.capturedAt : null,
      registeredAt: capture.capturedAt,
    );
  }
}

enum ParseRejectReason {
  noRuleMatched('noRuleMatched', '일치하는 규칙 없음'),
  noCourier('noCourier', '택배사를 찾지 못함'),
  invalidInvoice('invalidInvoice', '운송장번호 형식 불일치');

  final String code;
  final String labelKo;
  const ParseRejectReason(this.code, this.labelKo);
}

class ParseResult {
  final ExtractedParcel? parcel;
  final ParseRejectReason? reason;

  const ParseResult.success(ExtractedParcel this.parcel) : reason = null;
  const ParseResult.rejected(ParseRejectReason this.reason) : parcel = null;

  bool get matched => parcel != null;
}
