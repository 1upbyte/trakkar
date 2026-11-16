package com.oneupbyte.trakkar.live

/** Translate a server-relative lease into a bounded monotonic deadline. */
internal object LiveTrackingLease {
    fun deadline(expiresAt: Long, serverTime: Long, elapsedRealtime: Long): Long {
        val remaining = (expiresAt - serverTime).coerceIn(0, 30000)
        return elapsedRealtime + remaining
    }
}
