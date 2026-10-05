package com.myemailspamfilter

import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * F253 (Sprint 76): start a background scan when a mail app posts a
 * notification -- the mail app's own "new mail" signal.
 *
 * Harold, 2026-10-05: a notification only says mail arrived; the scan it
 * starts covers every selected folder of every background-enabled account
 * (the worker's normal all-accounts path), Bulk included.
 *
 * **Privacy (R-3) -- the whole contract of this class**: it reads ONLY
 * [StatusBarNotification.getPackageName] and [StatusBarNotification.getPostTime].
 * It never reads the notification itself (title, text, extras), never stores
 * anything from it, and ignores every app not in
 * [MailNotificationPolicy.MAIL_APP_PACKAGES]. Pinned by a source gate.
 *
 * Off unless BOTH the user granted Notification access in Android settings
 * AND turned on Settings > "Scan when new mail arrives" (the flag in
 * [PREFS]); with the flag off this ignores everything even while access is
 * still granted.
 *
 * ADR-0042: Android only (declared exception) -- see ADR-0044.
 */
class MailNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName
        val postedAt = sbn.postTime
        try {
            val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val decide = MailNotificationPolicy.shouldTrigger(
                packageName = pkg,
                enabled = prefs.getBoolean(KEY_ENABLED, false),
                nowMs = now,
                lastTriggerMs = prefs.getLong(KEY_LAST_TRIGGER_MS, 0L),
            )
            if (!decide) return

            prefs.edit().putLong(KEY_LAST_TRIGGER_MS, now).apply()
            DozeScanTrigger.enqueueAllAccounts(
                applicationContext,
                source = SOURCE_NOTIFICATION,
                triggerAtMs = postedAt,
                sourceApp = pkg,
            )
        } catch (t: Throwable) {
            // Never crash the listener: Android unbinds a crashing listener and
            // the user would have to re-grant access.
            Log.e(TAG, "trigger failed: ${t.message}")
        }
    }

    companion object {
        private const val TAG = "MailNotificationListener"
        const val PREFS = "f253_new_mail_trigger"
        const val KEY_ENABLED = "enabled"
        const val KEY_LAST_TRIGGER_MS = "last_trigger_ms"
        const val SOURCE_NOTIFICATION = "notification"
    }
}
