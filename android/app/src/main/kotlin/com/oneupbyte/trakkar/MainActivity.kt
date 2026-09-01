package com.oneupbyte.trakkar

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.oneupbyte.trakkar/tracking-support",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTrackingHealth" -> result.success(trackingHealth())
                "openLocationSettings" -> {
                    openAppSettings()
                    result.success(null)
                }
                "openBatterySettings" -> {
                    openBatterySettings()
                    result.success(null)
                }
                "requestAlwaysIfNeeded" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }

    private fun trackingHealth(): Map<String, Boolean> {
        val foregroundGranted =
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED ||
                checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        val backgroundGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        val batteryRelevant = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
        val batteryOkay = !batteryRelevant ||
            (getSystemService(POWER_SERVICE) as PowerManager)
                .isIgnoringBatteryOptimizations(packageName)

        return mapOf(
            "locationAlways" to (foregroundGranted && backgroundGranted),
            "batteryOptimizationOkay" to batteryOkay,
            "batteryOptimizationRelevant" to batteryRelevant,
        )
    }

    private fun openAppSettings() {
        startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun openBatterySettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            )
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            openAppSettings()
        }
    }
}
