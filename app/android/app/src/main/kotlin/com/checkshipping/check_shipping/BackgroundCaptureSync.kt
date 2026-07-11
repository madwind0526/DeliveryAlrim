package com.checkshipping.check_shipping

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/// Runs the Dart capture-sync pipeline without the app being open.
///
/// When a capture service enqueues a delivery-looking message it calls
/// [trigger]. If the activity is in the foreground we just poke it (the
/// app engine syncs itself); otherwise, after a short debounce that
/// batches notification bursts, a headless FlutterEngine executes the
/// `backgroundCaptureSync` entrypoint — the same parse/merge path the
/// app uses — and is torn down when Dart reports completion.
object BackgroundCaptureSync {
    private const val TAG = "CheckShippingBgSync"
    private const val DEBOUNCE_MS = 4_000L
    private const val ENGINE_TIMEOUT_MS = 60_000L

    private val mainHandler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var scheduled = false
    private var rerunRequested = false

    fun trigger(context: Context) {
        val appContext = context.applicationContext
        mainHandler.post {
            if (MainActivity.requestForegroundSync()) {
                Log.i(TAG, "delegated sync to foreground app")
                return@post
            }
            if (scheduled) return@post
            scheduled = true
            mainHandler.postDelayed({
                scheduled = false
                start(appContext)
            }, DEBOUNCE_MS)
        }
    }

    private fun start(context: Context) {
        if (MainActivity.requestForegroundSync()) {
            Log.i(TAG, "delegated sync to foreground app")
            return
        }
        if (engine != null) {
            rerunRequested = true
            return
        }
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            if (!loader.initialized()) {
                loader.startInitialization(context)
            }
            loader.ensureInitializationComplete(context, null)

            val newEngine = FlutterEngine(context)
            engine = newEngine
            GeneratedPluginRegistrant.registerWith(newEngine)
            CaptureChannelHandler.register(
                context,
                newEngine.dartExecutor.binaryMessenger,
            ) { finish(context) }
            newEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "package:check_shipping/background_sync.dart",
                    "backgroundCaptureSync",
                ),
            )
            Log.i(TAG, "background sync engine started")

            // Safety net: never keep a stuck engine alive.
            mainHandler.postDelayed({
                if (engine === newEngine) {
                    Log.w(TAG, "background sync engine timed out")
                    finish(context)
                }
            }, ENGINE_TIMEOUT_MS)
        } catch (error: Throwable) {
            Log.w(TAG, "background sync engine failed to start", error)
            engine?.destroy()
            engine = null
        }
    }

    private fun finish(context: Context) {
        mainHandler.post {
            engine?.destroy()
            engine = null
            Log.i(TAG, "background sync engine finished")
            if (rerunRequested) {
                rerunRequested = false
                start(context)
            }
        }
    }
}
