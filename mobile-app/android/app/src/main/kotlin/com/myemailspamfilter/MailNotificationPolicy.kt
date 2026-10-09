package com.myemailspamfilter

/**
 * F253 (Sprint 76): the decision "should this posted notification start a
 * scan?", as a PURE function so it runs in a JVM unit test with no device.
 *
 * F264 (Sprint 77): the same table now also says WHICH providers' accounts a
 * mail app's notification can be about ([providersFor]).
 *
 * Inputs are deliberately minimal -- the posting app's package name and times.
 * The listener never reads a notification's title, text or extras (F253 R-3);
 * nothing here could use them even if it did.
 */
object MailNotificationPolicy {
    /**
     * The payload value meaning "every provider". Must match `kAnyProvider` in
     * `lib/core/services/notification_account_filter.dart`.
     */
    const val ANY_PROVIDER = "*"

    private const val GMAIL = "gmail"
    private const val AOL = "aol"
    private const val YAHOO = "yahoo"

    /**
     * Mail apps whose notifications mean "new mail arrived", each with the
     * providers whose accounts it can be about (Harold, Sprint 77): the Gmail
     * app is about Gmail accounts, the AOL app about AOL accounts, Yahoo Mail
     * about Yahoo accounts, and Samsung Email and Outlook can show ANY account
     * (null = every provider). Package names as published on Google Play;
     * extend here only -- the Dart side reads the resolved set from the work
     * payload and keeps no copy of this table.
     *
     * Unverified until the Fold validation: the AOL and Yahoo package names
     * (from their Play listings, not checked on a device this sprint).
     */
    private val MAIL_APPS: Map<String, Set<String>?> = mapOf(
        "com.google.android.gm" to setOf(GMAIL),                  // Gmail
        "com.aol.mobile.aolapp" to setOf(AOL),                    // AOL
        "com.yahoo.mobile.client.android.mail" to setOf(YAHOO),   // Yahoo Mail
        "com.samsung.android.email.provider" to null,             // Samsung Email
        "com.microsoft.office.outlook" to null,                   // Outlook
    )

    val MAIL_APP_PACKAGES: Set<String> = MAIL_APPS.keys

    /**
     * DEBUG-BUILD-ONLY posters (Sprint 77 R76-1, Harold Q15 = 1), each with the
     * providers it stands in for. `adb shell cmd notification post` posts as
     * the shell package, which lets an emulator drive the listener with no mail
     * app installed; it stands in for the AOL app so the emulator's fake AOL
     * account exercises the per-account mapping (R76-1 arms 3-6). Accepted ONLY
     * when called with debugBuild = true, and the listener passes
     * BuildConfig.DEBUG, so a release build never accepts or maps it. Never add
     * an entry to [MAIL_APPS] for testing; add it here. Pinned by
     * MailNotificationPolicyTest and test/policy/debug_allowlist_gate_test.dart.
     */
    private val DEBUG_ONLY_APPS: Map<String, Set<String>?> = mapOf(
        "com.android.shell" to setOf(AOL),         // adb shell cmd notification post
    )

    val DEBUG_ONLY_PACKAGES: Set<String> = DEBUG_ONLY_APPS.keys

    /** The packages accepted for a build: the release list, plus the debug-only list in a debug build. */
    fun allowedPackages(debugBuild: Boolean): Set<String> =
        if (debugBuild) MAIL_APP_PACKAGES + DEBUG_ONLY_PACKAGES else MAIL_APP_PACKAGES

    /**
     * The providers whose accounts a notification from [packageName] can be
     * about: a set of provider names, null for "every provider", or an EMPTY
     * set for a package that is not a mail app. A debug-only poster maps only
     * in a debug build (lead merge, Sprint 77: without this the R76-1 shell
     * notifications would be accepted by [shouldTrigger] and then scan NO
     * account under F264's per-account selection).
     */
    fun providersFor(packageName: String?, debugBuild: Boolean = false): Set<String>? {
        if (packageName == null) return emptySet()
        if (packageName in MAIL_APPS) return MAIL_APPS[packageName]
        if (debugBuild && packageName in DEBUG_ONLY_APPS) return DEBUG_ONLY_APPS[packageName]
        return emptySet()
    }

    /**
     * [providersFor] as the string the work payload carries: "gmail", "*" for
     * every provider, or "" for none. Comma separated if a package ever maps
     * to several.
     */
    fun encodeProviders(packageName: String?, debugBuild: Boolean = false): String {
        val providers = providersFor(packageName, debugBuild) ?: return ANY_PROVIDER
        return providers.sorted().joinToString(",")
    }

    /** At most one triggered scan per this many milliseconds (F253 R-5). */
    const val MIN_GAP_MS: Long = 2 * 60 * 1000L

    /**
     * [enabled] is the native "any account has the switch on" flag (F264): the
     * per-account switches live in the app database, which this listener cannot
     * read, so it gates on the single flag and the Dart worker selects accounts.
     */
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

    /**
     * Sprint 77 Phase 5.1.2 F-PRECHECK: the throttle and the queued work are
     * kept PER PROVIDER SET. Since F264 a run scans only the accounts of the
     * posting app's providers, but the 2-minute throttle and the WorkManager
     * unique work (KEEP) were still single, app-wide slots: an AOL
     * notification within 2 minutes of a Gmail one, or while the Gmail run was
     * still queued, was DROPPED and the AOL account was not scanned. Keyed by
     * the encoded provider set, different providers never block each other,
     * and the same provider still respects the 2-minute gap and KEEP.
     *
     * [key] is the encoded set ([encodeProviders]) with "*" spelled "any".
     */
    fun providerKey(providers: String): String =
        if (providers == ANY_PROVIDER) "any" else providers

    /** SharedPreferences key holding the last trigger time for [providers]. */
    fun throttlePrefKey(providers: String): String = "last_trigger_ms_${providerKey(providers)}"

    /** Tag on every new-mail work request, so turning the feature off cancels all of them. */
    const val NEW_MAIL_WORK_TAG = "f253_new_mail_scan"

    /** WorkManager unique work name for [providers] (KEEP applies within one set only). */
    fun newMailWorkName(providers: String): String = "${NEW_MAIL_WORK_TAG}_${providerKey(providers)}"

    /** What the listener does for one accepted notification. */
    data class NewMailTrigger(
        val providers: String,
        val throttlePrefKey: String,
        val workName: String,
    )

    /**
     * The whole listener decision as one pure function, so the per-provider
     * wiring is JVM-tested: null to ignore the notification, otherwise the
     * provider set, the throttle key to read and stamp, and the work name.
     * [lastTriggerMsFor] reads a throttle key (0 when never stamped).
     */
    fun decide(
        packageName: String?,
        enabled: Boolean,
        nowMs: Long,
        lastTriggerMsFor: (String) -> Long,
        debugBuild: Boolean = false,
    ): NewMailTrigger? {
        val providers = encodeProviders(packageName, debugBuild)
        val key = throttlePrefKey(providers)
        val ok = shouldTrigger(
            packageName = packageName,
            enabled = enabled,
            nowMs = nowMs,
            lastTriggerMs = lastTriggerMsFor(key),
            debugBuild = debugBuild,
        )
        if (!ok || providers.isEmpty()) return null
        return NewMailTrigger(providers, key, newMailWorkName(providers))
    }
}
