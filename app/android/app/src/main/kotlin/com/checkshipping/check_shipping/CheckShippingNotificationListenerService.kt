package com.checkshipping.check_shipping

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class CheckShippingNotificationListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        activeService = this
        scanActiveNotifications("listener_connected")
    }

    override fun onListenerDisconnected() {
        if (activeService === this) activeService = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        processNotification(sbn, "posted")
    }

    override fun onDestroy() {
        if (activeService === this) activeService = null
        super.onDestroy()
    }

    fun scanActiveNotifications(reason: String): Int {
        val notifications = try {
            activeNotifications.orEmpty()
        } catch (error: SecurityException) {
            Log.w(TAG, "active notification scan denied reason=$reason", error)
            return 0
        }
        notifications.forEach { processNotification(it, reason) }
        Log.i(TAG, "scanned active notifications count=${notifications.size} reason=$reason")
        return notifications.size
    }

    private fun processNotification(sbn: StatusBarNotification?, reason: String) {
        val notification = sbn?.notification ?: return
        val packageName = sbn.packageName ?: return
        val channel = classifyPackage(packageName) ?: return
        val isGroupSummary = notification.flags and Notification.FLAG_GROUP_SUMMARY != 0

        val title = notification.textExtra(Notification.EXTRA_TITLE)
        val body = buildBody(notification)
        if (body.isBlank()) {
            Log.d(
                TAG,
                "ignored blank notification package=$packageName groupSummary=$isGroupSummary reason=$reason",
            )
            return
        }
        // Card-payment alerts (any issuer) rarely mention shipping words at
        // all, so they'd otherwise get dropped here before RuleEngine's
        // card_order_generic rule (titleMatch "카드$") ever sees them. Gate
        // on the same signal so this pre-filter doesn't silently swallow them.
        val looksLikeCardOrder = title?.trim()?.endsWith("카드") == true
        if (!looksLikeCardOrder && !looksLikeDelivery("$title\n$body")) {
            Log.d(
                TAG,
                "ignored non-delivery notification package=$packageName groupSummary=$isGroupSummary reason=$reason",
            )
            return
        }

        enqueueCapture(
            channel = channel,
            packageName = packageName,
            title = title,
            sender = title,
            body = body,
            capturedAtMillis = sbn.postTime.takeIf { it > 0 } ?: System.currentTimeMillis(),
            groupSummary = isGroupSummary,
            reason = reason,
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
        add(extras.getCharSequence(Notification.EXTRA_TITLE_BIG))
        add(extras.getCharSequence(Notification.EXTRA_SUB_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_INFO_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE))
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
        groupSummary: Boolean,
        reason: String,
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
            if (existing.optString("dedupeKey") == dedupeKey) {
                Log.d(
                    TAG,
                    "skipped duplicate notification channel=$channel package=$packageName groupSummary=$groupSummary reason=$reason",
                )
                return
            }
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
        Log.i(
            TAG,
            "captured notification channel=$channel package=$packageName groupSummary=$groupSummary reason=$reason",
        )
        BackgroundCaptureSync.trigger(this)
    }

    companion object {
        @Volatile
        private var activeService: CheckShippingNotificationListenerService? = null

        fun scanActiveNotificationsFromFlutter(): Int =
            activeService?.scanActiveNotifications("flutter_request") ?: 0

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
