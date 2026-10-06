package com.myemailspamfilter

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker
import dev.fluttercommunity.workmanager.buildTaskInputData
import java.util.concurrent.TimeUnit

/**
 * F235 (Sprint 73): hand a Doze-woken alarm off to the EXISTING WorkManager
 * worker rather than running a scan here.
 *
 * **Why not scan directly from the BroadcastReceiver.** A receiver has roughly
 * ten seconds before the system may kill it, and a mail scan takes far longer.
 * More importantly, the Dart worker already carries protections this card must
 * not re-implement or bypass:
 *
 *  - the cross-isolate exclusion (ADR-0039 amendment, Sprint 74): the worker
 *    skips an account with a live interactive scan, via a heartbeat on the
 *    shared `scan_results` row. (NOT the `ScanCoordinator` lease -- this
 *    worker runs in its own FlutterEngine, so that lease never sees the UI's
 *    scans; corrected in MV74-2);
 *  - the F177 per-batch memory handling that stopped Android low-memory kills;
 *  - the F175 R-6 exponential backoff that bounded a crashing scan.
 *
 * Enqueuing a one-off keeps all of it. The alarm's only job is to WAKE the
 * device in Doze, which is the one thing WorkManager cannot do for itself.
 *
 * **The input data is built with the plugin's own `buildTaskInputData`, not by
 * hand.** A hand-rolled version of this was written first and had two silent
 * defects: the Dart-task key carried the plugin's OLD package name
 * (`be.tramckrijte.…` rather than `dev.fluttercommunity.…`), and the payload
 * key lacked the mandatory `payload_` prefix, so `accountId` would never have
 * reached Dart. Both would have failed quietly at runtime -- the alarm would
 * fire, the worker would start, and the scan would do nothing.
 */
object DozeScanTrigger {
    private const val TAG = "DozeScanTrigger"

    /**
     * Must match `kAndroidScanTaskName` in
     * `lib/core/services/android_background_scan_worker.dart`.
     *
     * **This was WRONG and shipped wrong** (PR #435 review C-3): it read
     * "com.myemailspamfilter.backgroundScan", a string that appears nowhere
     * else in the repo, while the Dart constant is "spamfilter_background_scan".
     * The KDoc asserted parity that did not hold -- the exact defect class
     * CLAUDE.md IMP-2 names, in code written the same sprint the rule was
     * being applied elsewhere.
     *
     * **It did not break the scan, and that is what makes it dangerous.** The
     * dispatcher routes on `inputData`, not on `taskName`; `taskName` is read
     * only to decide `isTest`, and the wrong value happened to be falsy for
     * that comparison. Safe BY ACCIDENT, with nothing marking the dependency --
     * CLAUDE.md Sprint 72 IMP-1. Refactoring the dispatcher to
     * `switch (taskName)`, which is the obvious cleanup, would have silently
     * killed every Doze-woken scan.
     *
     * Pinned by a source-parity assertion in `f235_doze_alarm_test.dart` so
     * the two literals cannot drift apart again.
     */
    private const val TASK_NAME = "spamfilter_background_scan"

    /**
     * Payload keys the Dart worker reads to name what started it (F252 R-2).
     * Must match `kTriggerSourceKey` / `kTriggerAtMsKey` in
     * `lib/core/services/background_scan_trigger.dart` (pinned by a source-parity
     * test, the same way TASK_NAME is).
     */
    const val KEY_TRIGGER_SOURCE = "triggerSource"
    const val KEY_TRIGGER_AT_MS = "triggerAtMs"
    const val SOURCE_DOZE_ALARM = "doze-alarm"

    /**
     * [triggerAtMs] is when the ALARM fired (wall clock), so the worker can log
     * how long Android held the scan back after the alarm. F252: that delay is
     * the measurement that decides whether the alarm-to-WorkManager handoff
     * actually scans while the phone is idle.
     */
    fun enqueue(
        context: Context,
        accountId: String?,
        triggerAtMs: Long = System.currentTimeMillis(),
    ) {
        if (accountId == null) {
            Log.w(TAG, "no accountId on the alarm intent; nothing enqueued")
            return
        }
        try {
            val uniqueName = "f235_doze_scan_$accountId"

            val input = buildTaskInputData(
                dartTask = TASK_NAME,
                payload = mapOf(
                    "accountId" to accountId,
                    KEY_TRIGGER_SOURCE to SOURCE_DOZE_ALARM,
                    KEY_TRIGGER_AT_MS to triggerAtMs,
                ),
                uniqueName = uniqueName,
            )

            val request = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
                .setInputData(input)
                .setInitialDelay(0, TimeUnit.SECONDS)
                .build()

            // KEEP, not REPLACE and not APPEND (F249 part 2, Harold Q1 = 1,
            // 2026-10-05). APPEND would stack scans (F175, the Sprint 61
            // forensics). REPLACE was used until 0.17.4, but it CANCELS the
            // existing work even while it is RUNNING: an alarm firing during a
            // long Doze-started scan killed that scan mid-fetch, with no outcome
            // line and an in_progress row left for the reaper (both 5.1.1
            // reviewers confirmed the scenario). KEEP lets the running scan
            // finish and drops the new request; the next alarm re-arms anyway.
            WorkManager.getInstance(context).enqueueUniqueWork(
                uniqueName,
                ExistingWorkPolicy.KEEP,
                request,
            )
            Log.i(TAG, "scan enqueued after Doze wake")
        } catch (t: Throwable) {
            // Never crash the receiver. A failed enqueue means this interval is
            // missed; the alarm has already re-armed, so the next one fires.
            Log.e(TAG, "enqueue failed: ${t.message}")
        }
    }

    /** Must match `kTriggerAppKey` in `background_scan_trigger.dart`. */
    const val KEY_TRIGGER_APP = "triggerApp"
    private const val UNIQUE_NEW_MAIL = "f253_new_mail_scan"

    /**
     * F253 (Sprint 76): one scan of EVERY account (no accountId -- the worker's
     * all-accounts path, where each account's own background switch and the
     * per-account claim still decide), started by a mail app's notification.
     *
     * KEEP, not REPLACE: a notification that arrives while a triggered scan is
     * queued or running must not cancel it or stack a second (R-5). Requires a
     * network connection, so a trigger in a no-network moment waits instead of
     * running a scan that can only fail.
     */
    fun enqueueAllAccounts(
        context: Context,
        source: String,
        triggerAtMs: Long,
        sourceApp: String,
    ) {
        val input = buildTaskInputData(
            dartTask = TASK_NAME,
            payload = mapOf(
                KEY_TRIGGER_SOURCE to source,
                KEY_TRIGGER_AT_MS to triggerAtMs,
                KEY_TRIGGER_APP to sourceApp,
            ),
            uniqueName = UNIQUE_NEW_MAIL,
        )
        val request = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
            .setInputData(input)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
            )
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            UNIQUE_NEW_MAIL,
            ExistingWorkPolicy.KEEP,
            request,
        )
        // "requested", not "enqueued": with KEEP an already-queued scan wins
        // and this request is dropped by design (review H-1).
        Log.i(TAG, "scan requested after a mail notification")
    }

    /** Turning F253 off cancels a queued or backing-off new-mail scan (review H-1). */
    fun cancelNewMailScan(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_NEW_MAIL)
    }
}
