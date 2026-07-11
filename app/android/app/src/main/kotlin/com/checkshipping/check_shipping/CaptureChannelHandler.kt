package com.checkshipping.check_shipping

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/// Registers the capture MethodChannel on any Flutter engine — the
/// foreground activity engine and the headless background-sync engine
/// share this one implementation.
object CaptureChannelHandler {
    const val CHANNEL = "check_shipping/kakao_capture"

    fun register(
        context: Context,
        messenger: BinaryMessenger,
        onBackgroundSyncDone: (() -> Unit)? = null,
    ) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLatestCapture" -> result.success(readLatestCapture(appContext))
                "getPendingCaptures" -> result.success(readPendingCaptures(appContext))
                "scanActiveNotifications" -> result.success(
                    CheckShippingNotificationListenerService.scanActiveNotificationsFromFlutter(),
                )
                "getSamsungFlipFont" -> result.success(
                    SamsungFlipFontReader.read(appContext),
                )
                "clearLatestCapture", "clearPendingCaptures" -> {
                    clearCaptures(appContext)
                    result.success(null)
                }
                "notifyNewCaptures" -> {
                    val count = (call.argument<Int>("count")) ?: 0
                    CaptureNotifier.addUnseen(appContext, count)
                    result.success(null)
                }
                "backgroundSyncDone" -> {
                    onBackgroundSyncDone?.invoke()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readLatestCapture(context: Context): Map<String, Any?>? {
        val prefs = context.getSharedPreferences(CapturePrefs.NAME, Context.MODE_PRIVATE)
        val body = prefs.getString("last_body", null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: return null
        return mapOf(
            "channel" to (prefs.getString("last_channel", null) ?: "kakao"),
            "packageName" to prefs.getString("last_package", null),
            "title" to prefs.getString("last_title", null),
            "sender" to prefs.getString("last_sender", null),
            "body" to body,
            "capturedAtMillis" to prefs.getLong("last_captured_at", 0L),
        )
    }

    private fun readPendingCaptures(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(CapturePrefs.NAME, Context.MODE_PRIVATE)
        val queue = try {
            JSONArray(prefs.getString(CapturePrefs.KEY_PENDING_CAPTURES, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val captures = mutableListOf<Map<String, Any?>>()
        for (index in 0 until queue.length()) {
            val item = queue.optJSONObject(index) ?: continue
            val body = item.optString("body").trim()
            if (body.isEmpty()) continue
            captures.add(
                mapOf(
                    "channel" to item.optString("channel", "kakao"),
                    "packageName" to item.optNullableString("packageName"),
                    "title" to item.optNullableString("title"),
                    "sender" to item.optNullableString("sender"),
                    "body" to body,
                    "capturedAtMillis" to item.optLong("capturedAtMillis", 0L),
                ),
            )
        }
        return captures
    }

    private fun clearCaptures(context: Context) {
        context.getSharedPreferences(CapturePrefs.NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(CapturePrefs.KEY_PENDING_CAPTURES)
            .remove("last_channel")
            .remove("last_package")
            .remove("last_title")
            .remove("last_sender")
            .remove("last_body")
            .remove("last_captured_at")
            .apply()
    }

    private fun JSONObject.optNullableString(key: String): String? {
        if (isNull(key)) return null
        return optString(key).trim().takeIf { it.isNotEmpty() }
    }
}
