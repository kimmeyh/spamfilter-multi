package com.myemailspamfilter

import android.content.Context
import android.util.Log
import androidx.work.ExistingWorkPolicy
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
 *  - the `ScanCoordinator` lease (F175), which stops two scans opening two IMAP
 *    sessions to one account -- the Sprint 61 per-account session-cap failure;
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

    /** Must match `kAndroidScanTaskName` on the Dart side. */
    private const val TASK_NAME = "com.myemailspamfilter.backgroundScan"

    fun enqueue(context: Context, accountId: String?) {
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
                    "f235DozeWake" to true,
                ),
                uniqueName = uniqueName,
            )

            val request = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
                .setInputData(input)
                .setInitialDelay(0, TimeUnit.SECONDS)
                .build()

            // REPLACE, not APPEND: if a scan for this account is somehow still
            // queued, running a second is exactly the stacking F175 and the
            // Sprint 61 forensics exist to prevent.
            WorkManager.getInstance(context).enqueueUniqueWork(
                uniqueName,
                ExistingWorkPolicy.REPLACE,
                request,
            )
            Log.i(TAG, "scan enqueued after Doze wake")
        } catch (t: Throwable) {
            // Never crash the receiver. A failed enqueue means this interval is
            // missed; the alarm has already re-armed, so the next one fires.
            Log.e(TAG, "enqueue failed: ${t.message}")
        }
    }
}
