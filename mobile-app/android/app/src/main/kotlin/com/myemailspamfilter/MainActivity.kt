package com.myemailspamfilter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * F235 (Sprint 73): hosts the Doze-alarm method channel.
 *
 * This class was a bare `class MainActivity : FlutterActivity()` before -- the
 * app had no native bridge at all, which is most of why this card cost more
 * than its estimate assumed.
 *
 * The channel is deliberately thin: it forwards to [DozeAlarmScheduler] and
 * returns booleans. Every failure inside that object is caught and reported as
 * `false` rather than thrown, because the Dart side treats a false as "fall
 * back to WorkManager" -- a degradation, not a failure. A thrown
 * PlatformException would reach Dart as an error and risk disabling scheduling
 * entirely, which is worse than the defect being fixed.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "com.myemailspamfilter/doze_alarm"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            val accountId = call.argument<String>("accountId")
            if (accountId == null) {
                // Not an exception: the caller gets false and falls back.
                result.success(false)
                return@setMethodCallHandler
            }

            when (call.method) {
                "schedule" -> {
                    val minutes = call.argument<Int>("intervalMinutes") ?: 0
                    if (minutes <= 0) {
                        result.success(false)
                    } else {
                        result.success(
                            DozeAlarmScheduler.schedule(
                                applicationContext,
                                accountId,
                                minutes,
                            ),
                        )
                    }
                }

                "cancel" ->
                    result.success(
                        DozeAlarmScheduler.cancel(applicationContext, accountId),
                    )

                "isScheduled" ->
                    result.success(
                        DozeAlarmScheduler.isScheduled(applicationContext, accountId),
                    )

                else -> result.notImplemented()
            }
        }
    }
}
