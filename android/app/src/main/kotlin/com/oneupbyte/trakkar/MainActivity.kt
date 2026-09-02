package com.oneupbyte.trakkar

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.oneupbyte.trakkar/map-sdk",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setGoogleMapsApiKey" -> {
                    val key = call.argument<String>("key")?.trim().orEmpty()
                    result.success(key.isNotEmpty() && setGoogleMapsApiKey(key))
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Delivers a Google Maps SDK key at runtime.
     *
     * The Maps SDK reads `com.google.android.geo.API_KEY` from the
     * application's manifest meta-data when the first map is created. There is
     * no public runtime setter, so the meta-data bundle is updated in place on
     * every ApplicationInfo instance the SDK can observe. Android 11 and later
     * cache ApplicationInfo per process, so the change is visible to the SDK;
     * older versions hand out fresh copies and fall back to the build-time
     * manifest placeholder instead.
     */
    private fun setGoogleMapsApiKey(key: String): Boolean {
        var applied = false
        val infos = mutableListOf(applicationContext.applicationInfo, applicationInfo)
        try {
            infos += packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        } catch (_: PackageManager.NameNotFoundException) {
            // Unreachable for the running package, but never fatal.
        }
        for (info in infos) {
            val metaData = info.metaData ?: Bundle().also { info.metaData = it }
            metaData.putString(GOOGLE_MAPS_KEY_META, key)
            metaData.remove(LEGACY_GOOGLE_MAPS_KEY_META)
            applied = true
        }
        return applied
    }

    private companion object {
        const val GOOGLE_MAPS_KEY_META = "com.google.android.geo.API_KEY"
        const val LEGACY_GOOGLE_MAPS_KEY_META = "com.google.android.maps.v2.API_KEY"
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
