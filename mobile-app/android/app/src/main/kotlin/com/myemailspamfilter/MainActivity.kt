package com.myemailspamfilter

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
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
        const val BATTERY_CHANNEL = "com.myemailspamfilter/battery"
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

        // F252 (Sprint 76): battery-optimization state + the page where the
        // user changes it. A separate channel because the Doze channel above
        // requires an accountId on every call.
        //
        // Deliberately NOT `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: that
        // needs REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, which Google Play
        // restricts ("prohibit apps from requesting direct exemption ...
        // unless the core function of the app is adversely affected"). Opening
        // the app's own settings page lets the USER choose Unrestricted.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BATTERY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    try {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } catch (t: Throwable) {
                        // Unknown, not "optimized": Dart shows no status.
                        result.success(null)
                    }
                }

                "openAppSettings" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (t: Throwable) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
