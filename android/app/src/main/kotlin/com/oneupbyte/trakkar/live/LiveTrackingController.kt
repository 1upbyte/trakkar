package com.oneupbyte.trakkar.live

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONObject
import org.traccar.client.*
import java.net.HttpURLConnection
import java.net.URI

/** Uses the running Traccar foreground service; never launches permission UI from a push. */
object LiveTrackingController {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var job: Job? = null
    private var generation = 0
    private var expiresAt = 0L
    private const val PREFS = "trakkar-live-tracking"

    suspend fun configure(context: Context, arguments: Map<*, *>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        // Dart has applied the normal profile; prevent an older live job from
        // restoring another connection while account configuration changes.
        prefs.edit().putBoolean("temporary", false).commit()
        pause(context)
        val next = JSONObject(arguments)
        val previous = prefs.getString("baseline", null)?.let { JSONObject(it) }
        if (previous != null && (previous.optString("deviceId") != next.optString("deviceId") ||
                previous.optString("serverUrl") != next.optString("serverUrl"))) {
            prefs.edit().clear().commit()
        }
        prefs.edit().putString("baseline", next.toString()).commit()
        baseline(context)?.let { sharedTracker()?.updateConfig(it) }
    }

    fun register(context: Context, endpoint: String, token: String) {
        require(URI(endpoint).scheme == "https")
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("endpoint", endpoint.trimEnd('/')).putString("token", token).apply()
    }

    fun reconcile(context: Context) {
        val epoch = generation
        scope.launch {
            if (epoch != generation) return@launch
            if (job?.isActive == true) return@launch
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            // A process killed during live mode must not retain that profile forever.
            if (prefs.getBoolean("temporary", false)) restore(context)
            val until = fetchExpiry(context) ?: return@launch
            if (epoch == generation && until > System.currentTimeMillis()) kick(context, until)
        }
    }

    fun kick(context: Context, until: Long) {
        if (until <= System.currentTimeMillis() || until > System.currentTimeMillis() + 60000) {
            Log.w("TrakkarLive", "activation_rejected reason=expiry_out_of_range")
            return
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getString("token", null) == null) {
            Log.w("TrakkarLive", "activation_rejected reason=not_registered")
            return
        }
        expiresAt = maxOf(expiresAt, until)
        if (job?.isActive == true) return
        val epoch = ++generation
        job = scope.launch {
            try {
                val tracker = sharedTracker() ?: run {
                    Log.w("TrakkarLive", "activation_rejected reason=tracker_unavailable")
                    return@launch
                }
                // Do not restart tracking that the person has stopped.
                if (!tracker.state.value.enabled) {
                    Log.w("TrakkarLive", "activation_rejected reason=tracking_disabled")
                    return@launch
                }
                val base = baseline(context) ?: run {
                    Log.w("TrakkarLive", "activation_rejected reason=baseline_missing")
                    return@launch
                }
                prefs.edit().putBoolean("temporary", true).commit()
                tracker.updateConfig(base.copy(location = base.location.copy(
                    accuracy = Accuracy.HIGH, distanceMeters = 0, intervalSeconds = 5,
                    angleDegrees = 0, stopDetection = false,
                )))
                Log.i("TrakkarLive", "live_profile_activated")
                while (isActive && epoch == generation && System.currentTimeMillis() < expiresAt) {
                    val remaining = expiresAt - System.currentTimeMillis()
                    delay(minOf(10000L, remaining).coerceAtLeast(1))
                    // Failures do not extend the old lease. Server cancellation shortens it.
                    fetchExpiry(context)?.let { expiresAt = it }
                }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                Log.w("TrakkarLive", "live_profile_failed")
            } finally {
                if (epoch == generation) withContext(NonCancellable) { restore(context) }
            }
        }
    }

    suspend fun pause(context: Context) {
        generation++
        job?.cancelAndJoin()
        job = null
        restore(context)
    }

    suspend fun clear(context: Context) {
        pause(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().commit()
    }

    private suspend fun restore(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("temporary", false)) return
        val base = baseline(context) ?: return
        try {
            sharedTracker()?.updateConfig(base)
            prefs.edit().putBoolean("temporary", false).commit()
            Log.i("TrakkarLive", "baseline_restored")
        } catch (_: Exception) { /* retry on next process launch */ }
        expiresAt = 0
    }

    private fun baseline(context: Context): Config? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("baseline", null) ?: return null
        val data = JSONObject(raw)
        return Config(serverUrl = data.getString("serverUrl"), deviceId = data.getString("deviceId"),
            location = LocationConfig(accuracy = Accuracy.MEDIUM, distanceMeters = 100, intervalSeconds = 600, stopTimeoutSeconds = 120),
            buffer = true, notification = NotificationConfig(text = "Trakkar is sharing your location"))
    }

    private suspend fun fetchExpiry(context: Context): Long? = withContext(Dispatchers.IO) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val endpoint = prefs.getString("endpoint", null) ?: return@withContext null
        val token = prefs.getString("token", null) ?: return@withContext null
        try {
            val connection = URI("$endpoint/v1/device-session").toURL().openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = 3000
                connection.readTimeout = 3000
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("Authorization", "Bearer $token")
                if (connection.responseCode != 200) return@withContext 0L
                val value = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
                // Calculate remaining time against the server clock, clamp to a bounded lease.
                val remaining = (value.getLong("expiresAt") - value.getLong("serverTime")).coerceIn(0, 30000)
                System.currentTimeMillis() + remaining
            } finally { connection.disconnect() }
        } catch (_: Exception) { null }
    }
}
