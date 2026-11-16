package com.oneupbyte.trakkar.live

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import android.util.Log
import com.oneupbyte.trakkar.BuildConfig

class LiveTrackingMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (message.data["type"] != "live_tracking") return
        if (BuildConfig.DEBUG && BuildConfig.BUILD_TYPE == "debug") Log.i("TrakkarLive", "push_received")
        // A push is only a wake-up hint. Authorize against the current server
        // lease rather than comparing its timestamp with this phone's clock.
        LiveTrackingController.reconcile(applicationContext)
    }
    override fun onNewToken(token: String) {
        // Flutter re-registers the current token on its next foreground renewal.
        applicationContext.getSharedPreferences("trakkar-fcm", MODE_PRIVATE).edit()
            .putString("pushToken", token).apply()
    }
}
