package com.oneupbyte.trakkar.live

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

object LiveTrackingBridge {
    fun install(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "trakkar/live_tracking").setMethodCallHandler { call, result ->
            when (call.method) {
                "reconcile" -> {
                    LiveTrackingController.reconcile(context)
                    result.success(null)
                }
                "configure" -> CoroutineScope(Dispatchers.Main).launch {
                    LiveTrackingController.configure(context, call.arguments as Map<*, *>)
                    LiveTrackingController.reconcile(context)
                    result.success(null)
                }
                "setEnabled" -> {
                    val enabled = (call.arguments as? Map<*, *>)?.get("enabled") == true
                    if (enabled) {
                        LiveTrackingController.reconcile(context)
                        result.success(null)
                    } else CoroutineScope(Dispatchers.Main).launch {
                        LiveTrackingController.pause(context)
                        result.success(null)
                    }
                }
                "pushToken" -> {
                    if (FirebaseApp.getApps(context).isEmpty()) result.success(null)
                    else FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                        if (task.isSuccessful) result.success(task.result)
                        else result.error("push_token", "Push registration unavailable", null)
                    }
                }
                "register" -> {
                    val args = call.arguments as Map<*, *>
                    LiveTrackingController.register(context, args["endpoint"] as String, args["deviceToken"] as String)
                    LiveTrackingController.reconcile(context)
                    result.success(null)
                }
                "clear" -> CoroutineScope(Dispatchers.Main).launch {
                    LiveTrackingController.clear(context)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
