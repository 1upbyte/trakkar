package com.oneupbyte.trakkar.live

import kotlinx.coroutines.delay

/** Never tear down a service between startForegroundService and startForeground. */
internal suspend fun awaitForegroundService(
    ready: () -> Boolean,
    poll: suspend () -> Unit = { delay(50) },
) {
    repeat(100) {
        if (ready()) return
        poll()
    }
    check(ready()) { "Tracking service has not entered the foreground" }
}
