import '../../../core/constants/couriers.dart';
import 'parcel.dart';

/// True for a synthetic card-payment or mall order-confirmation "parcel"
/// that has no real shipment info yet — see [Couriers.cardOrder] and
/// [Couriers.mallOrder].
bool isOrderPlaceholder(Parcel p) =>
    p.courierCode == Couriers.cardOrder.code ||
    p.courierCode == Couriers.mallOrder.code;

// Whitespace and common punctuation only — deliberately NOT `\W`, which
// under Dart's default (non-Unicode) regex semantics treats every Hangul
// character as "non-word" and would strip Korean merchant/mall names
// down to nothing, leaving only stray Latin/digit fragments to compare.
final _matchPunctuationRe = RegExp(r'''[\s,.\-·:：;!?()\[\]{}"'“”‘’/\\_]+''');

/// Loose text match: lowercased, whitespace/punctuation stripped. Real
/// shipment text never matches an order-confirmation's wording exactly,
/// so this stays forgiving on purpose — it only needs to avoid matching
/// unrelated orders, not be precise about *how* similar two strings are.
String normalizeForOrderMatch(String s) =>
    s.toLowerCase().replaceAll(_matchPunctuationRe, '');

/// Containment either direction, on already-normalized text.
bool orderMatchTextOverlaps(String? a, String? b) {
  if (a == null || b == null) return false;
  if (a.length < 2 || b.length < 2) return false;
  return a.contains(b) || b.contains(a);
}

/// Best-effort check: does [candidate] look like the real shipment for
/// [placeholder]'s purchase? There's no shared ID between a card/mall
/// order alert and the courier's own notification, so this compares
/// mall/product text loosely instead — checking both same-field and
/// cross-field pairs, since a merchant name can land in the mall field
/// on one side (e.g. the courier's "보내는 곳") and the product field on
/// the other (e.g. "9,831원 결제 · TeslaMotors").
bool looksLikeSamePurchase(Parcel placeholder, Parcel candidate) {
  final placeholderMall = placeholder.mallName == null
      ? null
      : normalizeForOrderMatch(placeholder.mallName!);
  final placeholderProduct = placeholder.productName == null
      ? null
      : normalizeForOrderMatch(placeholder.productName!);
  final candidateMall = candidate.mallName == null
      ? null
      : normalizeForOrderMatch(candidate.mallName!);
  final candidateProduct = candidate.productName == null
      ? null
      : normalizeForOrderMatch(candidate.productName!);
  return orderMatchTextOverlaps(placeholderMall, candidateMall) ||
      orderMatchTextOverlaps(placeholderProduct, candidateProduct) ||
      orderMatchTextOverlaps(placeholderMall, candidateProduct) ||
      orderMatchTextOverlaps(placeholderProduct, candidateMall);
}
