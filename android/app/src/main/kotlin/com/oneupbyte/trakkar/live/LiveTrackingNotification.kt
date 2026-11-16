package com.oneupbyte.trakkar.live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import com.oneupbyte.trakkar.R

/** A visible, soundless indication for time-sensitive FCM activations. */
object LiveTrackingNotification {
    private const val CHANNEL = "live_tracking"
    private const val ID = 0x54524b

    fun show(context: Context, remainingMillis: Long) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, "Live location sharing", NotificationManager.IMPORTANCE_LOW,
            ).apply {
                setSound(null, null)
                enableVibration(false)
            })
            Notification.Builder(context, CHANNEL)
                .setTimeoutAfter(remainingMillis.coerceIn(1, 30000))
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { intent ->
            builder.setContentIntent(PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ))
        }
        @Suppress("DEPRECATION")
        val notification = builder
            .setSmallIcon(R.drawable.ic_live_tracking_notification)
            .setContentTitle("Live location sharing")
            .setContentText("Someone has Trakkar open. Sharing updates more frequently.")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setPriority(Notification.PRIORITY_LOW)
            .setSound(null)
            .setVibrate(null)
            .setDefaults(0)
            .build()
        try {
            manager.notify(ID, notification)
        } catch (_: SecurityException) {
            // Revoked notification permission must not interrupt location tracking.
        }
    }

    fun hide(context: Context) {
        context.getSystemService(NotificationManager::class.java).cancel(ID)
    }
}
