import 'package:crypto/crypto.dart' show sha1;
import 'dart:convert' show utf8;

import '../../../core/constants/couriers.dart';
import '../../parcels/models/parcel.dart';
import '../capture_models.dart';
import 'capture_screener.dart';
import 'parse_rule.dart';

/// Rule-based extractor: raw capture text → structured parcel.
/// Pure Dart, platform-independent — fully testable on PC with fixtures.
class RuleEngine {
  final RuleSet ruleSet;

  /// Ad/phishing gate applied to every capture before extraction, so all
  /// callers (notification sync, replay, tests) share one enforcement point.
  final CaptureScreener screener;

  /// Active courier list (built-ins ∪ user-added, per Settings > 로컬).
  /// Defaults to the bundled built-ins when not supplied (e.g. in tests).
  final List<Courier> couriers;

  RuleEngine(
    this.ruleSet, {
    List<Courier>? couriers,
    this.screener = const CaptureScreener(),
  }) : couriers = couriers ?? Couriers.all;

  late final Map<String, Courier> _courierByCode = {
    for (final c in couriers) c.code: c,
  };

  /// Courier detection by keyword co-occurrence. A tracking-looking number
  /// with no courier keyword in the same text is rejected on purpose
  /// (kills phone/order-number false positives). Built-in couriers use
  /// hand-tuned alias regexes; user-added couriers fall back to a literal
  /// name match.
  static final List<(RegExp, String)> _builtinCourierKeywords = [
    (RegExp(r'CJ\s*대한통운|대한통운'), 'cj'),
    (RegExp(r'한진\s*택배|한진'), 'hanjin'),
    (RegExp(r'롯데\s*(글로벌\s*로지스)?\s*택배|롯데택배|롯데'), 'lotte'),
    (RegExp(r'우체국'), 'epost'),
    (RegExp(r'로젠'), 'logen'),
  ];

  late final List<(RegExp, String)> _courierKeywords = [
    ..._builtinCourierKeywords,
    for (final c in couriers)
      if (!_builtinCourierKeywords.any((k) => k.$2 == c.code))
        (RegExp(RegExp.escape(c.nameKo)), c.code),
  ];

  /// Status keywords, checked in order — most terminal first so that
  /// e.g. terminal completion phrases win over weaker in-transit fragments.
  static final List<(RegExp, ParcelStatus)> _statusKeywords = [
    (RegExp(r'배송\s*완료|배달\s*완료|배송했습니다|전달\s*완료'), ParcelStatus.delivered),
    (
      RegExp(r'배송\s*출발|배달\s*예정|배달\s*준비|배송\s*예정|오늘\s*도착'),
      ParcelStatus.outForDelivery,
    ),
    (RegExp(r'배송\s*중|배송이\s*시작|이동\s*중|간선\s*상차'), ParcelStatus.inTransit),
    (RegExp(r'집화|집하|상품\s*인수|픽업'), ParcelStatus.pickedUp),
    (RegExp(r'상품\s*준비|출고|발송'), ParcelStatus.preparing),
    (RegExp(r'주문\s*완료|결제\s*완료|접수'), ParcelStatus.registered),
  ];

  /// Arrival-day hints map to a day offset
  /// from the capture time. Checked before status-based fallbacks.
  static final List<(RegExp, int)> _arrivalHints = [
    (RegExp(r'(오늘|금일)\s*(중\s*)?(도착|배달|배송)'), 0),
    (RegExp(r'내일\s*(중\s*)?(도착|배달|배송)'), 1),
  ];

  static final _productRe = RegExp(r'상품명\s*[:：]\s*([^\n]+)');
  static final _mallRe = RegExp(r'보내는(?:분|곳)\s*[:：]\s*([^\n]+)');
  static final _coupangOrderRe = RegExp(r'주문번호\s*[:：]?\s*(\d{6,20})');

  ParseResult parse(RawCapture capture) {
    final verdict = screener.screen(capture);
    if (verdict != null) {
      return ParseResult.rejected(
        verdict.reason,
        screeningNote: verdict.signal,
      );
    }

    final text = capture.fullText;
    ParseRejectReason? lastReason;

    for (final rule in ruleSet.rules) {
      if (!_appliesTo(rule, capture)) continue;
      final match = rule.bodyRegex.firstMatch(text);
      if (match == null) continue;

      if (rule.courierCode == Couriers.coupangDirect.code) {
        return ParseResult.success(_extractCoupang(capture, text, rule));
      }
      if (rule.courierCode == Couriers.cardOrder.code) {
        return ParseResult.success(_extractCardOrder(capture, text, match, rule));
      }

      final invoiceRaw = _namedOrNull(match, 'invoice');
      if (invoiceRaw == null) continue;
      final invoice = invoiceRaw.replaceAll('-', '');

      final courierCode = rule.courierCode ?? _detectCourier(text);
      if (courierCode == null) {
        lastReason = ParseRejectReason.noCourier;
        continue;
      }
      final courier = _courierByCode[courierCode] ?? Couriers.byCode(courierCode);
      if (courier == null) {
        lastReason = ParseRejectReason.noCourier;
        continue;
      }
      if (!RegExp(courier.invoicePattern).hasMatch(invoice)) {
        lastReason = ParseRejectReason.invalidInvoice;
        continue;
      }

      final status = _resolveStatus(rule, text);
      return ParseResult.success(
        ExtractedParcel(
          courierCode: courierCode,
          trackingNumber: invoice,
          status: status,
          productName: _extractProduct(rule, text),
          mallName: _firstGroup(_mallRe, text),
          expectedArrivalDate: _extractArrival(
            text,
            capture.capturedAt,
            status,
          ),
          matchedRuleId: rule.id,
        ),
      );
    }
    return ParseResult.rejected(lastReason ?? ParseRejectReason.noRuleMatched);
  }

  bool _appliesTo(ParseRule rule, RawCapture c) {
    if (!rule.sourceTypes.contains(c.channel.code)) return false;
    if (rule.packageName != null && rule.packageName != c.packageName) {
      return false;
    }
    if (rule.senderMatch != null &&
        (c.sender == null || !rule.senderMatch!.hasMatch(c.sender!))) {
      return false;
    }
    if (rule.titleMatch != null &&
        (c.title == null || !rule.titleMatch!.hasMatch(c.title!))) {
      return false;
    }
    return true;
  }

  /// Coupang direct delivery has no tracking number. Synthesize a stable
  /// key so multiple notifications for one order merge into one parcel:
  /// prefer the order number; fall back to normalized product + date bucket.
  ExtractedParcel _extractCoupang(
    RawCapture capture,
    String text,
    ParseRule rule,
  ) {
    final orderNo = _firstGroup(_coupangOrderRe, text);
    final product = _extractProduct(rule, text);

    final String seed;
    if (orderNo != null) {
      seed = 'order:$orderNo';
    } else {
      final normalized = (product ?? text.split('\n').first)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final bucket = capture.capturedAt.toIso8601String().substring(0, 10);
      seed = 'product:$normalized|$bucket';
    }
    final key = 'cp:${sha1.convert(utf8.encode(seed))}';

    final status = _resolveStatus(rule, text);
    return ExtractedParcel(
      courierCode: Couriers.coupangDirect.code,
      trackingNumber: key,
      status: status,
      productName: product,
      mallName: '쿠팡',
      expectedArrivalDate: _extractArrival(text, capture.capturedAt, status),
      matchedRuleId: rule.id,
    );
  }

  /// Card-payment approval alerts have no courier/tracking info yet, just
  /// proof an order happened — any issuer whose notification title ends in
  /// "카드" matches (avoids hand-listing every Korean card company). Keyed
  /// by a hash of the full body so an identical reposted notification
  /// dedupes, while distinct purchases (different amount/merchant/time)
  /// get their own row. If the real shipment notification arrives later,
  /// it registers separately under its own courier — this app doesn't
  /// try to link the two.
  ExtractedParcel _extractCardOrder(
    RawCapture capture,
    String text,
    RegExpMatch match,
    ParseRule rule,
  ) {
    final amount = _namedOrNull(match, 'amount');
    final issuer = (capture.title ?? capture.sender)?.trim();
    final seed = '${issuer ?? ''}|${text.replaceAll(RegExp(r'\s+'), ' ').trim()}';
    final key = 'card:${sha1.convert(utf8.encode(seed))}';

    return ExtractedParcel(
      courierCode: Couriers.cardOrder.code,
      trackingNumber: key,
      status: ParcelStatus.registered,
      productName: amount != null ? '$amount원 결제' : null,
      mallName: issuer,
      matchedRuleId: rule.id,
    );
  }

  DateTime? _extractArrival(
    String text,
    DateTime capturedAt,
    ParcelStatus status,
  ) {
    final day = DateTime(capturedAt.year, capturedAt.month, capturedAt.day);
    for (final (re, offset) in _arrivalHints) {
      if (re.hasMatch(text)) return day.add(Duration(days: offset));
    }
    // Out-for-delivery implies arrival today; delivered pins the day.
    if (status == ParcelStatus.outForDelivery ||
        status == ParcelStatus.delivered) {
      return day;
    }
    return null;
  }

  ParcelStatus _resolveStatus(ParseRule rule, String text) {
    if (rule.statusHint != null) return ParcelStatus.fromCode(rule.statusHint!);
    for (final (re, status) in _statusKeywords) {
      if (re.hasMatch(text)) return status;
    }
    return ParcelStatus.registered;
  }

  String? _extractProduct(ParseRule rule, String text) {
    if (rule.productRegex != null) {
      final m = rule.productRegex!.firstMatch(text);
      if (m != null) {
        return (_namedOrNull(m, 'product') ?? m.group(1))?.trim();
      }
    }
    return _firstGroup(_productRe, text);
  }

  String? _detectCourier(String text) {
    for (final (re, code) in _courierKeywords) {
      if (re.hasMatch(text)) return code;
    }
    return null;
  }

  static String? _firstGroup(RegExp re, String text) =>
      re.firstMatch(text)?.group(1)?.trim();

  static String? _namedOrNull(RegExpMatch m, String name) {
    try {
      return m.namedGroup(name);
    } on ArgumentError {
      return null;
    }
  }
}
