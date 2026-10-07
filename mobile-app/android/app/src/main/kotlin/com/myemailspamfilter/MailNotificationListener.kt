package com.myemailspamfilter

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * F253 (Sprint 76): start a background scan when a mail app posts a
 * notification -- the mail app's own "new mail" signal.
 *
 * Harold, 2026-10-05: a notification only says mail arrived; the scan it
 * starts covers every selected folder (Bulk included) of the accounts it can
 * be about. F264 (Sprint 77): the switch is per ACCOUNT and lives in the app
 * database; this listener cannot read it, so it gates on ONE native "any
 * account has it on" flag ([KEY_ENABLED]) and hands the Dart worker the
 * providers the posting app maps to ([MailNotificationPolicy.providersFor]);
 * the worker selects the accounts (provider + the account's own switch + its
 * background switch).
 *
 * **Privacy (R-3) -- the whole contract of this class**: it reads ONLY
 * [StatusBarNotification.getPackageName] and [StatusBarNotification.getPostTime].
 * It never reads the notification itself (title, text, extras), never stores
 * anything from it, and ignores every app not in
 * [MailNotificationPolicy.MAIL_APP_PACKAGES]. Pinned by a source gate.
 *
 * Off unless BOTH the user granted Notification access in Android settings
 * AND turned on Settings > "Scan when new mail arrives" (the flag in
 * [PREFS]). Turning the switch off also DISABLES this component (review M-2),
 * so Android stops binding it and the app is no longer woken for every
 * notification on the phone.
 *
 * **Outcome record (review HIGH-3)**: adb is unavailable on the test phones
 * and the diagnostic log has no Kotlin writer, so the last trigger's outcome is
 * kept in [PREFS] ([KEY_LAST_RESULT]) for Settings and the diagnostic log to
 * show.
 *
 * ADR-0042: Android only (declared exception) -- see ADR-0044.
 */
class MailNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName
        val postedAt = sbn.postTime
        val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        try {
            val now = System.currentTimeMillis()
            val decide = MailNotificationPolicy.shouldTrigger(
                packageName = pkg,
                enabled = prefs.getBoolean(KEY_ENABLED, false),
                nowMs = now,
                lastTriggerMs = prefs.getLong(KEY_LAST_TRIGGER_MS, 0L),
                debugBuild = BuildConfig.DEBUG,
            )
            if (!decide) return

            DozeScanTrigger.enqueueAllAccounts(
                applicationContext,
                source = SOURCE_NOTIFICATION,
                triggerAtMs = postedAt,
                sourceApp = pkg,
                // F264: which providers' accounts this app can be about; the
                // Dart worker picks accounts from it. Derived from the package
                // name only -- never from the notification's content.
                providers = MailNotificationPolicy.encodeProviders(pkg, debugBuild = BuildConfig.DEBUG),
            )
            // AFTER a successful enqueue (review HIGH-3): a failed enqueue must
            // not use up the 2-minute throttle.
            prefs.edit()
                .putLong(KEY_LAST_TRIGGER_MS, now)
                .putString(KEY_LAST_RESULT, "$now|requested a scan after a $pkg notification")
                .apply()
        } catch (t: Throwable) {
            // Never crash the listener: Android unbinds a crashing listener and
            // the user would have to re-grant access. Recorded, not swallowed.
            val what = "${t.javaClass.simpleName}: ${t.message}"
            Log.e(TAG, "trigger failed: $what")
            prefs.edit()
                .putString(KEY_LAST_RESULT, "${System.currentTimeMillis()}|FAILED: $what")
                .apply()
        }
    }

    companion object {
        private const val TAG = "MailNotificationListener"
        const val PREFS = "f253_new_mail_trigger"
        const val KEY_ENABLED = "enabled"
        const val KEY_LAST_TRIGGER_MS = "last_trigger_ms"
        /** "<epoch ms>|<outcome>" of the most recent trigger attempt. */
        const val KEY_LAST_RESULT = "last_result"
        const val SOURCE_NOTIFICATION = "notification"

        /**
         * Turn the feature on or off natively: the flag the listener reads, the
         * component itself (so Android binds it only while on), and -- when
         * turning off -- any queued new-mail scan.
         */
        fun applyEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_ENABLED, enabled).apply()
            val component = ComponentName(context, MailNotificationListener::class.java)
            context.packageManager.setComponentEnabledSetting(
                component,
                if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
            if (enabled) {
                // Ask Android to bind it again after it was disabled.
                requestRebind(component)
            } else {
                DozeScanTrigger.cancelNewMailScan(context)
            }
        }
    }
}
