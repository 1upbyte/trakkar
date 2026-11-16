package com.oneupbyte.trakkar.live

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.traccar.client.Config
import org.traccar.client.Tracker
import org.traccar.client.TrackerService
import org.traccar.client.sharedTracker

/** Serializes SDK rebuilds and leaves an unchanged running profile alone. */
internal object TrackingProfile {
    private val mutex = Mutex()

    suspend fun apply(context: Context, config: Config): Tracker = mutex.withLock {
        val tracker = sharedTracker(config)
        if (tracker.config == config) return@withLock tracker
        val requiresForeground = Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        if (requiresForeground && tracker.state.value.enabled) {
            val manager = context.getSystemService(ActivityManager::class.java)
            awaitForegroundService(ready = {
                @Suppress("DEPRECATION")
                manager.getRunningServices(Int.MAX_VALUE).any {
                    it.service.className == TrackerService::class.java.name && it.foreground
                }
            })
        }
        tracker.updateConfig(config)
    }
}
