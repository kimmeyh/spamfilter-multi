package com.myemailspamfilter

import java.util.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F264 (Sprint 77 Q13): start-time jitter for the Doze alarm -- up to 5
 * minutes either way, only for intervals over 15 minutes.
 *
 * What this does NOT catch: [DozeAlarmScheduler.schedule] actually adding the
 * offset to the trigger time (a one-line call site; pinned by a Dart source
 * gate and by the mutation run), or Android honoring the alarm time.
 */
class AlarmJitterTest {
    private val fiveMinutesMs = 5 * 60_000L

    @Test
    fun noJitterAtOrBelowFifteenMinutes() {
        val rnd = Random(1)
        for (minutes in listOf(1, 5, 14, 15)) {
            repeat(200) {
                assertEquals(0L, AlarmJitter.offsetMs(minutes, rnd))
            }
        }
    }

    @Test
    fun jitterStaysWithinFiveMinutesEitherWayAboveFifteen() {
        val rnd = Random(2)
        for (minutes in listOf(16, 30, 120, 5940)) {
            repeat(2_000) {
                val off = AlarmJitter.offsetMs(minutes, rnd)
                assertTrue("offset $off out of range", off >= -fiveMinutesMs && off <= fiveMinutesMs)
            }
        }
    }

    @Test
    fun jitterGoesBothWaysAndIsNotConstant() {
        val rnd = Random(3)
        val offsets = (1..2_000).map { AlarmJitter.offsetMs(30, rnd) }
        assertTrue("never early", offsets.any { it < 0 })
        assertTrue("never late", offsets.any { it > 0 })
        assertTrue("constant", offsets.toSet().size > 100)
    }

    @Test
    fun theConstantsMatchTheDocumentedRule() {
        assertEquals(15, AlarmJitter.THRESHOLD_MINUTES)
        assertEquals(5, AlarmJitter.JITTER_MINUTES)
    }
}
