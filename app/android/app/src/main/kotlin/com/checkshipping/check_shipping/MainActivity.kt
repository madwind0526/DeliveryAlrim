package com.checkshipping.check_shipping

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLatestCapture" -> result.success(readLatestCapture())
                    "getPendingCaptures" -> result.success(readPendingCaptures())
                    "getSamsungFlipFont" -> result.success(readSamsungFlipFont())
                    "clearLatestCapture" -> {
                        clearCaptures()
                        result.success(null)
                    }
                    "clearPendingCaptures" -> {
                        clearCaptures()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readState" -> result.success(readSettingsState())
                    "openNotificationAccessSettings" -> result.success(
                        openSettings(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
                    )
                    "openAccessibilitySettings" -> result.success(
                        openSettings(Settings.ACTION_ACCESSIBILITY_SETTINGS),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun readLatestCapture(): Map<String, Any?>? {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
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

    private fun readPendingCaptures(): List<Map<String, Any?>> {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val queue = try {
            JSONArray(prefs.getString(KEY_PENDING_CAPTURES, "[]"))
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

    private fun clearCaptures() {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .remove(KEY_PENDING_CAPTURES)
            .remove("last_channel")
            .remove("last_package")
            .remove("last_title")
            .remove("last_sender")
            .remove("last_body")
            .remove("last_captured_at")
            .apply()
    }

    private fun org.json.JSONObject.optNullableString(key: String): String? {
        if (isNull(key)) return null
        return optString(key).trim().takeIf { it.isNotEmpty() }
    }

    private fun readSamsungFlipFont(): ByteArray? {
        val fontStyleIndex = readFontStyleIndex()
        if (fontStyleIndex <= 0) {
            return null
        }
        val selected = when (fontStyleIndex) {
            1 -> "com.monotype.android.font.samsungone"
            2 -> "com.monotype.android.font.samsungsans"
            3 -> "com.monotype.android.font.applemint"
            4 -> "com.monotype.android.font.cooljazz"
            5 -> "com.monotype.android.font.chococooky"
            6 -> "com.monotype.android.font.tinkerbell"
            7 -> "com.monotype.android.font.sdmisaeng"
            else -> null
        }
        val candidates = (listOfNotNull(selected) + FLIP_FONT_PACKAGES)
            .distinct()
        for (packageName in candidates) {
            val bytes = readFirstFontAsset(packageName)
            if (bytes != null) return bytes
        }
        return null
    }

    private fun readFontStyleIndex(): Int {
        val global = android.provider.Settings.Global.getInt(
            contentResolver,
            "font_style_index",
            0,
        )
        if (global > 0) return global
        return android.provider.Settings.System.getInt(
            contentResolver,
            "font_style_index",
            0,
        )
    }

    private fun readFirstFontAsset(packageName: String): ByteArray? {
        val packageContext = try {
            createPackageContext(packageName, 0)
        } catch (_: Exception) {
            return null
        }
        val assets = packageContext.assets
        val fontFiles = try {
            assets.list("fonts")?.filter {
                it.endsWith(".ttf", ignoreCase = true) || it.endsWith(".otf", ignoreCase = true)
            }
        } catch (_: Exception) {
            null
        }.orEmpty()
        for (fontFile in fontFiles) {
            try {
                assets.open("fonts/$fontFile").use { input ->
                    val output = ByteArrayOutputStream()
                    input.copyTo(output)
                    return output.toByteArray()
                }
            } catch (_: Exception) {
                continue
            }
        }
        return null
    }

    private fun readSettingsState(): Map<String, Any> {
        return mapOf(
            "notificationAccess" to isNotificationAccessEnabled(),
            "accessibilityAccess" to isAccessibilityAccessEnabled(),
        )
    }

    private fun openSettings(action: String): Boolean {
        return try {
            startActivity(Intent(action))
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun isNotificationAccessEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val component = ComponentName(
            packageName,
            CheckShippingNotificationListenerService::class.java.name,
        )
        return enabled.split(':').any {
            it.equals(component.flattenToString(), ignoreCase = true)
        }
    }

    private fun isAccessibilityAccessEnabled(): Boolean {
        val accessibilityEnabled = Settings.Secure.getInt(
            contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0,
        ) == 1
        if (!accessibilityEnabled) return false
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val component = ComponentName(
            packageName,
            KakaoAccessibilityService::class.java.name,
        )
        return enabled.split(':').any {
            it.equals(component.flattenToString(), ignoreCase = true)
        }
    }

    companion object {
        private const val CHANNEL = "check_shipping/kakao_capture"
        private const val SETTINGS_CHANNEL = "check_shipping/system_settings"
        private const val PREFS = "kakao_accessibility"
        private const val KEY_PENDING_CAPTURES = "pending_captures"
        private val FLIP_FONT_PACKAGES = listOf(
            "com.monotype.android.font.samsungone",
            "com.monotype.android.font.samsungsans",
            "com.monotype.android.font.applemint",
            "com.monotype.android.font.cooljazz",
            "com.monotype.android.font.chococooky",
            "com.monotype.android.font.tinkerbell",
            "com.monotype.android.font.sdmisaeng",
            "com.monotype.android.font.foundation",
            "com.monotype.android.font.roboto",
        )
    }
}
