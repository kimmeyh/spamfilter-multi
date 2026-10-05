package com.myemailspamfilter

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F253 T-1 (AC-1, AC-2, AC-3): the notification-to-scan decision.
 *
 * What this does NOT catch: whether Android binds the listener and delivers
 * notifications on a real phone, or the mail apps' real package names -- both
 * are Fold validation (AC-5).
 */
class MailNotificationPolicyTest {
    private val gmail = "com.google.android.gm"
    private val now = 10_000_000L

    @Test
    fun aMailAppTriggers() {
        assertTrue(MailNotificationPolicy.shouldTrigger(gmail, true, now, 0L))
    }

    @Test
    fun anyOtherAppDoesNot() {
        assertFalse(MailNotificationPolicy.shouldTrigger("com.whatsapp", true, now, 0L))
        assertFalse(MailNotificationPolicy.shouldTrigger(null, true, now, 0L))
    }

    @Test
    fun theSwitchOffBlocksEvenAMailApp() {
        assertFalse(MailNotificationPolicy.shouldTrigger(gmail, false, now, 0L))
    }

    @Test
    fun aBurstCollapsesToOneScanWithinTwoMinutes() {
        // Five notifications in 10 seconds after a trigger: none re-trigger.
        for (i in 1..5) {
            assertFalse(
                MailNotificationPolicy.shouldTrigger(gmail, true, now + i * 2_000L, now)
            )
        }
        assertTrue(
            MailNotificationPolicy.shouldTrigger(
                gmail, true, now + MailNotificationPolicy.MIN_GAP_MS, now
            )
        )
    }

    @Test
    fun aClockMovedBackwardsDoesNotBlockForever() {
        assertTrue(MailNotificationPolicy.shouldTrigger(gmail, true, now, now + 60_000L))
    }
}
