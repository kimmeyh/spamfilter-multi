package com.myemailspamfilter

/**
 * F253 (Sprint 76): the decision "should this posted notification start a
 * scan?", as a PURE function so it runs in a JVM unit test with no device.
 *
 * Inputs are deliberately minimal -- the posting app's package name and times.
 * The listener never reads a notification's title, text or extras (F253 R-3);
 * nothing here could use them even if it did.
 */
object MailNotificationPolicy {
    /**
     * Mail apps whose notifications mean "new mail arrived". Package names
     * as published on Google Play; extend here only.
     *
     * Unverified until the Fold validation: the AOL and Yahoo package names
     * (from their Play listings, not checked on a device this sprint).
     */
    val MAIL_APP_PACKAGES: Set<String> = setOf(
        "com.google.android.gm",                   // Gmail
        "com.aol.mobile.aolapp",                   // AOL
        "com.yahoo.mobile.client.android.mail",    // Yahoo Mail
        "com.samsung.android.email.provider",      // Samsung Email
        "com.microsoft.office.outlook",            // Outlook
    )

    /**
     * DEBUG-BUILD-ONLY posters (Sprint 77 R76-1, Harold Q15 = 1). `adb shell
     * cmd notification post` posts as the shell package, which lets an
     * emulator drive the listener with no mail app installed. Accepted ONLY
     * when [shouldTrigger] is called with debugBuild = true, and the listener
     * passes BuildConfig.DEBUG, so a release build never accepts it. Never add
     * an entry to [MAIL_APP_PACKAGES] for testing; add it here. Pinned by
     * MailNotificationPolicyTest and test/policy/debug_allowlist_gate_test.dart.
     */
    val DEBUG_ONLY_PACKAGES: Set<String> = setOf(
        "com.android.shell",                       // adb shell cmd notification post
    )

    /** The packages accepted for a build: the release list, plus the debug-only list in a debug build. */
    fun allowedPackages(debugBuild: Boolean): Set<String> =
        if (debugBuild) MAIL_APP_PACKAGES + DEBUG_ONLY_PACKAGES else MAIL_APP_PACKAGES

    /** At most one triggered scan per this many milliseconds (F253 R-5). */
    const val MIN_GAP_MS: Long = 2 * 60 * 1000L

    fun shouldTrigger(
        packageName: String?,
        enabled: Boolean,
        nowMs: Long,
        lastTriggerMs: Long,
        debugBuild: Boolean = false,
    ): Boolean {
        if (!enabled) return false
        if (packageName == null || packageName !in allowedPackages(debugBuild)) return false
        // A clock that moved backwards must not block triggering forever.
        if (lastTriggerMs > nowMs) return true
        return nowMs - lastTriggerMs >= MIN_GAP_MS
    }
}
