package com.checkshipping.check_shipping

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/// Posts (and clears) the local notification behind the launcher icon
/// badge for deliveries/orders captured while the app wasn't open.
///
/// Android has no standalone "badge" API — the badge shown on the app
/// icon is derived from the app's own active notifications, so getting a
/// badge means keeping exactly one real notification around and updating
/// its count. The count persists across headless-engine runs (each one
/// is a throwaway process) and resets when the user actually opens the
/// app (MainActivity.onResume clears it).
object CaptureNotifier {
    private const val PREFS = "kakao_accessibility"
    private const val KEY_UNSEEN_COUNT = "unseen_capture_count"
    private const val CHANNEL_ID = "new_captures"
    private const val NOTIFICATION_ID = 1001

    fun addUnseen(context: Context, delta: Int) {
        if (delta <= 0) return
        val appContext = context.applicationContext
        val prefs = prefs(appContext)
        val total = prefs.getInt(KEY_UNSEEN_COUNT, 0) + delta
        prefs.edit().putInt(KEY_UNSEEN_COUNT, total).apply()
        post(appContext, total)
    }

    fun clearUnseen(context: Context) {
        val appContext = context.applicationContext
        if (prefs(appContext).getInt(KEY_UNSEEN_COUNT, 0) == 0) return
        prefs(appContext).edit().putInt(KEY_UNSEEN_COUNT, 0).apply()
        NotificationManagerCompat.from(appContext).cancel(NOTIFICATION_ID)
    }

    private fun post(context: Context, total: Int) {
        ensureChannel(context)
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(context.getString(R.string.new_capture_notification_title))
            .setContentText(
                context.getString(R.string.new_capture_notification_body, total),
            )
            .setNumber(total)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted (Android 13+, denied) — the
            // in-app list still has the data, just no badge this time.
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.new_capture_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
