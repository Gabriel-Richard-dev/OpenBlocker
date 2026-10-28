package dev.openblock.app.accessibility

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.view.accessibility.AccessibilityManager

/** Reports whether the OpenBlock accessibility service is enabled and running. */
object ServiceStatus {
    private fun component(context: Context) =
        ComponentName(context, OpenBlockAccessibilityService::class.java)

    /** The user switched the service on in system settings. */
    fun isEnabledInSettings(context: Context): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val target = component(context)
        return enabled.split(':').any {
            ComponentName.unflattenFromString(it) == target
        }
    }

    /** The system has the service bound right now. */
    fun isRunning(context: Context): Boolean {
        val manager = context.getSystemService(AccessibilityManager::class.java) ?: return false
        val target = component(context)
        return manager
            .getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { info ->
                val service = info.resolveInfo?.serviceInfo ?: return@any false
                ComponentName(service.packageName, service.name) == target
            } && OpenBlockAccessibilityService.isConnected
    }
}
