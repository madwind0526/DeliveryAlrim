/// Fixed set of supported Korean couriers.
/// Bundled locally so parser and fixtures work without a server.
class Courier {
  final String code;
  final String nameKo;

  /// Sweet Tracker carrier code. Null means the courier cannot be polled
  /// (e.g. Coupang direct delivery: status comes from notifications only).
  final String? sweettrackerCode;

  /// Regex the tracking number must fully match.
  final String invoicePattern;

  final bool isDirect;

  const Courier({
    required this.code,
    required this.nameKo,
    required this.sweettrackerCode,
    required this.invoicePattern,
    this.isDirect = false,
  });
}

abstract final class Couriers {
  static const cj = Courier(
    code: 'cj',
    nameKo: 'CJ대한통운',
    sweettrackerCode: '04',
    invoicePattern: r'^\d{10,12}$',
  );
  static const hanjin = Courier(
    code: 'hanjin',
    nameKo: '한진택배',
    sweettrackerCode: '05',
    invoicePattern: r'^\d{10,14}$',
  );
  static const lotte = Courier(
    code: 'lotte',
    nameKo: '롯데택배',
    sweettrackerCode: '08',
    invoicePattern: r'^\d{10,13}$',
  );
  static const epost = Courier(
    code: 'epost',
    nameKo: '우체국택배',
    sweettrackerCode: '01',
    invoicePattern: r'^\d{13}$',
  );
  static const logen = Courier(
    code: 'logen',
    nameKo: '로젠택배',
    sweettrackerCode: '06',
    invoicePattern: r'^\d{11}$',
  );
  static const coupangDirect = Courier(
    code: 'coupang_direct',
    nameKo: '쿠팡 배송',
    sweettrackerCode: null,
    invoicePattern: r'^cp:[0-9a-f]{40}$',
    isDirect: true,
  );

  /// Virtual "courier" for card-payment approval alerts (any issuer whose
  /// notification title ends in "카드" — see RuleEngine's card_order rule).
  /// These have no shipment yet, just a registered order; a real courier
  /// sighting later creates its own separate row rather than merging in.
  static const cardOrder = Courier(
    code: 'card_order',
    nameKo: '카드결제',
    sweettrackerCode: null,
    invoicePattern: r'^card:[0-9a-f]{40}$',
    isDirect: true,
  );

  /// Virtual "courier" for mall order-confirmation alimtalk/SMS/email that
  /// has no courier/tracking number yet (e.g. "[OO몰] 주문 완료 안내" with
  /// an order number and payment amount but nothing shipping-related) —
  /// same idea as [cardOrder], just triggered by the order-confirmation
  /// template instead of a card-payment approval.
  static const mallOrder = Courier(
    code: 'mall_order',
    nameKo: '쇼핑몰주문',
    sweettrackerCode: null,
    invoicePattern: r'^mall:[0-9a-f]{40}$',
    isDirect: true,
  );

  static const all = <Courier>[
    cj,
    hanjin,
    lotte,
    epost,
    logen,
    coupangDirect,
    cardOrder,
    mallOrder,
  ];

  static Courier? byCode(String code) {
    for (final c in all) {
      if (c.code == code) return c;
    }
    return null;
  }
}
