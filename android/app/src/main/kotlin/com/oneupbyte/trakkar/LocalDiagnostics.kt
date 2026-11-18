package com.oneupbyte.trakkar

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.util.AtomicFile
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.atomic.AtomicBoolean

internal object LocalDiagnostics {
    private const val RETENTION_MS = 7 * 24 * 60 * 60 * 1000L
    private val savingCrash = AtomicBoolean(false)

    fun directory(context: Context) = File(context.cacheDir, "trakkar-diagnostics")

    fun install(context: Context) {
        val previous = Thread.getDefaultUncaughtExceptionHandler() ?: return
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                if (!savingCrash.compareAndSet(false, true)) return@setDefaultUncaughtExceptionHandler
                val report = buildString {
                    appendLine("Android uncaught exception at ${timestamp(System.currentTimeMillis())}")
                    appendLine(error.javaClass.name)
                    error.stackTrace.take(32).forEach { frame ->
                        // Exception messages and process dumps can contain personal data.
                        appendLine("at ${frame.className.take(256)}.${frame.methodName.take(128)}:${frame.lineNumber}")
                    }
                }
                val directory = directory(context)
                directory.mkdirs()
                val file = AtomicFile(File(directory, "android-crash.log"))
                val stream = file.startWrite()
                try {
                    stream.write(report.toByteArray(Charsets.UTF_8))
                    file.finishWrite(stream)
                } catch (failure: Exception) {
                    file.failWrite(stream)
                }
            } catch (_: Exception) {
                // Preserve the system's crash handling even if the cache cannot be written.
            } finally {
                previous.uncaughtException(thread, error)
            }
        }
    }

    fun clean(context: Context) {
        val crash = File(directory(context), "android-crash.log")
        if (expired(crash)) AtomicFile(crash).delete()
        // Share Plus copies Android attachments before granting the recipient access.
        val shared = File(context.cacheDir, "share_plus/trakkar-diagnostics.txt")
        if (expired(shared)) shared.delete()
    }

    fun report(context: Context): String = buildString {
        clean(context)
        val file = File(directory(context), "android-crash.log")
        if (file.isFile) appendLine(file.readText())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val manager = context.getSystemService(ActivityManager::class.java) ?: return@buildString
            for (exit in manager.getHistoricalProcessExitReasons(context.packageName, 0, 12)) {
                if (System.currentTimeMillis() - exit.timestamp > RETENTION_MS) continue
                val reason = when (exit.reason) {
                    ApplicationExitInfo.REASON_CRASH -> "uncaught exception"
                    ApplicationExitInfo.REASON_CRASH_NATIVE -> "native crash"
                    ApplicationExitInfo.REASON_ANR -> "app not responding"
                    ApplicationExitInfo.REASON_LOW_MEMORY -> "low memory"
                    else -> continue
                }
                appendLine("Android process exit at ${timestamp(exit.timestamp)}: $reason (status ${exit.status})")
            }
        }
    }

    private fun expired(file: File): Boolean {
        val modified = file.lastModified()
        return modified != 0L && System.currentTimeMillis() - modified > RETENTION_MS
    }

    private fun timestamp(milliseconds: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(milliseconds))
}
