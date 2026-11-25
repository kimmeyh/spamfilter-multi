package com.myemailspamfilter.devicestate

import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * F346 (Sprint 86): reports the phone's power-save, device-idle and thermal
 * state for the diagnostic log line written when WorkManager stops a
 * background scan.
 *
 * Why a plugin and not a channel in MainActivity: the stop handler runs in the
 * WorkManager BACKGROUND engine (`BackgroundWorker.kt:132`,
 * workmanager_android 0.10.9), and MainActivity.configureFlutterEngine only
 * runs for the UI engine. A plugin listed in GeneratedPluginRegistrant is added
 * to every engine that registers plugins automatically, which the background
 * engine does (it reaches WorkmanagerPlugin that way, `BackgroundWorker.kt:137`).
 *
 * Every field is read in its own guard: a field that cannot be read is null
 * (Dart logs "unknown"), and the other fields still return.
 */
class DeviceStatePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "read" -> result.success(read())
            else -> result.notImplemented()
        }
    }

    private fun read(): Map<String, Any?> {
        val pm = try {
            context?.getSystemService(Context.POWER_SERVICE) as? PowerManager
        } catch (t: Throwable) {
            Log.e(TAG, "power service unavailable: ${t.message}")
            null
        }
        return mapOf(
            "powerSave" to guarded("powerSave") { pm?.isPowerSaveMode },
            "deviceIdle" to guarded("deviceIdle") { pm?.isDeviceIdleMode },
            "thermal" to guarded("thermal") {
                // getCurrentThermalStatus is API 29+; below that it is unknown.
                if (pm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    thermalName(pm.currentThermalStatus)
                } else {
                    null
                }
            },
        )
    }

    private fun <T> guarded(field: String, block: () -> T?): T? =
        try {
            block()
        } catch (t: Throwable) {
            Log.e(TAG, "$field read failed: ${t.message}")
            null
        }

    companion object {
        const val CHANNEL = "com.myemailspamfilter/device_state"
        private const val TAG = "DeviceStatePlugin"

        /** PowerManager.THERMAL_STATUS_* names; an unlisted value reads null. */
        fun thermalName(status: Int): String? = when (status) {
            0 -> "none"
            1 -> "light"
            2 -> "moderate"
            3 -> "severe"
            4 -> "critical"
            5 -> "emergency"
            6 -> "shutdown"
            else -> null
        }
    }
}
