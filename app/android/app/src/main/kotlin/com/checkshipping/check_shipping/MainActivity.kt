package com.checkshipping.check_shipping

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLatestCapture" -> result.success(readLatestCapture())
                    "getSamsungFlipFont" -> result.success(readSamsungFlipFont())
                    "clearLatestCapture" -> {
                        getSharedPreferences(PREFS, MODE_PRIVATE).edit().clear().apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readLatestCapture(): Map<String, Any?>? {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val invoice = prefs.getString("last_invoice", null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: return null
        return mapOf(
            "courierCode" to (prefs.getString("last_courier", null) ?: "unknown"),
            "trackingNumber" to invoice,
            "status" to (prefs.getString("last_status", null) ?: "registered"),
            "sender" to prefs.getString("last_sender", null),
            "capturedAtMillis" to prefs.getLong("last_captured_at", 0L),
        )
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
        val candidates = listOfNotNull(
            selected,
            "com.monotype.android.font.chococooky".takeIf { selected != "com.monotype.android.font.chococooky" },
        )
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

    companion object {
        private const val CHANNEL = "check_shipping/kakao_capture"
        private const val PREFS = "kakao_accessibility"
    }
}
