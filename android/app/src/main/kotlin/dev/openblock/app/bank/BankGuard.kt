package dev.openblock.app.bank

import android.Manifest
import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import dev.openblock.app.accessibility.OpenBlockAccessibilityService
import dev.openblock.app.storage.NativeStore
import dev.openblock.app.usage.UsageReader

/**
 * Steps the accessibility service aside while a banking app is in front.
 *
 * Many banking apps refuse to run while a third-party accessibility service is
 * enabled, and an enabled service cannot be hidden from them. With the user's
 * opt-in, the service turns itself off when a listed banking app opens and
 * [BankGuardService] turns it back on once an app with rules comes to the
 * front or OpenBlock itself is opened.
 *
 * Turning a service back on needs WRITE_SECURE_SETTINGS, which only ADB can
 * grant, and noticing when to do it needs usage access. Without both the guard
 * does nothing, so blocking is never left off by accident.
 */
object BankGuard {
    fun hasSecureSettingsPermission(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) ==
            PackageManager.PERMISSION_GRANTED

    fun isAvailable(context: Context): Boolean =
        hasSecureSettingsPermission(context) && UsageReader(context).hasPermission()

    /**
     * Turns [service] off until the banking app is left. Returns false, leaving
     * the service running, when the guard cannot bring it back afterwards.
     */
    fun pause(service: AccessibilityService): Boolean {
        if (!isAvailable(service)) return false
        try {
            service.startForegroundService(Intent(service, BankGuardService::class.java))
        } catch (_: RuntimeException) {
            // Starting a foreground service was refused; staying on is safer.
            return false
        }
        NativeStore.get(service).setBankPaused(true)
        service.disableSelf()
        return true
    }

    /** Turns the service back on if the guard turned it off. */
    fun resume(context: Context) {
        val store = NativeStore.get(context)
        if (!store.isBankPaused()) return
        enableService(context)
        store.setBankPaused(false)
        context.stopService(Intent(context, BankGuardService::class.java))
    }

    private fun enableService(context: Context) {
        val resolver = context.contentResolver
        val target = ComponentName(context, OpenBlockAccessibilityService::class.java)
        try {
            val services = Settings.Secure.getString(
                resolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ).orEmpty().split(':').filter { it.isNotBlank() }
            if (services.none { ComponentName.unflattenFromString(it) == target }) {
                Settings.Secure.putString(
                    resolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
                    (services + target.flattenToString()).joinToString(":"),
                )
            }
            Settings.Secure.putInt(resolver, Settings.Secure.ACCESSIBILITY_ENABLED, 1)
        } catch (_: SecurityException) {
            // The permission was revoked; Home reports the service as off.
        }
    }
}
