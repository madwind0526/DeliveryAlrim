package com.checkshipping.check_shipping

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject

class KakaoAccessibilityService : AccessibilityService() {
    private val seenTexts = LinkedHashSet<String>()

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.packageName != KAKAO_PACKAGE) return
        val root = rootInActiveWindow ?: return
        val messages = mutableListOf<String>()
        try {
            collectAlimtalkMessages(root, messages)
        } finally {
            root.recycle()
        }
        for (message in messages) {
            if (seenTexts.add(message)) {
                handleMessage(message)
            }
        }
        while (seenTexts.size > MAX_SEEN) {
            val first = seenTexts.firstOrNull() ?: break
            seenTexts.remove(first)
        }
    }

    override fun onInterrupt() = Unit

    private fun collectAlimtalkMessages(
        node: AccessibilityNodeInfo,
        out: MutableList<String>,
    ) {
        val viewId = node.viewIdResourceName
        val text = node.text?.toString()?.trim()
        if (viewId == ALIMTALK_TITLE_ID && !text.isNullOrBlank()) {
            out.add(text)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectAlimtalkMessages(child, out)
            child.recycle()
        }
    }

    private fun handleMessage(message: String) {
        val invoice = INVOICE_RE.find(message)?.groupValues?.getOrNull(1)
        // Card-payment alimtalk (e.g. "[삼성카드] ... 9,831원 ...") and mall
        // order-confirmation alimtalk (e.g. "[OO몰] 주문 완료 안내 ...") have
        // no invoice number at all — accept them too so RuleEngine's
        // card_order_bracket_tag / mall_order_complete_generic rules get a
        // chance to see them.
        val isCardOrder = CARD_ORDER_RE.containsMatchIn(message)
        val isMallOrder = MALL_ORDER_RE.containsMatchIn(message)
        if (invoice.isNullOrBlank() && !isCardOrder && !isMallOrder) return

        val capturedAtMillis = System.currentTimeMillis()

        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putString("last_channel", "kakao")
            .putString("last_package", KAKAO_PACKAGE)
            .putString("last_body", message)
            .putLong("last_captured_at", capturedAtMillis)
            .apply()
        enqueueCapture(message, capturedAtMillis)

        Log.i(TAG, "captured raw kakao message invoice=$invoice")
    }

    private fun enqueueCapture(body: String, capturedAtMillis: Long) {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val dedupeKey = "kakao|$KAKAO_PACKAGE|$body"
        val queue = try {
            JSONArray(prefs.getString(KEY_PENDING_CAPTURES, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        for (index in 0 until queue.length()) {
            val existing = queue.optJSONObject(index) ?: continue
            if (existing.optString("dedupeKey") == dedupeKey) return
        }
        val next = JSONArray()
        val start = (queue.length() - MAX_PENDING_CAPTURES + 1).coerceAtLeast(0)
        for (index in start until queue.length()) {
            next.put(queue.get(index))
        }
        next.put(
            JSONObject()
                .put("channel", "kakao")
                .put("packageName", KAKAO_PACKAGE)
                .put("title", JSONObject.NULL)
                .put("sender", JSONObject.NULL)
                .put("body", body)
                .put("capturedAtMillis", capturedAtMillis)
                .put("dedupeKey", dedupeKey),
        )
        prefs.edit().putString(KEY_PENDING_CAPTURES, next.toString()).apply()
        BackgroundCaptureSync.trigger(this)
    }

    companion object {
        private const val TAG = "CheckShippingKakao"
        private const val KAKAO_PACKAGE = "com.kakao.talk"
        private const val ALIMTALK_TITLE_ID = "com.kakao.talk:id/alimtalk_title"
        private const val PREFS = "kakao_accessibility"
        private const val KEY_PENDING_CAPTURES = "pending_captures"
        private const val MAX_SEEN = 100
        private const val MAX_PENDING_CAPTURES = 25

        private val INVOICE_RE = Regex("""운송장번호\s*[:：]\s*([0-9\-]{9,20})""")
        private val CARD_ORDER_RE = Regex("""\[[^\]]*카드\][\s\S]{0,80}?\d{1,3}(?:,\d{3})*\s*원""")
        private val MALL_ORDER_RE = Regex("""\[[^\]]+\][\s\S]{0,30}?주문\s*완료""")
    }
}
