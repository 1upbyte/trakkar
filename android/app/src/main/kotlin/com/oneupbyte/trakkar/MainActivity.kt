package com.oneupbyte.trakkar

import com.oneupbyte.trakkar.bridge.SdkConfigResetBridge
import com.oneupbyte.trakkar.live.LiveTrackingController
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "trakkar/live_tracking")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        LiveTrackingController.configure(applicationContext, call.arguments as Map<*, *>)
                        LiveTrackingController.reconcile(applicationContext)
                        result.success(null)
                    }
                    "setEnabled" -> {
                        val enabled = (call.arguments as? Map<*, *>)?.get("enabled") == true
                        if (enabled) {
                            LiveTrackingController.reconcile(applicationContext)
                            result.success(null)
                        } else CoroutineScope(Dispatchers.Main).launch {
                            LiveTrackingController.pause(applicationContext)
                            result.success(null)
                        }
                    }
                    "pushToken" -> {
                        if (FirebaseApp.getApps(applicationContext).isEmpty()) result.success(null)
                        else FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                            if (task.isSuccessful) result.success(task.result)
                            else result.error("push_token", "Push registration unavailable", null)
                        }
                    }
                    "register" -> {
                        val args = call.arguments as Map<*, *>
                        LiveTrackingController.register(applicationContext, args["endpoint"] as String, args["deviceToken"] as String)
                        LiveTrackingController.reconcile(applicationContext)
                        result.success(null)
                    }
                    "clear" -> CoroutineScope(Dispatchers.Main).launch {
                        LiveTrackingController.clear(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "trakkar/settings_reset",
        ).setMethodCallHandler { call, result ->
            if (call.method != "clearSdkConnectionConfig") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                SdkConfigResetBridge(applicationContext).clearConfiguration()
                result.success(null)
            } catch (error: Exception) {
                val pendingPositions = error.message == "Pending positions must sync before reset"
                result.error(
                    if (pendingPositions) "sdk_reset_queue_pending" else "sdk_reset_failed",
                    if (pendingPositions) "Pending positions must sync before reset." else "Could not clear tracking configuration.",
                    null,
                )
            }
        }
    }
}
