package com.oneupbyte.trakkar.live

import android.content.Context
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

    fun configure(context: Context, arguments: Map<*, *>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString("baseline", JSONObject(arguments).toString()).apply()
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
        if (until <= System.currentTimeMillis() || until > System.currentTimeMillis() + 60000) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getString("token", null) == null) return
        expiresAt = maxOf(expiresAt, until)
        if (job?.isActive == true) return
        val epoch = ++generation
        job = scope.launch {
            try {
                val tracker = sharedTracker() ?: return@launch
                // Do not restart tracking that the person has stopped.
                if (!tracker.state.value.enabled) return@launch
                val base = baseline(context) ?: return@launch
                prefs.edit().putBoolean("temporary", true).commit()
                tracker.updateConfig(base.copy(location = base.location.copy(
                    accuracy = Accuracy.HIGH, distanceMeters = 0, intervalSeconds = 5,
                    angleDegrees = 0, stopDetection = false,
                )))
                while (isActive && epoch == generation && System.currentTimeMillis() < expiresAt) {
                    val remaining = expiresAt - System.currentTimeMillis()
                    delay(minOf(10000L, remaining).coerceAtLeast(1))
                    // Failures do not extend the old lease. Server cancellation shortens it.
                    fetchExpiry(context)?.let { expiresAt = it }
                }
            } catch (_: Exception) {
                // Ordinary tracking continues; no credential or location logging.
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
        } catch (_: Exception) { /* retry on next process launch */ }
        expiresAt = 0
    }

    private fun baseline(context: Context): Config? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("baseline", null) ?: return null
        val data = JSONObject(raw)
        return Config(serverUrl = data.getString("serverUrl"), deviceId = data.getString("deviceId"),
            location = LocationConfig(accuracy = Accuracy.HIGH, distanceMeters = 75, intervalSeconds = 300),
            buffer = true)
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
