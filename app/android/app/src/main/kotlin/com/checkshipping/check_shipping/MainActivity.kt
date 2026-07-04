package com.checkshipping.check_shipping

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLatestCapture" -> result.success(readLatestCapture())
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

    companion object {
        private const val CHANNEL = "check_shipping/kakao_capture"
        private const val PREFS = "kakao_accessibility"
    }
}
