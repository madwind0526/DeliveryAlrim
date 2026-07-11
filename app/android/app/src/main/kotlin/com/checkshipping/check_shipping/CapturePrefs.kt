package com.checkshipping.check_shipping

/// Shared constants for the capture pipeline, used by every native class
/// that reads/writes the pending-capture queue or the native pre-filters —
/// one definition instead of copies that can drift out of sync.
object CapturePrefs {
    const val NAME = "kakao_accessibility"
    const val KEY_PENDING_CAPTURES = "pending_captures"

    /// Mirrors RuleEngine's card_order_bracket_tag rule
    /// (assets/parse_rules_fallback.json) so this native pre-filter accepts
    /// exactly what that rule would later match — kept unbounded like the
    /// JSON rule rather than an arbitrary length cap, so the two can't
    /// silently drift apart on how much boilerplate is allowed between the
    /// issuer tag and the amount.
    val CARD_ORDER_RE = Regex("""\[[^\]]*카드\][\s\S]*?\d{1,3}(?:,\d{3})*\s*원""")

    /// Mirrors RuleEngine's mall_order_complete_generic rule.
    val MALL_ORDER_RE = Regex("""\[[^\]]+\][\s\S]{0,30}?주문\s*완료""")
}
