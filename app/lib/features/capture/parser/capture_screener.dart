import '../capture_models.dart';

/// Why a capture was screened out, plus the matched signal for review UI.
class ScreeningVerdict {
  final ParseRejectReason reason;
  final String signal;

  const ScreeningVerdict({required this.reason, required this.signal});
}

/// Pre-parse gate that drops delivery-looking ads and quarantines
/// phishing-looking messages before any extraction rule runs.
///
/// Design constraints:
/// - Ads: only hard, legally-mandated Korean ad markers reject outright
///   ((광고) tag, 무료수신거부/수신거부 + 080 number). Soft promo words
///   alone never reject — real shipping mails mention coupons too.
/// - Phishing: heuristics must combine at least two signals (link shape +
///   lure phrase, or spoofed-context + link). Suspects are quarantined for
///   user review, never silently deleted — a false positive must stay
///   recoverable.
/// - This app never opens or fetches URLs from message bodies; tracking
///   queries go through the official API with extracted numbers only.
class CaptureScreener {
  const CaptureScreener();

  // --- Ad signals (hard markers) ---

  static final _adTag = RegExp(r'[(\[]\s*광\s*고\s*[)\]]');
  static final _freeRejectOptOut = RegExp(r'무료\s*수신\s*거부');
  static final _optOut = RegExp(r'수신\s*거부');
  static final _optOutNumber = RegExp(r'080[-\s]?\d{3,4}[-\s]?\d{4}');

  // --- Phishing signals ---

  /// Any clickable-looking link.
  static final _anyUrl = RegExp(r'(https?://|www\.)\S+', caseSensitive: false);

  /// Link shapes rarely used by legitimate couriers.
  static final _shortenerUrl = RegExp(
    r'\b(bit\.ly|me2\.do|han\.gl|url\.kr|vo\.la|buly\.kr|c11\.kr|t\.ly|'
    r'tinyurl\.com|is\.gd|goo\.su|zrr\.kr|lrl\.kr)/\S+',
    caseSensitive: false,
  );
  static final _ipUrl = RegExp(r'https?://\d{1,3}(\.\d{1,3}){3}');

  /// Classic Korean delivery-phishing lure phrases.
  static final _phishingLure = RegExp(
    r'주소\s*(불일치|오류|불명|미기재|확인\s*요망)|'
    r'통관|관세|세관|'
    r'본인\s*인증|신분증|'
    r'배송\s*불가|배달\s*불가|'
    r'보관\s*(중인\s*물품|료)|'
    r'결제\s*오류|미납|벌금',
  );

  /// Sender-context spoof: overseas SMS routes claiming domestic delivery.
  static final _overseasSender = RegExp(r'국제\s*발신|해외\s*발신');

  /// Generic delivery vocabulary used to scope link-shape heuristics.
  static final _deliveryWord = RegExp(r'택배|배송|배달|운송장|물류|주문|소포');

  /// Returns null when the capture is clean and may proceed to parsing.
  ScreeningVerdict? screen(RawCapture capture) {
    final text = capture.fullText;

    // Phishing first: a lure message must land in quarantine even when it
    // also carries ad-style opt-out decorations.
    final phishing = _phishingSignal(capture, text);
    if (phishing != null) {
      return ScreeningVerdict(
        reason: ParseRejectReason.suspectedPhishing,
        signal: phishing,
      );
    }

    final ad = _adSignal(text);
    if (ad != null) {
      return ScreeningVerdict(
        reason: ParseRejectReason.adFiltered,
        signal: ad,
      );
    }
    return null;
  }

  String? _adSignal(String text) {
    if (_adTag.hasMatch(text)) return '(광고) 표기';
    if (_freeRejectOptOut.hasMatch(text)) return '무료수신거부 문구';
    if (_optOut.hasMatch(text) && _optOutNumber.hasMatch(text)) {
      return '수신거부 080 번호';
    }
    return null;
  }

  String? _phishingSignal(RawCapture capture, String text) {
    final hasUrl = _anyUrl.hasMatch(text) || _shortenerUrl.hasMatch(text);
    final aboutDelivery = _deliveryWord.hasMatch(text);

    if (hasUrl && _phishingLure.hasMatch(text)) {
      return '유인 문구 + 링크';
    }
    if (aboutDelivery && _shortenerUrl.hasMatch(text)) {
      return '배송 문구 + 단축 URL';
    }
    if (aboutDelivery && _ipUrl.hasMatch(text)) {
      return '배송 문구 + IP 주소 링크';
    }
    final senderText = [capture.sender ?? '', text].join('\n');
    if (aboutDelivery && hasUrl && _overseasSender.hasMatch(senderText)) {
      return '국제발신 + 배송 문구 + 링크';
    }
    return null;
  }
}
