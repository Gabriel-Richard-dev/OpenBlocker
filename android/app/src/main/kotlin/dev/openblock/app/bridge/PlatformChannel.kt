package dev.openblock.app.bridge

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import dev.openblock.app.accessibility.ServiceStatus
import dev.openblock.app.apps.InstalledApps
import dev.openblock.app.bank.BankGuard
import dev.openblock.app.storage.NativeStore
import dev.openblock.app.usage.UsageReader
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Method channel `dev.openblock.app/platform`. The contract is documented in
 * docs/architecture.md and mirrored by `lib/data/platform/openblock_platform.dart`.
 */
class PlatformChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val store = NativeStore.get(context)
    private val usage = UsageReader(context)
    private val apps = InstalledApps(context)
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissions" -> result.success(
                mapOf(
                    "accessibilityEnabled" to ServiceStatus.isEnabledInSettings(context),
                    "accessibilityRunning" to ServiceStatus.isRunning(context),
                    "usageAccessGranted" to usage.hasPermission(),
                    "secureSettingsGranted" to BankGuard.hasSecureSettingsPermission(context),
                    "sdkInt" to Build.VERSION.SDK_INT,
                ),
            )
            "openAccessibilitySettings" -> open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS), result)
            "openUsageAccessSettings" -> open(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS), result)
            "openAppDetailsSettings" -> open(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", context.packageName, null),
                ),
                result,
            )
            "getInstalledApps" -> background(result) {
                apps.launchable().map { mapOf("packageName" to it.packageName, "label" to it.label) }
            }
            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.error("bad_args", "packageName is required", null)
                } else {
                    background(result) { apps.iconPng(packageName) }
                }
            }
            "syncConfig" -> {
                val config = call.argument<String>("config")
                if (config == null) {
                    result.error("bad_args", "config is required", null)
                } else {
                    store.saveConfig(config)
                    result.success(null)
                }
            }
            "getDailyUsage" -> {
                val packages = call.argument<List<String>>("packages").orEmpty().toSet()
                val days = (call.argument<Int>("days") ?: 7).coerceIn(1, 31)
                background(result) {
                    usage.dailyUsage(packages, days)?.map { (day, minutes) ->
                        mapOf("date" to day.toString(), "usage" to minutes)
                    }
                }
            }
            "getRuntimeState" -> result.success(runtimeState())
            "clearSnooze" -> {
                call.argument<String>("ruleId")?.let(store::clearSnooze)
                result.success(null)
            }
            "clearRuntimeData" -> {
                store.clearRuntime()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun runtimeState(): Map<String, Any?> {
        val events = store.events()
        val list = ArrayList<Map<String, Any?>>(events.length())
        for (i in 0 until events.length()) {
            val event = events.optJSONObject(i) ?: continue
            list.add(
                mapOf(
                    "atMs" to event.optLong("atMs"),
                    "ruleId" to event.optString("ruleId"),
                    "packageName" to event.optString("packageName"),
                    "kind" to event.optString("kind"),
                ),
            )
        }
        return mapOf(
            "snoozes" to store.snoozes(),
            "endedFocusId" to store.endedFocusId(),
            "endedFocusAtMs" to store.endedFocusAtMs(),
            "events" to list,
        )
    }

    private fun open(intent: Intent, result: MethodChannel.Result) {
        try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            result.success(null)
        } catch (e: Exception) {
            result.error("unavailable", e.message, null)
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message, null) }
            }
        }
    }

    companion object {
        const val CHANNEL = "dev.openblock.app/platform"
    }
}
