package com.myemailspamfilter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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

    // Sprint 77 R76-1 (Issue #464): the debug-only poster must never reach a release build.
    @Test
    fun theReleaseAllowlistNeverContainsTheDebugPackages() {
        assertTrue(MailNotificationPolicy.DEBUG_ONLY_PACKAGES.isNotEmpty())
        for (p in MailNotificationPolicy.DEBUG_ONLY_PACKAGES) {
            assertFalse(p in MailNotificationPolicy.MAIL_APP_PACKAGES)
            assertFalse(p in MailNotificationPolicy.allowedPackages(false))
            assertFalse(MailNotificationPolicy.shouldTrigger(p, true, now, 0L))
            assertFalse(MailNotificationPolicy.shouldTrigger(p, true, now, 0L, debugBuild = false))
        }
    }

    @Test
    fun aDebugBuildAcceptsTheDebugPackageAndStillTheReleaseOnes() {
        for (p in MailNotificationPolicy.DEBUG_ONLY_PACKAGES) {
            assertTrue(MailNotificationPolicy.shouldTrigger(p, true, now, 0L, debugBuild = true))
        }
        assertTrue(MailNotificationPolicy.shouldTrigger(gmail, true, now, 0L, debugBuild = true))
    }

    @Test
    fun aClockMovedBackwardsDoesNotBlockForever() {
        assertTrue(MailNotificationPolicy.shouldTrigger(gmail, true, now, now + 60_000L))
    }

    // ---- F264 (Sprint 77): which providers' accounts each app can be about ----

    @Test
    fun theGmailAppMapsToGmailAccounts() {
        assertEquals(setOf("gmail"), MailNotificationPolicy.providersFor(gmail))
    }

    @Test
    fun theAolAndYahooAppsMapToTheirOwnAccounts() {
        assertEquals(
            setOf("aol"),
            MailNotificationPolicy.providersFor("com.aol.mobile.aolapp")
        )
        assertEquals(
            setOf("yahoo"),
            MailNotificationPolicy.providersFor("com.yahoo.mobile.client.android.mail")
        )
    }

    @Test
    fun samsungEmailAndOutlookMapToEveryProvider() {
        // null = every provider
        assertNull(MailNotificationPolicy.providersFor("com.samsung.android.email.provider"))
        assertNull(MailNotificationPolicy.providersFor("com.microsoft.office.outlook"))
    }

    @Test
    fun anUnknownPackageMapsToNoProvider() {
        assertEquals(emptySet<String>(), MailNotificationPolicy.providersFor("com.whatsapp"))
        assertEquals(emptySet<String>(), MailNotificationPolicy.providersFor(null))
    }

    @Test
    fun theWorkPayloadEncodingIsWhatTheDartWorkerReads() {
        assertEquals("gmail", MailNotificationPolicy.encodeProviders(gmail))
        assertEquals("aol", MailNotificationPolicy.encodeProviders("com.aol.mobile.aolapp"))
        assertEquals(
            MailNotificationPolicy.ANY_PROVIDER,
            MailNotificationPolicy.encodeProviders("com.microsoft.office.outlook")
        )
        assertEquals("", MailNotificationPolicy.encodeProviders("com.whatsapp"))
    }

    @Test
    fun everyAllowlistedPackageHasAMapping() {
        // The two views of the table cannot drift: a package is a mail app
        // exactly when it has a mapping entry.
        for (pkg in MailNotificationPolicy.MAIL_APP_PACKAGES) {
            val providers = MailNotificationPolicy.providersFor(pkg)
            assertTrue(providers == null || providers.isNotEmpty())
        }
        assertEquals(5, MailNotificationPolicy.MAIL_APP_PACKAGES.size)
    }

    // Lead merge (Sprint 77): R76-1's debug-only poster must MAP in a debug
    // build (else F264 accepts its notification and scans no account) and
    // must map to NOTHING in release. What this does NOT catch: the listener
    // passing a literal instead of BuildConfig.DEBUG (the Dart source gate does).
    @Test
    fun theDebugOnlyPosterMapsOnlyInADebugBuild() {
        val shell = "com.android.shell"
        assertEquals(setOf("aol"), MailNotificationPolicy.providersFor(shell, debugBuild = true))
        assertEquals("aol", MailNotificationPolicy.encodeProviders(shell, debugBuild = true))
        assertEquals(emptySet<String>(), MailNotificationPolicy.providersFor(shell))
        assertEquals("", MailNotificationPolicy.encodeProviders(shell, debugBuild = false))
    }

    /**
     * Sprint 77 Phase 5.1.2 F-PRECHECK: one app-wide throttle and one unique
     * work name dropped an AOL notification within 2 minutes of a Gmail one.
     * Drives [MailNotificationPolicy.decide] the way the listener does, with a
     * map standing in for SharedPreferences.
     *
     * What this does NOT catch: the listener stamping the key decide()
     * returned (a Dart source gate pins that line), or WorkManager honoring
     * KEEP per unique name (device behavior).
     */
    @Test
    fun differentProvidersNeverBlockEachOtherAndTheSameProviderStillWaits() {
        val prefs = mutableMapOf<String, Long>()
        fun fire(pkg: String, at: Long): MailNotificationPolicy.NewMailTrigger? {
            val t = MailNotificationPolicy.decide(pkg, true, at, { prefs[it] ?: 0L })
            if (t != null) prefs[t.throttlePrefKey] = at
            return t
        }
        val aol = "com.aol.mobile.aolapp"
        val outlook = "com.microsoft.office.outlook"

        val g = fire(gmail, now)!!
        val a = fire(aol, now + 30_000L)
        assertTrue("AOL 30 s after Gmail must still trigger", a != null)
        assertTrue(g.workName != a!!.workName)
        assertTrue(g.throttlePrefKey != a.throttlePrefKey)
        assertEquals("gmail", g.providers)
        assertEquals("aol", a.providers)

        assertNull("Gmail again within 2 minutes is throttled", fire(gmail, now + 60_000L))
        assertTrue(fire(gmail, now + MailNotificationPolicy.MIN_GAP_MS) != null)

        val any = fire(outlook, now + 1_000L)!!
        assertEquals(MailNotificationPolicy.ANY_PROVIDER, any.providers)
        assertEquals("f253_new_mail_scan_any", any.workName)
        assertEquals("last_trigger_ms_any", any.throttlePrefKey)
    }

    @Test
    fun workNamesAndThrottleKeysAreStablePerProviderSet() {
        assertEquals("f253_new_mail_scan_gmail", MailNotificationPolicy.newMailWorkName("gmail"))
        assertEquals(
            MailNotificationPolicy.newMailWorkName("aol"),
            MailNotificationPolicy.newMailWorkName("aol"),
        )
        assertEquals("last_trigger_ms_aol", MailNotificationPolicy.throttlePrefKey("aol"))
        assertTrue(
            MailNotificationPolicy.newMailWorkName("gmail")
                .startsWith(MailNotificationPolicy.NEW_MAIL_WORK_TAG)
        )
        assertNull(MailNotificationPolicy.decide("com.whatsapp", true, now, { 0L }))
        assertNull(MailNotificationPolicy.decide(gmail, false, now, { 0L }))
    }

    @Test
    fun theTriggerGapAndEnabledRulesAreUnchangedByTheMapping() {
        assertFalse(MailNotificationPolicy.shouldTrigger(gmail, false, now, 0L))
        assertFalse(MailNotificationPolicy.shouldTrigger(gmail, true, now + 1_000L, now))
        assertTrue(
            MailNotificationPolicy.shouldTrigger(
                gmail, true, now + MailNotificationPolicy.MIN_GAP_MS, now
            )
        )
    }
}
