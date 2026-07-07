package com.checkshipping.check_shipping

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class CheckShippingNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        val packageName = sbn.packageName ?: return
        val channel = classifyPackage(packageName) ?: return

        val title = notification.textExtra(Notification.EXTRA_TITLE)
        val body = buildBody(notification)
        if (body.isBlank() || !looksLikeDelivery("$title\n$body")) return

        enqueueCapture(
            channel = channel,
            packageName = packageName,
            title = title,
            sender = title,
            body = body,
            capturedAtMillis = sbn.postTime.takeIf { it > 0 } ?: System.currentTimeMillis(),
        )
    }

    private fun classifyPackage(packageName: String): String? = when (packageName) {
        "com.google.android.gm" -> "gmail"
        "com.nhn.android.mail",
        "com.naver.mail",
        "com.naver.android.mail" -> "gmail"
        "com.samsung.android.messaging",
        "com.google.android.apps.messaging",
        "com.android.mms",
        "com.android.messaging" -> "sms"
        else -> null
    }

    private fun buildBody(notification: Notification): String {
        val extras = notification.extras
        val lines = mutableListOf<String>()
        fun add(value: CharSequence?) {
            val text = value?.toString()?.trim()
            if (!text.isNullOrEmpty() && !lines.contains(text)) lines.add(text)
        }

        add(extras.getCharSequence(Notification.EXTRA_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_BIG_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_SUB_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT))
        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        textLines?.forEach { add(it) }
        return lines.joinToString("\n")
    }

    private fun Notification.textExtra(key: String): String? =
        extras.getCharSequence(key)?.toString()?.trim()?.takeIf { it.isNotEmpty() }

    private fun looksLikeDelivery(text: String): Boolean =
        DELIVERY_HINTS.any { it.containsMatchIn(text) }

    private fun enqueueCapture(
        channel: String,
        packageName: String,
        title: String?,
        sender: String?,
        body: String,
        capturedAtMillis: Long,
    ) {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val dedupeKey = "$channel|$packageName|${title.orEmpty()}|$body"
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
                .put("channel", channel)
                .put("packageName", packageName)
                .put("title", title)
                .put("sender", sender)
                .put("body", body)
                .put("capturedAtMillis", capturedAtMillis)
                .put("dedupeKey", dedupeKey),
        )

        prefs.edit()
            .putString(KEY_PENDING_CAPTURES, next.toString())
            .putString("last_channel", channel)
            .putString("last_package", packageName)
            .putString("last_title", title)
            .putString("last_sender", sender)
            .putString("last_body", body)
            .putLong("last_captured_at", capturedAtMillis)
            .apply()
        Log.i(TAG, "captured notification channel=$channel package=$packageName")
    }

    companion object {
        private const val TAG = "CheckShippingNotify"
        private const val PREFS = "kakao_accessibility"
        private const val KEY_PENDING_CAPTURES = "pending_captures"
        private const val MAX_PENDING_CAPTURES = 25

        private val DELIVERY_HINTS = listOf(
            Regex("""운송장|송장|등기\s*번호"""),
            Regex("""배송|배달|택배|집화|집하|상품\s*인수"""),
            Regex("""CJ\s*대한통운|대한통운|한진|롯데\s*택배|롯데택배|우체국|로젠|쿠팡"""),
        )
    }
}
