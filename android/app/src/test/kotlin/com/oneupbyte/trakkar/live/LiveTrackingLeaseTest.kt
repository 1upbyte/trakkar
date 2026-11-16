package com.oneupbyte.trakkar.live

import org.junit.Assert.assertEquals
import org.junit.Test

class LiveTrackingLeaseTest {
    @Test
    fun serverClockOffsetDoesNotChangeTheLocalDeadline() {
        // Phones may be minutes or days ahead of or behind the server.
        for (offset in listOf(-86400000L, -60000L, 0L, 60000L, 86400000L)) {
            assertEquals(45000L, LiveTrackingLease.deadline(1030000L + offset, 1000000L + offset, 15000L))
        }
    }

    @Test
    fun expiredAndReleasedSessionsCannotActivateTracking() {
        assertEquals(15000L, LiveTrackingLease.deadline(999999L, 1000000L, 15000L))
        assertEquals(15000L, LiveTrackingLease.deadline(1000000L, 1000000L, 15000L))
        assertEquals(15000L, LiveTrackingLease.deadline(0L, 1000000L, 15000L))
    }

    @Test
    fun excessiveLeasesAreLimitedToThirtySeconds() {
        assertEquals(45000L, LiveTrackingLease.deadline(2000000L, 1000000L, 15000L))
    }

    @Test
    fun delayedDeliveryUsesOnlyTheTimeRemainingOnTheServer() {
        assertEquals(20000L, LiveTrackingLease.deadline(1030000L, 1025000L, 15000L))
    }
}
