package com.checkshipping.check_shipping

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.window.OnBackInvokedDispatcher
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var appControlChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_OVERLAY,
            ) {
                requestGoHome()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        isInForeground = true
    }

    override fun onPause() {
        isInForeground = false
        super.onPause()
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        isInForeground = false
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CaptureChannelHandler.register(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
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
        appControlChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_CONTROL_CHANNEL,
        )
        appControlChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Android framework, still used by FlutterActivity back dispatch.")
    override fun onBackPressed() {
        requestGoHome()
    }

    private fun requestGoHome() {
        appControlChannel?.invokeMethod("goHome", null)
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
        @Volatile
        private var instance: MainActivity? = null

        @Volatile
        var isInForeground: Boolean = false
            private set

        /// Asks the foreground app engine to run a capture sync now.
        /// Returns false when the app isn't in the foreground (the caller
        /// should fall back to the headless background engine). Must be
        /// called on the main thread.
        fun requestForegroundSync(): Boolean {
            if (!isInForeground) return false
            val channel = instance?.appControlChannel ?: return false
            channel.invokeMethod("syncNow", null)
            return true
        }

        private const val SETTINGS_CHANNEL = "check_shipping/system_settings"
        private const val APP_CONTROL_CHANNEL = "check_shipping/app_control"
    }
}
