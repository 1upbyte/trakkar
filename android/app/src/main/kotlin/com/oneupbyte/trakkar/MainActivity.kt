package com.oneupbyte.trakkar

import com.oneupbyte.trakkar.bridge.SdkConfigResetBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
