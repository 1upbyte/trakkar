package com.oneupbyte.trakkar.live

import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.Test

class ForegroundServiceGateTest {
    @Test
    fun configurationCannotContinueWhileForegroundStartupIsPending() = runBlocking {
        var foreground = false
        var configurationApplied = false
        val ready = CompletableDeferred<Unit>()
        val job = launch(start = CoroutineStart.UNDISPATCHED) {
            awaitForegroundService(ready = { foreground }, poll = { ready.await() })
            configurationApplied = true
        }
        assertFalse(configurationApplied)
        foreground = true
        ready.complete(Unit)
        job.join()
        assertTrue(configurationApplied)
    }

    @Test
    fun readyServiceDoesNotNeedAnArtificialDelay() = runBlocking {
        awaitForegroundService(ready = { true }, poll = { fail("Already foreground") })
    }

    @Test
    fun timeoutFailsBeforeConfigurationCanContinue() = runBlocking {
        var polls = 0
        try {
            awaitForegroundService(ready = { false }, poll = { polls++ })
            fail("A service that never enters foreground must not be rebuilt")
        } catch (_: IllegalStateException) {
            assertEquals(100, polls)
        }
    }

    @Test
    fun cancellingAPendingTransitionPreventsConfiguration() = runBlocking {
        var configurationApplied = false
        val job = launch(start = CoroutineStart.UNDISPATCHED) {
            awaitForegroundService(ready = { false }, poll = { awaitCancellation() })
            configurationApplied = true
        }
        job.cancelAndJoin()
        assertFalse(configurationApplied)
    }
}
