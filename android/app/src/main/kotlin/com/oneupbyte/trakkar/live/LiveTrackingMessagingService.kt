package com.oneupbyte.trakkar.live

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class LiveTrackingMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (message.data["type"] != "live_tracking") return
        val until = message.data["expiresAt"]?.toLongOrNull() ?: return
        LiveTrackingController.kick(applicationContext, until)
    }
    override fun onNewToken(token: String) {
        // Flutter re-registers the current token on its next visible-map renewal.
        applicationContext.getSharedPreferences("trakkar-fcm", MODE_PRIVATE).edit()
            .putString("pushToken", token).apply()
    }
}
