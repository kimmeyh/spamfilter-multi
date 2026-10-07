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

    /** At most one triggered scan per this many milliseconds (F253 R-5). */
    const val MIN_GAP_MS: Long = 2 * 60 * 1000L

    fun shouldTrigger(
        packageName: String?,
        enabled: Boolean,
        nowMs: Long,
        lastTriggerMs: Long,
    ): Boolean {
        if (!enabled) return false
        if (packageName == null || packageName !in MAIL_APP_PACKAGES) return false
        // A clock that moved backwards must not block triggering forever.
        if (lastTriggerMs > nowMs) return true
        return nowMs - lastTriggerMs >= MIN_GAP_MS
    }
}
