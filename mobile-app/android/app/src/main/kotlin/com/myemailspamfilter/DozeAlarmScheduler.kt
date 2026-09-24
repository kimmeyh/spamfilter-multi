package com.myemailspamfilter

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.util.Log

/**
 * F235 (Sprint 73): fire background scans while the device is in Doze.
 *
 * WorkManager runs on JobScheduler, which Doze suspends, so the app's periodic
 * scans frequently did not fire at all while the phone was idle. Harold:
 * "background jobs only run when the app is open and in view. This completely
 * renders 'background' jobs as useless."
 *
 * **`setAndAllowWhileIdle` is used deliberately, not `setExactAndAllowWhileIdle`.**
 * The inexact variant fires in Doze with NO permission and no Google Play
 * policy exposure; both exact variants require SCHEDULE_EXACT_ALARM or
 * USE_EXACT_ALARM and carry a justification burden. Android's own guidance is
 * to use the inexact variant unless core functionality needs precise timing --
 * a spam filter does not. The cost is a delivery window of about an hour.
 *
 * **Two things an alarm does not do for free, both handled here:**
 *  - it does not repeat, so [onReceive] re-arms after every firing;
 *  - it does not survive a reboot, so [BootReceiver] restores the schedule.
 *
 * Without either, this would be a REGRESSION against WorkManager, whose work
 * is persisted. The Dart side keeps WorkManager registered as a safety net for
 * the same reason.
 */
object DozeAlarmScheduler {
    private const val TAG = "DozeAlarmScheduler"
    private const val PREFS = "f235_doze_alarms"
    private const val KEY_ACCOUNTS = "armed_accounts"
    private const val KEY_INTERVAL_PREFIX = "interval_"

    const val ACTION_SCAN = "com.myemailspamfilter.ACTION_DOZE_SCAN"
    const val EXTRA_ACCOUNT_ID = "accountId"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Stable request code per account.
     *
     * The SAME account must always produce the SAME code, or cancel() would
     * fail to find the pending intent and re-arming would stack duplicate
     * alarms -- waking the device more often the more times the user toggled
     * the setting.
     */
    private fun requestCodeFor(accountId: String): Int = accountId.hashCode()

    private fun intentFor(context: Context, accountId: String): PendingIntent {
        val intent = Intent(context, DozeAlarmReceiver::class.java).apply {
            action = ACTION_SCAN
            // PR #435 review I-7: the DATA URI is what makes this intent
            // distinct per account, NOT the extra.
            //
            // PendingIntent matching uses Intent.filterEquals, which compares
            // action, data, type, component and categories -- and IGNORES
            // EXTRAS. Without this line two accounts produce intents that
            // filterEquals considers identical, differing only by the
            // accountId extra. The request code alone was carrying that
            // burden, and `accountId.hashCode()` is STABLE (Java's String
            // hash is specified) but not UNIQUE: on a 32-bit collision
            // FLAG_UPDATE_CURRENT makes account B overwrite A's alarm, so A
            // silently stops scanning and cancel(A) cancels B.
            //
            // The scheme is arbitrary and never resolved -- it exists only to
            // give filterEquals something to distinguish.
            data = Uri.parse("f235://scan/" + Uri.encode(accountId))
            putExtra(EXTRA_ACCOUNT_ID, accountId)
        }
        // FLAG_IMMUTABLE is mandatory from API 31 and harmless before it.
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(
            context, requestCodeFor(accountId), intent, flags
        )
    }

    fun schedule(context: Context, accountId: String, intervalMinutes: Int): Boolean {
        return try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = System.currentTimeMillis() + intervalMinutes * 60_000L

            am.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                intentFor(context, accountId)
            )

            // Remember it so BootReceiver can restore it, and so a re-arm after
            // firing knows the interval.
            val p = prefs(context)
            val accounts = p.getStringSet(KEY_ACCOUNTS, emptySet())!!.toMutableSet()
            accounts.add(accountId)
            p.edit()
                .putStringSet(KEY_ACCOUNTS, accounts)
                .putInt(KEY_INTERVAL_PREFIX + accountId, intervalMinutes)
                .apply()

            Log.i(TAG, "armed: interval=${intervalMinutes}m")
            true
        } catch (t: Throwable) {
            // Never throw into Flutter -- the Dart side falls back to
            // WorkManager, which is a degradation rather than a failure.
            Log.e(TAG, "schedule failed: ${t.message}")
            false
        }
    }

    fun cancel(context: Context, accountId: String): Boolean {
        return try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(intentFor(context, accountId))

            val p = prefs(context)
            val accounts = p.getStringSet(KEY_ACCOUNTS, emptySet())!!.toMutableSet()
            accounts.remove(accountId)
            p.edit()
                .putStringSet(KEY_ACCOUNTS, accounts)
                .remove(KEY_INTERVAL_PREFIX + accountId)
                .apply()

            Log.i(TAG, "cancelled")
            true
        } catch (t: Throwable) {
            Log.e(TAG, "cancel failed: ${t.message}")
            false
        }
    }

    fun isScheduled(context: Context, accountId: String): Boolean =
        prefs(context).getStringSet(KEY_ACCOUNTS, emptySet())!!.contains(accountId)

    /** Re-arm every remembered account. Used after a firing and after boot. */
    fun rescheduleAll(context: Context) {
        val p = prefs(context)
        val accounts = p.getStringSet(KEY_ACCOUNTS, emptySet()) ?: return
        // PR #435 review I-6: COUNT the successes; do not announce them.
        //
        // `schedule(...)` returns Boolean and this discarded it, then logged
        // "rescheduled N account(s)" unconditionally. After a boot where every
        // single re-arm failed, logcat would read "rescheduled 3 account(s)"
        // while zero alarms existed -- and this log is the primary evidence
        // for whether F235 survives a reboot, which is the one thing manual
        // validation is meant to establish. CLAUDE.md IMP-3: an unconditional
        // success message is a lie waiting to happen.
        var armed = 0
        var attempted = 0
        for (accountId in accounts) {
            val interval = p.getInt(KEY_INTERVAL_PREFIX + accountId, 0)
            if (interval > 0) {
                attempted++
                if (schedule(context, accountId, interval)) armed++
            }
        }
        if (armed == attempted) {
            Log.i(TAG, "rescheduled $armed of $attempted account(s)")
        } else {
            Log.w(TAG, "rescheduled only $armed of $attempted account(s) -- "
                + "the rest will not scan while idle")
        }
    }
}

/**
 * Receives the alarm, re-arms the next one, and lets WorkManager's existing
 * worker do the scan.
 *
 * **Re-arming FIRST is deliberate.** If the scan throws, the schedule must
 * survive -- an alarm chain that breaks on one bad scan stops silently and
 * forever, which is worse than the defect this card fixes.
 */
class DozeAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val accountId = intent.getStringExtra(DozeAlarmScheduler.EXTRA_ACCOUNT_ID)
        Log.i("DozeAlarmReceiver", "fired")

        // Re-arm before doing anything that can fail.
        if (accountId != null) {
            val prefs = context.getSharedPreferences("f235_doze_alarms", Context.MODE_PRIVATE)
            val interval = prefs.getInt("interval_$accountId", 0)
            if (interval > 0) {
                // PR #435 review I-6: the return was discarded here too, and
                // this one matters MORE than rescheduleAll's. An alarm does
                // not repeat -- this re-arm IS the chain. A silent failure
                // here stops the account scanning while idle, permanently,
                // until something else reschedules it.
                if (!DozeAlarmScheduler.schedule(context, accountId, interval)) {
                    Log.w("DozeAlarmReceiver", "re-arm FAILED -- this account "
                        + "will not wake again until the app reschedules it")
                }
            }
        }

        // The scan itself runs through the existing WorkManager one-off path,
        // so the Dart worker, the ScanCoordinator lease and all the F175/F177
        // protections are reused rather than duplicated here.
        DozeScanTrigger.enqueue(context, accountId)
    }
}

/**
 * Restores alarms after a reboot.
 *
 * WorkManager persists its work across restarts; an AlarmManager alarm does
 * NOT. Without this receiver, background scanning would silently stop after
 * every reboot and the user would have no way to know -- a regression against
 * the behaviour this card is replacing.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.i("BootReceiver", "restoring Doze alarms after boot")
            DozeAlarmScheduler.rescheduleAll(context)
        }
    }
}
