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
        // Card-payment and mall order-confirmation notification channels
        // have no invoice number at all — accept them too so RuleEngine's
        // card_order_bracket_tag / mall_order_complete_generic rules get a
        // chance to see them.
        val isCardOrder = CapturePrefs.CARD_ORDER_RE.containsMatchIn(message)
        val isMallOrder = CapturePrefs.MALL_ORDER_RE.containsMatchIn(message)
        if (invoice.isNullOrBlank() && !isCardOrder && !isMallOrder) {
            // Logged so a message this pre-filter drops is still
            // diagnosable from logcat if the JSON rules
            // (assets/parse_rules_fallback.json) change to accept
            // something this filter no longer mirrors.
            Log.i(TAG, "ignored non-matching kakao message excerpt=${message.take(60)}")
            return
        }

        val capturedAtMillis = System.currentTimeMillis()

        getSharedPreferences(CapturePrefs.NAME, MODE_PRIVATE)
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
        val prefs = getSharedPreferences(CapturePrefs.NAME, MODE_PRIVATE)
        val dedupeKey = "kakao|$KAKAO_PACKAGE|$body"
        val queue = try {
            JSONArray(prefs.getString(CapturePrefs.KEY_PENDING_CAPTURES, "[]"))
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
        prefs.edit().putString(CapturePrefs.KEY_PENDING_CAPTURES, next.toString()).apply()
        BackgroundCaptureSync.trigger(this)
    }

    companion object {
        private const val TAG = "CheckShippingKakao"
        private const val KAKAO_PACKAGE = "com.kakao.talk"
        private const val ALIMTALK_TITLE_ID = "com.kakao.talk:id/alimtalk_title"
        private const val MAX_SEEN = 100
        private const val MAX_PENDING_CAPTURES = 25

        private val INVOICE_RE = Regex("""운송장번호\s*[:：]\s*([0-9\-]{9,20})""")
    }
}
