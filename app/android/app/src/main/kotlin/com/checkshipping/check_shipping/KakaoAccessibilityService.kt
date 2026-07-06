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
        if (invoice.isNullOrBlank()) return

        val capturedAtMillis = System.currentTimeMillis()

        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putString("last_channel", "kakao")
            .putString("last_package", KAKAO_PACKAGE)
            .putString("last_body", message)
            .putLong("last_captured_at", capturedAtMillis)
            .apply()

        Log.i(TAG, "captured raw kakao message invoice=$invoice")
    }

    companion object {
        private const val TAG = "CheckShippingKakao"
        private const val KAKAO_PACKAGE = "com.kakao.talk"
        private const val ALIMTALK_TITLE_ID = "com.kakao.talk:id/alimtalk_title"
        private const val PREFS = "kakao_accessibility"
        private const val MAX_SEEN = 100

        private val INVOICE_RE = Regex("""운송장번호\s*[:：]\s*([0-9\-]{9,20})""")
    }
}
