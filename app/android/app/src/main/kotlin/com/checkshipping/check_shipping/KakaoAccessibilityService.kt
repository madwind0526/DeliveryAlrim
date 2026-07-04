package com.checkshipping.check_shipping

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class KakaoAccessibilityService : AccessibilityService() {
    private val seenTexts = LinkedHashSet<String>()

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.packageName != KAKAO_PACKAGE) return
        val root = rootInActiveWindow ?: return
        val messages = mutableListOf<String>()
        collectAlimtalkMessages(root, messages)
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
        if (invoice.isNullOrBlank()) return

        val courier = when {
            message.contains("CJ대한통운") || message.contains("대한통운") -> "cj"
            message.contains("롯데택배") -> "lotte"
            message.contains("한진") -> "hanjin"
            message.contains("우체국") -> "epost"
            message.contains("로젠") -> "logen"
            else -> "unknown"
        }
        val status = when {
            message.contains("배송완료") || message.contains("배달완료") -> "delivered"
            message.contains("배송출발") || message.contains("배송 예정") -> "out_for_delivery"
            message.contains("배송중") -> "in_transit"
            message.contains("집화") || message.contains("상품인수") -> "picked_up"
            else -> "registered"
        }
        val sender = SENDER_RE.find(message)?.groupValues?.getOrNull(1)?.trim()

        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putString("last_courier", courier)
            .putString("last_invoice", invoice)
            .putString("last_status", status)
            .putString("last_sender", sender)
            .putLong("last_captured_at", System.currentTimeMillis())
            .apply()

        Log.i(
            TAG,
            "captured courier=$courier invoice=$invoice status=$status sender=${sender ?: ""}",
        )
    }

    companion object {
        private const val TAG = "CheckShippingKakao"
        private const val KAKAO_PACKAGE = "com.kakao.talk"
        private const val ALIMTALK_TITLE_ID = "com.kakao.talk:id/alimtalk_title"
        private const val PREFS = "kakao_accessibility"
        private const val MAX_SEEN = 100

        private val INVOICE_RE = Regex("""운송장번호\s*[:：]\s*([0-9\-]{9,20})""")
        private val SENDER_RE = Regex("""보내는(?:분|곳)\s*[:：]\s*([^\n]+)""")
    }
}
